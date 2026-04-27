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

            Menu {
                menuContent
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(hoveredMenu ? MuxyTheme.hover : .clear)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(menuForeground)
                }
                .frame(width: 14, height: 24)
                .contentShape(Rectangle())
                .onHover { hoveredMenu = $0 }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .disabled(projectPath == nil)
            .help(menuHelpText)
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

            Menu {
                menuContent
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(hoveredMenu ? MuxyTheme.hover : .clear)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(menuForeground)
                }
                .frame(width: 18, height: 24)
                .contentShape(Rectangle())
                .onHover { hoveredMenu = $0 }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .disabled(projectPath == nil)
            .help(menuHelpText)
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        if installedApps.isEmpty {
            Button("No supported IDEs found") {}
                .disabled(true)
        } else {
            if !editorApps.isEmpty {
                Section("Editors & IDEs") {
                    ForEach(editorApps) { ide in
                        menuButton(for: ide)
                    }
                }
            }

            if !otherToolApps.isEmpty {
                Section("Other Tools") {
                    ForEach(otherToolApps) { ide in
                        menuButton(for: ide)
                    }
                }
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

    @ViewBuilder
    private func menuButton(for ide: IDEIntegrationService.IDEApplication) -> some View {
        Button {
            open(ide)
        } label: {
            HStack(spacing: 8) {
                AppBundleIconView(appURL: ide.appURL, fallbackSystemName: ide.symbolName, size: 15)
                Text(ide.displayName)
                if ide.bundleIdentifier == defaultIDE?.bundleIdentifier {
                    Spacer()
                    Text("Default")
                }
            }
        }
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
