import Foundation

/// A local, rule-driven companion. It does not pretend to be a language model: it classifies what the
/// person said, retrieves the moments that are genuinely relevant, and composes a reply from the
/// person's own words. Everything it says about the journal is traceable to a real moment.
///
/// It never fabricates memories: if nothing relevant exists, it says so.
final class LocalCompanionService: AICompanionService {
    /// Simulated thinking time, so the reply feels considered rather than instant. Zero in tests.
    var replyDelay: Duration = .milliseconds(900)

    init(replyDelay: Duration = .milliseconds(900)) {
        self.replyDelay = replyDelay
    }

    // MARK: - Analysis

    enum Intent: Equatable {
        case crisis
        case captureRequest
        case patternQuestion
        case recall
        case aboutConcept
        case difficult
        case tired
        case positive
        case greeting
        case thanks
        case goodbye
        case question
        case statement
    }

    struct Analysis {
        var text: String
        var lowered: String
        var sentiment: Double
        var intent: Intent
        var concepts: [ConceptSnapshot]
        var keywords: [String]
        var isQuestion: Bool
    }

    func analyse(_ message: String, context: CompanionContext) -> Analysis {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = text.lowercased()
        let sentiment = TextAnalyzer.sentiment(of: text)
        // Strip the phrases that signal intent so they don't count as topics when retrieving moments.
        var topical = lowered
        for phrase in Lexicon.recallPhrases + Lexicon.patternQuestionPhrases + Lexicon.captureRequestPhrases where topical.contains(phrase) {
            topical = topical.replacingOccurrences(of: phrase, with: " ")
        }
        let keywords = TextAnalyzer.contentWords(in: topical)
        let words = Set(TextAnalyzer.contentWords(in: text) + TextSnippets.words(in: text))
        let mentioned = context.concepts.filter { concept in
            concept.allNames.contains { containsWholeWord(lowered, $0.lowercased()) }
        }
        let isQuestion = text.hasSuffix("?") || lowered.hasPrefix("what") || lowered.hasPrefix("why") || lowered.hasPrefix("how") || lowered.hasPrefix("who") || lowered.hasPrefix("when") || lowered.hasPrefix("where") || lowered.hasPrefix("should") || lowered.hasPrefix("do i") || lowered.hasPrefix("am i")

        let intent: Intent
        if Lexicon.crisisPhrases.contains(where: { lowered.contains($0) }) {
            intent = .crisis
        } else if Lexicon.captureRequestPhrases.contains(where: { lowered.contains($0) }) {
            intent = .captureRequest
        } else if Lexicon.patternQuestionPhrases.contains(where: { lowered.contains($0) }) {
            intent = .patternQuestion
        } else if Lexicon.recallPhrases.contains(where: { lowered.contains($0) }) {
            intent = .recall
        } else if words.count <= 3, Lexicon.greetingPhrases.contains(where: { lowered == $0 || lowered.hasPrefix($0 + " ") || lowered.hasPrefix($0 + ",") }) {
            intent = .greeting
        } else if words.count <= 4, Lexicon.goodbyePhrases.contains(where: { lowered.contains($0) }) {
            intent = .goodbye
        } else if words.count <= 5, Lexicon.thanksPhrases.contains(where: { lowered.contains($0) }) {
            intent = .thanks
        } else if !words.isDisjoint(with: Lexicon.tiredWords), sentiment <= 0.1 {
            intent = .tired
        } else if isQuestion, words.isDisjoint(with: Lexicon.difficultWords) {
            // Questions are questions, unless they carry clearly difficult language.
            intent = .question
        } else if !words.isDisjoint(with: Lexicon.difficultWords) || sentiment < -0.6 {
            intent = .difficult
        } else if (!words.isDisjoint(with: Lexicon.positiveWords) && sentiment > 0) || sentiment > 0.6 {
            intent = .positive
        } else if !mentioned.isEmpty {
            intent = .aboutConcept
        } else {
            intent = .statement
        }

        return Analysis(text: text, lowered: lowered, sentiment: sentiment, intent: intent, concepts: mentioned, keywords: keywords, isQuestion: isQuestion)
    }

    // MARK: - Reply

    func reply(to message: String, history: [MessageSnapshot], context: CompanionContext) async throws -> CompanionReply {
        if replyDelay > .zero {
            try await Task.sleep(for: replyDelay)
        }
        return compose(message: message, history: history, context: context)
    }

    func compose(message: String, history: [MessageSnapshot], context: CompanionContext) -> CompanionReply {
        let analysis = analyse(message, context: context)
        let turn = history.filter { $0.role == .user }.count
        let seed = stableHash(message) &+ UInt64(turn)
        let name = context.userName

        switch analysis.intent {
        case .crisis:
            return crisisReply(name: name)
        case .captureRequest:
            return captureReply(analysis: analysis, context: context)
        case .patternQuestion:
            return patternReply(analysis: analysis, context: context, seed: seed)
        case .recall:
            return recallReply(analysis: analysis, context: context)
        case .greeting:
            return greetingReply(context: context, seed: seed)
        case .thanks:
            return CompanionReply(text: pick(["You're welcome. I'm here whenever you want to think something through.", "Any time. This is your space — I'm just here to help you look at it."], seed: seed))
        case .goodbye:
            let farewell = name.isEmpty ? "Take care." : "Take care, \(name)."
            return CompanionReply(text: pick([farewell + " Whatever you captured today will be here when you come back.", farewell + " Your moments are kept."], seed: seed))
        case .tired:
            return tiredReply(analysis: analysis, context: context, turn: turn, seed: seed)
        case .difficult:
            return difficultReply(analysis: analysis, context: context, turn: turn, seed: seed)
        case .positive:
            return positiveReply(analysis: analysis, context: context, turn: turn, seed: seed)
        case .aboutConcept:
            return conceptReply(analysis: analysis, context: context, seed: seed)
        case .question:
            return questionReply(analysis: analysis, context: context, seed: seed)
        case .statement:
            return statementReply(analysis: analysis, context: context, turn: turn, seed: seed)
        }
    }

