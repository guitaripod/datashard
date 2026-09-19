import UIKit

/// Every subtitle line of one scene file in order, the searched line lit up.
final class SceneViewController: UIViewController {
    private let scene: String
    private let lines: [DialogueLine]
    private let highlight: Int
    private let scrollView = UIScrollView()
    private let column = UIStackView()
    private var highlightedView: UIView?

    init(scene: String, lines: [DialogueLine], highlight: Int) {
        self.scene = scene
        self.lines = lines
        self.highlight = highlight
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bg2
        title = ReaderText.humanize(scene)
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = NavigationStyle.barButton(
            symbol: "scope",
            action: UIAction { [weak self] _ in self?.scrollToHighlight(animated: true) }
        )

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.contentInset = UIEdgeInsets(top: 6, left: 0, bottom: 16, right: 0)
        view.addSubview(scrollView)
        column.axis = .vertical
        column.spacing = 6
        column.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(column)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            column.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            column.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: Theme.gutter),
            column.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -Theme.gutter),
            column.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            column.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -2 * Theme.gutter),
        ])
        let summary = UILabel()
        summary.font = GameFont.mono(11)
        summary.textColor = Theme.dim
        summary.setTracked("\(scene) · \(lines.count) lines", tracking: 1.4)
        column.addArrangedSubview(summary)
        for line in lines {
            let row = makeRow(line, lit: line.id == highlight)
            column.addArrangedSubview(row)
            if line.id == highlight { highlightedView = row }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollToHighlight(animated: false)
    }

    private func scrollToHighlight(animated: Bool) {
        guard let target = highlightedView else { return }
        let frame = target.convert(target.bounds, to: scrollView)
        let y = max(-scrollView.adjustedContentInset.top, frame.midY - scrollView.bounds.height / 2)
        scrollView.setContentOffset(CGPoint(x: 0, y: y), animated: animated)
    }

    private func makeRow(_ line: DialogueLine, lit: Bool) -> UIView {
        let panel = UIView()
        panel.backgroundColor = lit ? Theme.panel2 : Theme.panel
        let edge = UIView()
        edge.backgroundColor = lit ? Theme.yellow : Theme.line
        edge.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(edge)
        let label = UILabel()
        label.font = GameFont.body(16, lit ? .semibold : .medium)
        label.textColor = lit ? Theme.ink : Theme.ink2
        label.numberOfLines = 0
        label.text = line.line
        label.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(label)
        NSLayoutConstraint.activate([
            edge.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            edge.topAnchor.constraint(equalTo: panel.topAnchor),
            edge.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
            edge.widthAnchor.constraint(equalToConstant: 2),
            label.topAnchor.constraint(equalTo: panel.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -9),
            label.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),
        ])
        return panel
    }
}
