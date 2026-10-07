import Testing
import Foundation
@testable import IAndMe

@MainActor
struct MemoryServiceTests {
    @Test func recognisesKnownConceptsByAlias() {
        let service = LocalMemoryService()
        let hannah = ConceptSnapshot(id: UUID(), name: "Hannah", kind: .person, aliases: ["Han"], note: nil, mentionCount: 3, lastSeen: .now, anchorDate: nil, recursYearly: false)
        let harbour = ConceptSnapshot(id: UUID(), name: "The harbour", kind: .place, aliases: ["harbour"], note: nil, mentionCount: 3, lastSeen: .now, anchorDate: nil, recursYearly: false)
        let mentions = service.mentions(in: "Walked the harbour with Han after work.", knownConcepts: [hannah, harbour], ownerName: "Sam")
        #expect(mentions.contains { $0.name == "Hannah" && $0.existingID == hannah.id })
        #expect(mentions.contains { $0.name == "The harbour" && $0.existingID == harbour.id })
        #expect(mentions.contains { $0.name == "Walking" && $0.kind == .theme })
        #expect(mentions.contains { $0.name == "Work" && $0.kind == .theme })
    }

    @Test func doesNotTreatOwnerNameAsPerson() {
        let service = LocalMemoryService()
        let mentions = service.mentions(in: "Sam went to Bristol with Priya.", knownConcepts: [], ownerName: "Sam")
        #expect(!mentions.contains { $0.name == "Sam" })
        #expect(mentions.contains { $0.name == "Priya" && $0.kind == .person })
    }

    @Test func linkingAttachesConceptsToEntry() throws {
        let services = try TestStack.make()
        let entry = try services.repository.createEntry(text: "Ran with Tom along the river. Slept badly.", occurredAt: .now, feeling: .steady, placeName: nil)
        services.process(entry)
        let names = Set(entry.concepts.map(\.name))
        #expect(names.contains("Tom"))
        #expect(names.contains("Running"))
        #expect(names.contains("Sleep"))
        let tom = services.repository.allConcepts(includeForgotten: false).first { $0.name == "Tom" }
        #expect(tom?.mentionCount == 1)
        #expect(tom?.source == .inferred)
    }

    @Test func forgottenConceptsAreNotLinked() throws {
        let services = try TestStack.make()
        let concept = MemoryConcept(name: "Tom", kind: .person, isForgotten: true, source: .inferred)
        services.repository.modelContext.insert(concept)
        try services.repository.save()
        let entry = try services.repository.createEntry(text: "Coffee with Tom.", occurredAt: .now, feeling: nil, placeName: nil)
        services.process(entry)
        #expect(!entry.concepts.contains { $0.name == "Tom" })
    }
}

@MainActor
struct InsightServiceTests {
    private func snapshot(_ text: String, daysAgo: Int, hour: Int = 12, feeling: Feeling?, concepts: [String], now: Date) -> EntrySnapshot {
        EntrySnapshot(id: UUID(), occurredAt: now.adding(days: -daysAgo).at(hour: hour), text: text, transcript: nil, feeling: feeling, placeName: nil, conceptNames: concepts, hasPhotos: false, hasVoice: false, isKept: false)
    }

    @Test func noticesReliefPatternAfterDifficultDays() {
        let now = Date.now.startOfDay.at(hour: 23)
        let walking = ConceptSnapshot(id: UUID(), name: "Walking", kind: .theme, aliases: [], note: nil, mentionCount: 3, lastSeen: now, anchorDate: nil, recursYearly: false)
        var entries: [EntrySnapshot] = []
        for pair in [(20, 19), (14, 13), (8, 7)] {
            entries.append(snapshot("Awful day at work.", daysAgo: pair.0, hour: 22, feeling: .heavy, concepts: ["Work"], now: now))
            entries.append(snapshot("Walked it off.", daysAgo: pair.1, hour: 18, feeling: .steady, concepts: ["Walking"], now: now))
        }
        let drafts = LocalInsightService().generateInsights(entries: entries, concepts: [walking], now: now)
        let relief = drafts.first { $0.kind == .noticed && $0.relatedConceptIDs.contains(walking.id) }
        #expect(relief != nil)
        #expect(relief?.relatedEntryIDs.count == 3)
        #expect(relief?.confidence == .moderate)
    }

