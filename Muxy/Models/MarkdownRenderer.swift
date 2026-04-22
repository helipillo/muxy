import AppKit
import Foundation
import os

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
    @MainActor
    static func html(
        content: String,
        filePath: String?,
        bgColor: NSColor,
        fgColor: NSColor,
        accentColor: NSColor
    ) -> String {
        let bgHex = colorToHex(bgColor)
        let fgHex = colorToHex(fgColor)
        let accentHex = colorToHex(accentColor)
        let borderHex = colorToHex(blend(foreground: fgColor, background: bgColor, amount: 0.2))
        let mutedHex = colorToHex(blend(foreground: fgColor, background: bgColor, amount: 0.65))
        let codeBgHex = colorToHex(blend(foreground: fgColor, background: bgColor, amount: 0.08))
        let rowAltHex = colorToHex(blend(foreground: fgColor, background: bgColor, amount: 0.04))
        let mermaidSecondaryHex = colorToHex(blend(foreground: fgColor, background: bgColor, amount: 0.12))
        let mermaidTertiaryHex = colorToHex(blend(foreground: fgColor, background: bgColor, amount: 0.18))
        let accentSoftHex = colorToHex(blend(foreground: accentColor, background: bgColor, amount: 0.22))
        let accentSubtleHex = colorToHex(blend(foreground: accentColor, background: bgColor, amount: 0.12))
        let accentMutedHex = colorToHex(blend(foreground: accentColor, background: bgColor, amount: 0.35))
        let accentStrongHex = colorToHex(blend(foreground: accentColor, background: bgColor, amount: 0.5))
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
        let preparedMermaidContent = MermaidCodeBlockNormalizer.normalizeMermaidCodeBlocks(in: content)
        let encodedPayload = Data(preparedMermaidContent.utf8).base64EncodedString()

        let title = escapeForHTML(filePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Markdown")
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(title)</title>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js" integrity="sha512-..." crossorigin="anonymous"></script>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/bash.min.js" crossorigin="anonymous"></script>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/swift.min.js" crossorigin="anonymous"></script>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/python.min.js" crossorigin="anonymous"></script>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/javascript.min.js" crossorigin="anonymous"></script>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/typescript.min.js" crossorigin="anonymous"></script>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/json.min.js" crossorigin="anonymous"></script>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/yaml.min.js" crossorigin="anonymous"></script>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/shell.min.js" crossorigin="anonymous"></script>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/marked/12.0.1/marked.min.js" integrity="sha512-..." crossorigin="anonymous"></script>
            <style>
                :root {
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
                .hljs { background: transparent !important; color: var(--fg) !important; }
                .hljs-comment,
                .hljs-quote { color: var(--muted) !important; }
                .hljs-keyword,
                .hljs-selector-tag,
                .hljs-subst { color: var(--accent) !important; }
                .hljs-string,
                .hljs-title,
                .hljs-name,
                .hljs-type,
                .hljs-attribute,
                .hljs-literal,
                .hljs-number,
                .hljs-symbol,
                .hljs-bullet,
                .hljs-built_in { color: var(--fg) !important; }
            </style>
        </head>
        <body>
            <div id="content">
                <div id="markdown" class="markdown-body"></div>
            </div>
            <script>
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

                var _mermaidInitialized = false;
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
                        'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js',
                        'https://unpkg.com/mermaid@10/dist/mermaid.min.js'
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

                async function renderMarkdown(content) {
                    marked.setOptions({
                        highlight: function(code, lang) {
                            if (lang && hljs.getLanguage(lang)) {
                                try {
                                    return hljs.highlight(code, { language: lang }).value;
                                } catch (_) {}
                            }
                            return hljs.highlightAuto(code).value;
                        },
                        breaks: false,
                        gfm: true,
                    });

                    // Replace Mermaid code blocks before marked parses them
                    var diagramMap = {};
                    content = content.replace(/```mermaid\\s*\\r?\\n([\\s\\S]*?)```/g, function(match, code) {
                        var id = 'mermaid-' + Object.keys(diagramMap).length;
                        diagramMap[id] = code.trim();
                        return '<div class=\"mermaid\" id=\"' + id + '\"></div>';
                    });

                    var html = marked.parse(content);
                    document.getElementById('markdown').innerHTML = html;
                    initializeMermaidControls();

                    // Apply syntax highlighting to non-mermaid code blocks
                    document.querySelectorAll('pre code:not(.hljs)').forEach(function(block) {
                        hljs.highlightElement(block);
                    });

                    // Render mermaid diagrams
                    if (Object.keys(diagramMap).length > 0) {
                        try {
                            var mermaidReady = await ensureMermaidLoaded();
                            if (mermaidReady && typeof mermaid !== 'undefined') {
                                if (!_mermaidInitialized) {
                                    mermaid.initialize({
                                        startOnLoad: false,
                                        theme: 'dark',
                                        themeVariables: \(mermaidThemeVariablesJSON)
                                    });
                                    _mermaidInitialized = true;
                                }
                                for (var id in diagramMap) {
                                    var el = document.getElementById(id);
                                    if (el) {
                                        try {
                                            var { svg } = await mermaid.render(id + '-svg', diagramMap[id]);
                                            el.innerHTML = svg;
                                        } catch (err) {
                                            el.innerHTML = '<div class="mermaid-error">Diagram Error: ' + (err.message || err) + '</div>';
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
                var markdownPayload = decodeBase64UTF8("\(encodedPayload)");
                renderMarkdown(markdownPayload).catch(function(err) {
                    window.__muxyErrors.push({
                        type: 'render-error',
                        message: String((err && err.message) ? err.message : err),
                        source: 'renderMarkdown'
                    });
                    console.error('renderMarkdown failed:', err);
                });
            </script>
        </body>
        </html>
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
