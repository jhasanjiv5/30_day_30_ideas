import Foundation

public final class LocalSceneGenerationEngine: SceneGenerationEngine, @unchecked Sendable {
    public let descriptor = VideoModelEngineDescriptor(
        id: "local-visual-text-lipsync-gated",
        displayName: "On-Device Visual-Text + Audio Lip-Sync Pipeline (Capability-Gated)",
        runtimeStatusNote: "No local Image-to-Video diffusion runtime or neural lip-sync weights are bundled in the MVP build. Generating subject actions (such as playing guitar with hand movement) and lip-syncing to music requires an Apple Silicon Mac (16+ GB unified memory), a linked local MLX/CoreML runtime, and user-imported offline model weights.",
        supportedPipelineStages: [
            "Stage 1 — Visual-Text Image-to-Video (e.g. Wan2.1-I2V / LTX-Video via MLX): animates supplied people + scene behavior text (e.g. playing guitar, hand motion)",
            "Stage 2 — Audio-Driven Portrait Lip-Sync (e.g. EchoMimic / Hallo2 / Wav2Lip via CoreML/MLX): synchronizes mouth & facial expressions to supplied music or .wav narration"
        ],
        expectedBundleFormats: [".safetensors", ".gguf", ".mlmodelc", ".mlpackage"],
        licenseRequirementsNote: "User-imported models (such as Apache-2.0 Wan2.1 weights or MIT/Apache lip-sync checkpoints) must retain their upstream LICENSE/NOTICE files and are never downloaded inside this app."
    )

    private let validator: OfflineVideoModelValidator
    private let fileManager: FileManager
    private let isAppleSilicon: Bool
    private let physicalMemoryGB: Int
    private let isRuntimeLinked: Bool

    public init(
        validator: OfflineVideoModelValidator = OfflineVideoModelValidator(),
        fileManager: FileManager = .default,
        isAppleSilicon: Bool = LocalSceneGenerationEngine.detectAppleSilicon(),
        physicalMemoryGB: Int = LocalSceneGenerationEngine.detectPhysicalMemoryGB(),
        isRuntimeLinked: Bool = false
    ) {
        self.validator = validator
        self.fileManager = fileManager
        self.isAppleSilicon = isAppleSilicon
        self.physicalMemoryGB = physicalMemoryGB
        self.isRuntimeLinked = isRuntimeLinked
    }

    public static func detectAppleSilicon() -> Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }

    public static func detectPhysicalMemoryGB() -> Int {
        Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024))
    }

    public func currentReadiness(modelDirectory: URL) -> ModelReadinessState {
        guard isAppleSilicon else {
            return .unsupportedArchitecture(
                guidance: "Local Visual-Text Image-to-Video and neural lip-sync require Apple Silicon (arm64). Non-AI storyboard editing and AVFoundation export remain available."
            )
        }

        let contents = (try? fileManager.contentsOfDirectory(atPath: modelDirectory.path)) ?? []
        if contents.isEmpty {
            if !isRuntimeLinked {
                return .engineNotLinked(
                    guidance: "No local Visual-Text / Lip-Sync inference runtime is linked in this MVP build, and no local model folder is imported. Storyboard motion, overlays, and audio export remain ready offline."
                )
            }
            return .weightsMissing(
                guidance: "Import an unpacked offline Visual-Text + Lip-Sync model folder containing model_manifest.json (or config.json) and weights."
            )
        }

        let bundle: ValidatedVideoModelBundle
        do {
            bundle = try validator.validate(directoryURL: modelDirectory)
        } catch {
            return .invalidBundle(reason: error.localizedDescription)
        }

        if physicalMemoryGB < bundle.capabilities.minimumUnifiedMemoryGB {
            return .insufficientMemory(
                guidance: "Imported model '\(bundle.modelArchitecture)' requires at least \(bundle.capabilities.minimumUnifiedMemoryGB) GB unified memory (detected \(physicalMemoryGB) GB)."
            )
        }

        guard isRuntimeLinked else {
            return .engineNotLinked(
                guidance: "Model folder '\(bundle.modelArchitecture)' is validated locally, but the native MLX/CoreML video diffusion + lip-sync runtime is not linked in this MVP build."
            )
        }

        return .ready(bundle: bundle)
    }

    public func currentCapabilities(modelDirectory: URL) -> VideoModelCapabilities {
        guard case .ready(let bundle) = currentReadiness(modelDirectory: modelDirectory) else {
            return .unavailable
        }
        return bundle.capabilities
    }

    public func validateModel(at directoryURL: URL) throws -> ValidatedVideoModelBundle {
        try validator.validate(directoryURL: directoryURL)
    }

    public func loadModel(from directoryURL: URL) async throws {
        guard isAppleSilicon else {
            throw VideoStudioError.aiGenerationUnavailable(
                reason: "Apple Silicon (arm64) is required for local Visual-Text + Lip-Sync inference."
            )
        }
        guard isRuntimeLinked else {
            throw VideoStudioError.aiGenerationUnavailable(
                reason: "No local Visual-Text + Lip-Sync runtime is linked in this MVP build. Placeholder video frames are never fabricated."
            )
        }
        let bundle = try validator.validate(directoryURL: directoryURL)
        if physicalMemoryGB < bundle.capabilities.minimumUnifiedMemoryGB {
            throw VideoStudioError.aiGenerationUnavailable(
                reason: "Insufficient unified memory (\(physicalMemoryGB) GB available, \(bundle.capabilities.minimumUnifiedMemoryGB) GB required)."
            )
        }
    }

    public func unloadModel() async {}

    public func generateSceneClip(
        _ request: SceneGenerationRequest,
        progress: @escaping @Sendable (VideoRenderProgress) -> Void
    ) async throws -> SceneGenerationResult {
        guard !request.referenceImageURLs.isEmpty else {
            throw VideoStudioError.invalidScene(
                reason: "Supply at least one reference portrait or scene image before running Visual-Text generation."
            )
        }
        guard !request.behaviorPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw VideoStudioError.invalidScene(
                reason: "Enter a scene behavior prompt (for example: 'Woman playing acoustic guitar with hand movement and lip-syncing to music')."
            )
        }

        throw VideoStudioError.aiGenerationUnavailable(
            reason: "On-device Visual-Text + Audio Lip-Sync generation is unavailable in this MVP build because no local diffusion/lip-sync runtime (MLX/CoreML) is linked. Your reference images, behavior prompt, and music track are saved safely; use standard storyboard motion and AVFoundation export or link a local Apple Silicon backend."
        )
    }
}
