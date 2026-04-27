import AppKit
import SwiftUI

@MainActor
struct AppBundleIconView: View {
    let appURL: URL
    let fallbackSystemName: String
    var size: CGFloat = 16

    var body: some View {
        if let image = AppBundleIconCache.shared.image(for: appURL) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: fallbackSystemName)
                .font(.system(size: size * 0.85, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
        }
    }
}

@MainActor
private final class AppBundleIconCache {
    static let shared = AppBundleIconCache()

    private let cache = NSCache<NSString, NSImage>()

    func image(for appURL: URL) -> NSImage? {
        let key = appURL.path as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let image = NSWorkspace.shared.icon(forFile: appURL.path)
        image.size = NSSize(width: 128, height: 128)
        cache.setObject(image, forKey: key)
        return image
    }
}
