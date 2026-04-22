import Foundation

enum CursorUsageAPIClient {
    private static let baseURL = URL(string: "https://api2.cursor.sh")!
    private static let usageURL = baseURL.appendingPathComponent("aiserver.v1.DashboardService/GetCurrentPeriodUsage")
    private static let planURL = baseURL.appendingPathComponent("aiserver.v1.DashboardService/GetPlanInfo")
    private static let refreshURL = baseURL.appendingPathComponent("oauth/token")
    private static let refreshClientID = "KbZUR41cY7W6zRSdpSUJ7I7mLYBKOCmB"

    private enum TokenSource {
        case environment
        case sqlite
        case keychain
    }

    private struct AuthState {
        var accessToken: String?
        let refreshToken: String?
        let source: TokenSource
    }

    static func fetchSnapshot(for provider: AIProviderUsageDescriptor) async -> AIProviderUsageSnapshot {
        do {
            var authState = try readAuthState()

            if needsRefresh(authState.accessToken),
               let refreshToken = authState.refreshToken,
               let refreshed = try await refreshAccessToken(refreshToken: refreshToken, source: authState.source)
            {
                authState.accessToken = refreshed
            }

            guard var accessToken = normalized(authState.accessToken) else {
                throw ClaudeUsageError.missingAccessToken
            }

            var usageResponse = try await connectPost(url: usageURL, accessToken: accessToken)
            if usageResponse.statusCode == 401, let refreshToken = authState.refreshToken,
               let refreshed = try await refreshAccessToken(refreshToken: refreshToken, source: authState.source)
            {
                accessToken = refreshed
                usageResponse = try await connectPost(url: usageURL, accessToken: accessToken)
            }

            if usageResponse.statusCode == 401 || usageResponse.statusCode == 403 {
                return AIProviderUsageSnapshot(
                    providerID: provider.providerID,
                    providerName: provider.providerName,
                    providerIconName: provider.providerIconName,
                    state: .unavailable(message: "Session expired. Sign in to Cursor."),
                    rows: []
                )
            }
            guard (200 ..< 300).contains(usageResponse.statusCode) else {
                throw ClaudeUsageError.httpStatus(usageResponse.statusCode)
            }

            let planData: Data?
            do {
                let planResponse = try await connectPost(url: planURL, accessToken: accessToken)
                planData = (200 ..< 300).contains(planResponse.statusCode) ? planResponse.data : nil
            } catch {
                planData = nil
            }

            let rows = try CursorUsageParser.parseMetricRows(usageData: usageResponse.data, planData: planData)
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
                state: .unavailable(message: "Sign in to Cursor"),
                rows: []
            )
        } catch CursorUsageParserError.noActiveSubscription {
            return AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .unavailable(message: "No active Cursor subscription"),
                rows: []
            )
        } catch let ClaudeUsageError.httpStatus(statusCode) {
            usageLogger.error("Cursor usage request failed with status \(statusCode)")
            return AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .error(message: "Usage request failed"),
                rows: []
            )
        } catch {
            usageLogger.error("Cursor usage request failed: \(error.localizedDescription)")
            return AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .error(message: "Unable to fetch usage"),
                rows: []
            )
        }
    }

    private static func readAuthState(env: [String: String] = ProcessInfo.processInfo.environment) throws -> AuthState {
        if let access = normalized(env["CURSOR_ACCESS_TOKEN"]) {
            return AuthState(accessToken: access, refreshToken: normalized(env["CURSOR_REFRESH_TOKEN"]), source: .environment)
        }

        let sqliteTokens = readSQLiteTokens()
        if sqliteTokens.accessToken != nil || sqliteTokens.refreshToken != nil {
            return AuthState(accessToken: sqliteTokens.accessToken, refreshToken: sqliteTokens.refreshToken, source: .sqlite)
        }

        let keychainTokens = readKeychainTokens()
        if keychainTokens.accessToken != nil || keychainTokens.refreshToken != nil {
            return AuthState(accessToken: keychainTokens.accessToken, refreshToken: keychainTokens.refreshToken, source: .keychain)
        }

        throw ClaudeUsageError.missingAccessToken
    }

    private static func readSQLiteTokens() -> (accessToken: String?, refreshToken: String?) {
        let dbPath = NSHomeDirectory() + "/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
        guard FileManager.default.fileExists(atPath: dbPath) else {
            return (nil, nil)
        }

        return (
            readSQLiteValue(dbPath: dbPath, key: "cursorAuth/accessToken"),
            readSQLiteValue(dbPath: dbPath, key: "cursorAuth/refreshToken")
        )
    }

    private static func readSQLiteValue(dbPath: String, key: String) -> String? {
        let escapedKey = key.replacingOccurrences(of: "'", with: "''")
        let sql = "SELECT value FROM ItemTable WHERE key = '\(escapedKey)' LIMIT 1;"
        guard let output = runCommand(executable: "/usr/bin/sqlite3", arguments: [dbPath, sql]) else { return nil }
        return normalized(output)
    }

    private static func writeSQLiteValue(key: String, value: String) {
        let dbPath = NSHomeDirectory() + "/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
        guard FileManager.default.fileExists(atPath: dbPath) else { return }

        let escapedKey = key.replacingOccurrences(of: "'", with: "''")
        let escapedValue = value.replacingOccurrences(of: "'", with: "''")
        let sql = "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('\(escapedKey)', '\(escapedValue)');"
        _ = runCommand(executable: "/usr/bin/sqlite3", arguments: [dbPath, sql])
    }

    private static func readKeychainTokens() -> (accessToken: String?, refreshToken: String?) {
        (
            readKeychain(service: "cursor-access-token"),
            readKeychain(service: "cursor-refresh-token")
        )
    }

    private static func readKeychain(service: String) -> String? {
        runCommand(executable: "/usr/bin/security", arguments: ["find-generic-password", "-s", service, "-w"])
            .flatMap(normalized)
    }

    private static func writeKeychain(service: String, value: String) {
        _ = runCommand(executable: "/usr/bin/security", arguments: ["add-generic-password", "-a", NSUserName(), "-s", service, "-w", value, "-U"])
    }

    private static func refreshAccessToken(refreshToken: String, source: TokenSource) async throws -> String? {
        guard !refreshToken.isEmpty else { return nil }

        var request = URLRequest(url: refreshURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "grant_type": "refresh_token",
            "client_id": refreshClientID,
            "refresh_token": refreshToken,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { return nil }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
                throw ClaudeUsageError.missingAccessToken
            }
            return nil
        }

        guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        if (payload["shouldLogout"] as? Bool) == true {
            throw ClaudeUsageError.missingAccessToken
        }

        guard let refreshed = normalized(payload["access_token"] as? String) else {
            return nil
        }

        switch source {
        case .sqlite:
            writeSQLiteValue(key: "cursorAuth/accessToken", value: refreshed)
        case .keychain:
            writeKeychain(service: "cursor-access-token", value: refreshed)
        case .environment:
            break
        }

        return refreshed
    }

    private static func connectPost(url: URL, accessToken: String) async throws -> (statusCode: Int, data: Data) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.httpBody = Data("{}".utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeUsageError.invalidResponse
        }
        return (httpResponse.statusCode, data)
    }

    private static func needsRefresh(_ accessToken: String?) -> Bool {
        guard let accessToken, let exp = jwtExpiration(accessToken) else {
            return true
        }
        let buffer: TimeInterval = 5 * 60
        return Date().addingTimeInterval(buffer).timeIntervalSince1970 >= exp
    }

    private static func jwtExpiration(_ token: String) -> TimeInterval? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        let payloadPart = String(parts[1])

        var base64 = payloadPart
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = base64.count % 4
        if remainder != 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: base64),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = payload["exp"] as? NSNumber
        else {
            return nil
        }

        return exp.doubleValue
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

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
