import UIKit

/// A horizontally scrolling row of uppercase chips; the selected one is a solid
/// yellow block, matching the game's filter rail.
final class ChipRail: UIView {
    struct Chip: Hashable {
        let key: String
        let title: String
        let count: Int?
    }

    var onSelect: ((String) -> Void)?
    private(set) var selectedKey: String?
    private var chips: [Chip] = []
    private var buttons: [String: UIButton] = [:]
    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: Theme.gutter),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -Theme.gutter),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 36)
    }

    func setChips(_ chips: [Chip], selected: String?) {
        self.chips = chips
        selectedKey = selected
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        buttons.removeAll()
        for chip in chips {
            let button = UIButton(type: .custom)
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            button.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                selectedKey = chip.key
                refresh()
                onSelect?(chip.key)
                scrollToSelected()
            }, for: .touchUpInside)
            buttons[chip.key] = button
            stack.addArrangedSubview(button)
        }
        refresh()
    }

    func select(_ key: String) {
        selectedKey = key
        refresh()
        scrollToSelected()
    }

    private func refresh() {
        for chip in chips {
            guard let button = buttons[chip.key] else { continue }
            let selected = chip.key == selectedKey
            var config = UIButton.Configuration.plain()
            config.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 10, bottom: 6, trailing: 10)
            let title = NSMutableAttributedString(
                string: chip.title.uppercased(),
                attributes: [.font: GameFont.mono(11), .foregroundColor: selected ? Theme.onYellow : Theme.ink2, .kern: 1.2]
            )
            if let count = chip.count {
                title.append(NSAttributedString(
                    string: "  \(count)",
                    attributes: [.font: GameFont.mono(10), .foregroundColor: selected ? Theme.onYellow : Theme.dim]
                ))
            }
            config.attributedTitle = AttributedString(title)
            config.background.backgroundColor = selected ? Theme.yellow : Theme.panel
            config.background.cornerRadius = 0
            button.configuration = config
        }
    }

    private func scrollToSelected() {
        guard let key = selectedKey, let button = buttons[key] else { return }
        scrollView.scrollRectToVisible(button.frame.insetBy(dx: -24, dy: 0), animated: true)
    }
}
