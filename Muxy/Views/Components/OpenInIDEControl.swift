import SwiftUI

@MainActor
struct OpenInIDEControl: View {
    let projectPath: String?
    var compact = true

    @ObservedObject private var ideService = IDEIntegrationService.shared

    var body: some View {
        Menu {
            if let defaultIDE {
                Button {
                    open(defaultIDE)
                } label: {
                    Label("Open in \(defaultIDE.displayName)", systemImage: defaultIDE.symbolName)
                }
            }

            if !installedApps.isEmpty {
                Divider()

                ForEach(installedApps) { ide in
                    Button {
                        open(ide)
                    } label: {
                        HStack {
                            Label(ide.displayName, systemImage: ide.symbolName)
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
            Image(systemName: defaultIDE?.symbolName ?? "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MuxyTheme.fgMuted)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
                .accessibilityLabel(helpText)
        } else {
            Label(defaultIDE.map { "Open in \($0.displayName)" } ?? "Open in IDE", systemImage: defaultIDE?.symbolName ?? "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MuxyTheme.fgMuted)
                .contentShape(Rectangle())
                .accessibilityLabel(helpText)
        }
    }

    private func open(_ ide: IDEIntegrationService.IDEApplication) {
        guard let projectPath else { return }
        _ = ideService.openProject(at: projectPath, in: ide)
    }
}
