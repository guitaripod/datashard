import UIKit

/// The reading screen. The navigation bar hides on swipe so the page owns the
/// screen; a yellow progress line sits under the bar; bookmark and next are
/// bar buttons, and a "next in group" card closes the page.
final class ReaderViewController: UIViewController, UIScrollViewDelegate {
    private let documents: [Document]
    private var index: Int
    private let crumbParts: [String]
    private let reading: ReadingStore
    private var isBookmarked = false
    private var markedRead = false

    private let progress = UIView()
    private let progressFill = UIView()
    private var progressWidth: NSLayoutConstraint!
    private let scrollView = UIScrollView()
    private let crumb = UILabel()
    private let frame = UIView()
    private let kicker = UILabel()
    private let idLabel = UILabel()
    private let titleLabel = GlitchTitleLabel(size: 30)
    private let metaLabel = UILabel()
    private let bodyStack = UIStackView()
    private let nextView = CutCornerView()
    private let nextSmall = UILabel()
    private let nextTitle = UILabel()
    private var bookmarkButton: UIBarButtonItem!
    private var nextButton: UIBarButtonItem!

    private var document: Document { documents[index] }

    init(documents: [Document], index: Int, crumb: [String], reading: ReadingStore) {
        self.documents = documents
        self.index = index
        self.crumbParts = crumb
        self.reading = reading
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bg2
        navigationItem.largeTitleDisplayMode = .never
        bookmarkButton = NavigationStyle.barButton(symbol: "bookmark", action: UIAction { [weak self] _ in self?.toggleBookmark() })
        nextButton = NavigationStyle.barButton(symbol: "arrow.right", action: UIAction { [weak self] _ in self?.showNext() })
        navigationItem.rightBarButtonItems = [nextButton, bookmarkButton]
        buildLayout()
        render()
        Task { await loadBookmarkState() }
    }

    private func buildLayout() {
        progress.backgroundColor = Theme.line
        progress.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progress)
        progressFill.backgroundColor = Theme.yellow
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progress.addSubview(progressFill)
        progressWidth = progressFill.widthAnchor.constraint(equalToConstant: 0)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.alwaysBounceVertical = true
        scrollView.contentInset = UIEdgeInsets(top: 3, left: 0, bottom: 16, right: 0)
        view.addSubview(scrollView)

        crumb.font = GameFont.mono(11)
        crumb.textColor = Theme.dim
        crumb.numberOfLines = 2

        frame.backgroundColor = Theme.panel
        let topRule = UIView()
        topRule.backgroundColor = Theme.red
        topRule.translatesAutoresizingMaskIntoConstraints = false
        frame.addSubview(topRule)

        kicker.font = GameFont.mono(11)
        kicker.textColor = Theme.red
        idLabel.font = GameFont.mono(11)
        idLabel.textColor = Theme.red
        idLabel.textAlignment = .right
        let kickerRow = UIStackView(arrangedSubviews: [kicker, idLabel])
        kickerRow.distribution = .fill

        metaLabel.font = GameFont.mono(11)
        metaLabel.textColor = Theme.dim
        metaLabel.numberOfLines = 2

        let bar = AccentBarView()
        bar.translatesAutoresizingMaskIntoConstraints = false

        bodyStack.axis = .vertical
        bodyStack.spacing = 12

        let inner = UIStackView(arrangedSubviews: [kickerRow, titleLabel, metaLabel, bar, bodyStack])
        inner.axis = .vertical
        inner.spacing = 6
        inner.setCustomSpacing(10, after: kickerRow)
        inner.setCustomSpacing(12, after: metaLabel)
        inner.setCustomSpacing(14, after: bar)
        inner.translatesAutoresizingMaskIntoConstraints = false
        frame.addSubview(inner)

