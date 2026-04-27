import AppKit
import SwiftUI

@MainActor
struct OpenInIDEControl: View {
    let projectPath: String?
    let filePath: String?
    let line: Int?
    let column: Int?
    var compact = true

    @ObservedObject private var ideService = IDEIntegrationService.shared
    @State private var hoveredPrimary = false
    @State private var hoveredMenu = false
    @State private var showingMenu = false

    var body: some View {
        if compact {
            compactSplitButton
        } else {
            expandedSplitButton
        }
    }

    private var compactSplitButton: some View {
        HStack(spacing: 0) {
            Button(action: openDefaultIDE) {
                Group {
                    if let defaultIDE {
                        AppBundleIconView(appURL: defaultIDE.appURL, fallbackSystemName: defaultIDE.symbolName, size: 16)
                    } else {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(primaryForeground)
                    }
                }
                .frame(width: 22, height: 24)
                .contentShape(Rectangle())
                .background(hoveredPrimary ? MuxyTheme.hover : .clear, in: RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .disabled(projectPath == nil || defaultIDE == nil)
            .onHover { hoveredPrimary = $0 }
            .help(helpText)
            .accessibilityLabel(helpText)

            menuToggleButton(width: 14)
        }
        .popover(isPresented: $showingMenu, arrowEdge: .bottom) {
            menuPopoverContent
        }
    }

    private var expandedSplitButton: some View {
        HStack(spacing: 0) {
            Button(action: openDefaultIDE) {
                HStack(spacing: 6) {
                    if let defaultIDE {
                        AppBundleIconView(appURL: defaultIDE.appURL, fallbackSystemName: defaultIDE.symbolName, size: 16)
                    } else {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                    }
                    Text(defaultIDE.map { "Open in \($0.displayName)" } ?? "Open in IDE")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(primaryForeground)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .contentShape(Rectangle())
                .background(hoveredPrimary ? MuxyTheme.hover : .clear, in: RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .disabled(projectPath == nil || defaultIDE == nil)
            .onHover { hoveredPrimary = $0 }
            .help(helpText)
            .accessibilityLabel(helpText)

            menuToggleButton(width: 18)
        }
        .popover(isPresented: $showingMenu, arrowEdge: .bottom) {
            menuPopoverContent
        }
    }

    private func menuToggleButton(width: CGFloat) -> some View {
        Button {
            guard projectPath != nil else { return }
            showingMenu.toggle()
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(menuForeground)
                .frame(width: width, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(projectPath == nil)
        .onHover { hoveredMenu = $0 }
        .help(menuHelpText)
    }

    private var menuPopoverContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if installedApps.isEmpty {
                    Text("No supported IDEs found")
                        .font(.system(size: 12))
                        .foregroundStyle(MuxyTheme.fgMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                } else {
                    if !editorApps.isEmpty {
                        menuSection(title: "Editors & IDEs", apps: editorApps)
                    }
                    if !otherToolApps.isEmpty {
                        menuSection(title: "Other Tools", apps: otherToolApps)
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .frame(width: menuPopoverWidth, height: min(CGFloat(max(installedApps.count, 1)) * 24 + 40, 280))
        .background(MuxyTheme.bg)
    }

    @ViewBuilder
    private func menuSection(title: String, apps: [IDEIntegrationService.IDEApplication]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MuxyTheme.fgMuted)
                .padding(.horizontal, 10)
                .padding(.top, 5)
                .padding(.bottom, 1)

            ForEach(apps) { ide in
                menuButton(for: ide)
            }
        }
    }

    private var menuPopoverWidth: CGFloat {
        let rowFont = NSFont.systemFont(ofSize: 12)
        let sectionFont = NSFont.systemFont(ofSize: 11, weight: .semibold)

        let appWidths = installedApps.map { textWidth($0.displayName, font: rowFont) }
        let sectionWidths = [
            textWidth("Editors & IDEs", font: sectionFont),
            textWidth("Other Tools", font: sectionFont),
            textWidth("No supported IDEs found", font: rowFont),
        ]

        let contentWidth = (appWidths + sectionWidths).max() ?? 0
        let paddedWidth = contentWidth + 48
        return min(max(220, paddedWidth), 380)
    }

    private func textWidth(_ text: String, font: NSFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return ceil((text as NSString).size(withAttributes: attributes).width)
    }

    private var installedApps: [IDEIntegrationService.IDEApplication] {
        ideService.installedApps
    }

    private var defaultIDE: IDEIntegrationService.IDEApplication? {
        ideService.defaultIDE
    }

    private var editorApps: [IDEIntegrationService.IDEApplication] {
        let apps = installedApps.filter { $0.group == .editor }
        return apps.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private var otherToolApps: [IDEIntegrationService.IDEApplication] {
        let apps = installedApps.filter { $0.group == .otherTool }
        return apps.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private func menuButton(for ide: IDEIntegrationService.IDEApplication) -> some View {
        Button {
            showingMenu = false
            open(ide)
        } label: {
            HStack(spacing: 7) {
                AppBundleIconView(appURL: ide.appURL, fallbackSystemName: ide.symbolName, size: 14)
                Text(ide.displayName)
                    .font(.system(size: 12))
            }
            .foregroundStyle(MuxyTheme.fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var helpText: String {
        guard projectPath != nil else { return "Open a project to enable IDE launching" }
        if let defaultIDE {
            return "Open in \(defaultIDE.displayName)"
        }
        return installedApps.isEmpty ? "No supported IDEs found" : "No default IDE available"
    }

    private var menuHelpText: String {
        guard projectPath != nil else { return "Open a project to choose an IDE" }
        return "Choose IDE"
    }

    private var primaryForeground: Color {
        if projectPath == nil || defaultIDE == nil {
            return MuxyTheme.fgMuted.opacity(0.45)
        }
        return hoveredPrimary ? MuxyTheme.fg : MuxyTheme.fgMuted
    }

    private var menuForeground: Color {
        if projectPath == nil {
            return MuxyTheme.fgMuted.opacity(0.45)
        }
        return hoveredMenu ? MuxyTheme.fg : MuxyTheme.fgMuted
    }

    private func openDefaultIDE() {
        guard let defaultIDE else { return }
        open(defaultIDE)
    }

    private func open(_ ide: IDEIntegrationService.IDEApplication) {
        guard let projectPath else { return }
        _ = ideService.openProject(
            at: projectPath,
            highlightingFileAt: filePath,
            line: line,
            column: column,
            in: ide
        )
    }
}
