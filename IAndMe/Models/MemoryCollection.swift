import Foundation
import SwiftData

/// A curated group of moments that belong together: a trip, a stretch of time, a ritual.
/// The journal is chronological; collections are meaningful.
@Model
final class MemoryCollection {
    @Attribute(.unique) var id: UUID
    var title: String
    var summary: String?
    var kindRaw: String
    var createdAt: Date
    var sourceRaw: String
    var coverFileName: String?
    var sortOrder: Int

    @Relationship(inverse: \JournalEntry.collections)
    var entries: [JournalEntry]

    init(
        id: UUID = UUID(),
        title: String,
        summary: String? = nil,
        kind: CollectionKind = .experience,
        createdAt: Date = .now,
        source: KnowledgeSource = .user,
        coverFileName: String? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.kindRaw = kind.rawValue
        self.createdAt = createdAt
        self.sourceRaw = source.rawValue
        self.coverFileName = coverFileName
        self.sortOrder = sortOrder
        self.entries = []
    }

    var kind: CollectionKind {
        get { CollectionKind(rawValue: kindRaw) ?? .experience }
        set { kindRaw = newValue.rawValue }
    }

    var source: KnowledgeSource {
        get { KnowledgeSource(rawValue: sourceRaw) ?? .user }
        set { sourceRaw = newValue.rawValue }
    }

    var sortedEntries: [JournalEntry] { entries.sorted { $0.occurredAt < $1.occurredAt } }

    var dateRange: ClosedRange<Date>? {
        let dates = entries.map(\.occurredAt)
        guard let first = dates.min(), let last = dates.max() else { return nil }
        return first...last
    }

    /// The first photo across the collection's moments, used as a cover when none is set.
    var resolvedCoverFileName: String? {
        coverFileName ?? sortedEntries.lazy.compactMap { $0.coverAttachment?.fileName }.first
    }
}

enum CollectionKind: String, Codable, CaseIterable, Sendable {
    case experience
    case ritual
    case milestone
    case unexpected

    var label: String {
        switch self {
        case .experience: return "Experience"
        case .ritual: return "Ritual"
        case .milestone: return "Milestone"
        case .unexpected: return "Unexpected"
        }
    }
}
