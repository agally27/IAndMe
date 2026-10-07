import SwiftUI
import SwiftData

/// The meaningful, not the merely chronological: kept moments, collections, people, places, photos, days.
struct MemoriesView: View {
    @Environment(AppRouter.self) private var router
    @Query(sort: \JournalEntry.occurredAt, order: .reverse) private var entries: [JournalEntry]
    @Query(sort: \MemoryCollection.sortOrder) private var collections: [MemoryCollection]
    @Query(sort: \MemoryConcept.mentionCount, order: .reverse) private var concepts: [MemoryConcept]

    private var kept: [JournalEntry] { entries.filter(\.isKept) }
    private var people: [MemoryConcept] { concepts.filter { $0.kind == .person && !$0.isForgotten && !$0.entries.isEmpty } }
    private var places: [MemoryConcept] { concepts.filter { $0.kind == .place && !$0.isForgotten && !$0.entries.isEmpty } }
    private var photoEntries: [JournalEntry] { entries.filter { !$0.attachments.isEmpty } }
    private var importantDates: [MemoryConcept] {
        concepts.filter { $0.kind == .importantDate && !$0.isForgotten }
            .sorted { ($0.daysUntilNextOccurrence() ?? Int.max) < ($1.daysUntilNextOccurrence() ?? Int.max) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    header
                    if entries.isEmpty {
                        GentleEmptyState(
                            title: "Your memories will begin here",
                            message: "As you capture moments, the ones worth keeping, the people, the places and the photos gather here.",
                            systemImage: "sparkles",
                            actionTitle: "Capture a moment"
                        ) { router.capture(.write) }
                    } else {
                        if !kept.isEmpty { keptSection }
                        if !collections.isEmpty { collectionsSection }
                        if !people.isEmpty { peopleSection }
                        if !places.isEmpty { placesSection }
                        if !photoEntries.isEmpty { photosSection }
                        if !importantDates.isEmpty { datesSection }
                        if kept.isEmpty && collections.isEmpty && people.isEmpty && places.isEmpty && photoEntries.isEmpty {
                            Text("Mark a moment as worth remembering, add a photo, or mention a person or place, and it will appear here.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.Colors.inkSecondary)
                        }
                    }
                }
                .pageHorizontalPadding()
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .background(CanvasBackground())
            .navigationBarTitleDisplayMode(.inline)
            .appDestinations()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Memories")
                .font(.displaySerif)
                .foregroundStyle(Theme.Colors.ink)
            Text("Not everything. The parts worth keeping.")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.inkSecondary)
        }
        .padding(.top, Theme.Spacing.xs)
    }

    private var keptSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeading(eyebrow: "Worth remembering", title: kept.count == 1 ? "One moment you kept" : "\(kept.count) moments you kept") {
                NavigationLink(value: AppScreen.keptMoments) {
                    Text("All").font(.subheadline.weight(.medium)).foregroundStyle(Theme.Colors.accent)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(kept.prefix(8)) { entry in
                        NavigationLink(value: entry) {
                            KeptTile(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeading(eyebrow: "Collections", title: "Moments that belong together")
            ForEach(collections) { collection in
                NavigationLink(value: collection) {
                    CollectionCard(collection: collection)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeading(eyebrow: "People", title: "Who appears in your moments") {
                NavigationLink(value: AppScreen.concepts(.person)) {
                    Text("All").font(.subheadline.weight(.medium)).foregroundStyle(Theme.Colors.accent)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(people.prefix(8)) { person in
                        NavigationLink(value: person) {
                            VStack(spacing: 6) {
                                InitialAvatar(name: person.name, size: 60)
                                Text(person.name).font(.subheadline.weight(.medium)).foregroundStyle(Theme.Colors.ink).lineLimit(1)
                                Text("\(person.entries.count)").font(.caption).foregroundStyle(Theme.Colors.inkTertiary)
                            }
                            .frame(width: 76)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(person.name), in \(person.entries.count) moments")
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private var placesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeading(eyebrow: "Places", title: "Where life has been happening") {
                NavigationLink(value: AppScreen.concepts(.place)) {
                    Text("All").font(.subheadline.weight(.medium)).foregroundStyle(Theme.Colors.accent)
                }
            }
            VStack(spacing: 0) {
                ForEach(places.prefix(5)) { place in
                    NavigationLink(value: place) {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "mappin.and.ellipse").foregroundStyle(Theme.Colors.accent).frame(width: 24)
                            Text(place.name).font(.body).foregroundStyle(Theme.Colors.ink)
                            Spacer()
                            Text("\(place.entries.count) moment\(place.entries.count == 1 ? "" : "s")").font(.caption).foregroundStyle(Theme.Colors.inkTertiary)
                            Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(Theme.Colors.inkTertiary)
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if place.id != places.prefix(5).last?.id { Hairline() }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).fill(Theme.Colors.surface))
        }
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeading(eyebrow: "Photos", title: "Visual memories") {
                NavigationLink(value: AppScreen.photos) {
                    Text("All").font(.subheadline.weight(.medium)).foregroundStyle(Theme.Colors.accent)
                }
            }
            let columns = [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)]
            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(photoEntries.prefix(6)) { entry in
                    if let cover = entry.coverAttachment {
                        NavigationLink(value: entry) {
                            LocalPhoto(fileName: cover.fileName, targetPixelSize: 400)
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Photo from \(DateFormatting.dayLabel(for: entry.occurredAt))")
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }
    }

    private var datesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeading(eyebrow: "Important days", title: "Days that matter")
            VStack(spacing: 0) {
                ForEach(importantDates.prefix(5)) { date in
                    NavigationLink(value: date) {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "calendar").foregroundStyle(Theme.Colors.accent).frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(date.name).font(.body).foregroundStyle(Theme.Colors.ink)
                                if let anchor = date.anchorDate {
                                    Text(anchor.formatted(.dateTime.day().month(.wide))).font(.caption).foregroundStyle(Theme.Colors.inkTertiary)
                                }
                            }
                            Spacer()
                            if let days = date.daysUntilNextOccurrence() {
                                Text(days == 0 ? "Today" : days == 1 ? "Tomorrow" : days > 0 ? "In \(days) days" : "\(-days) days ago")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(days >= 0 && days <= 7 ? Theme.Colors.accent : Theme.Colors.inkTertiary)
                            }
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if date.id != importantDates.prefix(5).last?.id { Hairline() }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).fill(Theme.Colors.surface))
        }
    }
}

/// A tall tile for a kept moment: photo-led when possible, words otherwise.
struct KeptTile: View {
    let entry: JournalEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let cover = entry.coverAttachment {
                LocalPhoto(fileName: cover.fileName, targetPixelSize: 700)
                    .frame(width: 170, height: 220)
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                    .frame(width: 170, height: 220)
                VStack(alignment: .leading, spacing: 3) {
                    Text(DateFormatting.dayLabel(for: entry.occurredAt).uppercased())
                        .font(.caption2.weight(.semibold)).tracking(0.8)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(entry.displayTitle)
                        .font(.headlineSerif)
                        .foregroundStyle(.white)
                        .lineLimit(3)
                }
                .padding(Theme.Spacing.sm)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(DateFormatting.dayLabel(for: entry.occurredAt).uppercased())
                        .font(.caption2.weight(.semibold)).tracking(0.8)
                        .foregroundStyle(Theme.Colors.inkTertiary)
                    Text(entry.trimmedText.isEmpty ? entry.displayTitle : entry.trimmedText)
                        .font(.calloutSerif)
                        .foregroundStyle(Theme.Colors.ink)
                        .lineLimit(7)
                    Spacer(minLength: 0)
                    if let feeling = entry.feeling { FeelingMark(feeling: feeling, size: 8) }
                }
                .padding(Theme.Spacing.sm)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Theme.Colors.surface)
            }
        }
        .frame(width: 170, height: 220)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.displayTitle), \(DateFormatting.dayLabel(for: entry.occurredAt))")
    }
}

struct CollectionCard: View {
    let collection: MemoryCollection

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            if let cover = collection.resolvedCoverFileName {
                LocalPhoto(fileName: cover, targetPixelSize: 400)
                    .frame(width: 86, height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous).fill(Theme.Colors.surfaceStrong)
                    Image(systemName: "square.stack").foregroundStyle(Theme.Colors.inkSecondary)
                }
                .frame(width: 86, height: 86)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(collection.kind.label.uppercased()).font(.caption2.weight(.semibold)).tracking(0.8).foregroundStyle(Theme.Colors.inkTertiary)
                Text(collection.title).font(.headlineSerif).foregroundStyle(Theme.Colors.ink).lineLimit(2)
                if let summary = collection.summary {
                    Text(summary).font(.subheadline).foregroundStyle(Theme.Colors.inkSecondary).lineLimit(2)
                }
                Text("\(collection.entries.count) moment\(collection.entries.count == 1 ? "" : "s")" + (collection.dateRange.flatMap { DateFormatting.periodLabel(from: $0.lowerBound, to: $0.upperBound) }.map { " · \($0)" } ?? ""))
                    .font(.caption).foregroundStyle(Theme.Colors.inkTertiary)
            }
            Spacer(minLength: 0)
        }
        .softCard(padding: Theme.Spacing.sm)
        .accessibilityElement(children: .combine)
    }
}

