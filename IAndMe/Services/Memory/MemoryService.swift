import Foundation

/// What a piece of text appears to be about: a known concept or a newly spotted one.
struct ConceptMention: Hashable, Sendable {
    var name: String
    var kind: ConceptKind
    /// Set when the mention matches a concept the app already knows.
    var existingID: UUID?
}

/// Finds the people, places and themes a moment refers to. Pure text-in, mentions-out so it can be
/// tested in isolation and replaced by a smarter model later.
protocol MemoryService: AnyObject {
    func mentions(in text: String, knownConcepts: [ConceptSnapshot], ownerName: String) -> [ConceptMention]
}

final class LocalMemoryService: MemoryService {
    func mentions(in text: String, knownConcepts: [ConceptSnapshot], ownerName: String) -> [ConceptMention] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var results: [ConceptMention] = []
        var takenNames = Set<String>()

        // 1. Known concepts by name or alias, whole-word, case-insensitive.
        for concept in knownConcepts {
            for candidate in concept.allNames where containsWholeWord(trimmed, candidate) {
                if takenNames.insert(concept.name.lowercased()).inserted {
                    results.append(ConceptMention(name: concept.name, kind: concept.kind, existingID: concept.id))
                }
                break
            }
        }

        // 2. Named entities the system recognises.
        let ownerFirst = ownerName.split(separator: " ").first.map(String.init)?.lowercased()
        let knownTokens = Set(knownConcepts.flatMap(\.allNames).flatMap { $0.lowercased().split(separator: " ").map(String.init) })
        for entity in TextAnalyzer.namedEntities(in: trimmed) {
            let lowered = entity.name.lowercased()
            if lowered == ownerFirst || takenNames.contains(lowered) { continue }
            if knownConcepts.contains(where: { $0.allNames.contains { $0.lowercased() == lowered } }) { continue }
            // "Sent Hannah" is Hannah with a stray word attached, not a new person.
            if lowered.split(separator: " ").contains(where: { knownTokens.contains(String($0)) || String($0) == ownerFirst }) { continue }
            takenNames.insert(lowered)
            results.append(ConceptMention(name: entity.name, kind: entity.kind, existingID: nil))
        }

        // 3. Themes from the lexicon.
        let lemmas = Set(TextAnalyzer.contentWords(in: trimmed) + TextSnippets.words(in: trimmed))
        for theme in Lexicon.themes where !theme.words.isDisjoint(with: lemmas) {
            let lowered = theme.name.lowercased()
            guard takenNames.insert(lowered).inserted else { continue }
            let existing = knownConcepts.first { $0.kind == .theme && $0.name.lowercased() == lowered }
            results.append(ConceptMention(name: theme.name, kind: .theme, existingID: existing?.id))
        }
        return results
    }

    private func containsWholeWord(_ text: String, _ word: String) -> Bool {
        guard !word.isEmpty else { return false }
        let pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: word) + "(?![\\p{L}\\p{N}])"
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
