import Foundation

/// Turns the dataset's plain bodies into reader blocks and list excerpts.
enum ReaderText {
    /// Paragraph chunks separated by blank lines; short chunks that do not end a
    /// sentence are headings (the shard pages store their headlines that way).
    static func blocks(for body: String) -> [ReaderBlock] {
        let chunks = body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var result: [ReaderBlock] = []
        for (index, chunk) in chunks.enumerated() {
            if looksLikeHeading(chunk, isLast: index == chunks.count - 1, total: chunks.count) {
                result.append(.heading(chunk))
            } else {
                result.append(.paragraph(chunk))
            }
        }
        return result
    }

    private static func looksLikeHeading(_ chunk: String, isLast: Bool, total: Int) -> Bool {
        guard total > 1, !isLast, chunk.count <= 64, !chunk.contains("\n") else { return false }
        guard let last = chunk.last else { return false }
        return !".?!…:".contains(last)
    }

    /// The first paragraph that is not the title itself, flattened to one line
    /// for a list row; falls back to the first heading when a page is all headings.
    static func excerpt(from body: String, excluding title: String? = nil) -> String {
        let blocks = blocks(for: body)
        let paragraphs = blocks.compactMap { block -> String? in
            if case let .paragraph(text) = block, text != title { return text }
            return nil
        }
        let headings = blocks.compactMap { block -> String? in
            if case let .heading(text) = block, text != title { return text }
            return nil
        }
        let pick = paragraphs.first ?? headings.first ?? ""
        return pick.replacingOccurrences(of: "\n", with: " ")
    }

    /// The headline a shard page leads with, or a humanised page id.
    static func pageHeadline(body: String, pageID: String) -> String {
        if case let .heading(text)? = blocks(for: body).first, text.count > 2 {
            return text
        }
        if case let .paragraph(text)? = blocks(for: body).first, text.count <= 48 {
            return text
        }
        return humanize(pageID)
    }

    static func humanize(_ identifier: String) -> String {
        var name = identifier
        while let first = name.first, first.isNumber || first == "_" {
            name.removeFirst()
        }
        let words = name.replacingOccurrences(of: "_", with: " ").split(separator: " ")
        return words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }

    static func readingTime(for body: String) -> String {
        let words = body.split(whereSeparator: { $0.isWhitespace }).count
        let minutes = max(1, Int((Double(words) / 210).rounded(.up)))
        return "~\(minutes) min"
    }

    /// `Districts.Watson` → `Watson`, `DeviceContentAssignment.q105` → `q105`.
    static func lastSegment(_ record: String) -> String {
        record.split(separator: ".").last.map(String.init) ?? record
    }

    static func district(from record: String?) -> String {
        guard let record, !record.isEmpty else { return "Unassigned" }
        let name = lastSegment(record)
        return name.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
    }

    /// Turns free text into an FTS5 expression: quoted prefix tokens joined by
    /// implicit AND, so typing never produces a syntax error.
    static func ftsQuery(from text: String) -> String? {
        let tokens = text
            .replacingOccurrences(of: "\"", with: " ")
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "'" })
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return nil }
        return tokens.map { "\"\($0.replacingOccurrences(of: "'", with: "''"))\"*" }.joined(separator: " ")
    }

    /// Splits a `snippet()` excerpt with `[` `]` markers into runs.
    static func snippetRuns(_ excerpt: String) -> [(text: String, marked: Bool)] {
        var runs: [(String, Bool)] = []
        var current = ""
        var marked = false
        for ch in excerpt {
            if ch == "[" && !marked {
                if !current.isEmpty { runs.append((current, false)) }
                current = ""
                marked = true
            } else if ch == "]" && marked {
                if !current.isEmpty { runs.append((current, true)) }
                current = ""
                marked = false
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { runs.append((current, marked)) }
        return runs
    }
}
