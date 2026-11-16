import Foundation

public struct ConsentRecord: Codable, Equatable, Sendable {
    public var confirmedOwnVoice: Bool
    public var confirmedAt: Date?
    public var policyVersion: String

    public init(
        confirmedOwnVoice: Bool = false,
        confirmedAt: Date? = nil,
        policyVersion: String = "1.0"
    ) {
        self.confirmedOwnVoice = confirmedOwnVoice
        self.confirmedAt = confirmedAt
        self.policyVersion = policyVersion
    }
}

public enum CaptureAssessmentStatus: String, Codable, Equatable, Sendable {
    case ok
    case silentOrTooQuiet
    case unusuallyShort
    case clippingDetected
}

public struct CaptureAssessment: Codable, Equatable, Sendable {
    public let status: CaptureAssessmentStatus
    public let headline: String
    public let detail: String

    public static let disclaimer =
        "Capture checks verify signal presence and duration only. They do not evaluate or guarantee voice cloning quality."

    public init(status: CaptureAssessmentStatus, headline: String, detail: String) {
        self.status = status
        self.headline = headline
        self.detail = detail
    }

    public var needsAttention: Bool {
        status != .ok
    }
}

public struct PromptRecording: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let promptID: String
    public let audioFileName: String
    public let recordedAt: Date
    public let durationSeconds: Double
    public let rmsDecibels: Float
    public let peakDecibels: Float
    public let sampleRate: Double
    public let captureAssessment: CaptureAssessment

    public init(
        id: UUID = UUID(),
        promptID: String,
        audioFileName: String,
        recordedAt: Date = Date(),
        durationSeconds: Double,
        rmsDecibels: Float,
        peakDecibels: Float,
        sampleRate: Double,
        captureAssessment: CaptureAssessment
    ) {
        self.id = id
        self.promptID = promptID
        self.audioFileName = audioFileName
        self.recordedAt = recordedAt
        self.durationSeconds = durationSeconds
        self.rmsDecibels = rmsDecibels
        self.peakDecibels = peakDecibels
        self.sampleRate = sampleRate
        self.captureAssessment = captureAssessment
    }
}

public struct VoiceProfile: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var displayName: String
    public let createdAt: Date
    public var updatedAt: Date
    public var consent: ConsentRecord
    public var currentPromptIndex: Int
    public var setupPaused: Bool
    public var setupCompleted: Bool
    public var recordings: [String: PromptRecording]
    public var primaryReferencePromptID: String?
    public var corrections: [PronunciationCorrection]
    public var generatedHistory: [GeneratedSpeechClip]
    public var importedModelDirectoryName: String?

    public init(
        id: UUID = UUID(),
        displayName: String = "My Personal Voice",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        consent: ConsentRecord = ConsentRecord(),
        currentPromptIndex: Int = 0,
        setupPaused: Bool = false,
        setupCompleted: Bool = false,
        recordings: [String: PromptRecording] = [:],
        primaryReferencePromptID: String? = nil,
        corrections: [PronunciationCorrection] = [],
        generatedHistory: [GeneratedSpeechClip] = [],
        importedModelDirectoryName: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.consent = consent
        self.currentPromptIndex = currentPromptIndex
        self.setupPaused = setupPaused
        self.setupCompleted = setupCompleted
        self.recordings = recordings
        self.primaryReferencePromptID = primaryReferencePromptID
        self.corrections = corrections
        self.generatedHistory = generatedHistory
        self.importedModelDirectoryName = importedModelDirectoryName
    }

    public var totalRecordedDuration: Double {
        recordings.values.reduce(0) { $0 + $1.durationSeconds }
    }

    public var usableReferenceRecordingsCount: Int {
        recordings.values.filter { $0.captureAssessment.status != .silentOrTooQuiet }.count
    }
}
