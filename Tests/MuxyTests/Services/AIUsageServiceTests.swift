import Foundation
import Testing

@testable import Muxy

@Suite("AIUsageService")
struct AIUsageServiceTests {
    @Test("tracked provider defaults to false when unset and persists updates")
    func trackedProviderPersistence() {
        let suiteName = "AIUsageServiceTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let providerID = "claude"

        #expect(!AIUsageProviderTrackingStore.isTracked(providerID: providerID, defaults: defaults))
        #expect(!AIUsageProviderTrackingStore.hasTrackedPreference(providerID: providerID, defaults: defaults))

        AIUsageProviderTrackingStore.setTracked(false, providerID: providerID, defaults: defaults)
        #expect(!AIUsageProviderTrackingStore.isTracked(providerID: providerID, defaults: defaults))
        #expect(AIUsageProviderTrackingStore.hasTrackedPreference(providerID: providerID, defaults: defaults))

        AIUsageProviderTrackingStore.setTracked(true, providerID: providerID, defaults: defaults)
        #expect(AIUsageProviderTrackingStore.isTracked(providerID: providerID, defaults: defaults))
        #expect(AIUsageProviderTrackingStore.hasTrackedPreference(providerID: providerID, defaults: defaults))
    }

    @Test("auto-track enables providers with available usage when no explicit tracking preference exists")
    func autoTrackAvailableUsageWhenUnset() {
        let suiteName = "AIUsageServiceTests.AutoTrackAvailable.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let providerID = "cursor"
        #expect(!AIUsageProviderTrackingStore.hasTrackedPreference(providerID: providerID, defaults: defaults))

        let snapshots = [
            AIProviderUsageSnapshot(
                providerID: providerID,
                providerName: "Cursor",
                providerIconName: "sparkles",
                state: .available,
                rows: [AIUsageMetricRow(label: "Monthly", percent: 45, resetDate: nil, detail: "45/100")]
            ),
        ]

        AIUsageAutoTracking.autoTrackProvidersWithAvailableUsage(snapshots: snapshots, defaults: defaults)

        #expect(AIUsageProviderTrackingStore.hasTrackedPreference(providerID: providerID, defaults: defaults))
        #expect(AIUsageProviderTrackingStore.isTracked(providerID: providerID, defaults: defaults))
    }

    @Test("explicit false tracking preference is not overridden by auto-track")
    func autoTrackDoesNotOverrideExplicitFalse() {
        let suiteName = "AIUsageServiceTests.AutoTrackExplicitFalse.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let providerID = "cursor"
        AIUsageProviderTrackingStore.setTracked(false, providerID: providerID, defaults: defaults)

        let snapshots = [
            AIProviderUsageSnapshot(
                providerID: providerID,
                providerName: "Cursor",
                providerIconName: "sparkles",
                state: .available,
                rows: [AIUsageMetricRow(label: "Monthly", percent: 80, resetDate: nil, detail: "80/100")]
            ),
        ]

        AIUsageAutoTracking.autoTrackProvidersWithAvailableUsage(snapshots: snapshots, defaults: defaults)

        #expect(AIUsageProviderTrackingStore.hasTrackedPreference(providerID: providerID, defaults: defaults))
        #expect(!AIUsageProviderTrackingStore.isTracked(providerID: providerID, defaults: defaults))
    }

    @Test("non-native enabled defaults to true and persists updates")
    func nonNativeEnabledPersistence() {
        let suiteName = "AIUsageServiceTests.NonNativeEnabled.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let providerID = "cursor"

        #expect(AIUsageProviderEnabledStore.isEnabled(providerID: providerID, defaults: defaults))

        AIUsageProviderEnabledStore.setEnabled(false, providerID: providerID, defaults: defaults)
        #expect(!AIUsageProviderEnabledStore.isEnabled(providerID: providerID, defaults: defaults))

        AIUsageProviderEnabledStore.setEnabled(true, providerID: providerID, defaults: defaults)
        #expect(AIUsageProviderEnabledStore.isEnabled(providerID: providerID, defaults: defaults))
    }

    @Test("auto refresh interval defaults to 5 minutes and persists updates")
    func autoRefreshIntervalPersistence() {
        let suiteName = "AIUsageServiceTests.AutoRefreshInterval.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(AIUsageSettingsStore.autoRefreshInterval(defaults: defaults) == .fiveMinutes)

        AIUsageSettingsStore.setAutoRefreshInterval(.fifteenMinutes, defaults: defaults)
        #expect(AIUsageSettingsStore.autoRefreshInterval(defaults: defaults) == .fifteenMinutes)

        AIUsageSettingsStore.setAutoRefreshInterval(.thirtyMinutes, defaults: defaults)
        #expect(AIUsageSettingsStore.autoRefreshInterval(defaults: defaults) == .thirtyMinutes)

        AIUsageSettingsStore.setAutoRefreshInterval(.oneHour, defaults: defaults)
        #expect(AIUsageSettingsStore.autoRefreshInterval(defaults: defaults) == .oneHour)
    }

