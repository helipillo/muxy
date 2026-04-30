import SwiftUI

struct FileTreeIconButton: View {
    let action: () -> Void
    @Environment(\.iconScale) private var iconScale
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 13 * iconScale, weight: .semibold))
                .foregroundStyle(hovered ? MuxyTheme.fg : MuxyTheme.fgMuted)
                .frame(width: 24 * iconScale, height: 24 * iconScale)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityLabel("File Tree")
    }
}
