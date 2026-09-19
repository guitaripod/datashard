import Foundation
import GRDB

/// Every read the app does over the dataset, one method per screen need.
/// Rows come back as plain value types so view controllers stay off the
/// database queue.
final class JournalStore: Sendable {
    private let dataset: Dataset

    init(dataset: Dataset) {
        self.dataset = dataset
    }

    // MARK: Journal shelves

    func documents(on shelf: Shelf) async throws -> [Document] {
        switch shelf {
        case .shards: return try await shards()
        case .net: return try await shardPages()
        case .mail: return try await emails()
        case .files: return try await files()
        case .quests: return try await quests()
        case .tarot: return try await tarots()
        }
    }

    func shelfCounts() async throws -> [Shelf: Int] {
        try await dataset.queue.read { db in
            var counts: [Shelf: Int] = [:]
            counts[.shards] = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM journal WHERE \(Self.shardFilter)") ?? 0
            counts[.net] = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM v_shards WHERE body IS NOT NULL AND body <> ''") ?? 0
            counts[.mail] = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM v_emails WHERE body <> '' OR image IS NOT NULL") ?? 0
            counts[.files] = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM journal WHERE kind = 'file' AND (body <> '' OR json_extract(extra, '$.image') IS NOT NULL)") ?? 0
            counts[.quests] = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM v_quests WHERE title <> '' AND (description IS NOT NULL OR objective_count > 0)") ?? 0
            counts[.tarot] = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM journal WHERE kind = 'tarot'") ?? 0
            return counts
        }
    }

    /// The game's datashards: every `onscreen` entry under the two shard
    /// folders (base game and Phantom Liberty name theirs differently),
    /// leaving out tutorial and warning popups that share the entry class.
    private static let shardFilter = """
        kind = 'onscreen' AND body <> '' AND (path LIKE 'onscreens/emails/%' OR path LIKE 'onscreens/shards/%')
        """

