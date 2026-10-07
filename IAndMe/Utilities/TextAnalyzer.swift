import Foundation
import NaturalLanguage

/// On-device language analysis built on Apple's NaturalLanguage framework. Nothing leaves the phone.
enum TextAnalyzer {
    /// Sentiment in -1...1. Uses the system model with a small lexicon fallback for short texts.
    static func sentiment(of text: String) -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = trimmed
        var scores: [Double] = []
        tagger.enumerateTags(in: trimmed.startIndex..<trimmed.endIndex, unit: .paragraph, scheme: .sentimentScore, options: []) { tag, _ in
            if let tag, let value = Double(tag.rawValue) { scores.append(value) }
            return true
        }
        let model = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
        let lexical = lexicalSentiment(of: trimmed)
        // Blend: the model is good on longer text; the lexicon catches short, direct statements.
        if scores.isEmpty { return lexical }
        return max(-1, min(1, model * 0.7 + lexical * 0.5))
    }

    private static func lexicalSentiment(of text: String) -> Double {
        let words = Set(contentWords(in: text) + TextSnippets.words(in: text))
        let negative = Double(words.intersection(Lexicon.difficultWords).count)
        let positive = Double(words.intersection(Lexicon.positiveWords).count)
        let total = negative + positive
        guard total > 0 else { return 0 }
        return max(-1, min(1, (positive - negative) / max(1, total) * min(1, total / 2)))
    }

    /// Lemmatised, lowercase content words with stop words removed.
    static func contentWords(in text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text
        var words: [String] = []
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma, options: options) { tag, range in
            let raw = String(text[range]).lowercased()
            let lemma = (tag?.rawValue.lowercased()).flatMap { $0.isEmpty ? nil : $0 } ?? raw
            if lemma.count > 2, !Lexicon.stopWords.contains(lemma), !Lexicon.stopWords.contains(raw) {
                words.append(lemma)
            }
            return true
        }
        return words
    }

    struct NamedEntity: Hashable {
        var name: String
        var kind: ConceptKind
    }

    /// People and places named in the text, using the on-device named-entity model with guards
    /// against its common mistakes (capitalised sentence starts, joined fragments).
    static func namedEntities(in text: String) -> [NamedEntity] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var results: [NamedEntity] = []
        let sentenceStarts = sentenceStartIndices(in: text)
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            guard let tag, tag == .personalName || tag == .placeName else { return true }
            var tokens = String(text[range]).split(whereSeparator: { $0.isWhitespace }).map { $0.trimmingCharacters(in: .punctuationCharacters) }.filter { !$0.isEmpty }
            // A capitalised word that merely starts a sentence is not evidence of a name,
            // unless it is a prefix that belongs to names ("St Ives", "Aunt May").
            if sentenceStarts.contains(range.lowerBound), let first = tokens.first, !Lexicon.namePrefixes.contains(first) {
                tokens.removeFirst()
            }
            // Every remaining token must look like part of a proper name.
            guard !tokens.isEmpty, tokens.allSatisfy({ $0.first?.isUppercase == true && $0.count >= 2 }) else { return true }
            let name = tokens.joined(separator: " ")
            guard name.count >= 3, !Lexicon.nameBlocklist.contains(name.lowercased()), !Lexicon.stopWords.contains(name.lowercased()) else { return true }
            results.append(NamedEntity(name: name, kind: tag == .personalName ? .person : .place))
            return true
        }
        // The system tagger misses less common names. Catch capitalised words that follow a cue
        // such as "with Priya" or "at Porthmeor", as long as they don't start a sentence.
        let personCues: Set<String> = ["with", "and", "met", "saw", "rang", "called", "texted", "told", "asked", "thanks", "love", "miss", "missed", "for"]
        let placeCues: Set<String> = ["in", "at", "near", "around", "through", "across", "along", "towards", "toward", "outside", "inside"]
        let known = Set(results.map { $0.name.lowercased() })
        for sentence in sentences(in: text) {
            let tokens = sentence.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard tokens.count > 1 else { continue }
            for index in 1..<tokens.count {
                let raw = tokens[index].trimmingCharacters(in: .punctuationCharacters)
                let previous = tokens[index - 1].lowercased().trimmingCharacters(in: .punctuationCharacters)
                guard raw.count >= 3, let first = raw.first, first.isUppercase, raw.dropFirst().allSatisfy({ $0.isLetter && $0.isLowercase }) else { continue }
                let lowered = raw.lowercased()
                guard !known.contains(lowered), !Lexicon.nameBlocklist.contains(lowered), !Lexicon.stopWords.contains(lowered) else { continue }
                // Skip words that end the previous sentence fragment (preceded by punctuation).
                guard !tokens[index - 1].hasSuffix(".") && !tokens[index - 1].hasSuffix("!") && !tokens[index - 1].hasSuffix("?") else { continue }
                if personCues.contains(previous) {
                    results.append(NamedEntity(name: raw, kind: .person))
                } else if placeCues.contains(previous) {
                    results.append(NamedEntity(name: raw, kind: .place))
                }
            }
        }
        var seen = Set<String>()
        return results.filter { seen.insert($0.name.lowercased()).inserted }
    }

    /// Indices where sentences begin, so sentence-initial capitals aren't mistaken for names.
    static func sentenceStartIndices(in text: String) -> Set<String.Index> {
        var starts = Set<String.Index>()
        text.enumerateSubstrings(in: text.startIndex..., options: [.bySentences, .substringNotRequired]) { _, range, _, _ in
            var index = range.lowerBound
            while index < range.upperBound, text[index].isWhitespace || text[index].isPunctuation {
                index = text.index(after: index)
            }
            starts.insert(index)
        }
        return starts
    }

    static func sentences(in text: String) -> [String] {
        var result: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: [.bySentences]) { sub, _, _, _ in
            if let sub {
                let trimmed = sub.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { result.append(trimmed) }
            }
        }
        return result
    }
}
