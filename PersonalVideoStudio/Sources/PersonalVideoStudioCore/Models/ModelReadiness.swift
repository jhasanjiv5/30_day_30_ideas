import Foundation

public struct VideoModelCapabilities: Codable, Equatable, Sendable {
    public let supportsImageToVideo: Bool
    public let supportsBehaviorTextPrompt: Bool
    public let supportsBodyAndHandMotion: Bool
    public let supportsPortraitLipSync: Bool
    public let supportsAudioConditioning: Bool
    public let minimumUnifiedMemoryGB: Int
    public let maxClipDurationSeconds: Double
    public let supportedAudioSampleRates: [Int]

    public init(
        supportsImageToVideo: Bool,
        supportsBehaviorTextPrompt: Bool,
        supportsBodyAndHandMotion: Bool,
        supportsPortraitLipSync: Bool,
        supportsAudioConditioning: Bool,
        minimumUnifiedMemoryGB: Int = 16,
        maxClipDurationSeconds: Double = 10.0,
        supportedAudioSampleRates: [Int] = []
    ) {
        self.supportsImageToVideo = supportsImageToVideo
        self.supportsBehaviorTextPrompt = supportsBehaviorTextPrompt
        self.supportsBodyAndHandMotion = supportsBodyAndHandMotion
        self.supportsPortraitLipSync = supportsPortraitLipSync
        self.supportsAudioConditioning = supportsAudioConditioning
        self.minimumUnifiedMemoryGB = minimumUnifiedMemoryGB
        self.maxClipDurationSeconds = maxClipDurationSeconds
        self.supportedAudioSampleRates = supportedAudioSampleRates
    }

    public static let unavailable = VideoModelCapabilities(
        supportsImageToVideo: false,
        supportsBehaviorTextPrompt: false,
        supportsBodyAndHandMotion: false,
        supportsPortraitLipSync: false,
        supportsAudioConditioning: false,
        minimumUnifiedMemoryGB: 16,
        maxClipDurationSeconds: 0,
        supportedAudioSampleRates: []
    )
}

public struct VideoModelEngineDescriptor: Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let runtimeStatusNote: String
    public let supportedPipelineStages: [String]
    public let expectedBundleFormats: [String]
    public let licenseRequirementsNote: String

    public init(
        id: String,
        displayName: String,
        runtimeStatusNote: String,
        supportedPipelineStages: [String],
        expectedBundleFormats: [String],
        licenseRequirementsNote: String
    ) {
        self.id = id
        self.displayName = displayName
        self.runtimeStatusNote = runtimeStatusNote
        self.supportedPipelineStages = supportedPipelineStages
        self.expectedBundleFormats = expectedBundleFormats
        self.licenseRequirementsNote = licenseRequirementsNote
    }
}

public struct ValidatedVideoModelBundle: Codable, Equatable, Sendable {
    public let directoryPath: String
    public let modelArchitecture: String
    public let runtimeFormat: String
    public let capabilities: VideoModelCapabilities
    public let weightFiles: [String]
    public let metadataFiles: [String]
    public let totalSizeBytes: Int64
    public let validatedAt: Date

    public init(
        directoryPath: String,
        modelArchitecture: String,
        runtimeFormat: String,
        capabilities: VideoModelCapabilities,
        weightFiles: [String],
        metadataFiles: [String],
        totalSizeBytes: Int64,
        validatedAt: Date = Date()
    ) {
        self.directoryPath = directoryPath
        self.modelArchitecture = modelArchitecture
        self.runtimeFormat = runtimeFormat
        self.capabilities = capabilities
        self.weightFiles = weightFiles
        self.metadataFiles = metadataFiles
        self.totalSizeBytes = totalSizeBytes
        self.validatedAt = validatedAt
    }
}

public enum ModelReadinessState: Equatable, Sendable {
    case ready(bundle: ValidatedVideoModelBundle)
    case weightsMissing(guidance: String)
    case engineNotLinked(guidance: String)
    case unsupportedArchitecture(guidance: String)
    case insufficientMemory(guidance: String)
    case invalidBundle(reason: String)

    public var isReadyForInference: Bool {
        if case .ready = self { return true }
        return false
    }

    public var statusTitle: String {
        switch self {
        case .ready:
            return "Local Visual-Text & Lip-Sync Model Ready"
        case .weightsMissing:
            return "No Local Video Model Weights Imported"
        case .engineNotLinked:
            return "Local Visual-Text Video Runtime Not Linked"
        case .unsupportedArchitecture:
            return "Unsupported Hardware Architecture"
        case .insufficientMemory:
            return "Insufficient Unified Memory for Local Video Model"
        case .invalidBundle:
            return "Invalid Local Model Folder"
        }
    }

    public var statusDetail: String {
        switch self {
        case .ready(let bundle):
            let gb = Double(bundle.totalSizeBytes) / (1024.0 * 1024.0 * 1024.0)
            return String(
                format: "Validated %@ (%@, %d weight file(s), %.2f GB) stored locally on this Mac.",
                bundle.modelArchitecture,
                bundle.runtimeFormat,
                bundle.weightFiles.count,
                gb
            )
        case .weightsMissing(let guidance),
             .engineNotLinked(let guidance),
             .unsupportedArchitecture(let guidance),
             .insufficientMemory(let guidance):
            return guidance
        case .invalidBundle(let reason):
            return reason
        }
    }
}
