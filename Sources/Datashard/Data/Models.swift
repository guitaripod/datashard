import Foundation

/// Which Journal shelf a row lives on. Raw values double as sub-tab keys.
enum Shelf: String, CaseIterable, Sendable {
    case shards, mail, files, quests, tarot

    var title: String {
        switch self {
        case .shards: return "Shards"
        case .mail: return "Mail"
        case .files: return "Files"
        case .quests: return "Quests"
        case .tarot: return "Tarot"
        }
    }

}

/// One readable thing: what the list shows and what the reader typesets.
/// `id` is the journal row id, stable across rebuilds of the same game files.
struct Document: Hashable, Sendable {
    let id: Int
    let path: String
    let kicker: String
    let title: String
    let excerpt: String
    let group: String
    let groupTitle: String
    let meta: String
    let body: String
    let icon: String
    var blocks: [ReaderBlock] { ReaderText.blocks(for: body) }
}

enum ReaderBlock: Hashable, Sendable {
    case heading(String)
    case paragraph(String)
}

struct Contact: Hashable, Sendable {
    let id: Int
    let path: String
    let name: String
    let contactType: String?
    let messageCount: Int
    let lastLine: String
}

struct PhoneLine: Hashable, Sendable {
    enum Kind: Sendable { case message, choice }
    let id: Int
    let conversation: String
    let kind: Kind
    let text: String
    let questImportant: Bool
}

struct CodexSection: Hashable, Sendable {
    let name: String
    let count: Int
}

struct SearchHit: Hashable, Sendable {
    enum Source: Sendable { case journal, dialogue }
    let source: Source
    let id: Int
    let kind: String
    let context: String
    let title: String
    let excerpt: String
    let rank: Double
}

struct DialogueLine: Hashable, Sendable {
    let id: Int
    let stringID: String
    let line: String
}

/// Where a search hit leads when opened.
enum SearchTarget: Sendable {
    case document(Document, siblings: [Document])
    case thread(Contact)
    case scene(name: String, lines: [DialogueLine], highlight: Int)
}
