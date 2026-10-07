import SwiftUI
import SwiftData

/// Thousands of small moments, read together. Editorial, not a report.
struct StoryView: View {
    @Environment(AppServices.self) private var services
    @Environment(AppRouter.self) private var router
    @Query(sort: \LifeChapter.sortOrder) private var chapters: [LifeChapter]
    @Query private var entries: [JournalEntry]
    @Query private var profiles: [UserProfile]
    @State private var showDraft = false

    private var present: LifeChapter? { chapters.first { $0.kind == .present } }
    private var periods: [LifeChapter] { chapters.filter { $0.kind == .period }.sorted { ($0.periodEnd ?? .distantPast) > ($1.periodEnd ?? .distantPast) } }
    private var themed: [LifeChapter] { [.people, .places, .learned, .remember].compactMap { kind in chapters.first { $0.kind == kind } } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    header
                    if chapters.isEmpty {
                        emptyStory
                    } else {
                        if let present { presentHero(present) }
                        chaptersSection
                        if !themed.isEmpty { themedSection }
                    }
                }
                .pageHorizontalPadding()
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .background(CanvasBackground())
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showDraft) { DraftChapterView() }
            .appDestinations()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(Brand.selfWord) & \(Brand.reflectiveWord)").eyebrowStyle()
            Text("My Story")
                .font(.displaySerif)
                .foregroundStyle(Theme.Colors.ink)
            Text("Small moments, read together, become the story of a life.")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.inkSecondary)
        }
        .padding(.top, Theme.Spacing.xs)
    }

    private var emptyStory: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Your story will begin here")
                .font(.title2Serif)
                .foregroundStyle(Theme.Colors.ink)
            Text(entries.count >= 3
                 ? "You have enough moments to draft a first chapter. It will be written from your own words and you can keep it or let it go."
                 : "Once you've captured a few moments, a first chapter can be drafted from them — in your own words, read back to you.")
                .font(.body)
                .foregroundStyle(Theme.Colors.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if entries.count >= 3 {
                Button("Draft a chapter") { showDraft = true }
                    .buttonStyle(.primary)
            } else {
                Button("Capture a moment") { router.capture(.write) }
                    .buttonStyle(.primary)
            }
        }
        .softCard(padding: Theme.Spacing.lg, raised: true)
    }

    private func presentHero(_ chapter: LifeChapter) -> some View {
        NavigationLink(value: chapter) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(chapter.kind.label).eyebrowStyle()
                Text(chapter.paragraphs.first ?? chapter.body)
                    .font(.readingSerif)
                    .foregroundStyle(Theme.Colors.ink)
                    .lineSpacing(4)
                    .lineLimit(6)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    Text("Read on")
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Colors.accent)
            }
            .softCard(padding: Theme.Spacing.lg, raised: true)
        }
        .buttonStyle(.plain)
    }

    private var chaptersSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeading(eyebrow: "Chapters", title: periods.isEmpty ? "No chapters yet" : "Recent chapters") {
                Button {
                    showDraft = true
                } label: {
                    Label("Draft", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.Colors.accent)
                }
                .accessibilityLabel("Draft a new chapter")
                .accessibilityIdentifier("story.draft")
            }
            ForEach(periods) { chapter in
                NavigationLink(value: chapter) {
                    ChapterCard(chapter: chapter)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var themedSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Threads").eyebrowStyle()
            VStack(spacing: 0) {
                ForEach(themed) { chapter in
                    NavigationLink(value: chapter) {
                        HStack(spacing: Theme.Spacing.sm) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(chapter.title).font(.headlineSerif).foregroundStyle(Theme.Colors.ink)
                                Text(chapter.kind == .remember ? "\(entries.filter(\.isKept).count) moments you kept" : TextSnippets.snippet(of: chapter.paragraphs.first ?? "", maxLength: 70))
                                    .font(.subheadline).foregroundStyle(Theme.Colors.inkSecondary).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(Theme.Colors.inkTertiary)
                        }
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if chapter.id != themed.last?.id { Hairline() }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).fill(Theme.Colors.surface))
        }
    }
}

struct ChapterCard: View {
    let chapter: LifeChapter

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let cover = chapter.resolvedCoverFileName {
                LocalPhoto(fileName: cover, targetPixelSize: 1200)
                    .frame(height: 170)
            }
            VStack(alignment: .leading, spacing: 6) {
                if let subtitle = chapter.subtitle { Text(subtitle).eyebrowStyle() }
                Text(chapter.title).font(.title3Serif).foregroundStyle(Theme.Colors.ink)
                Text(TextSnippets.snippet(of: chapter.paragraphs.first ?? "", maxLength: 140))
                    .font(.subheadline).foregroundStyle(Theme.Colors.inkSecondary).lineLimit(3)
                Text("\(chapter.entries.count) moment\(chapter.entries.count == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(Theme.Colors.inkTertiary).padding(.top, 2)
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.canvasRaised)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.Colors.hairline, lineWidth: 0.5))
        .shadow(color: Theme.Shadow.soft, radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }
}

