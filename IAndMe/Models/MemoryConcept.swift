import Foundation
import SwiftData

/// Something the app has come to recognise across moments: a person, a place, a theme, an important date.
/// This is the transparent "what the app remembers" layer. Every concept can be edited or forgotten.
@Model
final class MemoryConcept {
    @Attribute(.unique) var id: UUID
    var name: String
    var kindRaw: String
    var aliases: [String]
    /// A short, plain description in the companion's understanding, e.g. "Your sister. Lives in Leeds."
    var note: String?
    /// For important dates: the date (year may be ignored for recurring days).
    var anchorDate: Date?
    var recursYearly: Bool
    var firstSeen: Date
    var lastSeen: Date
    var mentionCount: Int
    /// Forgotten by the person. Kept so it is not re-created, but never used or shown as a memory.
    var isForgotten: Bool
    var sourceRaw: String
    var entries: [JournalEntry]
    var insights: [Insight]

    init(
        id: UUID = UUID(),
        name: String,
        kind: ConceptKind,
        aliases: [String] = [],
        note: String? = nil,
        anchorDate: Date? = nil,
        recursYearly: Bool = false,
        firstSeen: Date = .now,
        lastSeen: Date = .now,
        mentionCount: Int = 0,
        isForgotten: Bool = false,
        source: KnowledgeSource = .inferred
    ) {
        self.id = id
        self.name = name
        self.kindRaw = kind.rawValue
        self.aliases = aliases
        self.note = note
        self.anchorDate = anchorDate
        self.recursYearly = recursYearly
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
        self.mentionCount = mentionCount
        self.isForgotten = isForgotten
        self.sourceRaw = source.rawValue
        self.entries = []
        self.insights = []
    }

    var kind: ConceptKind {
        get { ConceptKind(rawValue: kindRaw) ?? .theme }
        set { kindRaw = newValue.rawValue }
    }

    var source: KnowledgeSource {
        get { KnowledgeSource(rawValue: sourceRaw) ?? .inferred }
        set { sourceRaw = newValue.rawValue }
    }

    var allNames: [String] { [name] + aliases }

    func matches(_ candidate: String) -> Bool {
        let lowered = candidate.lowercased()
        return allNames.contains { $0.lowercased() == lowered }
    }

    var sortedEntries: [JournalEntry] { entries.sorted { $0.occurredAt > $1.occurredAt } }

    /// Days until the next occurrence of an important date, if any.
    func daysUntilNextOccurrence(from now: Date = .now, calendar: Calendar = .current) -> Int? {
        guard kind == .importantDate, let anchorDate else { return nil }
        let today = calendar.startOfDay(for: now)
        var next = anchorDate
        if recursYearly {
            var comps = calendar.dateComponents([.month, .day], from: anchorDate)
            comps.year = calendar.component(.year, from: today)
            guard var candidate = calendar.date(from: comps) else { return nil }
            if candidate < today {
                comps.year! += 1
                candidate = calendar.date(from: comps) ?? candidate
            }
            next = candidate
        }
        return calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: next)).day
    }
}

enum ConceptKind: String, Codable, CaseIterable, Sendable {
    case person
    case place
    case theme
    case importantDate

    var label: String {
        switch self {
        case .person: return "Person"
        case .place: return "Place"
        case .theme: return "Theme"
        case .importantDate: return "Important date"
        }
    }

    var pluralLabel: String {
        switch self {
        case .person: return "People"
        case .place: return "Places"
        case .theme: return "Themes"
        case .importantDate: return "Important dates"
        }
    }

    var systemImage: String {
        switch self {
        case .person: return "person"
        case .place: return "mappin.and.ellipse"
        case .theme: return "circle.hexagongrid"
        case .importantDate: return "calendar"
        }
    }
}

/// Where a piece of remembered knowledge came from. Shown to the person for transparency.
enum KnowledgeSource: String, Codable, Sendable {
    case sample
    case inferred
    case user

    var label: String {
        switch self {
        case .sample: return "From the sample life"
        case .inferred: return "Noticed in your moments"
        case .user: return "Added by you"
        }
    }
}
