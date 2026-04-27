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
                    Label {
                        Text("Open in \(defaultIDE.displayName)")
                    } icon: {
                        AppBundleIconView(appURL: defaultIDE.appURL, fallbackSystemName: defaultIDE.symbolName)
                    }
                }
            }

            if !installedApps.isEmpty {
                Divider()

                ForEach(installedApps) { ide in
                    Button {
                        open(ide)
                    } label: {
                        HStack {
                            Label {
                                Text(ide.displayName)
                            } icon: {
                                AppBundleIconView(appURL: ide.appURL, fallbackSystemName: ide.symbolName)
                            }
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
            Group {
                if let defaultIDE {
                    AppBundleIconView(appURL: defaultIDE.appURL, fallbackSystemName: defaultIDE.symbolName, size: 16)
                } else {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MuxyTheme.fgMuted)
                }
            }
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
                .accessibilityLabel(helpText)
        } else {
            Label {
                Text(defaultIDE.map { "Open in \($0.displayName)" } ?? "Open in IDE")
            } icon: {
                if let defaultIDE {
                    AppBundleIconView(appURL: defaultIDE.appURL, fallbackSystemName: defaultIDE.symbolName, size: 16)
                } else {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                }
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
