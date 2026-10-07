# Architecture and design decisions

This document explains how the prototype is put together and why. [CLAUDE.md](../CLAUDE.md) is the reference; this is the reasoning.

## The shape of the app

```
┌──────────────────────────────────────────────────────────────────┐
│  Features (SwiftUI)                                              │
│  Today · Capture · Journal · Entry · Companion · Memories ·      │
│  Story · Insights · Profile · Onboarding                         │
├──────────────────────────────────────────────────────────────────┤
│  AppServices (one injectable, @Observable container)             │
│    repository: JournalRepository        media: MediaService      │
│    companion: AICompanionService        memory: MemoryService    │
│    insights: InsightService             lifeStory: LifeStoryService
│    transcription: TranscriptionService  export, sample           │
├──────────────────────────────────────────────────────────────────┤
│  Intelligence works on Sendable snapshots, never on model objects │
│  CompanionContext { entries, concepts, insights, focusEntry }    │
├──────────────────────────────────────────────────────────────────┤
│  Persistence: SwiftData models in one store, media as files      │
│  Application Support/LifeJournal/{Journal.store, Media/Photos,   │
│  Media/Audio}                                                    │
└──────────────────────────────────────────────────────────────────┘
```

Views read through `@Query` so the interface stays live. Every mutation goes through `JournalRepository`, which keeps media files and derived knowledge consistent. After a moment is saved, `AppServices.process(entry)` runs the pipeline: link concepts, refresh insights. That one method is the seam where a production AI pipeline would plug in.

## Why snapshots

The companion, insight and life-story services never touch SwiftData objects. They receive plain value types (`EntrySnapshot`, `ConceptSnapshot`, `InsightSnapshot`, `MessageSnapshot`) built by `CompanionContextBuilder` on the main actor. This has three effects:

1. The services are pure and testable without a model container.
2. Model objects never cross actor boundaries.
3. A remote implementation of `AICompanionService` would receive exactly the same inputs as the local one; the interface does not change when the engine does.

## The local companion is not a chatbot

`LocalCompanionService` is deliberately rule-driven and transparent:

- **Analyse**: on-device sentiment (NaturalLanguage) blended with a small lexicon, a question check, mentioned concepts, and topic words with the intent phrases ("remember when", "write this down") stripped out so they never count as topics.
- **Classify**: crisis → capture request → pattern question → recall → greeting/goodbye/thanks → tired → question → difficult → positive → about a concept → statement. Questions win over sentiment unless clearly difficult language is present, because the sentiment model is unreliable on short sentences.
- **Retrieve**: moments scored by shared concepts, shared topic words and recency. For replies that quote the journal, a real overlap is required (a shared concept or at least half the topic words); otherwise the companion says it cannot find anything rather than inventing a link.
- **Compose**: an acknowledgement that varies deterministically, a grounding sentence quoting the person's own words with a relative date, and one question whose depth increases with the number of turns. Follow-up suggestions are encoded into the stored message so they survive relaunch.

Hard rules: it never fabricates a memory, never diagnoses, never presents itself as a therapist, and on crisis language it steps back and points to people.

## Memory layer

`MemoryConcept` is the transparent "what the app remembers": people, places, themes and important dates, each with a source (sample, noticed, added by you), a note in plain words, and a "forgotten" flag that stops it being used without touching the moments themselves.

`LocalMemoryService` finds mentions by: known concepts (name or alias, whole-word, case-insensitive) → on-device named-entity tagging with guards against its mistakes (sentence-initial capitals, fragments joined to known names, name prefixes like "St") → a small cue heuristic ("with Priya", "at Porthmeor") → a theme lexicon over lemmatised words.

## Insights

`LocalInsightService` is deterministic over a 90-day window and produces drafts keyed so they update in place. Observations:

- relief patterns (a restorative theme or place that follows difficult days; work, sleep and health are excluded because they recur without being comforts)
- what lifted you (people/places with mostly good or bright moments)
- recurring themes, top people, top places
- the hardest stretch (a seven-day window with the most difficult moments)
- rhythm (late-night writing, morning writing, a dominant weekday)

Confidence comes from counts and drives the hedging language ("I may be seeing a pattern", "It seems", "You've mentioned this often"). Dismissed insights stay dismissed across refreshes.

## Life story

`LocalLifeStoryService.draftChapter` composes a chapter from a period: scale and mood, the people who appear most with a real quote, the places that return, the running themes with the heaviest and brightest days quoted, and a closing line based on the feeling trend. A title is chosen from the dominant place or theme and the trend. The sample chapters are hand-written to show the intended editorial quality; drafted chapters show the mechanism working on real data.

## Product decisions made during the build

- **Five tabs plus a capture accessory.** Today, Journal, Companion, Memories, Story. The iOS 26 tab bar accessory keeps "Capture a moment" (with voice and photo shortcuts) one thumb away on every screen, which is the most important interaction in the product.
- **Memories and Story are separate.** Memories holds things (kept moments, collections, people, places, photos, days). Story holds narrative (chapters, threads). Insights live under "Noticed", surfaced on Today and reachable from both.
- **Feelings are five words, not a scale or emoji**: Heavy, Low, Steady, Good, Bright. They tint quietly and feed the intelligence without turning the journal into a chart.
- **No entry types.** Kind is derived from content. A moment with a photo and a voice note is simply a moment.
- **Sample life is a choice in onboarding**, not a default dumped on the person, and it is removable without touching their own moments.
- **Serif for the editorial voice, sans for the interface.** Titles, chapters and the companion's words use the system serif design; controls use the system sans. Everything is Dynamic Type.
- **Transparency over cleverness.** Every insight shows the moments behind it. Every concept shows where it came from. The companion's references are tappable.

## Known limitations

- The companion is rule-based. It is convincing within the journal's vocabulary and honest outside it, but it is not a language model.
- Named-entity recognition is on-device and imperfect; the guards favour precision over recall. New names at the start of a sentence may be missed until they appear elsewhere.
- Sample photographs are procedurally rendered scenes, not photographs. Sample voice notes are read by the system speech synthesiser.
- On-device transcription depends on the device supporting it; the simulator often does not.
- Export references media files by name rather than bundling them.
- The local store is not encrypted beyond iOS data protection.