    @Test("auto refresh interval has expected options labels and raw values")
    func autoRefreshIntervalOptions() {
        #expect(AIUsageAutoRefreshInterval.allCases == [.fiveMinutes, .fifteenMinutes, .thirtyMinutes, .oneHour])
        #expect(AIUsageAutoRefreshInterval.fiveMinutes.rawValue == 300)
        #expect(AIUsageAutoRefreshInterval.fifteenMinutes.rawValue == 900)
        #expect(AIUsageAutoRefreshInterval.thirtyMinutes.rawValue == 1800)
        #expect(AIUsageAutoRefreshInterval.oneHour.rawValue == 3600)

        #expect(AIUsageAutoRefreshInterval.fiveMinutes.label == "5 min")
        #expect(AIUsageAutoRefreshInterval.fifteenMinutes.label == "15 min")
        #expect(AIUsageAutoRefreshInterval.thirtyMinutes.label == "30 min")
        #expect(AIUsageAutoRefreshInterval.oneHour.label == "1h")
    }



    @Test("tracking preferences canonicalize legacy provider IDs")
    func trackingCanonicalizesLegacyProviderIDs() {
        let suiteName = "AIUsageServiceTests.CanonicalTracking.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        AIUsageProviderTrackingStore.setTracked(true, providerID: "claude_code", defaults: defaults)

        #expect(AIUsageProviderTrackingStore.isTracked(providerID: "claude", defaults: defaults))
        #expect(AIUsageProviderTrackingStore.hasTrackedPreference(providerID: "claude", defaults: defaults))
    }

    @Test("snapshot merger deduplicates canonical provider IDs")
    func snapshotMergerDeduplicatesCanonicalProviderIDs() {
        let nativeSnapshots = [
            AIProviderUsageSnapshot(
                providerID: "claude",
                providerName: "Claude",
                providerIconName: "sparkles",
                state: .available,
                rows: [AIUsageMetricRow(label: "5h", percent: 25, resetDate: nil, detail: "25/100")]
            ),
        ]

        let openUsageSnapshots = [
            AIProviderUsageSnapshot(
                providerID: "claude_code",
                providerName: "Claude Code",
                providerIconName: "sparkles",
                state: .available,
                rows: [AIUsageMetricRow(label: "Monthly", percent: 50, resetDate: nil, detail: "50/100")]
            ),
        ]

        let merged = AIUsageSnapshotMerger.merge(
            nativeSnapshots: nativeSnapshots,
            openUsageSnapshots: openUsageSnapshots
        )

        #expect(merged.count == 1)
        #expect(merged[0].providerID == "claude")
    }


    @Test("compose snapshots includes tracked disabled non-native providers with Disabled state")
    func composeSnapshotsIncludesDisabledNonNativeProviderState() {
        let trackedProviders = [
            AITrackedProviderUsageDescriptor(
                providerID: "cursor",
                providerName: "Cursor",
                providerIconName: "sparkles",
                isEnabled: false
            ),
            AITrackedProviderUsageDescriptor(
                providerID: "opencode",
                providerName: "OpenCode",
                providerIconName: "sparkles",
                isEnabled: true
            ),
        ]

        let fetchedSnapshots = [
            AIProviderUsageSnapshot(
                providerID: "opencode",
                providerName: "OpenCode",
                providerIconName: "sparkles",
                state: .available,
                rows: []
            ),
        ]

        let composed = AIUsageSnapshotComposer.compose(
            trackedProviders: trackedProviders,
            fetchedSnapshots: fetchedSnapshots
        )

        #expect(composed.count == 2)
        #expect(composed[0].providerID == "cursor")
        #expect(composed[1].providerID == "opencode")
        #expect(composed[1].state == .available)

        if case let .unavailable(message) = composed[0].state {
            #expect(message == "Disabled")
        } else {
            Issue.record("Expected disabled provider to map to unavailable Disabled state")
        }
    }

    @Test("OpenUsage snapshot mapping supports progress, text, and badge lines")
    func openUsageSnapshotMapping() throws {
        let payload = """
        [
          {
            "provider": "cursor",
            "providerName": "Cursor",
            "lines": [
              {
                "type": "progress",
                "label": "Monthly",
                "used": 48,
                "limit": 100,
                "resetsAt": "2026-05-01T00:00:00Z"
              },
              {
                "type": "text",
                "label": "Plan",
                "value": "Pro"
              },
              {
                "type": "badge",
                "label": "Status",
                "subtitle": "Healthy"
              }
            ]
          }
        ]
        """

        let data = try #require(payload.data(using: .utf8))
        let catalogByProviderID: [String: AIUsageProviderCatalogEntry] = [
            "cursor": AIUsageProviderCatalogEntry(
                id: "cursor",
                displayName: "Cursor",
                iconName: "sparkles",
                source: .openUsage
            ),
        ]

        let snapshots = try OpenUsageAPIClient.parseSnapshots(
            from: data,
            catalogByProviderID: catalogByProviderID
        )

        #expect(snapshots.count == 1)
        let snapshot = try #require(snapshots.first)
        #expect(snapshot.providerID == "cursor")
        #expect(snapshot.state == .available)
        #expect(snapshot.rows.count == 3)

        let progressRow = snapshot.rows[0]
        #expect(progressRow.label == "Monthly")
        #expect(progressRow.percent == 48)
        #expect(progressRow.detail == "48/100")
        #expect(progressRow.resetDate != nil)

        let textRow = snapshot.rows[1]
        #expect(textRow.label == "Plan")
        #expect(textRow.percent == nil)
        #expect(textRow.detail == "Pro")

        let badgeRow = snapshot.rows[2]
        #expect(badgeRow.label == "Status")
        #expect(badgeRow.percent == nil)
        #expect(badgeRow.detail == "Healthy")
    }
}
