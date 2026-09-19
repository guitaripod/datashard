import UIKit

/// Full-text search over the journal and every spoken line, interleaved so
/// dialogue never drowns out the shards. The search field is the stock
/// navigation-bar search controller; results show the bracketed match the
/// dataset's snippet() produces, in cyan.
final class SearchViewController: UIViewController, UISearchResultsUpdating, UICollectionViewDelegate {
    private let store: JournalStore
    private let reading: ReadingStore
    private let searchController = UISearchController(searchResultsController: nil)
    private let emptyLabel = UILabel()
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, String>!
    private var hits: [SearchHit] = []
    private var hitsByKey: [String: SearchHit] = [:]
    private var searchTask: Task<Void, Never>?

    init(store: JournalStore, reading: ReadingStore) {
        self.store = store
        self.reading = reading
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bg2
        title = "Search"
        navigationItem.largeTitleDisplayMode = .always

        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = "Arasaka, neurotoxin, \"never fade away\""
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.autocorrectionType = .no
        searchController.searchBar.searchTextField.font = GameFont.body(16, .medium)
        searchController.searchBar.searchTextField.textColor = Theme.ink
        searchController.searchBar.tintColor = Theme.cyan
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true

        emptyLabel.font = GameFont.mono(11)
        emptyLabel.textColor = Theme.dim
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.setTracked("journal · codex · mail · files · 109k lines of dialogue", tracking: 1.4)
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.keyboardDismissMode = .onDrag
        collectionView.delegate = self
        collectionView.contentInset = UIEdgeInsets(top: 4, left: 0, bottom: 8, right: 0)
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])

        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, String> { [weak self] cell, _, key in
            guard let hit = self?.hitsByKey[key] else { return }
            cell.contentConfiguration = HitRowConfiguration(hit: hit)
            cell.backgroundConfiguration = .clear()
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { cv, indexPath, key in
            cv.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: key)
        }
    }

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { _, env in
            var config = UICollectionLayoutListConfiguration(appearance: .plain)
            config.backgroundColor = .clear
            config.showsSeparators = false
            return NSCollectionLayoutSection.list(using: config, layoutEnvironment: env)
        }
    }

    func updateSearchResults(for searchController: UISearchController) {
        searchTask?.cancel()
        let text = searchController.searchBar.text ?? ""
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled, let self else { return }
            await run(text)
        }
    }

    private func run(_ text: String) async {
        do {
            let found = try await store.search(text)
            guard !Task.isCancelled else { return }
            hits = found
            hitsByKey = Dictionary(uniqueKeysWithValues: found.map { (Self.key(for: $0), $0) })
            var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
            snapshot.appendSections([0])
            snapshot.appendItems(found.map(Self.key(for:)))
            await dataSource.apply(snapshot, animatingDifferences: false)
            if text.isEmpty {
                emptyLabel.setTracked("journal · codex · mail · files · 109k lines of dialogue", tracking: 1.4)
            } else {
                emptyLabel.setTracked(found.isEmpty ? "no hits for \(text)" : "", tracking: 1.4)
            }
            emptyLabel.isHidden = !found.isEmpty
        } catch {
            AppLogger.error("Search failed for \(text): \(error)", .search)
        }
    }

    private static func key(for hit: SearchHit) -> String {
        "\(hit.source == .journal ? "j" : "d")-\(hit.id)"
    }

    private func open(_ hit: SearchHit) {
        Task { [weak self] in
            guard let self else { return }
            do {
                guard let target = try await store.target(for: hit) else {
                    AppLogger.notice("No target for hit \(hit.kind) \(hit.context)", .search)
                    return
                }
                switch target {
                case let .document(doc, siblings):
                    let reader = ReaderViewController(
                        documents: siblings,
                        index: siblings.firstIndex(of: doc) ?? 0,
                        crumb: ["Search", doc.groupTitle],
                        reading: reading
                    )
                    navigationController?.pushViewController(reader, animated: true)
                case let .thread(contact):
                    navigationController?.pushViewController(ThreadViewController(contact: contact, store: store), animated: true)
                case let .scene(name, lines, highlight):
                    navigationController?.pushViewController(SceneViewController(scene: name, lines: lines, highlight: highlight), animated: true)
                }
            } catch {
                AppLogger.error("Opening hit failed: \(error)", .search)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let key = dataSource.itemIdentifier(for: indexPath), let hit = hitsByKey[key] else { return }
        open(hit)
    }
}

struct HitRowConfiguration: UIContentConfiguration, Hashable {
    let hit: SearchHit

    func makeContentView() -> UIView & UIContentView { HitRowContentView(configuration: self) }
    func updated(for state: UIConfigurationState) -> HitRowConfiguration { self }
}

final class HitRowContentView: UIView, UIContentView {
    var configuration: UIContentConfiguration { didSet { apply() } }

    private let panel = UIView()
    private let edge = UIView()
    private let sourceLabel = UILabel()
    private let contextLabel = UILabel()
    private let excerptLabel = UILabel()

    init(configuration: HitRowConfiguration) {
        self.configuration = configuration
        super.init(frame: .zero)
        panel.backgroundColor = Theme.panel
        panel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(panel)
        edge.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(edge)
        sourceLabel.font = GameFont.mono(10, .bold)
        sourceLabel.setContentHuggingPriority(.required, for: .horizontal)
        sourceLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        contextLabel.font = GameFont.mono(10)
        contextLabel.textColor = Theme.dim
        contextLabel.lineBreakMode = .byTruncatingHead
        excerptLabel.font = GameFont.body(16, .medium)
        excerptLabel.textColor = Theme.ink
        excerptLabel.numberOfLines = 3
        let top = UIStackView(arrangedSubviews: [sourceLabel, contextLabel])
        top.spacing = 8
        top.alignment = .firstBaseline
        let stack = UIStackView(arrangedSubviews: [top, excerptLabel])
        stack.axis = .vertical
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            panel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            panel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Theme.gutter),
            panel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Theme.gutter),
            edge.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            edge.topAnchor.constraint(equalTo: panel.topAnchor),
            edge.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
            edge.widthAnchor.constraint(equalToConstant: 2),
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 9),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),
        ])
        apply()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func apply() {
        guard let c = configuration as? HitRowConfiguration else { return }
        let hit = c.hit
        let isDialogue = hit.source == .dialogue
        sourceLabel.textColor = isDialogue ? Theme.red : Theme.cyan
        sourceLabel.setTracked(isDialogue ? "Dialogue" : ReaderText.humanize(hit.kind), tracking: 1.4)
        contextLabel.setTracked(hit.title.isEmpty ? hit.context : hit.title, tracking: 0.8, uppercase: false)
        edge.backgroundColor = isDialogue ? Theme.redDim : Theme.cyanDim
        let attributed = NSMutableAttributedString()
        for run in ReaderText.snippetRuns(hit.excerpt) {
            attributed.append(NSAttributedString(string: run.text, attributes: [
                .font: run.marked ? GameFont.body(16, .bold) : GameFont.body(16, .medium),
                .foregroundColor: run.marked ? Theme.cyan : Theme.ink,
            ]))
        }
        excerptLabel.attributedText = attributed
    }
}
