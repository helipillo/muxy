import Foundation
import Testing

@testable import Muxy

@Suite("CursorUsageParser")
struct CursorUsageParserTests {
    @Test("parses individual plan percent usage")
    func parsePercentUsage() throws {
        let usageJSON = """
        {
          "enabled": true,
          "billingCycleEnd": "1771077734000",
          "planUsage": {
            "totalPercentUsed": 42,
            "autoPercentUsed": 10,
            "apiPercentUsed": 20
          }
        }
        """

        let rows = try CursorUsageParser.parseMetricRows(
            usageData: Data(usageJSON.utf8),
            planData: nil
        )

        #expect(rows.first?.label == "Total usage")
        #expect(rows.first?.percent == 42)
        #expect(rows.contains { $0.label == "Auto usage" && $0.percent == 10 })
        #expect(rows.contains { $0.label == "API usage" && $0.percent == 20 })
    }

    @Test("parses team plan in dollars")
    func parseTeamUsage() throws {
        let usageJSON = """
        {
          "enabled": true,
          "billingCycleEnd": "1771077734000",
          "planUsage": {
            "totalSpend": 8474,
            "limit": 2000,
            "bonusSpend": 674
          },
          "spendLimitUsage": {
            "pooledLimit": 60000,
            "pooledRemaining": 19216
          }
        }
        """

        let planJSON = """
        {
          "planInfo": { "planName": "Team" }
        }
        """

        let rows = try CursorUsageParser.parseMetricRows(
            usageData: Data(usageJSON.utf8),
            planData: Data(planJSON.utf8)
        )

        #expect(rows.first?.label == "Total usage")
        #expect(rows.first?.detail == "84.7/20.0")
        #expect(rows.contains { $0.label == "Bonus spend" })
        #expect(rows.contains { $0.label == "On-demand" })
    }

    @Test("throws when subscription is disabled")
    func parseDisabled() throws {
        let usageJSON = """
        {
          "enabled": false,
          "planUsage": { "totalPercentUsed": 10 }
        }
        """

        do {
            _ = try CursorUsageParser.parseMetricRows(usageData: Data(usageJSON.utf8), planData: nil)
            Issue.record("Expected CursorUsageParserError.noActiveSubscription")
        } catch CursorUsageParserError.noActiveSubscription {
            // expected
        }
    }
}
