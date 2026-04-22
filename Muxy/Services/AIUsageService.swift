import Foundation
import os

let usageLogger = Logger(subsystem: "app.muxy", category: "AIUsageService")

private func canonicalAIUsageProviderID(_ providerID: String) -> String {
    let normalized = providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    switch normalized {
    case "claude_code":
        return "claude"
    default:
        return normalized
    }
}

struct AIProviderUsageDescriptor {
    let providerID: String
    let providerName: String
    let providerIconName: String
}

struct AITrackedProviderUsageDescriptor: Equatable {
    let providerID: String
    let providerName: String
    let providerIconName: String
    let isEnabled: Bool
}

enum AIUsageProviderTrackingStore {
    static func trackingKey(providerID: String) -> String {
        "muxy.usage.provider.\(canonicalAIUsageProviderID(providerID)).tracked"
    }

    static func trackedPreference(providerID: String, defaults: UserDefaults = .standard) -> Bool? {
        let key = trackingKey(providerID: providerID)
        guard defaults.object(forKey: key) != nil else { return nil }
        return defaults.bool(forKey: key)
    }

    static func hasTrackedPreference(providerID: String, defaults: UserDefaults = .standard) -> Bool {
        trackedPreference(providerID: providerID, defaults: defaults) != nil
    }

    static func isTracked(providerID: String, defaults: UserDefaults = .standard) -> Bool {
        trackedPreference(providerID: providerID, defaults: defaults) ?? false
    }

    static func setTracked(_ tracked: Bool, providerID: String, defaults: UserDefaults = .standard) {
        defaults.set(tracked, forKey: trackingKey(providerID: providerID))
    }
}

enum AIUsageAutoTracking {
    static func autoTrackProvidersWithAvailableUsage(
        snapshots: [AIProviderUsageSnapshot],
        defaults: UserDefaults = .standard
    ) {
        for snapshot in snapshots where hasAvailableUsage(snapshot) {
            if !AIUsageProviderTrackingStore.hasTrackedPreference(providerID: snapshot.providerID, defaults: defaults) {
                AIUsageProviderTrackingStore.setTracked(true, providerID: snapshot.providerID, defaults: defaults)
            }
        }
    }

    private static func hasAvailableUsage(_ snapshot: AIProviderUsageSnapshot) -> Bool {
        guard case .available = snapshot.state else { return false }
        return !snapshot.rows.isEmpty
    }
}

enum AIUsageProviderEnabledStore {
    static func enabledKey(providerID: String) -> String {
        "muxy.usage.provider.\(canonicalAIUsageProviderID(providerID)).enabled"
    }

    static func isEnabled(providerID: String, defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: enabledKey(providerID: providerID), fallback: true)
    }

    static func setEnabled(_ enabled: Bool, providerID: String, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: enabledKey(providerID: providerID))
    }
}

enum AIUsageDisplayMode: String, CaseIterable, Identifiable {
    case used
    case remaining

    var id: String { rawValue }

    var label: String {
        switch self {
        case .used:
            "Used"
        case .remaining:
            "Remaining"
        }
    }
}

enum AIUsageSettingsStore {
    static let autoRefreshIntervalKey = "muxy.usage.autoRefreshIntervalSeconds"
    static let usageDisplayModeKey = "muxy.usage.displayMode"

    static let defaultAutoRefreshInterval: AIUsageAutoRefreshInterval = .fiveMinutes
    static let defaultUsageDisplayMode: AIUsageDisplayMode = .used

    static func autoRefreshInterval(defaults: UserDefaults = .standard) -> AIUsageAutoRefreshInterval {
        guard defaults.object(forKey: autoRefreshIntervalKey) != nil else {
            return defaultAutoRefreshInterval
        }

        let rawValue = defaults.integer(forKey: autoRefreshIntervalKey)
        return AIUsageAutoRefreshInterval(rawValue: rawValue) ?? defaultAutoRefreshInterval
    }

    static func setAutoRefreshInterval(_ interval: AIUsageAutoRefreshInterval, defaults: UserDefaults = .standard) {
        defaults.set(interval.rawValue, forKey: autoRefreshIntervalKey)
    }

