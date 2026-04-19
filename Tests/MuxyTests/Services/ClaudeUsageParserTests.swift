import Foundation
import Testing

@testable import Muxy

@Suite("ClaudeUsageParser")
struct ClaudeUsageParserTests {
    @Test("parses known usage windows into metric rows")
    func parseKnownWindows() throws {
        let json = """
        {
          "five_hour": {
            "used": 20,
            "limit": 100,
            "reset_at": 1735779600
          },
          "seven_day": {
            "used": 140,
            "limit": 200,
            "reset_at": "2026-04-20T12:00:00.000Z"
          },
          "seven_day_opus": {
            "used": 30,
            "limit": 60,
            "reset_at": 1735783200000
          }
        }
        """

        let rows = try ClaudeUsageParser.parseMetricRows(from: Data(json.utf8))

        #expect(rows.count == 3)
        #expect(rows[0].label == "5h")
        #expect(rows[1].label == "7d")
        #expect(rows[2].label == "7d Opus")

        #expect(rows[0].percent == 20)
        #expect(rows[1].percent == 70)
        #expect(rows[2].percent == 50)

        #expect(rows[0].detail == "20.0/100")
        #expect(rows[1].detail == "140/200")
        #expect(rows[2].detail == "30.0/60.0")

        #expect(rows[0].resetDate != nil)
        #expect(rows[1].resetDate != nil)
        #expect(rows[2].resetDate != nil)
    }
}
