import UIKit

/// The game's look applied to stock UIKit chrome: navigation bars keep every
/// native behaviour (large titles, hide on swipe, swipe back) and only change
/// typeface and colour; the tab bar likewise.
enum NavigationStyle {
    static func apply(to navigation: UINavigationController) {
        let bar = navigation.navigationBar
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Theme.bg2
        appearance.shadowColor = Theme.line
        appearance.titleTextAttributes = [
            .font: GameFont.display(19, .bold),
            .foregroundColor: Theme.ink,
            .kern: 1.4,
        ]
        appearance.largeTitleTextAttributes = [
            .font: GameFont.display(36, .bold),
            .foregroundColor: Theme.ink,
            .kern: 1.6,
        ]
        let button = UIBarButtonItemAppearance(style: .plain)
        button.normal.titleTextAttributes = [.font: GameFont.display(16, .semibold), .foregroundColor: Theme.cyan]
        appearance.buttonAppearance = button
        appearance.backButtonAppearance = button
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.compactAppearance = appearance
        bar.compactScrollEdgeAppearance = appearance
        bar.prefersLargeTitles = true
        bar.tintColor = Theme.cyan
        navigation.hidesBarsOnSwipe = true
    }

    static func apply(to tabBar: UITabBar) {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Theme.bg2
        appearance.shadowColor = Theme.line
        for item in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
            item.normal.iconColor = Theme.dim
            item.normal.titleTextAttributes = [.font: GameFont.mono(10), .foregroundColor: Theme.dim, .kern: 1.0]
            item.selected.iconColor = Theme.red
            item.selected.titleTextAttributes = [.font: GameFont.mono(10, .bold), .foregroundColor: Theme.red, .kern: 1.0]
        }
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = Theme.red
    }

    static func barButton(symbol: String, action: UIAction) -> UIBarButtonItem {
        let item = UIBarButtonItem(image: UIImage(systemName: symbol), primaryAction: action)
        item.tintColor = Theme.cyan
        return item
    }
}
