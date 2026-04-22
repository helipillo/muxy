import Foundation

enum ZaiUsageAPIClient {
    private static let subscriptionURL: URL? = URL(string: "https://api.z.ai/api/biz/subscription/list")
    private static let quotaURL: URL? = URL(string: "https://api.z.ai/api/monitor/usage/quota/limit")

    static func fetchSnapshot(for provider: AIProviderUsageDescriptor) async -> AIProviderUsageSnapshot {
        do {
            let apiKey = try readToken()
            let headers = [
                "Authorization": "Bearer \(apiKey)",
                "Accept": "application/json",
            ]

            guard let subURL = subscriptionURL, let quotaURL else { throw ClaudeUsageError.missingAccessToken }
            let subscriptionData: Data?
            do {
                let response = try await fetch(url: subURL, headers: headers)
                if (200 ..< 300).contains(response.statusCode) {
                    subscriptionData = response.data
                } else {
                    subscriptionData = nil
                }
            } catch {
                subscriptionData = nil
            }

            let quotaResponse = try await fetch(url: quotaURL, headers: headers)
            if quotaResponse.statusCode == 401 || quotaResponse.statusCode == 403 {
                return AIProviderUsageSnapshot(
                    providerID: provider.providerID,
                    providerName: provider.providerName,
                    providerIconName: provider.providerIconName,
                    state: .unavailable(message: "Invalid Z.ai API key"),
                    rows: []
                )
            }
            guard (200 ..< 300).contains(quotaResponse.statusCode) else {
                throw ClaudeUsageError.httpStatus(quotaResponse.statusCode)
            }

            let rows = try ZaiUsageParser.parseMetricRows(quotaData: quotaResponse.data)
            guard !rows.isEmpty else {
                return AIProviderUsageSnapshot(
                    providerID: provider.providerID,
                    providerName: provider.providerName,
                    providerIconName: provider.providerIconName,
                    state: .unavailable(message: "No usage data"),
                    rows: []
                )
            }

            let planName = subscriptionData.flatMap { ZaiUsageParser.parsePlanName(subscriptionData: $0) } ?? provider.providerName

            return AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: planName,
                providerIconName: provider.providerIconName,
                state: .available,
                rows: rows
            )
        } catch ClaudeUsageError.missingAccessToken {
            return AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .unavailable(message: "Set ZAI_API_KEY or GLM_API_KEY"),
                rows: []
            )
        } catch let ClaudeUsageError.httpStatus(statusCode) {
            usageLogger.error("Z.ai usage request failed with status \(statusCode)")
            return AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .error(message: "Usage request failed"),
                rows: []
            )
        } catch {
            usageLogger.error("Z.ai usage request failed: \(error.localizedDescription)")
            return AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .error(message: "Unable to fetch usage"),
                rows: []
            )
        }
    }

    static func readToken(env: [String: String] = ProcessInfo.processInfo.environment) throws -> String {
        for key in ["ZAI_API_KEY", "GLM_API_KEY"] {
            if let token = env[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
                return token
            }
        }
        throw ClaudeUsageError.missingAccessToken
    }

    private static func fetch(url: URL, headers: [String: String]) async throws -> (statusCode: Int, data: Data) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeUsageError.invalidResponse
        }
        return (httpResponse.statusCode, data)
    }
}
