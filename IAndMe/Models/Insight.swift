import Foundation
import SwiftData

/// An observation the app has made about the person's moments. Always phrased with appropriate
/// uncertainty and always traceable to the moments it came from.
@Model
final class Insight {
    @Attribute(.unique) var id: UUID
    /// Stable key so regenerated insights update in place instead of duplicating.
    var key: String
    var kindRaw: String
    var title: String
    var body: String
    var confidenceRaw: String
    var createdAt: Date
    var updatedAt: Date
    var periodStart: Date?
    var periodEnd: Date?
    var isDismissed: Bool
    var sourceRaw: String

    @Relationship(inverse: \JournalEntry.insights)
    var relatedEntries: [JournalEntry]

    @Relationship(inverse: \MemoryConcept.insights)
    var relatedConcepts: [MemoryConcept]

    init(
        id: UUID = UUID(),
        key: String,
        kind: InsightKind,
        title: String,
        body: String,
        confidence: InsightConfidence,
        createdAt: Date = .now,
        periodStart: Date? = nil,
        periodEnd: Date? = nil,
        isDismissed: Bool = false,
        source: KnowledgeSource = .inferred
    ) {
        self.id = id
        self.key = key
        self.kindRaw = kind.rawValue
        self.title = title
        self.body = body
        self.confidenceRaw = confidence.rawValue
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.isDismissed = isDismissed
        self.sourceRaw = source.rawValue
        self.relatedEntries = []
        self.relatedConcepts = []
    }

    var kind: InsightKind {
        get { InsightKind(rawValue: kindRaw) ?? .noticed }
        set { kindRaw = newValue.rawValue }
    }

    var confidence: InsightConfidence {
        get { InsightConfidence(rawValue: confidenceRaw) ?? .tentative }
        set { confidenceRaw = newValue.rawValue }
    }

    var source: KnowledgeSource {
        get { KnowledgeSource(rawValue: sourceRaw) ?? .inferred }
        set { sourceRaw = newValue.rawValue }
    }

    var sortedEntries: [JournalEntry] { relatedEntries.sorted { $0.occurredAt > $1.occurredAt } }
}

enum InsightKind: String, Codable, CaseIterable, Sendable {
    case noticed      // "Something I've noticed"
    case lifted       // "Moments that lifted you"
    case recurring    // "Recurring thoughts"
    case people
    case places
    case difficult    // "A harder stretch"
    case rhythm       // "When you write"

    var sectionTitle: String {
        switch self {
        case .noticed: return "Something I've noticed"
        case .lifted: return "Moments that lifted you"
        case .recurring: return "Recurring thoughts"
        case .people: return "People"
        case .places: return "Places"
        case .difficult: return "Harder stretches"
        case .rhythm: return "Your rhythm"
        }
    }

    var systemImage: String {
        switch self {
        case .noticed: return "eye"
        case .lifted: return "sun.max"
        case .recurring: return "arrow.triangle.2.circlepath"
        case .people: return "person.2"
        case .places: return "mappin.and.ellipse"
        case .difficult: return "cloud.rain"
        case .rhythm: return "clock"
        }
    }
}

/// How sure the app is. Drives the hedging language ("I may be seeing…", "It seems…", "You've mentioned…").
enum InsightConfidence: String, Codable, Comparable, Sendable {
    case tentative
    case moderate
    case strong

    private var order: Int {
        switch self {
        case .tentative: return 0
        case .moderate: return 1
        case .strong: return 2
        }
    }

    static func < (lhs: InsightConfidence, rhs: InsightConfidence) -> Bool { lhs.order < rhs.order }

    var label: String {
        switch self {
        case .tentative: return "I may be seeing a pattern"
        case .moderate: return "It seems"
        case .strong: return "You've mentioned this often"
        }
    }
}
