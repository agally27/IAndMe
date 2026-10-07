# CLAUDE.md — I&ME

Guidance for anyone (human or AI) working in this repository.

## Purpose

I&ME is a private personal life journal with a reflective AI companion. The person captures fragments of life (text, voice, photos, a feeling, a place); the app keeps them, links them to people, places and themes, notices patterns, and composes them into memories and the chapters of a life story. The journal is the product; the companion exists to help the person understand it.

This is the first complete, **local-only** prototype. There is no backend, account, sync, analytics, payment or external AI. Do not add any of these without an explicit decision.

## Technology

- Swift 5 language mode on the Swift 6.2 compiler, Xcode 26, iOS 26 deployment target, iPhone only.
- SwiftUI for all UI; SwiftData for persistence; Swift Concurrency throughout.
- Native frameworks only: AVFoundation (recording, playback, sample speech synthesis), PhotosUI, Speech (on-device transcription), NaturalLanguage (sentiment, lemmas, named entities), UIKit for a few bridges (camera picker, image rendering).
- No third-party packages. Keep it that way for the prototype.

## Folder structure

```
IAndMe.xcodeproj/            Hand-written project using file-system-synchronised groups: adding a
                             file under IAndMe/, IAndMeTests/ or IAndMeUITests/ adds it to the target.
IAndMe/
  App/           IAndMeApp (entry, launch arguments), AppServices (DI container + post-save pipeline),
                 RootView (onboarding vs main), Brand (product name in one place)
  Models/        SwiftData @Model classes and their enums
  Persistence/   ModelContainerFactory + LocalStorage paths, JournalRepository protocol,
                 SwiftDataJournalRepository
  Services/
    AI/          CompanionTypes (snapshots, replies), AICompanionService protocol,
                 LocalCompanionService (rule engine), CompanionContextBuilder, Lexicon
    Memory/      MemoryService protocol + LocalMemoryService (mentions → concepts)
    Insights/    InsightService protocol + LocalInsightService
    LifeStory/   LifeStoryService protocol + LocalLifeStoryService
    Media/       MediaService protocol + LocalMediaService, ImageCache/ImageLoader/LocalPhoto
    Audio/       AudioRecorder, AudioPlayer, Waveform helpers
    Transcription/ TranscriptionService protocol + OnDeviceTranscriptionService
    Export/      ExportService (Markdown, JSON)
    Sample/      SampleLife (content), SampleDataService (installer), SampleImageRenderer,
                 SampleAudioSynthesizer
  Features/      Onboarding, Main (tabs, router, capture accessory), Today, Capture, Journal, Entry,
                 Companion, Memories, Story, Insights, Profile, Shared (MomentCard, destinations)
  DesignSystem/  Theme (colours, fonts, spacing, motion), Components (surfaces, buttons, chips,
                 waveform views)
  Utilities/     DateFormatting, TextSnippets, TextAnalyzer, StableHash
  Resources/     Assets.xcassets (semantic colours with light/dark variants, AccentColor, AppIcon)
IAndMeTests/     Swift Testing unit tests (in-memory container, temp media directory)
IAndMeUITests/   XCTest UI tests for the primary journey
Docs/            ARCHITECTURE.md and screenshots
```

## Data models (SwiftData)

| Model | Role | Key relationships |
| --- | --- | --- |
| `UserProfile` | The one person; name, avatar, onboarding and sample-life flags | — |
| `JournalEntry` | A moment: text, `occurredAt` (editable), `feelingRaw`, `isKept`, `placeName`, `isSample` | cascade → `attachments`, `recordings`, `conversations`; many-to-many `concepts`, `collections`, `insights`, `chapters` |
| `MediaAttachment` | A photo file in `Media/Photos` with pixel size and sort order | `entry` |
| `VoiceRecording` | An audio file in `Media/Audio`, duration, waveform samples, optional transcript and state | `entry` |
| `MemoryConcept` | A person, place, theme or important date the app recognises; aliases, note, source, `isForgotten` | `entries`, `insights` |
| `MemoryCollection` | A curated group of moments (experience, ritual, milestone, unexpected) | `entries` |
| `Insight` | An observation with a stable `key`, kind, confidence, period, `isDismissed`, source | `relatedEntries`, `relatedConcepts` |
| `LifeChapter` | Editorial chapter by kind (present, period, people, places, learned, remember) | `entries` |
| `Conversation` / `ConversationMessage` | Companion threads; messages carry referenced entry IDs and encoded suggestions | `entry` (optional anchor), cascade → `messages` |

Conventions: enums are stored as raw values with computed accessors; `EntryKind` is derived from content, never stored; `KnowledgeSource` (`sample`, `inferred`, `user`) tags everything the app learns so it can be shown and removed honestly.

## Service abstractions

All intelligence works on Sendable snapshots (`EntrySnapshot`, `ConceptSnapshot`, `InsightSnapshot`, `MessageSnapshot`) inside a `CompanionContext`, built by `CompanionContextBuilder` from the repository.

- `JournalRepository` — the single door for mutations and whole-journal operations (statistics, delete everything, delete sample life). Views read with `@Query`.
- `MediaService` — photo/audio file storage. `LocalMediaService` downsamples photos to 2048px JPEG.
- `AICompanionService` — `reply(to:history:context:)`, `opening(context:)`, `starters(context:)`, `todayPrompt(context:)`.
- `MemoryService` — `mentions(in:knownConcepts:ownerName:)`; `AppServices.linkConcepts(for:)` applies the result to the store.
- `InsightService` — `generateInsights(entries:concepts:now:)` → drafts keyed for in-place updates; `AppServices.refreshInsights()` applies them and keeps dismissals.
- `LifeStoryService` — `draftChapter(entries:concepts:period:now:)`.
- `TranscriptionService` — on-device only; reports availability honestly.
- `ExportService` — Markdown and JSON files in the temporary directory for `ShareLink`.

