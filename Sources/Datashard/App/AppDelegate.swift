import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        NSSetUncaughtExceptionHandler { exception in
            AppLogger.fault(
                "Uncaught exception \(exception.name.rawValue): \(exception.reason ?? "no reason")",
                .lifecycle,
                sync: true
            )
        }
        GameFont.registerBundledFaces()
        AppLogger.info("Launch, log at \(LogFileWriter.shared.currentPath)", .lifecycle)
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