    static func usageDisplayMode(defaults: UserDefaults = .standard) -> AIUsageDisplayMode {
        guard let raw = defaults.string(forKey: usageDisplayModeKey),
              let mode = AIUsageDisplayMode(rawValue: raw)
        else {
            return defaultUsageDisplayMode
        }
        return mode
    }

    static func setUsageDisplayMode(_ mode: AIUsageDisplayMode, defaults: UserDefaults = .standard) {
        defaults.set(mode.rawValue, forKey: usageDisplayModeKey)
    }
}

enum AIUsageAutoRefreshInterval: Int, CaseIterable, Identifiable {
    case fiveMinutes = 300
    case fifteenMinutes = 900
    case thirtyMinutes = 1800
    case oneHour = 3600

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .fiveMinutes:
            "5 min"
        case .fifteenMinutes:
            "15 min"
        case .thirtyMinutes:
            "30 min"
        case .oneHour:
            "1h"
        }
    }

    var timeInterval: TimeInterval {
        TimeInterval(rawValue)
    }
}

enum AIUsageProviderCatalogSource {
    case notificationIntegration
    case bundled
}

struct AIUsageProviderCatalogEntry: Identifiable, Equatable {
    let id: String
    let displayName: String
    let iconName: String
    let source: AIUsageProviderCatalogSource

    var hasNotificationIntegration: Bool { source == .notificationIntegration }
    var isBundled: Bool { source == .bundled }
}

@MainActor
enum AIUsageProviderCatalog {
    static let providers: [AIUsageProviderCatalogEntry] = {
        let notificationProviders = AIProviderRegistry.shared.providers.map {
            AIUsageProviderCatalogEntry(
                id: canonicalAIUsageProviderID($0.id),
                displayName: $0.displayName,
                iconName: $0.iconName,
                source: .notificationIntegration
            )
        }

        var byID = Dictionary(uniqueKeysWithValues: notificationProviders.map { ($0.id, $0) })
        for provider in bundledSeedProviders where byID[provider.id] == nil {
            byID[provider.id] = provider
        }

        let notificationProviderIDs = Set(notificationProviders.map(\.id))
        return byID.values.sorted { lhs, rhs in
            let lhsIntegrated = notificationProviderIDs.contains(lhs.id)
            let rhsIntegrated = notificationProviderIDs.contains(rhs.id)
            if lhsIntegrated != rhsIntegrated {
                return lhsIntegrated
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }()

    private static let providerByID: [String: AIUsageProviderCatalogEntry] =
        Dictionary(uniqueKeysWithValues: providers.map { (canonicalAIUsageProviderID($0.id), $0) })

    private static let notificationProviderByID: [String: any AIProviderIntegration] =
        Dictionary(uniqueKeysWithValues: AIProviderRegistry.shared.providers.map { (canonicalAIUsageProviderID($0.id), $0) })

    static func entry(providerID: String) -> AIUsageProviderCatalogEntry? {
        providerByID[canonicalAIUsageProviderID(providerID)]
    }

    static func notificationProvider(providerID: String) -> (any AIProviderIntegration)? {
        notificationProviderByID[canonicalAIUsageProviderID(providerID)]
    }

    private static let bundledSeedProviders: [AIUsageProviderCatalogEntry] = [
        .init(id: "codex", displayName: "Codex", iconName: "sparkles", source: .bundled),
        .init(id: "copilot", displayName: "Copilot", iconName: "sparkles", source: .bundled),
        .init(id: "cursor", displayName: "Cursor", iconName: "sparkles", source: .bundled),
        .init(id: "gemini", displayName: "Gemini", iconName: "sparkles", source: .bundled),
        .init(id: "minimax", displayName: "MiniMax", iconName: "sparkles", source: .bundled),
        .init(id: "opencode-go", displayName: "OpenCode Go", iconName: "sparkles", source: .bundled),
        .init(id: "windsurf", displayName: "Windsurf", iconName: "sparkles", source: .bundled),
        .init(id: "kimi", displayName: "Kimi", iconName: "sparkles", source: .bundled),
        .init(id: "kiro", displayName: "Kiro", iconName: "sparkles", source: .bundled),
        .init(id: "antigravity", displayName: "Antigravity", iconName: "sparkles", source: .bundled),
        .init(id: "amp", displayName: "Amp", iconName: "sparkles", source: .bundled),
        .init(id: "factory", displayName: "Factory", iconName: "sparkles", source: .bundled),
        .init(
            id: "jetbrains-ai-assistant",
            displayName: "JetBrains AI Assistant",
            iconName: "sparkles",
            source: .bundled
        ),
        .init(id: "zai", displayName: "Z.ai", iconName: "sparkles", source: .bundled),
        .init(id: "perplexity", displayName: "Perplexity", iconName: "sparkles", source: .bundled),
    ]

    static func canonicalID(for providerID: String) -> String {
        canonicalAIUsageProviderID(providerID)
    }
}

enum AIUsageSnapshotComposer {
    static func compose(
        trackedProviders: [AITrackedProviderUsageDescriptor],
        fetchedSnapshots: [AIProviderUsageSnapshot]
    ) -> [AIProviderUsageSnapshot] {
        let snapshotByProviderID = Dictionary(uniqueKeysWithValues: fetchedSnapshots
            .map { (canonicalAIUsageProviderID($0.providerID), $0) })

        return trackedProviders.map { provider in
            if !provider.isEnabled {
                return AIProviderUsageSnapshot(
                    providerID: provider.providerID,
                    providerName: provider.providerName,
                    providerIconName: provider.providerIconName,
                    state: .unavailable(message: "Disabled"),
                    rows: []
                )
            }

            if let snapshot = snapshotByProviderID[canonicalAIUsageProviderID(provider.providerID)] {
                return snapshot
            }

            return AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .unavailable(message: "Usage unavailable"),
                rows: []
            )
        }
    }
}

enum AIUsageSnapshotMerger {
    static func merge(
        nativeSnapshots: [AIProviderUsageSnapshot],
        openUsageSnapshots: [AIProviderUsageSnapshot]
    ) -> [AIProviderUsageSnapshot] {
        var byID = Dictionary(uniqueKeysWithValues: nativeSnapshots.map { (canonicalAIUsageProviderID($0.providerID), $0) })

        for snapshot in openUsageSnapshots {
            let key = canonicalAIUsageProviderID(snapshot.providerID)
            guard let existing = byID[key] else {
                byID[key] = snapshot
                continue
            }

            switch existing.state {
            case .available:
                continue
            case .unavailable, .error:
                byID[key] = snapshot
            }
        }

        return Array(byID.values)
    }
}

@MainActor
@Observable
final class AIUsageService {
    static let shared = AIUsageService()

