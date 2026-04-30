import SwiftUI

struct IconButton: View {
    let symbol: String
    var size: CGFloat = 13
    var color: Color = MuxyTheme.fgMuted
    var hoverColor: Color = MuxyTheme.fg
    let accessibilityLabel: String
    let action: () -> Void
    @Environment(\.iconScale) private var iconScale
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * iconScale, weight: .semibold))
                .foregroundStyle(hovered ? hoverColor : color)
                .frame(width: 24 * iconScale, height: 24 * iconScale)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityLabel(accessibilityLabel)
    }
}
