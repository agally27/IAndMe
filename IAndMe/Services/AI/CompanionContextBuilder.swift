import Foundation

/// Builds the plain-value context the companion works from. Runs on the main actor because it reads
/// SwiftData objects; the result is Sendable and can go anywhere.
@MainActor
struct CompanionContextBuilder {
    let repository: JournalRepository

    func build(focus: JournalEntry? = nil, now: Date = .now) -> CompanionContext {
        let profile = repository.profile()
        let entries = repository.allEntries().map(Self.snapshot)
        let concepts = repository.allConcepts(includeForgotten: false).map(Self.snapshot)
        let insights = repository.allInsights(includeDismissed: false).map(Self.snapshot)
        return CompanionContext(
            userName: profile.firstName,
            now: now,
            focusEntry: focus.map(Self.snapshot),
            entries: entries,
            concepts: concepts,
            insights: insights
        )
    }

    static func snapshot(_ entry: JournalEntry) -> EntrySnapshot {
        EntrySnapshot(
            id: entry.id,
            occurredAt: entry.occurredAt,
            text: entry.trimmedText,
            transcript: entry.recordings.compactMap(\.transcript).joined(separator: " ").nilIfEmpty,
            feeling: entry.feeling,
            placeName: entry.placeName,
            conceptNames: entry.concepts.filter { !$0.isForgotten }.map(\.name),
            hasPhotos: !entry.attachments.isEmpty,
            hasVoice: !entry.recordings.isEmpty,
            isKept: entry.isKept
        )
    }

    static func snapshot(_ concept: MemoryConcept) -> ConceptSnapshot {
        ConceptSnapshot(
            id: concept.id,
            name: concept.name,
            kind: concept.kind,
            aliases: concept.aliases,
            note: concept.note,
            mentionCount: max(concept.mentionCount, concept.entries.count),
            lastSeen: concept.lastSeen,
            anchorDate: concept.anchorDate,
            recursYearly: concept.recursYearly
        )
    }

    static func snapshot(_ insight: Insight) -> InsightSnapshot {
        InsightSnapshot(id: insight.id, kind: insight.kind, title: insight.title, body: insight.body, relatedEntryIDs: insight.relatedEntries.map(\.id))
    }

    static func snapshot(_ message: ConversationMessage) -> MessageSnapshot {
        MessageSnapshot(id: message.id, role: message.role, text: message.text, createdAt: message.createdAt)
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
