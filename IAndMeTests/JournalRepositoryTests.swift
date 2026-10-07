import Testing
import Foundation
@testable import IAndMe

@MainActor
struct JournalRepositoryTests {
    @Test func createsEntryWithFeelingAndPlace() throws {
        let services = try TestStack.make()
        let entry = try services.repository.createEntry(text: "Walked the harbour.", occurredAt: .now, feeling: .good, placeName: "The harbour")
        #expect(entry.feeling == .good)
        #expect(entry.placeName == "The harbour")
        #expect(entry.kind == .text)
        #expect(services.repository.allEntries().count == 1)
    }

    @Test func editsPersistAcrossFetch() throws {
        let services = try TestStack.make()
        let entry = try services.repository.createEntry(text: "First draft", occurredAt: .now, feeling: nil, placeName: nil)
        entry.text = "Second draft"
        entry.feeling = .low
        try services.repository.save()
        let fetched = services.repository.entry(id: entry.id)
        #expect(fetched?.text == "Second draft")
        #expect(fetched?.feeling == .low)
    }

    @Test func deleteRemovesEntryAndMediaFiles() throws {
        let services = try TestStack.make()
        let entry = try services.repository.createEntry(text: "With a photo", occurredAt: .now, feeling: nil, placeName: nil)
        let attachment = try services.repository.addPhoto(TestStack.solidImage(), to: entry)
        let url = services.media.photoURL(named: attachment.fileName)
        #expect(FileManager.default.fileExists(atPath: url.path))
        try services.repository.delete(entry)
        #expect(services.repository.allEntries().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func entriesAreOrderedNewestFirst() throws {
        let services = try TestStack.make()
        let now = Date.now
        try services.repository.createEntry(text: "Oldest", occurredAt: now.adding(days: -3), feeling: nil, placeName: nil)
        try services.repository.createEntry(text: "Newest", occurredAt: now, feeling: nil, placeName: nil)
        try services.repository.createEntry(text: "Middle", occurredAt: now.adding(days: -1), feeling: nil, placeName: nil)
        let texts = services.repository.allEntries().map(\.text)
        #expect(texts == ["Newest", "Middle", "Oldest"])
    }

    @Test func photoAndRecordingRelationshipsDeriveKind() throws {
        let services = try TestStack.make()
        let entry = try services.repository.createEntry(text: "", occurredAt: .now, feeling: nil, placeName: nil)
        try services.repository.addPhoto(TestStack.solidImage(), to: entry)
        #expect(entry.kind == .photo)
        let (fileName, url) = services.media.newAudioFile(extension: "caf")
        #expect(SampleAudioSynthesizer.writeTone(duration: 1, to: url))
        let recording = try services.repository.addRecording(fileName: fileName, duration: 1, waveform: [0.2, 0.5], to: entry)
        #expect(entry.kind == .moment)
        #expect(entry.recordings.count == 1)
        #expect(recording.entry?.id == entry.id)
        try services.repository.removeRecording(recording)
        #expect(entry.recordings.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(entry.kind == .photo)
    }

    @Test func removingAttachmentDeletesFile() throws {
        let services = try TestStack.make()
        let entry = try services.repository.createEntry(text: "Photo", occurredAt: .now, feeling: nil, placeName: nil)
        let attachment = try services.repository.addPhoto(TestStack.solidImage(), to: entry)
        let url = services.media.photoURL(named: attachment.fileName)
        try services.repository.removeAttachment(attachment)
        #expect(entry.attachments.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func statisticsReflectJournal() throws {
        let services = try TestStack.make()
        let a = try services.repository.createEntry(text: "One two three", occurredAt: .now, feeling: .good, placeName: nil)
        a.isKept = true
        try services.repository.createEntry(text: "Four five", occurredAt: .now.adding(days: -1), feeling: nil, placeName: nil)
        try services.repository.save()
        let stats = services.repository.statistics()
        #expect(stats.entryCount == 2)
        #expect(stats.wordCount == 5)
        #expect(stats.keptCount == 1)
        #expect(stats.daysWithEntries == 2)
    }

    @Test func deleteEverythingClearsStore() throws {
        let services = try TestStack.make(seedSample: true)
        #expect(!services.repository.allEntries().isEmpty)
        try services.repository.deleteEverything()
        #expect(services.repository.allEntries().isEmpty)
        #expect(services.repository.allConcepts(includeForgotten: true).isEmpty)
        #expect(services.repository.allChapters().isEmpty)
        #expect(services.repository.allConversations().isEmpty)
        #expect(services.repository.profile().name == "Sam")
    }
}
