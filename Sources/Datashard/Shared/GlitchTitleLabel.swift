import UIKit

/// A big uppercase heading with the game's chromatic-aberration echo: the text
/// drawn once in dim red offset right and once in dim cyan offset left, under
/// the real ink.
final class GlitchTitleLabel: UIView {
    private let redEcho = UILabel()
    private let cyanEcho = UILabel()
    private let main = UILabel()

    var text: String? {
        didSet {
            for label in [redEcho, cyanEcho, main] {
                label.setTracked(text, tracking: tracking)
            }
            invalidateIntrinsicContentSize()
        }
    }
    var tracking: CGFloat = 1.6

    init(size: CGFloat) {
        super.init(frame: .zero)
        for (label, color, dx) in [(redEcho, Theme.redDim, 2.0), (cyanEcho, Theme.cyanDim, -2.0), (main, Theme.ink, 0.0)] {
            label.font = GameFont.display(size, .bold)
            label.textColor = color
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: dx),
                label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: dx),
                label.topAnchor.constraint(equalTo: topAnchor),
                label.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: CGSize { main.intrinsicContentSize }
}