        nextView.fill = Theme.panel2
        nextView.cut = Theme.cutSmall
        nextSmall.font = GameFont.mono(10)
        nextSmall.textColor = Theme.dim
        nextTitle.font = GameFont.display(17, .bold)
        nextTitle.textColor = Theme.ink
        nextTitle.numberOfLines = 2
        let arrow = UILabel()
        arrow.text = "›"
        arrow.font = GameFont.display(26, .bold)
        arrow.textColor = Theme.red
        arrow.setContentHuggingPriority(.required, for: .horizontal)
        let nextText = UIStackView(arrangedSubviews: [nextSmall, nextTitle])
        nextText.axis = .vertical
        nextText.spacing = 3
        let nextRow = UIStackView(arrangedSubviews: [nextText, arrow])
        nextRow.alignment = .center
        nextRow.spacing = 12
        nextRow.translatesAutoresizingMaskIntoConstraints = false
        nextView.addSubview(nextRow)
        nextView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(nextTapped)))

        let column = UIStackView(arrangedSubviews: [crumb, frame, nextView])
        column.axis = .vertical
        column.spacing = 10
        column.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(column)

        NSLayoutConstraint.activate([
            progress.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progress.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progress.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progress.heightAnchor.constraint(equalToConstant: 3),
            progressFill.leadingAnchor.constraint(equalTo: progress.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progress.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progress.bottomAnchor),
            progressWidth,

            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            column.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            column.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: Theme.gutter),
            column.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -Theme.gutter),
            column.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            column.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -2 * Theme.gutter),

            topRule.topAnchor.constraint(equalTo: frame.topAnchor),
            topRule.leadingAnchor.constraint(equalTo: frame.leadingAnchor),
            topRule.trailingAnchor.constraint(equalTo: frame.trailingAnchor),
            topRule.heightAnchor.constraint(equalToConstant: 2),
            bar.heightAnchor.constraint(equalToConstant: 3),

            inner.topAnchor.constraint(equalTo: frame.topAnchor, constant: 16),
            inner.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: 16),
            inner.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -16),
            inner.bottomAnchor.constraint(equalTo: frame.bottomAnchor, constant: -20),

            nextRow.topAnchor.constraint(equalTo: nextView.topAnchor, constant: 12),
            nextRow.bottomAnchor.constraint(equalTo: nextView.bottomAnchor, constant: -12),
            nextRow.leadingAnchor.constraint(equalTo: nextView.leadingAnchor, constant: 14),
            nextRow.trailingAnchor.constraint(equalTo: nextView.trailingAnchor, constant: -14),
        ])
    }

    private func render() {
        let doc = document
        title = doc.kicker
        let position = "\(index + 1) / \(documents.count)"
        crumb.setTracked((crumbParts + [position]).joined(separator: "  ›  "), tracking: 1.4)
        kicker.setTracked(doc.kicker + " entry", tracking: 1.6)
        idLabel.setTracked("ID \(doc.id)", tracking: 1.6)
        titleLabel.text = doc.title
        metaLabel.setTracked([doc.meta, "\(doc.body.count) chars", ReaderText.readingTime(for: doc.body)].filter { !$0.isEmpty }.joined(separator: " · "), tracking: 1.2)

        bodyStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (blockIndex, block) in doc.blocks.enumerated() {
            let label = UILabel()
            label.numberOfLines = 0
            switch block {
            case let .heading(text):
                label.font = GameFont.display(20, .bold)
                label.textColor = Theme.cyan
                label.setTracked(text, tracking: 1.2)
            case let .paragraph(text):
                label.attributedText = Self.paragraph(text, dropCap: blockIndex == 0)
            }
            bodyStack.addArrangedSubview(label)
        }

        let hasNext = index + 1 < documents.count
        nextButton.isEnabled = hasNext
        if hasNext {
            let next = documents[index + 1]
            nextView.isHidden = false
            nextSmall.setTracked("Next in \(next.groupTitle)", tracking: 1.4)
            nextTitle.text = next.title
        } else {
            nextView.isHidden = true
        }
        scrollView.setContentOffset(CGPoint(x: 0, y: -scrollView.adjustedContentInset.top), animated: false)
        markedRead = false
        updateProgress()
    }

    private static func paragraph(_ text: String, dropCap: Bool) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.18
        let attributed = NSMutableAttributedString(string: text, attributes: [
            .font: GameFont.body(17, .medium),
            .foregroundColor: Theme.ink,
            .paragraphStyle: style,
        ])
        if dropCap, let first = text.first, first.isLetter {
            attributed.addAttributes([.foregroundColor: Theme.cyan, .font: GameFont.display(17, .bold)], range: NSRange(location: 0, length: 1))
        }
        return attributed
    }

    private func loadBookmarkState() async {
        isBookmarked = await reading.bookmarkIDs().contains(document.id)
        renderBookmark()
    }

    private func renderBookmark() {
        bookmarkButton.image = UIImage(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
        bookmarkButton.tintColor = isBookmarked ? Theme.yellow : Theme.cyan
    }

    private func toggleBookmark() {
        let id = document.id
        Task {
            isBookmarked = await reading.toggleBookmark(id)
            renderBookmark()
        }
    }

    private func showNext() {
        guard index + 1 < documents.count else { return }
        finishReading()
        index += 1
        UIView.transition(with: view, duration: 0.2, options: .transitionCrossDissolve) {
            self.render()
        }
        Task { await loadBookmarkState() }
    }

    @objc private func nextTapped() { showNext() }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        finishReading()
    }

    private func finishReading() {
        guard !markedRead else { return }
        markedRead = true
        let id = document.id
        Task { await reading.markRead(id) }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateProgress()
    }

    private func updateProgress() {
        let visible = scrollView.bounds.height
        let total = max(scrollView.contentSize.height + scrollView.adjustedContentInset.top + scrollView.adjustedContentInset.bottom, visible)
        let fraction = total <= visible ? 1 : min(1, max(0, (scrollView.contentOffset.y + scrollView.adjustedContentInset.top + visible) / total))
        progressWidth.constant = view.bounds.width * fraction
        if fraction > 0.85 { finishReading() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateProgress()
    }
}

/// The reader's cyan/red accent rule under the meta line.
final class AccentBarView: UIView {
    private let cyan = UIView()
    private let red = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        cyan.backgroundColor = Theme.cyan
        red.backgroundColor = Theme.red
        addSubview(cyan)
        addSubview(red)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        cyan.frame = CGRect(x: 0, y: 0, width: w * 0.38, height: bounds.height)
        red.frame = CGRect(x: w * 0.40, y: 0, width: w * 0.06, height: bounds.height)
    }
}
