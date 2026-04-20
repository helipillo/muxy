import AppKit
import os
import SwiftUI
import UniformTypeIdentifiers
import WebKit

private let markdownWebLogger = Logger(subsystem: "app.muxy", category: "MarkdownWebView")

extension WKWebView {
    var safeScrollView: NSScrollView? {
        for subview in subviews {
            if let scrollView = subview as? NSScrollView {
                return scrollView
            }
        }
        return nil
    }
}

struct MarkdownTabView: View {
    @Bindable var state: MarkdownTabState
    let onFocus: () -> Void

    @State private var showFilePicker = false

    private static let markdownContentTypes: [UTType] = {
        let extensions = ["md", "markdown", "mdown", "mkd"]
        let types = extensions.compactMap { UTType(filenameExtension: $0) }
        return types.isEmpty ? [.plainText] : types
    }()

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(MuxyTheme.border).frame(height: 1)
            content
        }
        .background(MuxyTheme.bg)
        .contentShape(Rectangle())
        .onTapGesture(perform: onFocus)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: Self.markdownContentTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                openFile(from: url)
            case let .failure(error):
                markdownWebLogger.error(
                    "Markdown file picker failed reason=\(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            IconButton(symbol: "folder", accessibilityLabel: "Open File") {
                showFilePicker = true
            }
            .help("Open Markdown File")

            if state.filePath != nil {
                IconButton(symbol: "arrow.clockwise", accessibilityLabel: "Reload") {
                    state.reload()
                }
                .help("Reload File")

                PathBreadcrumb(path: state.projectRelativePath ?? state.fileName)
            }

            Spacer(minLength: 0)

            if state.filePath != nil {
                HStack(spacing: 4) {
                    Text(state.fileName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(MuxyTheme.fgMuted)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 32)
        .background(MuxyTheme.bg)
    }

    @ViewBuilder
    private var content: some View {
        if state.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = state.errorMessage, state.rawContent == nil {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 24))
                    .foregroundStyle(MuxyTheme.fgMuted)
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(MuxyTheme.fgMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                Button("Choose Another File") {
                    showFilePicker = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(MuxyTheme.accent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.rawContent == nil {
            emptyState
        } else {
            MarkdownWebView(
                html: state.renderedHTML,
                filePath: state.filePath,
                scrollPosition: $state.scrollPosition
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 40))
                .foregroundStyle(MuxyTheme.fgMuted)

            VStack(spacing: 6) {
                Text("Markdown Reader")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MuxyTheme.fg)
                Text("Open a markdown file to preview it here with full formatting and diagram support.")
                    .font(.system(size: 12))
                    .foregroundStyle(MuxyTheme.fgMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            VStack(spacing: 8) {
                Button {
                    showFilePicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Open File")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(MuxyTheme.bg)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(MuxyTheme.accent, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Text("Or use ⌘P and search for .md files")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openFile(from url: URL) {
        markdownWebLogger.info(
            "Markdown open requested path=\(url.path, privacy: .public) extension=\(url.pathExtension.lowercased(), privacy: .public)"
        )
        guard url.startAccessingSecurityScopedResource() else {
            markdownWebLogger.error(
                "Markdown open denied security scope path=\(url.path, privacy: .public)"
            )
            state.errorMessage = "Unable to access selected file."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        state.loadFile(url.path)
    }
}

struct MarkdownWebView: NSViewRepresentable {
    let html: String
    let filePath: String?
    @Binding var scrollPosition: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        if let scrollView = webView.safeScrollView {
            var newBounds = scrollView.contentView.bounds
            newBounds.origin.y = scrollPosition
            scrollView.contentView.bounds = newBounds
        }

        context.coordinator.loadHTML(html, filePath: filePath, into: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.updateHTML(html, scrollPosition: scrollPosition, filePath: filePath, webView: webView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private var lastHTML: String = ""
        private var lastScrollPosition: CGFloat = -1
        private var pendingScrollPosition: CGFloat?
        private var activeNavigation: WKNavigation?
        private var loadCount: Int = 0
        private var currentFilePath: String?

        func loadHTML(_ html: String, filePath: String?, into webView: WKWebView) {
            lastHTML = html
            currentFilePath = filePath
            loadCount += 1
            markdownWebLogger.debug(
                "Markdown web load seq=\(self.loadCount) path=\(filePath ?? "<nil>", privacy: .public) htmlLength=\(html.utf8.count)"
            )
            activeNavigation = webView.loadHTMLString(html, baseURL: nil)
        }

        func updateHTML(_ html: String, scrollPosition: CGFloat, filePath: String?, webView: WKWebView) {
            currentFilePath = filePath
            if html != lastHTML {
                lastHTML = html
                pendingScrollPosition = scrollPosition
                loadCount += 1
                markdownWebLogger.debug(
                    "Markdown web update seq=\(self.loadCount) path=\(filePath ?? "<nil>", privacy: .public) htmlLength=\(html.utf8.count) pendingScrollY=\(scrollPosition)"
                )
                activeNavigation = webView.loadHTMLString(html, baseURL: nil)
            } else if scrollPosition != lastScrollPosition, scrollPosition >= 0 {
                lastScrollPosition = scrollPosition
                if let scrollView = webView.safeScrollView {
                    var newBounds = scrollView.contentView.bounds
                    newBounds.origin.y = scrollPosition
                    scrollView.contentView.bounds = newBounds
                }
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            markdownWebLogger.debug(
                "Markdown navigation didStart seq=\(self.loadCount) path=\(self.currentFilePath ?? "<nil>", privacy: .public)"
            )
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let navigation, let activeNavigation, navigation !== activeNavigation {
                markdownWebLogger.debug("Ignoring didFinish for stale markdown navigation")
                return
            }
            markdownWebLogger.debug(
                "Markdown navigation didFinish seq=\(self.loadCount) path=\(self.currentFilePath ?? "<nil>", privacy: .public)"
            )
            if let pending = pendingScrollPosition {
                pendingScrollPosition = nil
                lastScrollPosition = pending
                if let scrollView = webView.safeScrollView {
                    var newBounds = scrollView.contentView.bounds
                    newBounds.origin.y = pending
                    scrollView.contentView.bounds = newBounds
                }
            }
            collectJavaScriptErrors(from: webView)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            logNavigationFailure(kind: "provisional", navigation: navigation, error: error)
            collectJavaScriptErrors(from: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            logNavigationFailure(kind: "navigation", navigation: navigation, error: error)
            collectJavaScriptErrors(from: webView)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            markdownWebLogger.error(
                "Markdown web content process terminated path=\(self.currentFilePath ?? "<nil>", privacy: .public) reason=process-terminated"
            )
        }

        private func logNavigationFailure(kind: String, navigation: WKNavigation!, error: Error) {
            let nsError = error as NSError
            if let navigation, let activeNavigation, navigation !== activeNavigation {
                markdownWebLogger.debug(
                    "Ignoring stale markdown \(kind, privacy: .public) failure code=\(nsError.code) domain=\(nsError.domain, privacy: .public)"
                )
                return
            }
            markdownWebLogger.error(
                "Markdown \(kind, privacy: .public) failure path=\(self.currentFilePath ?? "<nil>", privacy: .public) code=\(nsError.code) domain=\(nsError.domain, privacy: .public) reason=\(nsError.localizedDescription, privacy: .public)"
            )
        }

        private func collectJavaScriptErrors(from webView: WKWebView) {
            let script = """
            (() => {
                const entries = Array.isArray(window.__muxyErrors) ? window.__muxyErrors : [];
                window.__muxyErrors = [];
                return entries;
            })()
            """

            webView.evaluateJavaScript(script) { result, error in
                if let error {
                    markdownWebLogger.error(
                        "Failed collecting markdown JavaScript errors: \(error.localizedDescription, privacy: .public)"
                    )
                    return
                }

                guard let entries = result as? [[String: Any]], !entries.isEmpty else {
                    return
                }

                for entry in entries {
                    let type = (entry["type"] as? String) ?? "unknown"
                    let message = (entry["message"] as? String) ?? ""
                    let source = (entry["source"] as? String) ?? ""
                    markdownWebLogger.error(
                        "Markdown JavaScript \(type, privacy: .public) message=\(message, privacy: .public) source=\(source, privacy: .public)"
                    )
                }
            }
        }
    }
}

struct PathBreadcrumb: View {
    let path: String

    private var components: [String] {
        path.components(separatedBy: "/").filter { !$0.isEmpty }
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(MuxyTheme.fgDim)
                }
                Text(component)
                    .font(.system(size: 10))
                    .foregroundStyle(index == components.count - 1 ? MuxyTheme.fg : MuxyTheme.fgMuted)
                    .lineLimit(1)
            }
        }
    }
}
