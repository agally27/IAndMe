import SwiftUI
import AVFoundation

/// Record, review, keep. One screen, no settings.
struct VoiceRecorderSheet: View {
    var onKeep: (AudioRecorder.Result) -> Void

    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @Environment(\.motion) private var motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var recorder: AudioRecorder?
    @State private var result: AudioRecorder.Result?
    @State private var player = AudioPlayer()
    @State private var pulse = false

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()
                VStack(spacing: Theme.Spacing.xl) {
                    Spacer(minLength: 0)
                    statusText
                    timer
                    waveform
                        .frame(height: 96)
                        .padding(.horizontal, Theme.Spacing.lg)
                    Spacer(minLength: 0)
                    controls
                        .padding(.bottom, Theme.Spacing.xl)
                }
                .padding(.horizontal, Theme.Spacing.page)
            }
            .navigationTitle("Voice moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { discardAndClose() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(recorder?.isActive ?? false)
        .task {
            if recorder == nil {
                let newRecorder = AudioRecorder(media: services.media, sampleInterval: services.isUITesting ? .milliseconds(500) : .milliseconds(50))
                recorder = newRecorder
                if AVAudioApplication.shared.recordPermission == .granted {
                    await newRecorder.start()
                }
            }
        }
        .onDisappear {
            player.stop()
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: recorder?.state == .recording)
        .sensoryFeedback(.success, trigger: result != nil)
    }

    // MARK: Pieces

    private var state: AudioRecorder.State { recorder?.state ?? .idle }

    /// Continuous animation is switched off for Reduce Motion and under UI testing, where it would
    /// stop the interface ever being "idle" for the test runner.
    private var animates: Bool { !reduceMotion && !services.isUITesting }

    @ViewBuilder
    private var statusText: some View {
        switch state {
        case .idle, .requestingPermission:
            Text("Say what's on your mind.\nIt stays on this phone.")
                .font(.title3Serif)
                .foregroundStyle(Theme.Colors.inkSecondary)
                .multilineTextAlignment(.center)
        case .preparing:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Getting the microphone ready…")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.Colors.inkSecondary)
            .accessibilityIdentifier("recorder.preparing")
        case .recording:
            Label("Recording", systemImage: "circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Colors.accent)
                .symbolEffect(.pulse, options: animates ? .repeating : .nonRepeating, isActive: animates)
        case .paused:
            Text("Paused")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Colors.inkSecondary)
        case .finished:
            Text("Listen back, then keep it or let it go.")
                .font(.title3Serif)
                .foregroundStyle(Theme.Colors.inkSecondary)
                .multilineTextAlignment(.center)
        case .denied:
            VStack(spacing: Theme.Spacing.sm) {
                Text("Microphone access is off")
                    .font(.title3Serif)
                    .foregroundStyle(Theme.Colors.ink)
                Text("Allow the microphone in Settings to record voice moments. Recordings never leave your phone.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.inkSecondary)
                    .multilineTextAlignment(.center)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: url)
                        .font(.subheadline.weight(.semibold))
                }
            }
        case .failed(let message):
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.inkSecondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("recorder.failed")
        }
    }

    private var timer: some View {
        let duration = result?.duration ?? recorder?.duration ?? 0
        let shown = state == .finished ? (player.isPlaying ? player.currentTime : duration) : duration
        return Text(DurationFormatting.short(shown))
            .font(.system(size: 56, weight: .light, design: .serif).monospacedDigit())
            .foregroundStyle(Theme.Colors.ink)
            .contentTransition(animates ? .numericText() : .identity)
            .accessibilityLabel("Duration \(DurationFormatting.spoken(shown))")
    }

    @ViewBuilder
    private var waveform: some View {
        switch state {
        case .recording, .paused:
            LiveWaveformView(levels: recorder?.liveLevels ?? [], animates: animates)
        case .finished:
            WaveformView(levels: result?.waveform ?? [], progress: player.progress)
        default:
            LiveWaveformView(levels: [], tint: Theme.Colors.accent.opacity(0.4))
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch state {
        case .preparing, .requestingPermission:
            Color.clear.frame(width: 80, height: 80)
        case .idle, .denied, .failed:
            VStack(spacing: Theme.Spacing.sm) {
                RecordButton(systemImage: "mic.fill", tint: Theme.Colors.accent) {
                    Task { await recorder?.start() }
                }
                .accessibilityLabel(state == .idle ? "Start recording" : "Try again")
                .accessibilityIdentifier("recorder.start")
                Text(state == .idle ? "Tap to start" : "Try again").font(.caption).foregroundStyle(Theme.Colors.inkTertiary)
            }
        case .recording, .paused:
            HStack(spacing: Theme.Spacing.xl) {
                Button {
                    if state == .recording { recorder?.pause() } else { recorder?.resume() }
                } label: {
                    Image(systemName: state == .recording ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Theme.Colors.surfaceStrong))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.Colors.ink)
                .accessibilityLabel(state == .recording ? "Pause" : "Resume")

                ZStack {
                    if state == .recording && animates {
                        Circle()
                            .stroke(Theme.Colors.accent.opacity(0.35), lineWidth: 2)
                            .frame(width: 96, height: 96)
                            .scaleEffect(pulse ? 1.18 : 0.95)
                            .opacity(pulse ? 0 : 0.8)
                            .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: pulse)
                            .onAppear { pulse = true }
                    }
                    RecordButton(systemImage: "stop.fill", tint: Theme.Colors.accent) {
                        finishRecording()
                    }
                    .accessibilityLabel("Stop recording")
                    .accessibilityIdentifier("recorder.stop")
                }
                Color.clear.frame(width: 56, height: 56)
            }
        case .finished:
            VStack(spacing: Theme.Spacing.md) {
                Button {
                    if let result { player.toggle(url: result.url) }
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: 72, height: 72)
                        .background(Circle().fill(Theme.Colors.surfaceStrong))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.Colors.ink)
                .accessibilityLabel(player.isPlaying ? "Pause playback" : "Play recording")
                HStack(spacing: Theme.Spacing.sm) {
                    Button("Record again") {
                        player.stop()
                        if let result { try? FileManager.default.removeItem(at: result.url) }
                        result = nil
                        recorder?.reset()
                        Task { await recorder?.start() }
                    }
                    .buttonStyle(.secondary)
                    Button("Keep") {
                        guard let result else { return }
                        player.stop()
                        onKeep(result)
                        dismiss()
                    }
                    .buttonStyle(.primary)
                    .accessibilityIdentifier("recorder.keep")
                }
            }
        }
    }

    private func finishRecording() {
        guard let recorder else { return }
        if let finished = recorder.stop() {
            result = finished
        } else {
            recorder.reset()
        }
    }

    private func discardAndClose() {
        player.stop()
        if let result { try? FileManager.default.removeItem(at: result.url) }
        recorder?.discard()
        dismiss()
    }
}

private struct RecordButton: View {
    var systemImage: String
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(Theme.Colors.canvasRaised)
                .frame(width: 80, height: 80)
                .background(Circle().fill(tint))
                .shadow(color: tint.opacity(0.35), radius: 16, y: 6)
        }
        .buttonStyle(.plain)
    }
}
