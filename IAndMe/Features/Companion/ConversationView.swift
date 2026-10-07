import SwiftUI
import SwiftData

/// A private conversation. Not a chat app: the companion's words read like a letter, the person's
/// like notes in the margin, and every reference points back to a real moment.
struct ConversationView: View {
    @Environment(AppServices.self) private var services
    @Environment(AppRouter.self) private var router
    @Environment(\.motion) private var motion

    @State private var session: ConversationSession?
    @State private var draft = ""
    @State private var pendingEntry: JournalEntry?
    @FocusState private var composerFocused: Bool

    private let existing: Conversation?
    private let start: ConversationStart?

    init(conversation: Conversation) {
        existing = conversation
        start = nil
    }

    init(start: ConversationStart) {
        existing = nil
        self.start = start
    }

    var body: some View {
        Group {
            if let session {
                content(session)
            } else {
                Color.clear
            }
        }
        .background(CanvasBackground())
        .navigationTitle(session?.conversation?.title ?? "Companion")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $pendingEntry) { EntryDetailView(entry: $0) }
        .task {
            if session == nil {
                let created: ConversationSession
                if let existing {
                    created = ConversationSession(services: services, conversation: existing)
                } else if let start {
                    created = ConversationSession(services: services, start: start)
                } else {
                    created = ConversationSession(services: services, start: ConversationStart())
                }
                session = created
                await created.prepare()
                if start?.openingMessage == nil && start?.entryID == nil && existing == nil {
                    composerFocused = true
                }
            }
        }
        .onDisappear { session?.discardIfEmpty() }
    }

    private func content(_ session: ConversationSession) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    if let entry = session.focusEntry {
                        NavigationLink(value: entry) {
                            MomentReference(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, Theme.Spacing.xs)
                    }
                    ForEach(session.messages) { message in
                        MessageView(message: message, session: session, isLatest: message.id == session.messages.last?.id && !session.isThinking) { suggestion in
                            handle(suggestion, session: session)
                        }
                        .id(message.id)
                        .transition(motion.transition(.opacity.combined(with: .move(edge: .bottom))))
                    }
                    if session.isThinking {
                        ThinkingIndicator()
                            .id("thinking")
                            .transition(motion.transition(.opacity))
                    }
                    if let error = session.errorMessage {
                        Text(error).font(.caption).foregroundStyle(Theme.Colors.inkTertiary)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .pageHorizontalPadding()
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.md)
                .animation(motion.gentle, value: session.messages.count)
                .animation(motion.gentle, value: session.isThinking)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: session.messages.count) { scrollToBottom(proxy) }
            .onChange(of: session.isThinking) { scrollToBottom(proxy) }
            .onAppear { scrollToBottom(proxy, animated: false) }
            .safeAreaInset(edge: .bottom) { composer(session) }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            withAnimation(animated ? motion.gentle : nil) { proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }

    private func composer(_ session: ConversationSession) -> some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.xs) {
            TextField("Say something", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($composerFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.Colors.canvasRaised))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.Colors.hairline))
                .accessibilityIdentifier("conversation.input")
                .onSubmit { send(session) }
            Button {
                send(session)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.Colors.canvasRaised)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(draft.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.Colors.inkTertiary : Theme.Colors.accent))
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || session.isThinking)
            .accessibilityLabel("Send")
            .accessibilityIdentifier("conversation.send")
        }
        .padding(.horizontal, Theme.Spacing.page)
        .padding(.vertical, Theme.Spacing.xs)
        .background(.bar)
    }

    private func send(_ session: ConversationSession) {
        let text = draft
        draft = ""
        Task { await session.send(text) }
    }

    private func handle(_ suggestion: CompanionSuggestion, session: ConversationSession) {
        switch suggestion.action {
        case .say(let text):
            Task { await session.send(text) }
        case .openEntry(let id):
            pendingEntry = session.entry(for: id)
        case .capture(let text):
            router.capture(.write, text: text)
        }
    }
}

private struct MessageView: View {
    let message: ConversationMessage
    let session: ConversationSession
    let isLatest: Bool
    let onSuggestion: (CompanionSuggestion) -> Void

    var body: some View {
        switch message.role {
        case .companion:
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                CompanionMark(size: 24)
                    .padding(.top, 3)
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(message.text)
                        .font(.bodySerif)
                        .foregroundStyle(Theme.Colors.ink)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                    let referenced = message.referencedEntryIDs.compactMap { session.entry(for: $0) }
                    if !referenced.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(referenced) { entry in
                                NavigationLink(value: entry) {
                                    MomentReference(entry: entry)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if isLatest, !message.suggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(message.suggestions) { suggestion in
                                    Button { onSuggestion(suggestion) } label: {
                                        Chip(title: suggestion.title, systemImage: icon(for: suggestion), tint: Theme.Colors.accent)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .scrollClipDisabled()
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Companion: \(message.text)")
        case .user:
            HStack {
                Spacer(minLength: 48)
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(Theme.Colors.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.Colors.surfaceStrong))
                    .textSelection(.enabled)
            }
            .accessibilityLabel("You: \(message.text)")
        }
    }

    private func icon(for suggestion: CompanionSuggestion) -> String? {
        switch suggestion.action {
        case .say: return nil
        case .openEntry: return "book.closed"
        case .capture: return "pencil.line"
        }
    }
}

private struct ThinkingIndicator: View {
    @State private var phase = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            CompanionMark(size: 24)
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Theme.Colors.inkTertiary)
                        .frame(width: 7, height: 7)
                        .opacity(reduceMotion ? 0.6 : (phase == index ? 1 : 0.35))
                }
            }
        }
        .accessibilityLabel("Companion is thinking")
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(320))
                phase = (phase + 1) % 3
            }
        }
    }
}
