import SwiftUI
import SwiftData

/// A single moment, shown with room to breathe, and a clear way to talk it through.
struct EntryDetailView: View {
    @Bindable var entry: JournalEntry

    @Environment(AppServices.self) private var services
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.motion) private var motion
    @State private var showDeleteConfirmation = false
    @State private var viewerAttachment: MediaAttachment?
    @State private var player = AudioPlayer()
    @State private var related: [JournalEntry] = []

    private var linkedConcepts: [MemoryConcept] {
        entry.concepts.filter { !$0.isForgotten }.sorted { $0.kind.rawValue < $1.kind.rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                if !entry.sortedAttachments.isEmpty {
                    photos
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    dateline
                    if !entry.trimmedText.isEmpty {
                        Text(entry.trimmedText)
                            .font(.readingSerif)
                            .foregroundStyle(Theme.Colors.ink)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                            .accessibilityIdentifier("entry.text")
                    }
                    ForEach(entry.sortedRecordings) { recording in
                        RecordingPlayerView(recording: recording, player: player)
                    }
                    if !linkedConcepts.isEmpty {
                        conceptRow
                    }
                    talkButton
                    if !related.isEmpty {
                        relatedSection
                    }
                }
                .pageHorizontalPadding()
            }
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(CanvasBackground())
        .navigationTitle(DateFormatting.dayLabel(for: entry.occurredAt))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(motion.spring) { entry.isKept.toggle() }
                    try? services.repository.save()
                } label: {
                    Image(systemName: entry.isKept ? "bookmark.fill" : "bookmark")
                        .symbolEffect(.bounce, value: entry.isKept)
                }
                .accessibilityLabel(entry.isKept ? "Worth remembering. Tap to unmark" : "Mark as worth remembering")
                .accessibilityIdentifier("entry.keep")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { router.edit(entry) } label: { Label("Edit or add to this moment", systemImage: "pencil") }
                    Divider()
                    Button(role: .destructive) { showDeleteConfirmation = true } label: { Label("Delete moment", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("More")
                .accessibilityIdentifier("entry.more")
            }
        }
        .confirmationDialog("Delete this moment?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete moment", role: .destructive) { delete() }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("The words, photos and recordings in it will be removed from this phone. This can't be undone.")
        }
        .fullScreenCover(item: $viewerAttachment) { attachment in
            PhotoViewer(attachments: entry.sortedAttachments, selected: attachment)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: entry.isKept)
        .task(id: entry.updatedAt) { loadRelated() }
        .onDisappear { player.stop() }
    }

    // MARK: Pieces

    private var photos: some View {
        TabView {
            ForEach(entry.sortedAttachments) { attachment in
                LocalPhoto(fileName: attachment.fileName, targetPixelSize: 1600)
                    .frame(height: 340)
                    .onTapGesture { viewerAttachment = attachment }
                    .accessibilityLabel("Photo")
                    .accessibilityHint("Opens full screen")
                    .accessibilityAddTraits(.isButton)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: entry.attachments.count > 1 ? .automatic : .never))
        .frame(height: 340)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .padding(.horizontal, Theme.Spacing.sm)
    }

    private var dateline: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(entry.occurredAt.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                Text("·")
                Text(DateFormatting.timeLabel(for: entry.occurredAt))
            }
            .eyebrowStyle()
            HStack(spacing: Theme.Spacing.sm) {
                if let feeling = entry.feeling {
                    HStack(spacing: 6) {
                        FeelingMark(feeling: feeling, size: 9)
                        Text("Felt \(feeling.label.lowercased())")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.Colors.inkSecondary)
                }
                if let place = entry.placeName {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse").font(.caption)
                        Text(place)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.Colors.inkSecondary)
                }
                if entry.isSample {
                    Text("Sample")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.Colors.surfaceStrong))
                        .foregroundStyle(Theme.Colors.inkTertiary)
                        .accessibilityLabel("Part of the sample life")
                }
            }
        }
        .padding(.top, entry.attachments.isEmpty ? Theme.Spacing.xs : 0)
    }

    private var conceptRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("About").eyebrowStyle()
            FlowLayout(spacing: 8) {
                ForEach(linkedConcepts) { concept in
                    NavigationLink(value: concept) {
                        Chip(title: concept.name, systemImage: concept.kind.systemImage)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var talkButton: some View {
        NavigationLink(value: ConversationStart(entryID: entry.id, title: "About \(DateFormatting.dayLabel(for: entry.occurredAt).lowercased())")) {
            HStack(spacing: Theme.Spacing.md) {
                CompanionMark(size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Talk about this")
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.ink)
                    Text("Think it through with your companion")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Colors.inkTertiary)
            }
            .softCard()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("entry.talk")
    }

    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeading(eyebrow: "Connected", title: "Moments that share something")
            ForEach(related) { other in
                NavigationLink(value: other) {
                    MomentReference(entry: other)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func loadRelated() {
        let names = Set(linkedConcepts.map(\.name))
        guard !names.isEmpty else { related = []; return }
        related = services.repository.allEntries()
            .filter { $0.id != entry.id && !Set($0.concepts.map(\.name)).isDisjoint(with: names) }
            .sorted { abs($0.occurredAt.timeIntervalSince(entry.occurredAt)) < abs($1.occurredAt.timeIntervalSince(entry.occurredAt)) }
            .prefix(3)
            .map { $0 }
    }

    private func delete() {
        player.stop()
        try? services.repository.delete(entry)
        services.refreshInsights()
        dismiss()
    }
}

/// Plays a voice moment and offers on-device transcription.
struct RecordingPlayerView: View {
    let recording: VoiceRecording
    let player: AudioPlayer

    @Environment(AppServices.self) private var services
    @State private var isTranscribing = false
    @State private var transcriptionMessage: String?

    private var url: URL { services.media.audioURL(named: recording.fileName) }
    private var fileExists: Bool { services.media.audioExists(named: recording.fileName) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    player.toggle(url: url)
                } label: {
                    Image(systemName: player.isPlaying(url) ? "pause.fill" : "play.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.Colors.canvasRaised)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(fileExists ? Theme.Colors.accent : Theme.Colors.inkTertiary))
                }
                .buttonStyle(.plain)
                .disabled(!fileExists)
                .accessibilityLabel(player.isPlaying(url) ? "Pause" : "Play voice recording, \(DurationFormatting.spoken(recording.duration))")
                WaveformView(levels: recording.waveform, progress: player.currentURL == url ? player.progress : 0)
                    .frame(height: 36)
                Text(player.currentURL == url && player.isPlaying ? DurationFormatting.short(player.currentTime) : recording.formattedDuration)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.Colors.inkSecondary)
                    .frame(minWidth: 36, alignment: .trailing)
            }
            if !fileExists {
                Text("This recording's audio is still being prepared.")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.inkTertiary)
            }
            if let transcript = recording.transcript {
                Text(transcript)
                    .font(.bodySerif)
                    .foregroundStyle(Theme.Colors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, Theme.Spacing.sm)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Theme.Colors.accent.opacity(0.5)).frame(width: 2)
                    }
                    .textSelection(.enabled)
            } else if fileExists {
                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        transcribe()
                    } label: {
                        if isTranscribing {
                            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Transcribing on this phone…") }
                        } else {
                            Label("Transcribe", systemImage: "text.quote")
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .disabled(isTranscribing)
                    .accessibilityHint("Turns the recording into text, on this phone only")
                    if let transcriptionMessage {
                        Text(transcriptionMessage)
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.inkTertiary)
                    }
                }
            }
            if let error = player.errorMessage, player.currentURL == url {
                Text(error).font(.caption).foregroundStyle(Theme.Colors.inkTertiary)
            }
        }
        .padding(Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).fill(Theme.Colors.surface))
    }

    private func transcribe() {
        isTranscribing = true
        transcriptionMessage = nil
        recording.transcriptionState = .inProgress
        Task {
            do {
                let text = try await services.transcription.transcribe(audioAt: url)
                recording.transcript = text
                recording.transcriptionState = .done
                try? services.repository.save()
                if let entry = recording.entry { services.process(entry) }
            } catch {
                recording.transcriptionState = .failed
                transcriptionMessage = (error as? LocalizedError)?.errorDescription ?? "Transcription isn't available right now."
            }
            isTranscribing = false
        }
    }
}

/// Full-screen, zoomable photo viewing.
struct PhotoViewer: View {
    let attachments: [MediaAttachment]
    @State var selected: MediaAttachment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $selected) {
                ForEach(attachments) { attachment in
                    ZoomableImage(fileName: attachment.fileName)
                        .tag(attachment)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: attachments.count > 1 ? .automatic : .never))
            .ignoresSafeArea()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.white.opacity(0.18)))
            }
            .buttonStyle(.plain)
            .padding()
            .accessibilityLabel("Close")
        }
    }
}

private struct ZoomableImage: View {
    let fileName: String
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        LocalPhoto(fileName: fileName, targetPixelSize: nil, contentMode: .fit)
            .scaleEffect(scale)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in scale = max(1, min(4, lastScale * value.magnification)) }
                    .onEnded { _ in lastScale = scale }
            )
            .onTapGesture(count: 2) {
                withAnimation(.snappy) {
                    scale = scale > 1 ? 1 : 2
                    lastScale = scale
                }
            }
            .accessibilityLabel("Photo, full screen")
    }
}

/// Wraps chips onto multiple lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
