import Foundation

/// The reflective companion. Every implementation receives the same snapshot-based context, so the
/// local engine here can be swapped for a remote model without touching the interface.
protocol AICompanionService: AnyObject {
    /// Replies to the person's message within a conversation.
    func reply(to message: String, history: [MessageSnapshot], context: CompanionContext) async throws -> CompanionReply

    /// The companion's first words when a conversation starts, optionally about a specific moment.
    func opening(context: CompanionContext) -> CompanionReply

    /// Ways into a conversation, grounded in what is actually in the journal.
    func starters(context: CompanionContext) -> [ConversationStarter]

    /// The reflective question on the Today screen.
    func todayPrompt(context: CompanionContext) -> TodayPrompt
}
