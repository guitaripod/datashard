import Foundation

/// Finds files copied from `Sources/Datashard/Resources`. SwiftPM exposes them
/// through `Bundle.module`; if the packaged app lays the bundle out differently
/// the main bundle and its `.bundle` children are searched as a fallback.
enum ResourceLocator {
    static func url(forResource name: String, withExtension ext: String, subdirectory: String? = nil) -> URL? {
        let sub = subdirectory.map { "Resources/\($0)" } ?? "Resources"
        for bundle in candidateBundles() {
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: sub) {
                return url
            }
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: subdirectory) {
                return url
            }
        }
        return nil
    }

    static func urls(inSubdirectory subdirectory: String, withExtension ext: String) -> [URL] {
        for bundle in candidateBundles() {
            for sub in ["Resources/\(subdirectory)", subdirectory] {
                if let found = bundle.urls(forResourcesWithExtension: ext, subdirectory: sub), !found.isEmpty {
                    return found.sorted { $0.lastPathComponent < $1.lastPathComponent }
                }
            }
        }
        return []
    }

    private static func candidateBundles() -> [Bundle] {
        var bundles: [Bundle] = [Bundle.module, Bundle.main]
        let main = Bundle.main.bundleURL
        if let children = try? FileManager.default.contentsOfDirectory(at: main, includingPropertiesForKeys: nil) {
            for child in children where child.pathExtension == "bundle" {
                if let bundle = Bundle(url: child) {
                    bundles.append(bundle)
                }
            }
        }
        return bundles
    }
}
