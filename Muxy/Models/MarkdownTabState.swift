import AppKit
import Foundation
import os

let markdownLogger = Logger(subsystem: "app.muxy", category: "MarkdownPreview")

private enum MarkdownLoadError: LocalizedError {
    case invalidUTF8

    var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            "File is not valid UTF-8 text."
        }
    }
}

@MainActor
@Observable
final class MarkdownTabState {
    private static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]

    private struct LoadedMarkdownContent {
        let content: String
        let bytes: Int
    }

    private enum LoadedMarkdownResult {
        case success(LoadedMarkdownContent)
        case failure(error: Error, loadedBytes: Int?)
    }

    private struct RenderCacheKey: Equatable {
        let content: String
        let filePath: String?
        let themeVersion: Int
        let bgHex: String
        let fgHex: String
        let accentHex: String
    }

    private var renderedHTMLCache: (key: RenderCacheKey, html: String)?
    private var loadTask: Task<Void, Never>?
    private var loadRequestID: UUID?

    let projectPath: String

    var filePath: String?
    var rawContent: String?
    var errorMessage: String?
    var isLoading = false
    var scrollPosition: CGFloat = 0

    var fileName: String {
        guard let filePath else { return "Markdown Reader" }
        return URL(fileURLWithPath: filePath).lastPathComponent
    }

    var projectRelativePath: String? {
        guard let filePath else { return nil }
        let url = URL(fileURLWithPath: filePath)
        return url.path.replacingOccurrences(of: projectPath + "/", with: "")
    }

    var renderedHTML: String {
        let bgColor = MuxyTheme.nsBg
        let fgColor = MuxyTheme.nsFg
        let accentColor = MuxyTheme.nsAccent

        let key = RenderCacheKey(
            content: rawContent ?? "",
            filePath: filePath,
            themeVersion: GhosttyService.shared.configVersion,
            bgHex: Self.colorKey(bgColor),
            fgHex: Self.colorKey(fgColor),
            accentHex: Self.colorKey(accentColor)
        )

        if let cached = renderedHTMLCache, cached.key == key {
            return cached.html
        }

        let html = MarkdownRenderer.html(
            content: key.content,
            filePath: key.filePath,
            bgColor: bgColor,
            fgColor: fgColor,
            accentColor: accentColor
        )

        renderedHTMLCache = (key, html)

        markdownLogger.debug(
            """
            Rendered markdown html
            path=\(self.filePath ?? "<nil>", privacy: .public)
            contentBytes=\((self.rawContent ?? "").utf8.count)
            htmlLength=\(html.utf8.count)
            """
        )
        return html
    }

    init(projectPath: String, filePath: String? = nil) {
        self.projectPath = projectPath
        self.filePath = filePath
        if let filePath {
            loadFile(filePath)
        }
    }

    func loadFile(_ path: String) {
        loadTask?.cancel()

        let requestID = UUID()
        loadRequestID = requestID
        isLoading = true
        errorMessage = nil
        filePath = path

        let url = URL(fileURLWithPath: path)
        let ext = url.pathExtension.lowercased()
        markdownLogger.info(
            "Markdown file load requested path=\(path, privacy: .public) extension=\(ext, privacy: .public)"
        )

        guard Self.markdownExtensions.contains(ext) else {
            rawContent = nil
            errorMessage = "Not a markdown file: \(url.pathExtension)"
            markdownLogger.error(
                """
                Rejected non-markdown file
                path=\(path, privacy: .public)
                extension=\(url.pathExtension, privacy: .public)
                bytes=0
                status=failure
                reason=unsupported-extension
                """
            )
            isLoading = false
            return
        }

        loadTask = Task.detached(priority: .userInitiated) { [weak self, requestID, path, ext, url] in
            let result = Self.loadMarkdownContent(from: url)
            await MainActor.run {
                guard let self,
                      self.loadRequestID == requestID,
                      self.filePath == path
                else {
                    return
                }

                switch result {
                case let .success(loaded):
                    self.rawContent = loaded.content
                    markdownLogger.info(
                        """
                        Loaded markdown file
                        path=\(path, privacy: .public)
                        extension=\(ext, privacy: .public)
                        bytes=\(loaded.bytes)
                        status=success
                        """
                    )
                case let .failure(error, loadedBytes):
                    self.rawContent = nil
                    self.errorMessage = error.localizedDescription
                    markdownLogger.error(
                        """
                        Failed loading markdown file
                        path=\(path, privacy: .public)
                        extension=\(ext, privacy: .public)
                        bytes=\(loadedBytes ?? -1)
                        status=failure
                        reason=\(error.localizedDescription, privacy: .public)
                        """
                    )
                }

                self.isLoading = false
            }
        }
    }

    nonisolated private static func loadMarkdownContent(from url: URL) -> LoadedMarkdownResult {
        do {
            let data = try Data(contentsOf: url)
            let bytes = data.count
            guard let content = String(data: data, encoding: .utf8) else {
                return .failure(error: MarkdownLoadError.invalidUTF8, loadedBytes: bytes)
            }

            return .success(LoadedMarkdownContent(content: content, bytes: bytes))
        } catch {
            return .failure(error: error, loadedBytes: nil)
        }
    }

    func reload() {
        guard let path = filePath else { return }
        loadFile(path)
    }

    private static func colorKey(_ color: NSColor) -> String {
        let colorSpaces: [NSColorSpace] = [.sRGB, .extendedSRGB, .deviceRGB, .genericRGB]
        for colorSpace in colorSpaces {
            if let rgb = color.usingColorSpace(colorSpace) {
                let r = Int(round(rgb.redComponent * 255))
                let g = Int(round(rgb.greenComponent * 255))
                let b = Int(round(rgb.blueComponent * 255))
                return String(format: "%02X%02X%02X", max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))
            }
        }
        return "1E1E1E"
    }
}
