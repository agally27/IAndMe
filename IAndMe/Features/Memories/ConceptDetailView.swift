import SwiftUI
import SwiftData

/// A person, place, theme or date: what the app has noticed, with the moments behind it, and the
/// controls to correct or forget it.
struct ConceptDetailView: View {
    @Bindable var concept: MemoryConcept
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var isEditingNote = false
    @State private var noteDraft = ""
    @State private var showForgetConfirmation = false

    private var entries: [JournalEntry] { concept.sortedEntries }

    private var feelingSummary: String? {
        let felt = entries.compactMap(\.feeling)
        guard felt.count >= 2 else { return nil }
        let up = felt.filter(\.isUplifting).count
        let down = felt.filter(\.isDifficult).count
        if Double(up) / Double(felt.count) >= 0.6 { return "Moments here mostly felt good." }
        if Double(down) / Double(felt.count) >= 0.6 { return "Moments here have often felt heavy." }
        return "A mix of feelings, like most things."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header
                if concept.kind != .importantDate || !entries.isEmpty {
                    talkLink
                }
                if !entries.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text(entries.count == 1 ? "One moment" : "\(entries.count) moments").eyebrowStyle()
                        ForEach(entries) { entry in
                            NavigationLink(value: entry) { MomentCard(entry: entry, showsDay: true, compact: true) }.buttonStyle(.plain)
                        }
                    }
                } else {
                    Text(concept.kind == .importantDate ? "No moments are linked to this day yet." : "No moments mention this yet.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
                sourceLine
            }
            .pageHorizontalPadding()
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(CanvasBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { noteDraft = concept.note ?? ""; isEditingNote = true } label: { Label(concept.note == nil ? "Add a note" : "Edit note", systemImage: "pencil") }
                    Button(role: .destructive) { showForgetConfirmation = true } label: { Label("Forget this", systemImage: "eraser") }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("More")
            }
        }
        .alert("A note about \(concept.name)", isPresented: $isEditingNote) {
            TextField("What should I remember?", text: $noteDraft)
            Button("Save") {
                concept.note = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                if concept.source == .inferred { concept.source = .user }
                try? services.repository.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("In your words. The companion will use this when it mentions \(concept.name).")
        }
        .confirmationDialog("Forget \(concept.name)?", isPresented: $showForgetConfirmation, titleVisibility: .visible) {
            Button("Forget", role: .destructive) {
                concept.isForgotten = true
                try? services.repository.save()
                services.refreshInsights()
                dismiss()
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("Your moments stay exactly as they are. The app simply stops recognising this and won't bring it up.")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            if concept.kind == .person {
                InitialAvatar(name: concept.name, size: 64)
            } else {
                ZStack {
                    Circle().fill(Theme.Colors.accent.opacity(0.14))
                    Image(systemName: concept.kind.systemImage).font(.title2).foregroundStyle(Theme.Colors.accent)
                }
                .frame(width: 64, height: 64)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(concept.kind.label).eyebrowStyle()
                Text(concept.name).font(.titleSerif).foregroundStyle(Theme.Colors.ink)
                if let note = concept.note {
                    Text(note).font(.bodySerif).foregroundStyle(Theme.Colors.inkSecondary).fixedSize(horizontal: false, vertical: true)
                }
                if concept.kind == .importantDate, let anchor = concept.anchorDate {
                    HStack(spacing: 6) {
                        Text(anchor.formatted(.dateTime.day().month(.wide).year()))
                        if let days = concept.daysUntilNextOccurrence() {
                            Text("·")
                            Text(days == 0 ? "Today" : days == 1 ? "Tomorrow" : days > 0 ? "In \(days) days" : "\(-days) days ago")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.inkSecondary)
                } else if !entries.isEmpty {
                    Text("In \(entries.count) moment\(entries.count == 1 ? "" : "s") since \(concept.firstSeen.formatted(.dateTime.month(.wide).year()))" + (feelingSummary.map { ". \($0)" } ?? ""))
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var talkLink: some View {
        NavigationLink(value: ConversationStart(openingMessage: "I've been thinking about \(concept.name).", title: concept.name)) {
            HStack(spacing: Theme.Spacing.sm) {
                CompanionMark(size: 28)
                Text("Talk about \(concept.name)").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.Colors.ink)
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.Colors.inkTertiary)
            }
            .softCard(padding: Theme.Spacing.sm)
        }
        .buttonStyle(.plain)
    }

    private var sourceLine: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle").font(.caption)
            Text(concept.source.label)
        }
        .font(.caption)
        .foregroundStyle(Theme.Colors.inkTertiary)
    }
}

/// Every concept of one kind.
struct ConceptListView: View {
    let kind: ConceptKind
    @Query(sort: \MemoryConcept.mentionCount, order: .reverse) private var concepts: [MemoryConcept]

    private var items: [MemoryConcept] { concepts.filter { $0.kind == kind && !$0.isForgotten } }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(items) { concept in
                    NavigationLink(value: concept) {
                        HStack(spacing: Theme.Spacing.sm) {
                            if kind == .person {
                                InitialAvatar(name: concept.name, size: 40)
                            } else {
                                Image(systemName: kind.systemImage).foregroundStyle(Theme.Colors.accent).frame(width: 40)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(concept.name).font(.body).foregroundStyle(Theme.Colors.ink)
                                if let note = concept.note { Text(note).font(.caption).foregroundStyle(Theme.Colors.inkSecondary).lineLimit(1) }
                            }
                            Spacer()
                            Text("\(concept.entries.count)").font(.caption).foregroundStyle(Theme.Colors.inkTertiary)
                            Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(Theme.Colors.inkTertiary)
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Hairline()
                }
            }
            .pageHorizontalPadding()
        }
        .background(CanvasBackground())
        .navigationTitle(kind.pluralLabel)
        .navigationBarTitleDisplayMode(.inline)
    }
}
