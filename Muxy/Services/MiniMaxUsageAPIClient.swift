import Foundation

enum MiniMaxRegion {
    case global
    case cn
}

enum MiniMaxUsageClientError: Error {
    case missingAPIKey
    case sessionExpired
    case httpStatus(Int)
    case networkFailure
    case parseFailure
    case noUsageData
    case apiError(String)
}

enum MiniMaxUsageAPIClient {
    private static let globalEndpoints: [URL] = [
        URL(string: "https://api.minimax.io/v1/api/openplatform/coding_plan/remains")!,
        URL(string: "https://api.minimax.io/v1/coding_plan/remains")!,
        URL(string: "https://www.minimax.io/v1/api/openplatform/coding_plan/remains")!,
    ]

    private static let cnEndpoints: [URL] = [
        URL(string: "https://api.minimaxi.com/v1/api/openplatform/coding_plan/remains")!,
        URL(string: "https://api.minimaxi.com/v1/coding_plan/remains")!,
    ]

    static func fetchSnapshot(for provider: AIProviderUsageDescriptor) async -> AIProviderUsageSnapshot {
        do {
            let credentials = try readCredentials()
            let regionAttempts = buildRegionAttempts(credentials: credentials)
            guard !regionAttempts.isEmpty else {
                throw MiniMaxUsageClientError.missingAPIKey
            }

            var firstError: Error?

            for regionAttempt in regionAttempts {
                do {
                    let rows = try await fetchRows(for: regionAttempt)
                    guard !rows.isEmpty else {
                        if firstError == nil {
                            firstError = MiniMaxUsageClientError.noUsageData
                        }
                        continue
                    }

                    return AIProviderUsageSnapshot(
                        providerID: provider.providerID,
                        providerName: provider.providerName,
                        providerIconName: provider.providerIconName,
                        state: .available,
                        rows: rows
                    )
                } catch {
                    if firstError == nil {
                        firstError = error
                    }
                }
            }

            return snapshot(for: provider, error: firstError ?? MiniMaxUsageClientError.noUsageData)
        } catch {
            return snapshot(for: provider, error: error)
        }
    }

    static func readToken(env: [String: String] = ProcessInfo.processInfo.environment) throws -> String {
        let credentials = try readCredentials(env: env)
        if let token = token(for: preferredRegion(env: credentials.environment), credentials: credentials) {
            return token
        }
        throw MiniMaxUsageClientError.missingAPIKey
    }

    private static func fetchRows(for attempt: (region: MiniMaxRegion, token: String)) async throws -> [AIUsageMetricRow] {
        var hadNetworkError = false
        var authStatusCount = 0
        var lastStatusCode: Int?
        var parsedEmpty = false

        for endpoint in endpoints(for: attempt.region) {
            do {
                var request = URLRequest(url: endpoint)
                request.httpMethod = "GET"
                request.setValue("Bearer \(attempt.token)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    continue
                }

                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    authStatusCount += 1
                    continue
                }

                guard (200 ..< 300).contains(httpResponse.statusCode) else {
                    lastStatusCode = httpResponse.statusCode
                    continue
                }

                do {
                    let rows = try MiniMaxUsageParser.parseMetricRows(from: data, region: attempt.region)
                    if !rows.isEmpty {
                        return rows
                    }
                    parsedEmpty = true
                    continue
                } catch let parserError as MiniMaxUsageParserError {
                    switch parserError {
                    case .authError:
                        throw MiniMaxUsageClientError.sessionExpired
                    case let .apiError(message):
                        throw MiniMaxUsageClientError.apiError(message)
                    case .invalidPayload:
                        continue
                    }
                }
            } catch let nsError as NSError where nsError.domain == NSURLErrorDomain {
                hadNetworkError = true
                continue
            }
        }

