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

private enum MarkdownWebBridge {
    static let scrollHandlerName = "muxyMarkdownScroll"
    static let wheelHandlerName = "muxyMarkdownWheel"

    static let scrollObserverScript = #"""
    (() => {
        const handler = window.webkit?.messageHandlers?.muxyMarkdownScroll;
        const wheelHandler = window.webkit?.messageHandlers?.muxyMarkdownWheel;
        if (!handler) return;

        const scrollRoot = () => document.getElementById('content')
            || document.scrollingElement
            || document.documentElement
            || document.body;
        const report = () => {
            const root = scrollRoot();
            if (!root) return;
            const maxScrollY = Math.max(0, root.scrollHeight - root.clientHeight);
            const progress = maxScrollY > 0 ? root.scrollTop / maxScrollY : 0;
            handler.postMessage(progress);
        };

        const attach = () => {
            const root = scrollRoot();
            if (!root) return;
            root.addEventListener('scroll', report, { passive: true });
            root.addEventListener('wheel', event => {
                if (!wheelHandler) return;
                if (!document.documentElement?.classList.contains('muxy-linked-scroll')) return;
                wheelHandler.postMessage({ deltaY: event.deltaY });
                event.preventDefault();
            }, { passive: false });
            report();
        };

        window.addEventListener('resize', report, { passive: true });
        window.addEventListener('load', () => setTimeout(attach, 0));
        document.addEventListener('DOMContentLoaded', () => setTimeout(attach, 0));
        setTimeout(attach, 0);
    })();
    """#

    static func scrollToProgressScript(_ progress: CGFloat) -> String {
        let clamped = min(max(progress, 0), 1)
        return """
        (() => {
            const root = document.getElementById('content')
                || document.scrollingElement
                || document.documentElement
                || document.body;
            if (!root) return;
            const maxScrollY = Math.max(0, root.scrollHeight - root.clientHeight);
            root.scrollTop = maxScrollY * \(clamped);
        })();
        """
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
    struct Configuration {
        let scrollSyncEnabled: Bool
        let showsVerticalScroller: Bool
        let hidesContentScrollbar: Bool
        let linkedScrollEnabled: Bool
        let onScrollProgressChanged: ((CGFloat) -> Void)?
        let onLinkedScrollWheel: ((CGFloat) -> Void)?
    }

    let html: String
    let filePath: String?
    @Binding var scrollPosition: CGFloat
    var scrollSyncEnabled = true
    var showsVerticalScroller = true
    var hidesContentScrollbar = false
    var linkedScrollEnabled = false
    var onScrollProgressChanged: ((CGFloat) -> Void)?
    var onLinkedScrollWheel: ((CGFloat) -> Void)?

    private var configuration: Configuration {
        Configuration(
            scrollSyncEnabled: scrollSyncEnabled,
            showsVerticalScroller: showsVerticalScroller,
            hidesContentScrollbar: hidesContentScrollbar,
            linkedScrollEnabled: linkedScrollEnabled,
            onScrollProgressChanged: onScrollProgressChanged,
            onLinkedScrollWheel: onLinkedScrollWheel
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        context.coordinator.installBridge(into: config)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.configure(with: configuration)
        context.coordinator.updateScrollerVisibility(in: webView)
        if scrollSyncEnabled {
            context.coordinator.applyScrollProgress(scrollPosition, to: webView)
        }

        context.coordinator.loadHTML(html, filePath: filePath, into: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.configure(with: configuration)
        context.coordinator.updateScrollerVisibility(in: webView)
        context.coordinator.updateContentScrollbarVisibility(in: webView)
        context.coordinator.updateHTML(
            html,
            scrollPosition: scrollPosition,
            scrollSyncEnabled: scrollSyncEnabled,
            filePath: filePath,
            webView: webView
        )
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.navigationDelegate = nil
        webView.configuration.userContentController.removeScriptMessageHandler(forName: MarkdownWebBridge.scrollHandlerName)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: MarkdownWebBridge.wheelHandlerName)
        coordinator.removeScrollObserver()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private static let programmaticScrollSuppressionWindow: TimeInterval = 0.2

        private var lastHTML: String = ""
        private var lastScrollProgress: CGFloat = -1
        private var lastReportedScrollProgress: CGFloat = -1
        private var pendingScrollProgress: CGFloat?
        private var revealAfterLoad = false
        private var activeNavigation: WKNavigation?
        private var loadCount: Int = 0
        private var currentFilePath: String?
        private var scrollSyncEnabled = true
        private var lastConfiguredScrollSyncEnabled = true
        private var showsVerticalScroller = true
        private var hidesContentScrollbar = false
        private var linkedScrollEnabled = false
        private var onScrollProgressChanged: ((CGFloat) -> Void)?
        private var onLinkedScrollWheel: ((CGFloat) -> Void)?
        private var isApplyingProgrammaticScroll = false
        private var isNavigationInFlight = false
        private var programmaticScrollSuppressionUntil: Date?

        func configure(with configuration: Configuration) {
            scrollSyncEnabled = configuration.scrollSyncEnabled
            showsVerticalScroller = configuration.showsVerticalScroller
            hidesContentScrollbar = configuration.hidesContentScrollbar
            linkedScrollEnabled = configuration.linkedScrollEnabled
            onScrollProgressChanged = configuration.onScrollProgressChanged
            onLinkedScrollWheel = configuration.onLinkedScrollWheel
        }

        func updateScrollerVisibility(in webView: WKWebView) {
            guard let scrollView = webView.safeScrollView else { return }
            if scrollView.hasVerticalScroller != showsVerticalScroller {
                scrollView.hasVerticalScroller = showsVerticalScroller
            }
            if scrollView.autohidesScrollers != showsVerticalScroller {
                scrollView.autohidesScrollers = showsVerticalScroller
            }
        }

        func updateContentScrollbarVisibility(in webView: WKWebView) {
            let hideScrollbar = hidesContentScrollbar ? "true" : "false"
            let script = """
            (() => {
                const root = document.documentElement;
                if (!root) return;
                root.classList.toggle('muxy-hide-content-scrollbar', \(
                    hideScrollbar
                ));
                root.classList.toggle('muxy-linked-scroll', \(
                    linkedScrollEnabled ? "true" : "false"
                ));
            })();
            """
            webView.evaluateJavaScript(script) { _, error in
                if let error {
                    markdownWebLogger.error(
                        "Failed updating markdown content scrollbar visibility: \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }

        func installBridge(into configuration: WKWebViewConfiguration) {
            configuration.userContentController.removeScriptMessageHandler(forName: MarkdownWebBridge.scrollHandlerName)
            configuration.userContentController.removeScriptMessageHandler(forName: MarkdownWebBridge.wheelHandlerName)
            configuration.userContentController.removeAllUserScripts()
            configuration.userContentController.add(self, name: MarkdownWebBridge.scrollHandlerName)
            configuration.userContentController.add(self, name: MarkdownWebBridge.wheelHandlerName)
            configuration.userContentController.addUserScript(
                WKUserScript(
                    source: MarkdownWebBridge.scrollObserverScript,
                    injectionTime: .atDocumentEnd,
                    forMainFrameOnly: true
                )
            )
        }

        func removeScrollObserver() {
            isApplyingProgrammaticScroll = false
            programmaticScrollSuppressionUntil = nil
        }

        func loadHTML(_ html: String, filePath: String?, into webView: WKWebView) {
            lastHTML = html
            currentFilePath = filePath
            lastScrollProgress = -1
            loadCount += 1
            isNavigationInFlight = true
            markdownWebLogger.debug(
                "Markdown web load seq=\(self.loadCount) path=\(filePath ?? "<nil>", privacy: .public) htmlLength=\(html.utf8.count)"
            )
            activeNavigation = webView.loadHTMLString(html, baseURL: nil)
        }

        func updateHTML(
            _ html: String,
            scrollPosition: CGFloat,
            scrollSyncEnabled: Bool,
            filePath: String?,
            webView: WKWebView
        ) {
            let syncWasJustEnabled = scrollSyncEnabled && !lastConfiguredScrollSyncEnabled
            lastConfiguredScrollSyncEnabled = scrollSyncEnabled
            currentFilePath = filePath
            if html != lastHTML {
                lastHTML = html
                pendingScrollProgress = scrollSyncEnabled ? scrollPosition : nil
                revealAfterLoad = true
                webView.alphaValue = 0
                lastScrollProgress = -1
                loadCount += 1
                isNavigationInFlight = true
                markdownWebLogger.debug(
                    """
                    Markdown web update seq=\(self.loadCount)
                    path=\(filePath ?? "<nil>", privacy: .public)
                    htmlLength=\(html.utf8.count) pendingScrollProgress=\(scrollPosition)
                    """
                )
                activeNavigation = webView.loadHTMLString(html, baseURL: nil)
            } else if scrollSyncEnabled,
                      syncWasJustEnabled || scrollPosition != lastScrollProgress,
                      scrollPosition >= 0
            {
                applyScrollProgress(scrollPosition, to: webView)
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isNavigationInFlight = true
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
                """
                Markdown navigation didFinish
                seq=\(self.loadCount)
                path=\(self.currentFilePath ?? "<nil>", privacy: .public)
                """
            )
            isNavigationInFlight = false
            if let pending = pendingScrollProgress {
                pendingScrollProgress = nil
                applyScrollProgress(pending, to: webView) {
                    if self.revealAfterLoad {
                        webView.alphaValue = 1
                        self.revealAfterLoad = false
                    }
                }
            } else if revealAfterLoad {
                webView.alphaValue = 1
                revealAfterLoad = false
            }
            updateContentScrollbarVisibility(in: webView)
            collectJavaScriptErrors(from: webView)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            isNavigationInFlight = false
            logNavigationFailure(kind: "provisional", navigation: navigation, error: error)
            collectJavaScriptErrors(from: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isNavigationInFlight = false
            logNavigationFailure(kind: "navigation", navigation: navigation, error: error)
            collectJavaScriptErrors(from: webView)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            isNavigationInFlight = false
            markdownWebLogger.error(
                """
                Markdown web content process terminated
                path=\(self.currentFilePath ?? "<nil>", privacy: .public)
                reason=process-terminated
                """
            )
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == MarkdownWebBridge.wheelHandlerName {
                guard linkedScrollEnabled,
                      let payload = message.body as? [String: Any],
                      let deltaY = payload["deltaY"] as? Double
                else { return }
                onLinkedScrollWheel?(CGFloat(deltaY))
                return
            }

            guard message.name == MarkdownWebBridge.scrollHandlerName,
                  scrollSyncEnabled,
                  !isNavigationInFlight,
                  let progress = message.body as? Double
            else { return }

            let clampedProgress = min(max(CGFloat(progress), 0), 1)

            if let suppressionUntil = programmaticScrollSuppressionUntil, Date() < suppressionUntil {
                lastReportedScrollProgress = clampedProgress
                return
            }

            programmaticScrollSuppressionUntil = nil

            if isApplyingProgrammaticScroll, abs(clampedProgress - lastScrollProgress) <= 0.0005 {
                isApplyingProgrammaticScroll = false
                lastReportedScrollProgress = clampedProgress
                return
            }

            if isApplyingProgrammaticScroll {
                isApplyingProgrammaticScroll = false
                lastReportedScrollProgress = clampedProgress
                return
            }

            guard abs(lastReportedScrollProgress - clampedProgress) > 0.0005 else { return }
            lastReportedScrollProgress = clampedProgress
            lastScrollProgress = clampedProgress
            onScrollProgressChanged?(clampedProgress)
        }

        func applyScrollProgress(_ progress: CGFloat, to webView: WKWebView, completion: (() -> Void)? = nil) {
            guard progress >= 0 else {
                completion?()
                return
            }

            let clampedProgress = min(max(progress, 0), 1)
            guard abs(lastScrollProgress - clampedProgress) > 0.0005 else {
                completion?()
                return
            }

            isApplyingProgrammaticScroll = true
            programmaticScrollSuppressionUntil = Date().addingTimeInterval(Self.programmaticScrollSuppressionWindow)
            let script = MarkdownWebBridge.scrollToProgressScript(clampedProgress)
            webView.evaluateJavaScript(script) { _, error in
                if let error {
                    self.isApplyingProgrammaticScroll = false
                    self.programmaticScrollSuppressionUntil = nil
                    markdownWebLogger.error(
                        """
                        Failed applying markdown scroll progress
                        reason=\(error.localizedDescription, privacy: .public)
                        """
                    )
                    completion?()
                    return
                }

                self.lastScrollProgress = clampedProgress
                completion?()
            }
        }

        private func logNavigationFailure(kind: String, navigation: WKNavigation!, error: Error) {
            let nsError = error as NSError
            if let navigation, let activeNavigation, navigation !== activeNavigation {
                markdownWebLogger.debug(
                    """
                    Ignoring stale markdown \(kind, privacy: .public) failure
                    code=\(nsError.code) domain=\(nsError.domain, privacy: .public)
                    """
                )
                return
            }
            markdownWebLogger.error(
                """
                Markdown \(kind, privacy: .public) failure
                path=\(self.currentFilePath ?? "<nil>", privacy: .public)
                code=\(nsError.code) domain=\(nsError.domain, privacy: .public)
                reason=\(nsError.localizedDescription, privacy: .public)
                """
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
                        """
                        Failed collecting markdown JavaScript errors
                        reason=\(error.localizedDescription, privacy: .public)
                        """
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
                        """
                        Markdown JavaScript \(type, privacy: .public)
                        message=\(message, privacy: .public)
                        source=\(source, privacy: .public)
                        """
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
