import Foundation
import GRDB

/// The only writable state: which journal rows were read and which are
/// bookmarked, keyed on the dataset's stable ids. Lives in Application Support.
final class ReadingStore: Sendable {
    private let queue: DatabaseQueue

    init() throws {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("Reading", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var config = Configuration()
        config.busyMode = .timeout(5)
        queue = try DatabaseQueue(path: directory.appendingPathComponent("reading.sqlite").path, configuration: config)
        try Self.migrator.migrate(queue)
    }

    func readIDs() async -> Set<Int> {
        (try? await queue.read { db in
            Set(try Int.fetchAll(db, sql: "SELECT journal_id FROM read_mark"))
        }) ?? []
    }

    func bookmarkIDs() async -> Set<Int> {
        (try? await queue.read { db in
            Set(try Int.fetchAll(db, sql: "SELECT journal_id FROM bookmark ORDER BY added_at DESC"))
        }) ?? []
    }

    func markRead(_ id: Int) async {
        await write("INSERT OR IGNORE INTO read_mark (journal_id, read_at) VALUES (?, ?)", [id, Self.now()])
    }

    func toggleBookmark(_ id: Int) async -> Bool {
        let wasBookmarked = await bookmarkIDs().contains(id)
        if wasBookmarked {
            await write("DELETE FROM bookmark WHERE journal_id = ?", [id])
        } else {
            await write("INSERT OR IGNORE INTO bookmark (journal_id, added_at) VALUES (?, ?)", [id, Self.now()])
        }
        return !wasBookmarked
    }

    private func write(_ sql: String, _ arguments: StatementArguments) async {
        do {
            try await queue.write { db in
                try db.execute(sql: sql, arguments: arguments)
            }
        } catch {
            AppLogger.error("Reading store write failed: \(error)", .persistence)
        }
    }

    private static func now() -> Int { Int(Date().timeIntervalSince1970) }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "read_mark") { t in
                t.primaryKey("journal_id", .integer)
                t.column("read_at", .integer).notNull()
            }
            try db.create(table: "bookmark") { t in
                t.primaryKey("journal_id", .integer)
                t.column("added_at", .integer).notNull()
            }
        }
        return migrator
    }
}
