import Foundation
import SwiftData
import UIKit

/// Installs the fictional sample life so the app never opens as an empty shell.
/// Everything it creates is marked as sample so it can be removed cleanly, leaving the person's
/// own moments untouched.
@MainActor
final class SampleDataService {
    private let repository: JournalRepository
    private let media: MediaService
    private let calendar = Calendar.current

    init(repository: JournalRepository, media: MediaService) {
        self.repository = repository
        self.media = media
    }

    var isInstalled: Bool {
        repository.allEntries().contains(where: \.isSample)
    }

    /// Creates entries, concepts, collections, chapters and conversations. When `renderMedia` is
    /// true, placeholder photographs are rendered and sample voice notes are synthesised in the
    /// background.
    func installSampleLife(renderMedia: Bool = true, now: Date = .now) throws {
        guard !isInstalled else { return }
        let context = repository.modelContext

        // Concepts first so entries link to them deterministically.
        var concepts: [String: MemoryConcept] = [:]
        for person in SampleLife.people {
            let concept = MemoryConcept(name: person.name, kind: .person, aliases: person.aliases, note: person.note, firstSeen: now, lastSeen: now, source: .sample)
            context.insert(concept)
            concepts[person.name] = concept
        }
        for place in SampleLife.places {
            let concept = MemoryConcept(name: place.name, kind: .place, aliases: place.aliases, note: place.note, firstSeen: now, lastSeen: now, source: .sample)
            context.insert(concept)
            concepts[place.name] = concept
        }
        for date in SampleLife.importantDates {
            let anchor = calendar.startOfDay(for: now).adding(days: date.daysFromNow)
            let concept = MemoryConcept(name: date.name, kind: .importantDate, note: date.note.isEmpty ? nil : date.note, anchorDate: anchor, recursYearly: date.recursYearly, firstSeen: anchor, lastSeen: anchor, mentionCount: 1, source: .sample)
            context.insert(concept)
            concepts[date.name] = concept
        }

        // Entries
        var entriesByKey: [String: JournalEntry] = [:]
        var pendingVoice: [(VoiceRecording, String)] = []
        for seed in SampleLife.entries {
            let occurredAt = date(daysAgo: seed.daysAgo, weekday: seed.weekday, hour: seed.hour, minute: seed.minute, now: now)
            let entry = JournalEntry(createdAt: occurredAt, occurredAt: occurredAt, text: seed.text, feeling: seed.feeling, isKept: seed.kept, placeName: seed.place, isSample: true)
            context.insert(entry)
            entriesByKey[seed.key] = entry

            for (index, scene) in seed.photos.enumerated() {
                let fileName = "sample-\(seed.key)-\(index).jpg"
                let size = scene.isPortrait ? (900, 1200) : (1200, 900)
                let attachment = MediaAttachment(fileName: fileName, createdAt: occurredAt, pixelWidth: size.0, pixelHeight: size.1, sortOrder: index)
                entry.attachments.append(attachment)
                if renderMedia, !FileManager.default.fileExists(atPath: media.photoURL(named: fileName).path) {
                    let image = SampleImageRenderer.render(scene)
                    if let data = image.jpegData(compressionQuality: 0.85) {
                        try? data.write(to: media.photoURL(named: fileName), options: .atomic)
                    }
                }
            }

            if let voice = seed.voice {
                let fileName = "sample-\(seed.key).caf"
                let recording = VoiceRecording(fileName: fileName, createdAt: occurredAt, duration: voice.duration, waveform: Waveform.placeholder(key: seed.key), transcript: voice.transcript, transcriptionState: .done)
                entry.recordings.append(recording)
                pendingVoice.append((recording, voice.transcript))
            }
        }
        try context.save()

        // Link concepts to entries using the same memory service the live app uses.
        let memory = LocalMemoryService()
        let owner = repository.profile().name
        for entry in entriesByKey.values {
            let known = Array(concepts.values).map(CompanionContextBuilder.snapshot) + repository.allConcepts(includeForgotten: true).filter { concepts[$0.name] == nil }.map(CompanionContextBuilder.snapshot)
            let text = [entry.text, entry.recordings.compactMap(\.transcript).joined(separator: " "), entry.placeName ?? ""].joined(separator: "\n")
            for mention in memory.mentions(in: text, knownConcepts: known, ownerName: owner) {
                let concept: MemoryConcept
                if let existing = concepts[mention.name] {
                    concept = existing
                } else if let existing = repository.allConcepts(includeForgotten: true).first(where: { $0.matches(mention.name) }) {
                    concept = existing
                } else {
                    concept = MemoryConcept(name: mention.name, kind: mention.kind, firstSeen: entry.occurredAt, lastSeen: entry.occurredAt, source: .inferred)
                    context.insert(concept)
                    concepts[mention.name] = concept
                }
                if !concept.entries.contains(where: { $0.id == entry.id }) {
                    concept.entries.append(entry)
                }
            }
        }
        for concept in concepts.values where concept.kind != .importantDate {
            let dates = concept.entries.map(\.occurredAt)
            concept.mentionCount = concept.entries.count
            if let first = dates.min() { concept.firstSeen = first }
            if let last = dates.max() { concept.lastSeen = last }
        }

        // Collections
        for (index, seed) in SampleLife.collections.enumerated() {
            let collection = MemoryCollection(title: seed.title, summary: seed.summary, kind: seed.kind, createdAt: now, source: .sample, sortOrder: index)
            collection.entries = seed.entryKeys.compactMap { entriesByKey[$0] }
            context.insert(collection)
        }

        // Chapters
        for (index, seed) in SampleLife.chapters.enumerated() {
            let entries = seed.entryKeys.compactMap { entriesByKey[$0] }
            let dates = entries.map(\.occurredAt)
            let chapter = LifeChapter(
                kind: seed.kind,
                title: seed.title,
                subtitle: seed.subtitle ?? DateFormatting.periodLabel(from: dates.min(), to: dates.max()),
                body: seed.body,
                periodStart: dates.min(),
                periodEnd: dates.max(),
                sortOrder: index,
                createdAt: now,
                source: .sample,
                coverFileName: seed.coverKey.flatMap { entriesByKey[$0]?.coverAttachment?.fileName }
            )
            chapter.entries = entries
            context.insert(chapter)
        }

        // Conversations
        for seed in SampleLife.conversations {
            let createdAt = now.adding(days: -seed.daysAgo).at(hour: 20, minute: 30)
            let conversation = Conversation(title: seed.title, createdAt: createdAt, isSample: true, entry: seed.aboutEntryKey.flatMap { entriesByKey[$0] })
            context.insert(conversation)
            for (offset, message) in seed.messages.enumerated() {
                let suggestions = message.suggestions.map { CompanionSuggestion.say($0) }
                let m = ConversationMessage(role: message.role, text: message.text, createdAt: createdAt.addingTimeInterval(Double(offset) * 45), referencedEntryIDs: message.refs.compactMap { entriesByKey[$0]?.id }, suggestions: suggestions)
                conversation.messages.append(m)
            }
            conversation.updatedAt = createdAt.addingTimeInterval(Double(seed.messages.count) * 45)
        }

        let profile = repository.profile()
        profile.usesSampleLife = true
        try context.save()

        if renderMedia {
            let jobs = pendingVoice.map { ($0.0.fileName, $0.1) }
            let media = self.media
            Task.detached(priority: .utility) {
                for (fileName, transcript) in jobs {
                    let url = media.audioURL(named: fileName)
                    if FileManager.default.fileExists(atPath: url.path) { continue }
                    _ = await SampleAudioSynthesizer.synthesize(text: transcript, to: url)
                }
            }
        }
    }

    private func date(daysAgo: Int, weekday: Int?, hour: Int, minute: Int, now: Date) -> Date {
        var day = calendar.startOfDay(for: now).adding(days: -daysAgo)
        if let weekday {
            var attempts = 0
            while calendar.component(.weekday, from: day) != weekday && attempts < 7 {
                day = day.adding(days: -1)
                attempts += 1
            }
        }
        return min(day.at(hour: hour, minute: minute), now)
    }
}
