import Foundation

public enum CorrectionCategory: String, Codable, Equatable, Sendable, CaseIterable, Identifiable {
    case pronunciation = "Pronunciation"
    case stressOrEmphasis = "Stress / Emphasis"
    case pacingOrPause = "Pacing / Pause"
    case properNoun = "Name / Term"

    public var id: String { rawValue }
}

public struct PronunciationCorrection: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let targetPhrase: String
    public let phoneticHint: String
    public let category: CorrectionCategory
    public let audioFileName: String
    public let durationSeconds: Double
    public let createdAt: Date
    public let captureAssessment: CaptureAssessment

    public init(
        id: UUID = UUID(),
        targetPhrase: String,
        phoneticHint: String,
        category: CorrectionCategory,
        audioFileName: String,
        durationSeconds: Double,
        createdAt: Date = Date(),
        captureAssessment: CaptureAssessment
    ) {
        self.id = id
        self.targetPhrase = targetPhrase
        self.phoneticHint = phoneticHint
        self.category = category
        self.audioFileName = audioFileName
        self.durationSeconds = durationSeconds
        self.createdAt = createdAt
        self.captureAssessment = captureAssessment
    }
}
