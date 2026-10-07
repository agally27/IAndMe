import Foundation
import AVFoundation
import Observation

/// Records voice moments with live level metering. Audio is written straight to the app's local media
/// directory and never leaves the device.
@MainActor
@Observable
final class AudioRecorder {
    enum State: Equatable {
        case idle
        case requestingPermission
        case preparing
        case recording
        case paused
        case finished
        case denied
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var duration: TimeInterval = 0
    /// Rolling live levels (0...1) for the waveform while recording.
    private(set) var liveLevels: [Float] = []
    /// Full history of sampled levels, stored with the recording.
    private(set) var sampledLevels: [Float] = []

    private var recorder: AVAudioRecorder?
    private var meterTask: Task<Void, Never>?
    private var fileURL: URL?
    private var fileName: String?
    private let media: MediaService
    /// Incremented on every start/discard so a slow setup that finishes late can be ignored.
    private var generation = 0
    /// How long to wait for the audio hardware before giving up.
    var setupTimeout: Duration = .seconds(8)

    private let liveWindow = 48
    /// How often levels are sampled. UI tests use a slow interval so the run loop can go idle.
    private let sampleInterval: Duration

    init(media: MediaService, sampleInterval: Duration = .milliseconds(50)) {
        self.media = media
        self.sampleInterval = sampleInterval
    }

    var isActive: Bool { state == .recording || state == .paused }

    func start() async {
        guard state == .idle || state == .finished || state == .denied || isFailed else { return }
        state = .requestingPermission
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            state = .denied
            return
        }
        generation += 1
        let myGeneration = generation
        state = .preparing
        let (name, url) = media.newAudioFile(extension: "m4a")
        fileName = name
        fileURL = url

        // Audio hardware setup can block for a long time (notably in the Simulator), so it runs off
        // the main actor and is raced against a timeout. A task group would wait for the blocked
        // child, so the race uses a continuation that resumes exactly once; a late result is discarded.
        let race = SetupRace()
        let timeout = setupTimeout
        let result: RecorderBox? = await withCheckedContinuation { continuation in
            race.attach(continuation)
            Task.detached(priority: .userInitiated) {
                let box = RecorderBox.prepare(url: url)
                if !race.resume(with: box) {
                    box?.stopAndDiscard()
                }
            }
            Task.detached {
                try? await Task.sleep(for: timeout)
                _ = race.resume(with: nil)
            }
        }

        // The person may have cancelled while we waited.
        guard myGeneration == generation, state == .preparing else {
            Task.detached { result?.stopAndDiscard() }
            return
        }
        guard let box = result else {
            try? FileManager.default.removeItem(at: url)
            state = .failed("The microphone isn't responding. On a real iPhone this starts straight away; in the Simulator the Mac's microphone may not be available.")
            return
        }
        recorder = box.recorder
        duration = 0
        liveLevels = Array(repeating: 0, count: liveWindow)
        sampledLevels = []
        state = .recording
        startMetering()
    }

    private var isFailed: Bool {
        if case .failed = state { return true }
        return false
    }

    func pause() {
        guard state == .recording, let recorder else { return }
        recorder.pause()
        state = .paused
    }

    func resume() {
        guard state == .paused, let recorder else { return }
        recorder.record()
        state = .recording
    }

    struct Result: Sendable {
        var fileName: String
        var url: URL
        var duration: TimeInterval
        var waveform: [Float]
    }

    /// Stops and returns the finished recording. Returns nil if nothing usable was captured.
    func stop() -> Result? {
        guard let recorder, let fileURL, let fileName, isActive else { return nil }
        meterTask?.cancel()
        meterTask = nil
        let finalDuration = recorder.currentTime > 0 ? recorder.currentTime : duration
        recorder.stop()
        self.recorder = nil
        state = .finished
        deactivateSession()
        guard finalDuration >= 0.5, FileManager.default.fileExists(atPath: fileURL.path) else {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
        duration = finalDuration
        return Result(fileName: fileName, url: fileURL, duration: finalDuration, waveform: Waveform.condense(sampledLevels, to: 120))
    }

    /// Stops and throws the audio away.
    func discard() {
        generation += 1
        meterTask?.cancel()
        meterTask = nil
        recorder?.stop()
        recorder = nil
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
        fileURL = nil
        fileName = nil
        duration = 0
        liveLevels = []
        sampledLevels = []
        state = .idle
        deactivateSession()
    }

    func reset() {
        discard()
    }

    private func startMetering() {
        meterTask?.cancel()
        meterTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                try? await Task.sleep(for: self.sampleInterval)
                guard let recorder = self.recorder else { return }
                guard self.state == .recording else { continue }
                recorder.updateMeters()
                let power = recorder.averagePower(forChannel: 0)
                let level = Waveform.normalise(decibels: power)
                self.duration = recorder.currentTime
                self.liveLevels.append(level)
                if self.liveLevels.count > self.liveWindow { self.liveLevels.removeFirst() }
                self.sampledLevels.append(level)
            }
        }
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}

/// Resumes a continuation at most once, from whichever side finishes first.
final class SetupRace: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<RecorderBox?, Never>?

    func attach(_ continuation: CheckedContinuation<RecorderBox?, Never>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    /// Returns false if the race was already decided; the caller should discard its result.
    func resume(with value: RecorderBox?) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let continuation else { return false }
        self.continuation = nil
        continuation.resume(returning: value)
        return true
    }
}

/// Owns an `AVAudioRecorder` created off the main actor. The class is only ever handed back to the
/// main actor once setup is complete.
final class RecorderBox: @unchecked Sendable {
    let recorder: AVAudioRecorder

    private init(recorder: AVAudioRecorder) {
        self.recorder = recorder
    }

    static func prepare(url: URL) -> RecorderBox? {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = true
            guard recorder.prepareToRecord(), recorder.record() else { return nil }
            return RecorderBox(recorder: recorder)
        } catch {
            return nil
        }
    }

    func stopAndDiscard() {
        recorder.stop()
        recorder.deleteRecording()
    }
}

enum Waveform {
    /// Maps recorder decibels (-160...0) to a perceptual 0...1 level.
    static func normalise(decibels: Float) -> Float {
        let clamped = max(-60, min(0, decibels))
        let linear = (clamped + 60) / 60
        return pow(linear, 1.6)
    }

    /// Reduces a long series of samples to a fixed number of bars by averaging peaks.
    static func condense(_ samples: [Float], to count: Int) -> [Float] {
        guard !samples.isEmpty, count > 0 else { return [] }
        guard samples.count > count else { return samples }
        let bucket = Double(samples.count) / Double(count)
        return (0..<count).map { i in
            let start = Int(Double(i) * bucket)
            let end = min(samples.count, Int(Double(i + 1) * bucket))
            let slice = samples[start..<max(start + 1, end)]
            return slice.max() ?? 0
        }
    }

    /// A gentle, deterministic placeholder waveform for recordings without captured levels.
    static func placeholder(count: Int = 120, key: String = "placeholder") -> [Float] {
        var generator = SeededGenerator(seed: StableHash.fnv1a(key))
        return (0..<count).map { i in
            let base = 0.35 + 0.25 * sin(Double(i) / 6.0) + 0.15 * sin(Double(i) / 2.3)
            let noise = Double.random(in: -0.12...0.12, using: &generator)
            return Float(max(0.05, min(1, base + noise)))
        }
    }
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
