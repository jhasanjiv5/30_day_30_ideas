import Foundation

public struct ReferenceAudioSample: Equatable, Sendable {
    public let audioURL: URL
    public let transcript: String

    public init(audioURL: URL, transcript: String) {
        self.audioURL = audioURL
        self.transcript = transcript
    }
}

public struct SynthesisRequest: Equatable, Sendable {
    public let text: String
    public let referenceSample: ReferenceAudioSample
    public let outputWAVURL: URL
    public let language: String
    public let speakingRate: Double?
    public let sentencePauseSeconds: Double?
    public let stylePresetID: String?

    public init(
        text: String,
        referenceSample: ReferenceAudioSample,
        outputWAVURL: URL,
        language: String = "English",
        speakingRate: Double? = nil,
        sentencePauseSeconds: Double? = nil,
        stylePresetID: String? = nil
    ) {
        self.text = text
        self.referenceSample = referenceSample
        self.outputWAVURL = outputWAVURL
        self.language = language
        self.speakingRate = speakingRate
        self.sentencePauseSeconds = sentencePauseSeconds
        self.stylePresetID = stylePresetID
    }
}

public struct SynthesisResult: Equatable, Sendable {
    public let audioURL: URL
    public let durationSeconds: Double
    public let sampleRate: Double
    public let modelIdentifier: String

    public init(
        audioURL: URL,
        durationSeconds: Double,
        sampleRate: Double,
        modelIdentifier: String
    ) {
        self.audioURL = audioURL
        self.durationSeconds = durationSeconds
        self.sampleRate = sampleRate
        self.modelIdentifier = modelIdentifier
    }
}

public protocol VoiceSynthesisEngine: Sendable {
    var descriptor: ModelEngineDescriptor { get }
    var capabilities: ModelCapabilities { get }

    func currentReadiness(localModelDirectory: URL) -> ModelReadinessState
    func validateLocalModel(at directoryURL: URL) throws -> ValidatedModelBundle
    func loadModel(from directoryURL: URL) async throws
    func unloadModel() async
    func synthesize(_ request: SynthesisRequest) async throws -> SynthesisResult
}