        if authStatusCount > 0, lastStatusCode == nil, !hadNetworkError {
            throw MiniMaxUsageClientError.sessionExpired
        }
        if let lastStatusCode {
            throw MiniMaxUsageClientError.httpStatus(lastStatusCode)
        }
        if hadNetworkError {
            throw MiniMaxUsageClientError.networkFailure
        }
        if parsedEmpty {
            throw MiniMaxUsageClientError.noUsageData
        }
        throw MiniMaxUsageClientError.parseFailure
    }

    private static func snapshot(for provider: AIProviderUsageDescriptor, error: Error) -> AIProviderUsageSnapshot {
        switch error {
        case MiniMaxUsageClientError.missingAPIKey:
            return AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .unavailable(message: "MiniMax API key missing. Set MINIMAX_API_KEY or MINIMAX_CN_API_KEY."),
                rows: []
            )
        case MiniMaxUsageClientError.sessionExpired:
            return AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .unavailable(message: "Session expired. Check your MiniMax API key."),
                rows: []
            )
        case let MiniMaxUsageClientError.httpStatus(statusCode):
            usageLogger.error("MiniMax usage request failed with status \(statusCode)")
            return AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .error(message: "Request failed (HTTP \(statusCode)). Try again later."),
                rows: []
            )
        case MiniMaxUsageClientError.networkFailure:
            return AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .error(message: "Request failed. Check your connection."),
                rows: []
            )
        case MiniMaxUsageClientError.parseFailure:
            return AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .error(message: "Could not parse usage data."),
                rows: []
            )
        case MiniMaxUsageClientError.noUsageData:
            return AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .unavailable(message: "No usage data"),
                rows: []
            )
        case let MiniMaxUsageClientError.apiError(message):
            return AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .error(message: "MiniMax API error: \(message)"),
                rows: []
            )
        case let parserError as MiniMaxUsageParserError:
            switch parserError {
            case let .apiError(message):
                return snapshot(for: provider, error: MiniMaxUsageClientError.apiError(message))
            case .authError:
                return snapshot(for: provider, error: MiniMaxUsageClientError.sessionExpired)
            case .invalidPayload:
                return snapshot(for: provider, error: MiniMaxUsageClientError.parseFailure)
            }
        case let nsError as NSError where nsError.domain == NSURLErrorDomain:
            return snapshot(for: provider, error: MiniMaxUsageClientError.networkFailure)
        default:
            usageLogger.error("MiniMax usage request failed: \(error.localizedDescription)")
            return AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .error(message: "Unable to fetch usage"),
                rows: []
            )
        }
    }

    private static func readCredentials(
        env: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> (environment: [String: String], fallbackToken: String?) {
        let fallbackToken = readFallbackTokenFromDisk()

        let hasAnyEnvironmentToken = [
            normalizedToken(env["MINIMAX_CN_API_KEY"]),
            normalizedToken(env["MINIMAX_API_KEY"]),
            normalizedToken(env["MINIMAX_API_TOKEN"]),
        ].contains { $0 != nil }

        if hasAnyEnvironmentToken || fallbackToken != nil {
            return (env, fallbackToken)
        }

        throw MiniMaxUsageClientError.missingAPIKey
    }

    private static func readFallbackTokenFromDisk() -> String? {
        let home = NSHomeDirectory()
        let candidatePaths = [
            "\(home)/.mmx/config.json",
            "\(home)/.mmx/credentials.json",
        ]

        for path in candidatePaths where FileManager.default.fileExists(atPath: path) {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

                if let token = AIUsageParserSupport.string(in: payload, keys: ["api_key", "apiKey", "token", "access_token"]), !token.isEmpty {
                    return token
                }

                if let auth = payload["auth"] as? [String: Any],
                   let token = AIUsageParserSupport.string(in: auth, keys: ["api_key", "apiKey", "token", "access_token"]),
                   !token.isEmpty
                {
                    return token
                }
            } catch {
                continue
            }
        }

        return nil
    }

    private static func normalizedToken(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func preferredRegion(env: [String: String]) -> MiniMaxRegion {
        normalizedToken(env["MINIMAX_CN_API_KEY"]) != nil ? .cn : .global
    }

    private static func regionOrder(env: [String: String]) -> [MiniMaxRegion] {
        preferredRegion(env: env) == .cn ? [.cn, .global] : [.global, .cn]
    }

    private static func token(
        for region: MiniMaxRegion,
        credentials: (environment: [String: String], fallbackToken: String?)
    ) -> String? {
        let env = credentials.environment

        switch region {
        case .global:
            return normalizedToken(env["MINIMAX_API_KEY"])
                ?? normalizedToken(env["MINIMAX_API_TOKEN"])
                ?? credentials.fallbackToken
        case .cn:
            return normalizedToken(env["MINIMAX_CN_API_KEY"])
                ?? normalizedToken(env["MINIMAX_API_KEY"])
                ?? normalizedToken(env["MINIMAX_API_TOKEN"])
                ?? credentials.fallbackToken
        }
    }

    private static func endpoints(for region: MiniMaxRegion) -> [URL] {
        switch region {
        case .global:
            return globalEndpoints
        case .cn:
            return cnEndpoints
        }
    }

    private static func buildRegionAttempts(
        credentials: (environment: [String: String], fallbackToken: String?)
    ) -> [(region: MiniMaxRegion, token: String)] {
        regionOrder(env: credentials.environment).compactMap { region in
            guard let token = token(for: region, credentials: credentials) else { return nil }
            return (region: region, token: token)
        }
    }
}
