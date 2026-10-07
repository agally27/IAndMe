import Foundation
import SwiftData
import Observation

/// Drives one conversation: creates it when needed, sends messages, asks the companion to reply,
/// and keeps everything persisted.
@MainActor
@Observable
final class ConversationSession {
    private let services: AppServices
    private(set) var conversation: Conversation?
    private(set) var isThinking = false
    private(set) var errorMessage: String?
    private let start: ConversationStart?
    private var didPrepare = false

    init(services: AppServices, conversation: Conversation) {
        self.services = services
        self.conversation = conversation
        self.start = nil
    }

    init(services: AppServices, start: ConversationStart) {
        self.services = services
        self.conversation = nil
        self.start = start
    }

    var focusEntry: JournalEntry? { conversation?.entry }

    var messages: [ConversationMessage] { conversation?.sortedMessages ?? [] }

    /// Creates the conversation and its first exchange, if this is a new one.
    func prepare() async {
        guard !didPrepare else { return }
        didPrepare = true
        guard conversation == nil, let start else { return }
        let entry = start.entryID.flatMap { services.repository.entry(id: $0) }
        let title = start.title ?? entry.map { "About \(DateFormatting.dayLabel(for: $0.occurredAt).lowercased())" } ?? "A conversation"
        guard let created = try? services.repository.createConversation(title: title, about: entry) else { return }
        conversation = created

        if let opening = start.openingMessage, !opening.isEmpty, entry == nil {
            await send(opening)
            return
        }
        // When a conversation is anchored to a moment, the companion opens by reflecting on it;
        // any starter text is just the title, not something the person needs to "say".
        let context = services.companionContext(focus: entry)
        let reply = services.companion.opening(context: context)
        append(role: .companion, reply: reply)
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let conversation, !isThinking else { return }
        let userMessage = ConversationMessage(role: .user, text: trimmed)
        conversation.messages.append(userMessage)
        conversation.updatedAt = .now
        if conversation.title == "A conversation" {
            conversation.title = TextSnippets.truncate(trimmed, maxLength: 40).replacingOccurrences(of: "…", with: "")
        }
        try? services.repository.save()

        isThinking = true
        errorMessage = nil
        let history = conversation.sortedMessages.dropLast().map(CompanionContextBuilder.snapshot)
        let context = services.companionContext(focus: conversation.entry)
        do {
            let reply = try await services.companion.reply(to: trimmed, history: Array(history), context: context)
            append(role: .companion, reply: reply)
        } catch {
            errorMessage = "I couldn't think of a reply just now. Try again in a moment."
        }
        isThinking = false
    }

    private func append(role: MessageRole, reply: CompanionReply) {
        guard let conversation else { return }
        let message = ConversationMessage(role: role, text: reply.text, referencedEntryIDs: reply.referencedEntryIDs, suggestions: reply.suggestions)
        conversation.messages.append(message)
        conversation.updatedAt = .now
        try? services.repository.save()
    }

    /// Removes a conversation the person never actually took part in.
    func discardIfEmpty() {
        guard let conversation, !conversation.messages.contains(where: { $0.role == .user }) else { return }
        try? services.repository.delete(conversation)
        self.conversation = nil
    }

    func entry(for id: UUID) -> JournalEntry? {
        services.repository.entry(id: id)
    }
}