    // MARK: - Opening, starters, prompts

    func opening(context: CompanionContext) -> CompanionReply {
        if let entry = context.focusEntry {
            var parts: [String] = []
            var when = "This is from \(DateFormatting.prosePhrase(for: entry.occurredAt, relativeTo: context.now))"
            if let place = entry.placeName { when += ", at \(place)" }
            parts.append(when + ".")
            if !entry.fullText.isEmpty {
                parts.append("You wrote: “\(TextSnippets.snippet(of: entry.fullText, maxLength: 140))”")
            } else if entry.hasPhotos {
                parts.append("There's no writing with it, just the photo" + (entry.hasVoice ? " and your voice." : "."))
            } else if entry.hasVoice {
                parts.append("It's a voice moment. You might want to transcribe it so we can look at the words together.")
            }
            if let feeling = entry.feeling {
                parts.append("You marked it as \(feeling.label.lowercased()).")
            }
            let related = relatedEntries(to: entry, in: context, limit: 1)
            if let other = related.first {
                parts.append("Around the same time you also wrote about \(sharedConceptPhrase(entry, other, context: context) ?? "something similar") — \(DateFormatting.prosePhrase(for: other.occurredAt, relativeTo: context.now)).")
            }
            parts.append("What stands out to you about it now?")
            return CompanionReply(
                text: parts.joined(separator: " "),
                referencedEntryIDs: related.map(\.id),
                suggestions: [
                    .say("What was I feeling then?"),
                    .say("How does this connect to other moments?"),
                    .say("Why does this one matter?")
                ]
            )
        }
        let name = context.userName
        let hello = name.isEmpty ? "Hello." : "Hello, \(name)."
        if let latest = context.entries.first, DateFormatting.daysBetween(latest.occurredAt, context.now) <= 1 {
            return CompanionReply(
                text: "\(hello) \(DateFormatting.prosePhrase(for: latest.occurredAt, relativeTo: context.now).capitalisedFirst) you captured “\(TextSnippets.snippet(of: latest.fullText.isEmpty ? latest.hasVoice ? "a voice moment" : "a photo" : latest.fullText, maxLength: 70))”. What's on your mind?",
                referencedEntryIDs: [latest.id],
                suggestions: [.say("Let's talk about that"), .say("Something else is on my mind")]
            )
        }
        return CompanionReply(text: "\(hello) This is a space to think out loud. Nothing you say here leaves your phone. What's on your mind?")
    }

    func starters(context: CompanionContext) -> [ConversationStarter] {
        var starters: [ConversationStarter] = []
        let recent = context.entries(within: 7)

        if let today = context.entries.first, Calendar.current.isDate(today.occurredAt, inSameDayAs: context.now) {
            starters.append(ConversationStarter(
                id: "today",
                title: "Talk about \(DateFormatting.prosePhrase(for: today.occurredAt, relativeTo: context.now))",
                detail: TextSnippets.snippet(of: today.fullText.isEmpty ? "A moment without words" : today.fullText, maxLength: 60),
                openingMessage: "I'd like to talk about what I captured \(DateFormatting.prosePhrase(for: today.occurredAt, relativeTo: context.now)).",
                focusEntryID: today.id
            ))
        }

        let difficultRecent = recent.filter { $0.feeling?.isDifficult ?? false }
        if difficultRecent.count >= 2 {
            starters.append(ConversationStarter(
                id: "heavy-week",
                title: "The last few days have felt heavier",
                detail: "\(difficultRecent.count) moments this week felt heavy or low.",
                openingMessage: "The last few days have felt heavy. Can we talk it through?",
                focusEntryID: nil
            ))
        }

        if let person = topConcept(kind: .person, in: recent, context: context) {
            starters.append(ConversationStarter(
                id: "person-\(person.id)",
                title: "\(person.name) has been on your mind",
                detail: "Mentioned \(context.entries(within: 30).filter { $0.conceptNames.contains(person.name) }.count) times this month.",
                openingMessage: "I've been thinking about \(person.name).",
                focusEntryID: nil
            ))
        }

        if let lifted = context.insights.first(where: { $0.kind == .lifted }) {
            starters.append(ConversationStarter(
                id: "lifted",
                title: "What's been lifting me",
                detail: lifted.title,
                openingMessage: "What has been lifting me lately?",
                focusEntryID: nil
            ))
        }

        if let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: context.now),
           let then = context.entries.first(where: { abs($0.occurredAt.timeIntervalSince(monthAgo)) < 3 * 86_400 }) {
            starters.append(ConversationStarter(
                id: "month-ago",
                title: "This time last month",
                detail: TextSnippets.snippet(of: then.fullText, maxLength: 60),
                openingMessage: "I'd like to look back at this time last month.",
                focusEntryID: then.id
            ))
        }

