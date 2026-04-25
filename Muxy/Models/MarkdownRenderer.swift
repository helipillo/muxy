import AppKit
import Foundation
import os

private let markdownLogger = Logger(subsystem: "app.muxy", category: "MarkdownPreview")

private struct MermaidThemeVariables: Codable {
    let primaryColor: String
    let primaryTextColor: String
    let primaryBorderColor: String
    let textColor: String
    let lineColor: String
    let secondaryColor: String
    let tertiaryColor: String
    let background: String
    let mainBkg: String
    let secondBkg: String
    let tertiaryBkg: String
    let nodeBorder: String
    let clusterBkg: String
    let clusterBorder: String
    let defaultLinkColor: String
    let titleColor: String
    let edgeLabelBackground: String
    let nodeTextColor: String
    let labelTextColor: String
    let noteBkgColor: String
    let noteTextColor: String
    let noteBorderColor: String
    let actorBkg: String
    let actorBorder: String
    let actorTextColor: String
    let actorLineColor: String
    let signalColor: String
    let signalTextColor: String
    let labelBoxBkgColor: String
    let labelBoxBorderColor: String
    let loopTextColor: String
    let activationBorderColor: String
    let activationBkgColor: String
    let sequenceNumberColor: String
    let classText: String
    let entityBkgColor: String
    let entityBorderColor: String
    let entityTextColor: String
    let sectionBkgColor: String
    let altSectionBkgColor: String
    let sectionBkgColor2: String
    let taskBkgColor: String
    let taskTextColor: String
    let taskTextDarkColor: String
    let taskTextOutsideColor: String
    let taskTextClickableColor: String
    let activeTaskBkgColor: String
    let doneTaskBkgColor: String
    let doneTaskBorderColor: String
    let critBorderColor: String
    let critBkgColor: String
    let todayLineColor: String
    let personBorder: String
    let personBkg: String
    let pie1: String
    let pie2: String
    let pie3: String
    let pie4: String
    let pie5: String
    let pie6: String
    let pie7: String
    let pie8: String
    let pie9: String
    let pie10: String
    let pie11: String
    let pie12: String

    var jsObjectLiteral: String {
        guard let data = try? JSONEncoder().encode(self),
              let json = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return json
    }
}

enum MarkdownRenderer {
    struct Palette {
        let background: NSColor
        let foreground: NSColor
        let accent: NSColor
    }

