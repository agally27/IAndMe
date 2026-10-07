import Testing
import Foundation
@testable import IAndMe

@MainActor
struct LifeStoryServiceTests {
    @Test func draftsChapterFromSampleMoments() throws {
        let services = try TestStack.make(seedSample: true)
        let context = services.companionContext()
        let draft = LocalLifeStoryService().draftChapter(entries: context.entries, concepts: context.concepts, period: Date.now.adding(days: -92)...Date.now, now: .now)
        let chapter = try #require(draft)
        #expect(!chapter.title.isEmpty)
        #expect(chapter.body.components(separatedBy: "\n\n").count >= 3)
        #expect(chapter.entryIDs.count >= 10)
        #expect(chapter.body.contains("“"))
    }

    @Test func needsAtLeastThreeMoments() {
        let now = Date.now
        let entries = [EntrySnapshot(id: UUID(), occurredAt: now, text: "One", transcript: nil, feeling: nil, placeName: nil, conceptNames: [], hasPhotos: false, hasVoice: false, isKept: false)]
        #expect(LocalLifeStoryService().draftChapter(entries: entries, concepts: [], period: now.adding(days: -10)...now, now: now) == nil)
    }

    @Test func detectsImprovingTrend() {
        let now = Date.now
        let feelings: [Feeling] = [.heavy, .low, .low, .steady, .good, .bright]
        let entries = feelings.enumerated().map { index, feeling in
            EntrySnapshot(id: UUID(), occurredAt: now.adding(days: index - 10), text: "x", transcript: nil, feeling: feeling, placeName: nil, conceptNames: [], hasPhotos: false, hasVoice: false, isKept: false)
        }
        #expect(LocalLifeStoryService().feelingTrend(entries) == .improving)
    }
}

@MainActor
struct SampleDataTests {
    @Test func installsACoherentLife() throws {
        let services = try TestStack.make(seedSample: true)
        let entries = services.repository.allEntries()
        #expect(entries.count == SampleLife.entries.count)
        #expect(entries.allSatisfy { $0.isSample })
        #expect(entries.contains { !$0.recordings.isEmpty })
        #expect(entries.contains { !$0.attachments.isEmpty })
        #expect(services.repository.allCollections().count == SampleLife.collections.count)
        #expect(services.repository.allChapters().count == SampleLife.chapters.count)
        #expect(services.repository.allConversations().count == SampleLife.conversations.count)
        let hannah = try #require(services.repository.allConcepts(includeForgotten: false).first { $0.name == "Hannah" })
        #expect(hannah.entries.count >= 5)
        let stIves = try #require(services.repository.allConcepts(includeForgotten: false).first { $0.name == "St Ives" })
        #expect(stIves.entries.count >= 4)
        #expect(services.repository.profile().usesSampleLife)
    }

    @Test func installIsIdempotent() throws {
        let services = try TestStack.make(seedSample: true)
        try services.sample.installSampleLife(renderMedia: false)
        #expect(services.repository.allEntries().count == SampleLife.entries.count)
    }

    @Test func removingSampleLifeKeepsOwnMoments() throws {
        let services = try TestStack.make(seedSample: true)
        let mine = try services.repository.createEntry(text: "My own moment with Hannah.", occurredAt: .now, feeling: .good, placeName: nil)
        services.process(mine)
        try services.repository.deleteSampleLife()
        let remaining = services.repository.allEntries()
        #expect(remaining.count == 1)
        #expect(remaining.first?.id == mine.id)
        #expect(services.repository.allChapters().isEmpty)
        #expect(services.repository.allConversations().isEmpty)
        #expect(!services.repository.profile().usesSampleLife)
        #expect(services.repository.allConcepts(includeForgotten: true).allSatisfy { $0.source != .sample })
    }

    @Test func sundayRitualsLandOnSundays() throws {
        let services = try TestStack.make(seedSample: true)
        let bread = services.repository.allEntries().filter { $0.text.hasPrefix("Bread.") || $0.text.hasPrefix("Made bread") }
        #expect(!bread.isEmpty)
        for entry in bread {
            #expect(Calendar.current.component(.weekday, from: entry.occurredAt) == 1)
        }
    }
}

@MainActor
struct ExportServiceTests {
    @Test func markdownContainsMoments() throws {
        let services = try TestStack.make(seedSample: true)
        let url = try services.export.export(format: .markdown)
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("# Sam's journal"))
        #expect(text.contains("Coffee on the back step"))
        #expect(text.contains("Felt good"))
    }

    @Test func jsonRoundTrips() throws {
        let services = try TestStack.make(seedSample: true)
        let url = try services.export.export(format: .json)
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(JournalExport.self, from: data)
        #expect(export.entries.count == SampleLife.entries.count)
        #expect(export.concepts.contains { $0.name == "Hannah" })
    }
}

struct TextHelperTests {
    @Test func firstSentenceStopsAtPunctuation() {
        #expect(TextSnippets.firstSentence(of: "Walked the Downs. Mist on the grass.") == "Walked the Downs.")
        #expect(TextSnippets.firstSentence(of: "   ") == nil)
    }

    @Test func truncationEndsOnWordBoundary() {
        let text = "The quick brown fox jumps over the lazy dog"
        let result = TextSnippets.truncate(text, maxLength: 15)
        #expect(result == "The quick brown…")
    }

    @Test func dayLabelsAreHuman() {
        let now = Date.now
        #expect(DateFormatting.dayLabel(for: now, relativeTo: now) == "Today")
        #expect(DateFormatting.dayLabel(for: now.adding(days: -1), relativeTo: now) == "Yesterday")
        #expect(DateFormatting.prosePhrase(for: now.adding(days: -1), relativeTo: now) == "yesterday")
    }

    @Test func waveformCondensesToRequestedCount() {
        let samples = (0..<1000).map { Float($0 % 10) / 10 }
        #expect(Waveform.condense(samples, to: 120).count == 120)
        #expect(Waveform.placeholder(count: 50, key: "a") == Waveform.placeholder(count: 50, key: "a"))
        #expect(Waveform.placeholder(count: 50, key: "a") != Waveform.placeholder(count: 50, key: "b"))
    }
}
