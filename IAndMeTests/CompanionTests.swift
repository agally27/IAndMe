import Testing
import Foundation
@testable import IAndMe

@MainActor
struct CompanionContextTests {
    @Test func contextIncludesFocusEntryAndConcepts() throws {
        let services = try TestStack.make(seedSample: true)
        let entry = try #require(services.repository.allEntries().first)
        let context = services.companionContext(focus: entry)
        #expect(context.focusEntry?.id == entry.id)
        #expect(context.userName == "Sam")
        #expect(context.entries.count == services.repository.allEntries().count)
        #expect(context.concepts.contains { $0.name == "Hannah" })
        #expect(context.entries.first?.occurredAt ?? .distantPast >= context.entries.last?.occurredAt ?? .distantPast)
    }

    @Test func snapshotsExcludeForgottenConcepts() throws {
        let services = try TestStack.make(seedSample: true)
        let hannah = try #require(services.repository.allConcepts(includeForgotten: false).first { $0.name == "Hannah" })
        hannah.isForgotten = true
        try services.repository.save()
        let context = services.companionContext()
        #expect(!context.concepts.contains { $0.name == "Hannah" })
        #expect(!context.entries.contains { $0.conceptNames.contains("Hannah") })
    }
}

@MainActor
struct LocalCompanionServiceTests {
    private func sampleContext() throws -> CompanionContext {
        try TestStack.make(seedSample: true).companionContext()
    }

    @Test func difficultMessageIsAcknowledgedAndGrounded() async throws {
        let service = LocalCompanionService(replyDelay: .zero)
        let context = try sampleContext()
        let reply = try await service.reply(to: "I've had a terrible week at work.", history: [], context: context)
        #expect(reply.text.contains("?"))
        #expect(!reply.referencedEntryIDs.isEmpty)
        #expect(reply.suggestions.contains { if case .capture = $0.action { return true } else { return false } })
    }

    @Test func recallWithNoMatchNeverFabricates() async throws {
        let service = LocalCompanionService(replyDelay: .zero)
        let context = try sampleContext()
        let reply = try await service.reply(to: "Remember when I went skydiving in Peru?", history: [], context: context)
        #expect(reply.text.contains("can't find"))
        #expect(reply.referencedEntryIDs.isEmpty)
    }

    @Test func recallWithMatchQuotesRealMoment() async throws {
        let service = LocalCompanionService(replyDelay: .zero)
        let context = try sampleContext()
        let reply = try await service.reply(to: "When did I write about the bread?", history: [], context: context)
        #expect(!reply.referencedEntryIDs.isEmpty)
        let referenced = context.entries.filter { reply.referencedEntryIDs.contains($0.id) }
        #expect(referenced.allSatisfy { $0.fullText.lowercased().contains("bread") || $0.conceptNames.contains("Cooking") })
    }

    @Test func captureRequestOffersCapture() async throws {
        let service = LocalCompanionService(replyDelay: .zero)
        let reply = try await service.reply(to: "Write this down: Hannah is coming for Dad's birthday.", history: [], context: try sampleContext())
        let capture = reply.suggestions.compactMap { suggestion -> String? in
            if case .capture(let text) = suggestion.action { return text }
            return nil
        }.first
        #expect(capture?.contains("Hannah is coming") == true)
    }

    @Test func patternQuestionAboutGoodMomentsUsesConcepts() async throws {
        let service = LocalCompanionService(replyDelay: .zero)
        let reply = try await service.reply(to: "What makes me feel good?", history: [], context: try sampleContext())
        #expect(reply.text.contains("good or bright"))
        #expect(!reply.referencedEntryIDs.isEmpty)
    }

    @Test func personMentionDrawsOnTheirMoments() async throws {
        let service = LocalCompanionService(replyDelay: .zero)
        let reply = try await service.reply(to: "I've been thinking about Hannah.", history: [], context: try sampleContext())
        #expect(reply.text.contains("Hannah"))
        #expect(reply.text.contains("sister") || reply.text.contains("moments"))
        #expect(!reply.referencedEntryIDs.isEmpty)
    }

    @Test func crisisLanguagePointsToPeopleNotDiagnosis() async throws {
        let service = LocalCompanionService(replyDelay: .zero)
        let reply = try await service.reply(to: "I don't want to be here anymore", history: [], context: try sampleContext())
        #expect(reply.text.contains("someone you trust"))
        #expect(!reply.text.lowercased().contains("depress"))
    }

