import SwiftUI

@MainActor
struct OpenInIDEControl: View {
    let projectPath: String?
    let filePath: String?
    let line: Int?
    let column: Int?
    var compact = true

    @ObservedObject private var ideService = IDEIntegrationService.shared

    var body: some View {
        Menu {
            if let defaultIDE {
                Button {
                    open(defaultIDE)
                } label: {
                    HStack(spacing: 8) {
                        AppBundleIconView(appURL: defaultIDE.appURL, fallbackSystemName: defaultIDE.symbolName, size: 14)
                        Text("Open in \(defaultIDE.displayName)")
                    }
                }
            }

            if !installedApps.isEmpty {
                Divider()

                ForEach(installedApps) { ide in
                    Button {
                        open(ide)
                    } label: {
                        HStack(spacing: 8) {
                            AppBundleIconView(appURL: ide.appURL, fallbackSystemName: ide.symbolName, size: 14)
                            Text(ide.displayName)
                            if ide.bundleIdentifier == defaultIDE?.bundleIdentifier {
                                Spacer()
                                Text("Default")
                            }
                        }
                    }
                }
            } else {
                Button("No supported IDEs found") {}
                    .disabled(true)
            }

            Divider()

            Button("Refresh IDE List") {
                ideService.refreshInstalledApps()
            }
        } label: {
            label
        }
        .menuStyle(.borderlessButton)
        .disabled(projectPath == nil)
        .help(helpText)
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
        return installedApps.isEmpty ? "No supported IDEs found" : "Open in IDE"
    }

    @ViewBuilder
    private var label: some View {
        if compact {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MuxyTheme.fgMuted)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
                .accessibilityLabel(helpText)
        } else {
            HStack(spacing: 8) {
                if let defaultIDE {
                    AppBundleIconView(appURL: defaultIDE.appURL, fallbackSystemName: defaultIDE.symbolName, size: 14)
                } else {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                }
                Text(defaultIDE.map { "Open in \($0.displayName)" } ?? "Open in IDE")
            }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MuxyTheme.fgMuted)
                .contentShape(Rectangle())
                .accessibilityLabel(helpText)
        }
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
