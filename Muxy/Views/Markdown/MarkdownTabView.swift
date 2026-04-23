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

    static func scrollToLinkedEditorPositionScript(
        editorScrollY: CGFloat,
        editorMaxScrollY: CGFloat,
        progress: CGFloat
    ) -> String {
        let clampedEditorScrollY = max(editorScrollY, 0)
        let clampedEditorMaxScrollY = max(editorMaxScrollY, 0)
        let clampedProgress = min(max(progress, 0), 1)
        return """
        (() => {
            const root = document.getElementById('content')
                || document.scrollingElement
                || document.documentElement
                || document.body;
            if (!root) return;
            const previewMaxScrollY = Math.max(0, root.scrollHeight - root.clientHeight);
            if (previewMaxScrollY <= 0) {
                root.scrollTop = 0;
                return;
            }
            const editorScrollY = \(clampedEditorScrollY);
            const editorMaxScrollY = \(clampedEditorMaxScrollY);
            const fallbackProgress = \(clampedProgress);
            if (!Number.isFinite(editorScrollY) || !Number.isFinite(editorMaxScrollY) || editorMaxScrollY <= 0) {
                root.scrollTop = previewMaxScrollY * fallbackProgress;
                return;
            }
            const progress = Math.min(Math.max(editorScrollY / editorMaxScrollY, 0), 1);
            const extraScrollY = Math.max(0, previewMaxScrollY - editorMaxScrollY);
            const targetY = editorScrollY + Math.pow(progress, 2.2) * extraScrollY;
            root.scrollTop = Math.min(Math.max(targetY, 0), previewMaxScrollY);
        })();
        """
    }
}

struct MarkdownWebView: NSViewRepresentable {
    struct Configuration {
        let scrollSyncEnabled: Bool
        let showsVerticalScroller: Bool
        let hidesContentScrollbar: Bool
        let linkedScrollEnabled: Bool
        let editorScrollY: CGFloat
        let editorMaxScrollY: CGFloat
        let onScrollProgressChanged: ((CGFloat) -> Void)?
        let onLinkedScrollWheel: ((CGFloat) -> Void)?
        let onAnchorGeometryChanged: (([MarkdownPreviewAnchorGeometry]) -> Void)?
    }

    let html: String
    let filePath: String?
    @Binding var scrollPosition: CGFloat
    var editorScrollY: CGFloat = 0
    var editorMaxScrollY: CGFloat = 0
    var scrollSyncEnabled = true
    var showsVerticalScroller = true
    var hidesContentScrollbar = false
    var linkedScrollEnabled = false
    var onScrollProgressChanged: ((CGFloat) -> Void)?
    var onLinkedScrollWheel: ((CGFloat) -> Void)?
    var onAnchorGeometryChanged: (([MarkdownPreviewAnchorGeometry]) -> Void)?

