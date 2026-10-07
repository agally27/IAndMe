import Foundation
import SwiftData
import Observation

/// Everything the interface needs, in one injectable object. Features talk to protocols, so the
/// local implementations here can be replaced one at a time as the product grows a backend.
@MainActor
@Observable
final class AppServices {
    let container: ModelContainer
    let repository: JournalRepository
    let media: MediaService
    let companion: AICompanionService
    let memory: MemoryService
    let insights: InsightService
    let lifeStory: LifeStoryService
    let transcription: TranscriptionService
    let export: ExportService
    let sample: SampleDataService

    /// Set when the app was launched for UI testing, so animations and delays can be shortened.
    let isUITesting: Bool

    init(container: ModelContainer, isUITesting: Bool = false, replyDelay: Duration? = nil, mediaRoot: URL? = nil) {
        self.container = container
        self.isUITesting = isUITesting
        let media = mediaRoot.map { LocalMediaService(root: $0) } ?? LocalMediaService()
        let repository = SwiftDataJournalRepository(modelContext: container.mainContext, media: media)
        self.media = media
        self.repository = repository
        self.companion = LocalCompanionService(replyDelay: replyDelay ?? (isUITesting ? .zero : .milliseconds(900)))
        self.memory = LocalMemoryService()
        self.insights = LocalInsightService()
        self.lifeStory = LocalLifeStoryService()
        self.transcription = OnDeviceTranscriptionService()
        self.export = ExportService(repository: repository)
        self.sample = SampleDataService(repository: repository, media: media)
    }

    /// An isolated in-memory stack for previews and tests.
    static func preview(seeded: Bool = true) -> AppServices {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("preview-media-\(UUID().uuidString)", isDirectory: true)
        let services = AppServices(container: ModelContainerFactory.makeInMemory(), replyDelay: .zero, mediaRoot: root)
        if seeded {
            let profile = services.repository.profile()
            profile.name = "Sam"
            profile.hasCompletedOnboarding = true
            try? services.sample.installSampleLife(renderMedia: false)
        }
        return services
    }

    // MARK: - Pipeline after a moment is saved

    /// Links concepts to the entry and refreshes insights. This is the seam where a future AI
    /// processing pipeline would run.
    func process(_ entry: JournalEntry) {
        linkConcepts(for: entry)
        refreshInsights()
    }

    func linkConcepts(for entry: JournalEntry) {
        let known = repository.allConcepts(includeForgotten: true).map(CompanionContextBuilder.snapshot)
        let owner = repository.profile().name
        let text = [entry.trimmedText, entry.recordings.compactMap(\.transcript).joined(separator: " "), entry.placeName ?? ""].joined(separator: "\n")
        let mentions = memory.mentions(in: text, knownConcepts: known, ownerName: owner)
        var linked: [MemoryConcept] = []
        for mention in mentions {
            let concept: MemoryConcept
            if let id = mention.existingID, let existing = repository.concept(id: id) {
                concept = existing
            } else if let existing = repository.allConcepts(includeForgotten: true).first(where: { $0.matches(mention.name) }) {
                concept = existing
            } else {
                concept = MemoryConcept(name: mention.name, kind: mention.kind, firstSeen: entry.occurredAt, lastSeen: entry.occurredAt, source: .inferred)
                repository.modelContext.insert(concept)
            }
            if concept.isForgotten { continue }
            if !concept.entries.contains(where: { $0.id == entry.id }) {
                concept.entries.append(entry)
            }
            concept.lastSeen = max(concept.lastSeen, entry.occurredAt)
            concept.firstSeen = min(concept.firstSeen, entry.occurredAt)
            concept.mentionCount = concept.entries.count
            linked.append(concept)
        }
        // Drop links that no longer apply after an edit (only inferred ones; sample links stay).
        let linkedIDs = Set(linked.map(\.id))
        for existing in entry.concepts where !linkedIDs.contains(existing.id) && existing.source == .inferred && !entry.isSample {
            existing.entries.removeAll { $0.id == entry.id }
            existing.mentionCount = existing.entries.count
        }
        try? repository.save()
    }

    /// Recomputes inferred insights, updating in place so dismissed ones stay dismissed.
    func refreshInsights(now: Date = .now) {
        let entries = repository.allEntries().map(CompanionContextBuilder.snapshot)
        let concepts = repository.allConcepts(includeForgotten: false).map(CompanionContextBuilder.snapshot)
        let drafts = insights.generateInsights(entries: entries, concepts: concepts, now: now)
        let existing = repository.allInsights(includeDismissed: true)
        var byKey = Dictionary(uniqueKeysWithValues: existing.map { ($0.key, $0) })
        var seenKeys = Set<String>()
        for draft in drafts {
            seenKeys.insert(draft.key)
            let insight: Insight
            if let found = byKey[draft.key] {
                insight = found
                insight.title = draft.title
                insight.body = draft.body
                insight.confidence = draft.confidence
                insight.updatedAt = now
            } else {
                insight = Insight(key: draft.key, kind: draft.kind, title: draft.title, body: draft.body, confidence: draft.confidence, createdAt: now, periodStart: draft.periodStart, periodEnd: draft.periodEnd, source: .inferred)
                repository.modelContext.insert(insight)
                byKey[draft.key] = insight
            }
            insight.periodStart = draft.periodStart
            insight.periodEnd = draft.periodEnd
            insight.relatedEntries = draft.relatedEntryIDs.compactMap { repository.entry(id: $0) }
            insight.relatedConcepts = draft.relatedConceptIDs.compactMap { repository.concept(id: $0) }
        }
        for stale in existing where stale.source == .inferred && !seenKeys.contains(stale.key) {
            repository.modelContext.delete(stale)
        }
        try? repository.save()
    }

    /// Builds the companion's context from the current store.
    func companionContext(focus: JournalEntry? = nil) -> CompanionContext {
        CompanionContextBuilder(repository: repository).build(focus: focus)
    }
}
