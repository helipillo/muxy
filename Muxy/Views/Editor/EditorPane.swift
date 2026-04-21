import SwiftUI

struct EditorPane: View {
    @Bindable var state: EditorTabState
    let focused: Bool
    let onFocus: () -> Void
    @Environment(GhosttyService.self) private var ghostty
    @State private var editorSettings = EditorSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            EditorBreadcrumb(state: state)
            Rectangle().fill(MuxyTheme.border).frame(height: 1)
            if state.awaitingLargeFileConfirmation {
                largeFileConfirmation
            } else if state.isLoading {
                loadingView
            } else if let error = state.errorMessage {
                errorView(error)
            } else {
                editorContentLayer
            }
        }
        .background(MuxyTheme.bg)
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { onFocus() })
        .onReceive(NotificationCenter.default.publisher(for: .findInTerminal)) { _ in
            guard focused else { return }
            if state.isMarkdownFile, state.markdownViewMode == .preview {
                state.markdownViewMode = .code
            }
            if !state.currentSelection.isEmpty {
                state.searchNeedle = state.currentSelection
            }
            state.searchVisible = true
            state.searchFocusVersion += 1
        }
    }

    private var editorContentLayer: some View {
        ZStack(alignment: .topTrailing) {
            editorMainContent

            if state.isIncrementalLoading {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("Loading full file...")
                        .font(.system(size: 11))
                        .foregroundStyle(MuxyTheme.fgMuted)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(MuxyTheme.bg.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(MuxyTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.top, 6)
                .padding(.trailing, state.searchVisible && showsCodeEditor ? 260 : 8)
            }

            if state.searchVisible, showsCodeEditor {
                EditorSearchBar(
                    state: state,
                    onNext: {
                        state.navigateSearch(.next)
                    },
                    onPrevious: {
                        state.navigateSearch(.previous)
                    },
                    onReplace: {
                        state.requestReplaceCurrent()
                    },
                    onReplaceAll: {
                        state.requestReplaceAll()
                    },
                    onClose: {
                        state.searchVisible = false
                        state.editorFocusVersion += 1
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var editorMainContent: some View {
        if state.isMarkdownFile {
            switch state.markdownViewMode {
            case .code:
                codeEditorContainer
            case .preview:
                markdownPreviewContainer
            case .split:
                HSplitView {
                    codeEditorContainer
                    markdownPreviewContainer
                }
            }
        } else {
            codeEditorContainer
        }
    }

    private var codeEditorContainer: some View {
        HStack(spacing: 0) {
            CodeEditorView(
                state: state,
                editorSettings: editorSettings,
                themeVersion: ghostty.configVersion,
                focused: focused,
                searchNeedle: state.searchNeedle,
                searchNavigationVersion: state.searchNavigationVersion,
                searchNavigationDirection: state.searchNavigationDirection,
                searchCaseSensitive: state.searchCaseSensitive,
                searchUseRegex: state.searchUseRegex,
                replaceText: state.replaceText,
                replaceVersion: state.replaceVersion,
                replaceAllVersion: state.replaceAllVersion,
                editorFocusVersion: state.editorFocusVersion
            )
        }
    }

    private var markdownPreviewContainer: some View {
        MarkdownWebView(
            html: renderedMarkdownHTML,
            filePath: state.filePath,
            scrollPosition: $state.markdownScrollPosition,
            scrollSyncEnabled: state.markdownViewMode == .split && state.markdownScrollSyncEnabled,
            onScrollProgressChanged: { progress in
                guard state.markdownViewMode == .split, state.markdownScrollSyncEnabled else { return }
                guard abs(state.markdownScrollPosition - progress) > 0.0005 else { return }
                state.markdownScrollPosition = progress
            }
        )
        .background(MuxyTheme.bg)
    }

    private var renderedMarkdownHTML: String {
        MarkdownRenderer.html(
            content: state.backingStore?.fullText() ?? "",
            filePath: state.filePath,
            bgColor: ghostty.backgroundColor,
            fgColor: ghostty.foregroundColor,
            accentColor: ghostty.accentColor
        )
    }

    private var showsCodeEditor: Bool {
        !state.isMarkdownFile || state.markdownViewMode != .preview
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView().controlSize(.small)
            Spacer()
        }
    }

    private var largeFileConfirmation: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(MuxyTheme.fgMuted)
            Text("Large File")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MuxyTheme.fg)
            Text("This file is \(formattedLargeFileSize). Large files may slow down the editor.")
                .font(.system(size: 12))
                .foregroundStyle(MuxyTheme.fgMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            HStack(spacing: 8) {
                Button("Cancel") {
                    state.cancelLargeFileOpen()
                }
                .keyboardShortcut(.cancelAction)
                Button("Open Anyway") {
                    state.confirmLargeFileOpen()
                }
                .keyboardShortcut(.defaultAction)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var formattedLargeFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: state.largeFileSize)
    }

    private func errorView(_ error: String) -> some View {
        VStack {
            Spacer()
            Text(error)
                .font(.system(size: 12))
                .foregroundStyle(MuxyTheme.diffRemoveFg)
            Spacer()
        }
    }
}

private struct EditorMarkdownModePicker: View {
    @Binding var mode: EditorMarkdownViewMode
    @Binding var scrollSyncEnabled: Bool

    var body: some View {
        HStack(spacing: 2) {
            ForEach(EditorMarkdownViewMode.allCases, id: \.self) { candidate in
                Button {
                    mode = candidate
                } label: {
                    Image(systemName: candidate.symbol)
                        .font(.system(size: 10, weight: .medium))
                        .frame(width: 22, height: 20)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(mode == candidate ? MuxyTheme.surface : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help(candidate.title)
                .accessibilityLabel("Markdown \(candidate.title) View")
            }

            if mode == .split {
                Rectangle()
                    .fill(MuxyTheme.border)
                    .frame(width: 1, height: 14)
                    .padding(.horizontal, 2)
                EditorMarkdownScrollSyncButton(isEnabled: $scrollSyncEnabled)
            }
        }
        .padding(2)
        .background(MuxyTheme.bg)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(MuxyTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct EditorMarkdownScrollSyncButton: View {
    @Binding var isEnabled: Bool

    var body: some View {
        Button {
            isEnabled.toggle()
        } label: {
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(isEnabled ? MuxyTheme.accent : MuxyTheme.fgMuted)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 28, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isEnabled ? MuxyTheme.surface : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isEnabled ? MuxyTheme.accent.opacity(0.35) : Color.clear, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isEnabled ? "Disable Scroll Sync" : "Enable Scroll Sync")
        .accessibilityLabel(isEnabled ? "Disable Markdown Scroll Sync" : "Enable Markdown Scroll Sync")
    }
}

private struct EditorBreadcrumb: View {
    @Bindable var state: EditorTabState

    private var relativePath: String {
        let full = state.filePath
        let base = state.projectPath
        guard full.hasPrefix(base) else { return state.fileName }
        var rel = String(full.dropFirst(base.count))
        if rel.hasPrefix("/") { rel = String(rel.dropFirst()) }
        return rel
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "doc.text")
                .font(.system(size: 10))
                .foregroundStyle(MuxyTheme.fgDim)
            Text(relativePath)
                .font(.system(size: 11))
                .foregroundStyle(MuxyTheme.fgMuted)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            if state.isModified {
                Circle()
                    .fill(MuxyTheme.fg)
                    .frame(width: 6, height: 6)
            }
            if state.isReadOnly {
                Label("Read-only", systemImage: "lock.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MuxyTheme.diffHunkFg)
            }
            Spacer()
            if state.isMarkdownFile {
                EditorMarkdownModePicker(
                    mode: $state.markdownViewMode,
                    scrollSyncEnabled: $state.markdownScrollSyncEnabled
                )
                .padding(.trailing, 6)
            }
            Text("Ln \(state.cursorLine), Col \(state.cursorColumn)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(MuxyTheme.fgDim)
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(MuxyTheme.bg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(breadcrumbAccessibilityLabel)
    }

    private var breadcrumbAccessibilityLabel: String {
        var label = relativePath
        if state.isModified { label += ", modified" }
        if state.isReadOnly { label += ", read-only" }
        label += ", Line \(state.cursorLine), Column \(state.cursorColumn)"
        return label
    }
}
