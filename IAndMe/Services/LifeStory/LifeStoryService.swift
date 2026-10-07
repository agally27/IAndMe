import Foundation

struct ChapterDraft: Hashable, Sendable {
    var title: String
    var subtitle: String
    var body: String
    var periodStart: Date
    var periodEnd: Date
    var entryIDs: [UUID]
}

/// Turns a stretch of moments into an editorial chapter. The local version composes from templates
/// and real quotes; a production model would write prose from the same inputs.
protocol LifeStoryService: AnyObject {
    func draftChapter(entries: [EntrySnapshot], concepts: [ConceptSnapshot], period: ClosedRange<Date>, now: Date) -> ChapterDraft?
}

final class LocalLifeStoryService: LifeStoryService {
    private let calendar = Calendar.current

    func draftChapter(entries allEntries: [EntrySnapshot], concepts: [ConceptSnapshot], period: ClosedRange<Date>, now: Date) -> ChapterDraft? {
        let entries = allEntries.filter { period.contains($0.occurredAt) }.sorted { $0.occurredAt < $1.occurredAt }
        guard entries.count >= 3, let first = entries.first, let last = entries.last else { return nil }

        let days = Set(entries.map { calendar.startOfDay(for: $0.occurredAt) }).count
        let felt = entries.compactMap(\.feeling)
        let difficult = entries.filter { ($0.feeling?.isDifficult ?? false) }
        let uplifting = entries.filter { ($0.feeling?.isUplifting ?? false) }

        func mentioning(_ concept: ConceptSnapshot) -> [EntrySnapshot] {
            let names = Set(concept.allNames.map { $0.lowercased() })
            return entries.filter { $0.conceptNames.contains { names.contains($0.lowercased()) } }
        }
        let people = concepts.filter { $0.kind == .person }.map { ($0, mentioning($0)) }.filter { $0.1.count >= 1 }.sorted { $0.1.count > $1.1.count }
        let places = concepts.filter { $0.kind == .place }.map { ($0, mentioning($0)) }.filter { $0.1.count >= 1 }.sorted { $0.1.count > $1.1.count }
        let themes = concepts.filter { $0.kind == .theme }.map { ($0, mentioning($0)) }.filter { $0.1.count >= 2 }.sorted { $0.1.count > $1.1.count }

        var paragraphs: [String] = []

        // Scale and mood
        let span = DateFormatting.periodLabel(from: first.occurredAt, to: last.occurredAt) ?? ""
        var opening = "Across \(span.isEmpty ? "this stretch" : span) you captured \(entries.count) moments over \(days) day\(days == 1 ? "" : "s")."
        if !felt.isEmpty {
            if Double(uplifting.count) / Double(felt.count) >= 0.5 {
                opening += " Most of them felt good, some of them bright."
            } else if Double(difficult.count) / Double(felt.count) >= 0.5 {
                opening += " More of them felt heavy than light — it was not an easy time."
            } else {
                opening += " It was a mixed stretch: \(difficult.count) that felt heavy or low, \(uplifting.count) that felt good or bright, and the rest somewhere steady in between."
            }
        }
        paragraphs.append(opening)

        // People
        if let (topPerson, topMentions) = people.first {
            var text = "\(topPerson.name) appears more than anyone else, in \(topMentions.count) moment\(topMentions.count == 1 ? "" : "s")."
            if people.count > 1 {
                let others = people.dropFirst().prefix(2).map { $0.0.name }
                text += " \(others.joined(separator: " and ")) \(others.count == 1 ? "is" : "are") never far away."
            }
            if let quote = topMentions.last.map({ TextSnippets.snippet(of: $0.fullText, maxLength: 120) }) {
                text += " In one of them you wrote: “\(quote)”"
            }
            paragraphs.append(text)
        }

        // Places
        if let (topPlace, placeMentions) = places.first {
            var text = "\(topPlace.name) kept returning — \(placeMentions.count) of these moments happened there"
            let placeFelt = placeMentions.compactMap(\.feeling)
            if !placeFelt.isEmpty, Double(placeFelt.filter(\.isUplifting).count) / Double(placeFelt.count) >= 0.5 {
                text += ", and most of them felt good."
            } else {
                text += "."
            }
            if places.count > 1 {
                text += " \(places[1].0.name) too, in its own quieter way."
            }
            paragraphs.append(text)
        }

        // Themes, hardest and brightest
        var themeText = ""
        if let (topTheme, themeMentions) = themes.first {
            themeText = "\(topTheme.name) ran through these weeks, showing up in \(themeMentions.count) moments."
            if themes.count > 1 {
                themeText += " So did \(themes[1].0.name.lowercased())."
            }
        }
        if let heaviest = difficult.min(by: { ($0.feeling?.rawValue ?? 3) < ($1.feeling?.rawValue ?? 3) }) {
            themeText += (themeText.isEmpty ? "" : " ") + "The heaviest day was \(heaviest.occurredAt.formatted(.dateTime.day().month(.wide))): “\(TextSnippets.snippet(of: heaviest.fullText, maxLength: 110))”"
        }
        if let brightest = uplifting.max(by: { ($0.feeling?.rawValue ?? 3) < ($1.feeling?.rawValue ?? 3) }) {
            themeText += (themeText.isEmpty ? "" : " ") + "And the brightest, \(brightest.occurredAt.formatted(.dateTime.day().month(.wide))): “\(TextSnippets.snippet(of: brightest.fullText, maxLength: 110))”"
        }
        if !themeText.isEmpty { paragraphs.append(themeText) }

        // Trend and closing
        let trend = feelingTrend(entries)
        let closing: String
        switch trend {
        case .improving: closing = "Read together, these moments lean upward. Whatever was heavy at the start had loosened by the end."
        case .worsening: closing = "Read together, these moments get heavier as they go. It may be worth noticing what changed, and what you'd want to be different next time."
        case .steady: closing = "Read together, these moments feel steady — not dramatic, but lived. That is most of what a life is made of."
        case .unknown: closing = "Read together, these moments are the raw material of a chapter. The shape of it is yours to decide."
        }
        paragraphs.append(closing)

        let title = chapterTitle(trend: trend, places: places.map { $0.0 }, themes: themes.map { $0.0 }, entries: entries)
        let subtitle = span.isEmpty ? "A chapter" : span
        return ChapterDraft(
            title: title,
            subtitle: subtitle,
            body: paragraphs.joined(separator: "\n\n"),
            periodStart: first.occurredAt,
            periodEnd: last.occurredAt,
            entryIDs: entries.map(\.id)
        )
    }

