import Foundation
import SwiftData

/// A chapter of the person's story: an editorial piece drawn from many small moments.
@Model
final class LifeChapter {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var title: String
    var subtitle: String?
    /// Paragraphs separated by blank lines.
    var body: String
    var periodStart: Date?
    var periodEnd: Date?
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    var sourceRaw: String
    var coverFileName: String?

    @Relationship(inverse: \JournalEntry.chapters)
    var entries: [JournalEntry]

    init(
        id: UUID = UUID(),
        kind: ChapterKind,
        title: String,
        subtitle: String? = nil,
        body: String,
        periodStart: Date? = nil,
        periodEnd: Date? = nil,
        sortOrder: Int = 0,
        createdAt: Date = .now,
        source: KnowledgeSource = .inferred,
        coverFileName: String? = nil
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.sourceRaw = source.rawValue
        self.coverFileName = coverFileName
        self.entries = []
    }

    var kind: ChapterKind {
        get { ChapterKind(rawValue: kindRaw) ?? .period }
        set { kindRaw = newValue.rawValue }
    }

    var source: KnowledgeSource {
        get { KnowledgeSource(rawValue: sourceRaw) ?? .inferred }
        set { sourceRaw = newValue.rawValue }
    }

    var paragraphs: [String] {
        body.components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    var sortedEntries: [JournalEntry] { entries.sorted { $0.occurredAt < $1.occurredAt } }

    var resolvedCoverFileName: String? {
        coverFileName ?? sortedEntries.lazy.compactMap { $0.coverAttachment?.fileName }.first
    }
}

enum ChapterKind: String, Codable, CaseIterable, Sendable {
    case present    // Who I am now
    case period     // A stretch of time
    case people     // People who shaped me
    case places     // Places I've been
    case learned    // Things I've learned
    case remember   // Moments I want to remember

    var label: String {
        switch self {
        case .present: return "Who I am now"
        case .period: return "Chapter"
        case .people: return "People who shaped me"
        case .places: return "Places I keep returning to"
        case .learned: return "Things I've learned"
        case .remember: return "Moments I want to remember"
        }
    }
}
