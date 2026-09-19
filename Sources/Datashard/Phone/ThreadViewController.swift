import UIKit

/// One contact's whole message history in journal order: conversation titles
/// as section rules, messages as cyan-edged panels, and V's reply options as
/// the game's picker block. The dataset carries no sender on messages, so
/// nothing is guessed about who said what.
final class ThreadViewController: UIViewController {
    private let contact: Contact
    private let store: JournalStore
    private let scrollView = UIScrollView()
    private let column = UIStackView()

    init(contact: Contact, store: JournalStore) {
        self.contact = contact
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bg2
        title = contact.name
        navigationItem.largeTitleDisplayMode = .never

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.contentInset = UIEdgeInsets(top: 6, left: 0, bottom: 16, right: 0)
        view.addSubview(scrollView)
        column.axis = .vertical
        column.spacing = 8
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
        load()
    }

    private func load() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let lines = try await store.phoneLines(for: contact)
                render(lines)
            } catch {
                AppLogger.error("Loading thread for \(contact.name) failed: \(error)", .dataset)
            }
        }
    }

    private func render(_ lines: [PhoneLine]) {
        column.arrangedSubviews.forEach { $0.removeFromSuperview() }
        column.addArrangedSubview(makeSummary(lines))
        var currentConversation: String?
        var pendingChoices: [PhoneLine] = []

        func flushChoices() {
            guard !pendingChoices.isEmpty else { return }
            column.addArrangedSubview(makePicker(pendingChoices))
            pendingChoices.removeAll()
        }

        for line in lines {
            if line.conversation != currentConversation {
                flushChoices()
                currentConversation = line.conversation
                column.addArrangedSubview(makeConversationRule(line.conversation))
            }
            switch line.kind {
            case .choice:
                pendingChoices.append(line)
            case .message:
                flushChoices()
                column.addArrangedSubview(makeMessage(line))
            }
        }
        flushChoices()
    }

    private func makeSummary(_ lines: [PhoneLine]) -> UIView {
        let label = UILabel()
        label.font = GameFont.mono(11)
        label.textColor = Theme.dim
        let threads = Set(lines.map(\.conversation)).count
        let kind = contact.contactType.map { " · " + $0 } ?? ""
        label.setTracked("\(lines.count) lines · \(threads) conversations\(kind)", tracking: 1.4)
        return label
    }

    private func makeConversationRule(_ title: String) -> UIView {
        let label = UILabel()
        label.font = GameFont.mono(10)
        label.textColor = Theme.dim
        label.textAlignment = .center
        label.numberOfLines = 2
        label.setTracked(title.isEmpty ? "conversation" : title, tracking: 1.6)
        let wrap = UIView()
        label.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -4),
            label.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -8),
        ])
        return wrap
    }

    private func makeMessage(_ line: PhoneLine) -> UIView {
        let panel = CutCornerView()
        panel.cut = Theme.cutSmall
        panel.fill = line.questImportant ? Theme.panel2 : Theme.panel
        let edge = UIView()
        edge.backgroundColor = Theme.cyan
        edge.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(edge)
        let label = UILabel()
        label.font = GameFont.body(16, .medium)
        label.textColor = Theme.ink
        label.numberOfLines = 0
        label.text = line.text
        label.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(label)
        let wrap = UIView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(panel)
        NSLayoutConstraint.activate([
            edge.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            edge.topAnchor.constraint(equalTo: panel.topAnchor),
            edge.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
            edge.widthAnchor.constraint(equalToConstant: 2),
            label.topAnchor.constraint(equalTo: panel.topAnchor, constant: 9),
            label.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -10),
            label.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),
            panel.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
            panel.topAnchor.constraint(equalTo: wrap.topAnchor),
            panel.bottomAnchor.constraint(equalTo: wrap.bottomAnchor),
            panel.widthAnchor.constraint(lessThanOrEqualTo: wrap.widthAnchor, multiplier: 0.86),
        ])
        return wrap
    }

    private func makePicker(_ choices: [PhoneLine]) -> UIView {
        let box = CutCornerView()
        box.cut = Theme.cutSmall
        box.fill = Theme.panel2
        box.outline = Theme.line
        let label = UILabel()
        label.font = GameFont.mono(10, .bold)
        label.textColor = Theme.yellow
        label.setTracked("Reply", tracking: 1.8)
        let stack = UIStackView(arrangedSubviews: [label])
        stack.axis = .vertical
        stack.spacing = 2
        stack.setCustomSpacing(8, after: label)
        for (index, choice) in choices.enumerated() {
            let row = UILabel()
            row.numberOfLines = 0
            let marker = NSMutableAttributedString(
                string: index == 0 ? "▶  " : "·  ",
                attributes: [.font: GameFont.mono(12, .bold), .foregroundColor: index == 0 ? Theme.cyan : Theme.dim]
            )
            marker.append(NSAttributedString(
                string: choice.text,
                attributes: [.font: GameFont.body(15, index == 0 ? .semibold : .medium), .foregroundColor: index == 0 ? Theme.ink : Theme.ink2]
            ))
            row.attributedText = marker
            stack.addArrangedSubview(row)
        }
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: box.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
        ])
        return box
    }
}