    @Test func emptyJournalPatternQuestionIsHonest() async throws {
        let service = LocalCompanionService(replyDelay: .zero)
        let context = try TestStack.make().companionContext()
        let reply = try await service.reply(to: "What has been difficult lately?", history: [], context: context)
        #expect(reply.text.contains("isn't enough") || reply.text.contains("only know"))
    }

    @Test func openingAboutEntryQuotesIt() throws {
        let service = LocalCompanionService(replyDelay: .zero)
        let services = try TestStack.make(seedSample: true)
        let entry = try #require(services.repository.allEntries().first { !$0.trimmedText.isEmpty })
        let reply = service.opening(context: services.companionContext(focus: entry))
        #expect(reply.text.contains("You wrote"))
        #expect(reply.text.contains("?"))
        #expect(!reply.suggestions.isEmpty)
    }

    @Test func startersAndPromptAreGrounded() throws {
        let service = LocalCompanionService(replyDelay: .zero)
        let context = try sampleContext()
        let starters = service.starters(context: context)
        #expect(!starters.isEmpty)
        #expect(starters.count <= 4)
        let prompt = service.todayPrompt(context: context)
        #expect(prompt.question.hasSuffix("?"))
    }

    @Test func followUpQuestionsVaryWithDepth() async throws {
        let service = LocalCompanionService(replyDelay: .zero)
        let context = try sampleContext()
        let first = try await service.reply(to: "Everything feels heavy.", history: [], context: context)
        let history = [MessageSnapshot(id: UUID(), role: .user, text: "Everything feels heavy.", createdAt: .now), MessageSnapshot(id: UUID(), role: .companion, text: first.text, createdAt: .now)]
        let second = try await service.reply(to: "It's mostly the job, I think.", history: history, context: context)
        #expect(first.text != second.text)
    }
}

@MainActor
struct ConversationSessionTests {
    @Test func sessionCreatesConversationAndPersistsReply() async throws {
        let services = try TestStack.make(seedSample: true)
        let session = ConversationSession(services: services, start: ConversationStart(openingMessage: "I've had a terrible week."))
        await session.prepare()
        let conversation = try #require(session.conversation)
        #expect(conversation.messages.count == 2)
        #expect(conversation.sortedMessages.first?.role == .user)
        #expect(conversation.sortedMessages.last?.role == .companion)
        #expect(services.repository.conversation(id: conversation.id) != nil)
    }

    @Test func emptyConversationIsDiscarded() async throws {
        let services = try TestStack.make(seedSample: true)
        let entry = try #require(services.repository.allEntries().first)
        let session = ConversationSession(services: services, start: ConversationStart(entryID: entry.id))
        await session.prepare()
        let id = try #require(session.conversation?.id)
        session.discardIfEmpty()
        #expect(services.repository.conversation(id: id) == nil)
    }
}

@MainActor
struct CompanionIntentTests {
    @Test func neutralStatementsAreNotTreatedAsDifficult() {
        let service = LocalCompanionService(replyDelay: .zero)
        let context = CompanionContext.empty
        #expect(service.analyse("I'd like to talk about what I captured this morning.", context: context).intent == .statement)
        #expect(service.analyse("Why did that walk help?", context: context).intent == .question)
        #expect(service.analyse("I've had a terrible week.", context: context).intent == .difficult)
        #expect(service.analyse("Today was lovely, honestly.", context: context).intent == .positive)
        #expect(service.analyse("hello", context: context).intent == .greeting)
        #expect(service.analyse("thanks, that helped", context: context).intent == .thanks)
    }

    @Test func questionAboutFocusEntryIsGroundedInIt() async throws {
        let service = LocalCompanionService(replyDelay: .zero)
        let services = try TestStack.make(seedSample: true)
        let entry = try #require(services.repository.allEntries().first { $0.text.hasPrefix("Walked the harbour after work") })
        let context = services.companionContext(focus: entry)
        let reply = try await service.reply(to: "Why did that walk help?", history: [], context: context)
        #expect(reply.text.contains("In the moment itself you wrote"))
        #expect(!reply.text.contains("weighing on you"))
    }
}
