import AVFoundation
import Foundation

@MainActor
public final class AudioPlaybackService: NSObject, ObservableObject {
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var activeClipIdentifier: String?
    @Published public private(set) var currentTime: TimeInterval = 0
    @Published public private(set) var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?

    public override init() {
        super.init()
    }

    public func play(url: URL, clipIdentifier: String) throws {
        stop()
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw StudioError.audioFileCorruptedOrMissing
        }

        let audioPlayer: AVAudioPlayer
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
        } catch {
            throw StudioError.playbackFailed(reason: error.localizedDescription)
        }

        audioPlayer.delegate = self
        guard audioPlayer.prepareToPlay(), audioPlayer.play() else {
            throw StudioError.playbackFailed(reason: "Audio output failed to start.")
        }

        self.player = audioPlayer
        self.activeClipIdentifier = clipIdentifier
        self.duration = audioPlayer.duration
        self.currentTime = 0
        self.isPlaying = true
        startProgressTimer()
    }

    public func pause() {
        guard let player, isPlaying else { return }
        player.pause()
        isPlaying = false
        progressTimer?.invalidate()
        progressTimer = nil
    }

    public func resume() {
        guard let player, !isPlaying else { return }
        if player.play() {
            isPlaying = true
            startProgressTimer()
        }
    }

    public func seek(to time: TimeInterval) {
        guard let player else { return }
        let clamped = max(0, min(time, player.duration))
        player.currentTime = clamped
        currentTime = clamped
    }

    public func stop() {
        progressTimer?.invalidate()
        progressTimer = nil
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        activeClipIdentifier = nil
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
                if !player.isPlaying && self.isPlaying {
                    self.isPlaying = false
                }
            }
        }
    }
}

extension AudioPlaybackService: AVAudioPlayerDelegate {
    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.stop()
        }
    }

    nonisolated public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            self?.stop()
        }
    }
}
