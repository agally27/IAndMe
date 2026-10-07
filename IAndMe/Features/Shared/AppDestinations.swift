import SwiftUI

/// Value used to start a new conversation from anywhere.
struct ConversationStart: Hashable {
    var id = UUID()
    var entryID: UUID? = nil
    var openingMessage: String? = nil
    var title: String? = nil
}

/// Secondary screens that several tabs can push.
enum AppScreen: Hashable {
    case insights
    case keptMoments
    case photos
    case concepts(ConceptKind)
    case whatIRemember
    case privacy
    case export
}

extension View {
    /// Registers every navigation destination the app uses, so any stack can push any screen.
    func appDestinations() -> some View {
        self
            .navigationDestination(for: JournalEntry.self) { EntryDetailView(entry: $0) }
            .navigationDestination(for: MemoryConcept.self) { ConceptDetailView(concept: $0) }
            .navigationDestination(for: MemoryCollection.self) { CollectionDetailView(collection: $0) }
            .navigationDestination(for: LifeChapter.self) { ChapterDetailView(chapter: $0) }
            .navigationDestination(for: Insight.self) { InsightDetailView(insight: $0) }
            .navigationDestination(for: Conversation.self) { ConversationView(conversation: $0) }
            .navigationDestination(for: ConversationStart.self) { ConversationView(start: $0) }
            .navigationDestination(for: AppScreen.self) { screen in
                switch screen {
                case .insights: InsightsView()
                case .keptMoments: KeptMomentsView()
                case .photos: PhotosGridView()
                case .concepts(let kind): ConceptListView(kind: kind)
                case .whatIRemember: WhatIRememberView()
                case .privacy: PrivacyView()
                case .export: ExportView()
                }
            }
    }
}
