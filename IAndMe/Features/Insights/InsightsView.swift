import SwiftUI
import SwiftData

/// Observations, not analytics. Grouped by the kind of thing noticed, each traceable to real moments.
struct InsightsView: View {
    @Environment(AppServices.self) private var services
    @Query(sort: \Insight.updatedAt, order: .reverse) private var insights: [Insight]
    @Query private var entries: [JournalEntry]
    @State private var isRefreshing = false

    private var active: [Insight] { insights.filter { !$0.isDismissed } }

    private var sections: [(kind: InsightKind, items: [Insight])] {
        InsightKind.allCases.compactMap { kind in
            let items = active.filter { $0.kind == kind }
            return items.isEmpty ? nil : (kind, items)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Noticed").eyebrowStyle()
                    Text("What I've noticed")
                        .font(.displaySerif)
                        .foregroundStyle(Theme.Colors.ink)
                    Text("Patterns in your moments, offered carefully. I may be wrong — you'd know better than I would.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if active.isEmpty {
                    GentleEmptyState(
                        title: entries.count < 3 ? "Nothing to notice yet" : "Nothing stands out yet",
                        message: entries.count < 3 ? "After a few more moments, patterns start to show: what lifts you, what keeps returning, who matters." : "Keep capturing. Patterns need a little time.",
                        systemImage: "eye"
                    )
                } else {
                    ForEach(sections, id: \.kind) { section in
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Label(section.kind.sectionTitle, systemImage: section.kind.systemImage)
                                .eyebrowStyle()
                            ForEach(section.items) { insight in
                                NavigationLink(value: insight) {
                                    InsightCard(insight: insight)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .pageHorizontalPadding()
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(CanvasBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isRefreshing = true
                    services.refreshInsights()
                    isRefreshing = false
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Look again")
            }
        }
    }
}

struct InsightCard: View {
    let insight: Insight

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(insight.title)
                .font(.headlineSerif)
                .foregroundStyle(Theme.Colors.ink)
                .multilineTextAlignment(.leading)
            Text(insight.body)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.inkSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Text(insight.confidence.label)
                if !insight.relatedEntries.isEmpty {
                    Text("·")
                    Text("\(insight.relatedEntries.count) moment\(insight.relatedEntries.count == 1 ? "" : "s")")
                }
            }
            .font(.caption)
            .foregroundStyle(Theme.Colors.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard()
        .accessibilityElement(children: .combine)
    }
}

struct InsightDetailView: View {
    @Bindable var insight: Insight
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(insight.kind.sectionTitle, systemImage: insight.kind.systemImage).eyebrowStyle()
                    Text(insight.title)
                        .font(.titleSerif)
                        .foregroundStyle(Theme.Colors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(insight.body)
                        .font(.readingSerif)
                        .foregroundStyle(Theme.Colors.ink)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    if let label = DateFormatting.periodLabel(from: insight.periodStart, to: insight.periodEnd) {
                        Text("Looking at \(label.lowercased().hasPrefix("the") ? label : label)").font(.caption).foregroundStyle(Theme.Colors.inkTertiary)
                    }
                }
                HStack(spacing: Theme.Spacing.sm) {
                    NavigationLink(value: ConversationStart(openingMessage: "You noticed that \(insight.title.lowercasedFirst). Let's talk about it.", title: insight.title)) {
                        HStack(spacing: 8) {
                            CompanionMark(size: 22)
                            Text("Talk about this").font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(Theme.Colors.ink)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Theme.Colors.surfaceStrong))
                    }
                    .buttonStyle(.plain)
                    Button {
                        insight.isDismissed = true
                        try? services.repository.save()
                        dismiss()
                    } label: {
                        Text("That's not right")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.Colors.inkSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Hides this observation")
                }
                if !insight.relatedConcepts.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(insight.relatedConcepts) { concept in
                            NavigationLink(value: concept) { Chip(title: concept.name, systemImage: concept.kind.systemImage) }.buttonStyle(.plain)
                        }
                    }
                }
                if !insight.sortedEntries.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        SectionHeading(eyebrow: "Based on", title: "\(insight.sortedEntries.count) moment\(insight.sortedEntries.count == 1 ? "" : "s")")
                        ForEach(insight.sortedEntries) { entry in
                            NavigationLink(value: entry) { MomentCard(entry: entry, showsDay: true, compact: true) }.buttonStyle(.plain)
                        }
                    }
                }
                HStack(spacing: 6) {
                    Image(systemName: "info.circle").font(.caption)
                    Text(insight.source == .sample ? "From the sample life" : "Worked out on this phone from your moments. Nothing was sent anywhere.")
                }
                .font(.caption)
                .foregroundStyle(Theme.Colors.inkTertiary)
            }
            .pageHorizontalPadding()
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(CanvasBackground())
        .navigationBarTitleDisplayMode(.inline)
    }
}
