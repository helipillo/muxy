import Foundation
import Testing

@testable import Muxy

@Suite("ZaiUsageAPIClient")
struct ZaiUsageAPIClientTests {
    @Test("prefers ZAI_API_KEY over GLM_API_KEY")
    func readTokenPrefersZai() throws {
        let token = try ZaiUsageAPIClient.readToken(env: [
            "ZAI_API_KEY": "zai_primary",
            "GLM_API_KEY": "glm_fallback",
        ])

        #expect(token == "zai_primary")
    }

    @Test("falls back to GLM_API_KEY")
    func readTokenFallback() throws {
        let token = try ZaiUsageAPIClient.readToken(env: ["GLM_API_KEY": "glm_token"])
        #expect(token == "glm_token")
    }
}
