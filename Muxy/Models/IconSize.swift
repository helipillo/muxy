import CoreGraphics
import Foundation

enum IconSize: String, CaseIterable, Identifiable {
    case normal
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: "Normal"
        case .large: "Large"
        }
    }

    var scale: CGFloat {
        switch self {
        case .normal: 1.0
        case .large: 1.3
        }
    }

    static let storageKey = "muxy.iconSize"
    static let defaultValue: IconSize = .normal

    static var current: IconSize {
        guard let raw = UserDefaults.standard.string(forKey: storageKey),
              let size = IconSize(rawValue: raw)
        else { return defaultValue }
        return size
    }
}
