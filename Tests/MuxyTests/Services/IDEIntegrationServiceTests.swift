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
            symbolName: "chevron.left.forwardslash.chevron.right",
            rank: 10
        )
        let zed = IDEIntegrationService.IDEApplication(
            bundleIdentifier: "dev.zed.Zed",
            displayName: "Zed",
            appURL: URL(fileURLWithPath: "/Applications/Zed.app"),
            symbolName: "bolt.horizontal",
            rank: 13
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
            symbolName: "chevron.left.forwardslash.chevron.right",
            rank: 10
        )
        let zed = IDEIntegrationService.IDEApplication(
            bundleIdentifier: "dev.zed.Zed",
            displayName: "Zed",
            appURL: URL(fileURLWithPath: "/Applications/Zed.app"),
            symbolName: "bolt.horizontal",
            rank: 13
        )

        let resolved = IDEIntegrationService.resolveDefaultIDE(
            installedApps: [vscode, zed],
            selectedBundleIdentifier: "com.example.missing"
        )

        #expect(resolved?.bundleIdentifier == vscode.bundleIdentifier)
    }

    @Test("classifies JetBrains IDEs automatically")
    func classifiesJetBrainsIDEsAutomatically() {
        let metadata = IDEIntegrationService.AppMetadata(
            bundleIdentifier: "com.jetbrains.PhpStorm",
            displayName: "PhpStorm",
            executableName: "phpstorm",
            category: "public.app-category.developer-tools",
            appURL: URL(fileURLWithPath: "/Applications/PhpStorm.app")
        )

        let app = IDEIntegrationService.ideApplication(from: metadata)

        #expect(app != nil)
        #expect(app?.displayName == "PhpStorm")
    }

    @Test("classifies developer tools by editor-like names")
    func classifiesDeveloperToolsByEditorLikeNames() {
        let metadata = IDEIntegrationService.AppMetadata(
            bundleIdentifier: "com.google.antigravity",
            displayName: "Antigravity",
            executableName: "Electron",
            category: "public.app-category.developer-tools",
            appURL: URL(fileURLWithPath: "/Applications/Antigravity.app")
        )

        let app = IDEIntegrationService.ideApplication(from: metadata)

        #expect(app != nil)
        #expect(app?.symbolName == "sparkles")
    }

    @Test("does not classify JetBrains Toolbox as an IDE target")
    func doesNotClassifyJetBrainsToolbox() {
        let metadata = IDEIntegrationService.AppMetadata(
            bundleIdentifier: "com.jetbrains.toolbox",
            displayName: "JetBrains Toolbox",
            executableName: "jetbrains-toolbox",
            category: "public.app-category.developer-tools",
            appURL: URL(fileURLWithPath: "/Applications/JetBrains Toolbox.app")
        )

        #expect(IDEIntegrationService.ideApplication(from: metadata) == nil)
    }

    @Test("sort prioritizes curated IDE ranks before alphabetical order")
    func sortPrioritizesCuratedRanks() {
        let apps = [
            IDEIntegrationService.IDEApplication(
                bundleIdentifier: "com.jetbrains.PhpStorm",
                displayName: "PhpStorm",
                appURL: URL(fileURLWithPath: "/Applications/PhpStorm.app"),
                symbolName: "chevron.left.forwardslash.chevron.right",
                rank: 19
            ),
            IDEIntegrationService.IDEApplication(
                bundleIdentifier: "com.microsoft.VSCode",
                displayName: "VS Code",
                appURL: URL(fileURLWithPath: "/Applications/Visual Studio Code.app"),
                symbolName: "chevron.left.forwardslash.chevron.right",
                rank: 10
            ),
            IDEIntegrationService.IDEApplication(
                bundleIdentifier: "com.google.antigravity",
                displayName: "Antigravity",
                appURL: URL(fileURLWithPath: "/Applications/Antigravity.app"),
                symbolName: "sparkles",
                rank: 35
            ),
        ]

        let sorted = apps.sorted(by: IDEIntegrationService.compareInstalledApps)

        #expect(sorted.map(\.displayName) == ["VS Code", "PhpStorm", "Antigravity"])
    }
}
