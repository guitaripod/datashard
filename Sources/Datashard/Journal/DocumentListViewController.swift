import UIKit

/// The Journal and Codex tabs: a large-title navigation bar that hides on
/// swipe, the shelf tabs and group rail pinned under it, and the document
/// list. A horizontal swipe on the list moves between shelves; selecting a
/// row opens the reader over the rows in the same group so "next" walks the
/// shelf in order.
final class DocumentListViewController: UIViewController {
    enum Mode { case journal, codex }

    private let mode: Mode
    private let store: JournalStore
    private let images: ImageStore
    private let reading: ReadingStore
    private let subTabs = SubTabsView()
    private let rail = ChipRail()
    private let topBar = UIView()
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, Int>!
    private var documentsByID: [Int: Document] = [:]
    private var allDocuments: [Document] = []
    private var readIDs: Set<Int> = []
    private var bookmarkIDs: Set<Int> = []
    private var shelf: Shelf = .shards
    private var groupKey = DocumentListViewController.allKey
    private var showSavedOnly = false
    private var loadTask: Task<Void, Never>?
    private var savedButton: UIBarButtonItem!
    private var pendingOpenID: Int?

    private static let allKey = "*"

    init(mode: Mode, store: JournalStore, images: ImageStore, reading: ReadingStore) {
        self.mode = mode
        self.store = store
        self.images = images
        self.reading = reading
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bg2
        title = mode == .journal ? "Journal" : "Codex"
        navigationItem.largeTitleDisplayMode = .always
        savedButton = NavigationStyle.barButton(symbol: "bookmark", action: UIAction { [weak self] _ in self?.toggleSavedFilter() })
        navigationItem.rightBarButtonItem = savedButton

        topBar.backgroundColor = Theme.bg2
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)

        subTabs.translatesAutoresizingMaskIntoConstraints = false
        subTabs.isHidden = mode == .codex
        subTabs.setTabs(Shelf.allCases.map { SubTabsView.Tab(key: $0.rawValue, title: $0.title, count: nil) }, selected: shelf.rawValue)
        subTabs.onSelect = { [weak self] key in
            guard let self, let next = Shelf(rawValue: key) else { return }
            switchShelf(to: next)
        }
        topBar.addSubview(subTabs)

