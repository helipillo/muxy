import AppKit
import Foundation

@MainActor
final class IDEIntegrationService: ObservableObject {
    static let shared = IDEIntegrationService()

    struct IDEApplication: Identifiable, Hashable {
        let bundleIdentifier: String
        let displayName: String
        let appURL: URL
        let symbolName: String

        var id: String { bundleIdentifier }
    }

    struct IDECandidate: Hashable {
        let bundleIdentifier: String
        let displayName: String
        let symbolName: String
        let fallbackPaths: [String]
    }

    static let selectedBundleIdentifierKey = "muxy.ide.selectedBundleIdentifier"

    @Published private(set) var installedApps: [IDEApplication] = []

    private let workspace: NSWorkspace
    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let catalog: [IDECandidate]

    init(
        workspace: NSWorkspace = .shared,
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        catalog: [IDECandidate] = IDEIntegrationService.defaultCatalog
    ) {
        self.workspace = workspace
        self.defaults = defaults
        self.fileManager = fileManager
        self.catalog = catalog
        refreshInstalledApps()
    }

    var selectedBundleIdentifier: String? {
        defaults.string(forKey: Self.selectedBundleIdentifierKey)
    }

    var defaultIDE: IDEApplication? {
        Self.resolveDefaultIDE(installedApps: installedApps, selectedBundleIdentifier: selectedBundleIdentifier)
    }

    func refreshInstalledApps() {
        let apps = catalog.compactMap(resolveApp(for:))
        installedApps = apps.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }

        guard let selectedBundleIdentifier,
              installedApps.contains(where: { $0.bundleIdentifier == selectedBundleIdentifier })
        else { return }

        defaults.set(selectedBundleIdentifier, forKey: Self.selectedBundleIdentifierKey)
    }

    @discardableResult
    func openProject(at path: String, in ide: IDEApplication? = nil) -> Bool {
        guard let app = ide ?? defaultIDE else { return false }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", app.appURL.path, path]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return false
        }

        guard process.terminationStatus == 0 else { return false }
        defaults.set(app.bundleIdentifier, forKey: Self.selectedBundleIdentifierKey)
        return true
    }

    static func resolveDefaultIDE(
        installedApps: [IDEApplication],
        selectedBundleIdentifier: String?
    ) -> IDEApplication? {
        if let selectedBundleIdentifier,
           let selected = installedApps.first(where: { $0.bundleIdentifier == selectedBundleIdentifier }) {
            return selected
        }
        return installedApps.first
    }

    private func resolveApp(for candidate: IDECandidate) -> IDEApplication? {
        if let appURL = workspace.urlForApplication(withBundleIdentifier: candidate.bundleIdentifier) {
            return IDEApplication(
                bundleIdentifier: candidate.bundleIdentifier,
                displayName: candidate.displayName,
                appURL: appURL,
                symbolName: candidate.symbolName
            )
        }

        if let appURL = candidate.fallbackPaths
            .map({ NSString(string: $0).expandingTildeInPath })
            .map(URL.init(fileURLWithPath:))
            .first(where: { fileManager.fileExists(atPath: $0.path) }) {
            return IDEApplication(
                bundleIdentifier: candidate.bundleIdentifier,
                displayName: candidate.displayName,
                appURL: appURL,
                symbolName: candidate.symbolName
            )
        }

        return nil
    }

    private static let defaultCatalog: [IDECandidate] = [
        IDECandidate(
            bundleIdentifier: "com.openai.codex",
            displayName: "Codex",
            symbolName: "sparkles.rectangle.stack",
            fallbackPaths: [
                "/Applications/Codex.app",
                "~/Applications/Codex.app",
            ]
        ),
        IDECandidate(
            bundleIdentifier: "ai.opencode.desktop",
            displayName: "OpenCode",
            symbolName: "chevron.left.forwardslash.chevron.right",
            fallbackPaths: [
                "/Applications/OpenCode.app",
                "~/Applications/OpenCode.app",
            ]
        ),
        IDECandidate(
            bundleIdentifier: "com.apple.dt.Xcode",
            displayName: "Xcode",
            symbolName: "hammer",
            fallbackPaths: [
                "/Applications/Xcode.app",
                "~/Applications/Xcode.app",
            ]
        ),
        IDECandidate(
            bundleIdentifier: "com.microsoft.VSCode",
            displayName: "VS Code",
            symbolName: "chevron.left.forwardslash.chevron.right",
            fallbackPaths: [
                "/Applications/Visual Studio Code.app",
                "~/Applications/Visual Studio Code.app",
            ]
        ),
        IDECandidate(
            bundleIdentifier: "com.microsoft.VSCodeInsiders",
            displayName: "VS Code Insiders",
            symbolName: "chevron.left.forwardslash.chevron.right",
            fallbackPaths: [
                "/Applications/Visual Studio Code - Insiders.app",
                "~/Applications/Visual Studio Code - Insiders.app",
            ]
        ),
        IDECandidate(
            bundleIdentifier: "com.todesktop.230313mzl4w4u92",
            displayName: "Cursor",
            symbolName: "cursorarrow.click.2",
            fallbackPaths: [
                "/Applications/Cursor.app",
                "~/Applications/Cursor.app",
            ]
        ),
        IDECandidate(
            bundleIdentifier: "dev.zed.Zed",
            displayName: "Zed",
            symbolName: "bolt.horizontal",
            fallbackPaths: [
                "/Applications/Zed.app",
                "~/Applications/Zed.app",
            ]
        ),
        IDECandidate(
            bundleIdentifier: "com.exafunction.windsurf",
            displayName: "Windsurf",
            symbolName: "wind",
            fallbackPaths: [
                "/Applications/Windsurf.app",
                "~/Applications/Windsurf.app",
            ]
        ),
        IDECandidate(
            bundleIdentifier: "com.vscodium",
            displayName: "VSCodium",
            symbolName: "chevron.left.forwardslash.chevron.right",
            fallbackPaths: [
                "/Applications/VSCodium.app",
                "~/Applications/VSCodium.app",
            ]
        ),
    ]
}
