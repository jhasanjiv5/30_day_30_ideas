import AppKit
import AVFoundation
import CoreGraphics
import CoreImage
import Foundation

public final class AVFoundationVideoRenderer: VideoRenderingEngine, @unchecked Sendable {
    private let fileManager: FileManager
    private let diskChecker: DiskSpaceChecking
    private let ciContext: CIContext

    public init(
        fileManager: FileManager = .default,
        diskChecker: DiskSpaceChecking = DiskSpaceChecker()
    ) {
        self.fileManager = fileManager
        self.diskChecker = diskChecker
        self.ciContext = CIContext(options: [.useSoftwareRenderer: false])
    }

    public func render(
        project: VideoProject,
        storagePaths: LocalStoragePaths,
        outputURL: URL,
        progress: @escaping @Sendable (VideoRenderProgress) -> Void
    ) async throws -> RenderedVideoRecord {
        try project.validateForExport()
        for track in project.audioTracks {
            try track.validate()
        }

        try storagePaths.ensureProjectDirectoriesExist(for: project.id, fileManager: fileManager)
        try diskChecker.ensureSufficientSpace(
            at: outputURL.deletingLastPathComponent(),
            requiredBytes: 150_000_000
        )

        let config = project.exportConfiguration
        let width = config.pixelWidth
        let height = config.pixelHeight
        let fps = config.frameRate.rawValue
        let totalDuration = project.totalDurationSeconds
        let totalFrames = max(1, Int((totalDuration * Double(fps)).rounded()))

        let tempVideoURL = outputURL.deletingLastPathComponent()
            .appendingPathComponent("tmp-\(UUID().uuidString).mp4", isDirectory: false)
        defer {
            try? fileManager.removeItem(at: tempVideoURL)
        }

        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }

        let sceneAssets = try await preloadSceneVisuals(
            scenes: project.scenes,
            projectID: project.id,
            storagePaths: storagePaths
        )

        progress(VideoRenderProgress(fractionCompleted: 0.05, statusMessage: "Preparing video encoder…"))

