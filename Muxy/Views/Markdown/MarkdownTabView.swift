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
            handler.postMessage({
                scrollTop: root.scrollTop,
                scrollHeight: root.scrollHeight,
                clientHeight: root.clientHeight,
            });
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

    static func scrollToSyncPointScript(_ point: MarkdownSyncPoint) -> String {
        let escapedAnchorID = point.anchorID
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let anchorLine = max(point.startLine, 1)
        let startLine = max(point.startLine, 1)
        let endLine = max(point.endLine, startLine)
        let progress = min(max(point.localProgress, 0), 1)
        return """
        (() => {
            const root = document.getElementById('content')
                || document.scrollingElement
                || document.documentElement
                || document.body;
            if (!root) return;

            const desiredStart = \(startLine);
            const desiredEnd = \(endLine);
            const desiredLine = \(anchorLine);
            const localProgress = \(progress);
            const desiredAnchorID = "\(escapedAnchorID)";

            const rootRect = root.getBoundingClientRect();
            const nodes = Array.from(document.querySelectorAll('[data-muxy-line-start][data-muxy-line-end]'));
            if (!nodes.length) return;

            const candidate = nodes.find(el => {
                const anchorID = el.getAttribute('data-muxy-anchor-id');
                return anchorID && anchorID === desiredAnchorID;
            }) || nodes.find(el => {
                const s = parseInt(el.getAttribute('data-muxy-line-start') || '0', 10);
                const e = parseInt(el.getAttribute('data-muxy-line-end') || '0', 10);
                return s === desiredStart && e === desiredEnd;
            }) || nodes.find(el => {
                const s = parseInt(el.getAttribute('data-muxy-line-start') || '0', 10);
                const e = parseInt(el.getAttribute('data-muxy-line-end') || '0', 10);
                return s <= desiredLine && desiredLine <= e;
            }) || nodes[0];

            const rect = candidate.getBoundingClientRect();
            const top = rect.top - rootRect.top + root.scrollTop;
            const height = Math.max(1, rect.height);
            const maxScrollTop = Math.max(0, root.scrollHeight - root.clientHeight);
            var target = top + localProgress * height;

            const firstNode = nodes[0];
            if (candidate === firstNode && localProgress <= 0.001) {
                target = 0;
            }

            target = Math.min(maxScrollTop, Math.max(0, target));

            window.__muxyProgrammaticScroll = true;
            root.scrollTop = target;
            setTimeout(() => { window.__muxyProgrammaticScroll = false; }, 180);
        })();
        """
    }
}

struct MarkdownWebView: NSViewRepresentable {
    struct Configuration {
        let scrollSyncEnabled: Bool
        let showsVerticalScroller: Bool
        let hidesContentScrollbar: Bool
        let syncScrollRequestVersion: Int
        let syncScrollRequest: MarkdownSyncPoint?
        let onSyncPointChanged: ((MarkdownSyncPoint) -> Void)?
        let onLayoutChanged: (() -> Void)?
        let onAnchorGeometryChanged: (([MarkdownPreviewAnchorGeometry]) -> Void)?
    }

    let html: String
    let filePath: String?
    @Binding var syncScrollRequest: MarkdownSyncPoint?
    let syncScrollRequestVersion: Int
    var scrollSyncEnabled = true
    var showsVerticalScroller = true
    var hidesContentScrollbar = false
    var onSyncPointChanged: ((MarkdownSyncPoint) -> Void)?
    var onLayoutChanged: (() -> Void)?
    var onAnchorGeometryChanged: (([MarkdownPreviewAnchorGeometry]) -> Void)?