    @MainActor
    static func html(
        anchors: [MarkdownSyncAnchor],
        filePath: String?,
        palette: Palette
    ) -> String {
        let bgHex = colorToHex(palette.background)
        let fgHex = colorToHex(palette.foreground)
        let accentHex = colorToHex(palette.accent)
        let borderHex = colorToHex(blend(foreground: palette.foreground, background: palette.background, amount: 0.2))
        let mutedHex = colorToHex(blend(foreground: palette.foreground, background: palette.background, amount: 0.65))
        let codeBgHex = colorToHex(blend(foreground: palette.foreground, background: palette.background, amount: 0.08))
        let rowAltHex = colorToHex(blend(foreground: palette.foreground, background: palette.background, amount: 0.04))
        let mermaidSecondaryHex = colorToHex(blend(foreground: palette.foreground, background: palette.background, amount: 0.12))
        let mermaidTertiaryHex = colorToHex(blend(foreground: palette.foreground, background: palette.background, amount: 0.18))
        let accentSoftHex = colorToHex(blend(foreground: palette.accent, background: palette.background, amount: 0.22))
        let accentSubtleHex = colorToHex(blend(foreground: palette.accent, background: palette.background, amount: 0.12))
        let accentMutedHex = colorToHex(blend(foreground: palette.accent, background: palette.background, amount: 0.35))
        let accentStrongHex = colorToHex(blend(foreground: palette.accent, background: palette.background, amount: 0.5))
        let mermaidThemeVariables = MermaidThemeVariables(
            primaryColor: "#\(accentHex)",
            primaryTextColor: "#\(fgHex)",
            primaryBorderColor: "#\(borderHex)",
            textColor: "#\(fgHex)",
            lineColor: "#\(mutedHex)",
            secondaryColor: "#\(mermaidSecondaryHex)",
            tertiaryColor: "#\(mermaidTertiaryHex)",
            background: "#\(bgHex)",
            mainBkg: "#\(codeBgHex)",
            secondBkg: "#\(mermaidSecondaryHex)",
            tertiaryBkg: "#\(mermaidTertiaryHex)",
            nodeBorder: "#\(borderHex)",
            clusterBkg: "#\(mermaidSecondaryHex)",
            clusterBorder: "#\(borderHex)",
            defaultLinkColor: "#\(mutedHex)",
            titleColor: "#\(fgHex)",
            edgeLabelBackground: "#\(codeBgHex)",
            nodeTextColor: "#\(fgHex)",
            labelTextColor: "#\(fgHex)",
            noteBkgColor: "#\(codeBgHex)",
            noteTextColor: "#\(fgHex)",
            noteBorderColor: "#\(borderHex)",
            actorBkg: "#\(mermaidSecondaryHex)",
            actorBorder: "#\(borderHex)",
            actorTextColor: "#\(fgHex)",
            actorLineColor: "#\(mutedHex)",
            signalColor: "#\(fgHex)",
            signalTextColor: "#\(fgHex)",
            labelBoxBkgColor: "#\(codeBgHex)",
            labelBoxBorderColor: "#\(borderHex)",
            loopTextColor: "#\(fgHex)",
            activationBorderColor: "#\(borderHex)",
            activationBkgColor: "#\(accentSubtleHex)",
            sequenceNumberColor: "#\(bgHex)",
            classText: "#\(fgHex)",
            entityBkgColor: "#\(codeBgHex)",
            entityBorderColor: "#\(borderHex)",
            entityTextColor: "#\(fgHex)",
            sectionBkgColor: "#\(mermaidSecondaryHex)",
            altSectionBkgColor: "#\(codeBgHex)",
            sectionBkgColor2: "#\(mermaidTertiaryHex)",
            taskBkgColor: "#\(accentSoftHex)",
            taskTextColor: "#\(fgHex)",
            taskTextDarkColor: "#\(bgHex)",
            taskTextOutsideColor: "#\(fgHex)",
            taskTextClickableColor: "#\(accentHex)",
            activeTaskBkgColor: "#\(accentMutedHex)",
            doneTaskBkgColor: "#\(mermaidTertiaryHex)",
            doneTaskBorderColor: "#\(borderHex)",
            critBorderColor: "#\(accentStrongHex)",
            critBkgColor: "#\(accentMutedHex)",
            todayLineColor: "#\(accentHex)",
            personBorder: "#\(borderHex)",
            personBkg: "#\(mermaidSecondaryHex)",
            pie1: "#\(accentHex)",
            pie2: "#\(accentMutedHex)",
            pie3: "#\(mermaidSecondaryHex)",
            pie4: "#\(mermaidTertiaryHex)",
            pie5: "#\(accentSoftHex)",
            pie6: "#\(accentStrongHex)",
            pie7: "#\(borderHex)",
            pie8: "#\(mutedHex)",
            pie9: "#\(codeBgHex)",
            pie10: "#\(accentSubtleHex)",
            pie11: "#\(mermaidSecondaryHex)",
            pie12: "#\(mermaidTertiaryHex)"
        )
        let mermaidThemeVariablesJSON = mermaidThemeVariables.jsObjectLiteral
        let isDarkPreview = isDarkColor(palette.background)
        let mermaidBaseTheme = isDarkPreview ? "dark" : "default"
        let colorScheme = isDarkPreview ? "dark" : "light"
        let codeBackground = blend(foreground: palette.foreground, background: palette.background, amount: 0.08)
        let syntaxCSS = SyntaxHTMLRenderer.cssStylesheet(background: codeBackground, foreground: palette.foreground)

        let title = escapeForHTML(filePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Markdown")
        let imageBaseHost = filePath.flatMap { encodedImageBaseHost(forMarkdownFilePath: $0) } ?? ""
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(title)</title>
            <script src="muxy-asset://markdown/marked.min.js"></script>
            <style>
                :root {
                    color-scheme: \(colorScheme);
                    --bg: #\(bgHex);
                    --fg: #\(fgHex);
                    --accent: #\(accentHex);
                    --border: #\(borderHex);
                    --muted: #\(mutedHex);
                    --code-bg: #\(codeBgHex);
                    --blockquote-border: #\(borderHex);
                    --row-alt: #\(rowAltHex);
                }
                * { box-sizing: border-box; margin: 0; padding: 0; }
                html, body {
                    background: var(--bg);
                    color: var(--fg);
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
                    font-size: 14px;
                    line-height: 1.6;
                    padding: 0;
                    margin: 0;
                    height: 100%;
                    overflow: hidden;
                }
                #content {
                    height: 100%;
                    overflow-y: auto;
                    padding: 24px 32px max(60px, 40vh) 32px;
                    box-sizing: border-box;
                }
                html.muxy-hide-content-scrollbar #content {
                    scrollbar-width: none;
                    -ms-overflow-style: none;
                    overscroll-behavior: none;
                }
                html.muxy-hide-content-scrollbar #content::-webkit-scrollbar {
                    width: 0;
                    height: 0;
                    display: none;
                }
                html.muxy-linked-scroll #content {
                    overflow-y: hidden;
                    overscroll-behavior: none;
                }
                .markdown-body {
                    max-width: 900px;
                    margin: 0 auto;
                    color: var(--fg);
                }
                .muxy-anchor-block {
                    display: block;
                    position: relative;
                }
                .markdown-body h1, .markdown-body h2, .markdown-body h3,
                .markdown-body h4, .markdown-body h5, .markdown-body h6 {
                    color: var(--fg);
                    font-weight: 600;
                    margin-top: 24px;
                    margin-bottom: 16px;
                    line-height: 1.25;
                }
                .markdown-body h1 { font-size: 2em; border-bottom: 1px solid var(--border); padding-bottom: 0.3em; }
                .markdown-body h2 { font-size: 1.5em; border-bottom: 1px solid var(--border); padding-bottom: 0.3em; }
                .markdown-body h3 { font-size: 1.25em; }
                .markdown-body h4 { font-size: 1em; }
                .markdown-body a { color: var(--accent); text-decoration: none; }
                .markdown-body a:hover { text-decoration: underline; }
                .markdown-body code {
                    background: var(--code-bg);
                    border-radius: 4px;
                    padding: 0.2em 0.4em;
                    font-size: 85%;
                    font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
                }
                .markdown-body pre {
                    background: var(--code-bg);
                    border: 1px solid var(--border);
                    border-radius: 6px;
                    padding: 16px;
                    overflow: auto;
                    margin: 16px 0;
                }
                .markdown-body pre code {
                    background: transparent;
                    padding: 0;
                    font-size: 90%;
                    border-radius: 0;
                    white-space: pre;
                }
                .markdown-body blockquote {
                    border-left: 4px solid var(--blockquote-border);
                    padding: 0 16px;
                    color: var(--muted);
                    margin: 16px 0;
                }
                .markdown-body table {
                    border-collapse: collapse;
                    width: 100%;
                    margin: 16px 0;
                }
                .markdown-body table th, .markdown-body table td {
                    border: 1px solid var(--border);
                    padding: 8px 13px;
                    text-align: left;
                }
                .markdown-body table th { background: var(--code-bg); font-weight: 600; }
                .markdown-body table tr:nth-child(even) { background: var(--row-alt); }
                .markdown-body img { max-width: 100%; border-radius: 4px; }
                .markdown-body ul, .markdown-body ol { padding-left: 2em; margin: 16px 0; }
                .markdown-body li { margin: 4px 0; }
                .markdown-body hr { border: none; border-top: 1px solid var(--border); margin: 24px 0; }
                .mermaid {
                    width: 100%;
                    margin: 16px 0;
                }
                .mermaid .mermaid-toolbar {
                    display: flex;
                    align-items: center;
                    gap: 6px;
                    justify-content: flex-end;
                    margin-bottom: 6px;
                    font-size: 11px;
                    color: var(--muted);
                }
                .mermaid .mermaid-btn {
                    border: 1px solid var(--border);
                    background: var(--code-bg);
                    color: var(--fg);
                    border-radius: 4px;
                    padding: 2px 6px;
                    cursor: pointer;
                    font-size: 11px;
                    line-height: 1.2;
                }
                .mermaid .mermaid-btn:hover {
                    border-color: var(--accent);
                }
                .mermaid .mermaid-zoom-label {
                    min-width: 42px;
                    text-align: center;
                    color: var(--muted);
                }
                .mermaid .mermaid-canvas {
                    width: 100%;
                    overflow: auto;
                }
                .mermaid svg {
                    display: block;
                    max-width: 100%;
                    width: 100%;
                    height: auto;
                    margin: 0 auto;
                }
                .mermaid[data-size-mode="natural"] svg {
                    max-width: none;
                    width: auto;
                }
                .mermaid svg[width],
                .mermaid svg[height] {
                    max-width: 100%;
                    height: auto;
                }
                .mermaid-error {
                    background: rgba(248, 81, 73, 0.1);
                    border: 1px solid rgba(248, 81, 73, 0.3);
                    border-radius: 6px;
                    padding: 12px 16px;
                    color: #f85149;
                    font-size: 13px;
                    margin: 16px 0;
                }
                .markdown-body pre.muxy-prehl { background: var(--code-bg); }
                .markdown-body pre.muxy-prehl code.muxy-hl { color: var(--fg); }
                \(syntaxCSS)
            </style>
        </head>
        <body>
            <div id="content">
                <div id="markdown" class="markdown-body"></div>
            </div>
            <script>
                window.__muxyImageBaseHost = "\(imageBaseHost)";
                window.__muxyErrors = window.__muxyErrors || [];
                window.addEventListener('error', function(event) {
                    try {
                        var target = event && event.target;
                        if (target && target.tagName === 'SCRIPT') {
                            window.__muxyErrors.push({
                                type: 'script-load',
                                message: 'Failed to load script',
                                source: target.src || ''
                            });
                            return;
                        }
                        window.__muxyErrors.push({
                            type: 'js-error',
                            message: (event && event.message) ? String(event.message) : 'Unknown JavaScript error',
                            source: (event && event.filename) ? String(event.filename) : ''
                        });
                    } catch (_) {}
                }, true);
                window.addEventListener('unhandledrejection', function(event) {
                    try {
                        var reason = event && event.reason;
                        var message = (reason && reason.message) ? reason.message : String(reason || 'Unhandled rejection');
                        window.__muxyErrors.push({
                            type: 'unhandled-rejection',
                            message: String(message),
                            source: ''
                        });
                    } catch (_) {}
                });

                var _markedConfigured = false;
                function decodeBase64UTF8(base64) {
                    try {
                        var binary = atob(base64);
                        var bytes = new Uint8Array(binary.length);
                        for (var i = 0; i < binary.length; i++) {
                            bytes[i] = binary.charCodeAt(i);
                        }
                        if (typeof TextDecoder !== 'undefined') {
                            return new TextDecoder('utf-8', { fatal: false }).decode(bytes);
                        }
                        var escaped = '';
                        for (var j = 0; j < bytes.length; j++) {
                            escaped += '%' + bytes[j].toString(16).padStart(2, '0');
                        }
                        return decodeURIComponent(escaped);
                    } catch (_) {
                        return '';
                    }
                }

                function escapeHTML(value) {
                    return String(value || '')
                        .replace(/&/g, '&amp;')
                        .replace(/</g, '&lt;')
                        .replace(/>/g, '&gt;')
                        .replace(/"/g, '&quot;')
                        .replace(/'/g, '&#39;');
                }

                function sanitizeURL(rawValue, options) {
                    var value = String(rawValue || '').trim();
                    if (!value) {
                        return null;
                    }

                    if (value.startsWith('#')) {
                        return value;
                    }

                    var lower = value.toLowerCase();
                    if (value.startsWith('//') || lower.startsWith('javascript:') || lower.startsWith('vbscript:')) {
                        return null;
                    }

                    var allowData = Boolean(options && options.allowData);
                    var allowBlob = Boolean(options && options.allowBlob);
                    if (lower.startsWith('data:')) {
                        return allowData ? value : null;
                    }
                    if (lower.startsWith('blob:')) {
                        return allowBlob ? value : null;
                    }

                    var hasExplicitScheme = /^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(value);
                    if (!hasExplicitScheme) {
                        return value;
                    }

                    try {
                        var resolved = new URL(value, document.baseURI);
                        if (['http:', 'https:', 'mailto:', 'file:'].includes(resolved.protocol)) {
                            return resolved.href;
                        }
                    } catch (_) {
                        return null;
                    }

                    return null;
                }

                function sanitizeMarkdownDOM(markdownRoot) {
                    if (!markdownRoot) {
                        return;
                    }

                    var blockedTags = new Set([
                        'script', 'iframe', 'object', 'embed', 'meta', 'link', 'style', 'base',
                        'form', 'input', 'button', 'textarea', 'select', 'option', 'frame',
                        'frameset', 'applet', 'svg', 'math'
                    ]);

                    var elements = Array.from(markdownRoot.querySelectorAll('*'));
                    elements.forEach(function(element) {
                        var tag = (element.tagName || '').toLowerCase();
                        if (!tag) {
                            return;
                        }

                        if (blockedTags.has(tag)) {
                            element.remove();
                            return;
                        }

                        Array.from(element.attributes).forEach(function(attribute) {
                            var name = String(attribute.name || '').toLowerCase();
                            if (!name) {
                                return;
                            }

                            if (name.startsWith('on') || name === 'srcdoc') {
                                element.removeAttribute(attribute.name);
                                return;
                            }

                            if (name === 'href') {
                                var safeHref = sanitizeURL(attribute.value, { allowData: false, allowBlob: false });
                                if (safeHref) {
                                    element.setAttribute(attribute.name, safeHref);
                                } else {
                                    element.removeAttribute(attribute.name);
                                }
                                return;
                            }

                            if (name === 'src') {
                                var isImageLike = ['img', 'source'].includes(tag);
                                var safeSrc = sanitizeURL(attribute.value, {
                                    allowData: isImageLike,
                                    allowBlob: isImageLike,
                                });
                                if (safeSrc) {
                                    element.setAttribute(attribute.name, safeSrc);
                                } else {
                                    element.removeAttribute(attribute.name);
                                }
                                return;
                            }

                            if (name === 'xlink:href') {
                                element.removeAttribute(attribute.name);
                            }
                        });
                    });
                }

                function loadScript(url) {
                    return new Promise(function(resolve, reject) {
                        var script = document.createElement('script');
                        script.src = url;
                        script.async = true;
                        script.onload = function() { resolve(true); };
                        script.onerror = function() { reject(new Error('Failed to load ' + url)); };
                        document.head.appendChild(script);
                    });
                }

                async function ensureMermaidLoaded() {
                    if (typeof mermaid !== 'undefined') {
                        return true;
                    }

                    var urls = [
                        'muxy-asset://markdown/mermaid.min.js'
                    ];

                    for (var i = 0; i < urls.length; i++) {
                        try {
                            await loadScript(urls[i]);
                            if (typeof mermaid !== 'undefined') {
                                return true;
                            }
                        } catch (_) {}
                    }

                    return false;
                }
                function initializeMermaidControls() {
                    var blocks = document.querySelectorAll('.mermaid');
                    blocks.forEach(function(block) {
                        var svg = block.querySelector('svg');
                        if (!svg) {
                            return;
                        }

                        var existingToolbars = block.querySelectorAll(':scope > .mermaid-toolbar');
                        if (existingToolbars.length > 1) {
                            for (var t = 1; t < existingToolbars.length; t++) {
                                existingToolbars[t].remove();
                            }
                        }

                        var existingCanvases = block.querySelectorAll(':scope > .mermaid-canvas');
                        if (existingCanvases.length > 1) {
                            for (var c = 1; c < existingCanvases.length; c++) {
                                existingCanvases[c].remove();
                            }
                        }

                        var toolbar = existingToolbars[0] || null;
                        var canvas = existingCanvases[0] || null;

                        if (block.dataset.controlsReady === 'true' && toolbar && canvas && canvas.contains(svg)) {
                            applyMermaidState(block, svg, toolbar);
                            return;
                        }

                        if (toolbar) {
                            toolbar.remove();
                        }

                        if (!(svg.parentElement && svg.parentElement.classList.contains('mermaid-canvas'))) {
                            if (!canvas) {
                                canvas = document.createElement('div');
                                canvas.className = 'mermaid-canvas';
                            }
                            if (svg.parentNode) {
                                svg.parentNode.insertBefore(canvas, svg);
                            } else {
                                block.appendChild(canvas);
                            }
                            canvas.appendChild(svg);
                        } else {
                            canvas = svg.parentElement;
                        }

                        toolbar = document.createElement('div');
                        toolbar.className = 'mermaid-toolbar';
                        toolbar.innerHTML = '' +
                            '<button class="mermaid-btn" data-action="toggle-size">Natural</button>' +
                            '<button class="mermaid-btn" data-action="zoom-out">-</button>' +
                            '<span class="mermaid-zoom-label">100%</span>' +
                            '<button class="mermaid-btn" data-action="zoom-in">+</button>' +
                            '<button class="mermaid-btn" data-action="zoom-reset">Reset</button>';

                        block.insertBefore(toolbar, canvas);

                        var viewBox = (svg.getAttribute('viewBox') || '').trim().split(/\\s+/);
                        var naturalWidth = parseFloat(svg.getAttribute('width'));
                        if (!isFinite(naturalWidth) || naturalWidth <= 0) {
                            naturalWidth = viewBox.length === 4 ? parseFloat(viewBox[2]) : NaN;
                        }
                        if (!isFinite(naturalWidth) || naturalWidth <= 0) {
                            naturalWidth = Math.max(400, svg.getBoundingClientRect().width || 800);
                        }

                        block.dataset.controlsReady = 'true';
                        block.dataset.sizeMode = 'fit';
                        block.dataset.zoom = '1';
                        block.dataset.naturalWidth = String(naturalWidth);

                        toolbar.addEventListener('click', function(event) {
                            var target = event.target;
                            var actionEl = null;
                            if (target && typeof target.closest === 'function') {
                                actionEl = target.closest('[data-action]');
                            }
                            if (!actionEl) {
                                return;
                            }
                            var action = actionEl.dataset.action;
                            if (!action) {
                                return;
                            }

                            event.preventDefault();
                            var zoom = parseFloat(block.dataset.zoom || '1');
                            var mode = block.dataset.sizeMode || 'fit';

                            if (action === 'toggle-size') {
                                mode = mode === 'fit' ? 'natural' : 'fit';
                                block.dataset.sizeMode = mode;
                            } else if (action === 'zoom-in') {
                                zoom = Math.min(4, zoom + 0.1);
                            } else if (action === 'zoom-out') {
                                zoom = Math.max(0.3, zoom - 0.1);
                            } else if (action === 'zoom-reset') {
                                zoom = 1;
                            }

                            block.dataset.zoom = String(zoom);
                            applyMermaidState(block, svg, toolbar);
                        });

                        applyMermaidState(block, svg, toolbar);
                    });
                }

                function applyMermaidState(block, svg, toolbar) {
                    var mode = block.dataset.sizeMode || 'fit';
                    var zoom = parseFloat(block.dataset.zoom || '1');
                    var naturalWidth = parseFloat(block.dataset.naturalWidth || '800');
                    var toggleBtn = toolbar.querySelector('[data-action="toggle-size"]');
                    var zoomLabel = toolbar.querySelector('.mermaid-zoom-label');

                    if (mode === 'fit') {
                        svg.style.width = (zoom * 100).toFixed(1).replace('.0', '') + '%';
                        svg.style.maxWidth = 'none';
                    } else {
                        svg.style.width = Math.max(120, naturalWidth * zoom) + 'px';
                        svg.style.maxWidth = 'none';
                    }
                    svg.style.height = 'auto';

                    if (toggleBtn) {
                        toggleBtn.textContent = mode === 'fit' ? 'Natural' : 'Fit';
                    }
                    if (zoomLabel) {
                        zoomLabel.textContent = Math.round(zoom * 100) + '%';
                    }
                }

                function detectAnchorKind(lines, index) {
                    var line = lines[index] || '';
                    var trimmed = line.trim();
                    if (!trimmed) {
                        return null;
                    }
                    if (/^ {0,3}(?:```+|~~~+)/.test(line)) {
                        var info = line.replace(/^ {0,3}(?:```+|~~~+)\\s*/, '').trim().toLowerCase();
                        return info === 'mermaid' ? 'mermaid' : 'fencedCode';
                    }
                    if (/^ {0,3}#{1,6}(?:\\s+|$)/.test(line)) {
                        return 'heading';
                    }
                    if (/^ {0,3}(?:[-*_])(?:\\s*[-*_]){2,}\\s*$/.test(line)) {
                        return 'thematicBreak';
                    }
                    if (/^ {0,3}>\\s?/.test(line)) {
                        return 'blockquote';
                    }
                    if (/^ {0,3}(?:[*+-]|\\d+[.)])\\s+/.test(line)) {
                        return 'list';
                    }
                    if (/^\\s*!\\[[^\\]]*\\]\\([^\\)]+\\)\\s*$/.test(line)) {
                        return 'image';
                    }
                    if (/\\|/.test(line)) {
                        var next = lines[index + 1] || '';
                        if (/^\\s*\\|?(?:\\s*:?-{3,}:?\\s*\\|)+\\s*:?-{3,}:?\\s*\\|?\\s*$/.test(next)) {
                            return 'table';
                        }
                    }
                    if (/^ {0,3}<(?!!--)([A-Za-z][\\w-]*)(\\s|>|$)/.test(line)) {
                        return 'htmlBlock';
                    }
                    return 'paragraph';
                }

                function consumeAnchor(lines, index, kind) {
                    var i = index;
                    if (kind === 'heading' || kind === 'thematicBreak' || kind === 'image' || kind === 'htmlBlock') {
                        return index;
                    }
                    if (kind === 'fencedCode' || kind === 'mermaid') {
                        var opener = lines[index] || '';
                        var openerMatch = opener.match(/^ {0,3}(```+|~~~+)/);
                        var fence = openerMatch ? openerMatch[1][0] : '`';
                        var minCount = openerMatch ? openerMatch[1].length : 3;
                        i = index + 1;
                        while (i < lines.length) {
                            var candidate = lines[i] || '';
                            var closeMatch = candidate.match(/^ {0,3}(```+|~~~+)\\s*$/);
                            if (closeMatch && closeMatch[1][0] === fence && closeMatch[1].length >= minCount) {
                                return i;
                            }
                            i += 1;
                        }
                        return lines.length - 1;
                    }
                    if (kind === 'blockquote') {
                        while (i + 1 < lines.length) {
                            var nextLine = lines[i + 1] || '';
                            if (!nextLine.trim()) {
                                i += 1;
                                continue;
                            }
                            if (!/^ {0,3}>\\s?/.test(nextLine)) {
                                break;
                            }
                            i += 1;
                        }
                        return i;
                    }
                    if (kind === 'list') {
                        while (i + 1 < lines.length) {
                            var listNext = lines[i + 1] || '';
                            if (!listNext.trim()) {
                                i += 1;
                                continue;
                            }
                            if (/^ {0,3}(?:[*+-]|\\d+[.)])\\s+/.test(listNext) || /^\\s{2,}\\S/.test(listNext)) {
                                i += 1;
                                continue;
                            }
                            break;
                        }
                        return i;
                    }
                    if (kind === 'table') {
                        i = index + 1;
                        while (i + 1 < lines.length) {
                            var tableNext = lines[i + 1] || '';
                            if (!tableNext.trim() || !/\\|/.test(tableNext)) {
                                break;
                            }
                            i += 1;
                        }
                        return i;
                    }
                    while (i + 1 < lines.length) {
                        var paragraphNext = lines[i + 1] || '';
                        if (!paragraphNext.trim()) {
                            break;
                        }
                        if (detectAnchorKind(lines, i + 1) !== 'paragraph') {
                            break;
                        }
                        i += 1;
                    }
                    return i;
                }

                function parseSyncAnchors(content) {
                    var lines = content.split(/\\r?\\n/);
                    var anchors = [];
                    var i = 0;
                    var sequence = 0;
                    while (i < lines.length) {
                        if (!(lines[i] || '').trim()) {
                            i += 1;
                            continue;
                        }
                        var kind = detectAnchorKind(lines, i) || 'other';
                        var end = consumeAnchor(lines, i, kind);
                        var startLine = i + 1;
                        var endLine = end + 1;
                        anchors.push({
                            id: 'muxy-anchor-' + String(sequence),
                            kind: kind,
                            startLine: startLine,
                            endLine: Math.max(startLine, endLine)
                        });
                        sequence += 1;
                        i = end + 1;
                    }
                    return anchors;
                }

                function inferElementKind(element) {
                    if (!element) {
                        return 'other';
                    }
                    var tag = (element.tagName || '').toLowerCase();
                    if (/^h[1-6]$/.test(tag)) {
                        return 'heading';
                    }
                    if (tag === 'ul' || tag === 'ol') {
                        return 'list';
                    }
                    if (tag === 'blockquote') {
                        return 'blockquote';
                    }
                    if (tag === 'pre') {
                        return 'fencedCode';
                    }
                    if (tag === 'table') {
                        return 'table';
                    }
                    if (tag === 'hr') {
                        return 'thematicBreak';
                    }
                    if (tag === 'img') {
                        return 'image';
                    }
                    if (tag === 'div' && element.classList.contains('mermaid')) {
                        return 'mermaid';
                    }
                    if (tag === 'p') {
                        var meaningfulNodes = Array.prototype.slice.call(element.childNodes).filter(function(node) {
                            if (node.nodeType === Node.TEXT_NODE) {
                                return Boolean((node.textContent || '').trim());
                            }
                            return true;
                        });
                        if (meaningfulNodes.length === 1
                            && meaningfulNodes[0].nodeType === Node.ELEMENT_NODE
                            && meaningfulNodes[0].tagName
                            && meaningfulNodes[0].tagName.toLowerCase() === 'img') {
                            return 'image';
                        }
                        return 'paragraph';
                    }
                    return 'other';
                }

                function collectAnchorElements(root) {
                    return Array.prototype.slice.call(root.children).filter(function(element) {
                        if (!element || !element.tagName) {
                            return false;
                        }
                        var tag = element.tagName.toLowerCase();
                        if (/^h[1-6]$/.test(tag)) {
                            return true;
                        }
                        return ['p', 'ul', 'ol', 'blockquote', 'pre', 'table', 'hr', 'img', 'div'].includes(tag);
                    });
                }

                function normalizeLocalImageSources(markdownRoot) {
                    if (!markdownRoot) {
                        return;
                    }
                    var baseHost = window.__muxyImageBaseHost || '';
                    var images = markdownRoot.querySelectorAll('img[src]');
                    images.forEach(function(image) {
                        var rawSrc = image.getAttribute('src');
                        if (!rawSrc) {
                            return;
                        }
                        var trimmed = rawSrc.trim();
                        if (!trimmed) {
                            return;
                        }
                        var lower = trimmed.toLowerCase();
                        var hasScheme = /^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(trimmed);
                        if (hasScheme || trimmed.startsWith('//') || lower.startsWith('data:') || lower.startsWith('blob:')) {
                            return;
                        }
                        if (!baseHost) {
                            return;
                        }
                        var relative = trimmed.replace(/^\\/+/, '');
                        var encodedRelative = relative.split('/').map(encodeURIComponent).join('/');
                        image.setAttribute('src', 'muxy-md-image://' + baseHost + '/' + encodedRelative);
                    });
                }

                function assignAnchorMetadata(markdownRoot, anchors) {
                    if (!markdownRoot || !anchors || !anchors.length) {
                        return;
                    }
                    var elements = collectAnchorElements(markdownRoot);
                    var anchorIndex = 0;
                    for (var i = 0; i < elements.length && anchorIndex < anchors.length; i++) {
                        var element = elements[i];
                        var elementKind = inferElementKind(element);
                        var selectedIndex = anchorIndex;
                        for (var lookahead = anchorIndex; lookahead < Math.min(anchorIndex + 6, anchors.length); lookahead++) {
                            if (anchors[lookahead].kind === elementKind) {
                                selectedIndex = lookahead;
                                break;
                            }
                        }
                        var anchor = anchors[selectedIndex];
                        anchorIndex = selectedIndex + 1;
                        var target = element;
                        if (['mermaid', 'image', 'fencedCode', 'table'].includes(elementKind)) {
                            var wrapper = document.createElement('div');
                            wrapper.className = 'muxy-anchor-block muxy-anchor-kind-' + elementKind;
                            if (element.parentNode) {
                                element.parentNode.insertBefore(wrapper, element);
                                wrapper.appendChild(element);
                                target = wrapper;
                            }
                        }
                        target.setAttribute('data-muxy-anchor-id', anchor.id);
                        target.setAttribute('data-muxy-line-start', String(anchor.startLine));
                        target.setAttribute('data-muxy-line-end', String(anchor.endLine));
                    }
                }

                function imageCacheKey(image) {
                    if (!image) {
                        return '';
                    }
                    var src = image.getAttribute('src') || image.currentSrc || '';
                    var alt = image.getAttribute('alt') || '';
                    return src + '||' + alt;
                }

                function syncImageAttributes(sourceImage, targetImage) {
                    if (!sourceImage || !targetImage) {
                        return;
                    }

                    Array.from(targetImage.attributes).forEach(function(attribute) {
                        if (!sourceImage.hasAttribute(attribute.name)) {
                            targetImage.removeAttribute(attribute.name);
                        }
                    });

                    Array.from(sourceImage.attributes).forEach(function(attribute) {
                        if (attribute.name === 'src' && targetImage.getAttribute('src') === attribute.value) {
                            return;
                        }
                        targetImage.setAttribute(attribute.name, attribute.value);
                    });
                }

                function preserveExistingImages(markdownRoot, nextRoot) {
                    if (!markdownRoot || !nextRoot) {
                        return;
                    }

                    var imagePool = new Map();
                    markdownRoot.querySelectorAll('img[src]').forEach(function(image) {
                        var key = imageCacheKey(image);
                        if (!key) {
                            return;
                        }
                        if (!imagePool.has(key)) {
                            imagePool.set(key, []);
                        }
                        imagePool.get(key).push(image);
                    });

                    nextRoot.querySelectorAll('img[src]').forEach(function(image) {
                        var key = imageCacheKey(image);
                        var candidates = key ? imagePool.get(key) : null;
                        if (!candidates || !candidates.length) {
                            return;
                        }

                        var existingImage = candidates.shift();
                        syncImageAttributes(image, existingImage);
                        image.replaceWith(existingImage);
                    });
                }

                async function renderMarkdown(content) {
                    var anchors = parseSyncAnchors(content);
                    if (!_markedConfigured) {
                        marked.use({
                            walkTokens: function(token) {
                                if (!token || typeof token !== 'object') {
                                    return;
                                }

                                if (token.type === 'link') {
                                    var safeHref = sanitizeURL(token.href, { allowData: false, allowBlob: false });
                                    if (safeHref) {
                                        token.href = safeHref;
                                    } else {
                                        delete token.href;
                                    }
                                }

                                if (token.type === 'image') {
                                    var safeSrc = sanitizeURL(token.href, { allowData: true, allowBlob: true });
                                    if (safeSrc) {
                                        token.href = safeSrc;
                                    } else {
                                        delete token.href;
                                    }
                                }
                            }
                        });
                        _markedConfigured = true;
                    }
                    marked.setOptions({
                        breaks: false,
                        gfm: true,
                    });

                    var diagramMap = {};
                    content = content.replace(/```mermaid\\s*\\r?\\n([\\s\\S]*?)```/g, function(match, code) {
                        var id = 'mermaid-' + Object.keys(diagramMap).length;
                        diagramMap[id] = code.trim();
                        return '<div class=\"mermaid\" id=\"' + id + '\" data-muxy-mermaid=\"true\"></div>';
                    });

                    var html = marked.parse(content);
                    var markdownRoot = document.getElementById('markdown');
                    var nextRoot = document.createElement('div');
                    nextRoot.innerHTML = html;
                    sanitizeMarkdownDOM(nextRoot);
                    normalizeLocalImageSources(nextRoot);
                    preserveExistingImages(markdownRoot, nextRoot);

                    var fragment = document.createDocumentFragment();
                    while (nextRoot.firstChild) {
                        fragment.appendChild(nextRoot.firstChild);
                    }
                    markdownRoot.replaceChildren(fragment);

                    assignAnchorMetadata(markdownRoot, anchors);
                    initializeMermaidControls();

                    if (Object.keys(diagramMap).length > 0) {
                        try {
                            var mermaidReady = await ensureMermaidLoaded();
                            if (mermaidReady && typeof mermaid !== 'undefined') {
                                mermaid.initialize({
                                    startOnLoad: false,
                                    theme: '\(mermaidBaseTheme)',
                                    themeVariables: \(mermaidThemeVariablesJSON)
                                });
                                for (var id in diagramMap) {
                                    var el = document.getElementById(id);
                                    if (el) {
                                        try {
                                            var { svg } = await mermaid.render(id + '-svg', diagramMap[id]);
                                            el.innerHTML = svg;
                                        } catch (err) {
                                            el.innerHTML = '<div class="mermaid-error">Diagram Error: '
                                                + escapeHTML(err.message || err)
                                                + '</div>';
                                        }
                                    }
                                }
                                initializeMermaidControls();
                            } else {
                                for (var id in diagramMap) {
                                    var el = document.getElementById(id);
                                    if (el) {
                                        el.innerHTML = '<div class="mermaid-error">'
                                            + 'Mermaid.js not loaded. '
                                            + 'Check your internet connection or CDN access.'
                                            + '</div>';
                                    }
                                }
                            }
                        } catch (err) {
                            console.error('Mermaid render error:', err);
                        }
                    }
                }
                window.__muxyRenderMarkdown = function(base64Payload) {
                    var markdownPayload = decodeBase64UTF8(String(base64Payload || ''));
                    renderMarkdown(markdownPayload).catch(function(err) {
                        window.__muxyErrors.push({
                            type: 'render-error',
                            message: String((err && err.message) ? err.message : err),
                            source: 'renderMarkdown'
                        });
                        console.error('renderMarkdown failed:', err);
                    });
                    return true;
                };
            </script>
        </body>
        </html>
        """
    }

    static func updateScript(content: String) -> String {
        let preparedMermaidContent = MermaidCodeBlockNormalizer.normalizeMermaidCodeBlocks(in: content)
        let preparedContent = MarkdownCodeBlockHighlighter.prerenderCodeBlocks(in: preparedMermaidContent)
        let encodedPayload = Data(preparedContent.utf8).base64EncodedString()
        return """
        (() => {
            if (typeof window.__muxyRenderMarkdown !== 'function') {
                return false;
            }
            return window.__muxyRenderMarkdown("\(encodedPayload)");
        })();
        """
    }

    private static func colorToHex(_ color: NSColor) -> String {
        let colorSpaces: [NSColorSpace] = [.sRGB, .extendedSRGB, .deviceRGB, .genericRGB]
        for colorSpace in colorSpaces {
            if let rgb = color.usingColorSpace(colorSpace) {
                let r = Int(round(rgb.redComponent * 255))
                let g = Int(round(rgb.greenComponent * 255))
                let b = Int(round(rgb.blueComponent * 255))
                return String(format: "%02X%02X%02X", max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))
            }
        }

        markdownLogger.error("Failed to convert NSColor to RGB hex, using fallback")
        return "1E1E1E"
    }

    private static func encodedImageBaseHost(forMarkdownFilePath path: String) -> String? {
        let directory = URL(fileURLWithPath: path).deletingLastPathComponent().standardizedFileURL.path
        guard let data = directory.data(using: .utf8) else { return nil }
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func isDarkColor(_ color: NSColor) -> Bool {
        guard let rgb = color.usingColorSpace(.sRGB) else { return false }
        let luminance = 0.2126 * rgb.redComponent + 0.7152 * rgb.greenComponent + 0.0722 * rgb.blueComponent
        return luminance < 0.5
    }

    private static func blend(foreground: NSColor, background: NSColor, amount: CGFloat) -> NSColor {
        let a = max(0, min(1, amount))
        guard let fg = foreground.usingColorSpace(.sRGB),
              let bg = background.usingColorSpace(.sRGB)
        else {
            return foreground.withAlphaComponent(a)
        }

        let r = bg.redComponent + (fg.redComponent - bg.redComponent) * a
        let g = bg.greenComponent + (fg.greenComponent - bg.greenComponent) * a
        let b = bg.blueComponent + (fg.blueComponent - bg.blueComponent) * a
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    private static func escapeForHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