        rail.translatesAutoresizingMaskIntoConstraints = false
        rail.onSelect = { [weak self] key in
            guard let self else { return }
            groupKey = key
            applySnapshot(animating: true)
        }
        topBar.addSubview(rail)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.delegate = self
        collectionView.contentInset = UIEdgeInsets(top: 2, left: 0, bottom: 8, right: 0)
        view.addSubview(collectionView)
        if mode == .journal {
            for direction in [UISwipeGestureRecognizer.Direction.left, .right] {
                let swipe = UISwipeGestureRecognizer(target: self, action: #selector(swiped(_:)))
                swipe.direction = direction
                collectionView.addGestureRecognizer(swipe)
            }
        }

        let subTabsHeight = subTabs.heightAnchor.constraint(equalToConstant: mode == .codex ? 0 : 40)
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            subTabs.topAnchor.constraint(equalTo: topBar.topAnchor, constant: mode == .codex ? 0 : 6),
            subTabs.leadingAnchor.constraint(equalTo: topBar.leadingAnchor),
            subTabs.trailingAnchor.constraint(equalTo: topBar.trailingAnchor),
            subTabsHeight,

            rail.topAnchor.constraint(equalTo: subTabs.bottomAnchor, constant: 6),
            rail.leadingAnchor.constraint(equalTo: topBar.leadingAnchor),
            rail.trailingAnchor.constraint(equalTo: topBar.trailingAnchor),
            rail.heightAnchor.constraint(equalToConstant: 36),
            rail.bottomAnchor.constraint(equalTo: topBar.bottomAnchor, constant: -4),

            collectionView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        configureDataSource()
        load()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { await refreshReadingState() }
    }

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { _, env in
            var config = UICollectionLayoutListConfiguration(appearance: .plain)
            config.backgroundColor = .clear
            config.showsSeparators = false
            return NSCollectionLayoutSection.list(using: config, layoutEnvironment: env)
        }
    }

    private func configureDataSource() {
        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Int> { [weak self] cell, _, id in
            guard let self, let document = documentsByID[id] else { return }
            cell.contentConfiguration = DocumentRowConfiguration(
                document: document,
                isRead: readIDs.contains(id),
                isBookmarked: bookmarkIDs.contains(id),
                images: images
            )
            cell.backgroundConfiguration = .clear()
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { cv, indexPath, id in
            cv.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: id)
        }
    }

    private func switchShelf(to next: Shelf) {
        guard next != shelf else { return }
        shelf = next
        groupKey = Self.allKey
        subTabs.select(next.rawValue)
        load()
    }

    @objc private func swiped(_ gesture: UISwipeGestureRecognizer) {
        let shelves = Shelf.allCases
        guard let index = shelves.firstIndex(of: shelf) else { return }
        let target = gesture.direction == .left ? index + 1 : index - 1
        guard shelves.indices.contains(target) else { return }
        switchShelf(to: shelves[target])
    }

    private func load() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                async let docs = mode == .journal ? store.documents(on: shelf) : store.codexArticles()
                async let read = reading.readIDs()
                async let saved = reading.bookmarkIDs()
                let (loaded, readSet, savedSet) = try await (docs, read, saved)
                try Task.checkCancellation()
                allDocuments = loaded
                documentsByID = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
                readIDs = readSet
                bookmarkIDs = savedSet
                rebuildRail()
                applySnapshot(animating: false)
                if let id = pendingOpenID, let doc = documentsByID[id] {
                    pendingOpenID = nil
                    open(doc)
                }
                if mode == .journal {
                    let counts = try await store.shelfCounts()
                    for (shelf, count) in counts { subTabs.setCount(count, for: shelf.rawValue) }
                }
            } catch is CancellationError {
            } catch {
                AppLogger.error("Loading \(mode) failed: \(error)", .dataset)
            }
        }
    }

    private func rebuildRail() {
        var counts: [String: Int] = [:]
        var order: [String] = []
        for doc in allDocuments {
            if counts[doc.group] == nil { order.append(doc.group) }
            counts[doc.group, default: 0] += 1
        }
        let sorted = mode == .journal && (shelf == .shards || shelf == .net)
            ? order.sorted { (counts[$0] ?? 0, $1) > (counts[$1] ?? 0, $0) }
            : order
        var chips = [ChipRail.Chip(key: Self.allKey, title: "All", count: allDocuments.count)]
        chips += sorted.map { ChipRail.Chip(key: $0, title: $0, count: counts[$0]) }
        rail.isHidden = sorted.count < 2
        rail.setChips(chips, selected: groupKey)
    }

    private var visibleDocuments: [Document] {
        var docs = groupKey == Self.allKey ? allDocuments : allDocuments.filter { $0.group == groupKey }
        if showSavedOnly {
            docs = docs.filter { bookmarkIDs.contains($0.id) }
        }
        return docs
    }

    private func applySnapshot(animating: Bool) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
        snapshot.appendSections([0])
        snapshot.appendItems(visibleDocuments.map(\.id))
        dataSource.apply(snapshot, animatingDifferences: animating)
        if animating, !visibleDocuments.isEmpty {
            collectionView.setContentOffset(CGPoint(x: 0, y: -collectionView.adjustedContentInset.top), animated: false)
        }
    }

    private func refreshReadingState() async {
        let read = await reading.readIDs()
        let saved = await reading.bookmarkIDs()
        guard read != readIDs || saved != bookmarkIDs else { return }
        readIDs = read
        bookmarkIDs = saved
        if showSavedOnly {
            applySnapshot(animating: true)
            return
        }
        var snapshot = dataSource.snapshot()
        snapshot.reconfigureItems(snapshot.itemIdentifiers)
        await dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func toggleSavedFilter() {
        showSavedOnly.toggle()
        savedButton.image = UIImage(systemName: showSavedOnly ? "bookmark.fill" : "bookmark")
        savedButton.tintColor = showSavedOnly ? Theme.yellow : Theme.cyan
        applySnapshot(animating: true)
    }

    /// Opens the document once its shelf has loaded (launch routes only).
    func openWhenLoaded(id: Int?, shelf target: Shelf?) {
        pendingOpenID = id
        if let target, mode == .journal, target != shelf {
            shelf = target
            subTabs.select(target.rawValue)
        }
    }

    private func open(_ document: Document) {
        let siblings = visibleDocuments
        let reader = ReaderViewController(
            documents: siblings,
            index: siblings.firstIndex(of: document) ?? 0,
            crumb: crumb(),
            images: images,
            reading: reading
        )
        navigationController?.pushViewController(reader, animated: true)
    }

    private func crumb() -> [String] {
        switch mode {
        case .journal: return ["Journal", shelf.title] + (groupKey == Self.allKey ? [] : [groupKey])
        case .codex: return ["Codex"] + (groupKey == Self.allKey ? [] : [groupKey])
        }
    }
}

extension DocumentListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let id = dataSource.itemIdentifier(for: indexPath), let doc = documentsByID[id] else { return }
        open(doc)
    }
}
