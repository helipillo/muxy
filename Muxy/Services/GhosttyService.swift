import Foundation
import AppKit
import GhosttyKit

@MainActor
final class GhosttyService {
    static let shared = GhosttyService()

    private(set) var app: ghostty_app_t?
    private(set) var config: ghostty_config_t?
    private var tickTimer: Timer?
    private let runtimeEvents: any GhosttyRuntimeEventHandling = GhosttyRuntimeEventAdapter()

    private init() {
        initializeGhostty()
    }

    private func initializeGhostty() {
        if getenv("NO_COLOR") != nil {
            unsetenv("NO_COLOR")
        }

        resolveGhosttyResources()

        let result = ghostty_init(UInt(CommandLine.argc), CommandLine.unsafeArgv)
        guard result == GHOSTTY_SUCCESS else {
            print("[Muxy] ghostty_init failed: \(result)")
            return
        }

        guard let cfg = ghostty_config_new() else {
            print("[Muxy] ghostty_config_new failed")
            return
        }

        ghostty_config_load_default_files(cfg)
        ghostty_config_finalize(cfg)

        var rt = ghostty_runtime_config_s()
        rt.userdata = Unmanaged.passUnretained(self).toOpaque()
        rt.supports_selection_clipboard = true
        rt.wakeup_cb = { _ in
            GhosttyService.shared.runtimeEvents.wakeup()
        }
        rt.action_cb = { app, target, action in
            return GhosttyService.shared.runtimeEvents.action(app: app, target: target, action: action)
        }
        rt.read_clipboard_cb = { userdata, location, state in
            GhosttyService.shared.runtimeEvents.readClipboard(userdata: userdata, location: location, state: state)
        }
        rt.confirm_read_clipboard_cb = { userdata, content, state, _ in
            GhosttyService.shared.runtimeEvents.confirmReadClipboard(userdata: userdata, content: content, state: state)
        }
        rt.write_clipboard_cb = { _, location, content, len, _ in
            GhosttyService.shared.runtimeEvents.writeClipboard(location: location, content: content, len: UInt(len))
        }
        rt.close_surface_cb = { userdata, needsConfirm in
            GhosttyService.shared.runtimeEvents.closeSurface(userdata: userdata, needsConfirm: needsConfirm)
        }

        guard let createdApp = ghostty_app_new(&rt, cfg) else {
            print("[Muxy] ghostty_app_new failed")
            ghostty_config_free(cfg)
            return
        }

        self.app = createdApp
        self.config = cfg

        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.tick()
            }
        }
        RunLoop.main.add(tickTimer!, forMode: .common)
    }

    var backgroundColor: NSColor {
        configColor("background") ?? NSColor(srgbRed: 0.11, green: 0.11, blue: 0.14, alpha: 1)
    }

    var foregroundColor: NSColor {
        configColor("foreground") ?? .white
    }

    private func configColor(_ key: String) -> NSColor? {
        guard let config else { return nil }
        var color = ghostty_config_color_s()
        guard ghostty_config_get(config, &color, key, UInt(key.lengthOfBytes(using: .utf8))) else {
            return nil
        }
        return NSColor(
            srgbRed: CGFloat(color.r) / 255,
            green: CGFloat(color.g) / 255,
            blue: CGFloat(color.b) / 255,
            alpha: 1
        )
    }

    func tick() {
        guard let app else { return }
        ghostty_app_tick(app)
    }

    private func resolveGhosttyResources() {
        guard getenv("GHOSTTY_RESOURCES_DIR") == nil else { return }

        let candidates = [
            "/Applications/Ghostty.app/Contents/Resources/ghostty",
            "\(NSHomeDirectory())/Applications/Ghostty.app/Contents/Resources/ghostty"
        ]

        for path in candidates {
            if FileManager.default.fileExists(atPath: "\(path)/shell-integration") {
                setenv("GHOSTTY_RESOURCES_DIR", path, 1)
                return
            }
        }
    }
}
