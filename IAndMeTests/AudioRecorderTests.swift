import Testing
import Foundation
@testable import IAndMe

@MainActor
struct AudioRecorderTests {
    /// Whatever the audio hardware does, starting a recording must never leave the interface stuck:
    /// within the timeout the recorder is either recording or has failed honestly.
    @Test func startEitherRecordsOrFailsWithinTimeout() async throws {
        let services = try TestStack.make()
        let recorder = AudioRecorder(media: services.media, sampleInterval: .milliseconds(200))
        recorder.setupTimeout = .seconds(2)
        let started = Date()
        await recorder.start()
        let elapsed = Date().timeIntervalSince(started)
        #expect(elapsed < 6, "start() took \(elapsed)s")
        switch recorder.state {
        case .recording:
            try? await Task.sleep(for: .milliseconds(600))
            let result = recorder.stop()
            #expect(result == nil || result!.duration > 0)
            if let result { try? FileManager.default.removeItem(at: result.url) }
        case .failed, .denied:
            break
        default:
            Issue.record("Unexpected state \(recorder.state)")
        }
    }

    @Test func discardReturnsToIdle() throws {
        let services = try TestStack.make()
        let recorder = AudioRecorder(media: services.media)
        recorder.discard()
        #expect(recorder.state == .idle)
        #expect(recorder.duration == 0)
    }
}