    private(set) var snapshots: [AIProviderUsageSnapshot] = []
    private(set) var isRefreshing = false
    private(set) var lastRefreshDate: Date?

    var minimumRefreshInterval: TimeInterval {
        AIUsageSettingsStore.autoRefreshInterval().timeInterval
    }

    @ObservationIgnored private var refreshTask: Task<[AIProviderUsageSnapshot], Never>?
    @ObservationIgnored private var fetchedSnapshotsCache: [AIProviderUsageSnapshot] = []

    private init() {}

    private struct ProviderRuntimePreferences {
        let trackedProviderIDs: Set<String>
        let enabledByProviderID: [String: Bool]

        @MainActor
        init(catalogProviders: [AIUsageProviderCatalogEntry], defaults: UserDefaults = .standard) {
            var trackedProviderIDs: Set<String> = []
            trackedProviderIDs.reserveCapacity(catalogProviders.count)

            var enabledByProviderID: [String: Bool] = [:]
            enabledByProviderID.reserveCapacity(catalogProviders.count)

            for provider in catalogProviders {
                let providerID = provider.id

                if AIUsageProviderTrackingStore.trackedPreference(providerID: providerID, defaults: defaults) == true {
                    trackedProviderIDs.insert(providerID)
                }

                if provider.hasNotificationIntegration {
                    enabledByProviderID[providerID] = AIUsageProviderCatalog.notificationProvider(providerID: providerID)?.isEnabled ?? false
                } else {
                    enabledByProviderID[providerID] = AIUsageProviderEnabledStore.isEnabled(providerID: providerID, defaults: defaults)
                }
            }

            self.trackedProviderIDs = trackedProviderIDs
            self.enabledByProviderID = enabledByProviderID
        }
    }

    func refreshIfNeeded(force: Bool = false) async {
        if let refreshTask {
            _ = await refreshTask.value
            return
        }

        guard force || shouldRefresh(at: Date()) else { return }

        await refresh(force: true)
    }

