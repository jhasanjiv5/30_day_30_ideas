import AVFoundation
import CoreGraphics
import Foundation
import Vision

public enum CalibrationStatus: String, Codable, Equatable, Sendable {
    case pass
    case warning
    case failed
}

public struct NormalizedFaceRect: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var areaRatio: Double {
        max(0, width) * max(0, height)
    }
}

public struct PortraitCalibrationResult: Codable, Equatable, Sendable {
    public let imageFileName: String
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let detectedFaceCount: Int
    public let primaryFaceBox: NormalizedFaceRect?
    public let hasMouthLandmarks: Bool
    public let status: CalibrationStatus
    public let summary: String
    public let calibratedAt: Date

    public init(
        imageFileName: String,
        pixelWidth: Int,
        pixelHeight: Int,
        detectedFaceCount: Int,
        primaryFaceBox: NormalizedFaceRect?,
        hasMouthLandmarks: Bool,
        status: CalibrationStatus,
        summary: String,
        calibratedAt: Date = Date()
    ) {
        self.imageFileName = imageFileName
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.detectedFaceCount = detectedFaceCount
        self.primaryFaceBox = primaryFaceBox
        self.hasMouthLandmarks = hasMouthLandmarks
        self.status = status
        self.summary = summary
        self.calibratedAt = calibratedAt
    }
}

public struct AudioSyncCalibrationResult: Codable, Equatable, Sendable {
    public let audioFileName: String
    public let durationSeconds: Double
    public let sampleRate: Double
    public let rmsDecibels: Double
    public let peakDecibels: Double
    /// 10 Hz normalized energy envelope (0.0...1.0) used for deterministic beat-synced motion and preview.
    public let energyEnvelope10Hz: [Double]
    public let status: CalibrationStatus
    public let summary: String
    public let calibratedAt: Date

    public init(
        audioFileName: String,
        durationSeconds: Double,
        sampleRate: Double,
        rmsDecibels: Double,
        peakDecibels: Double,
        energyEnvelope10Hz: [Double],
        status: CalibrationStatus,
        summary: String,
        calibratedAt: Date = Date()
    ) {
        self.audioFileName = audioFileName
        self.durationSeconds = durationSeconds
        self.sampleRate = sampleRate
        self.rmsDecibels = rmsDecibels
        self.peakDecibels = peakDecibels
        self.energyEnvelope10Hz = energyEnvelope10Hz
        self.status = status
        self.summary = summary
        self.calibratedAt = calibratedAt
    }
}

public protocol PortraitAndAudioCalibrating: Sendable {
    func calibratePortrait(at imageURL: URL) throws -> PortraitCalibrationResult
    func calibrateAudioTrack(at audioURL: URL) async throws -> AudioSyncCalibrationResult
}

public struct PortraitAndAudioCalibrator: PortraitAndAudioCalibrating {
    public init() {}

    public func calibratePortrait(at imageURL: URL) throws -> PortraitCalibrationResult {
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw VideoStudioError.mediaImportFailed(
                reason: "Could not decode portrait image '\(imageURL.lastPathComponent)' for calibration."
            )
        }

        let width = cgImage.width
        let height = cgImage.height
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        let primary = observations.max { ($0.boundingBox.width * $0.boundingBox.height) < ($1.boundingBox.width * $1.boundingBox.height) }

        let faceBox = primary.map {
            NormalizedFaceRect(
                x: Double($0.boundingBox.origin.x),
                y: Double($0.boundingBox.origin.y),
                width: Double($0.boundingBox.size.width),
                height: Double($0.boundingBox.size.height)
            )
        }
        let hasMouth = primary?.landmarks?.outerLips != nil || primary?.landmarks?.innerLips != nil