    private var configuration: Configuration {
        Configuration(
            scrollSyncEnabled: scrollSyncEnabled,
            showsVerticalScroller: showsVerticalScroller,
            hidesContentScrollbar: hidesContentScrollbar,
            linkedScrollEnabled: linkedScrollEnabled,
            editorScrollY: editorScrollY,
            editorMaxScrollY: editorMaxScrollY,
            onScrollProgressChanged: onScrollProgressChanged,
            onLinkedScrollWheel: onLinkedScrollWheel,
            onAnchorGeometryChanged: onAnchorGeometryChanged
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
            context.coordinator.applyPreferredScroll(
                progress: scrollPosition,
                editorScrollY: editorScrollY,
                editorMaxScrollY: editorMaxScrollY,
                to: webView
            )
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
        webView.configuration.userContentController
            .removeScriptMessageHandler(forName: MarkdownPreviewAnchorGeometryBridge.geometryHandlerName)
        coordinator.removeScrollObserver()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private static let programmaticScrollSuppressionWindow: TimeInterval = 0.2

        private var lastHTML: String = ""
        private var lastScrollProgress: CGFloat = -1
        private var lastReportedScrollProgress: CGFloat = -1
        private var pendingScrollProgress: CGFloat?
        private var pendingEditorScrollY: CGFloat?
        private var pendingEditorMaxScrollY: CGFloat?
        private var activeNavigation: WKNavigation?
        private var loadCount: Int = 0
        private var currentFilePath: String?
        private var scrollSyncEnabled = true
        private var lastConfiguredScrollSyncEnabled = true
        private var showsVerticalScroller = true
        private var hidesContentScrollbar = false
        private var linkedScrollEnabled = false
        private var editorScrollY: CGFloat = 0
        private var editorMaxScrollY: CGFloat = 0
        private var onScrollProgressChanged: ((CGFloat) -> Void)?
        private var onLinkedScrollWheel: ((CGFloat) -> Void)?
        private var onAnchorGeometryChanged: (([MarkdownPreviewAnchorGeometry]) -> Void)?
        private var isApplyingProgrammaticScroll = false
        private var isNavigationInFlight = false
        private var programmaticScrollSuppressionUntil: Date?
        private var lastAnchorGeometrySnapshot: [MarkdownPreviewAnchorGeometry] = []

        func configure(with configuration: Configuration) {
            scrollSyncEnabled = configuration.scrollSyncEnabled
            showsVerticalScroller = configuration.showsVerticalScroller
            hidesContentScrollbar = configuration.hidesContentScrollbar
            linkedScrollEnabled = configuration.linkedScrollEnabled
            editorScrollY = configuration.editorScrollY
            editorMaxScrollY = configuration.editorMaxScrollY
            onScrollProgressChanged = configuration.onScrollProgressChanged
            onLinkedScrollWheel = configuration.onLinkedScrollWheel
            onAnchorGeometryChanged = configuration.onAnchorGeometryChanged
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
            configuration.userContentController.removeScriptMessageHandler(forName: MarkdownPreviewAnchorGeometryBridge.geometryHandlerName)
            configuration.userContentController.removeAllUserScripts()
            configuration.userContentController.add(self, name: MarkdownWebBridge.scrollHandlerName)
            configuration.userContentController.add(self, name: MarkdownWebBridge.wheelHandlerName)
            configuration.userContentController.add(self, name: MarkdownPreviewAnchorGeometryBridge.geometryHandlerName)
            configuration.userContentController.addUserScript(
                WKUserScript(
                    source: MarkdownWebBridge.scrollObserverScript,
                    injectionTime: .atDocumentEnd,
                    forMainFrameOnly: true
                )
            )
            configuration.userContentController.addUserScript(
                WKUserScript(
                    source: MarkdownPreviewAnchorGeometryBridge.observerScript,
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
                pendingEditorScrollY = scrollSyncEnabled ? editorScrollY : nil
                pendingEditorMaxScrollY = scrollSyncEnabled ? editorMaxScrollY : nil
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
                applyPreferredScroll(
                    progress: scrollPosition,
                    editorScrollY: editorScrollY,
                    editorMaxScrollY: editorMaxScrollY,
                    to: webView
                )
            }
        }

        @MainActor
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url
            else {
                decisionHandler(.allow)
                return
            }

            if let scheme = url.scheme?.lowercased(), ["http", "https", "mailto"].contains(scheme) {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.cancel)
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
            lastAnchorGeometrySnapshot = []
            if let pending = pendingScrollProgress {
                pendingScrollProgress = nil
                let pendingEditorScrollY = pendingEditorScrollY
                let pendingEditorMaxScrollY = pendingEditorMaxScrollY
                self.pendingEditorScrollY = nil
                self.pendingEditorMaxScrollY = nil
                applyPreferredScroll(
                    progress: pending,
                    editorScrollY: pendingEditorScrollY ?? editorScrollY,
                    editorMaxScrollY: pendingEditorMaxScrollY ?? editorMaxScrollY,
                    to: webView
                )
            }

            webView.evaluateJavaScript(
                MarkdownPreviewAnchorGeometryBridge.requestMeasureScript(reason: "swift-didFinish")
            ) { _, error in
                if let error {
                    markdownWebLogger.error(
                        "Failed requesting markdown anchor geometry: \(error.localizedDescription, privacy: .public)"
                    )
                }
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

            if message.name == MarkdownPreviewAnchorGeometryBridge.geometryHandlerName {
                guard !isNavigationInFlight else { return }
                handleAnchorGeometryMessage(message.body)
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

        func applyScrollProgress(_ progress: CGFloat, to webView: WKWebView) {
            guard progress >= 0 else { return }

            let clampedProgress = min(max(progress, 0), 1)
            guard abs(lastScrollProgress - clampedProgress) > 0.0005 else { return }

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
                    return
                }

                self.lastScrollProgress = clampedProgress
            }
        }

        func applyPreferredScroll(
            progress: CGFloat,
            editorScrollY: CGFloat,
            editorMaxScrollY: CGFloat,
            to webView: WKWebView
        ) {
            guard progress >= 0 else { return }
            _ = editorScrollY
            _ = editorMaxScrollY

            let clampedProgress = min(max(progress, 0), 1)
            applyScrollProgress(clampedProgress, to: webView)
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

        private func handleAnchorGeometryMessage(_ body: Any) {
            guard let payload = body as? [String: Any],
                  let entries = payload["anchors"] as? [[String: Any]]
            else {
                return
            }

            let geometries = entries.compactMap { entry -> MarkdownPreviewAnchorGeometry? in
                guard let anchorID = entry["anchorID"] as? String,
                      let topNumber = entry["top"] as? NSNumber,
                      let heightNumber = entry["height"] as? NSNumber
                else {
                    return nil
                }

                let startLine = (entry["startLine"] as? NSNumber)?.intValue
                let endLine = (entry["endLine"] as? NSNumber)?.intValue
                return MarkdownPreviewAnchorGeometry(
                    anchorID: anchorID,
                    startLine: startLine,
                    endLine: endLine,
                    top: CGFloat(truncating: topNumber),
                    height: CGFloat(truncating: heightNumber)
                )
            }.sorted(by: { lhs, rhs in
                if abs(lhs.top - rhs.top) > 0.5 {
                    return lhs.top < rhs.top
                }
                return lhs.anchorID < rhs.anchorID
            })

            guard geometrySnapshotIsMeaningfullyDifferent(from: lastAnchorGeometrySnapshot, to: geometries) else {
                return
            }

            lastAnchorGeometrySnapshot = geometries
            logAnchorGeometryIssuesIfNeeded(geometries)
            onAnchorGeometryChanged?(geometries)
        }

        private func geometrySnapshotIsMeaningfullyDifferent(
            from lhs: [MarkdownPreviewAnchorGeometry],
            to rhs: [MarkdownPreviewAnchorGeometry]
        ) -> Bool {
            if lhs.count != rhs.count {
                return true
            }

            for (left, right) in zip(lhs, rhs) {
                if left.anchorID != right.anchorID {
                    return true
                }
                if left.startLine != right.startLine || left.endLine != right.endLine {
                    return true
                }
                if abs(left.top - right.top) > 0.5 {
                    return true
                }
                if abs(left.height - right.height) > 0.5 {
                    return true
                }
            }

            return false
        }

        private func logAnchorGeometryIssuesIfNeeded(_ snapshot: [MarkdownPreviewAnchorGeometry]) {
            guard UserDefaults.standard.bool(forKey: "MuxyMarkdownAnchorGeometryDebug") else {
                return
            }

            if snapshot.isEmpty {
                markdownWebLogger.debug("Markdown anchor geometry snapshot empty")
                return
            }

            var previousTop: CGFloat?
            for geometry in snapshot {
                if let previousTop, geometry.top + 0.25 < previousTop {
                    markdownWebLogger.error(
                        "Markdown anchor geometry out of order anchorID=\(geometry.anchorID, privacy: .public) top=\(geometry.top)"
                    )
                    break
                }
                previousTop = geometry.top
            }

            markdownWebLogger.debug(
                "Markdown anchor geometry snapshot count=\(snapshot.count) first=\(snapshot.first?.anchorID ?? "<nil>") last=\(snapshot.last?.anchorID ?? "<nil>")"
            )
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
