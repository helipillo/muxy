import SwiftUI

struct ProviderIconView: View {
    let iconName: String
    let size: CGFloat

    var body: some View {
        if let image = loadProviderImage(named: iconName) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.8))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
        }
    }

    private func loadProviderImage(named name: String) -> NSImage? {
        if let iconsURL = Bundle.providerIconsURL {
            let fileURL = iconsURL.appendingPathComponent("\(name).svg")
            if let image = NSImage(contentsOf: fileURL) {
                return image
            }
        }

        if let url = Bundle.appResources.url(forResource: name, withExtension: "svg") ??
            Bundle.main.url(forResource: name, withExtension: "svg")
        {
            return NSImage(contentsOf: url)
        }

        return nil
    }
}
