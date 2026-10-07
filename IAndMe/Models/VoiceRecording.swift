import Foundation
import SwiftData

/// A voice note attached to a moment. Audio stays on the device; the transcript is optional and
/// only produced when the person asks for it.
@Model
final class VoiceRecording {
    @Attribute(.unique) var id: UUID
    var fileName: String
    var createdAt: Date
    var duration: TimeInterval
    /// Normalised amplitude samples (0...1) captured while recording, used to draw the waveform.
    var waveform: [Float]
    var transcript: String?
    var transcriptionStateRaw: String
    var entry: JournalEntry?

    init(
        id: UUID = UUID(),
        fileName: String,
        createdAt: Date = .now,
        duration: TimeInterval,
        waveform: [Float] = [],
        transcript: String? = nil,
        transcriptionState: TranscriptionState = .none
    ) {
        self.id = id
        self.fileName = fileName
        self.createdAt = createdAt
        self.duration = duration
        self.waveform = waveform
        self.transcript = transcript
        self.transcriptionStateRaw = transcriptionState.rawValue
    }

    var transcriptionState: TranscriptionState {
        get { TranscriptionState(rawValue: transcriptionStateRaw) ?? .none }
        set { transcriptionStateRaw = newValue.rawValue }
    }

    var formattedDuration: String { DurationFormatting.short(duration) }
}

enum TranscriptionState: String, Codable, Sendable {
    case none
    case inProgress
    case done
    case failed
    case unavailable
}
