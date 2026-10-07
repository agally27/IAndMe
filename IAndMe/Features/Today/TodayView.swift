import SwiftUI
import SwiftData

/// The front door. A greeting, one reflective question, one thing noticed, one memory worth
/// keeping close, and the most recent moments. Capture is always a thumb away in the tab accessory.
struct TodayView: View {
    @Environment(AppServices.self) private var services
    @Environment(AppRouter.self) private var router
    @Query(sort: \JournalEntry.occurredAt, order: .reverse) private var entries: [JournalEntry]
    @Query private var profiles: [UserProfile]
    @Query(sort: \Insight.updatedAt, order: .reverse) private var insights: [Insight]
    @Query private var concepts: [MemoryConcept]

    @State private var prompt: TodayPrompt?
    @State private var starter: ConversationStarter?
    @State private var showProfile = false

    private var profile: UserProfile? { profiles.first }
    private var recent: [JournalEntry] { Array(entries.prefix(3)) }
    private var todayEntries: [JournalEntry] { entries.filter { Calendar.current.isDateInToday($0.occurredAt) } }
    private var activeInsights: [Insight] { insights.filter { !$0.isDismissed } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    header
                    if entries.isEmpty {
                        firstMomentInvitation
                    } else {
                        promptCard
                        if let insight = activeInsights.first { noticedSection(insight) }
                        if let memory = memoryWorthKeeping { memorySection(memory) }
                        if let starter { companionSection(starter) }
                        recentSection
                    }
                }
                .pageHorizontalPadding()
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .background(CanvasBackground())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showProfile = true } label: {
                        ProfileAvatar(profile: profile, size: 32)
                    }
                    .accessibilityLabel("Your profile")
                    .accessibilityIdentifier("today.profile")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showProfile) { ProfileView() }
            .appDestinations()
            .task(id: entries.count) { refreshPrompt() }
            .onChange(of: insights.count) { refreshPrompt() }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .eyebrowStyle()
            Text(greeting)
                .font(.displaySerif)
                .foregroundStyle(Theme.Colors.ink)
                .fixedSize(horizontal: false, vertical: true)
            if !todayEntries.isEmpty {
                Text(todayEntries.count == 1 ? "One moment captured today." : "\(todayEntries.count) moments captured today.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.inkSecondary)
            }
        }
        .padding(.top, Theme.Spacing.xs)
        .accessibilityIdentifier("today.header")
    }

    private var greeting: String {
        let base = DateFormatting.greeting()
        if let name = profile?.firstName, !name.isEmpty { return "\(base), \(name)." }
        return base + "."
    }

    private var firstMomentInvitation: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Capture your first moment")
                .font(.title2Serif)
                .foregroundStyle(Theme.Colors.ink)
            Text("It doesn't need to be important. A thought, a photo, something someone said. Your story starts with whatever is true right now.")
                .font(.body)
                .foregroundStyle(Theme.Colors.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: Theme.Spacing.xs) {
                InvitationRow(title: "Write something", detail: "A line or a page", systemImage: "pencil.line") { router.capture(.write, prompt: prompt?.question) }
                    .accessibilityIdentifier("today.first.write")
                InvitationRow(title: "Say it out loud", detail: "A voice moment, kept on this phone", systemImage: "mic") { router.capture(.voice) }
                InvitationRow(title: "Start with a photo", detail: "From your library", systemImage: "photo") { router.capture(.photo) }
            }
            if let prompt {
                Text("If you need a nudge: \(prompt.question)")
                    .font(.calloutSerif)
                    .italic()
                    .foregroundStyle(Theme.Colors.inkSecondary)
                    .padding(.top, Theme.Spacing.xs)
            }
        }
        .softCard(padding: Theme.Spacing.lg, raised: true)
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if let prompt {
                Text(prompt.eyebrow).eyebrowStyle()
                Text(prompt.question)
                    .font(.title3Serif)
                    .foregroundStyle(Theme.Colors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        router.capture(.write, prompt: prompt.question)
                    } label: {
                        Label("Write about this", systemImage: "pencil.line")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .accessibilityIdentifier("today.prompt.write")
                    Button {
                        router.capture(.voice, prompt: prompt.question)
                    } label: {
                        Label("Say it", systemImage: "mic")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                }
                .padding(.top, 4)
            }
        }
        .softCard(padding: Theme.Spacing.lg)
    }

    private func noticedSection(_ insight: Insight) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeading(eyebrow: "Something I've noticed", title: insight.title) {
                NavigationLink(value: AppScreen.insights) {
                    Text("All")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.Colors.accent)
                }
                .accessibilityLabel("All observations")
            }
            NavigationLink(value: insight) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(insight.body)
                        .font(.bodySerif)
                        .foregroundStyle(Theme.Colors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        Image(systemName: insight.kind.systemImage).font(.caption)
                        Text(insight.relatedEntries.isEmpty ? insight.confidence.label : "Based on \(insight.relatedEntries.count) moment\(insight.relatedEntries.count == 1 ? "" : "s")")
                            .font(.caption)
                    }
                    .foregroundStyle(Theme.Colors.inkTertiary)
                }
                .softCard()
            }
            .buttonStyle(.plain)
        }
    }

    private var memoryWorthKeeping: JournalEntry? {
        let kept = entries.filter { $0.isKept && !Calendar.current.isDateInToday($0.occurredAt) }
        guard !kept.isEmpty else { return nil }
        // Prefer a photo moment, and rotate daily so the same memory doesn't sit there forever.
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        let withPhotos = kept.filter { !$0.attachments.isEmpty }
        let pool = withPhotos.isEmpty ? kept : withPhotos
        return pool[day % pool.count]
    }

    private func memorySection(_ entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeading(eyebrow: "Worth remembering", title: DateFormatting.dayLabel(for: entry.occurredAt)) {
                NavigationLink(value: AppScreen.keptMoments) {
                    Text("All")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.Colors.accent)
                }
                .accessibilityLabel("All moments worth remembering")
            }
            NavigationLink(value: entry) {
                MemoryHeroCard(entry: entry)
            }
            .buttonStyle(.plain)
        }
    }

    private func companionSection(_ starter: ConversationStarter) -> some View {
        NavigationLink(value: ConversationStart(entryID: starter.focusEntryID, openingMessage: starter.openingMessage.isEmpty ? nil : starter.openingMessage, title: starter.title)) {
            HStack(spacing: Theme.Spacing.md) {
                CompanionMark(size: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(starter.title)
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.ink)
                    if let detail = starter.detail {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.inkSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Colors.inkTertiary)
            }
            .softCard()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens a conversation with your companion")
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeading(eyebrow: "Recently", title: "Your latest moments") {
                Button("Journal") { router.selectedTab = .journal }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.Colors.accent)
            }
            ForEach(recent) { entry in
                NavigationLink(value: entry) {
                    MomentCard(entry: entry, showsDay: true, compact: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func refreshPrompt() {
        let context = services.companionContext()
        prompt = services.companion.todayPrompt(context: context)
        starter = services.companion.starters(context: context).first
    }
}

private struct InvitationRow: View {
    var title: String
    var detail: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(Theme.Colors.ink)
                    Text(detail).font(.subheadline).foregroundStyle(Theme.Colors.inkSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.Colors.inkTertiary)
            }
            .padding(Theme.Spacing.sm)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).fill(Theme.Colors.surface))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A large, photo-led card for a single meaningful moment.
struct MemoryHeroCard: View {
    let entry: JournalEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let cover = entry.coverAttachment {
                LocalPhoto(fileName: cover.fileName, targetPixelSize: 1200)
                    .frame(height: 260)
                LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 4) {
                    if let place = entry.placeName {
                        Text(place.uppercased())
                            .font(.caption.weight(.semibold))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Text(entry.displayTitle)
                        .font(.title3Serif)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                .padding(Theme.Spacing.md)
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    if let place = entry.placeName {
                        Text(place).eyebrowStyle()
                    }
                    Text(entry.trimmedText.isEmpty ? entry.displayTitle : entry.trimmedText)
                        .font(.title3Serif)
                        .foregroundStyle(Theme.Colors.ink)
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                    if let feeling = entry.feeling {
                        HStack(spacing: 6) {
                            FeelingMark(feeling: feeling, size: 8)
                            Text("Felt \(feeling.label.lowercased())").font(.caption).foregroundStyle(Theme.Colors.inkTertiary)
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.surface)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Worth remembering: \(entry.displayTitle), \(DateFormatting.dayLabel(for: entry.occurredAt))")
    }
}

/// The person's avatar: their photo if they've added one, otherwise their initials.
struct ProfileAvatar: View {
    let profile: UserProfile?
    var size: CGFloat = 44

    var body: some View {
        if let fileName = profile?.avatarFileName {
            LocalPhoto(fileName: fileName, targetPixelSize: 200)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            InitialAvatar(name: profile?.name ?? "", size: size)
        }
    }
}
