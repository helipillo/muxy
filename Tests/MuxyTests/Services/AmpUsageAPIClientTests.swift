import Foundation
import Testing

@testable import Muxy

@Suite("AmpUsageAPIClient")
struct AmpUsageAPIClientTests {
    @Test("reads token from env")
    func readTokenFromEnv() throws {
        let token = try AmpUsageAPIClient.readToken(env: ["AMP_API_KEY": "amp_token"])
        #expect(token == "amp_token")
    }
}
