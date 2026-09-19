import CoreText
import UIKit

/// Rajdhani, the condensed face the game's menus use, registered from the
/// resource bundle at launch; falls back to the system font if registration
/// fails so the app never renders blank text.
enum GameFont {
    enum Weight {
        case regular, medium, semibold, bold

        fileprivate var postScriptName: String {
            switch self {
            case .regular: return "Rajdhani-Regular"
            case .medium: return "Rajdhani-Medium"
            case .semibold: return "Rajdhani-SemiBold"
            case .bold: return "Rajdhani-Bold"
            }
        }

        fileprivate var systemWeight: UIFont.Weight {
            switch self {
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            }
        }
    }

    nonisolated(unsafe) private static var registered = false

    static func registerBundledFaces() {
        guard !registered else { return }
        registered = true
        let urls = ResourceLocator.urls(inSubdirectory: "Fonts", withExtension: "ttf")
        guard !urls.isEmpty else {
            AppLogger.error("No bundled fonts found; using system fallback", .ui)
            return
        }
        var count = 0
        for url in urls {
            var cfError: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &cfError) {
                count += 1
            } else if let error = cfError?.takeRetainedValue() {
                AppLogger.error("Font registration failed for \(url.lastPathComponent): \(error)", .ui)
            }
        }
        AppLogger.info("Registered \(count)/\(urls.count) Rajdhani faces", .ui)
    }

    static func display(_ size: CGFloat, _ weight: Weight = .bold) -> UIFont {
        UIFont(name: weight.postScriptName, size: size)
            ?? .systemFont(ofSize: size, weight: weight.systemWeight)
    }

    static func body(_ size: CGFloat, _ weight: Weight = .medium) -> UIFont {
        UIFont(name: weight.postScriptName, size: size)
            ?? .systemFont(ofSize: size, weight: weight.systemWeight)
    }

    static func mono(_ size: CGFloat, _ weight: UIFont.Weight = .semibold) -> UIFont {
        .monospacedSystemFont(ofSize: size, weight: weight)
    }
}

extension UILabel {
    /// Uppercase, letter-spaced text in the game's label style.
    func setTracked(_ text: String?, tracking: CGFloat, uppercase: Bool = true) {
        guard let text else {
            attributedText = nil
            return
        }
        let shown = uppercase ? text.uppercased() : text
        attributedText = NSAttributedString(
            string: shown,
            attributes: [.kern: tracking, .font: font as Any, .foregroundColor: textColor as Any]
        )
    }
}
