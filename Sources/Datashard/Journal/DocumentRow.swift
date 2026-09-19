import UIKit

/// A Journal list row: badge square, title, two-line excerpt, kicker on the
/// right, with the left edge telling read state (cyan unread, line read,
/// yellow bookmarked).
struct DocumentRowConfiguration: UIContentConfiguration, Hashable {
    let document: Document
    let isRead: Bool
    let isBookmarked: Bool
    let images: ImageStore

    func makeContentView() -> UIView & UIContentView {
        DocumentRowContentView(configuration: self)
    }

    func updated(for state: UIConfigurationState) -> DocumentRowConfiguration { self }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.document == rhs.document && lhs.isRead == rhs.isRead && lhs.isBookmarked == rhs.isBookmarked
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(document)
        hasher.combine(isRead)
        hasher.combine(isBookmarked)
    }
}

final class DocumentRowContentView: UIView, UIContentView {
    var configuration: UIContentConfiguration {
        didSet { apply() }
    }

    private let panel = UIView()
    private let edge = UIView()
    private let badge = UILabel()
    private let badgeBox = UIView()
    private let thumb = PictureView()
    private let titleLabel = UILabel()
    private let excerptLabel = UILabel()
    private let kickerLabel = UILabel()

    init(configuration: DocumentRowConfiguration) {
        self.configuration = configuration
        super.init(frame: .zero)
        setup()
        apply()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .clear
        panel.backgroundColor = Theme.panel
        panel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(panel)

        edge.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(edge)

        badgeBox.backgroundColor = Theme.panel2
        badgeBox.translatesAutoresizingMaskIntoConstraints = false
        badge.font = GameFont.mono(11, .bold)
        badge.textColor = Theme.cyan
        badge.textAlignment = .center
        badge.translatesAutoresizingMaskIntoConstraints = false
        badgeBox.addSubview(badge)
        thumb.translatesAutoresizingMaskIntoConstraints = false
        badgeBox.addSubview(thumb)

        titleLabel.font = GameFont.display(17, .bold)
        titleLabel.textColor = Theme.ink
        titleLabel.numberOfLines = 2

        excerptLabel.font = GameFont.body(14, .medium)
        excerptLabel.textColor = Theme.ink2
        excerptLabel.numberOfLines = 2

        kickerLabel.font = GameFont.mono(10)
        kickerLabel.textColor = Theme.dim
        kickerLabel.setContentHuggingPriority(.required, for: .horizontal)
        kickerLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let text = UIStackView(arrangedSubviews: [titleLabel, excerptLabel])
        text.axis = .vertical
        text.spacing = 3

        let row = UIStackView(arrangedSubviews: [badgeBox, text, kickerLabel])
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .top
        row.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(row)

        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            panel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            panel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Theme.gutter),
            panel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Theme.gutter),

            edge.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            edge.topAnchor.constraint(equalTo: panel.topAnchor),
            edge.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
            edge.widthAnchor.constraint(equalToConstant: 2),

            badgeBox.widthAnchor.constraint(equalToConstant: 48),
            badgeBox.heightAnchor.constraint(equalToConstant: 48),
            badge.centerXAnchor.constraint(equalTo: badgeBox.centerXAnchor),
            badge.centerYAnchor.constraint(equalTo: badgeBox.centerYAnchor),
            thumb.topAnchor.constraint(equalTo: badgeBox.topAnchor),
            thumb.bottomAnchor.constraint(equalTo: badgeBox.bottomAnchor),
            thumb.leadingAnchor.constraint(equalTo: badgeBox.leadingAnchor),
            thumb.trailingAnchor.constraint(equalTo: badgeBox.trailingAnchor),

            row.topAnchor.constraint(equalTo: panel.topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -10),
            row.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),
        ])
    }

    private func apply() {
        guard let c = configuration as? DocumentRowConfiguration else { return }
        badge.text = c.document.icon
        thumb.isHidden = c.document.listPicture == nil
        thumb.show(c.document.listPicture, from: c.images, fitting: 48)
        titleLabel.text = c.document.title
        excerptLabel.text = c.document.excerpt
        kickerLabel.setTracked(c.isBookmarked ? "Saved" : (c.isRead ? "Read" : c.document.kicker), tracking: 1.2)
        kickerLabel.textColor = c.isBookmarked ? Theme.yellow : Theme.dim
        edge.backgroundColor = c.isBookmarked ? Theme.yellow : (c.isRead ? Theme.line : Theme.cyanDim)
        titleLabel.textColor = c.isRead && !c.isBookmarked ? Theme.ink2 : Theme.ink
    }
}
