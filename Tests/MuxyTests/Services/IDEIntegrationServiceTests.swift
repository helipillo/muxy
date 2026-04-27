import Foundation
import Testing

@testable import Muxy

@Suite("IDEIntegrationService")
@MainActor
struct IDEIntegrationServiceTests {
    @Test("resolveDefaultIDE prefers remembered selection when installed")
    func resolveDefaultIDEPrefersRememberedSelection() {
        let vscode = IDEIntegrationService.IDEApplication(
            bundleIdentifier: "com.microsoft.VSCode",
            displayName: "VS Code",
            appURL: URL(fileURLWithPath: "/Applications/Visual Studio Code.app"),
            symbolName: "chevron.left.forwardslash.chevron.right"
        )
        let zed = IDEIntegrationService.IDEApplication(
            bundleIdentifier: "dev.zed.Zed",
            displayName: "Zed",
            appURL: URL(fileURLWithPath: "/Applications/Zed.app"),
            symbolName: "bolt.horizontal"
        )

        let resolved = IDEIntegrationService.resolveDefaultIDE(
            installedApps: [vscode, zed],
            selectedBundleIdentifier: zed.bundleIdentifier
        )

        #expect(resolved?.bundleIdentifier == zed.bundleIdentifier)
    }

    @Test("resolveDefaultIDE falls back to first installed IDE when selection is missing")
    func resolveDefaultIDEFallsBackToFirstInstalled() {
        let vscode = IDEIntegrationService.IDEApplication(
            bundleIdentifier: "com.microsoft.VSCode",
            displayName: "VS Code",
            appURL: URL(fileURLWithPath: "/Applications/Visual Studio Code.app"),
            symbolName: "chevron.left.forwardslash.chevron.right"
        )
        let zed = IDEIntegrationService.IDEApplication(
            bundleIdentifier: "dev.zed.Zed",
            displayName: "Zed",
            appURL: URL(fileURLWithPath: "/Applications/Zed.app"),
            symbolName: "bolt.horizontal"
        )

        let resolved = IDEIntegrationService.resolveDefaultIDE(
            installedApps: [vscode, zed],
            selectedBundleIdentifier: "com.example.missing"
        )

        #expect(resolved?.bundleIdentifier == vscode.bundleIdentifier)
    }
}