struct KeptMomentsView: View {
    @Query(sort: \JournalEntry.occurredAt, order: .reverse) private var entries: [JournalEntry]
    private var kept: [JournalEntry] { entries.filter(\.isKept) }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.sm) {
                if kept.isEmpty {
                    GentleEmptyState(title: "Nothing kept yet", message: "Tap the bookmark on any moment to keep it close.", systemImage: "bookmark")
                }
                ForEach(kept) { entry in
                    NavigationLink(value: entry) { MomentCard(entry: entry, showsDay: true) }.buttonStyle(.plain)
                }
            }
            .pageHorizontalPadding()
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(CanvasBackground())
        .navigationTitle("Worth remembering")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PhotosGridView: View {
    @Query(sort: \JournalEntry.occurredAt, order: .reverse) private var entries: [JournalEntry]

    private var items: [(entry: JournalEntry, attachment: MediaAttachment)] {
        entries.flatMap { entry in entry.sortedAttachments.map { (entry, $0) } }
    }

    var body: some View {
        ScrollView {
            let columns = [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)]
            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(items, id: \.attachment.id) { item in
                    NavigationLink(value: item.entry) {
                        LocalPhoto(fileName: item.attachment.fileName, targetPixelSize: 400)
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Photo from \(DateFormatting.dayLabel(for: item.entry.occurredAt))")
                }
            }
            .padding(.horizontal, 3)
        }
        .background(CanvasBackground())
        .navigationTitle("Photos")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CollectionDetailView: View {
    let collection: MemoryCollection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                if let cover = collection.resolvedCoverFileName {
                    LocalPhoto(fileName: cover, targetPixelSize: 1400)
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                        .padding(.horizontal, Theme.Spacing.sm)
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(collection.kind.label).eyebrowStyle()
                        Text(collection.title).font(.titleSerif).foregroundStyle(Theme.Colors.ink)
                        if let summary = collection.summary {
                            Text(summary).font(.bodySerif).foregroundStyle(Theme.Colors.inkSecondary).fixedSize(horizontal: false, vertical: true)
                        }
                        if let range = collection.dateRange, let label = DateFormatting.periodLabel(from: range.lowerBound, to: range.upperBound) {
                            Text(label).font(.caption).foregroundStyle(Theme.Colors.inkTertiary)
                        }
                    }
                    ForEach(collection.sortedEntries) { entry in
                        NavigationLink(value: entry) { MomentCard(entry: entry, showsDay: true) }.buttonStyle(.plain)
                    }
                }
                .pageHorizontalPadding()
            }
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(CanvasBackground())
        .navigationBarTitleDisplayMode(.inline)
    }
}
