import SwiftUI
import SwiftData

/// The chronological journal: life unfolding, newest first, grouped by day and month.
struct JournalView: View {
    @Environment(AppRouter.self) private var router
    @Query(sort: \JournalEntry.occurredAt, order: .reverse) private var entries: [JournalEntry]
    @State private var searchText = ""
    @State private var keptOnly = false

    private var filtered: [JournalEntry] {
        var result = entries
        if keptOnly { result = result.filter(\.isKept) }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter { $0.searchableText.localizedCaseInsensitiveContains(query) }
        }
        return result
    }

    private struct MonthGroup: Identifiable {
        let id: Date
        let label: String
        let days: [DayGroup]
    }

    private struct DayGroup: Identifiable {
        let id: Date
        let label: String
        let entries: [JournalEntry]
    }

    private var groups: [MonthGroup] {
        let calendar = Calendar.current
        let byMonth = Dictionary(grouping: filtered) { entry -> Date in
            let comps = calendar.dateComponents([.year, .month], from: entry.occurredAt)
            return calendar.date(from: comps) ?? entry.occurredAt
        }
        return byMonth.keys.sorted(by: >).map { month in
            let monthEntries = byMonth[month] ?? []
            let byDay = Dictionary(grouping: monthEntries) { calendar.startOfDay(for: $0.occurredAt) }
            let days = byDay.keys.sorted(by: >).map { day in
                DayGroup(id: day, label: DateFormatting.dayLabel(for: day), entries: (byDay[day] ?? []).sorted { $0.occurredAt > $1.occurredAt })
            }
            return MonthGroup(id: month, label: DateFormatting.monthLabel(for: month), days: days)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    emptyJournal
                } else if filtered.isEmpty {
                    GentleEmptyState(
                        title: keptOnly && searchText.isEmpty ? "Nothing kept yet" : "Nothing matches",
                        message: keptOnly && searchText.isEmpty ? "Mark a moment as worth remembering and it will appear here." : "Try a different word, a place, or a name.",
                        systemImage: "magnifyingglass"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(CanvasBackground())
                } else {
                    timeline
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        keptOnly.toggle()
                    } label: {
                        Image(systemName: keptOnly ? "bookmark.fill" : "bookmark")
                    }
                    .accessibilityLabel(keptOnly ? "Showing moments worth remembering" : "Show only moments worth remembering")
                }
            }
            .searchable(text: $searchText, prompt: "Search your moments")
            .appDestinations()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Journal")
                .font(.displaySerif)
                .foregroundStyle(Theme.Colors.ink)
            Text(entries.count == 1 ? "One moment, so far." : "\(entries.count) moments, in the order life happened.")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.inkSecondary)
        }
        .padding(.top, Theme.Spacing.xs)
    }

    private var timeline: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg, pinnedViews: []) {
                header
                ForEach(groups) { month in
                    Text(month.label)
                        .font(.title2Serif)
                        .foregroundStyle(Theme.Colors.ink)
                        .padding(.top, Theme.Spacing.sm)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(month.days) { day in
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text(day.label)
                                .eyebrowStyle()
                                .accessibilityAddTraits(.isHeader)
                            ForEach(day.entries) { entry in
                                NavigationLink(value: entry) {
                                    MomentCard(entry: entry)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("journal.entry")
                            }
                        }
                    }
                }
            }
            .pageHorizontalPadding()
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(CanvasBackground())
        .accessibilityIdentifier("journal.list")
    }

    private var emptyJournal: some View {
        ScrollView {
            GentleEmptyState(
                title: "Your journal begins here",
                message: "Every moment you capture — a line, a photo, your voice — will gather here in the order life happened.",
                systemImage: "book.closed",
                actionTitle: "Capture a moment"
            ) {
                router.capture(.write)
            }
            .padding(.top, Theme.Spacing.xxl)
        }
        .background(CanvasBackground())
    }
}