`AppServices.process(_ entry:)` is the post-save pipeline (link concepts → refresh insights) and the seam for any future processing.

## AI abstraction

`LocalCompanionService` is a deterministic rule engine (see Docs/ARCHITECTURE.md): analyse → classify intent → retrieve relevant moments → compose from templates and the person's own words → suggest follow-ups (`CompanionSuggestion`: say, open entry, capture). It never fabricates: if retrieval finds nothing it says so. Reply variation is seeded by a stable hash of the message, so tests are reproducible. `replyDelay` simulates thinking and is zero under `-ui-testing` and in tests.

To replace it with a real model: implement `AICompanionService`, build the prompt from `CompanionContext` (which already contains everything the local engine uses), keep `CompanionReply.referencedEntryIDs` populated so references stay tappable, and swap the instance in `AppServices.init`. The UI needs no changes.

## Local storage

`Application Support/LifeJournal/` (brand-neutral name) contains `Journal.store` (SwiftData) and `Media/Photos`, `Media/Audio`. `LocalStorage` owns the paths. `-reset-data` removes both. Exports are written to the temporary directory.

## Future strategy (not implemented)

- **Backend**: an API layer in front of Postgres (Supabase or Neon). Add a `RemoteJournalRepository` or a sync layer behind `JournalRepository`; keep the snapshot types as the wire-level contract for intelligence calls. Media would move to object storage with signed URLs behind `MediaService`.
- **Authentication**: Sign in with Apple first, then email. Gate only sync and remote AI behind sign-in; the local journal must keep working signed out.
- **Production AI**: a `RemoteCompanionService` calling a server that holds the model keys. Server-side extraction would populate `MemoryConcept`, `Insight` and `LifeChapter` through the same `KnowledgeSource.inferred` path. Keep on-device fallbacks for offline use and keep every AI output traceable to entry IDs.
- **Privacy**: encrypt the store and media at rest, end-to-end encrypt sync, explicit per-feature consent for any processing that leaves the device, deletion that propagates to the server, a real privacy policy. `PrivacyView` already states this honestly.

## Privacy considerations in the prototype

Nothing leaves the device. Speech recognition is forced on-device. The companion and insights are computed locally. "What I remember" lists every concept with its source and a forget action. Deletion is double-confirmed and final. The sample life is clearly labelled and separately removable.

## Testing

- Unit tests (`IAndMeTests`, Swift Testing) use `TestStack.make(seedSample:)` for an in-memory container and a throwaway media directory. They cover the repository (create, edit, delete, ordering, media relationships, statistics, delete everything), memory extraction and linking, insight generation on synthetic and sample data, companion intents, retrieval honesty, context building, conversation sessions, life-story drafting, sample installation/removal, export, and text helpers.
- UI tests (`IAndMeUITests`, XCTest) run the primary journey: launch → onboarding → capture → journal → open moment → companion → memories → story, plus a sweep of the sample-life screens and the voice recorder. Set the `SCREENSHOT_DIR` environment variable (as `TEST_RUNNER_SCREENSHOT_DIR` with xcodebuild) to save PNGs. Grant the microphone first for the recorder test: `xcrun simctl privacy booted grant microphone com.iandme.prototype`.
- When writing `#expect`, avoid key-path-as-function arguments inside the macro (`allSatisfy(\.x)`); use closures.

## Build and run

```bash
xcodebuild -project IAndMe.xcodeproj -scheme IAndMe -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project IAndMe.xcodeproj -scheme IAndMe -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Launch arguments: `-reset-data`, `-seed-sample`, `-open-tab <today|journal|companion|memories|story>`, `-capture <write|voice|photo>`, `-ui-testing`.

Note for the Simulator: the first voice recording triggers a macOS microphone prompt for the Simulator app. If nobody answers it, the recorder reports the microphone as unavailable after 8 seconds rather than hanging; on a device it starts immediately.

## Working conventions

- Microcopy is human: "Capture a moment", "Worth remembering", "Your memories will begin here". No generic app copy, no emoji in the interface.
- Serif (`.serif` design) for editorial text and the companion's voice; system sans for controls. Use Dynamic Type text styles only.
- Colours come from the asset catalogue through `Theme.Colors`; never hard-code.
- Respect Reduce Motion via `@Environment(\.motion)`.
- Give every control an accessibility label; add identifiers for anything a UI test touches.
- Never let a feature depend on the product name: use `Brand`.

## Known limitations

See Docs/ARCHITECTURE.md. In short: rule-based companion, imperfect on-device name recognition, procedurally rendered sample imagery and synthesised sample voice, transcription availability varies, export references media by name, no encryption beyond iOS data protection, iPhone-only layout.

## Suggested next steps

1. Real model behind `AICompanionService` with the same grounding guarantees.
2. Server-side concept and chapter extraction feeding the existing models.
3. Encrypted sync and Sign in with Apple.
4. Bundled export (ZIP with media) and PDF chapters.
5. User-created collections and chapter editing.
6. iPad layout and widgets for Today's question.
