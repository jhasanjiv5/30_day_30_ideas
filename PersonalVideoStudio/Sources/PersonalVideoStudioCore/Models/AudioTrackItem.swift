import Foundation

public enum AudioTrackRole: String, Codable, CaseIterable, Equatable, Sendable {
    case narration
    case music

    public var displayName: String {
        switch self {
        case .narration: return "Narration / Vocals"
        case .music: return "Background Music"
        }
    }
}

public struct AudioTrackItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var role: AudioTrackRole
    public var displayName: String
    public var fileName: String
    public var sourceFormat: String
    public var sourceDurationSeconds: Double
    public var sampleRate: Double
    public var trimStartSeconds: Double
    public var trimEndSeconds: Double
    public var startOffsetSeconds: Double
    public var volume: Double

    public init(
        id: UUID = UUID(),
        role: AudioTrackRole,
        displayName: String,
        fileName: String,
        sourceFormat: String,
        sourceDurationSeconds: Double,
        sampleRate: Double = 44_100,
        trimStartSeconds: Double = 0,
        trimEndSeconds: Double? = nil,
        startOffsetSeconds: Double = 0,
        volume: Double? = nil
    ) {
        self.id = id
        self.role = role
        self.displayName = displayName
        self.fileName = fileName
        self.sourceFormat = sourceFormat
        self.sourceDurationSeconds = sourceDurationSeconds
        self.sampleRate = sampleRate
        self.trimStartSeconds = max(0, trimStartSeconds)
        self.trimEndSeconds = min(sourceDurationSeconds, trimEndSeconds ?? sourceDurationSeconds)
        self.startOffsetSeconds = max(0, startOffsetSeconds)
        self.volume = volume ?? (role == .narration ? 1.0 : 0.45)
    }

    public var trimmedDurationSeconds: Double {
        max(0, trimEndSeconds - trimStartSeconds)
    }

    public func validate() throws {
        guard sourceDurationSeconds > 0 else {
            throw VideoStudioError.invalidAudioTrack(reason: "\(displayName) has an invalid zero duration.")
        }
        guard trimStartSeconds >= 0 && trimStartSeconds < trimEndSeconds else {
            throw VideoStudioError.invalidAudioTrack(reason: "\(displayName) trim start must precede trim end.")
        }
        guard trimEndSeconds <= sourceDurationSeconds + 0.01 else {
            throw VideoStudioError.invalidAudioTrack(reason: "\(displayName) trim end exceeds audio file length.")
        }
        guard volume >= 0.0 && volume <= 1.5 else {
            throw VideoStudioError.invalidAudioTrack(reason: "\(displayName) volume must be between 0% and 150%.")
        }
    }
}
