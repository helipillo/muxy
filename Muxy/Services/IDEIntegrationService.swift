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
        let rank: Int

        var id: String {
            bundleIdentifier.isEmpty ? appURL.path : bundleIdentifier
        }
    }

    struct AppMetadata: Hashable {
        let bundleIdentifier: String
        let displayName: String
        let executableName: String
        let category: String?
        let appURL: URL
    }

    struct MatchMetadata: Hashable {
        let symbolName: String
        let rank: Int
    }

    static let selectedBundleIdentifierKey = "muxy.ide.selectedBundleIdentifier"

    @Published private(set) var installedApps: [IDEApplication] = []

    private let workspace: NSWorkspace
    private let defaults: UserDefaults
    private let fileManager: FileManager

    init(
        workspace: NSWorkspace = .shared,
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) {
        self.workspace = workspace
        self.defaults = defaults
        self.fileManager = fileManager
        refreshInstalledApps()
    }

    var selectedBundleIdentifier: String? {
        defaults.string(forKey: Self.selectedBundleIdentifierKey)
    }

    var defaultIDE: IDEApplication? {
        Self.resolveDefaultIDE(installedApps: installedApps, selectedBundleIdentifier: selectedBundleIdentifier)
    }

    func refreshInstalledApps() {
        var discovered: [IDEApplication] = []
        var seenKeys = Set<String>()

        for root in Self.discoveryRoots(fileManager: fileManager) {
            for metadata in discoverAppMetadata(in: root) {
                guard let app = Self.ideApplication(from: metadata) else { continue }
                let key = dedupeKey(for: app)
                guard seenKeys.insert(key).inserted else { continue }
                discovered.append(app)
            }
        }

        for bundleIdentifier in Self.curatedBundleMetadata.keys.sorted() {
            guard let appURL = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier),
                  let metadata = Self.loadMetadata(at: appURL)
            else { continue }
            guard let app = Self.ideApplication(from: metadata) else { continue }
            let key = dedupeKey(for: app)
            guard seenKeys.insert(key).inserted else { continue }
            discovered.append(app)
        }

        installedApps = discovered.sorted(by: Self.compareInstalledApps)
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

    static func ideApplication(from metadata: AppMetadata) -> IDEApplication? {
        guard let match = matchMetadata(for: metadata) else { return nil }
        return IDEApplication(
            bundleIdentifier: metadata.bundleIdentifier,
            displayName: metadata.displayName,
            appURL: metadata.appURL,
            symbolName: match.symbolName,
            rank: match.rank
        )
    }

    static func matchMetadata(for metadata: AppMetadata) -> MatchMetadata? {
        if let curated = curatedBundleMetadata[metadata.bundleIdentifier] {
            return curated
        }

        let loweredName = metadata.displayName.lowercased()
        let loweredExecutable = metadata.executableName.lowercased()
        let loweredIdentifier = metadata.bundleIdentifier.lowercased()
        let haystack = [loweredName, loweredExecutable, loweredIdentifier]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if loweredIdentifier == "com.jetbrains.toolbox" || loweredName.contains("toolbox") {
            return nil
        }

        if loweredIdentifier.hasPrefix("com.jetbrains."),
           !loweredName.contains("toolbox") {
            return MatchMetadata(symbolName: "chevron.left.forwardslash.chevron.right", rank: 40)
        }

        if let keywordMatch = keywordMatches.first(where: { containsKeyword($0.keyword, in: haystack) }) {
            return MatchMetadata(symbolName: keywordMatch.symbolName, rank: keywordMatch.rank)
        }

        if metadata.category == developerToolsCategory,
           editorLikeNameFragments.contains(where: { containsKeyword($0, in: loweredName) || containsKeyword($0, in: loweredExecutable) }) {
            return MatchMetadata(symbolName: "chevron.left.forwardslash.chevron.right", rank: 90)
        }

        return nil
    }

    static func compareInstalledApps(_ lhs: IDEApplication, _ rhs: IDEApplication) -> Bool {
        if lhs.rank != rhs.rank {
            return lhs.rank < rhs.rank
        }
        let nameOrder = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
        if nameOrder != .orderedSame {
            return nameOrder == .orderedAscending
        }
        return lhs.appURL.path.localizedCaseInsensitiveCompare(rhs.appURL.path) == .orderedAscending
    }

    static func discoveryRoots(fileManager: FileManager) -> [URL] {
        [
            URL(fileURLWithPath: "/Applications"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
        ].filter { fileManager.fileExists(atPath: $0.path) }
    }

    static func loadMetadata(at appURL: URL) -> AppMetadata? {
        let infoURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let info = NSDictionary(contentsOf: infoURL) as? [String: Any] else { return nil }

        let bundleIdentifier = info["CFBundleIdentifier"] as? String ?? ""
        let bundleName = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? appURL.deletingPathExtension().lastPathComponent
        let executableName = info["CFBundleExecutable"] as? String ?? ""
        let category = info["LSApplicationCategoryType"] as? String

        return AppMetadata(
            bundleIdentifier: bundleIdentifier,
            displayName: bundleName,
            executableName: executableName,
            category: category,
            appURL: appURL
        )
    }

    private func discoverAppMetadata(in root: URL) -> [AppMetadata] {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var results: [AppMetadata] = []
        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == "app" else { continue }
            if let metadata = Self.loadMetadata(at: url) {
                results.append(metadata)
            }
            enumerator.skipDescendants()
        }
        return results
    }

    private func dedupeKey(for app: IDEApplication) -> String {
        if !app.bundleIdentifier.isEmpty {
            return app.bundleIdentifier
        }
        return app.appURL.standardizedFileURL.path
    }

    private static func containsKeyword(_ keyword: String, in haystack: String) -> Bool {
        haystack.contains(keyword.lowercased())
    }

    private static let developerToolsCategory = "public.app-category.developer-tools"

    private static let curatedBundleMetadata: [String: MatchMetadata] = [
        "com.microsoft.VSCode": .init(symbolName: "chevron.left.forwardslash.chevron.right", rank: 10),
        "com.microsoft.VSCodeInsiders": .init(symbolName: "chevron.left.forwardslash.chevron.right", rank: 11),
        "com.todesktop.230313mzl4w4u92": .init(symbolName: "cursorarrow.click.2", rank: 12),
        "dev.zed.Zed": .init(symbolName: "bolt.horizontal", rank: 13),
        "com.exafunction.windsurf": .init(symbolName: "wind", rank: 14),
        "com.vscodium": .init(symbolName: "chevron.left.forwardslash.chevron.right", rank: 15),
        "com.openai.codex": .init(symbolName: "sparkles.rectangle.stack", rank: 16),
        "ai.opencode.desktop": .init(symbolName: "chevron.left.forwardslash.chevron.right", rank: 17),
        "com.apple.dt.Xcode": .init(symbolName: "hammer", rank: 18),
        "com.jetbrains.PhpStorm": .init(symbolName: "chevron.left.forwardslash.chevron.right", rank: 19),
        "com.jetbrains.WebStorm": .init(symbolName: "chevron.left.forwardslash.chevron.right", rank: 20),
        "com.jetbrains.PyCharm": .init(symbolName: "chevron.left.forwardslash.chevron.right", rank: 21),
        "com.jetbrains.IntelliJ-IDEA": .init(symbolName: "chevron.left.forwardslash.chevron.right", rank: 22),
        "com.jetbrains.CLion": .init(symbolName: "chevron.left.forwardslash.chevron.right", rank: 23),
        "com.jetbrains.GoLand": .init(symbolName: "chevron.left.forwardslash.chevron.right", rank: 24),
        "com.jetbrains.RubyMine": .init(symbolName: "chevron.left.forwardslash.chevron.right", rank: 25),
        "com.jetbrains.DataGrip": .init(symbolName: "chevron.left.forwardslash.chevron.right", rank: 26),
        "com.jetbrains.Rider": .init(symbolName: "chevron.left.forwardslash.chevron.right", rank: 27),
        "com.jetbrainsFleet": .init(symbolName: "chevron.left.forwardslash.chevron.right", rank: 28),
        "com.google.antigravity": .init(symbolName: "sparkles", rank: 29),
        "com.jcode.launcher": .init(symbolName: "terminal", rank: 30),
        "com.panic.Nova": .init(symbolName: "chevron.left.forwardslash.chevron.right", rank: 31),
        "com.sublimetext.4": .init(symbolName: "text.cursor", rank: 32),
        "com.barebones.bbedit": .init(symbolName: "text.cursor", rank: 33),
        "com.macromates.TextMate": .init(symbolName: "text.cursor", rank: 34),
    ]

    private static let editorLikeNameFragments: [String] = [
        "code",
        "cursor",
        "zed",
        "studio",
        "storm",
        "editor",
        "nova",
        "fleet",
        "codex",
        "opencode",
        "windsurf",
        "xcode",
        "sublime",
        "bbedit",
        "textmate",
        "antigravity",
        "jcode",
        "phpstorm",
        "webstorm",
        "pycharm",
        "rubymine",
        "clion",
        "goland",
        "datagrip",
        "rider",
        "intellij",
        "idea",
        "android studio",
    ]

    private static let keywordMatches: [(keyword: String, symbolName: String, rank: Int)] = [
        ("visual studio code", "chevron.left.forwardslash.chevron.right", 10),
        ("vscode", "chevron.left.forwardslash.chevron.right", 11),
        ("code - insiders", "chevron.left.forwardslash.chevron.right", 12),
        ("vscodium", "chevron.left.forwardslash.chevron.right", 13),
        ("cursor", "cursorarrow.click.2", 14),
        ("zed", "bolt.horizontal", 15),
        ("windsurf", "wind", 16),
        ("codex", "sparkles.rectangle.stack", 17),
        ("opencode", "chevron.left.forwardslash.chevron.right", 18),
        ("xcode", "hammer", 19),
        ("phpstorm", "chevron.left.forwardslash.chevron.right", 20),
        ("webstorm", "chevron.left.forwardslash.chevron.right", 21),
        ("pycharm", "chevron.left.forwardslash.chevron.right", 22),
        ("rubymine", "chevron.left.forwardslash.chevron.right", 23),
        ("clion", "chevron.left.forwardslash.chevron.right", 24),
        ("goland", "chevron.left.forwardslash.chevron.right", 25),
        ("datagrip", "chevron.left.forwardslash.chevron.right", 26),
        ("rider", "chevron.left.forwardslash.chevron.right", 27),
        ("fleet", "chevron.left.forwardslash.chevron.right", 28),
        ("intellij", "chevron.left.forwardslash.chevron.right", 29),
        ("android studio", "chevron.left.forwardslash.chevron.right", 30),
        ("nova", "chevron.left.forwardslash.chevron.right", 31),
        ("sublime text", "text.cursor", 32),
        ("bbedit", "text.cursor", 33),
        ("textmate", "text.cursor", 34),
        ("antigravity", "sparkles", 35),
        ("jcode", "terminal", 36),
    ]
}
