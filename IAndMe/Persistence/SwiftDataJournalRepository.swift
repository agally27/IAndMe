import Foundation
import SwiftData
import UIKit

@MainActor
final class SwiftDataJournalRepository: JournalRepository {
    let modelContext: ModelContext
    private let media: MediaService

    init(modelContext: ModelContext, media: MediaService) {
        self.modelContext = modelContext
        self.media = media
    }

    // MARK: Profile

    func profile() -> UserProfile {
        let descriptor = FetchDescriptor<UserProfile>(sortBy: [SortDescriptor(\.createdAt)])
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let profile = UserProfile()
        modelContext.insert(profile)
        try? modelContext.save()
        return profile
    }

    // MARK: Entries

    @discardableResult
    func createEntry(text: String, occurredAt: Date = .now, feeling: Feeling? = nil, placeName: String? = nil) throws -> JournalEntry {
        let entry = JournalEntry(occurredAt: occurredAt, text: text, feeling: feeling, placeName: placeName)
        modelContext.insert(entry)
        try modelContext.save()
        return entry
    }

    func save() throws {
        try modelContext.save()
    }

    func delete(_ entry: JournalEntry) throws {
        for attachment in entry.attachments { media.deletePhoto(named: attachment.fileName) }
        for recording in entry.recordings { media.deleteAudio(named: recording.fileName) }
        modelContext.delete(entry)
        try modelContext.save()
    }

