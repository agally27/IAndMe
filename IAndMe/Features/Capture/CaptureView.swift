import SwiftUI
import PhotosUI
import SwiftData

/// One place to capture anything: words, a feeling, photos, voice, a place, a time. The person
/// never chooses a "type" of entry — whatever they add decides what it is.
struct CaptureView: View {
    let request: CaptureRequest

    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @Environment(\.motion) private var motion

    @State private var text: String
    @State private var feeling: Feeling?
    @State private var occurredAt: Date
    @State private var placeName: String
    @State private var showPlaceField: Bool

    @State private var pendingImages: [PendingImage] = []
    @State private var pendingRecordings: [AudioRecorder.Result] = []
    @State private var removedAttachmentIDs: Set<UUID> = []
    @State private var removedRecordingIDs: Set<UUID> = []

    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var showRecorder = false
    @State private var showDatePicker = false
    @State private var showDiscardConfirmation = false
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var didAutoOpen = false
    @State private var player = AudioPlayer()
    @FocusState private var textFocused: Bool
    @FocusState private var placeFocused: Bool

    struct PendingImage: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    init(request: CaptureRequest) {
        self.request = request
        _text = State(initialValue: request.editing?.text ?? request.prefilledText)
        _feeling = State(initialValue: request.editing?.feeling)
        _occurredAt = State(initialValue: request.editing?.occurredAt ?? .now)
        _placeName = State(initialValue: request.editing?.placeName ?? "")
        _showPlaceField = State(initialValue: !(request.editing?.placeName ?? "").isEmpty)
    }

    private var isEditing: Bool { request.editing != nil }

    private var existingAttachments: [MediaAttachment] {
        (request.editing?.sortedAttachments ?? []).filter { !removedAttachmentIDs.contains($0.id) }
    }

    private var existingRecordings: [VoiceRecording] {
        (request.editing?.sortedRecordings ?? []).filter { !removedRecordingIDs.contains($0.id) }
    }

