import Foundation

public struct SceneGenerationRequest: Equatable, Sendable {
    public let referenceImageURLs: [URL]
    public let behaviorPrompt: String
    public let drivingAudioURL: URL?
    public let outputVideoURL: URL
    public let aspectRatio: ExportAspectRatio
    public let targetFrameRate: Int
    public let durationSeconds: Double
    public let enableLipSync: Bool

    public init(
        referenceImageURLs: [URL],
        behaviorPrompt: String,
        drivingAudioURL: URL?,
        outputVideoURL: URL,
        aspectRatio: ExportAspectRatio,
        targetFrameRate: Int,
        durationSeconds: Double,
        enableLipSync: Bool = true
    ) {
        self.referenceImageURLs = referenceImageURLs
        self.behaviorPrompt = behaviorPrompt
        self.drivingAudioURL = drivingAudioURL
        self.outputVideoURL = outputVideoURL
        self.aspectRatio = aspectRatio
        self.targetFrameRate = targetFrameRate
        self.durationSeconds = durationSeconds
        self.enableLipSync = enableLipSync
    }
}

public struct SceneGenerationResult: Equatable, Sendable {
    public let generatedClipURL: URL
    public let durationSeconds: Double
    public let modelIdentifier: String

    public init(generatedClipURL: URL, durationSeconds: Double, modelIdentifier: String) {
        self.generatedClipURL = generatedClipURL
        self.durationSeconds = durationSeconds
        self.modelIdentifier = modelIdentifier
    }
}

public protocol SceneGenerationEngine: Sendable {
    var descriptor: VideoModelEngineDescriptor { get }
    func currentReadiness(modelDirectory: URL) -> ModelReadinessState
    func currentCapabilities(modelDirectory: URL) -> VideoModelCapabilities
    func validateModel(at directoryURL: URL) throws -> ValidatedVideoModelBundle
    func loadModel(from directoryURL: URL) async throws
    func unloadModel() async
    func generateSceneClip(
        _ request: SceneGenerationRequest,
        progress: @escaping @Sendable (VideoRenderProgress) -> Void
    ) async throws -> SceneGenerationResult
}
