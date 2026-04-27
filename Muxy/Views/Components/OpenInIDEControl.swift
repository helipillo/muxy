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
                        AppBundleIconView(appURL: defaultIDE.appURL, fallbackSystemName: defaultIDE.symbolName, size: 12)
                    } else {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(primaryForeground)
                    }
                }
                .frame(width: 20, height: 24)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(projectPath == nil || defaultIDE == nil)
            .onHover { hoveredPrimary = $0 }
            .help(helpText)
            .accessibilityLabel(helpText)

            Menu {
                menuContent
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(menuForeground)
                    .frame(width: 14, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .disabled(projectPath == nil)
            .onHover { hoveredMenu = $0 }
            .help(menuHelpText)
        }
    }

    private var expandedSplitButton: some View {
        HStack(spacing: 0) {
            Button(action: openDefaultIDE) {
                HStack(spacing: 6) {
                    if let defaultIDE {
                        AppBundleIconView(appURL: defaultIDE.appURL, fallbackSystemName: defaultIDE.symbolName, size: 12)
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
            }
            .buttonStyle(.plain)
            .disabled(projectPath == nil || defaultIDE == nil)
            .onHover { hoveredPrimary = $0 }
            .help(helpText)
            .accessibilityLabel(helpText)

            Menu {
                menuContent
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(menuForeground)
                    .frame(width: 18, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .disabled(projectPath == nil)
            .onHover { hoveredMenu = $0 }
            .help(menuHelpText)
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        if installedApps.isEmpty {
            Button("No supported IDEs found") {}
                .disabled(true)
        } else {
            ForEach(installedApps) { ide in
                Button {
                    open(ide)
                } label: {
                    HStack(spacing: 8) {
                        AppBundleIconView(appURL: ide.appURL, fallbackSystemName: ide.symbolName, size: 12)
                        Text(ide.displayName)
                        if ide.bundleIdentifier == defaultIDE?.bundleIdentifier {
                            Spacer()
                            Text("Default")
                        }
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
