import Foundation

public struct RequirementCheckItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let isSatisfied: Bool
    public let detail: String

    public init(id: String, title: String, isSatisfied: Bool, detail: String) {
        self.id = id
        self.title = title
        self.isSatisfied = isSatisfied
        self.detail = detail
    }
}

public struct VideoGenerationRequirementsReport: Equatable, Sendable {
    public let hardwareArchitectureName: String
    public let unifiedMemoryGB: Int
    public let freeDiskSpaceGB: Double
    public let items: [RequirementCheckItem]

    public var isReadyForAIGeneration: Bool {
        items.allSatisfy(\.isSatisfied)
    }

    public init(
        hardwareArchitectureName: String,
        unifiedMemoryGB: Int,
        freeDiskSpaceGB: Double,
        items: [RequirementCheckItem]
    ) {
        self.hardwareArchitectureName = hardwareArchitectureName
        self.unifiedMemoryGB = unifiedMemoryGB
        self.freeDiskSpaceGB = freeDiskSpaceGB
        self.items = items
    }
}

public enum VideoGenerationRequirementsChecker {
    public static func evaluate(
        isAppleSilicon: Bool = LocalSceneGenerationEngine.detectAppleSilicon(),
        unifiedMemoryGB: Int = LocalSceneGenerationEngine.detectPhysicalMemoryGB(),
        freeDiskBytes: Int64,
        modelReadiness: ModelReadinessState,
        activeProject: VideoProject?,
        selectedScene: StoryboardScene?,
        isRuntimeLinked: Bool = false
    ) -> VideoGenerationRequirementsReport {
        let freeGB = Double(max(0, freeDiskBytes)) / (1024.0 * 1024.0 * 1024.0)
        let archName = isAppleSilicon ? "Apple Silicon (arm64)" : "Intel (x86_64)"

        var requiredMemoryGB = 16
        if case .ready(let bundle) = modelReadiness {
            requiredMemoryGB = bundle.capabilities.minimumUnifiedMemoryGB
        }

        let hasSceneMedia = selectedScene?.allReferenceMediaFileNames.isEmpty == false
        let hasBehaviorPrompt = selectedScene?.behaviorPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasAudio = activeProject?.audioTracks.isEmpty == false

        let items: [RequirementCheckItem] = [
            RequirementCheckItem(
                id: "arch",
                title: "Apple Silicon Mac (arm64)",
                isSatisfied: isAppleSilicon,
                detail: isAppleSilicon
                    ? "Detected Apple Silicon for Metal / MLX unified memory execution."
                    : "Detected \(archName). On-device Visual-Text + Lip-Sync models require Apple Silicon."
            ),
            RequirementCheckItem(
                id: "ram",
                title: "Unified Memory (>= \(requiredMemoryGB) GB)",
                isSatisfied: unifiedMemoryGB >= requiredMemoryGB,
                detail: "Detected \(unifiedMemoryGB) GB unified memory (recommend 16 GB minimum, 32+ GB for Wan2.1 720p)."
            ),
            RequirementCheckItem(
                id: "disk",
                title: "Free Disk Space (>= 20 GB recommended for model weights + renders)",
                isSatisfied: freeGB >= 20.0,
                detail: String(format: "%.1f GB currently available on target volume.", freeGB)
            ),
            RequirementCheckItem(
                id: "weights",
                title: "Offline Model Folder Validated",
                isSatisfied: {
                    switch modelReadiness {
                    case .ready: return true
                    case .engineNotLinked(let guidance):
                        return guidance.contains("is validated locally")
                    default:
                        return false
                    }
                }(),
                detail: modelReadiness.statusDetail
            ),
            RequirementCheckItem(
                id: "runtime",
                title: "Local MLX / CoreML Video Runtime Linked",
                isSatisfied: isRuntimeLinked,
                detail: isRuntimeLinked
                    ? "Local inference runtime is linked."
                    : "MVP build omits multi-GB MLX diffusion/lip-sync runtime; capability remains gated until linked."
            ),
            RequirementCheckItem(
                id: "scene-inputs",
                title: "Scene Inputs (Reference Image + Behavior Prompt + Audio Track)",
                isSatisfied: hasSceneMedia && hasBehaviorPrompt && hasAudio,
                detail: "Requires at least 1 subject portrait, a non-empty behavior prompt, and an imported music or .wav narration track."
            )
        ]

        return VideoGenerationRequirementsReport(
            hardwareArchitectureName: archName,
            unifiedMemoryGB: unifiedMemoryGB,
            freeDiskSpaceGB: freeGB,
            items: items
        )
    }
}
