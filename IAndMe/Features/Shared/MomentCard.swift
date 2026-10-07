import SwiftUI

/// The standard way a moment appears in lists: time, feeling, words, and any photos or voice.
struct MomentCard: View {
    let entry: JournalEntry
    var showsDay = false
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 8) {
                if let feeling = entry.feeling {
                    FeelingMark(feeling: feeling, size: 8)
                }
                Text(showsDay ? "\(DateFormatting.dayLabel(for: entry.occurredAt)) · \(DateFormatting.timeLabel(for: entry.occurredAt))" : DateFormatting.timeLabel(for: entry.occurredAt))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.Colors.inkTertiary)
                if let place = entry.placeName {
                    Text("·").foregroundStyle(Theme.Colors.inkTertiary).font(.caption)
                    Text(place)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.Colors.inkTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if entry.isKept {
                    Image(systemName: "bookmark.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.accent)
                        .accessibilityLabel("Worth remembering")
                }
            }

            if !entry.sortedAttachments.isEmpty && !compact {
                PhotoCollage(attachments: entry.sortedAttachments)
                    .frame(height: entry.sortedAttachments.count == 1 ? (entry.sortedAttachments[0].isPortrait ? 300 : 210) : 200)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            }

            if !entry.trimmedText.isEmpty {
                Text(entry.trimmedText)
                    .font(.bodySerif)
                    .foregroundStyle(Theme.Colors.ink)
                    .lineLimit(compact ? 3 : 6)
                    .fixedSize(horizontal: false, vertical: true)
            } else if entry.recordings.isEmpty && entry.attachments.isEmpty {
                Text("An empty moment")
                    .font(.bodySerif)
                    .foregroundStyle(Theme.Colors.inkTertiary)
            }

            if !entry.recordings.isEmpty {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(entry.sortedRecordings) { recording in
                        VoiceChip(recording: recording)
                    }
                }
            }

            if compact, let first = entry.sortedAttachments.first {
                HStack(spacing: 6) {
                    Image(systemName: "photo").font(.caption)
                    Text(entry.attachments.count == 1 ? "1 photo" : "\(entry.attachments.count) photos").font(.caption)
                }
                .foregroundStyle(Theme.Colors.inkTertiary)
                .accessibilityHidden(first.fileName.isEmpty)
            }
        }
        .softCard(raised: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var parts = [DateFormatting.dayLabel(for: entry.occurredAt), DateFormatting.timeLabel(for: entry.occurredAt)]
        if let place = entry.placeName { parts.append(place) }
        if let feeling = entry.feeling { parts.append("felt \(feeling.label.lowercased())") }
        if !entry.attachments.isEmpty { parts.append("\(entry.attachments.count) photo\(entry.attachments.count == 1 ? "" : "s")") }
        if !entry.recordings.isEmpty { parts.append("\(entry.recordings.count) voice recording\(entry.recordings.count == 1 ? "" : "s")") }
        parts.append(entry.trimmedText.isEmpty ? entry.displayTitle : TextSnippets.snippet(of: entry.trimmedText, maxLength: 200))
        return parts.joined(separator: ", ")
    }
}

/// A small voice pill with the duration and a mini waveform.
struct VoiceChip: View {
    let recording: VoiceRecording

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.Colors.accent)
            WaveformView(levels: recording.waveform, barWidth: 2, spacing: 1.5, minHeight: 2)
                .frame(width: 54, height: 14)
            Text(recording.formattedDuration)
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundStyle(Theme.Colors.inkSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(Theme.Colors.surface))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Voice recording, \(DurationFormatting.spoken(recording.duration))")
    }
}

/// Lays out one to four photos the way a memory should look: large, edge to edge, no chrome.
struct PhotoCollage: View {
    let attachments: [MediaAttachment]

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let gap: CGFloat = 3
            switch attachments.count {
            case 0:
                Color.clear
            case 1:
                photo(attachments[0], w, h)
            case 2:
                HStack(spacing: gap) {
                    photo(attachments[0], (w - gap) / 2, h)
                    photo(attachments[1], (w - gap) / 2, h)
                }
            case 3:
                HStack(spacing: gap) {
                    photo(attachments[0], w * 0.6, h)
                    VStack(spacing: gap) {
                        photo(attachments[1], w * 0.4 - gap, (h - gap) / 2)
                        photo(attachments[2], w * 0.4 - gap, (h - gap) / 2)
                    }
                }
            default:
                HStack(spacing: gap) {
                    photo(attachments[0], w * 0.6, h)
                    VStack(spacing: gap) {
                        photo(attachments[1], w * 0.4 - gap, (h - gap) / 2)
                        ZStack {
                            photo(attachments[2], w * 0.4 - gap, (h - gap) / 2)
                            if attachments.count > 3 {
                                Color.black.opacity(0.35)
                                Text("+\(attachments.count - 3)")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: w * 0.4 - gap, height: (h - gap) / 2)
                        .clipped()
                    }
                }
            }
        }
        .accessibilityLabel(attachments.count == 1 ? "Photo" : "\(attachments.count) photos")
    }

    private func photo(_ attachment: MediaAttachment, _ width: CGFloat, _ height: CGFloat) -> some View {
        LocalPhoto(fileName: attachment.fileName, targetPixelSize: 900)
            .frame(width: max(0, width), height: max(0, height))
            .clipped()
    }
}

/// A compact link to a moment, used beneath companion messages and in insights.
struct MomentReference: View {
    let entry: JournalEntry

    var body: some View {
        HStack(spacing: 10) {
            if let cover = entry.coverAttachment {
                LocalPhoto(fileName: cover.fileName, targetPixelSize: 160)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.Colors.surfaceStrong)
                    Image(systemName: entry.kind.systemImage)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
                .frame(width: 40, height: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(DateFormatting.dayLabel(for: entry.occurredAt))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Colors.inkSecondary)
                Text(entry.displayTitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.ink)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.Colors.inkTertiary)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous).fill(Theme.Colors.surface))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Moment from \(DateFormatting.dayLabel(for: entry.occurredAt)): \(entry.displayTitle)")
    }
}

/// Shared destination for navigation links to a moment.
struct EntryDestination: Hashable {
    let id: UUID
}
