import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.tintColor = Theme.cyan
        window.backgroundColor = Theme.bg2
        self.window = window
        window.makeKeyAndVisible()

        do {
            let dataset = try Dataset.bundled()
            let reading = try ReadingStore()
            window.rootViewController = TabBarController(store: JournalStore(dataset: dataset), reading: reading)
        } catch {
            AppLogger.fault("Dataset failed to open: \(error)", .dataset, sync: true)
            window.rootViewController = DatasetFailureViewController(message: "\(error)")
        }
        window.addSubview(ScanlineOverlayView(frame: window.bounds))
    }
}
