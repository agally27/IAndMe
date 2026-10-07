import Foundation

struct InsightDraft: Hashable, Sendable {
    var key: String
    var kind: InsightKind
    var title: String
    var body: String
    var confidence: InsightConfidence
    var periodStart: Date?
    var periodEnd: Date?
    var relatedEntryIDs: [UUID]
    var relatedConceptIDs: [UUID]
}

/// Produces observations from moments. Pure and deterministic given its inputs.
protocol InsightService: AnyObject {
    func generateInsights(entries: [EntrySnapshot], concepts: [ConceptSnapshot], now: Date) -> [InsightDraft]
}

final class LocalInsightService: InsightService {
    private let windowDays = 90
    private let calendar = Calendar.current

    func generateInsights(entries allEntries: [EntrySnapshot], concepts: [ConceptSnapshot], now: Date) -> [InsightDraft] {
        guard let cutoff = calendar.date(byAdding: .day, value: -windowDays, to: now) else { return [] }
        let entries = allEntries.filter { $0.occurredAt >= cutoff && $0.occurredAt <= now }.sorted { $0.occurredAt < $1.occurredAt }
        guard entries.count >= 3 else { return [] }
        let periodStart = entries.first?.occurredAt
        let periodEnd = entries.last?.occurredAt

        var drafts: [InsightDraft] = []
        drafts.append(contentsOf: reliefPatterns(entries: entries, concepts: concepts, start: periodStart, end: periodEnd))
        drafts.append(contentsOf: liftedBy(entries: entries, concepts: concepts, start: periodStart, end: periodEnd))
        drafts.append(contentsOf: recurringThemes(entries: entries, concepts: concepts, now: now, start: periodStart, end: periodEnd))
        if let people = topConcepts(kind: .person, entries: entries, concepts: concepts, start: periodStart, end: periodEnd) { drafts.append(people) }
        if let places = topConcepts(kind: .place, entries: entries, concepts: concepts, start: periodStart, end: periodEnd) { drafts.append(places) }
        if let hard = hardestStretch(entries: entries) { drafts.append(hard) }
        if let rhythm = rhythm(entries: entries, start: periodStart, end: periodEnd) { drafts.append(rhythm) }
        return drafts
    }

    // MARK: Helpers

    private func entriesMentioning(_ concept: ConceptSnapshot, in entries: [EntrySnapshot]) -> [EntrySnapshot] {
        let names = Set(concept.allNames.map { $0.lowercased() })
        return entries.filter { entry in
            entry.conceptNames.contains { names.contains($0.lowercased()) }
        }
    }

    private func isDifficult(_ entry: EntrySnapshot) -> Bool {
        if let feeling = entry.feeling { return feeling.isDifficult }
        return TextAnalyzer.sentiment(of: entry.fullText) < -0.35
    }

    private func isUplifting(_ entry: EntrySnapshot) -> Bool {
        if let feeling = entry.feeling { return feeling.isUplifting }
        return TextAnalyzer.sentiment(of: entry.fullText) > 0.4
    }

    private func confidence(for count: Int) -> InsightConfidence {
        switch count {
        case ..<3: return .tentative
        case 3...4: return .moderate
        default: return .strong
        }
    }

