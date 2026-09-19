import UIKit

final class TabBarController: UITabBarController {
    private let store: JournalStore
    private let images: ImageStore
    private let reading: ReadingStore

    init(store: JournalStore, images: ImageStore, reading: ReadingStore) {
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
        NavigationStyle.apply(to: tabBar)

        let journal = wrap(
            DocumentListViewController(mode: .journal, store: store, images: images, reading: reading),
            title: "Journal", symbol: "book.pages", selected: "book.pages.fill"
        )
        let codex = wrap(
            DocumentListViewController(mode: .codex, store: store, images: images, reading: reading),
            title: "Codex", symbol: "text.book.closed", selected: "text.book.closed.fill"
        )
        let phone = wrap(
            ContactsViewController(store: store, images: images),
            title: "Phone", symbol: "phone", selected: "phone.fill"
        )
        let search = wrap(
            SearchViewController(store: store, images: images, reading: reading),
            title: "Search", symbol: "magnifyingglass", selected: "magnifyingglass"
        )
        viewControllers = [journal, codex, phone, search]
    }

    /// Jumps straight to a screen; used when the app is launched from the
    /// build machine with a `DATASHARD_OPEN` route to screenshot a page.
    func open(_ route: LaunchRoute) {
        selectedIndex = route.tab
        guard let list = (viewControllers?[route.tab] as? UINavigationController)?.viewControllers.first as? DocumentListViewController else { return }
        list.openWhenLoaded(id: route.documentID, shelf: route.shelf)
    }

    private func wrap(_ root: UIViewController, title: String, symbol: String, selected: String) -> UINavigationController {
        let nav = UINavigationController(rootViewController: root)
        NavigationStyle.apply(to: nav)
        nav.tabBarItem = UITabBarItem(
            title: title.uppercased(),
            image: UIImage(systemName: symbol),
            selectedImage: UIImage(systemName: selected)
        )
        return nav
    }
}
