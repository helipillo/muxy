import AppKit

extension MuxyTheme {
    @MainActor static var nsFg: NSColor {
        GhosttyService.shared.foregroundColor
    }

    @MainActor static var nsAccent: NSColor {
        GhosttyService.shared.accentColor
    }
}
