import Foundation
import GRDB

/// The bundled, read-only reader dataset (`cpdb export --profile reader`).
/// Opened straight from the resource bundle: it never changes at runtime, so
/// nothing is copied and no journal is ever written next to it.
final class Dataset: Sendable {
    static let requiredSchemaVersion = 4

    let queue: DatabaseQueue
    let schemaVersion: Int
    let fingerprint: String

    static func bundled() throws -> Dataset {
        guard let url = ResourceLocator.url(forResource: "cp2077-reader", withExtension: "sqlite") else {
            throw DatasetError.missingResource
        }
        return try Dataset(url: url)
    }

    init(url: URL) throws {
        var config = Configuration()
        config.readonly = true
        config.busyMode = .timeout(2)
        queue = try DatabaseQueue(path: url.path, configuration: config)
        let meta: [String: String] = try queue.read { db in
            var values: [String: String] = [:]
            for row in try Row.fetchAll(db, sql: "SELECT key, value FROM meta") {
                values[row["key"]] = row["value"]
            }
            return values
        }
        schemaVersion = Int(meta["schema_version"] ?? "") ?? 0
        fingerprint = meta["input_fingerprint"] ?? ""
        guard schemaVersion == Self.requiredSchemaVersion else {
            throw DatasetError.schemaMismatch(found: schemaVersion, wanted: Self.requiredSchemaVersion)
        }
        AppLogger.info("Dataset open: schema \(schemaVersion), profile \(meta["profile"] ?? "full"), fingerprint \(fingerprint.prefix(12))", .dataset)
    }
}

enum DatasetError: LocalizedError {
    case missingResource
    case schemaMismatch(found: Int, wanted: Int)

    var errorDescription: String? {
        switch self {
        case .missingResource:
            return "cp2077-reader.sqlite is not in the app bundle"
        case let .schemaMismatch(found, wanted):
            return "dataset schema \(found), this build reads \(wanted)"
        }
    }
}
