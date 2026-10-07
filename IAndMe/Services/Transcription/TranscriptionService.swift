import Foundation
import Speech

/// Turns a voice moment into text. Only ever on the person's explicit request.
protocol TranscriptionService: AnyObject {
    /// Whether transcription can run entirely on this device.
    func availability() async -> TranscriptionAvailability
    func transcribe(audioAt url: URL) async throws -> String
}

enum TranscriptionAvailability: Sendable {
    case available
    case needsPermission
    case denied
    case unavailable(reason: String)
}

enum TranscriptionError: LocalizedError {
    case unavailable(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason): return reason
        case .empty: return "Nothing recognisable was heard in this recording."
        }
    }
}

/// On-device speech recognition using Apple's Speech framework. Recognition is forced on-device so
/// audio never leaves the phone; if the device can't do that, transcription is reported as unavailable.
final class OnDeviceTranscriptionService: TranscriptionService {
    private let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-GB"))

    func availability() async -> TranscriptionAvailability {
        guard let recognizer, recognizer.isAvailable else {
            return .unavailable(reason: "Speech recognition isn't available on this device right now.")
        }
        guard recognizer.supportsOnDeviceRecognition else {
            return .unavailable(reason: "This device can't transcribe privately on-device yet.")
        }
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return .available
        case .notDetermined: return .needsPermission
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }

    func transcribe(audioAt url: URL) async throws -> String {
        guard let recognizer, recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            throw TranscriptionError.unavailable("On-device transcription isn't available here.")
        }
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else {
            throw TranscriptionError.unavailable("Transcription needs speech recognition permission.")
        }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        return try await withCheckedThrowingContinuation { continuation in
            var finished = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !finished else { return }
                if let error {
                    finished = true
                    continuation.resume(throwing: error)
                    return
                }
                if let result, result.isFinal {
                    finished = true
                    let text = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                    if text.isEmpty {
                        continuation.resume(throwing: TranscriptionError.empty)
                    } else {
                        continuation.resume(returning: text)
                    }
                }
            }
        }
    }
}
