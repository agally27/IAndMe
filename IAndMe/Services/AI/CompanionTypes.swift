import Foundation

// MARK: - Snapshots
//
// The intelligence services never touch SwiftData objects directly. They work on plain, Sendable
// snapshots. This keeps them testable, keeps model objects on the main actor, and means a future
// remote AI service receives exactly the same inputs as the local one.

struct EntrySnapshot: Identifiable, Hashable, Sendable {
    var id: UUID
    var occurredAt: Date
    var text: String
    var transcript: String?
    var feeling: Feeling?
    var placeName: String?
    var conceptNames: [String]
    var hasPhotos: Bool
    var hasVoice: Bool
    var isKept: Bool

    /// Text plus any transcript, for analysis.
    var fullText: String {
        [text, transcript ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var snippet: String { TextSnippets.snippet(of: fullText, maxLength: 90) }
}

struct ConceptSnapshot: Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var kind: ConceptKind
    var aliases: [String]
    var note: String?
    var mentionCount: Int
    var lastSeen: Date
    var anchorDate: Date?
    var recursYearly: Bool

    var allNames: [String] { [name] + aliases }
}

struct InsightSnapshot: Identifiable, Hashable, Sendable {
    var id: UUID
    var kind: InsightKind
    var title: String
    var body: String
    var relatedEntryIDs: [UUID]
}

struct MessageSnapshot: Identifiable, Hashable, Sendable {
    var id: UUID
    var role: MessageRole
    var text: String
    var createdAt: Date
}

/// Everything the companion knows when it replies. Built on the main actor from the store, then handed over.
struct CompanionContext: Sendable {
    var userName: String
    var now: Date
    var focusEntry: EntrySnapshot?
    var entries: [EntrySnapshot]        // newest first
    var concepts: [ConceptSnapshot]
    var insights: [InsightSnapshot]

    static let empty = CompanionContext(userName: "", now: .now, focusEntry: nil, entries: [], concepts: [], insights: [])

    func entries(within days: Int, from reference: Date? = nil) -> [EntrySnapshot] {
        let ref = reference ?? now
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: ref) else { return entries }
        return entries.filter { $0.occurredAt >= cutoff && $0.occurredAt <= ref }
    }

    func concept(named name: String) -> ConceptSnapshot? {
        let lowered = name.lowercased()
        return concepts.first { $0.allNames.contains { $0.lowercased() == lowered } }
    }
}

// MARK: - Replies

/// A follow-up the companion offers. Encoded into the message so it survives relaunch.
struct CompanionSuggestion: Codable, Hashable, Identifiable, Sendable {
    enum Action: Codable, Hashable, Sendable {
        /// Sends this text as the person's next message.
        case say(String)
        /// Opens a moment.
        case openEntry(UUID)
        /// Opens capture pre-filled with this text.
        case capture(String)
    }

    var id: UUID
    var title: String
    var action: Action

    init(id: UUID = UUID(), title: String, action: Action) {
        self.id = id
        self.title = title
        self.action = action
    }

    static func say(_ text: String, title: String? = nil) -> CompanionSuggestion {
        CompanionSuggestion(title: title ?? text, action: .say(text))
    }
}

struct CompanionReply: Sendable {
    var text: String
    var referencedEntryIDs: [UUID]
    var suggestions: [CompanionSuggestion]

    init(text: String, referencedEntryIDs: [UUID] = [], suggestions: [CompanionSuggestion] = []) {
        self.text = text
        self.referencedEntryIDs = referencedEntryIDs
        self.suggestions = suggestions
    }
}

/// A way into a conversation, shown on the companion's home and on Today.
struct ConversationStarter: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var detail: String?
    var openingMessage: String
    var focusEntryID: UUID?
}

/// The reflective question offered on the Today screen.
struct TodayPrompt: Hashable, Sendable {
    var eyebrow: String
    var question: String
    var focusEntryID: UUID?
}