    private func shards() async throws -> [Document] {
        try await dataset.queue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT id, path, title, body, json_extract(extra, '$.image') AS image FROM journal
                WHERE \(Self.shardFilter) ORDER BY path
                """)
            let pictures = try Self.pictures(db, keys: rows.compactMap { $0["image"] })
            return rows.map { row in
                let path: String = row["path"]
                let body: String = row["body"]
                let group = Self.shardGroup(path)
                let title: String = row["title"]
                let code = Self.questCode(in: path)
                return Document(
                    id: row["id"],
                    path: path,
                    kicker: "Shard",
                    title: title.isEmpty ? ReaderText.pageHeadline(body: body, pageID: path.split(separator: "/").last.map(String.init) ?? "shard") : title,
                    excerpt: ReaderText.excerpt(from: body, excluding: title),
                    group: group,
                    groupTitle: group,
                    meta: [group, code].compactMap { $0 }.joined(separator: " · "),
                    body: body,
                    icon: Self.abbreviation(group),
                    picture: (row["image"] as String?).flatMap { pictures[$0] }
                )
            }
        }
    }

    private func shardPages() async throws -> [Document] {
        try await dataset.queue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT p.id AS id, s.source, s.page_path, s.page_id, s.site_title, s.address, s.text_count, s.body, s.images
                FROM v_shards s
                JOIN journal p ON p.kind = 'internet_page' AND p.path = s.page_path AND p.source = s.source
                WHERE s.body IS NOT NULL AND s.body <> ''
                ORDER BY s.site_title, s.page_path
                """)
            let pictures = try Self.pictures(db, keys: rows.flatMap { Self.keyList($0["images"]) })
            return rows.map { row in
                let body: String = row["body"]
                let site = Self.siteName(row["site_title"])
                let pageID: String = row["page_id"]
                let headline = ReaderText.pageHeadline(body: body, pageID: pageID)
                let address: String? = row["address"]
                let gallery = Self.keyList(row["images"]).compactMap { pictures[$0] }.filter(\.isGalleryWorthy)
                return Document(
                    id: row["id"],
                    path: row["page_path"],
                    kicker: "Net",
                    title: headline,
                    excerpt: ReaderText.excerpt(from: body, excluding: headline),
                    group: site,
                    groupTitle: site,
                    meta: [address, "\(row["text_count"] as Int) texts"].compactMap { $0 }.joined(separator: " · "),
                    body: body,
                    icon: Self.abbreviation(site),
                    picture: gallery.first,
                    gallery: Array(gallery.dropFirst())
                )
            }
        }
    }

    private func emails() async throws -> [Document] {
        try await dataset.queue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT id, path, subject, sender, addressee, body, image FROM v_emails
                WHERE body <> '' OR image IS NOT NULL ORDER BY path
                """)
            let pictures = try Self.pictures(db, keys: rows.compactMap { $0["image"] })
            return rows.map { row in
                let path: String = row["path"]
                let group = Self.mailGroup(path)
                let sender: String = row["sender"] ?? ""
                let addressee: String = row["addressee"] ?? ""
                let subject: String = row["subject"]
                return Document(
                    id: row["id"],
                    path: path,
                    kicker: "Email",
                    title: subject.isEmpty ? "(no subject)" : subject,
                    excerpt: Self.excerptOrPicture(row["body"]),
                    group: group,
                    groupTitle: group,
                    meta: ["From " + (sender.isEmpty ? "unknown" : sender), addressee.isEmpty ? nil : "To " + addressee]
                        .compactMap { $0 }.joined(separator: " · "),
                    body: row["body"],
                    icon: "MSG",
                    picture: (row["image"] as String?).flatMap { pictures[$0] }
                )
            }
        }
    }

    private func files() async throws -> [Document] {
        try await dataset.queue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT id, path, title, body, json_extract(extra, '$.image') AS image FROM journal
                WHERE kind = 'file' AND (body <> '' OR json_extract(extra, '$.image') IS NOT NULL) ORDER BY path
                """)
            let pictures = try Self.pictures(db, keys: rows.compactMap { $0["image"] })
            return rows.map { row in
                let path: String = row["path"]
                let group = Self.questCode(in: path) ?? "Misc"
                let title: String = row["title"]
                return Document(
                    id: row["id"],
                    path: path,
                    kicker: "File",
                    title: title.isEmpty ? ReaderText.humanize(path.split(separator: "/").last.map(String.init) ?? "file") : title,
                    excerpt: Self.excerptOrPicture(row["body"]),
                    group: group,
                    groupTitle: group.uppercased(),
                    meta: "Document · \(group)",
                    body: row["body"],
                    icon: "DOC",
                    picture: (row["image"] as String?).flatMap { pictures[$0] }
                )
            }
        }
    }

    private func quests() async throws -> [Document] {
        try await dataset.queue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT q.id, q.path, q.title, q.quest_type, q.district, q.description, q.objective_count,
                       (SELECT group_concat(o.body, char(30)) FROM (
                            SELECT o.body FROM journal o
                            WHERE o.kind = 'quest_objective' AND o.body <> '' AND o.path LIKE q.path || '/%'
                            ORDER BY o.id) o) AS objectives
                FROM v_quests q
                WHERE q.title <> '' AND (q.description IS NOT NULL OR q.objective_count > 0)
                ORDER BY q.path
                """)
            return rows.map { row in
                let district = ReaderText.district(from: row["district"])
                let description: String = row["description"] ?? ""
                let objectives: String = row["objectives"] ?? ""
                let questType: String = row["quest_type"] ?? ""
                var body = description
                if !objectives.isEmpty {
                    let list = objectives.split(separator: "\u{1E}").map { "• " + $0 }.joined(separator: "\n\n")
                    body += (body.isEmpty ? "" : "\n\n") + "Objectives\n\n" + list
                }
                let count: Int = row["objective_count"]
                return Document(
                    id: row["id"],
                    path: row["path"],
                    kicker: questType.isEmpty ? "Quest" : ReaderText.humanize(questType),
                    title: row["title"],
                    excerpt: description.isEmpty ? "\(count) objectives" : ReaderText.excerpt(from: description),
                    group: district,
                    groupTitle: district,
                    meta: [district, "\(count) objectives"].joined(separator: " · "),
                    body: body,
                    icon: "QST"
                )
            }
        }
    }

    private func tarots() async throws -> [Document] {
        try await dataset.queue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT id, title, body, json_extract(extra, '$.index') AS idx, image FROM v_tarots
                ORDER BY idx, id
                """)
            let pictures = try Self.pictures(db, keys: rows.compactMap { $0["image"] })
            return rows.map { row in
                let index: Int? = row["idx"]
                return Document(
                    id: row["id"],
                    path: "tarots/\(row["id"] as Int)",
                    kicker: "Tarot",
                    title: row["title"],
                    excerpt: ReaderText.excerpt(from: row["body"]),
                    group: "Arcana",
                    groupTitle: "Major Arcana",
                    meta: index.map { "Card \($0)" } ?? "Card",
                    body: row["body"],
                    icon: index.map { String(format: "%02d", $0) } ?? "XX",
                    picture: (row["image"] as String?).flatMap { pictures[$0] }
                )
            }
        }
    }

    // MARK: Codex

    func codexSections() async throws -> [CodexSection] {
        try await dataset.queue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT section, COUNT(*) AS n FROM v_codex
                WHERE section IS NOT NULL GROUP BY section ORDER BY MIN(id)
                """).map { CodexSection(name: $0["section"], count: $0["n"]) }
        }
    }

    func codexArticles() async throws -> [Document] {
        try await dataset.queue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT id, entry_path, section, title, subtitle, body, image, thumb FROM v_codex
                WHERE body <> '' ORDER BY id
                """)
            let pictures = try Self.pictures(db, keys: rows.flatMap { [$0["image"], $0["thumb"]].compactMap { $0 } })
            return rows.map { row in
                let section: String = row["section"] ?? "Codex"
                let subtitle: String? = row["subtitle"]
                return Document(
                    id: row["id"],
                    path: row["entry_path"],
                    kicker: "Codex",
                    title: row["title"],
                    excerpt: ReaderText.excerpt(from: row["body"]),
                    group: section,
                    groupTitle: section,
                    meta: [section, subtitle].compactMap { $0 }.joined(separator: " · "),
                    body: row["body"],
                    icon: Self.abbreviation(section),
                    picture: (row["image"] as String?).flatMap { pictures[$0] },
                    thumbnail: (row["thumb"] as String?).flatMap { pictures[$0] }
                )
            }
        }
    }

    // MARK: Phone

    func contacts() async throws -> [Contact] {
        try await dataset.queue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT c.id, c.path, c.name, c.contact_type, c.message_count, c.avatar,
                       (SELECT m.body FROM journal m
                         WHERE m.kind = 'phone_message' AND m.body <> '' AND m.source = c.source
                           AND m.path LIKE c.path || '/%'
                         ORDER BY m.id DESC LIMIT 1) AS last_line
                FROM v_contacts c
                WHERE c.message_count > 0
                ORDER BY c.message_count DESC, c.name
                """)
            let pictures = try Self.pictures(db, keys: rows.compactMap { $0["avatar"] })
            return rows.map { row in
                Contact(
                    id: row["id"],
                    path: row["path"],
                    name: row["name"],
                    contactType: row["contact_type"],
                    messageCount: row["message_count"],
                    lastLine: (row["last_line"] as String? ?? "").replacingOccurrences(of: "\n", with: " "),
                    avatar: (row["avatar"] as String?).flatMap { pictures[$0] }
                )
            }
        }
    }

    func phoneLines(for contact: Contact) async throws -> [PhoneLine] {
        try await dataset.queue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT m.id, m.kind, m.body,
                       json_extract(m.extra, '$.quest_important') AS important,
                       (SELECT v.title FROM journal v
                         WHERE v.kind = 'phone_conversation' AND m.path LIKE v.path || '/%'
                         ORDER BY length(v.path) DESC LIMIT 1) AS conversation
                FROM journal m
                WHERE m.kind IN ('phone_message', 'phone_choice') AND m.body <> ''
                  AND m.path LIKE ? || '/%'
                ORDER BY m.id
                """, arguments: [contact.path]).map { row in
                let kind: String = row["kind"]
                let important: Int? = row["important"]
                return PhoneLine(
                    id: row["id"],
                    conversation: row["conversation"] ?? "",
                    kind: kind == "phone_choice" ? .choice : .message,
                    text: row["body"],
                    questImportant: (important ?? 0) != 0
                )
            }
        }
    }

    // MARK: Search

    func search(_ text: String, limit: Int = 60) async throws -> [SearchHit] {
        guard let query = ReaderText.ftsQuery(from: text) else { return [] }
        return try await dataset.queue.read { db in
            let journal = try Row.fetchAll(db, sql: """
                SELECT j.id, j.kind, j.path, j.title,
                       snippet(journal_fts, -1, '[', ']', '…', 16) AS excerpt,
                       bm25(journal_fts) AS rank
                FROM journal_fts JOIN journal j ON j.id = journal_fts.rowid
                WHERE journal_fts MATCH ? AND j.kind NOT IN ('folder', 'map_pin', 'quest_codex_link', 'internet_image', 'image')
                ORDER BY rank LIMIT ?
                """, arguments: [query, limit]).map { row in
                SearchHit(
                    source: .journal, id: row["id"], kind: row["kind"], context: row["path"],
                    title: row["title"], excerpt: row["excerpt"], rank: row["rank"]
                )
            }
            let dialogue = try Row.fetchAll(db, sql: """
                SELECT s.id, s.file_path,
                       snippet(subtitles_fts, -1, '[', ']', '…', 16) AS excerpt,
                       bm25(subtitles_fts) AS rank
                FROM subtitles_fts JOIN subtitles s ON s.id = subtitles_fts.rowid
                WHERE subtitles_fts MATCH ?
                ORDER BY rank LIMIT ?
                """, arguments: [query, limit]).map { row in
                let file: String = row["file_path"]
                return SearchHit(
                    source: .dialogue, id: row["id"], kind: "dialogue", context: Self.sceneName(file),
                    title: "", excerpt: row["excerpt"], rank: row["rank"]
                )
            }
            return Self.interleave([journal, dialogue], limit: limit)
        }
    }

    /// Resolves a hit to the screen that shows it in context.
    func target(for hit: SearchHit) async throws -> SearchTarget? {
        switch hit.source {
        case .dialogue:
            let lines = try await sceneLines(named: hit.context)
            return .scene(name: hit.context, lines: lines, highlight: hit.id)
        case .journal:
            return try await journalTarget(for: hit)
        }
    }

    private func journalTarget(for hit: SearchHit) async throws -> SearchTarget? {
        let path = hit.context
        switch hit.kind {
        case "onscreen":
            return pick(try await shards()) { $0.id == hit.id }
        case "shard_text", "internet_page":
            return pick(try await shardPages()) { $0.path == path }
        case "email":
            return pick(try await emails()) { $0.id == hit.id }
        case "file":
            return pick(try await files()) { $0.id == hit.id }
        case "tarot":
            return pick(try await tarots()) { $0.id == hit.id }
        case "codex_entry", "codex_description":
            let docs = try await codexArticles()
            if let exact = docs.first(where: { $0.id == hit.id }) {
                return .document(exact, siblings: docs.filter { $0.group == exact.group })
            }
            let entryPath = hit.kind == "codex_description"
                ? path.split(separator: "/").dropLast().joined(separator: "/")
                : path
            return pick(docs) { $0.path == entryPath }
        case "quest", "quest_description", "quest_objective", "quest_phase", "quest_title_variant":
            guard let questPath = try await questPath(containing: path) else { return nil }
            return pick(try await quests()) { $0.path == questPath }
        case "phone_message", "phone_choice", "phone_conversation", "contact":
            let contacts = try await contacts()
            guard let contact = contacts.first(where: { path.hasPrefix($0.path + "/") || path == $0.path }) else {
                return nil
            }
            return .thread(contact)
        default:
            return nil
        }
    }

    private func pick(_ docs: [Document], where matches: (Document) -> Bool) -> SearchTarget? {
        guard let doc = docs.first(where: matches) else { return nil }
        return .document(doc, siblings: docs.filter { $0.group == doc.group })
    }

    private func questPath(containing path: String) async throws -> String? {
        try await dataset.queue.read { db in
            try String.fetchOne(db, sql: """
                SELECT q.path FROM journal q
                WHERE q.kind = 'quest' AND (? = q.path OR ? LIKE q.path || '/%')
                ORDER BY length(q.path) DESC LIMIT 1
                """, arguments: [path, path])
        }
    }

    func sceneLines(named scene: String) async throws -> [DialogueLine] {
        try await dataset.queue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT id, string_id, line FROM v_dialogue WHERE scene = ? ORDER BY id
                """, arguments: [scene]).map {
                DialogueLine(id: $0["id"], stringID: $0["string_id"], line: $0["line"])
            }
        }
    }

    // MARK: Pictures

    func imageData(for picture: Picture) async throws -> Data? {
        try await dataset.queue.read { db in
            try Data.fetchOne(db, sql: "SELECT data FROM images WHERE key = ?", arguments: [picture.key])
        }
    }

    /// Size and existence of every key in one query; a key without a row
    /// (a build without images, or a part the game lost) simply resolves to nil.
    private static func pictures(_ db: Database, keys: [String]) throws -> [String: Picture] {
        let unique = Array(Set(keys))
        guard !unique.isEmpty else { return [:] }
        var found: [String: Picture] = [:]
        for chunk in stride(from: 0, to: unique.count, by: 400).map({ Array(unique[$0..<min($0 + 400, unique.count)]) }) {
            let marks = Array(repeating: "?", count: chunk.count).joined(separator: ",")
            for row in try Row.fetchAll(db, sql: "SELECT key, width, height FROM images WHERE key IN (\(marks))", arguments: StatementArguments(chunk)) {
                let key: String = row["key"]
                found[key] = Picture(key: key, width: row["width"], height: row["height"])
            }
        }
        return found
    }

    private static func excerptOrPicture(_ body: String) -> String {
        body.isEmpty ? "Picture attachment" : ReaderText.excerpt(from: body)
    }

    /// `onscreens/<folder>/generic/[shards/]<category>/…` is a category shard
    /// (the base game nests one folder deeper than Phantom Liberty); the
    /// quest folders hold the ones picked up during a job.
    static func shardGroup(_ path: String) -> String {
        let parts = path.split(separator: "/").map(String.init)
        guard parts.count > 3 else { return "Other" }
        switch parts[2] {
        case "generic":
            let category = parts[3] == "shards" && parts.count > 4 ? parts[4] : parts[3]
            return ReaderText.humanize(category)
        case "quests": return "Quests"
        default: return ReaderText.humanize(parts[2])
        }
    }

    private static func keyList(_ joined: String?) -> [String] {
        (joined ?? "").split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    // MARK: Helpers

    static func abbreviation(_ name: String) -> String {
        let words = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        let short: String
        if words.count >= 2 {
            short = words.prefix(3).map { String($0.prefix(1)) }.joined()
        } else {
            short = String(name.filter { $0.isLetter || $0.isNumber }.prefix(3))
        }
        return short.isEmpty ? "NET" : short.uppercased()
    }

    /// A site's localized name, or its internal id made readable when the
    /// game never localized it (`growl_fm` → `Growl Fm`).
    static func siteName(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "Net" }
        let looksLikeID = raw.contains("_") || raw == raw.lowercased()
        return looksLikeID ? ReaderText.humanize(raw) : raw
    }

    static func mailGroup(_ path: String) -> String {
        let parts = path.split(separator: "/").map(String.init)
        guard parts.count > 3 else { return "Inbox" }
        if parts[2] == "generic" { return "Generic" }
        if let code = questCode(in: path) { return code }
        return ReaderText.humanize(parts[3])
    }

    /// `q105`, `sq030`, `mq030`: the quest code embedded in a journal path.
    static func questCode(in path: String) -> String? {
        for part in path.split(separator: "/") {
            let text = String(part)
            if let match = text.range(of: "^(m?s?q[0-9]{3}[a-z]?)", options: .regularExpression) {
                return String(text[match])
            }
        }
        return nil
    }

    static func sceneName(_ filePath: String) -> String {
        let base = filePath.split(separator: "\\").last.map(String.init) ?? filePath
        return base.hasSuffix(".json") ? String(base.dropLast(5)) : base
    }

    private static func interleave(_ lists: [[SearchHit]], limit: Int) -> [SearchHit] {
        var queues = lists.filter { !$0.isEmpty }.map { $0[...] }
        var merged: [SearchHit] = []
        while !queues.isEmpty && merged.count < limit {
            queues.sort { ($0.first?.rank ?? 0) < ($1.first?.rank ?? 0) }
            for index in queues.indices where merged.count < limit {
                if let hit = queues[index].popFirst() {
                    merged.append(hit)
                }
            }
            queues.removeAll { $0.isEmpty }
        }
        return merged
    }
}
