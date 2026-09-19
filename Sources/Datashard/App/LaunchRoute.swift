import Foundation

/// `DATASHARD_OPEN=<tab>[:<shelf>][:<journal id>]` in the launch environment,
/// e.g. `codex:17586`, `journal:tarot:23637` or `phone`, so a page can be
/// reached without tapping when the app is launched over USB from the build
/// machine.
struct LaunchRoute {
    let tab: Int
    let shelf: Shelf?
    let documentID: Int?

    static func fromEnvironment() -> LaunchRoute? {
        guard let raw = ProcessInfo.processInfo.environment["DATASHARD_OPEN"], !raw.isEmpty else { return nil }
        var parts = raw.split(separator: ":").map(String.init)
        let tabs = ["journal": 0, "codex": 1, "phone": 2, "search": 3]
        guard let tab = tabs[parts.removeFirst().lowercased()] else { return nil }
        let id = parts.last.flatMap(Int.init)
        let shelf = parts.first.flatMap { Shelf(rawValue: $0.lowercased()) }
        return LaunchRoute(tab: tab, shelf: shelf, documentID: id)
    }
}
