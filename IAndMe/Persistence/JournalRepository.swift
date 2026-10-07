import Foundation
import SwiftData
import UIKit

/// The single door into the journal. Views read through `@Query`; every mutation goes through here so
/// media files, derived knowledge and persistence stay consistent. A future synced or remote
/// implementation would conform to the same protocol.
@MainActor
protocol JournalRepository: AnyObject {
    var modelContext: ModelContext { get }

    // Profile
    func profile() -> UserProfile

    // Entries
    @discardableResult
    func createEntry(text: String, occurredAt: Date, feeling: Feeling?, placeName: String?) throws -> JournalEntry
    func save() throws
    func delete(_ entry: JournalEntry) throws
    func allEntries() -> [JournalEntry]
    func entries(from start: Date, to end: Date) -> [JournalEntry]
    func entry(id: UUID) -> JournalEntry?
    func recentEntries(limit: Int) -> [JournalEntry]

    // Media
    @discardableResult
    func addPhoto(_ image: UIImage, to entry: JournalEntry) throws -> MediaAttachment
    func removeAttachment(_ attachment: MediaAttachment) throws
    @discardableResult
    func addRecording(fileName: String, duration: TimeInterval, waveform: [Float], to entry: JournalEntry) throws -> VoiceRecording
    func removeRecording(_ recording: VoiceRecording) throws

    // Concepts
    func allConcepts(includeForgotten: Bool) -> [MemoryConcept]
    func concept(id: UUID) -> MemoryConcept?

    // Conversations
    func allConversations() -> [Conversation]
    func conversation(id: UUID) -> Conversation?
    @discardableResult
    func createConversation(title: String, about entry: JournalEntry?) throws -> Conversation
    func delete(_ conversation: Conversation) throws

    // Collections, insights, chapters
    func allCollections() -> [MemoryCollection]
    func allInsights(includeDismissed: Bool) -> [Insight]
    func allChapters() -> [LifeChapter]

    // Whole-journal operations
    func statistics() -> JournalStatistics
    func deleteEverything() throws
    func deleteSampleLife() throws
}

struct JournalStatistics: Sendable {
    var entryCount: Int
    var photoCount: Int
    var voiceCount: Int
    var voiceDuration: TimeInterval
    var keptCount: Int
    var wordCount: Int
    var firstEntryDate: Date?
    var daysWithEntries: Int
    var conceptCount: Int
    var conversationCount: Int
    var mediaBytes: Int64

    static let empty = JournalStatistics(entryCount: 0, photoCount: 0, voiceCount: 0, voiceDuration: 0, keptCount: 0, wordCount: 0, firstEntryDate: nil, daysWithEntries: 0, conceptCount: 0, conversationCount: 0, mediaBytes: 0)
}
