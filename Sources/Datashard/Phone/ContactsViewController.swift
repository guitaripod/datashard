import UIKit

/// The Phone tab: every contact with a thread, most talkative first, with the
/// last thing they said.
final class ContactsViewController: UIViewController, UICollectionViewDelegate {
    private let store: JournalStore
    private let images: ImageStore
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, Int>!
    private var contacts: [Contact] = []
    private var contactsByID: [Int: Contact] = [:]

    init(store: JournalStore, images: ImageStore) {
        self.store = store
        self.images = images
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bg2
        title = "Phone"
        navigationItem.largeTitleDisplayMode = .always

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.delegate = self
        collectionView.contentInset = UIEdgeInsets(top: 4, left: 0, bottom: 8, right: 0)
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Int> { [weak self] cell, _, id in
            guard let contact = self?.contactsByID[id] else { return }
            cell.contentConfiguration = ContactRowConfiguration(contact: contact, images: self?.images)
            cell.backgroundConfiguration = .clear()
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { cv, indexPath, id in
            cv.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: id)
        }
        load()
    }

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { _, env in
            var config = UICollectionLayoutListConfiguration(appearance: .plain)
            config.backgroundColor = .clear
            config.showsSeparators = false
            return NSCollectionLayoutSection.list(using: config, layoutEnvironment: env)
        }
    }

    private func load() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let loaded = try await store.contacts()
                contacts = loaded
                contactsByID = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
                var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
                snapshot.appendSections([0])
                snapshot.appendItems(loaded.map(\.id))
                await dataSource.apply(snapshot, animatingDifferences: false)
            } catch {
                AppLogger.error("Loading contacts failed: \(error)", .dataset)
            }
        }
    }

    func open(_ contact: Contact) {
        navigationController?.pushViewController(ThreadViewController(contact: contact, store: store, images: images), animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let id = dataSource.itemIdentifier(for: indexPath), let contact = contactsByID[id] else { return }
        open(contact)
    }
}

struct ContactRowConfiguration: UIContentConfiguration, Hashable {
    let contact: Contact
    let images: ImageStore?

    func makeContentView() -> UIView & UIContentView { ContactRowContentView(configuration: self) }
    func updated(for state: UIConfigurationState) -> ContactRowConfiguration { self }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.contact == rhs.contact }
    func hash(into hasher: inout Hasher) { hasher.combine(contact) }
}

final class ContactRowContentView: UIView, UIContentView {
    var configuration: UIContentConfiguration { didSet { apply() } }

    private let panel = UIView()
    private let edge = UIView()
    private let avatar = UILabel()
    private let portrait = PictureView()
    private let nameLabel = UILabel()
    private let lastLabel = UILabel()
    private let countLabel = UILabel()

    init(configuration: ContactRowConfiguration) {
        self.configuration = configuration
        super.init(frame: .zero)
        panel.backgroundColor = Theme.panel
        panel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(panel)
        edge.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(edge)

        avatar.font = GameFont.display(16, .bold)
        avatar.textAlignment = .center
        avatar.translatesAutoresizingMaskIntoConstraints = false
        portrait.translatesAutoresizingMaskIntoConstraints = false
        portrait.isUserInteractionEnabled = false
        avatar.addSubview(portrait)

        nameLabel.font = GameFont.display(17, .bold)
        nameLabel.textColor = Theme.ink
        lastLabel.font = GameFont.body(14, .medium)
        lastLabel.textColor = Theme.ink2
        lastLabel.numberOfLines = 1
        countLabel.font = GameFont.mono(11, .bold)
        countLabel.textColor = Theme.cyan
        countLabel.textAlignment = .right
        countLabel.numberOfLines = 2
        countLabel.setContentHuggingPriority(.required, for: .horizontal)
        countLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let text = UIStackView(arrangedSubviews: [nameLabel, lastLabel])
        text.axis = .vertical
        text.spacing = 2
        let row = UIStackView(arrangedSubviews: [avatar, text, countLabel])
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(row)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            panel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            panel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Theme.gutter),
            panel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Theme.gutter),
            edge.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            edge.topAnchor.constraint(equalTo: panel.topAnchor),
            edge.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
            edge.widthAnchor.constraint(equalToConstant: 2),
            avatar.widthAnchor.constraint(equalToConstant: 44),
            avatar.heightAnchor.constraint(equalToConstant: 44),
            portrait.topAnchor.constraint(equalTo: avatar.topAnchor),
            portrait.bottomAnchor.constraint(equalTo: avatar.bottomAnchor),
            portrait.leadingAnchor.constraint(equalTo: avatar.leadingAnchor),
            portrait.trailingAnchor.constraint(equalTo: avatar.trailingAnchor),
            row.topAnchor.constraint(equalTo: panel.topAnchor, constant: 9),
            row.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -9),
            row.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 8),
            row.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -10),
        ])
        apply()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func apply() {
        guard let c = configuration as? ContactRowConfiguration else { return }
        let fixer = (c.contact.contactType ?? "").lowercased().contains("fixer")
        avatar.text = String(JournalStore.abbreviation(c.contact.name).prefix(2))
        avatar.backgroundColor = fixer ? Theme.red : Theme.cyan
        avatar.textColor = fixer ? .white : Theme.cyanInk
        portrait.isHidden = c.contact.avatar == nil || c.images == nil
        if let images = c.images {
            portrait.show(c.contact.avatar, from: images, fitting: 44)
        }
        nameLabel.setTracked(c.contact.name, tracking: 0.6)
        lastLabel.text = c.contact.lastLine.isEmpty ? "—" : c.contact.lastLine
        let count = NSMutableAttributedString(string: "\(c.contact.messageCount)\n", attributes: [.font: GameFont.mono(12, .bold), .foregroundColor: Theme.cyan])
        count.append(NSAttributedString(string: "MSGS", attributes: [.font: GameFont.mono(9), .foregroundColor: Theme.dim, .kern: 1.2]))
        countLabel.attributedText = count
        edge.backgroundColor = fixer ? Theme.redDim : Theme.cyanDim
    }
}
