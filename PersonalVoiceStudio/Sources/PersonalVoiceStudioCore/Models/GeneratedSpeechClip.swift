import Foundation

public enum ExportAudioFormat: String, Codable, Equatable, Sendable, CaseIterable, Identifiable {
    case wav
    case m4a

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .wav: return "WAV (Uncompressed PCM)"
        case .m4a: return "M4A (AAC Audio)"
        }
    }

    public var fileExtension: String { rawValue }
}

public struct GeneratedSpeechClip: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let textPreview: String
    public let fullText: String
    public let audioFileName: String
    public let durationSeconds: Double
    public let sampleRate: Double
    public let createdAt: Date
    public let modelIdentifier: String
    public let speakingRate: Double?
    public let sentencePauseSeconds: Double?
    public let stylePresetID: String?

    public init(
        id: UUID = UUID(),
        fullText: String,
        audioFileName: String,
        durationSeconds: Double,
        sampleRate: Double,
        createdAt: Date = Date(),
        modelIdentifier: String,
        speakingRate: Double? = nil,
        sentencePauseSeconds: Double? = nil,
        stylePresetID: String? = nil
    ) {
        self.id = id
        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 72 {
            self.textPreview = String(trimmed.prefix(72)) + "…"
        } else {
            self.textPreview = trimmed
        }
        self.fullText = fullText
        self.audioFileName = audioFileName
        self.durationSeconds = durationSeconds
        self.sampleRate = sampleRate
        self.createdAt = createdAt
        self.modelIdentifier = modelIdentifier
        self.speakingRate = speakingRate
        self.sentencePauseSeconds = sentencePauseSeconds
        self.stylePresetID = stylePresetID
    }
}