    func refresh(force: Bool = false) async {
        if let refreshTask {
            _ = await refreshTask.value
            return
        }

        if !force, !shouldRefresh(at: Date()) {
            return
        }

        let catalogProviders = AIUsageProviderCatalog.providers
        let preferences = ProviderRuntimePreferences(catalogProviders: catalogProviders)

        let enabledProviderDescriptors = catalogProviders.compactMap { provider -> AIProviderUsageDescriptor? in
            guard preferences.enabledByProviderID[provider.id] == true else { return nil }
            return AIProviderUsageDescriptor(
                providerID: provider.id,
                providerName: provider.displayName,
                providerIconName: provider.iconName
            )
        }

        let nativeProviderDescriptors = enabledProviderDescriptors.filter {
            AIUsageFetcher.supportsNativeCollector(providerID: $0.providerID)
        }

        isRefreshing = true
        defer {
            isRefreshing = false
            refreshTask = nil
        }

        let task = Task { [nativeProviderDescriptors, enabledProviderDescriptors] in
            async let nativeSnapshots = AIUsageFetcher.fetchSnapshots(for: nativeProviderDescriptors)
            async let openUsageSnapshots = OpenUsageAPIClient.fetchSnapshots(for: enabledProviderDescriptors)

            let mergedSnapshots = AIUsageSnapshotMerger.merge(
                nativeSnapshots: await nativeSnapshots,
                openUsageSnapshots: await openUsageSnapshots
            )

            return mergedSnapshots
        }

        refreshTask = task
        let fetchedSnapshots = await task.value
        AIUsageAutoTracking.autoTrackProvidersWithAvailableUsage(snapshots: fetchedSnapshots)

        fetchedSnapshotsCache = fetchedSnapshots
        let composedSnapshots = composeSnapshots(
            catalogProviders: catalogProviders,
            fetchedSnapshots: fetchedSnapshots
        )

        if snapshots != composedSnapshots {
            snapshots = composedSnapshots
        }
        lastRefreshDate = Date()
    }

    private func shouldRefresh(at date: Date) -> Bool {
        guard let lastRefreshDate else { return true }

        let interval = AIUsageSettingsStore.autoRefreshInterval()
        return date.timeIntervalSince(lastRefreshDate) >= interval.timeInterval
    }

    func recomposeSnapshots() {
        let catalogProviders = AIUsageProviderCatalog.providers
        let recomposed = composeSnapshots(
            catalogProviders: catalogProviders,
            fetchedSnapshots: fetchedSnapshotsCache
        )
        if snapshots != recomposed {
            snapshots = recomposed
        }
    }

    private func composeSnapshots(
        catalogProviders: [AIUsageProviderCatalogEntry],
        fetchedSnapshots: [AIProviderUsageSnapshot]
    ) -> [AIProviderUsageSnapshot] {
        let updatedPreferences = ProviderRuntimePreferences(catalogProviders: catalogProviders)
        let trackedProviders = catalogProviders.compactMap { provider -> AITrackedProviderUsageDescriptor? in
            guard updatedPreferences.trackedProviderIDs.contains(provider.id) else { return nil }
            return AITrackedProviderUsageDescriptor(
                providerID: provider.id,
                providerName: provider.displayName,
                providerIconName: provider.iconName,
                isEnabled: updatedPreferences.enabledByProviderID[provider.id] ?? false
            )
        }

        return AIUsageSnapshotComposer.compose(
            trackedProviders: trackedProviders,
            fetchedSnapshots: fetchedSnapshots
        )
    }
}

enum AIUsageFetcher {
    static func supportsNativeCollector(providerID: String) -> Bool {
        switch canonicalAIUsageProviderID(providerID) {
        case "claude", "codex", "copilot", "minimax", "cursor", "amp", "zai":
            return true
        default:
            return false
        }
    }

    static func fetchSnapshots(for providers: [AIProviderUsageDescriptor]) async -> [AIProviderUsageSnapshot] {
        await withTaskGroup(of: (Int, AIProviderUsageSnapshot).self) { group in
            for (index, provider) in providers.enumerated() {
                group.addTask {
                    await (index, fetchSnapshot(for: provider))
                }
            }

            var indexedSnapshots: [(Int, AIProviderUsageSnapshot)] = []
            indexedSnapshots.reserveCapacity(providers.count)

            for await indexed in group {
                indexedSnapshots.append(indexed)
            }

            return indexedSnapshots
                .sorted { $0.0 < $1.0 }
                .map(\.1)
        }
    }