    func allEntries() -> [JournalEntry] {
        let descriptor = FetchDescriptor<JournalEntry>(sortBy: [SortDescriptor(\.occurredAt, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func entries(from start: Date, to end: Date) -> [JournalEntry] {
        let predicate = #Predicate<JournalEntry> { $0.occurredAt >= start && $0.occurredAt <= end }
        let descriptor = FetchDescriptor<JournalEntry>(predicate: predicate, sortBy: [SortDescriptor(\.occurredAt, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func entry(id: UUID) -> JournalEntry? {
        let predicate = #Predicate<JournalEntry> { $0.id == id }
        var descriptor = FetchDescriptor<JournalEntry>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    func recentEntries(limit: Int) -> [JournalEntry] {
        var descriptor = FetchDescriptor<JournalEntry>(sortBy: [SortDescriptor(\.occurredAt, order: .reverse)])
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: Media

    @discardableResult
    func addPhoto(_ image: UIImage, to entry: JournalEntry) throws -> MediaAttachment {
        let stored = try media.storePhoto(image)
        let attachment = MediaAttachment(
            fileName: stored.fileName,
            pixelWidth: stored.pixelWidth,
            pixelHeight: stored.pixelHeight,
            sortOrder: (entry.attachments.map(\.sortOrder).max() ?? -1) + 1
        )
        entry.attachments.append(attachment)
        entry.updatedAt = .now
        try modelContext.save()
        return attachment
    }

    func removeAttachment(_ attachment: MediaAttachment) throws {
        media.deletePhoto(named: attachment.fileName)
        if let entry = attachment.entry {
            entry.attachments.removeAll { $0.id == attachment.id }
            entry.updatedAt = .now
        }
        modelContext.delete(attachment)
        try modelContext.save()
    }

    @discardableResult
    func addRecording(fileName: String, duration: TimeInterval, waveform: [Float], to entry: JournalEntry) throws -> VoiceRecording {
        let recording = VoiceRecording(fileName: fileName, duration: duration, waveform: waveform)
        entry.recordings.append(recording)
        entry.updatedAt = .now
        try modelContext.save()
        return recording
    }

    func removeRecording(_ recording: VoiceRecording) throws {
        media.deleteAudio(named: recording.fileName)
        if let entry = recording.entry {
            entry.recordings.removeAll { $0.id == recording.id }
            entry.updatedAt = .now
        }
        modelContext.delete(recording)
        try modelContext.save()
    }

    // MARK: Concepts

    func allConcepts(includeForgotten: Bool = false) -> [MemoryConcept] {
        let descriptor = FetchDescriptor<MemoryConcept>(sortBy: [SortDescriptor(\.mentionCount, order: .reverse)])
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return includeForgotten ? all : all.filter { !$0.isForgotten }
    }

    func concept(id: UUID) -> MemoryConcept? {
        let predicate = #Predicate<MemoryConcept> { $0.id == id }
        var descriptor = FetchDescriptor<MemoryConcept>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: Conversations

    func allConversations() -> [Conversation] {
        let descriptor = FetchDescriptor<Conversation>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func conversation(id: UUID) -> Conversation? {
        let predicate = #Predicate<Conversation> { $0.id == id }
        var descriptor = FetchDescriptor<Conversation>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    @discardableResult
    func createConversation(title: String, about entry: JournalEntry?) throws -> Conversation {
        let conversation = Conversation(title: title, entry: entry)
        modelContext.insert(conversation)
        try modelContext.save()
        return conversation
    }

    func delete(_ conversation: Conversation) throws {
        modelContext.delete(conversation)
        try modelContext.save()
    }

    // MARK: Collections, insights, chapters

    func allCollections() -> [MemoryCollection] {
        let descriptor = FetchDescriptor<MemoryCollection>(sortBy: [SortDescriptor(\.sortOrder)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func allInsights(includeDismissed: Bool = false) -> [Insight] {
        let descriptor = FetchDescriptor<Insight>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return includeDismissed ? all : all.filter { !$0.isDismissed }
    }

    func allChapters() -> [LifeChapter] {
        let descriptor = FetchDescriptor<LifeChapter>(sortBy: [SortDescriptor(\.sortOrder)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: Whole journal

    func statistics() -> JournalStatistics {
        let entries = allEntries()
        let calendar = Calendar.current
        let days = Set(entries.map { calendar.startOfDay(for: $0.occurredAt) })
        let recordings = entries.flatMap(\.recordings)
        return JournalStatistics(
            entryCount: entries.count,
            photoCount: entries.reduce(0) { $0 + $1.attachments.count },
            voiceCount: recordings.count,
            voiceDuration: recordings.reduce(0) { $0 + $1.duration },
            keptCount: entries.filter(\.isKept).count,
            wordCount: entries.reduce(0) { $0 + TextSnippets.wordCount($1.text) },
            firstEntryDate: entries.map(\.occurredAt).min(),
            daysWithEntries: days.count,
            conceptCount: allConcepts(includeForgotten: false).count,
            conversationCount: allConversations().count,
            mediaBytes: media.totalBytes()
        )
    }

    func deleteEverything() throws {
        // Deleted object by object so cascade rules and inverse relationships are honoured.
        for conversation in allConversations() { modelContext.delete(conversation) }
        for insight in allInsights(includeDismissed: true) { modelContext.delete(insight) }
        for chapter in allChapters() { modelContext.delete(chapter) }
        for collection in allCollections() { modelContext.delete(collection) }
        for concept in allConcepts(includeForgotten: true) { modelContext.delete(concept) }
        for entry in allEntries() { modelContext.delete(entry) }
        try modelContext.save()
        media.deleteAll()
        let profile = profile()
        profile.usesSampleLife = false
        try modelContext.save()
    }

    /// Removes only the fictional sample life, leaving the person's own moments untouched.
    func deleteSampleLife() throws {
        for entry in allEntries() where entry.isSample {
            for attachment in entry.attachments { media.deletePhoto(named: attachment.fileName) }
            for recording in entry.recordings { media.deleteAudio(named: recording.fileName) }
            modelContext.delete(entry)
        }
        for conversation in allConversations() where conversation.isSample {
            modelContext.delete(conversation)
        }
        for concept in allConcepts(includeForgotten: true) where concept.source == .sample {
            modelContext.delete(concept)
        }
        for collection in allCollections() where collection.source == .sample {
            modelContext.delete(collection)
        }
        for insight in allInsights(includeDismissed: true) where insight.source == .sample {
            modelContext.delete(insight)
        }
        for chapter in allChapters() where chapter.source == .sample {
            modelContext.delete(chapter)
        }
        let profile = profile()
        profile.usesSampleLife = false
        try modelContext.save()
    }
}
