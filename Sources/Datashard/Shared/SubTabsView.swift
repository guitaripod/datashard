import UIKit

/// The Journal's second-level tabs (SHARDS 678 · MAIL 726 …): panel blocks with
/// a coloured left edge, the active one cyan.
final class SubTabsView: UIView {
    struct Tab: Hashable {
        let key: String
        let title: String
        var count: Int?
    }

    var onSelect: ((String) -> Void)?
    private(set) var selectedKey: String?
    private var tabs: [Tab] = []
    private var buttons: [String: UIButton] = [:]
    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .fill
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
        CGSize(width: UIView.noIntrinsicMetric, height: 40)
    }

    func setTabs(_ tabs: [Tab], selected: String) {
        self.tabs = tabs
        selectedKey = selected
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        buttons.removeAll()
        for tab in tabs {
            let button = UIButton(type: .custom)
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            button.addAction(UIAction { [weak self] _ in
                guard let self, selectedKey != tab.key else { return }
                selectedKey = tab.key
                refresh()
                onSelect?(tab.key)
            }, for: .touchUpInside)
            buttons[tab.key] = button
            stack.addArrangedSubview(button)
        }
        refresh()
    }

    func select(_ key: String) {
        selectedKey = key
        refresh()
        if let button = buttons[key] {
            scrollView.scrollRectToVisible(button.frame.insetBy(dx: -24, dy: 0), animated: true)
        }
    }

    func setCount(_ count: Int, for key: String) {
        guard let index = tabs.firstIndex(where: { $0.key == key }) else { return }
        tabs[index].count = count
        refresh()
    }

    private func refresh() {
        for tab in tabs {
            guard let button = buttons[tab.key] else { continue }
            let selected = tab.key == selectedKey
            var config = UIButton.Configuration.plain()
            config.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 12, bottom: 7, trailing: 12)
            let title = NSMutableAttributedString(
                string: tab.title.uppercased(),
                attributes: [.font: GameFont.display(14, .bold), .foregroundColor: selected ? Theme.cyan : Theme.ink2, .kern: 1.8]
            )
            if let count = tab.count {
                title.append(NSAttributedString(
                    string: "  \(count)",
                    attributes: [.font: GameFont.mono(11), .foregroundColor: Theme.dim]
                ))
            }
            config.attributedTitle = AttributedString(title)
            config.background.backgroundColor = selected ? Theme.panel2 : Theme.panel
            config.background.cornerRadius = 0
            button.configuration = config
            button.layer.sublayers?.filter { $0.name == "edge" }.forEach { $0.removeFromSuperlayer() }
            let edge = CALayer()
            edge.name = "edge"
            edge.backgroundColor = (selected ? Theme.cyan : Theme.line).cgColor
            edge.frame = CGRect(x: 0, y: 0, width: 2, height: 40)
            button.layer.addSublayer(edge)
        }
    }
}
