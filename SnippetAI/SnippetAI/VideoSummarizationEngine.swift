import AVFoundation
import Foundation
import FoundationModels
import Vision

@MainActor
final class VideoSummarizationEngine {
    private struct FrameAnalysis: Encodable {
        let id: Int
        let time: Double
        let observations: [String]
    }

    private struct ModelResponse: Decodable {
        struct Highlight: Decodable {
            let id: Int
            let reason: String
            let caption: String
        }

        let highlights: [Highlight]
    }

    func summarizeVideoFootage(
        videoAsset: AVAsset,
        targetDurationSeconds: Int
    ) async throws -> [VideoSegmentDecision] {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw AnalysisError.modelUnavailable(String(describing: model.availability))
        }

        let duration = try await videoAsset.load(.duration).seconds
        guard duration.isFinite, duration > 0 else {
            throw AnalysisError.invalidDuration
        }

        let videoTracks = try await videoAsset.loadTracks(withMediaType: .video)
        guard !videoTracks.isEmpty else {
            throw AnalysisError.noVideoTrack
        }

        let analyses = try await analyzeFrames(
            from: videoAsset,
            duration: duration
        )
        guard !analyses.isEmpty else {
            throw AnalysisError.noFrames
        }

        let promptData = try JSONEncoder().encode(analyses)
        let promptFrames = String(decoding: promptData, as: UTF8.self)
        let session = LanguageModelSession(
            model: model,
            instructions: """
            You create concise video highlight edits. Choose moments that are \
            visually meaningful, varied, and useful to a viewer. You only know \
            the frame descriptions supplied by the user; do not invent events \
            or dialogue. Return only valid JSON with this shape: \
            {"highlights":[{"id":0,"reason":"short reason","caption":"short caption"}]}. \
            Use only IDs present in the input, do not repeat IDs, and select no \
            more moments than the requested duration in seconds.
            """
        )
        let response = try await session.respond(to: """
            Select up to \(max(1, targetDurationSeconds)) seconds of highlights
            from these sampled video frames. Each selected frame represents one
            second beginning at its time. Return JSON only.
            Frames: \(promptFrames)
            """)

        let modelResult = try decodeModelResponse(response.content)
        let validFrames = Dictionary(uniqueKeysWithValues: analyses.map { ($0.id, $0) })
        let selected = modelResult.highlights
            .filter { validFrames[$0.id] != nil }
            .reduce(into: [Int: ModelResponse.Highlight]()) { unique, highlight in
                if unique[highlight.id] == nil {
                    unique[highlight.id] = highlight
                }
            }
            .values
            .sorted { validFrames[$0.id]!.time < validFrames[$1.id]!.time }
            .prefix(max(1, targetDurationSeconds))

        return selected.compactMap { highlight in
            guard let frame = validFrames[highlight.id] else { return nil }
            let end = min(frame.time + 1, duration)
            guard end > frame.time else { return nil }
            return VideoSegmentDecision(
                timeRange: CMTimeRange(
                    start: CMTime(seconds: frame.time, preferredTimescale: 600),
                    end: CMTime(seconds: end, preferredTimescale: 600)
                ),
                keep: true,
                reason: highlight.reason,
                caption: highlight.caption
            )
        }
    }

    private func analyzeFrames(
        from asset: AVAsset,
        duration: Double
    ) async throws -> [FrameAnalysis] {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 512, height: 512)
        let sampleInterval = max(1, Int(ceil(duration / 60)))
        let sampleCount = min(60, Int(ceil(duration / Double(sampleInterval))))
        var frames: [FrameAnalysis] = []
        frames.reserveCapacity(sampleCount)

        for id in 0..<sampleCount {
            try Task.checkCancellation()
            let time = min(
                Double(id * sampleInterval),
                max(0, duration - 0.05)
            )
            let (image, _) = try await generator.image(
                at: CMTime(seconds: time, preferredTimescale: 600)
            )
            let request = VNClassifyImageRequest()
            try VNImageRequestHandler(cgImage: image).perform([request])
            let observations = (request.results ?? [])
                .prefix(3)
                .map { "\($0.identifier) (\(Int($0.confidence * 100))%)" }
            frames.append(FrameAnalysis(id: id, time: time, observations: observations))
        }
        return frames
    }

    private func decodeModelResponse(_ text: String) throws -> ModelResponse {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"),
              start <= end else {
            throw AnalysisError.invalidModelResponse
        }
        let json = String(text[start...end])
        do {
            return try JSONDecoder().decode(ModelResponse.self, from: Data(json.utf8))
        } catch {
            throw AnalysisError.invalidModelResponse
        }
    }

    enum AnalysisError: LocalizedError {
        case invalidDuration
        case noVideoTrack
        case noFrames
        case modelUnavailable(String)
        case invalidModelResponse

        var errorDescription: String? {
            switch self {
            case .invalidDuration:
                "The selected video has no valid duration."
            case .noVideoTrack:
                "The selected file does not contain a video track."
            case .noFrames:
                "No video frames could be analyzed."
            case .modelUnavailable(let reason):
                "On-device Apple Intelligence is unavailable (\(reason)). Enable it or use a compatible device."
            case .invalidModelResponse:
                "The on-device model returned an invalid highlight selection. Please try again."
            }
        }
    }
}