        let writer = try AVAssetWriter(outputURL: tempVideoURL, fileType: .mp4)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: width >= 1920 ? 8_000_000 : 4_500_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )

        guard writer.canAdd(writerInput) else {
            throw VideoStudioError.exportFailed(reason: "Unable to configure H.264 video writer input.")
        }
        writer.add(writerInput)

        guard writer.startWriting() else {
            throw VideoStudioError.exportFailed(reason: writer.error?.localizedDescription ?? "Writer failed to start.")
        }
        writer.startSession(atSourceTime: .zero)

        let sceneTimings = buildSceneTimings(scenes: project.scenes)
        let canvasSize = CGSize(width: width, height: height)

        for frameIndex in 0..<totalFrames {
            if Task.isCancelled {
                writer.cancelWriting()
                throw VideoStudioError.exportCancelled
            }

            while !writerInput.isReadyForMoreMediaData {
                if Task.isCancelled {
                    writer.cancelWriting()
                    throw VideoStudioError.exportCancelled
                }
                try await Task.sleep(nanoseconds: 5_000_000)
            }

            let timestampSeconds = Double(frameIndex) / Double(fps)
            let presentationTime = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(fps))

            guard let pixelBufferPool = adaptor.pixelBufferPool else {
                throw VideoStudioError.exportFailed(reason: "Pixel buffer pool is unavailable.")
            }
            var bufferOut: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &bufferOut)
            guard status == kCVReturnSuccess, let pixelBuffer = bufferOut else {
                throw VideoStudioError.exportFailed(reason: "Failed to allocate video frame buffer.")
            }

            try renderFrame(
                at: timestampSeconds,
                sceneTimings: sceneTimings,
                assets: sceneAssets,
                canvasSize: canvasSize,
                into: pixelBuffer
            )

            if !adaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
                throw VideoStudioError.exportFailed(
                    reason: writer.error?.localizedDescription ?? "Failed appending video frame."
                )
            }

            if frameIndex % max(1, fps / 2) == 0 || frameIndex == totalFrames - 1 {
                let videoFraction = 0.05 + (Double(frameIndex + 1) / Double(totalFrames)) * 0.75
                progress(
                    VideoRenderProgress(
                        fractionCompleted: videoFraction,
                        statusMessage: "Rendering video frames (\(frameIndex + 1)/\(totalFrames))…"
                    )
                )
            }
        }

        writerInput.markAsFinished()
        await withCheckedContinuation { continuation in
            writer.finishWriting {
                continuation.resume()
            }
        }

        if let writerError = writer.error {
            throw VideoStudioError.exportFailed(reason: writerError.localizedDescription)
        }

        if Task.isCancelled {
            throw VideoStudioError.exportCancelled
        }

        if config.includeAudioMix && !project.audioTracks.isEmpty {
            progress(VideoRenderProgress(fractionCompleted: 0.85, statusMessage: "Mixing local audio tracks…"))
            try await muxAudioTracks(
                videoURL: tempVideoURL,
                audioTracks: project.audioTracks,
                projectID: project.id,
                storagePaths: storagePaths,
                totalDurationSeconds: totalDuration,
                destinationURL: outputURL
            )
        } else {
            progress(VideoRenderProgress(fractionCompleted: 0.92, statusMessage: "Finalizing MP4 container…"))
            try fileManager.moveItem(at: tempVideoURL, to: outputURL)
        }

        let fileSize = (try? outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        progress(VideoRenderProgress(fractionCompleted: 1.0, statusMessage: "Export complete."))

        return RenderedVideoRecord(
            fileName: outputURL.lastPathComponent,
            width: width,
            height: height,
            frameRate: fps,
            durationSeconds: totalDuration,
            fileSizeBytes: fileSize
        )
    }

    private struct SceneTiming {
        let index: Int
        let scene: StoryboardScene
        let start: Double
        let end: Double
    }

    private struct PreloadedSceneVisual {
        let image: CGImage?
        let videoGenerator: AVAssetImageGenerator?
    }

    private func buildSceneTimings(scenes: [StoryboardScene]) -> [SceneTiming] {
        var cursor = 0.0
        return scenes.enumerated().map { idx, scene in
            let duration = max(0.5, scene.durationSeconds)
            let timing = SceneTiming(index: idx, scene: scene, start: cursor, end: cursor + duration)
            cursor += duration
            return timing
        }
    }

    private func preloadSceneVisuals(
        scenes: [StoryboardScene],
        projectID: UUID,
        storagePaths: LocalStoragePaths
    ) async throws -> [UUID: PreloadedSceneVisual] {
        var map: [UUID: PreloadedSceneVisual] = [:]
        for scene in scenes {
            if let generatedClip = scene.generatedVideoFileName, !generatedClip.isEmpty {
                let clipURL = storagePaths.generatedClipURL(projectID: projectID, fileName: generatedClip)
                guard fileManager.fileExists(atPath: clipURL.path) else {
                    throw VideoStudioError.mediaFileMissing(fileName: generatedClip)
                }
                let asset = AVURLAsset(url: clipURL)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.requestedTimeToleranceBefore = CMTime(seconds: 0.05, preferredTimescale: 600)
                generator.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)
                map[scene.id] = PreloadedSceneVisual(image: nil, videoGenerator: generator)
                continue
            }

            guard let fileName = scene.mediaFileName, !fileName.isEmpty else {
                map[scene.id] = PreloadedSceneVisual(image: nil, videoGenerator: nil)
                continue
            }
            let fileURL = storagePaths.mediaFileURL(projectID: projectID, fileName: fileName)
            guard fileManager.fileExists(atPath: fileURL.path) else {
                throw VideoStudioError.mediaFileMissing(fileName: fileName)
            }
            switch scene.mediaKind {
            case .image:
                guard let nsImage = NSImage(contentsOf: fileURL),
                      let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    throw VideoStudioError.mediaImportFailed(reason: "Could not decode image '\(fileName)'.")
                }
                map[scene.id] = PreloadedSceneVisual(image: cgImage, videoGenerator: nil)
            case .video:
                let asset = AVURLAsset(url: fileURL)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.requestedTimeToleranceBefore = CMTime(seconds: 0.05, preferredTimescale: 600)
                generator.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)
                map[scene.id] = PreloadedSceneVisual(image: nil, videoGenerator: generator)
            }
        }
        return map
    }

    private func renderFrame(
        at timeSeconds: Double,
        sceneTimings: [SceneTiming],
        assets: [UUID: PreloadedSceneVisual],
        canvasSize: CGSize,
        into pixelBuffer: CVPixelBuffer
    ) throws {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: Int(canvasSize.width),
            height: Int(canvasSize.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            throw VideoStudioError.exportFailed(reason: "Unable to create CoreGraphics rendering context.")
        }

        context.setFillColor(NSColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1.0).cgColor)
        context.fill(CGRect(origin: .zero, size: canvasSize))

        guard let active = sceneTimings.last(where: { timeSeconds >= $0.start && timeSeconds <= $0.end }) ?? sceneTimings.last else {
            return
        }

        let localElapsed = max(0, timeSeconds - active.start)
        let sceneDuration = max(0.5, active.end - active.start)
        let sceneProgress = min(max(localElapsed / sceneDuration, 0), 1)

        // Check if we are in a cross-dissolve into the active scene from the previous scene
        if active.index > 0,
           active.scene.transition == .crossDissolve,
           active.scene.transitionDurationSeconds > 0,
           localElapsed < active.scene.transitionDurationSeconds {
            let previous = sceneTimings[active.index - 1]
            let dissolveAlpha = CGFloat(localElapsed / active.scene.transitionDurationSeconds)
            drawSceneVisual(
                previous.scene,
                localTime: previous.end - previous.start,
                progress: 1.0,
                alpha: 1.0 - dissolveAlpha,
                assets: assets,
                canvasSize: canvasSize,
                in: context
            )
            drawSceneVisual(
                active.scene,
                localTime: localElapsed,
                progress: sceneProgress,
                alpha: dissolveAlpha,
                assets: assets,
                canvasSize: canvasSize,
                in: context
            )
        } else {
            drawSceneVisual(
                active.scene,
                localTime: localElapsed,
                progress: sceneProgress,
                alpha: 1.0,
                assets: assets,
                canvasSize: canvasSize,
                in: context
            )
        }

        drawTextOverlays(for: active.scene, canvasSize: canvasSize, in: context)
    }

    private func drawSceneVisual(
        _ scene: StoryboardScene,
        localTime: Double,
        progress: Double,
        alpha: CGFloat,
        assets: [UUID: PreloadedSceneVisual],
        canvasSize: CGSize,
        in context: CGContext
    ) {
        let visual = assets[scene.id]
        var frameImage: CGImage? = visual?.image
        if frameImage == nil, let generator = visual?.videoGenerator {
            let requested = CMTime(seconds: max(0, localTime), preferredTimescale: 600)
            frameImage = try? generator.copyCGImage(at: requested, actualTime: nil)
        }

        guard let cgImage = frameImage else {
            return
        }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        guard imageSize.width > 0 && imageSize.height > 0 else { return }

        let baseScale = max(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
        var zoomFactor: CGFloat = 1.0
        var offsetX: CGFloat = 0
        let offsetY: CGFloat = 0

        switch scene.motionEffect {
        case .none:
            zoomFactor = 1.0
        case .kenBurnsZoomIn:
            zoomFactor = 1.0 + CGFloat(progress) * 0.08
        case .kenBurnsZoomOut:
            zoomFactor = 1.08 - CGFloat(progress) * 0.08
        case .panLeftToRight:
            zoomFactor = 1.08
            offsetX = (CGFloat(progress) - 0.5) * canvasSize.width * 0.06
        case .panRightToLeft:
            zoomFactor = 1.08
            offsetX = (0.5 - CGFloat(progress)) * canvasSize.width * 0.06
        case .subtleBeatPulse:
            let pulse = sin(localTime * .pi * 2.0) * 0.5 + 0.5
            zoomFactor = 1.02 + CGFloat(pulse) * 0.025
        }

        let drawWidth = imageSize.width * baseScale * zoomFactor
        let drawHeight = imageSize.height * baseScale * zoomFactor
        let drawRect = CGRect(
            x: (canvasSize.width - drawWidth) / 2.0 + offsetX,
            y: (canvasSize.height - drawHeight) / 2.0 + offsetY,
            width: drawWidth,
            height: drawHeight
        )

        context.saveGState()
        context.setAlpha(alpha)
        context.interpolationQuality = .high
        context.draw(cgImage, in: drawRect)
        context.restoreGState()
    }

    private func drawTextOverlays(for scene: StoryboardScene, canvasSize: CGSize, in context: CGContext) {
        let title = scene.titleOverlay.trimmingCharacters(in: .whitespacesAndNewlines)
        let caption = scene.captionScript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty || !caption.isEmpty else { return }

        let scale = canvasSize.width / 1280.0
        let horizontalPadding = 64.0 * scale

        let nsGraphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsGraphicsContext

        let scrimHeight = min(canvasSize.height * 0.34, 260.0 * scale)
        let scrimRect: CGRect
        switch scene.overlayPlacement {
        case .top:
            scrimRect = CGRect(x: 0, y: canvasSize.height - scrimHeight, width: canvasSize.width, height: scrimHeight)
        case .center:
            scrimRect = CGRect(x: 0, y: (canvasSize.height - scrimHeight) / 2.0, width: canvasSize.width, height: scrimHeight)
        case .bottom:
            scrimRect = CGRect(x: 0, y: 0, width: canvasSize.width, height: scrimHeight)
        }

        context.saveGState()
        context.setFillColor(NSColor.black.withAlphaComponent(0.55).cgColor)
        context.fill(scrimRect)
        context.restoreGState()

        let textMaxWidth = canvasSize.width - (horizontalPadding * 2.0)
        var cursorY = scrimRect.minY + 32.0 * scale

        if !caption.isEmpty {
            let captionFont = NSFont.systemFont(ofSize: max(18, 26 * scale), weight: .regular)
            let captionAttr = NSAttributedString(
                string: caption,
                attributes: [
                    .font: captionFont,
                    .foregroundColor: NSColor.white.withAlphaComponent(0.92)
                ]
            )
            let captionSize = captionAttr.boundingRect(
                with: CGSize(width: textMaxWidth, height: scrimHeight),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            captionAttr.draw(in: CGRect(x: horizontalPadding, y: cursorY, width: textMaxWidth, height: captionSize.height + 8))
            cursorY += captionSize.height + 14 * scale
        }

        if !title.isEmpty {
            let titleFont = NSFont.systemFont(ofSize: max(26, 40 * scale), weight: .semibold)
            let titleAttr = NSAttributedString(
                string: title,
                attributes: [
                    .font: titleFont,
                    .foregroundColor: NSColor.white
                ]
            )
            let titleSize = titleAttr.boundingRect(
                with: CGSize(width: textMaxWidth, height: scrimHeight),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            titleAttr.draw(in: CGRect(x: horizontalPadding, y: cursorY, width: textMaxWidth, height: titleSize.height + 8))
        }

        NSGraphicsContext.restoreGraphicsState()
    }

    private func muxAudioTracks(
        videoURL: URL,
        audioTracks: [AudioTrackItem],
        projectID: UUID,
        storagePaths: LocalStoragePaths,
        totalDurationSeconds: Double,
        destinationURL: URL
    ) async throws {
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: videoURL)

        let sourceVideoTracks = try await videoAsset.loadTracks(withMediaType: .video)
        guard let sourceVideoTrack = sourceVideoTracks.first,
              let compVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
              ) else {
            throw VideoStudioError.exportFailed(reason: "Failed loading rendered video track for audio muxing.")
        }

        let videoDuration = try await videoAsset.load(.duration)
        try compVideoTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: videoDuration),
            of: sourceVideoTrack,
            at: .zero
        )

        var mixParameters: [AVMutableAudioMixInputParameters] = []

        for trackItem in audioTracks {
            let audioURL = storagePaths.audioFileURL(projectID: projectID, fileName: trackItem.fileName)
            guard fileManager.fileExists(atPath: audioURL.path) else {
                throw VideoStudioError.mediaFileMissing(fileName: trackItem.fileName)
            }
            let audioAsset = AVURLAsset(url: audioURL)
            let loadedTracks = try await audioAsset.loadTracks(withMediaType: .audio)
            guard let sourceAudio = loadedTracks.first,
                  let compAudioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                  ) else {
                continue
            }

            let maxInsertDuration = max(0, totalDurationSeconds - trackItem.startOffsetSeconds)
            let trimmedDuration = min(trackItem.trimmedDurationSeconds, maxInsertDuration)
            guard trimmedDuration > 0.05 else { continue }

            let timeRange = CMTimeRange(
                start: CMTime(seconds: trackItem.trimStartSeconds, preferredTimescale: 600),
                duration: CMTime(seconds: trimmedDuration, preferredTimescale: 600)
            )
            let insertAt = CMTime(seconds: trackItem.startOffsetSeconds, preferredTimescale: 600)
            try compAudioTrack.insertTimeRange(timeRange, of: sourceAudio, at: insertAt)

            let params = AVMutableAudioMixInputParameters(track: compAudioTrack)
            params.setVolume(Float(min(max(trackItem.volume, 0.0), 1.5)), at: .zero)
            mixParameters.append(params)
        }

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoStudioError.exportFailed(reason: "Unable to create AVAssetExportSession for audio muxing.")
        }

        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = mixParameters
        exportSession.audioMix = audioMix
        exportSession.outputURL = destinationURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = false

        await exportSession.export()

        if Task.isCancelled || exportSession.status == .cancelled {
            throw VideoStudioError.exportCancelled
        }
        if exportSession.status != .completed {
            throw VideoStudioError.exportFailed(
                reason: exportSession.error?.localizedDescription ?? "Audio mixing export failed."
            )
        }
    }
}
