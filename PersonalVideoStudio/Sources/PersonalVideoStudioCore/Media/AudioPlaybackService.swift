import AVFoundation
import Foundation

@MainActor
public final class AudioPlaybackService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published public private(set) var isPlaying = false
    @Published public private(set) var playingTrackID: UUID?

    private var player: AVAudioPlayer?

    public override init() {
        super.init()
    }

    public func togglePlayback(trackID: UUID, fileURL: URL, volume: Double) throws {
        if isPlaying && playingTrackID == trackID {
            stop()
            return
        }
        stop()
        let audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
        audioPlayer.delegate = self
        audioPlayer.volume = Float(min(max(volume, 0.0), 1.0))
        audioPlayer.prepareToPlay()
        audioPlayer.play()
        self.player = audioPlayer
        self.playingTrackID = trackID
        self.isPlaying = true
    }

    public func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        playingTrackID = nil
    }

    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.playingTrackID = nil
            self.player = nil
        }
    }
}