    enum Trend { case improving, worsening, steady, unknown }

    func feelingTrend(_ entries: [EntrySnapshot]) -> Trend {
        let felt = entries.compactMap { $0.feeling.map { Double($0.rawValue) } }
        guard felt.count >= 4 else { return .unknown }
        let half = felt.count / 2
        let firstAverage = felt.prefix(half).reduce(0, +) / Double(half)
        let secondAverage = felt.suffix(felt.count - half).reduce(0, +) / Double(felt.count - half)
        let delta = secondAverage - firstAverage
        if delta > 0.4 { return .improving }
        if delta < -0.4 { return .worsening }
        return .steady
    }

    private func chapterTitle(trend: Trend, places: [ConceptSnapshot], themes: [ConceptSnapshot], entries: [EntrySnapshot]) -> String {
        if let place = places.first, Double(entries.filter { $0.conceptNames.contains(place.name) }.count) / Double(entries.count) >= 0.3 {
            return "The \(place.name) Days"
        }
        if let theme = themes.first, Double(entries.filter { $0.conceptNames.contains(theme.name) }.count) / Double(entries.count) >= 0.4 {
            switch trend {
            case .improving: return "\(theme.name), and Then Lighter"
            case .worsening: return "Under the Weight of \(theme.name)"
            default: return "A Season of \(theme.name)"
            }
        }
        switch trend {
        case .improving: return "Finding a Rhythm"
        case .worsening: return "Carrying More"
        case .steady: return "Holding Steady"
        case .unknown: return "A Stretch of Days"
        }
    }
}
