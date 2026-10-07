import Foundation
import SwiftData

/// A thread with the companion. May be anchored to a specific moment.
@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var isSample: Bool
    var entry: JournalEntry?

    @Relationship(deleteRule: .cascade, inverse: \ConversationMessage.conversation)
    var messages: [ConversationMessage]

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        isSample: Bool = false,
        entry: JournalEntry? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.isSample = isSample
        self.entry = entry
        self.messages = []
    }

    var sortedMessages: [ConversationMessage] { messages.sorted { $0.createdAt < $1.createdAt } }

    var lastMessage: ConversationMessage? { sortedMessages.last }

    var preview: String {
        lastMessage?.text ?? ""
    }
}

@Model
final class ConversationMessage {
    @Attribute(.unique) var id: UUID
    var roleRaw: String
    var text: String
    var createdAt: Date
    /// Moments the companion drew on for this message, shown as small links beneath it.
    var referencedEntryIDs: [UUID]
    /// Encoded follow-up suggestions offered after a companion message.
    var suggestionsData: Data?
    var conversation: Conversation?

    init(
        id: UUID = UUID(),
        role: MessageRole,
        text: String,
        createdAt: Date = .now,
        referencedEntryIDs: [UUID] = [],
        suggestions: [CompanionSuggestion] = []
    ) {
        self.id = id
        self.roleRaw = role.rawValue
        self.text = text
        self.createdAt = createdAt
        self.referencedEntryIDs = referencedEntryIDs
        self.suggestionsData = try? JSONEncoder().encode(suggestions)
    }

    var role: MessageRole {
        get { MessageRole(rawValue: roleRaw) ?? .companion }
        set { roleRaw = newValue.rawValue }
    }

    var suggestions: [CompanionSuggestion] {
        get {
            guard let suggestionsData else { return [] }
            return (try? JSONDecoder().decode([CompanionSuggestion].self, from: suggestionsData)) ?? []
        }
        set { suggestionsData = try? JSONEncoder().encode(newValue) }
    }
}

enum MessageRole: String, Codable, Sendable {
    case user
    case companion
}
