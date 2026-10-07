import SwiftUI
import SwiftData

/// The companion's front page: grounded ways in, and the threads you've already started.
struct CompanionHomeView: View {
    @Environment(AppServices.self) private var services
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @Query private var entries: [JournalEntry]
    @State private var starters: [ConversationStarter] = []
    @State private var draft = ""
    @State private var pendingStart: ConversationStart?
    @State private var conversationToDelete: Conversation?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    header
                    composer
                    if !starters.isEmpty { startersSection }
                    if !conversations.isEmpty { threadsSection }
                }
                .pageHorizontalPadding()
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(CanvasBackground())
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $pendingStart) { ConversationView(start: $0) }
            .appDestinations()
            .task(id: entries.count) { refreshStarters() }
            .confirmationDialog("Delete this conversation?", isPresented: Binding(get: { conversationToDelete != nil }, set: { if !$0 { conversationToDelete = nil } }), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let conversationToDelete { try? services.repository.delete(conversationToDelete) }
                    conversationToDelete = nil
                }
                Button("Keep", role: .cancel) { conversationToDelete = nil }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            CompanionMark(size: 44)
            Text("Companion")
                .font(.displaySerif)
                .foregroundStyle(Theme.Colors.ink)
            Text("Somewhere to think out loud. It only knows what you've captured here, and nothing you say leaves this phone.")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Theme.Spacing.xs)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.xs) {
            TextField("What's on your mind?", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.Colors.canvasRaised))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.Colors.hairline))
                .onSubmit { startFromDraft() }
                .accessibilityIdentifier("companion.input")
            Button { startFromDraft() } label: {
                Image(systemName: "arrow.up")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.Colors.canvasRaised)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(draft.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.Colors.inkTertiary : Theme.Colors.accent))
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel("Start a conversation")
            .accessibilityIdentifier("companion.send")
        }
    }

    private var startersSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Start somewhere").eyebrowStyle()
            ForEach(starters) { starter in
                Button {
                    pendingStart = ConversationStart(entryID: starter.focusEntryID, openingMessage: starter.openingMessage.isEmpty ? nil : starter.openingMessage, title: starter.title)
                } label: {
                    HStack(spacing: Theme.Spacing.md) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(starter.title)
                                .font(.headline)
                                .foregroundStyle(Theme.Colors.ink)
                                .multilineTextAlignment(.leading)
                            if let detail = starter.detail {
                                Text(detail)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.Colors.inkSecondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.Colors.accent)
                    }
                    .softCard()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("companion.starter")
            }
        }
    }

    private var threadsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Threads").eyebrowStyle()
            ForEach(conversations) { conversation in
                NavigationLink(value: conversation) {
                    HStack(spacing: Theme.Spacing.md) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(conversation.title)
                                    .font(.headline)
                                    .foregroundStyle(Theme.Colors.ink)
                                    .lineLimit(1)
                                Spacer()
                                Text(DateFormatting.dayLabel(for: conversation.updatedAt))
                                    .font(.caption)
                                    .foregroundStyle(Theme.Colors.inkTertiary)
                            }
                            Text(conversation.preview)
                                .font(.subheadline)
                                .foregroundStyle(Theme.Colors.inkSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) { conversationToDelete = conversation } label: {
                        Label("Delete conversation", systemImage: "trash")
                    }
                }
                Hairline()
            }
        }
    }

    private func refreshStarters() {
        starters = services.companion.starters(context: services.companionContext())
    }

    private func startFromDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        pendingStart = ConversationStart(openingMessage: text, title: TextSnippets.truncate(text, maxLength: 40).replacingOccurrences(of: "…", with: ""))
    }
}
