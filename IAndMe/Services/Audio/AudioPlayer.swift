import Foundation
import AVFoundation
import Observation

/// Plays back voice moments. One shared player per screen keeps playback state simple.
@MainActor
@Observable
final class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var currentURL: URL?
    private(set) var errorMessage: String?

    private var player: AVAudioPlayer?
    private var progressTask: Task<Void, Never>?

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, currentTime / duration)
    }

    func isPlaying(_ url: URL) -> Bool { isPlaying && currentURL == url }

    func toggle(url: URL) {
        if currentURL == url, let player {
            if player.isPlaying {
                player.pause()
                isPlaying = false
                stopProgress()
            } else {
                activateSession()
                player.play()
                isPlaying = true
                startProgress()
            }
            return
        }
        play(url: url)
    }

    func play(url: URL) {
        stop()
        do {
            activateSession()
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            self.player = player
            currentURL = url
            duration = player.duration
            currentTime = 0
            errorMessage = nil
            player.play()
            isPlaying = true
            startProgress()
        } catch {
            errorMessage = "This recording couldn't be played."
            isPlaying = false
        }
    }

    func seek(to fraction: Double) {
        guard let player else { return }
        player.currentTime = max(0, min(player.duration, player.duration * fraction))
        currentTime = player.currentTime
    }

    func stop() {
        stopProgress()
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        currentURL = nil
    }

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }

    private func startProgress() {
        stopProgress()
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(60))
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
            }
        }
    }

    private func stopProgress() {
        progressTask?.cancel()
        progressTask = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentTime = 0
            self.stopProgress()
        }
    }
}
