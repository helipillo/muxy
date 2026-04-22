import Foundation

enum CodexUsageAPIClient {
    private static let endpointURL: URL? = URL(string: "https://chatgpt.com/backend-api/wham/usage")

    static func fetchSnapshot(for provider: AIProviderUsageDescriptor) async -> AIProviderUsageSnapshot {
        do {
            let auth = try readAuth()

            guard let url = endpointURL else { throw ClaudeUsageError.invalidResponse }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            if let accountID = auth.accountID, !accountID.isEmpty {
                request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClaudeUsageError.invalidResponse
            }
            guard (200 ..< 300).contains(httpResponse.statusCode) else {
                throw ClaudeUsageError.httpStatus(httpResponse.statusCode)
            }

            let rows = try CodexUsageParser.parseMetricRows(from: data)
            if rows.isEmpty {
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
                state: .unavailable(message: "Sign in to Codex"),
                rows: []
            )
        } catch let ClaudeUsageError.httpStatus(statusCode) {
            usageLogger.error("Codex usage request failed with status \(statusCode)")
            return AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .error(message: "Usage request failed"),
                rows: []
            )
        } catch {
            usageLogger.error("Codex usage request failed: \(error.localizedDescription)")
            return AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .error(message: "Unable to fetch usage"),
                rows: []
            )
        }
    }

    static func readAuth(env: [String: String] = ProcessInfo.processInfo.environment) throws -> (accessToken: String, accountID: String?) {
        if let token = env["CODEX_ACCESS_TOKEN"]?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
            return (token, env["CODEX_ACCOUNT_ID"]?.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let home = NSHomeDirectory()
        let candidatePaths = [
            (env["CODEX_HOME"].map { "\($0)/auth.json" }),
            "\(home)/.config/codex/auth.json",
            "\(home)/.codex/auth.json",
        ].compactMap(\.self)

        for path in candidatePaths {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            if let tokens = payload["tokens"] as? [String: Any],
               let accessToken = AIUsageParserSupport.string(in: tokens, keys: ["access_token"]),
               !accessToken.isEmpty
            {
                let accountID = AIUsageParserSupport.string(in: tokens, keys: ["account_id"])
                return (accessToken, accountID)
            }
        }

        throw ClaudeUsageError.missingAccessToken
    }
}