struct ChapterDetailView: View {
    let chapter: LifeChapter
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \JournalEntry.occurredAt, order: .reverse) private var allEntries: [JournalEntry]
    @State private var showDelete = false

    private var moments: [JournalEntry] {
        chapter.kind == .remember ? allEntries.filter(\.isKept) : chapter.sortedEntries
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                if let cover = chapter.resolvedCoverFileName, chapter.kind == .period {
                    LocalPhoto(fileName: cover, targetPixelSize: 1600)
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                        .padding(.horizontal, Theme.Spacing.sm)
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let subtitle = chapter.subtitle { Text(subtitle).eyebrowStyle() }
                        Text(chapter.title)
                            .font(.displaySerif)
                            .foregroundStyle(Theme.Colors.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if chapter.kind == .learned {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            ForEach(Array(chapter.paragraphs.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.readingSerif)
                                    .foregroundStyle(Theme.Colors.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.leading, Theme.Spacing.sm)
                                    .overlay(alignment: .leading) { Rectangle().fill(Theme.Colors.accent.opacity(0.5)).frame(width: 2) }
                            }
                        }
                    } else {
                        ForEach(Array(chapter.paragraphs.enumerated()), id: \.offset) { index, paragraph in
                            Text(paragraph)
                                .font(index == 0 ? .title3Serif : .readingSerif)
                                .fontWeight(index == 0 ? .regular : .regular)
                                .foregroundStyle(index == 0 ? Theme.Colors.ink : Theme.Colors.ink.opacity(0.92))
                                .lineSpacing(6)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "sparkle").font(.caption)
                        Text(chapter.source == .sample ? "Written from the sample life" : "Drafted from \(chapter.entries.count) of your moments. Every quote is your own.")
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.inkTertiary)
                    if !moments.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            SectionHeading(eyebrow: "The moments behind it", title: "\(moments.count) moment\(moments.count == 1 ? "" : "s")")
                            ForEach(moments) { entry in
                                NavigationLink(value: entry) { MomentCard(entry: entry, showsDay: true, compact: true) }.buttonStyle(.plain)
                            }
                        }
                    }
                }
                .pageHorizontalPadding()
            }
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(CanvasBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if chapter.kind == .period {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) { showDelete = true } label: { Label("Remove chapter", systemImage: "trash") }
                    } label: { Image(systemName: "ellipsis") }
                    .accessibilityLabel("More")
                }
            }
        }
        .confirmationDialog("Remove this chapter?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                services.repository.modelContext.delete(chapter)
                try? services.repository.save()
                dismiss()
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("The moments it was drawn from stay in your journal.")
        }
    }
}

/// Lets the person draft a chapter from a stretch of their own moments, preview it, and keep it.
struct DraftChapterView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var period: Period = .month
    @State private var draft: ChapterDraft?
    @State private var noDraft = false

    enum Period: String, CaseIterable, Identifiable {
        case month, quarter, half, all
        var id: String { rawValue }
        var label: String {
            switch self {
            case .month: return "Last month"
            case .quarter: return "Last three months"
            case .half: return "Last six months"
            case .all: return "Everything"
            }
        }
        var range: ClosedRange<Date> {
            let now = Date.now
            switch self {
            case .month: return now.adding(days: -31)...now
            case .quarter: return now.adding(days: -92)...now
            case .half: return now.adding(days: -183)...now
            case .all: return Date.distantPast...now
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text("A chapter is drafted from your own moments: who appears, where you were, how things felt, and what you wrote. Nothing is invented.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Picker("Period", selection: $period) {
                        ForEach(Period.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.Colors.accent)
                    if let draft {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text(draft.subtitle).eyebrowStyle()
                            Text(draft.title).font(.titleSerif).foregroundStyle(Theme.Colors.ink)
                            ForEach(Array(draft.body.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, paragraph in
                                Text(paragraph).font(.bodySerif).foregroundStyle(Theme.Colors.ink).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                            }
                            Text("Drawn from \(draft.entryIDs.count) moments").font(.caption).foregroundStyle(Theme.Colors.inkTertiary)
                        }
                        .softCard(padding: Theme.Spacing.lg, raised: true)
                    } else if noDraft {
                        Text("There aren't enough moments in that stretch to write from. Try a longer period.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.inkSecondary)
                    }
                }
                .padding(Theme.Spacing.page)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .background(CanvasBackground())
            .navigationTitle("Draft a chapter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Keep chapter") { keep() }.fontWeight(.semibold).disabled(draft == nil)
                        .accessibilityIdentifier("draft.keep")
                }
            }
            .task(id: period) { generate() }
        }
    }

    private func generate() {
        let context = services.companionContext()
        let result = services.lifeStory.draftChapter(entries: context.entries, concepts: context.concepts, period: period.range, now: .now)
        draft = result
        noDraft = result == nil
    }

    private func keep() {
        guard let draft else { return }
        let existing = services.repository.allChapters()
        let chapter = LifeChapter(kind: .period, title: draft.title, subtitle: draft.subtitle, body: draft.body, periodStart: draft.periodStart, periodEnd: draft.periodEnd, sortOrder: (existing.map(\.sortOrder).max() ?? 0) + 1, source: .user)
        chapter.entries = draft.entryIDs.compactMap { services.repository.entry(id: $0) }
        services.repository.modelContext.insert(chapter)
        try? services.repository.save()
        dismiss()
    }
}