    private static func fetchSnapshot(for provider: AIProviderUsageDescriptor) async -> AIProviderUsageSnapshot {
        switch provider.providerID {
        case "claude":
            await ClaudeUsageAPIClient.fetchSnapshot(for: provider)
        case "codex":
            await CodexUsageAPIClient.fetchSnapshot(for: provider)
        case "copilot":
            await CopilotUsageAPIClient.fetchSnapshot(for: provider)
        case "minimax":
            await MiniMaxUsageAPIClient.fetchSnapshot(for: provider)
        case "cursor":
            await CursorUsageAPIClient.fetchSnapshot(for: provider)
        case "amp":
            await AmpUsageAPIClient.fetchSnapshot(for: provider)
        case "zai":
            await ZaiUsageAPIClient.fetchSnapshot(for: provider)
        case "opencode":
            AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .unavailable(message: "Usage unavailable"),
                rows: []
            )
        case "gemini", "opencode-go", "windsurf", "kimi", "kiro", "antigravity", "factory", "jetbrains-ai-assistant", "perplexity":
            AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .unavailable(message: "Native usage collector not implemented yet"),
                rows: []
            )
        default:
            AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .unavailable(message: "Unsupported provider"),
                rows: []
            )
        }
    }
}

enum OpenUsageAPIClient {
    private static let endpointURL = URL(string: "http://127.0.0.1:6736/v1/usage")!
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 1.5
        configuration.timeoutIntervalForResource = 2
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    static func fetchSnapshots(for providers: [AIProviderUsageDescriptor]) async -> [AIProviderUsageSnapshot] {
        do {
            var request = URLRequest(url: endpointURL)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 1.5

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return []
            }
            guard (200 ..< 300).contains(httpResponse.statusCode) else {
                usageLogger.info("OpenUsage bridge returned status \(httpResponse.statusCode)")
                return []
            }

            return try parseSnapshots(from: data, providers: providers)
        } catch {
            return []
        }
    }

    private static func parseSnapshots(
        from data: Data,
        providers: [AIProviderUsageDescriptor]
    ) throws -> [AIProviderUsageSnapshot] {
        guard let rawSnapshots = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        let providerByID = Dictionary(uniqueKeysWithValues: providers.map { (canonicalAIUsageProviderID($0.providerID), $0) })

        return rawSnapshots.compactMap { rawSnapshot in
            guard let providerID = extractString(from: rawSnapshot, keys: ["providerId", "provider_id", "provider", "id"]),
                  !providerID.isEmpty
            else {
                return nil
            }

            let canonicalProviderID = canonicalAIUsageProviderID(providerID)
            let providerInfo = providerByID[canonicalProviderID]

            let providerName = providerInfo?.providerName
                ?? extractString(from: rawSnapshot, keys: ["displayName", "providerName", "provider_name", "name", "title"])
                ?? providerID
            let providerIcon = providerInfo?.providerIconName ?? "sparkles"

            let rawLines = extractArray(from: rawSnapshot, keys: ["lines", "rows", "metrics", "usage"])
            let rows = rawLines.compactMap { mapMetricRow(from: $0) }

            let state: AIProviderUsageState = rows.isEmpty
                ? .unavailable(message: "No usage data")
                : .available

            return AIProviderUsageSnapshot(
                providerID: canonicalProviderID,
                providerName: providerName,
                providerIconName: providerIcon,
                state: state,
                rows: rows
            )
        }
    }

    private static func mapMetricRow(from rawLine: [String: Any]) -> AIUsageMetricRow? {
        let lineType = (extractString(from: rawLine, keys: ["type", "kind", "lineType"]) ?? "text")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let label = extractString(from: rawLine, keys: ["label", "name", "title"]) ?? "Usage"
        let resetDate = extractDate(from: rawLine, keys: ["resetsAt", "resetAt", "resetDate"])

        if lineType == "progress" || (extractDouble(from: rawLine, keys: ["used"]) != nil && extractDouble(from: rawLine, keys: ["limit"]) != nil) {
            let used = extractDouble(from: rawLine, keys: ["used", "current", "value"])
            let limit = extractDouble(from: rawLine, keys: ["limit", "max", "total"])

            let percent: Double?
            if let used, let limit, limit > 0 {
                percent = max(0, min(100, (used / limit) * 100))
            } else {
                percent = nil
            }

            let detail: String?
            if let used, let limit {
                detail = "\(formatUsageNumber(used))/\(formatUsageNumber(limit))"
            } else {
                detail = nil
            }

            return AIUsageMetricRow(label: label, percent: percent, resetDate: resetDate, detail: detail)
        }

        let detail = extractString(from: rawLine, keys: ["value", "detail", "text", "subtitle"])
        return AIUsageMetricRow(label: label, percent: nil, resetDate: resetDate, detail: detail)
    }

    private static func extractString(from object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            guard let value = object[key] else { continue }
            if let string = value as? String {
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            } else if let number = value as? NSNumber {
                return number.stringValue
            }
        }

        return nil
    }

    private static func extractDouble(from object: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            guard let value = object[key] else { continue }
            if let number = value as? NSNumber {
                return number.doubleValue
            }
            if let string = value as? String,
               let parsed = Double(string.trimmingCharacters(in: .whitespacesAndNewlines))
            {
                return parsed
            }
        }

        return nil
    }

    private static func extractArray(from object: [String: Any], keys: [String]) -> [[String: Any]] {
        for key in keys {
            if let array = object[key] as? [[String: Any]] {
                return array
            }
        }

        return []
    }

    private static func extractDate(from object: [String: Any], keys: [String]) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let standardFormatter = ISO8601DateFormatter()
        standardFormatter.formatOptions = [.withInternetDateTime]

        for key in keys {
            guard let value = object[key] else { continue }

            if let string = value as? String {
                if let parsed = fractionalFormatter.date(from: string)
                    ?? standardFormatter.date(from: string)
                {
                    return parsed
                }
            }

            if let number = value as? NSNumber {
                let raw = number.doubleValue
                let seconds = raw > 10_000_000_000 ? raw / 1_000 : raw
                return Date(timeIntervalSince1970: seconds)
            }
        }

        return nil
    }

    private static func formatUsageNumber(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(rounded - value) < 0.000_001 {
            return String(Int(rounded))
        }

        return String(format: "%.1f", value)
    }
}