    private var configuration: Configuration {
        Configuration(
            scrollSyncEnabled: scrollSyncEnabled,
            showsVerticalScroller: showsVerticalScroller,
            hidesContentScrollbar: hidesContentScrollbar,
            syncScrollRequestVersion: syncScrollRequestVersion,
            syncScrollRequest: syncScrollRequest,
            onSyncPointChanged: onSyncPointChanged,
            onLayoutChanged: onLayoutChanged,
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
                requestVersion: syncScrollRequestVersion,
                syncPoint: syncScrollRequest,
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
            syncScrollRequest: syncScrollRequest,
            syncScrollRequestVersion: syncScrollRequestVersion,
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
        private var lastAppliedSyncRequestVersion: Int = -1
        private var lastReportedScrollTop: CGFloat = -1
        private var pendingSyncPoint: MarkdownSyncPoint?
        private var pendingSyncRequestVersion: Int = -1
        private var activeNavigation: WKNavigation?
        private var loadCount: Int = 0
        private var currentFilePath: String?
        private var scrollSyncEnabled = true
        private var lastConfiguredScrollSyncEnabled = true
        private var showsVerticalScroller = true
        private var hidesContentScrollbar = false
        private var onSyncPointChanged: ((MarkdownSyncPoint) -> Void)?
        private var onLayoutChanged: (() -> Void)?
        private var onAnchorGeometryChanged: (([MarkdownPreviewAnchorGeometry]) -> Void)?
        private var isApplyingProgrammaticScroll = false
        private var isNavigationInFlight = false
        private var programmaticScrollSuppressionUntil: Date?
        private var lastAnchorGeometrySnapshot: [MarkdownPreviewAnchorGeometry] = []

        func configure(with configuration: Configuration) {
            scrollSyncEnabled = configuration.scrollSyncEnabled
            showsVerticalScroller = configuration.showsVerticalScroller
            hidesContentScrollbar = configuration.hidesContentScrollbar
            onSyncPointChanged = configuration.onSyncPointChanged
            onLayoutChanged = configuration.onLayoutChanged
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
            lastAppliedSyncRequestVersion = -1
            lastReportedScrollTop = -1
            loadCount += 1
            isNavigationInFlight = true
            markdownWebLogger.debug(
                "Markdown web load seq=\(self.loadCount) path=\(filePath ?? "<nil>", privacy: .public) htmlLength=\(html.utf8.count)"
            )
            activeNavigation = webView.loadHTMLString(html, baseURL: baseURL(for: filePath))
        }

        func updateHTML(
            _ html: String,
            syncScrollRequest: MarkdownSyncPoint?,
            syncScrollRequestVersion: Int,
            filePath: String?,
            webView: WKWebView
        ) {
            let syncWasJustEnabled = scrollSyncEnabled && !lastConfiguredScrollSyncEnabled
            lastConfiguredScrollSyncEnabled = scrollSyncEnabled
            currentFilePath = filePath
            if html != lastHTML {
                lastHTML = html
                pendingSyncPoint = scrollSyncEnabled ? syncScrollRequest : nil
                pendingSyncRequestVersion = scrollSyncEnabled ? syncScrollRequestVersion : -1
                lastAppliedSyncRequestVersion = -1
                loadCount += 1
                isNavigationInFlight = true
                markdownWebLogger.debug(
                    """
                    Markdown web update seq=\(self.loadCount)
                    path=\(filePath ?? "<nil>", privacy: .public)
                    htmlLength=\(html.utf8.count) pendingSyncRequestVersion=\(syncScrollRequestVersion)
                    """
                )
                activeNavigation = webView.loadHTMLString(html, baseURL: baseURL(for: filePath))
            } else if scrollSyncEnabled, syncWasJustEnabled || syncScrollRequestVersion != lastAppliedSyncRequestVersion {
                applyPreferredScroll(
                    requestVersion: syncScrollRequestVersion,
                    syncPoint: syncScrollRequest,
                    to: webView
                )
            }
        }

        private func baseURL(for filePath: String?) -> URL? {
            guard let filePath else { return nil }
            let fileURL = URL(fileURLWithPath: filePath)
            return fileURL.deletingLastPathComponent()
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
            if let pendingSyncPoint {
                let pendingRequestVersion = pendingSyncRequestVersion
                self.pendingSyncPoint = nil
                pendingSyncRequestVersion = -1
                applyPreferredScroll(
                    requestVersion: pendingRequestVersion,
                    syncPoint: pendingSyncPoint,
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
            if message.name == MarkdownPreviewAnchorGeometryBridge.geometryHandlerName {
                guard !isNavigationInFlight else { return }
                handleAnchorGeometryMessage(message.body)
                return
            }

            guard message.name == MarkdownWebBridge.scrollHandlerName,
                  scrollSyncEnabled,
                  !isNavigationInFlight,
                  let payload = message.body as? [String: Any],
                  let scrollTopNumber = payload["scrollTop"] as? NSNumber
            else { return }

            let scrollTop = CGFloat(truncating: scrollTopNumber)

            if let suppressionUntil = programmaticScrollSuppressionUntil, Date() < suppressionUntil {
                lastReportedScrollTop = scrollTop
                return
            }

            programmaticScrollSuppressionUntil = nil

            if isApplyingProgrammaticScroll, abs(scrollTop - lastReportedScrollTop) <= 0.5 {
                isApplyingProgrammaticScroll = false
                lastReportedScrollTop = scrollTop
                return
            }

            if isApplyingProgrammaticScroll {
                isApplyingProgrammaticScroll = false
                lastReportedScrollTop = scrollTop
                return
            }

            guard abs(lastReportedScrollTop - scrollTop) > 0.5 else { return }
            lastReportedScrollTop = scrollTop
            guard let point = syncPoint(forScrollTop: scrollTop, snapshot: lastAnchorGeometrySnapshot) else {
                return
            }
            onSyncPointChanged?(point)
        }

        func applyPreferredScroll(
            requestVersion: Int,
            syncPoint: MarkdownSyncPoint?,
            to webView: WKWebView
        ) {
            guard let syncPoint else { return }
            guard requestVersion != lastAppliedSyncRequestVersion else { return }

            isApplyingProgrammaticScroll = true
            programmaticScrollSuppressionUntil = Date().addingTimeInterval(Self.programmaticScrollSuppressionWindow)
            let script = MarkdownWebBridge.scrollToSyncPointScript(syncPoint)
            webView.evaluateJavaScript(script) { _, error in
                if let error {
                    self.isApplyingProgrammaticScroll = false
                    self.programmaticScrollSuppressionUntil = nil
                    markdownWebLogger.error(
                        """
                        Failed applying markdown sync scroll
                        reason=\(error.localizedDescription, privacy: .public)
                        """
                    )
                    return
                }

                self.lastAppliedSyncRequestVersion = requestVersion
            }
        }

        private func syncPoint(
            forScrollTop scrollTop: CGFloat,
            snapshot: [MarkdownPreviewAnchorGeometry]
        ) -> MarkdownSyncPoint? {
            struct GeometryCandidate {
                let geometry: MarkdownPreviewAnchorGeometry
                let startLine: Int
                let endLine: Int
            }

            let candidates: [GeometryCandidate] = snapshot.compactMap { geometry in
                guard let startLine = geometry.startLine, let endLine = geometry.endLine else {
                    return nil
                }
                return GeometryCandidate(geometry: geometry, startLine: startLine, endLine: endLine)
            }

            guard let first = candidates.first else {
                return nil
            }

            var active = first
            for candidate in candidates {
                if candidate.geometry.top <= scrollTop + 4 {
                    active = candidate
                    continue
                }
                break
            }

            let height = max(active.geometry.height, 1)
            let progress = min(max((scrollTop - active.geometry.top) / height, 0), 1)
            return MarkdownSyncPoint(
                anchorID: active.geometry.anchorID,
                startLine: active.startLine,
                endLine: active.endLine,
                localProgress: progress
            )
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
            onLayoutChanged?()
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

            let first = snapshot.first?.anchorID ?? "<nil>"
            let last = snapshot.last?.anchorID ?? "<nil>"
            markdownWebLogger.debug(
                "Markdown anchor geometry snapshot count=\(snapshot.count) first=\(first) last=\(last)"
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