    @Test func recurringThemeNeedsThreeMentions() {
        let now = Date.now.startOfDay.at(hour: 23)
        let work = ConceptSnapshot(id: UUID(), name: "Work", kind: .theme, aliases: [], note: nil, mentionCount: 2, lastSeen: now, anchorDate: nil, recursYearly: false)
        let two = [snapshot("Work.", daysAgo: 3, feeling: nil, concepts: ["Work"], now: now), snapshot("Work again.", daysAgo: 2, feeling: nil, concepts: ["Work"], now: now), snapshot("Nothing.", daysAgo: 1, feeling: nil, concepts: [], now: now)]
        #expect(!LocalInsightService().generateInsights(entries: two, concepts: [work], now: now).contains { $0.kind == .recurring })
        let three = two + [snapshot("Work once more.", daysAgo: 0, feeling: nil, concepts: ["Work"], now: now)]
        #expect(LocalInsightService().generateInsights(entries: three, concepts: [work], now: now).contains { $0.kind == .recurring })
    }

    @Test func tooFewEntriesProduceNothing() {
        let now = Date.now
        let entries = [snapshot("One.", daysAgo: 1, feeling: .heavy, concepts: [], now: now), snapshot("Two.", daysAgo: 0, feeling: .heavy, concepts: [], now: now)]
        #expect(LocalInsightService().generateInsights(entries: entries, concepts: [], now: now).isEmpty)
    }

    @Test func sampleLifeYieldsExpectedObservations() throws {
        let services = try TestStack.make(seedSample: true)
        let insights = services.repository.allInsights(includeDismissed: false)
        #expect(!insights.isEmpty)
        #expect(insights.contains { $0.kind == .noticed && $0.title.contains("after harder days") })
        #expect(insights.contains { $0.kind == .recurring && $0.title.contains("Work") })
        #expect(insights.contains { $0.kind == .lifted && $0.title.contains("St Ives") })
        #expect(insights.contains { $0.kind == .people })
        for insight in insights where insight.source == .inferred {
            #expect(!insight.body.isEmpty)
        }
    }

    @Test func refreshKeepsDismissedInsightsDismissed() throws {
        let services = try TestStack.make(seedSample: true)
        guard let first = services.repository.allInsights(includeDismissed: false).first else {
            Issue.record("Expected at least one insight")
            return
        }
        first.isDismissed = true
        try services.repository.save()
        services.refreshInsights()
        let again = services.repository.allInsights(includeDismissed: true).first { $0.key == first.key }
        #expect(again?.isDismissed == true)
    }
}

@MainActor
struct InferredConceptQualityTests {
    /// Inferred concepts come from the on-device tagger plus a small heuristic; this guards against junk.
    @Test func inferredConceptsLookLikeNames() throws {
        let services = try TestStack.make(seedSample: true)
        let inferred = services.repository.allConcepts(includeForgotten: true).filter { $0.source == .inferred && $0.kind != .theme }
        print("Inferred concepts:", inferred.map { "\($0.name) (\($0.kind.rawValue), \($0.entries.count))" }.joined(separator: ", "))
        for concept in inferred {
            #expect(concept.name.count >= 3, "\(concept.name)")
            #expect(concept.name.first?.isUppercase == true, "\(concept.name)")
            #expect(!Lexicon.stopWords.contains(concept.name.lowercased()), "\(concept.name)")
        }
        #expect(inferred.contains { $0.name == "Priya" })
        #expect(inferred.contains { $0.name == "Claire" })
        for junk in ["Sent Hannah", "Reorg", "Tiny", "Hannah asleep", "Gulls", "Ives"] {
            #expect(!inferred.contains { $0.name == junk }, Comment(rawValue: junk))
        }
    }

    @Test func noReliefInsightForWork() throws {
        let services = try TestStack.make(seedSample: true)
        let insights = services.repository.allInsights(includeDismissed: false)
        #expect(!insights.contains { $0.kind == .noticed && $0.title.hasPrefix("Work") })
        #expect(insights.contains { $0.kind == .noticed && $0.title.hasPrefix("Walking") })
    }
}
