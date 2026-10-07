import Foundation

enum TextSnippets {
    /// The first sentence of a piece of text, trimmed and capped to a sensible length.
    static func firstSentence(of text: String, maxLength: Int = 80) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var sentence = trimmed
        trimmed.enumerateSubstrings(in: trimmed.startIndex..., options: [.bySentences]) { sub, _, _, stop in
            if let sub, !sub.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sentence = sub
                stop = true
            }
        }
        sentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        if let newline = sentence.firstIndex(of: "\n") {
            sentence = String(sentence[..<newline])
        }
        return truncate(sentence, maxLength: maxLength)
    }

    /// A short excerpt suitable for quoting, ending on a word boundary.
    static func snippet(of text: String, maxLength: Int = 90) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return truncate(collapsed, maxLength: maxLength)
    }

    static func truncate(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        let cut = text.index(text.startIndex, offsetBy: maxLength)
        var prefix = String(text[..<cut])
        // Only step back to a word boundary if the cut landed mid-word.
        if !text[cut].isWhitespace, let lastSpace = prefix.lastIndex(of: " ") {
            prefix = String(prefix[..<lastSpace])
        }
        let trimmed = prefix.trimmingCharacters(in: CharacterSet(charactersIn: " ,;:-"))
        return trimmed + "…"
    }

    /// Lowercase words with punctuation stripped.
    static func words(in text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'’")).inverted)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "'’")) }
            .filter { !$0.isEmpty }
    }

    static func wordCount(_ text: String) -> Int { words(in: text).count }
}

enum DurationFormatting {
    /// "0:42" or "12:05".
    static func short(_ duration: TimeInterval) -> String {
        let total = max(0, Int(duration.rounded()))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// "42 seconds" / "3 minutes", for accessibility.
    static func spoken(_ duration: TimeInterval) -> String {
        let total = max(0, Int(duration.rounded()))
        if total < 60 { return "\(total) second\(total == 1 ? "" : "s")" }
        let minutes = total / 60
        let seconds = total % 60
        if seconds == 0 { return "\(minutes) minute\(minutes == 1 ? "" : "s")" }
        return "\(minutes) minute\(minutes == 1 ? "" : "s") \(seconds) second\(seconds == 1 ? "" : "s")"
    }
}