enum ClaudeUsageAPIClient {
    private static let credentialsPath = NSHomeDirectory() + "/.claude/.credentials.json"
    private static let endpointURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    static func fetchSnapshot(for provider: AIProviderUsageDescriptor) async -> AIProviderUsageSnapshot {
        do {
            let token = try readAccessToken()

            var request = URLRequest(url: endpointURL)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClaudeUsageError.invalidResponse
            }
            guard (200 ..< 300).contains(httpResponse.statusCode) else {
                throw ClaudeUsageError.httpStatus(httpResponse.statusCode)
            }

            let rows = try ClaudeUsageParser.parseMetricRows(from: data)
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
                state: .unavailable(message: "Sign in to Claude"),
                rows: []
            )
        } catch let ClaudeUsageError.httpStatus(statusCode) {
            usageLogger.error("Claude usage request failed with status \(statusCode)")
            return AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .error(message: "Usage request failed"),
                rows: []
            )
        } catch {
            usageLogger.error("Claude usage request failed: \(error.localizedDescription)")
            return AIProviderUsageSnapshot(
                providerID: provider.providerID,
                providerName: provider.providerName,
                providerIconName: provider.providerIconName,
                state: .error(message: "Unable to fetch usage"),
                rows: []
            )
        }
    }

    private static func readAccessToken() throws -> String {
        guard FileManager.default.fileExists(atPath: credentialsPath) else {
            throw ClaudeUsageError.missingAccessToken
        }

        let fileURL = URL(fileURLWithPath: credentialsPath)
        let data = try Data(contentsOf: fileURL)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any],
              let accessToken = oauth["accessToken"] as? String
        else {
            throw ClaudeUsageError.missingAccessToken
        }

        let token = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw ClaudeUsageError.missingAccessToken
        }
        return token
    }
}

enum ClaudeUsageError: Error {
    case missingAccessToken
    case invalidResponse
    case httpStatus(Int)
}
