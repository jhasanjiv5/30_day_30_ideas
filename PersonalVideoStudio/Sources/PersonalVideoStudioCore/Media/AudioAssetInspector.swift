import AVFoundation
import Foundation

public struct AudioAssetMetadata: Equatable, Sendable {
    public let durationSeconds: Double
    public let sampleRate: Double
    public let formatExtension: String

    public init(durationSeconds: Double, sampleRate: Double, formatExtension: String) {
        self.durationSeconds = durationSeconds
        self.sampleRate = sampleRate
        self.formatExtension = formatExtension
    }
}

public protocol AudioAssetInspecting: Sendable {
    func inspectAudio(at url: URL) async throws -> AudioAssetMetadata
}

public struct AudioAssetInspector: AudioAssetInspecting {
    public init() {}

    public func inspectAudio(at url: URL) async throws -> AudioAssetMetadata {
        let asset = AVURLAsset(url: url)
        let durationTime = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(durationTime)
        guard durationSeconds.isFinite && durationSeconds > 0 else {
            throw VideoStudioError.mediaImportFailed(
                reason: "The selected audio file '\(url.lastPathComponent)' has no readable duration."
            )
        }

        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard let firstTrack = audioTracks.first else {
            throw VideoStudioError.mediaImportFailed(
                reason: "The selected file '\(url.lastPathComponent)' does not contain an audio track."
            )
        }

        var sampleRate: Double = 44_100
        let descriptions = try await firstTrack.load(.formatDescriptions)
        if let firstDesc = descriptions.first,
           let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(firstDesc) {
            if asbd.pointee.mSampleRate > 0 {
                sampleRate = asbd.pointee.mSampleRate
            }
        }

        return AudioAssetMetadata(
            durationSeconds: durationSeconds,
            sampleRate: sampleRate,
            formatExtension: url.pathExtension.lowercased()
        )
    }
}
