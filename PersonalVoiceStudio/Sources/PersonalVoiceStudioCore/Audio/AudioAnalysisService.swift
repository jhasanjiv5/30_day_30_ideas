import AVFoundation
import Foundation

public struct AudioMetrics: Equatable, Sendable {
    public let durationSeconds: Double
    public let rmsDecibels: Float
    public let peakDecibels: Float
    public let sampleRate: Double

    public init(
        durationSeconds: Double,
        rmsDecibels: Float,
        peakDecibels: Float,
        sampleRate: Double
    ) {
        self.durationSeconds = durationSeconds
        self.rmsDecibels = rmsDecibels
        self.peakDecibels = peakDecibels
        self.sampleRate = sampleRate
    }
}

public protocol AudioAnalyzing: Sendable {
    func analyzeAudioFile(at url: URL) throws -> AudioMetrics
    func assessCapture(metrics: AudioMetrics, minimumExpectedSeconds: Double) -> CaptureAssessment
}

public struct AudioAnalysisService: AudioAnalyzing, Sendable {
    public init() {}

    public func analyzeAudioFile(at url: URL) throws -> AudioMetrics {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw StudioError.audioFileCorruptedOrMissing
        }

        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: url)
        } catch {
            throw StudioError.audioFileCorruptedOrMissing
        }

        let format = audioFile.processingFormat
        let totalFrames = audioFile.length
        let sampleRate = format.sampleRate
        guard sampleRate > 0, totalFrames > 0 else {
            return AudioMetrics(
                durationSeconds: 0,
                rmsDecibels: -120,
                peakDecibels: -120,
                sampleRate: max(sampleRate, 0)
            )
        }

        let durationSeconds = Double(totalFrames) / sampleRate
        let chunkFrames: AVAudioFrameCount = 16_384
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames) else {
            throw StudioError.audioFileCorruptedOrMissing
        }

        var sumSquares: Double = 0
        var sampleCount: Int64 = 0
        var maxSample: Float = 0

        while audioFile.framePosition < totalFrames {
            buffer.frameLength = 0
            do {
                try audioFile.read(into: buffer)
            } catch {
                throw StudioError.audioFileCorruptedOrMissing
            }
            let framesRead = Int(buffer.frameLength)
            if framesRead == 0 { break }

            if let channelData = buffer.floatChannelData {
                let channelCount = Int(format.channelCount)
                for ch in 0..<channelCount {
                    let samples = channelData[ch]
                    for i in 0..<framesRead {
                        let s = samples[i]
                        let absS = abs(s)
                        if absS > maxSample {
                            maxSample = absS
                        }
                        sumSquares += Double(s) * Double(s)
                        sampleCount += 1
                    }
                }
            }
        }

        let rms = sampleCount > 0 ? sqrt(sumSquares / Double(sampleCount)) : 0
        let rmsDB = rms > 1e-7 ? Float(20.0 * log10(rms)) : -120.0
        let peakDB = maxSample > 1e-7 ? Float(20.0 * log10(Double(maxSample))) : -120.0

        return AudioMetrics(
            durationSeconds: durationSeconds,
            rmsDecibels: rmsDB,
            peakDecibels: peakDB,
            sampleRate: sampleRate
        )
    }

    public func assessCapture(metrics: AudioMetrics, minimumExpectedSeconds: Double) -> CaptureAssessment {
        if metrics.durationSeconds < 0.25 || (metrics.peakDecibels < -52.0 && metrics.rmsDecibels < -58.0) {
            return CaptureAssessment(
                status: .silentOrTooQuiet,
                headline: "Clip appears silent or empty",
                detail: "Very little microphone signal was detected. Check your input device and try recording again."
            )
        }

        let shortThreshold = max(0.9, minimumExpectedSeconds * 0.45)
        if metrics.durationSeconds < shortThreshold {
            return CaptureAssessment(
                status: .unusuallyShort,
                headline: "Clip is unusually short",
                detail: String(
                    format: "Recorded %.1fs; try speaking the full prompt at a steady pace (about %.1fs+).",
                    metrics.durationSeconds,
                    minimumExpectedSeconds
                )
            )
        }

        if metrics.peakDecibels >= -0.35 {
            return CaptureAssessment(
                status: .clippingDetected,
                headline: "Input level is very loud",
                detail: "Peak signal reached near 0 dBFS. Moving slightly back from the microphone can reduce distortion."
            )
        }

        return CaptureAssessment(
            status: .ok,
            headline: "Signal captured",
            detail: String(
                format: "%.1fs recorded (RMS %.0f dBFS).",
                metrics.durationSeconds,
                metrics.rmsDecibels
            )
        )
    }
}
