import Foundation
import SwiftData

/// A single captured moment. Text, photos, voice and a feeling can all live together in one entry;
/// the person never has to decide what "type" of entry it is.
@Model
final class JournalEntry {
    @Attribute(.unique) var id: UUID
    /// When the moment was captured in the app.
    var createdAt: Date
    /// When the moment actually happened. Editable, so older memories can be placed correctly.
    var occurredAt: Date
    var updatedAt: Date
    var text: String
    var feelingRaw: Int?
    /// Marked by the person as worth remembering. Surfaces in Memories and the Story.
    var isKept: Bool
    var placeName: String?
    var isSample: Bool

    @Relationship(deleteRule: .cascade, inverse: \MediaAttachment.entry)
    var attachments: [MediaAttachment]

    @Relationship(deleteRule: .cascade, inverse: \VoiceRecording.entry)
    var recordings: [VoiceRecording]

    /// People, places and themes the memory layer has linked to this moment.
    @Relationship(inverse: \MemoryConcept.entries)
    var concepts: [MemoryConcept]

    @Relationship(deleteRule: .cascade, inverse: \Conversation.entry)
    var conversations: [Conversation]

    var collections: [MemoryCollection]
    var insights: [Insight]
    var chapters: [LifeChapter]

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        occurredAt: Date = .now,
        text: String = "",
        feeling: Feeling? = nil,
        isKept: Bool = false,
        placeName: String? = nil,
        isSample: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.occurredAt = occurredAt
        self.updatedAt = createdAt
        self.text = text
        self.feelingRaw = feeling?.rawValue
        self.isKept = isKept
        self.placeName = placeName
        self.isSample = isSample
        self.attachments = []
        self.recordings = []
        self.concepts = []
        self.conversations = []
        self.collections = []
        self.insights = []
        self.chapters = []
    }

    var feeling: Feeling? {
        get { feelingRaw.flatMap(Feeling.init(rawValue:)) }
        set { feelingRaw = newValue?.rawValue }
    }

    /// Derived from content rather than chosen by the person.
    var kind: EntryKind {
        let hasText = !trimmedText.isEmpty
        let hasPhotos = !attachments.isEmpty
        let hasVoice = !recordings.isEmpty
        switch (hasText, hasPhotos, hasVoice) {
        case (_, true, true), (true, true, _), (true, _, true): return .moment
        case (false, true, false): return .photo
        case (false, false, true): return .voice
        default: return .text
        }
    }

    var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var hasContent: Bool {
        !trimmedText.isEmpty || !attachments.isEmpty || !recordings.isEmpty
    }

    var sortedAttachments: [MediaAttachment] {
        attachments.sorted { $0.sortOrder < $1.sortOrder }
    }

    var sortedRecordings: [VoiceRecording] {
        recordings.sorted { $0.createdAt < $1.createdAt }
    }

    /// A short, human title derived from the content. Never stored, so edits stay in one place.
    var displayTitle: String {
        if let first = firstSentence, !first.isEmpty { return first }
        if let transcript = recordings.compactMap(\.transcript).first,
           let sentence = TextSnippets.firstSentence(of: transcript) { return sentence }
        switch kind {
        case .voice: return "A voice moment"
        case .photo: return attachments.count == 1 ? "A photo" : "\(attachments.count) photos"
        default: return "A moment"
        }
    }

    var firstSentence: String? { TextSnippets.firstSentence(of: trimmedText) }

    /// Everything searchable about the moment, for the journal search and companion retrieval.
    var searchableText: String {
        var parts = [trimmedText]
        parts.append(contentsOf: recordings.compactMap(\.transcript))
        if let placeName { parts.append(placeName) }
        parts.append(contentsOf: concepts.map(\.name))
        return parts.joined(separator: " ")
    }

    var coverAttachment: MediaAttachment? { sortedAttachments.first }

    var totalVoiceDuration: TimeInterval { recordings.reduce(0) { $0 + $1.duration } }
}

enum EntryKind: String, Codable, Sendable {
    case text, voice, photo, moment

    var label: String {
        switch self {
        case .text: return "Written"
        case .voice: return "Voice"
        case .photo: return "Photo"
        case .moment: return "Moment"
        }
    }

    var systemImage: String {
        switch self {
        case .text: return "text.alignleft"
        case .voice: return "waveform"
        case .photo: return "photo"
        case .moment: return "sparkles"
        }
    }
}
