import UIKit

/// The faint CRT scanlines the game's menus sit behind. Lives on the window,
/// above everything, and never intercepts touches.
final class ScanlineOverlayView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundColor = UIColor(patternImage: Self.pattern())
        isOpaque = false
        observeStyleChanges()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func observeStyleChanges() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.backgroundColor = UIColor(patternImage: Self.pattern())
        }
    }

    private static func pattern() -> UIImage {
        let size = CGSize(width: 1, height: 3)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            Theme.scanline.setFill()
            ctx.fill(CGRect(x: 0, y: 2, width: 1, height: 1))
        }
    }
}