    private var hasContent: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !pendingImages.isEmpty || !pendingRecordings.isEmpty
            || !existingAttachments.isEmpty || !existingRecordings.isEmpty
    }

    private var hasChanges: Bool {
        guard let editing = request.editing else { return hasContent || feeling != nil }
        return text != editing.text || feeling != editing.feeling || occurredAt != editing.occurredAt
            || placeName.trimmingCharacters(in: .whitespaces) != (editing.placeName ?? "")
            || !pendingImages.isEmpty || !pendingRecordings.isEmpty
            || !removedAttachmentIDs.isEmpty || !removedRecordingIDs.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    if let prompt = request.prompt, !isEditing {
                        Text(prompt)
                            .font(.calloutSerif)
                            .italic()
                            .foregroundStyle(Theme.Colors.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    editor
                    if !existingAttachments.isEmpty || !pendingImages.isEmpty {
                        photoStrip
                    }
                    if !existingRecordings.isEmpty || !pendingRecordings.isEmpty {
                        recordingsList
                    }
                    FeelingPicker(feeling: $feeling)
                    placeRow
                }
                .padding(Theme.Spacing.page)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(CanvasBackground())
            .safeAreaInset(edge: .bottom) { toolbar }
            .navigationTitle(isEditing ? "Edit moment" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancel() }
                        .accessibilityIdentifier("capture.cancel")
                }
                ToolbarItem(placement: .principal) {
                    Button {
                        showDatePicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("\(DateFormatting.dayLabel(for: occurredAt)), \(DateFormatting.timeLabel(for: occurredAt))")
                            Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.Colors.inkSecondary)
                    }
                    .accessibilityLabel("When this happened: \(DateFormatting.dayLabel(for: occurredAt)), \(DateFormatting.timeLabel(for: occurredAt))")
                    .accessibilityHint("Change the date and time")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Done" : "Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!hasContent || isSaving || (isEditing && !hasChanges))
                        .accessibilityIdentifier("capture.save")
                }
            }
            .sheet(isPresented: $showDatePicker) { datePickerSheet }
            .sheet(isPresented: $showRecorder) {
                VoiceRecorderSheet { result in
                    withAnimation(motion.gentle) { pendingRecordings.append(result) }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    withAnimation(motion.gentle) { pendingImages.append(PendingImage(image: image)) }
                }
                .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoItems, maxSelectionCount: 6, matching: .images)
            .onChange(of: photoItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await loadPhotos(items) }
            }
            .confirmationDialog("Discard this moment?", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { discardAndDismiss() }
                Button("Keep editing", role: .cancel) {}
            }
            .alert("Couldn't save", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("OK") {}
            } message: {
                Text(saveError ?? "")
            }
            .interactiveDismissDisabled(hasChanges)
            .onAppear { autoOpen() }
            .onDisappear { player.stop() }
            .sensoryFeedback(.success, trigger: isSaving)
        }
        .presentationDragIndicator(.hidden)
    }

    // MARK: Pieces

    private var editor: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .font(.readingSerif)
            .foregroundStyle(Theme.Colors.ink)
            .lineLimit(4...)
            .focused($textFocused)
            .frame(minHeight: 120, alignment: .top)
            .accessibilityIdentifier("capture.text")
            .accessibilityLabel("Your moment")
    }

    private var placeholder: String {
        switch request.mode {
        case .voice: return "Add a few words, if you like"
        case .photo: return "What's happening in this photo?"
        case .write: return isEditing ? "" : "What's happening?"
        }
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(existingAttachments) { attachment in
                    thumbnail {
                        LocalPhoto(fileName: attachment.fileName, targetPixelSize: 300)
                    } remove: {
                        withAnimation(motion.gentle) { _ = removedAttachmentIDs.insert(attachment.id) }
                    }
                }
                ForEach(pendingImages) { pending in
                    thumbnail {
                        Image(uiImage: pending.image).resizable().aspectRatio(contentMode: .fill)
                    } remove: {
                        withAnimation(motion.gentle) { pendingImages.removeAll { $0.id == pending.id } }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }

    private func thumbnail<Content: View>(@ViewBuilder content: () -> Content, remove: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
            content()
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            Button(action: remove) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(.black.opacity(0.55)))
            }
            .buttonStyle(.plain)
            .padding(6)
            .accessibilityLabel("Remove photo")
        }
    }

    private var recordingsList: some View {
        VStack(spacing: Theme.Spacing.xs) {
            ForEach(existingRecordings) { recording in
                recordingRow(url: services.media.audioURL(named: recording.fileName), waveform: recording.waveform, duration: recording.duration) {
                    withAnimation(motion.gentle) { _ = removedRecordingIDs.insert(recording.id) }
                }
            }
            ForEach(pendingRecordings, id: \.fileName) { recording in
                recordingRow(url: recording.url, waveform: recording.waveform, duration: recording.duration) {
                    player.stop()
                    try? FileManager.default.removeItem(at: recording.url)
                    withAnimation(motion.gentle) { pendingRecordings.removeAll { $0.fileName == recording.fileName } }
                }
            }
        }
    }

    private func recordingRow(url: URL, waveform: [Float], duration: TimeInterval, remove: @escaping () -> Void) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button { player.toggle(url: url) } label: {
                Image(systemName: player.isPlaying(url) ? "pause.fill" : "play.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.canvasRaised)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.Colors.accent))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying(url) ? "Pause" : "Play recording")
            WaveformView(levels: waveform, progress: player.currentURL == url ? player.progress : 0)
                .frame(height: 28)
            Text(DurationFormatting.short(duration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.Colors.inkSecondary)
            Button(action: remove) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.Colors.inkSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove recording")
        }
        .padding(Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).fill(Theme.Colors.surface))
    }

    private var placeRow: some View {
        Group {
            if showPlaceField {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(Theme.Colors.accent)
                    TextField("Where were you?", text: $placeName)
                        .focused($placeFocused)
                        .submitLabel(.done)
                        .accessibilityIdentifier("capture.place")
                    if !placeName.isEmpty {
                        Button {
                            placeName = ""
                            showPlaceField = false
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.Colors.inkTertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear place")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Capsule().fill(Theme.Colors.surface))
            } else {
                Button {
                    withAnimation(motion.quick) { showPlaceField = true }
                    placeFocused = true
                } label: {
                    Chip(title: "Add a place", systemImage: "mappin.and.ellipse")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ToolbarCircle(systemImage: "photo.on.rectangle", label: "Add photos") { showPhotoPicker = true }
                .accessibilityIdentifier("capture.addPhotos")
            if CameraPicker.isAvailable {
                ToolbarCircle(systemImage: "camera", label: "Take a photo") { showCamera = true }
            }
            ToolbarCircle(systemImage: "mic", label: "Record your voice") { showRecorder = true }
                .accessibilityIdentifier("capture.addVoice")
            Spacer()
            if textFocused {
                Button("Done") { textFocused = false }
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal, Theme.Spacing.page)
        .padding(.vertical, Theme.Spacing.xs)
        .background(.bar)
    }

    private var datePickerSheet: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.md) {
                Text("Moments can be placed when they happened, not just when you wrote them down.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.inkSecondary)
                    .padding(.horizontal, Theme.Spacing.page)
                DatePicker("When this happened", selection: $occurredAt, in: ...Date.now.adding(days: 1))
                    .datePickerStyle(.graphical)
                    .padding(.horizontal, Theme.Spacing.sm)
                Spacer()
            }
            .padding(.top, Theme.Spacing.sm)
            .background(CanvasBackground())
            .navigationTitle("When")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showDatePicker = false }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: Actions

    private func autoOpen() {
        guard !didAutoOpen else { return }
        didAutoOpen = true
        switch request.mode {
        case .write:
            if !isEditing { textFocused = true }
        case .voice, .photo:
            // Let this sheet finish presenting before presenting another on top of it; an
            // immediate nested presentation can be dropped by the system.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                if request.mode == .voice { showRecorder = true } else { showPhotoPicker = true }
            }
        }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        var loaded: [PendingImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                loaded.append(PendingImage(image: image))
            }
        }
        let images = loaded
        await MainActor.run {
            withAnimation(motion.gentle) { pendingImages.append(contentsOf: images) }
            photoItems = []
            if request.mode == .photo && text.isEmpty { textFocused = true }
        }
    }

    private func cancel() {
        if hasChanges && (hasContent || !pendingRecordings.isEmpty) {
            showDiscardConfirmation = true
        } else {
            discardAndDismiss()
        }
    }

    private func discardAndDismiss() {
        player.stop()
        for recording in pendingRecordings {
            try? FileManager.default.removeItem(at: recording.url)
        }
        dismiss()
    }

    private func save() {
        guard hasContent, !isSaving else { return }
        isSaving = true
        player.stop()
        do {
            let repository = services.repository
            let entry: JournalEntry
            let trimmedPlace = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
            if let editing = request.editing {
                entry = editing
                entry.text = text
                entry.feeling = feeling
                entry.occurredAt = occurredAt
                entry.placeName = trimmedPlace.isEmpty ? nil : trimmedPlace
                entry.updatedAt = .now
                for attachment in editing.attachments where removedAttachmentIDs.contains(attachment.id) {
                    try repository.removeAttachment(attachment)
                }
                for recording in editing.recordings where removedRecordingIDs.contains(recording.id) {
                    try repository.removeRecording(recording)
                }
            } else {
                entry = try repository.createEntry(text: text, occurredAt: occurredAt, feeling: feeling, placeName: trimmedPlace.isEmpty ? nil : trimmedPlace)
            }
            for pending in pendingImages {
                try repository.addPhoto(pending.image, to: entry)
            }
            for recording in pendingRecordings {
                try repository.addRecording(fileName: recording.fileName, duration: recording.duration, waveform: recording.waveform, to: entry)
            }
            try repository.save()
            services.process(entry)
            dismiss()
        } catch {
            isSaving = false
            saveError = error.localizedDescription
        }
    }
}

private struct ToolbarCircle: View {
    var systemImage: String
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.Colors.ink)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.Colors.surfaceStrong))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
