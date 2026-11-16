import Foundation

public struct VoiceStylePreset: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let summary: String

    public init(id: String, name: String, summary: String) {
        self.id = id
        self.name = name
        self.summary = summary
    }
}

public struct ModelCapabilities: Codable, Equatable, Sendable {
    public let supportsZeroShotVoiceCloning: Bool
    public let supportsSpeakingRate: Bool
    public let speakingRateRange: ClosedRange<Double>
    public let supportsPauseControl: Bool
    public let pauseDurationRange: ClosedRange<Double>
    public let supportedStylePresets: [VoiceStylePreset]
    public let supportsCorrectionConditioning: Bool
    public let supportedLanguages: [String]

    public init(
        supportsZeroShotVoiceCloning: Bool,
        supportsSpeakingRate: Bool,
        speakingRateRange: ClosedRange<Double> = 0.8...1.2,
        supportsPauseControl: Bool,
        pauseDurationRange: ClosedRange<Double> = 0.15...1.0,
        supportedStylePresets: [VoiceStylePreset] = [],
        supportsCorrectionConditioning: Bool = false,
        supportedLanguages: [String] = ["English"]
    ) {
        self.supportsZeroShotVoiceCloning = supportsZeroShotVoiceCloning
        self.supportsSpeakingRate = supportsSpeakingRate
        self.speakingRateRange = speakingRateRange
        self.supportsPauseControl = supportsPauseControl
        self.pauseDurationRange = pauseDurationRange
        self.supportedStylePresets = supportedStylePresets
        self.supportsCorrectionConditioning = supportsCorrectionConditioning
        self.supportedLanguages = supportedLanguages
    }

    public static let unavailable = ModelCapabilities(
        supportsZeroShotVoiceCloning: false,
        supportsSpeakingRate: false,
        supportsPauseControl: false,
        supportedStylePresets: [],
        supportsCorrectionConditioning: false,
        supportedLanguages: []
    )
}

public struct ModelEngineDescriptor: Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let enginePackageName: String
    public let enginePackageURL: String
    public let engineLicense: String
    public let targetModelName: String
    public let targetModelVersion: String
    public let modelLicense: String
    public let attributionNotice: String

    public init(
        id: String,
        displayName: String,
        enginePackageName: String,
        enginePackageURL: String,
        engineLicense: String,
        targetModelName: String,
        targetModelVersion: String,
        modelLicense: String,
        attributionNotice: String
    ) {
        self.id = id
        self.displayName = displayName
        self.enginePackageName = enginePackageName
        self.enginePackageURL = enginePackageURL
        self.engineLicense = engineLicense
        self.targetModelName = targetModelName
        self.targetModelVersion = targetModelVersion
        self.modelLicense = modelLicense
        self.attributionNotice = attributionNotice
    }
}

public struct ValidatedModelBundle: Codable, Equatable, Sendable {
    public let directoryPath: String
    public let modelType: String
    public let weightFiles: [String]
    public let tokenizerFiles: [String]
    public let totalSizeBytes: Int64
    public let validatedAt: Date

    public init(
        directoryPath: String,
        modelType: String,
        weightFiles: [String],
        tokenizerFiles: [String],
        totalSizeBytes: Int64,
        validatedAt: Date = Date()
    ) {
        self.directoryPath = directoryPath
        self.modelType = modelType
        self.weightFiles = weightFiles
        self.tokenizerFiles = tokenizerFiles
        self.totalSizeBytes = totalSizeBytes
        self.validatedAt = validatedAt
    }
}

public enum ModelReadinessState: Equatable, Sendable {
    case ready(bundle: ValidatedModelBundle)
    case weightsMissing(guidance: String)
    case engineNotLinked(guidance: String)
    case unsupportedArchitecture(guidance: String)
    case invalidBundle(reason: String)

    public var isReadyForInference: Bool {
        if case .ready = self { return true }
        return false
    }

    public var statusTitle: String {
        switch self {
        case .ready:
            return "Ready for Offline Generation"
        case .weightsMissing:
            return "Local Model Weights Not Imported"
        case .engineNotLinked:
            return "Inference Package Not Linked"
        case .unsupportedArchitecture:
            return "Unsupported Hardware Architecture"
        case .invalidBundle:
            return "Invalid Local Model Folder"
        }
    }

    public var statusDetail: String {
        switch self {
        case .ready(let bundle):
            let mb = Double(bundle.totalSizeBytes) / (1024.0 * 1024.0)
            return String(
                format: "Validated %@ (%d weight file(s), %.1f MB) stored locally on this Mac.",
                bundle.modelType,
                bundle.weightFiles.count,
                mb
            )
        case .weightsMissing(let guidance),
             .engineNotLinked(let guidance),
             .unsupportedArchitecture(let guidance):
            return guidance
        case .invalidBundle(let reason):
            return reason
        }
    }
}
