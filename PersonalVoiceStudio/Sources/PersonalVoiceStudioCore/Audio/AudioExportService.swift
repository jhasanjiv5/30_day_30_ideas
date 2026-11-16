import AVFoundation
import Foundation

public struct AudioExportService: Sendable {
    private let diskChecker: DiskSpaceChecking

    public init(diskChecker: DiskSpaceChecking = DiskSpaceChecker()) {
        self.diskChecker = diskChecker
    }

    public func export(sourceWAVURL: URL, to destinationURL: URL, format: ExportAudioFormat) async throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: sourceWAVURL.path) else {
            throw StudioError.audioFileCorruptedOrMissing
        }

        let attrs = try? fm.attributesOfItem(atPath: sourceWAVURL.path)
        let sourceSize = (attrs?[.size] as? Int64) ?? 1_048_576
        try diskChecker.ensureSufficientSpace(
            at: destinationURL.deletingLastPathComponent(),
            requiredBytes: max(sourceSize * 2, 5_242_880)
        )

        if fm.fileExists(atPath: destinationURL.path) {
            try fm.removeItem(at: destinationURL)
        }

        switch format {
        case .wav:
            do {
                try fm.copyItem(at: sourceWAVURL, to: destinationURL)
            } catch {
                throw StudioError.exportFailed(reason: error.localizedDescription)
            }

        case .m4a:
            let asset = AVURLAsset(url: sourceWAVURL)
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                throw StudioError.exportFailed(reason: "M4A encoder could not be initialized on this Mac.")
            }
            exportSession.outputURL = destinationURL
            exportSession.outputFileType = .m4a

            let exportError: Error? = await withCheckedContinuation { continuation in
                exportSession.exportAsynchronously {
                    switch exportSession.status {
                    case .completed:
                        continuation.resume(returning: nil)
                    case .failed:
                        continuation.resume(
                            returning: exportSession.error
                                ?? StudioError.exportFailed(reason: "M4A export failed.")
                        )
                    case .cancelled:
                        continuation.resume(returning: StudioError.exportFailed(reason: "Export was cancelled."))
                    default:
                        continuation.resume(returning: StudioError.exportFailed(reason: "Unexpected export state."))
                    }
                }
            }

            if let exportError {
                throw StudioError.exportFailed(reason: exportError.localizedDescription)
            }
        }
    }
}
