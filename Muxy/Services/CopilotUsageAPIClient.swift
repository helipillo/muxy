import Foundation

enum CopilotUsageAPIClient {
    private static let endpointURL = URL(string: "https://api.github.com/copilot_internal/user")!

    static func fetchSnapshot(for provider: AIProviderUsageDescriptor) async -> AIProviderUsageSnapshot {
        do {
            let token = try readToken()

            var request = URLRequest(url: endpointURL)
            request.httpMethod = "GET"
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("vscode/1.96.2", forHTTPHeaderField: "Editor-Version")
            request.setValue("copilot-chat/0.26.7", forHTTPHeaderField: "Editor-Plugin-Version")
            request.setValue("GitHubCopilotChat/0.26.7", forHTTPHeaderField: "User-Agent")
            request.setValue("2025-04-01", forHTTPHeaderField: "X-Github-Api-Version")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClaudeUsageError.invalidResponse
            }
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                return AIProviderUsageSnapshot(
                    providerID: provider.providerID,
                    providerName: provider.providerName,
                    providerIconName: provider.providerIconName,
                    state: .unavailable(message: "Copilot token lacks usage access"),
                    rows: []
                )
            }
            guard (200 ..< 300).contains(httpResponse.statusCode) else {
                throw ClaudeUsageError.httpStatus(httpResponse.statusCode)
            }

            let rows = try CopilotUsageParser.parseMetricRows(from: data)
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
                state: .unavailable(message: "Sign in to Copilot"),
                rows: []
            )
        } catch let ClaudeUsageError.httpStatus(statusCode) {
            usageLogger.error("Copilot usage request failed with status \(statusCode)")
            return AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .error(message: "Usage request failed"),
                rows: []
            )
        } catch {
            usageLogger.error("Copilot usage request failed: \(error.localizedDescription)")
            return AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .error(message: "Unable to fetch usage"),
                rows: []
            )
        }
    }

    static func readToken(
        env: [String: String] = ProcessInfo.processInfo.environment,
        keychainReader: ((String) -> String?)? = nil,
        homeDirectory: String = NSHomeDirectory(),
        fileExists: ((String) -> Bool)? = nil,
        dataReader: ((String) throws -> Data)? = nil
    ) throws -> String {
        let doesFileExist: (String) -> Bool = fileExists ?? { path in
            FileManager.default.fileExists(atPath: path)
        }
        let readData: (String) throws -> Data = dataReader ?? { path in
            try Data(contentsOf: URL(fileURLWithPath: path))
        }
        for key in ["COPILOT_GITHUB_TOKEN", "GH_TOKEN", "GITHUB_TOKEN"] {
            if let token = env[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
                return token
            }
        }

        let hostsPath = homeDirectory + "/.config/github-copilot/hosts.json"
        if doesFileExist(hostsPath) {
            let data = try readData(hostsPath)
            if let token = try CopilotUsageParser.extractToken(fromHostsData: data), !token.isEmpty {
                return token
            }
        }

        let readKeychainValue: (String) -> String? = keychainReader ?? { service in
            runCommand(executable: "/usr/bin/security", arguments: ["find-generic-password", "-s", service, "-w"])
        }

        if let raw = readKeychainValue("OpenUsage-copilot") {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if let data = trimmed.data(using: .utf8),
               let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = AIUsageParserSupport.string(in: payload, keys: ["token"]),
               !token.isEmpty
            {
                return token
            }
        }

        if let rawGh = readKeychainValue("gh:github.com") {
            let trimmed = rawGh.trimmingCharacters(in: .whitespacesAndNewlines)
            let tokenCandidate: String
            if trimmed.hasPrefix("go-keyring-base64:") {
                let encoded = String(trimmed.dropFirst("go-keyring-base64:".count))
                if let data = Data(base64Encoded: encoded), let decoded = String(data: data, encoding: .utf8) {
                    tokenCandidate = decoded
                } else {
                    tokenCandidate = trimmed
                }
            } else {
                tokenCandidate = trimmed
            }

            let normalized = tokenCandidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalized.isEmpty {
                return normalized
            }
        }

        let ghHostsPath = homeDirectory + "/.config/gh/hosts.yml"
        if doesFileExist(ghHostsPath) {
            let data = try readData(ghHostsPath)
            if let yaml = String(data: data, encoding: .utf8),
               let token = CopilotUsageParser.extractToken(fromGHHostsYAML: yaml),
               !token.isEmpty
            {
                return token
            }
        }

        throw ClaudeUsageError.missingAccessToken
    }

    private static func runCommand(executable: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            return nil
        }

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        _ = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0,
              let output = String(data: outputData, encoding: .utf8)
        else {
            return nil
        }

        return output
    }
}
