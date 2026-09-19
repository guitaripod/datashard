import UIKit

/// The game's pause-menu palette. Dark is the native look; light is a cream
/// "printed shard" variant with the same accents so the chrome reads the same.
enum Theme {
    static let bg = dynamic(dark: 0x07080A, light: 0xE9E6DA)
    static let bg2 = dynamic(dark: 0x0F1114, light: 0xF1EEE3)
    static let panel = dynamic(dark: 0x15181C, light: 0xF8F6EE)
    static let panel2 = dynamic(dark: 0x1C2025, light: 0xECE9DC)
    static let line = dynamic(dark: 0x2A2F36, light: 0xCFCABB)
    static let ink = dynamic(dark: 0xE9E5D6, light: 0x15171A)
    static let ink2 = dynamic(dark: 0xA9A698, light: 0x464A50)
    static let dim = dynamic(dark: 0x6C6F75, light: 0x7D8088)
    static let cyan = dynamic(dark: 0x4FE8F5, light: 0x0A8B99)
    static let cyanDim = dynamic(dark: 0x1E6B72, light: 0x9FD9DF)
    static let cyanInk = dynamic(dark: 0x052B2E, light: 0xFFFFFF)
    static let red = dynamic(dark: 0xFF4A5A, light: 0xC8102E)
    static let redDim = dynamic(dark: 0x5A1D24, light: 0xF0C5CB)
    static let yellow = dynamic(dark: 0xFCEE0A, light: 0xC9B900)
    static let onYellow = dynamic(dark: 0x07080A, light: 0x15171A)
    static let scanline = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.035)
            : UIColor.black.withAlphaComponent(0.035)
    }

    static let cut: CGFloat = 12
    static let cutSmall: CGFloat = 7
    static let padding: CGFloat = 16
    static let gutter: CGFloat = 12

    private static func dynamic(dark: UInt32, light: UInt32) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        }
    }
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