    private func joinNames(_ names: [String]) -> String {
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        case 2: return "\(names[0]) and \(names[1])"
        default: return names.dropLast().joined(separator: ", ") + " and " + names.last!
        }
    }

    // MARK: Patterns

    /// "You've mentioned walking several times after difficult days."
    private func reliefPatterns(entries: [EntrySnapshot], concepts: [ConceptSnapshot], start: Date?, end: Date?) -> [InsightDraft] {
        let difficult = entries.filter(isDifficult)
        guard difficult.count >= 2 else { return [] }
        var drafts: [InsightDraft] = []
        for theme in concepts where theme.kind == .place || (theme.kind == .theme && Lexicon.restorativeThemes.contains(theme.name)) {
            let mentioning = entriesMentioning(theme, in: entries).filter { !isDifficult($0) }
            guard mentioning.count >= 2 else { continue }
            let afterHardDay = mentioning.filter { entry in
                difficult.contains { hard in
                    hard.id != entry.id && hard.occurredAt < entry.occurredAt && entry.occurredAt.timeIntervalSince(hard.occurredAt) <= 36 * 3600
                }
            }
            guard afterHardDay.count >= 2 else { continue }
            let name = theme.name
            let lowered = theme.kind == .place ? name : name.lowercased()
            let verb = theme.kind == .place ? "gone to" : "turned to"
            drafts.append(InsightDraft(
                key: "noticed.relief.\(theme.id.uuidString)",
                kind: .noticed,
                title: "\(name) after harder days",
                body: "You've \(verb) \(lowered) \(afterHardDay.count) times in the day after a difficult moment. It may be something that helps, or just a habit — only you would know.",
                confidence: confidence(for: afterHardDay.count),
                periodStart: start,
                periodEnd: end,
                relatedEntryIDs: afterHardDay.map(\.id),
                relatedConceptIDs: [theme.id]
            ))
        }
        return Array(drafts.prefix(2))
    }

    /// Places and people that coincide with uplifting moments.
    private func liftedBy(entries: [EntrySnapshot], concepts: [ConceptSnapshot], start: Date?, end: Date?) -> [InsightDraft] {
        var drafts: [InsightDraft] = []
        for concept in concepts where concept.kind == .place || concept.kind == .person {
            let mentioning = entriesMentioning(concept, in: entries)
            guard mentioning.count >= 2 else { continue }
            let lifted = mentioning.filter(isUplifting)
            guard lifted.count >= 2, Double(lifted.count) / Double(mentioning.count) >= 0.6 else { continue }
            let body: String
            if concept.kind == .place {
                body = "You seemed particularly positive around \(concept.name): \(lifted.count) of the \(mentioning.count) moments there were marked good or bright."
            } else {
                body = "Moments with \(concept.name) are often ones you marked good or bright — \(lifted.count) of \(mentioning.count) lately."
            }
            drafts.append(InsightDraft(
                key: "lifted.\(concept.id.uuidString)",
                kind: .lifted,
                title: concept.kind == .place ? "Time at \(concept.name)" : "Time with \(concept.name)",
                body: body,
                confidence: confidence(for: lifted.count),
                periodStart: start,
                periodEnd: end,
                relatedEntryIDs: lifted.map(\.id),
                relatedConceptIDs: [concept.id]
            ))
        }
        return Array(drafts.sorted { $0.relatedEntryIDs.count > $1.relatedEntryIDs.count }.prefix(2))
    }

    private func recurringThemes(entries: [EntrySnapshot], concepts: [ConceptSnapshot], now: Date, start: Date?, end: Date?) -> [InsightDraft] {
        let ranked = concepts.filter { $0.kind == .theme }
            .map { ($0, entriesMentioning($0, in: entries)) }
            .filter { $0.1.count >= 3 }
            .sorted { $0.1.count > $1.1.count }
        return ranked.prefix(2).map { theme, mentioning in
            let latest = mentioning.map(\.occurredAt).max() ?? now
            let difficultShare = Double(mentioning.filter(isDifficult).count) / Double(mentioning.count)
            var body = "\(theme.name) has appeared in \(mentioning.count) of your moments in the last few months, most recently \(DateFormatting.prosePhrase(for: latest, relativeTo: now))."
            if difficultShare >= 0.5 {
                body += " More often than not, those moments felt heavy."
            } else if difficultShare <= 0.2 {
                body += " Those moments have mostly felt steady or good."
            }
            return InsightDraft(
                key: "recurring.\(theme.id.uuidString)",
                kind: .recurring,
                title: "\(theme.name) keeps returning",
                body: body,
                confidence: confidence(for: mentioning.count),
                periodStart: start,
                periodEnd: end,
                relatedEntryIDs: mentioning.suffix(6).map(\.id),
                relatedConceptIDs: [theme.id]
            )
        }
    }

    private func topConcepts(kind: ConceptKind, entries: [EntrySnapshot], concepts: [ConceptSnapshot], start: Date?, end: Date?) -> InsightDraft? {
        let ranked = concepts.filter { $0.kind == kind }
            .map { ($0, entriesMentioning($0, in: entries)) }
            .filter { $0.1.count >= 2 }
            .sorted { $0.1.count > $1.1.count }
        guard !ranked.isEmpty else { return nil }
        let top = Array(ranked.prefix(3))
        let names = joinNames(top.map { $0.0.name })
        let body: String
        if kind == .person {
            body = top.count == 1
                ? "\(names) appears in \(top[0].1.count) of your recent moments — more than anyone else."
                : "\(names) appear most often in your recent moments. \(top[0].0.name) most of all, in \(top[0].1.count) of them."
        } else {
            body = top.count == 1
                ? "\(names) comes up in \(top[0].1.count) of your recent moments. It seems to hold something for you."
                : "\(names) are the places that keep appearing. \(top[0].0.name) most of all, in \(top[0].1.count) moments."
        }
        return InsightDraft(
            key: "top.\(kind.rawValue)",
            kind: kind == .person ? .people : .places,
            title: kind == .person ? "The people in your moments" : "The places you return to",
            body: body,
            confidence: confidence(for: top[0].1.count),
            periodStart: start,
            periodEnd: end,
            relatedEntryIDs: Array(Set(top.flatMap { $0.1.suffix(3).map(\.id) })),
            relatedConceptIDs: top.map { $0.0.id }
        )
    }

    private func hardestStretch(entries: [EntrySnapshot]) -> InsightDraft? {
        let difficult = entries.filter(isDifficult)
        guard difficult.count >= 3 else { return nil }
        var best: (start: Date, members: [EntrySnapshot])?
        for anchor in difficult {
            let windowEnd = anchor.occurredAt.adding(days: 7)
            let members = difficult.filter { $0.occurredAt >= anchor.occurredAt && $0.occurredAt < windowEnd }
            if members.count >= 3, members.count > (best?.members.count ?? 0) || (members.count == best?.members.count && anchor.occurredAt > best!.start) {
                best = (anchor.occurredAt, members)
            }
        }
        guard let best else { return nil }
        let weekLabel = best.start.formatted(.dateTime.day().month(.wide))
        return InsightDraft(
            key: "difficult.\(calendar.startOfDay(for: best.start).timeIntervalSince1970)",
            kind: .difficult,
            title: "A heavier stretch",
            body: "The days around \(weekLabel) seemed harder than most — \(best.members.count) moments from that week felt heavy or low. Looking back at how you came through it might be worth something.",
            confidence: confidence(for: best.members.count),
            periodStart: best.start,
            periodEnd: best.members.map(\.occurredAt).max(),
            relatedEntryIDs: best.members.map(\.id),
            relatedConceptIDs: []
        )
    }

    private func rhythm(entries: [EntrySnapshot], start: Date?, end: Date?) -> InsightDraft? {
        guard entries.count >= 8 else { return nil }
        let hours = entries.map { calendar.component(.hour, from: $0.occurredAt) }
        let late = hours.filter { $0 >= 22 || $0 < 4 }
        let early = hours.filter { $0 >= 5 && $0 < 10 }
        if Double(late.count) / Double(hours.count) >= 0.3 {
            let lateEntries = entries.filter { let h = calendar.component(.hour, from: $0.occurredAt); return h >= 22 || h < 4 }
            return InsightDraft(
                key: "rhythm.late",
                kind: .rhythm,
                title: "You often write late",
                body: "\(late.count) of your \(hours.count) recent moments were captured after ten at night. Late entries tend to be the honest ones — but it may also say something about sleep.",
                confidence: confidence(for: late.count),
                periodStart: start, periodEnd: end,
                relatedEntryIDs: lateEntries.suffix(5).map(\.id),
                relatedConceptIDs: []
            )
        }
        if Double(early.count) / Double(hours.count) >= 0.4 {
            return InsightDraft(
                key: "rhythm.morning",
                kind: .rhythm,
                title: "A morning writer",
                body: "Most of your moments are captured before ten in the morning. Mornings seem to be when you take stock.",
                confidence: confidence(for: early.count),
                periodStart: start, periodEnd: end,
                relatedEntryIDs: [],
                relatedConceptIDs: []
            )
        }
        let weekdays = Dictionary(grouping: entries) { calendar.component(.weekday, from: $0.occurredAt) }
        if let (day, members) = weekdays.max(by: { $0.value.count < $1.value.count }), members.count >= 4, Double(members.count) / Double(entries.count) >= 0.3 {
            let name = calendar.weekdaySymbols[day - 1]
            return InsightDraft(
                key: "rhythm.weekday",
                kind: .rhythm,
                title: "\(name)s",
                body: "\(name) is when you write most — \(members.count) of your recent moments. Something about that day makes room for it.",
                confidence: confidence(for: members.count),
                periodStart: start, periodEnd: end,
                relatedEntryIDs: members.suffix(4).map(\.id),
                relatedConceptIDs: []
            )
        }
        return nil
    }
}
