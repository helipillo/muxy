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
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(hoveredMenu ? MuxyTheme.hover : .clear)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(menuForeground)
            }
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
        .frame(width: 280, height: min(CGFloat(max(installedApps.count, 1)) * 28 + 44, 320))
        .background(MuxyTheme.bg)
    }

    @ViewBuilder
    private func menuSection(title: String, apps: [IDEIntegrationService.IDEApplication]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MuxyTheme.fgMuted)
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 2)

            ForEach(apps) { ide in
                menuButton(for: ide)
            }
        }
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
            HStack(spacing: 8) {
                AppBundleIconView(appURL: ide.appURL, fallbackSystemName: ide.symbolName, size: 15)
                Text(ide.displayName)
                    .font(.system(size: 12))
                if ide.bundleIdentifier == defaultIDE?.bundleIdentifier {
                    Spacer()
                    Text("Default")
                        .font(.system(size: 11))
                        .foregroundStyle(MuxyTheme.fgMuted)
                }
            }
            .foregroundStyle(MuxyTheme.fg)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
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
        return hoveredMenu ? .white : MuxyTheme.fgMuted
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