        if starters.isEmpty || context.entries.isEmpty {
            starters.append(ConversationStarter(
                id: "open",
                title: "What's on my mind",
                detail: "Start anywhere.",
                openingMessage: "",
                focusEntryID: nil
            ))
        }
        return Array(starters.prefix(4))
    }

    func todayPrompt(context: CompanionContext) -> TodayPrompt {
        let weekday = Calendar.current.component(.weekday, from: context.now)
        let hour = Calendar.current.component(.hour, from: context.now)
        let yesterday = context.entries.first { DateFormatting.daysBetween($0.occurredAt, context.now) == 1 }

        if let yesterday, yesterday.feeling?.isDifficult == true {
            return TodayPrompt(eyebrow: "After yesterday", question: "Yesterday felt \(yesterday.feeling!.label.lowercased()). How are things this \(hour < 12 ? "morning" : hour < 18 ? "afternoon" : "evening")?", focusEntryID: yesterday.id)
        }
        if let yesterday, yesterday.feeling?.isUplifting == true {
            return TodayPrompt(eyebrow: "Carrying it forward", question: "Yesterday felt \(yesterday.feeling!.label.lowercased()). What from it is worth keeping?", focusEntryID: yesterday.id)
        }
        if let date = context.concepts.first(where: { $0.kind == .importantDate && daysUntil($0, now: context.now).map { $0 >= 0 && $0 <= 7 } == true }),
           let days = daysUntil(date, now: context.now) {
            let when = days == 0 ? "today" : days == 1 ? "tomorrow" : "in \(days) days"
            return TodayPrompt(eyebrow: "Coming up", question: "\(date.name) is \(when). Is there anything you want to remember about it?", focusEntryID: nil)
        }
        if context.entries.isEmpty {
            return TodayPrompt(eyebrow: "A first moment", question: "What's one small thing from today you'd want to remember in a year?", focusEntryID: nil)
        }
        let general: [String]
        switch weekday {
        case 2: general = ["What would make this week feel good, honestly?", "What's one thing you're carrying into the week?"]
        case 6, 7: general = ["What's one moment from this week worth keeping?", "Who did you feel closest to this week?"]
        case 1: general = ["What did this week teach you, if anything?", "What are you looking forward to, even slightly?"]
        default:
            if hour >= 20 {
                general = ["What did today look like, honestly?", "What's one thing from today you'd keep?"]
            } else {
                general = ["What's been quietly on your mind?", "Who have you thought about today?", "What's one ordinary thing worth noticing today?"]
            }
        }
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: context.now) ?? 0
        return TodayPrompt(eyebrow: "A question for today", question: general[dayIndex % general.count], focusEntryID: nil)
    }

    // MARK: - Intent replies

    private func crisisReply(name: String) -> CompanionReply {
        let address = name.isEmpty ? "" : "\(name), "
        return CompanionReply(
            text: "\(address.capitalisedFirst)it sounds like you're carrying something really heavy right now, and I'm glad you said it somewhere. I'm a journal companion, not a person who can be with you — please reach out to someone you trust, or to a local support line, so you're not holding this alone. If it would help, we can write down what's happening, in your own words, and keep it here.",
            suggestions: [.say("I'd like to write it down", title: "Write it down"), .say("I'm okay, I just needed to say it")]
        )
    }

    private func captureReply(analysis: Analysis, context: CompanionContext) -> CompanionReply {
        var cleaned = analysis.text
        for phrase in Lexicon.captureRequestPhrases {
            if let range = cleaned.range(of: phrase, options: .caseInsensitive) {
                cleaned.removeSubrange(range)
            }
        }
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: " :,.-")).capitalisedFirst
        if cleaned.count < 4 { cleaned = "" }
        return CompanionReply(
            text: cleaned.isEmpty
                ? "Of course. Tell me what you'd like to keep, or open a new moment and write it there."
                : "Of course. I've started a moment with this — add anything you'd like before keeping it.",
            suggestions: [CompanionSuggestion(title: "Keep as a moment", action: .capture(cleaned))]
        )
    }

    private func greetingReply(context: CompanionContext, seed: UInt64) -> CompanionReply {
        let name = context.userName
        let hello = pick([name.isEmpty ? "Hello." : "Hello, \(name).", name.isEmpty ? "Hi." : "Hi, \(name)."], seed: seed)
        if let latest = context.entries.first, DateFormatting.daysBetween(latest.occurredAt, context.now) <= 2 {
            return CompanionReply(
                text: "\(hello) \(DateFormatting.prosePhrase(for: latest.occurredAt, relativeTo: context.now).capitalisedFirst) you wrote about \(TextSnippets.snippet(of: latest.fullText.isEmpty ? "a moment" : latest.fullText, maxLength: 60).lowercasedFirst) Is that still with you, or is it something else today?",
                referencedEntryIDs: [latest.id],
                suggestions: [.say("Still that"), .say("Something else")]
            )
        }
        return CompanionReply(text: "\(hello) What's on your mind?")
    }

    private func tiredReply(analysis: Analysis, context: CompanionContext, turn: Int, seed: UInt64) -> CompanionReply {
        let sleepEntries = context.entries(within: 14).filter { $0.conceptNames.contains("Sleep") }
        var text = pick(["That kind of tired gets into everything.", "Tired makes everything else heavier."], seed: seed)
        var refs: [UUID] = []
        if sleepEntries.count >= 2 {
            text += " Sleep has come up \(sleepEntries.count) times in the last two weeks, so this isn't a one-off."
            refs = Array(sleepEntries.prefix(2).map(\.id))
        } else if let last = sleepEntries.first {
            text += " You mentioned sleep \(DateFormatting.prosePhrase(for: last.occurredAt, relativeTo: context.now)) too."
            refs = [last.id]
        }
        text += " " + pick(["Is it the kind of tired that rest fixes, or the other kind?", "What's been using up the energy, do you think?"], seed: seed &+ 1)
        return CompanionReply(text: text, referencedEntryIDs: refs, suggestions: [.say("The other kind"), .say("I just need sleep"), CompanionSuggestion(title: "Keep this as a moment", action: .capture(analysis.text))])
    }

    private func difficultReply(analysis: Analysis, context: CompanionContext, turn: Int, seed: UInt64) -> CompanionReply {
        var parts: [String] = []
        var refs: [UUID] = []

        if turn == 0 {
            parts.append(pick([
                "That sounds like a lot to carry.",
                "It sounds like this has been weighing on you.",
                "I'm sorry it's been like this."
            ], seed: seed))
        } else {
            parts.append(pick(["Thank you for saying that.", "That makes sense.", "I hear you."], seed: seed))
        }

        // Ground in the journal, only when something genuinely overlaps.
        let related = retrieve(for: analysis, context: context, preferDifficult: true, limit: 2, requireMatch: true)
        if let first = related.first {
            if analysis.concepts.isEmpty {
                parts.append("You wrote about something similar \(DateFormatting.prosePhrase(for: first.occurredAt, relativeTo: context.now)): “\(first.snippet)”")
            } else {
                parts.append("\(analysis.concepts[0].name) came up \(DateFormatting.prosePhrase(for: first.occurredAt, relativeTo: context.now)) as well: “\(first.snippet)”")
            }
            refs.append(first.id)
        } else if turn == 0, let streak = difficultStreak(context: context), streak >= 2 {
            parts.append("It's not the first heavy day this week, either — \(streak) of your recent moments felt that way.")
        }

        // A gentle hint from a relief insight, offered without prescribing.
        if turn <= 1, let relief = context.insights.first(where: { $0.kind == .noticed && $0.title.contains("after harder days") }) {
            let thing = relief.title.replacingOccurrences(of: " after harder days", with: "")
            parts.append("In the past, \(thing.lowercased()) has tended to follow days like this — you've written about it more than once. No pressure; just something I've noticed.")
        }

        let questions = [
            "Do you want to explore what's been making it difficult, or would it help to just get it out of your head first?",
            "What part of it feels heaviest right now?",
            "Has anything, even something small, made it a little lighter?",
            "What would you want to remember about how you got through this?"
        ]
        parts.append(questions[min(turn, questions.count - 1)])

        var suggestions: [CompanionSuggestion] = []
        if turn == 0 {
            suggestions = [.say("I just need to get it out"), .say("Let's explore what's been difficult")]
        } else {
            suggestions = [.say("The heaviest part is…", title: "The heaviest part"), .say("Something small did help")]
        }
        suggestions.append(CompanionSuggestion(title: "Keep this as a moment", action: .capture(analysis.text)))
        return CompanionReply(text: parts.joined(separator: " "), referencedEntryIDs: refs, suggestions: suggestions)
    }

    private func positiveReply(analysis: Analysis, context: CompanionContext, turn: Int, seed: UInt64) -> CompanionReply {
        var parts: [String] = [pick(["That's lovely to hear.", "I'm glad.", "That sounds like a good one."], seed: seed)]
        var refs: [UUID] = []
        let related = retrieve(for: analysis, context: context, preferDifficult: false, limit: 1, requireMatch: true)
        if let first = related.first, first.feeling?.isUplifting == true || TextAnalyzer.sentiment(of: first.fullText) > 0.2 {
            parts.append("It reminds me of \(DateFormatting.prosePhrase(for: first.occurredAt, relativeTo: context.now)), when you wrote: “\(first.snippet)”")
            refs.append(first.id)
        }
        parts.append(pick(["What made it feel good, do you think?", "Is this one you'd want to keep?", "What would you want to remember about it?"], seed: seed &+ UInt64(turn)))
        return CompanionReply(text: parts.joined(separator: " "), referencedEntryIDs: refs, suggestions: [
            CompanionSuggestion(title: "Keep this as a moment", action: .capture(analysis.text)),
            .say("What made it good")
        ])
    }

    private func conceptReply(analysis: Analysis, context: CompanionContext, seed: UInt64) -> CompanionReply {
        guard let concept = analysis.concepts.first else { return statementReply(analysis: analysis, context: context, turn: 0, seed: seed) }
        let mentioning = context.entries.filter { $0.conceptNames.contains(concept.name) }
        var parts: [String] = []
        var refs: [UUID] = []
        switch concept.kind {
        case .person:
            if mentioning.isEmpty {
                parts.append("I don't have any moments about \(concept.name) yet — only what you tell me here.")
            } else {
                parts.append("\(concept.name) comes up in \(mentioning.count) of your moments, most recently \(DateFormatting.prosePhrase(for: mentioning[0].occurredAt, relativeTo: context.now)).")
                if let note = concept.note { parts.append(note.hasSuffix(".") ? note : note + ".") }
                parts.append("Then you wrote: “\(mentioning[0].snippet)”")
                refs.append(mentioning[0].id)
            }
            parts.append("What's on your mind about them?")
        case .place:
            if mentioning.isEmpty {
                parts.append("You haven't captured anything at \(concept.name) yet.")
            } else {
                let lifted = mentioning.filter { $0.feeling?.isUplifting ?? false }.count
                parts.append("You've written about \(concept.name) \(mentioning.count) time\(mentioning.count == 1 ? "" : "s")" + (lifted >= 2 ? ", and most of those moments felt good." : "."))
                parts.append("Most recently, \(DateFormatting.prosePhrase(for: mentioning[0].occurredAt, relativeTo: context.now)): “\(mentioning[0].snippet)”")
                refs.append(mentioning[0].id)
            }
            parts.append("What does that place hold for you?")
        case .theme, .importantDate:
            if mentioning.isEmpty {
                parts.append("I don't have much about \(concept.name.lowercased()) in your moments yet.")
            } else {
                let difficultShare = Double(mentioning.filter { $0.feeling?.isDifficult ?? false }.count) / Double(mentioning.count)
                parts.append("\(concept.name) has appeared in \(mentioning.count) of your moments" + (difficultShare >= 0.5 ? ", and it's often been a heavy subject." : "."))
                parts.append("\(DateFormatting.prosePhrase(for: mentioning[0].occurredAt, relativeTo: context.now).capitalisedFirst) you wrote: “\(mentioning[0].snippet)”")
                refs.append(mentioning[0].id)
            }
            parts.append("What's different about it today?")
        }
        var suggestions: [CompanionSuggestion] = []
        if let first = mentioning.first { suggestions.append(CompanionSuggestion(title: "Open that moment", action: .openEntry(first.id))) }
        suggestions.append(.say("How has it changed over time?"))
        return CompanionReply(text: parts.joined(separator: " "), referencedEntryIDs: refs, suggestions: suggestions)
    }

    private func patternReply(analysis: Analysis, context: CompanionContext, seed: UInt64) -> CompanionReply {
        let window = context.entries(within: 90)
        guard window.count >= 3 else {
            return CompanionReply(text: "I only know what you've captured here, and there isn't enough yet to see a pattern honestly. A few more moments and I'll be able to say more.", suggestions: [CompanionSuggestion(title: "Capture a moment", action: .capture(""))])
        }
        let lowered = analysis.lowered
        let weeks = max(1, DateFormatting.daysBetween(window.last!.occurredAt, context.now) / 7)

        func conceptCounts(in entries: [EntrySnapshot], kinds: [ConceptKind]) -> [(String, Int)] {
            var counts: [String: Int] = [:]
            let allowed = Set(context.concepts.filter { kinds.contains($0.kind) }.map(\.name))
            for entry in entries { for name in entry.conceptNames where allowed.contains(name) { counts[name, default: 0] += 1 } }
            return counts.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
        }

        if lowered.contains("good") || lowered.contains("lift") || lowered.contains("happy") || lowered.contains("help") {
            let lifted = window.filter { $0.feeling?.isUplifting ?? false }
            guard !lifted.isEmpty else {
                return CompanionReply(text: "Looking across the last \(weeks) weeks, you haven't marked many moments as good or bright, so I'd be guessing. It might be worth noticing the next one when it comes.")
            }
            let top = conceptCounts(in: lifted, kinds: [.person, .place, .theme]).prefix(3).map(\.0)
            var text = "Looking across the last \(weeks) weeks, the moments you marked good or bright most often involve \(joinNames(top))."
            if let example = lifted.first {
                text += " For example, \(DateFormatting.prosePhrase(for: example.occurredAt, relativeTo: context.now)): “\(example.snippet)”"
            }
            text += " Does that match how it feels from the inside?"
            return CompanionReply(text: text, referencedEntryIDs: lifted.prefix(2).map(\.id), suggestions: [.say("Yes, that sounds right"), .say("Not quite")])
        }

        if lowered.contains("difficult") || lowered.contains("hard") || lowered.contains("heavy") || lowered.contains("struggl") {
            let hard = window.filter { $0.feeling?.isDifficult ?? false }
            guard !hard.isEmpty else {
                return CompanionReply(text: "In the last \(weeks) weeks you haven't marked many moments as heavy or low. Either it's been a steadier time, or those moments didn't get written down.")
            }
            let top = conceptCounts(in: hard, kinds: [.theme, .person, .place]).prefix(3).map(\.0)
            var text = "The moments that felt heavy or low in the last \(weeks) weeks — \(hard.count) of them — most often involve \(joinNames(top))."
            if let example = hard.first {
                text += " \(DateFormatting.prosePhrase(for: example.occurredAt, relativeTo: context.now).capitalisedFirst) you wrote: “\(example.snippet)”"
            }
            text += " Would it help to look at one of them together?"
            return CompanionReply(text: text, referencedEntryIDs: hard.prefix(2).map(\.id), suggestions: hard.prefix(1).map { CompanionSuggestion(title: "Open the most recent", action: .openEntry($0.id)) } + [.say("What usually helps afterwards?")])
        }

        if lowered.contains("who") || lowered.contains("people") || lowered.contains("matters") {
            let top = conceptCounts(in: window, kinds: [.person]).prefix(4)
            guard !top.isEmpty else { return CompanionReply(text: "I haven't noticed any people in your moments yet — or I haven't recognised their names. You can tell me who matters, and I'll remember.") }
            let text = "Going by your moments, \(joinNames(top.map(\.0))) are the people who appear most. \(top.first!.0) most of all — \(top.first!.1) times in the last \(weeks) weeks. Does that reflect who matters, or just who you write about?"
            return CompanionReply(text: text, suggestions: [.say("That's about right"), .say("Someone's missing")])
        }

        if lowered.contains("where") || lowered.contains("place") {
            let top = conceptCounts(in: window, kinds: [.place]).prefix(4)
            guard !top.isEmpty else { return CompanionReply(text: "I haven't noticed particular places in your moments yet. Adding where you were, even loosely, helps me see them.") }
            return CompanionReply(text: "\(joinNames(top.map(\.0))) are the places that come up most. \(top.first!.0) appears \(top.first!.1) times. Which of those feels most like yours?")
        }

        if lowered.contains("changed") || lowered.contains("how am i") || lowered.contains("how have i been") || lowered.contains("doing") {
            let drafter = LocalLifeStoryService()
            let trend = drafter.feelingTrend(window.reversed())
            let topThemes = conceptCounts(in: window, kinds: [.theme]).prefix(2).map(\.0)
            var text: String
            switch trend {
            case .improving: text = "Comparing recent weeks with the ones before, more of your moments are marked good or bright. Something has shifted upward."
            case .worsening: text = "Comparing recent weeks with the ones before, more of your moments are marked heavy or low. It's been getting harder, going by what you've written."
            case .steady: text = "Looking across the last \(weeks) weeks, things read as fairly steady — not dramatic either way."
            case .unknown: text = "There isn't quite enough marked feeling in your moments to say how things have moved. The words are there, though."
            }
            if !topThemes.isEmpty { text += " \(joinNames(topThemes)) \(topThemes.count == 1 ? "has" : "have") been the thread running through it." }
            text += " Does that match how it feels from the inside?"
            return CompanionReply(text: text, suggestions: [.say("Yes"), .say("It feels different from that")])
        }

        if lowered.contains("learn") {
            let kept = window.filter(\.isKept)
            if let example = kept.first {
                return CompanionReply(text: "I can't tell you what you've learned — but the moments you chose to keep might. \(DateFormatting.prosePhrase(for: example.occurredAt, relativeTo: context.now).capitalisedFirst) you kept this: “\(example.snippet)” What did that one teach you?", referencedEntryIDs: [example.id], suggestions: [CompanionSuggestion(title: "Open that moment", action: .openEntry(example.id))])
            }
            return CompanionReply(text: "I can't tell you what you've learned, but you can mark moments as worth remembering, and over time those tend to hold the lessons.")
        }

        // General: recurring thoughts
        let top = conceptCounts(in: window, kinds: [.theme]).prefix(3)
        guard !top.isEmpty else {
            return CompanionReply(text: "I haven't spotted a clear recurring thread yet. The more you capture, the more I can see — and I'd rather say nothing than make something up.")
        }
        var text = "\(joinNames(top.map(\.0))) \(top.count == 1 ? "keeps" : "keep") appearing in your moments — \(top.first!.0) in \(top.first!.1) of them over the last \(weeks) weeks."
        if let recent = window.first(where: { $0.conceptNames.contains(top.first!.0) }) {
            text += " Most recently \(DateFormatting.prosePhrase(for: recent.occurredAt, relativeTo: context.now)): “\(recent.snippet)”"
            return CompanionReply(text: text + " Is that what you expected?", referencedEntryIDs: [recent.id], suggestions: [.say("Yes"), .say("I hadn't noticed")])
        }
        return CompanionReply(text: text + " Is that what you expected?")
    }

    private func recallReply(analysis: Analysis, context: CompanionContext) -> CompanionReply {
        let hits = retrieve(for: analysis, context: context, preferDifficult: nil, limit: 3, requireMatch: true)
        guard !hits.isEmpty else {
            return CompanionReply(
                text: "I can't find anything about that in your journal yet — I only know what you've captured here. Would you like to write it down now so it's kept?",
                suggestions: [CompanionSuggestion(title: "Capture it now", action: .capture(""))]
            )
        }
        var parts = ["Here's what I can find."]
        for hit in hits {
            parts.append("\(DateFormatting.prosePhrase(for: hit.occurredAt, relativeTo: context.now).capitalisedFirst) you wrote: “\(hit.snippet)”")
        }
        parts.append(hits.count == 1 ? "Is that the one?" : "Is one of those what you meant?")
        return CompanionReply(
            text: parts.joined(separator: " "),
            referencedEntryIDs: hits.map(\.id),
            suggestions: hits.prefix(2).map { CompanionSuggestion(title: "Open \(DateFormatting.dayLabel(for: $0.occurredAt, relativeTo: context.now))", action: .openEntry($0.id)) }
        )
    }

    private func questionReply(analysis: Analysis, context: CompanionContext, seed: UInt64) -> CompanionReply {
        if let focus = context.focusEntry, !focus.fullText.isEmpty, !analysis.lowered.hasPrefix("should i") {
            var text = pick(["That's a good question to sit with.", "Worth asking.", "I can't answer that for you, but we can look at it together."], seed: seed)
            text += " In the moment itself you wrote: “\(focus.snippet)”"
            if let feeling = focus.feeling {
                text += " You marked it as \(feeling.label.lowercased())."
            }
            let related = relatedEntries(to: focus, in: context, limit: 1)
            if let other = related.first, let shared = sharedConceptPhrase(focus, other, context: context) {
                text += " \(shared.capitalisedFirst) comes up \(DateFormatting.prosePhrase(for: other.occurredAt, relativeTo: context.now)) as well."
            }
            text += " " + pick(["What do you think made the difference?", "What was different about it, compared with the day before?", "If you had to name one thing, what was it?"], seed: seed &+ 5)
            return CompanionReply(text: text, referencedEntryIDs: related.map(\.id), suggestions: [
                .say("I think it was…", title: "I think it was"),
                .say("Honestly, I'm not sure"),
                CompanionSuggestion(title: "Keep this as a moment", action: .capture(analysis.text))
            ])
        }
        if analysis.lowered.hasPrefix("should i") || analysis.lowered.contains("what should i") {
            var text = "I can't tell you what to do — that's yours to decide — but I can help you think it through."
            if let kept = context.entries.first(where: \.isKept) {
                text += " \(DateFormatting.prosePhrase(for: kept.occurredAt, relativeTo: context.now).capitalisedFirst) you kept a moment that might be relevant: “\(kept.snippet)”"
                return CompanionReply(text: text + " What would the version of you who wrote that say?", referencedEntryIDs: [kept.id], suggestions: [.say("They'd say yes"), .say("They'd be cautious")])
            }
            return CompanionReply(text: text + " What's pulling you one way, and what's pulling the other?", suggestions: [.say("What's pulling me one way is…", title: "One way"), .say("What holds me back is…", title: "What holds me back")])
        }
        let related = retrieve(for: analysis, context: context, preferDifficult: nil, limit: 1, requireMatch: true)
        if let hit = related.first {
            return CompanionReply(
                text: "That's a good question to sit with. There's something in your journal that might be connected — \(DateFormatting.prosePhrase(for: hit.occurredAt, relativeTo: context.now)) you wrote: “\(hit.snippet)” Does that help, or is it a different question underneath?",
                referencedEntryIDs: [hit.id],
                suggestions: [CompanionSuggestion(title: "Open that moment", action: .openEntry(hit.id)), .say("It's a different question")]
            )
        }
        return CompanionReply(text: pick([
            "That's worth sitting with. I don't have anything in your journal that answers it directly, so I'd rather ask: what's your own sense of it?",
            "I can only answer from what you've captured, and that one isn't there. What makes you ask it today?"
        ], seed: seed), suggestions: [.say("My sense is…", title: "My sense is"), CompanionSuggestion(title: "Write it down instead", action: .capture(analysis.text))])
    }

    private func statementReply(analysis: Analysis, context: CompanionContext, turn: Int, seed: UInt64) -> CompanionReply {
        var parts: [String] = []
        var refs: [UUID] = []
        parts.append(pick(["Tell me more about that.", "Go on.", "I'm listening."], seed: seed))
        if let focus = context.focusEntry, turn <= 1, !focus.fullText.isEmpty {
            parts.append("Looking back at what you wrote \(DateFormatting.prosePhrase(for: focus.occurredAt, relativeTo: context.now)) — “\(focus.snippet)” — does this connect to it?")
            refs.append(focus.id)
        } else if let hit = retrieve(for: analysis, context: context, preferDifficult: nil, limit: 1, requireMatch: true).first {
            parts.append("\(DateFormatting.prosePhrase(for: hit.occurredAt, relativeTo: context.now).capitalisedFirst) you wrote about something that might be connected: “\(hit.snippet)” Is it?")
            refs.append(hit.id)
        } else {
            parts.append(pick(["What's underneath that, do you think?", "How does that sit with you right now?", "Is that new, or has it been building?"], seed: seed &+ 3))
        }
        return CompanionReply(text: parts.joined(separator: " "), referencedEntryIDs: refs, suggestions: [
            .say("It's connected"),
            .say("It's something new"),
            CompanionSuggestion(title: "Keep this as a moment", action: .capture(analysis.text))
        ])
    }

    // MARK: - Retrieval

    /// Finds moments relevant to what the person said, scored by shared concepts, shared words and recency.
    func retrieve(for analysis: Analysis, context: CompanionContext, preferDifficult: Bool?, limit: Int, requireMatch: Bool = false) -> [EntrySnapshot] {
        let keywords = Set(analysis.keywords)
        let conceptNames = Set(analysis.concepts.map(\.name))
        // A genuine match needs a shared concept, or at least half of the topic words.
        let requiredHits = max(1, Int((Double(keywords.count) / 2).rounded(.up)))
        var scored: [(EntrySnapshot, Double)] = []
        for entry in context.entries where entry.id != context.focusEntry?.id {
            var score = 0.0
            let entryConcepts = Set(entry.conceptNames)
            let conceptHits = entryConcepts.intersection(conceptNames).count
            score += Double(conceptHits) * 3
            let entryWords = Set(TextAnalyzer.contentWords(in: entry.fullText))
            let keywordHits = entryWords.intersection(keywords).count
            score += Double(keywordHits) * 1.2
            let age = DateFormatting.daysBetween(entry.occurredAt, context.now)
            if score > 0 { score += max(0, 1.5 - Double(age) / 30) }
            if let preferDifficult, let feeling = entry.feeling {
                if preferDifficult && feeling.isDifficult { score += score > 0 ? 1 : 0.4 }
                if !preferDifficult && feeling.isUplifting { score += score > 0 ? 1 : 0.4 }
            }
            if requireMatch, conceptHits == 0, keywords.isEmpty || keywordHits < requiredHits { continue }
            if score > 0 { scored.append((entry, score)) }
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }

    func relatedEntries(to entry: EntrySnapshot, in context: CompanionContext, limit: Int) -> [EntrySnapshot] {
        let names = Set(entry.conceptNames)
        guard !names.isEmpty else { return [] }
        return context.entries
            .filter { $0.id != entry.id && !Set($0.conceptNames).isDisjoint(with: names) }
            .sorted { abs($0.occurredAt.timeIntervalSince(entry.occurredAt)) < abs($1.occurredAt.timeIntervalSince(entry.occurredAt)) }
            .prefix(limit)
            .map { $0 }
    }

    /// The most meaningful thing two moments share, phrased for prose: people and places by name,
    /// themes in lowercase.
    private func sharedConceptPhrase(_ a: EntrySnapshot, _ b: EntrySnapshot, context: CompanionContext? = nil) -> String? {
        let shared = Set(a.conceptNames).intersection(b.conceptNames)
        guard !shared.isEmpty else { return nil }
        let ranked = shared.sorted { lhs, rhs in
            let l = kindRank(lhs, context: context), r = kindRank(rhs, context: context)
            return l == r ? lhs < rhs : l < r
        }
        guard let best = ranked.first else { return nil }
        if let kind = conceptKind(best, context: context), kind == .theme { return best.lowercasedFirst }
        return best
    }

    private func conceptKind(_ name: String, context: CompanionContext?) -> ConceptKind? {
        context?.concepts.first { $0.name == name }?.kind
    }

    private func kindRank(_ name: String, context: CompanionContext?) -> Int {
        switch conceptKind(name, context: context) {
        case .person: return 0
        case .place: return 1
        case .importantDate: return 2
        default: return 3
        }
    }

    private func difficultStreak(context: CompanionContext) -> Int? {
        let recent = context.entries(within: 7).filter { $0.feeling?.isDifficult ?? false }
        return recent.isEmpty ? nil : recent.count
    }

    private func topConcept(kind: ConceptKind, in entries: [EntrySnapshot], context: CompanionContext) -> ConceptSnapshot? {
        var counts: [String: Int] = [:]
        for entry in entries { for name in entry.conceptNames { counts[name, default: 0] += 1 } }
        return context.concepts
            .filter { $0.kind == kind && (counts[$0.name] ?? 0) >= 2 }
            .max { (counts[$0.name] ?? 0) < (counts[$1.name] ?? 0) }
    }

    private func daysUntil(_ concept: ConceptSnapshot, now: Date) -> Int? {
        guard concept.kind == .importantDate, let anchor = concept.anchorDate else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        var next = anchor
        if concept.recursYearly {
            var comps = calendar.dateComponents([.month, .day], from: anchor)
            comps.year = calendar.component(.year, from: today)
            if let candidate = calendar.date(from: comps) {
                next = candidate < today ? (calendar.date(byAdding: .year, value: 1, to: candidate) ?? candidate) : candidate
            }
        }
        return calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: next)).day
    }

    // MARK: - Small helpers

    private func pick(_ options: [String], seed: UInt64) -> String {
        options[Int(seed % UInt64(options.count))]
    }

    private func stableHash(_ text: String) -> UInt64 {
        StableHash.fnv1a(text)
    }

    private func joinNames(_ names: [String]) -> String {
        switch names.count {
        case 0: return "nothing in particular"
        case 1: return names[0]
        case 2: return "\(names[0]) and \(names[1])"
        default: return names.dropLast().joined(separator: ", ") + " and " + names.last!
        }
    }

    private func containsWholeWord(_ text: String, _ word: String) -> Bool {
        guard !word.isEmpty else { return false }
        let pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: word) + "(?![\\p{L}\\p{N}])"
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}

extension String {
    var capitalisedFirst: String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst()
    }

    var lowercasedFirst: String {
        guard let first = first else { return self }
        return first.lowercased() + dropFirst()
    }
}