        let assessment = Self.assessPortrait(
            fileName: imageURL.lastPathComponent,
            pixelWidth: width,
            pixelHeight: height,
            detectedFaceCount: observations.count,
            primaryFaceBox: faceBox,
            hasMouthLandmarks: hasMouth
        )
        return assessment
    }

    public static func assessPortrait(
        fileName: String,
        pixelWidth: Int,
        pixelHeight: Int,
        detectedFaceCount: Int,
        primaryFaceBox: NormalizedFaceRect?,
        hasMouthLandmarks: Bool
    ) -> PortraitCalibrationResult {
        if detectedFaceCount == 0 {
            return PortraitCalibrationResult(
                imageFileName: fileName,
                pixelWidth: pixelWidth,
                pixelHeight: pixelHeight,
                detectedFaceCount: 0,
                primaryFaceBox: nil,
                hasMouthLandmarks: false,
                status: .warning,
                summary: "No face detected in \(fileName). Visual-Text camera motion works, but portrait lip-sync requires a clear visible face."
            )
        }

        if min(pixelWidth, pixelHeight) < 512 {
            return PortraitCalibrationResult(
                imageFileName: fileName,
                pixelWidth: pixelWidth,
                pixelHeight: pixelHeight,
                detectedFaceCount: detectedFaceCount,
                primaryFaceBox: primaryFaceBox,
                hasMouthLandmarks: hasMouthLandmarks,
                status: .warning,
                summary: "Low resolution (\(pixelWidth)×\(pixelHeight)). Recommend at least 512 px short edge for crisp lip-sync and hand detail."
            )
        }

        if let box = primaryFaceBox, box.areaRatio < 0.04 {
            return PortraitCalibrationResult(
                imageFileName: fileName,
                pixelWidth: pixelWidth,
                pixelHeight: pixelHeight,
                detectedFaceCount: detectedFaceCount,
                primaryFaceBox: box,
                hasMouthLandmarks: hasMouthLandmarks,
                status: .warning,
                summary: "Subject face occupies under 4% of the frame. Crop closer or frame tighter for reliable lip-sync landmarks."
            )
        }

        if !hasMouthLandmarks {
            return PortraitCalibrationResult(
                imageFileName: fileName,
                pixelWidth: pixelWidth,
                pixelHeight: pixelHeight,
                detectedFaceCount: detectedFaceCount,
                primaryFaceBox: primaryFaceBox,
                hasMouthLandmarks: false,
                status: .warning,
                summary: "Face detected (\(pixelWidth)×\(pixelHeight)), but mouth landmarks are occluded or turned away."
            )
        }

        return PortraitCalibrationResult(
            imageFileName: fileName,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            detectedFaceCount: detectedFaceCount,
            primaryFaceBox: primaryFaceBox,
            hasMouthLandmarks: true,
            status: .pass,
            summary: "Calibrated \(detectedFaceCount) face(s) at \(pixelWidth)×\(pixelHeight) with mouth landmarks ready."
        )
    }

    public func calibrateAudioTrack(at audioURL: URL) async throws -> AudioSyncCalibrationResult {
        let asset = AVURLAsset(url: audioURL)
        let durationTime = try await asset.load(.duration)
        let duration = CMTimeGetSeconds(durationTime)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let track = tracks.first, duration.isFinite, duration > 0 else {
            throw VideoStudioError.mediaImportFailed(reason: "Audio track '\(audioURL.lastPathComponent)' could not be read for calibration.")
        }

        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 16_000
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else {
            throw VideoStudioError.mediaImportFailed(reason: "Unable to decode PCM audio for calibration.")
        }
        reader.add(output)
        reader.startReading()

        var samples: [Float] = []
        while let sampleBuffer = output.copyNextSampleBuffer(),
              let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
            let length = CMBlockBufferGetDataLength(blockBuffer)
            var data = Data(count: length)
            data.withUnsafeMutableBytes { rawBuffer in
                if let base = rawBuffer.baseAddress {
                    CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: base)
                }
            }
            let count = length / MemoryLayout<Float>.size
            data.withUnsafeBytes { rawBuffer in
                let ptr = rawBuffer.bindMemory(to: Float.self)
                samples.append(contentsOf: ptr.prefix(count))
            }
        }

        return Self.assessAudioSamples(
            fileName: audioURL.lastPathComponent,
            durationSeconds: duration,
            sampleRate: 16_000,
            monoSamples: samples
        )
    }

    public static func assessAudioSamples(
        fileName: String,
        durationSeconds: Double,
        sampleRate: Double,
        monoSamples: [Float]
    ) -> AudioSyncCalibrationResult {
        guard !monoSamples.isEmpty else {
            return AudioSyncCalibrationResult(
                audioFileName: fileName,
                durationSeconds: durationSeconds,
                sampleRate: sampleRate,
                rmsDecibels: -96,
                peakDecibels: -96,
                energyEnvelope10Hz: [],
                status: .failed,
                summary: "No decodable audio samples found in \(fileName)."
            )
        }

        var sumSquares: Double = 0
        var peak: Float = 0
        for s in monoSamples {
            let absS = abs(s)
            if absS > peak { peak = absS }
            sumSquares += Double(s) * Double(s)
        }
        let rms = sqrt(sumSquares / Double(monoSamples.count))
        let rmsDB = rms > 1e-6 ? 20.0 * log10(rms) : -96.0
        let peakDB = peak > 1e-6 ? 20.0 * log10(Double(peak)) : -96.0

        // 10 Hz energy envelope (100ms buckets)
        let bucketSize = max(1, Int(sampleRate / 10.0))
        var envelope: [Double] = []
        var idx = 0
        while idx < monoSamples.count {
            let end = min(monoSamples.count, idx + bucketSize)
            var bucketSum: Double = 0
            for i in idx..<end {
                let v = Double(monoSamples[i])
                bucketSum += v * v
            }
            let bucketRms = sqrt(bucketSum / Double(max(1, end - idx)))
            envelope.append(min(1.0, bucketRms * 2.8))
            idx = end
        }

        let status: CalibrationStatus
        let summary: String
        if rmsDB < -55.0 {
            status = .warning
            summary = String(format: "Audio level is very quiet (RMS %.1f dB). Increase track volume before lip-sync.", rmsDB)
        } else if peakDB > -0.3 {
            status = .warning
            summary = String(format: "Audio peaks near clipping (%.1f dB). Consider lowering volume slightly.", peakDB)
        } else {
            status = .pass
            summary = String(format: "Audio calibrated (RMS %.1f dB, Peak %.1f dB, %d sync frames).", rmsDB, peakDB, envelope.count)
        }

        return AudioSyncCalibrationResult(
            audioFileName: fileName,
            durationSeconds: durationSeconds,
            sampleRate: sampleRate,
            rmsDecibels: rmsDB,
            peakDecibels: peakDB,
            energyEnvelope10Hz: envelope,
            status: status,
            summary: summary
        )
    }
}
