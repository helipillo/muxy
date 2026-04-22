import Foundation

enum AmpUsageAPIClient {
    private static let endpointURL = URL(string: "https://ampcode.com/api/internal")!

    static func fetchSnapshot(for provider: AIProviderUsageDescriptor) async -> AIProviderUsageSnapshot {
        do {
            let token = try readToken()

            var request = URLRequest(url: endpointURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "method": "userDisplayBalanceInfo",
                "params": [:],
            ])

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClaudeUsageError.invalidResponse
            }

            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                return AIProviderUsageSnapshot(
                    providerID: provider.providerID,
                    providerName: provider.providerName,
                    providerIconName: provider.providerIconName,
                    state: .unavailable(message: "Session expired. Re-authenticate in Amp."),
                    rows: []
                )
            }

            guard (200 ..< 300).contains(httpResponse.statusCode) else {
                throw ClaudeUsageError.httpStatus(httpResponse.statusCode)
            }

            let rows = try AmpUsageParser.parseMetricRows(from: data)
            guard !rows.isEmpty else {
                return AIProviderUsageSnapshot(
                    providerID: provider.providerID,
                    providerName: provider.providerName,
                    providerIconName: provider.providerIconName,
                    state: .unavailable(message: "No usage data"),
                    rows: []
                )
            }

            return AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .available,
                rows: rows
            )
        } catch ClaudeUsageError.missingAccessToken {
            return AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .unavailable(message: "Sign in to Amp"),
                rows: []
            )
        } catch let ClaudeUsageError.httpStatus(statusCode) {
            usageLogger.error("Amp usage request failed with status \(statusCode)")
            return AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .error(message: "Usage request failed"),
                rows: []
            )
        } catch {
            usageLogger.error("Amp usage request failed: \(error.localizedDescription)")
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
        if let token = env["AMP_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
            return token
        }

        let path = NSHomeDirectory() + "/.local/share/amp/secrets.json"
        if FileManager.default.fileExists(atPath: path) {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            if let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = AIUsageParserSupport.string(in: payload, keys: ["apiKey@https://ampcode.com/", "apiKey", "token"]),
               !token.isEmpty
            {
                return token
            }
        }

        throw ClaudeUsageError.missingAccessToken
    }
}
