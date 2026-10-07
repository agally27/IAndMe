import Foundation
import AVFoundation

/// Produces playable audio for the sample life's voice moments, entirely on-device.
/// Uses the system speech synthesiser to read the sample transcript; falls back to a soft tone
/// if synthesis isn't available, so playback still demonstrates the player.
enum SampleAudioSynthesizer {
    static func synthesize(text: String, to url: URL) async -> Bool {
        let spoken = await speak(text: text, to: url)
        if spoken { return true }
        return writeTone(duration: 6, to: url)
    }

    /// Keeps the synthesiser and output file alive for the duration of the write.
    private final class SynthesisJob: @unchecked Sendable {
        let synthesizer = AVSpeechSynthesizer()
        var file: AVAudioFile?
        var resumed = false
        var wroteFrames = false
        let lock = NSLock()

        func finish(_ continuation: CheckedContinuation<Bool, Never>, result: Bool) {
            lock.lock()
            defer { lock.unlock() }
            guard !resumed else { return }
            resumed = true
            continuation.resume(returning: result)
        }
    }

    private static func speak(text: String, to url: URL) async -> Bool {
        let job = SynthesisJob()
        return await withCheckedContinuation { continuation in
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-GB") ?? AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
            job.synthesizer.write(utterance) { buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                if pcm.frameLength == 0 {
                    job.finish(continuation, result: job.wroteFrames)
                    return
                }
                do {
                    if job.file == nil {
                        job.file = try AVAudioFile(forWriting: url, settings: pcm.format.settings, commonFormat: pcm.format.commonFormat, interleaved: pcm.format.isInterleaved)
                    }
                    try job.file?.write(from: pcm)
                    job.wroteFrames = true
                } catch {
                    job.finish(continuation, result: false)
                }
            }
            // Safety net: if nothing arrives, give up after a while.
            DispatchQueue.global().asyncAfter(deadline: .now() + 20) {
                job.finish(continuation, result: job.wroteFrames)
            }
        }
    }

    /// A quiet, warm two-note tone. Used only when speech synthesis isn't available.
    static func writeTone(duration: TimeInterval, to url: URL) -> Bool {
        let sampleRate = 22_050.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return false }
        let frames = AVAudioFrameCount(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return false }
        buffer.frameLength = frames
        guard let channel = buffer.floatChannelData?[0] else { return false }
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let envelope = min(1, t * 2) * min(1, (duration - t) * 2) * 0.18
            let value = sin(2 * .pi * 220 * t) * 0.6 + sin(2 * .pi * 330 * t) * 0.4
            channel[i] = Float(value * envelope)
        }
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
            return true
        } catch {
            return false
        }
    }
}
