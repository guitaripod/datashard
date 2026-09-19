import CoreGraphics
import Foundation

/// Which Journal shelf a row lives on. Raw values double as sub-tab keys.
/// Shards are the game's readable datashards (`onscreen` entries); Net is
/// the browsable net pages.
enum Shelf: String, CaseIterable, Sendable {
    case shards, net, mail, files, quests, tarot

    var title: String {
        switch self {
        case .shards: return "Shards"
        case .net: return "Net"
        case .mail: return "Mail"
        case .files: return "Files"
        case .quests: return "Quests"
        case .tarot: return "Tarot"
        }
    }

}

/// A picture in the dataset's `images` table: its key plus the pixel size,
/// known up front so layouts never jump when the bytes arrive.
struct Picture: Hashable, Sendable {
    let key: String
    let width: Int
    let height: Int

    var aspect: CGFloat { CGFloat(width) / CGFloat(max(height, 1)) }
    var isPortrait: Bool { height > width }

    /// Net pages also carry buttons, stars and separators; only pictures
    /// with some size to them are worth showing outside the page layout.
    var isGalleryWorthy: Bool { min(width, height) >= 96 }
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
    var picture: Picture? = nil
    var thumbnail: Picture? = nil
    var gallery: [Picture] = []
    var blocks: [ReaderBlock] { ReaderText.blocks(for: body) }

    /// What a list row shows: the game's own small version when it has one.
    var listPicture: Picture? { thumbnail ?? picture }
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
    let avatar: Picture?
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
