import Foundation

public enum SceneMediaKind: String, Codable, CaseIterable, Equatable, Sendable {
    case image
    case video

    public var displayName: String {
        switch self {
        case .image: return "Still Image"
        case .video: return "Video Clip"
        }
    }
}

public enum SceneTransitionKind: String, Codable, CaseIterable, Equatable, Sendable {
    case cut
    case crossDissolve

    public var displayName: String {
        switch self {
        case .cut: return "Hard Cut"
        case .crossDissolve: return "Cross Dissolve"
        }
    }
}

public enum StillMotionEffect: String, Codable, CaseIterable, Equatable, Sendable {
    case none
    case kenBurnsZoomIn
    case kenBurnsZoomOut
    case panLeftToRight
    case panRightToLeft
    case subtleBeatPulse

    public var displayName: String {
        switch self {
        case .none: return "Static Frame"
        case .kenBurnsZoomIn: return "Slow Zoom In"
        case .kenBurnsZoomOut: return "Slow Zoom Out"
        case .panLeftToRight: return "Pan Left to Right"
        case .panRightToLeft: return "Pan Right to Left"
        case .subtleBeatPulse: return "Subtle Pulse"
        }
    }
}

public enum OverlayPlacement: String, Codable, CaseIterable, Equatable, Sendable {
    case top
    case center
    case bottom

    public var displayName: String {
        switch self {
        case .top: return "Top"
        case .center: return "Center"
        case .bottom: return "Lower Third"
        }
    }
}

public struct StoryboardScene: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var titleOverlay: String
    public var captionScript: String
    /// Visual-text prompt describing how the subject(s) in the supplied image(s)
    /// should act in the scene (for example: "Woman playing acoustic guitar with natural hand movement and lip-syncing to music").
    public var behaviorPrompt: String
    public var mediaKind: SceneMediaKind
    public var mediaFileName: String?
    /// Optional additional reference portraits of people used by a local Visual-Text + Lip-Sync model.
    public var referenceImageFileNames: [String]
    /// Optional locally generated video clip produced by a validated SceneGenerationEngine backend.
    public var generatedVideoFileName: String?
    public var durationSeconds: Double
    public var transition: SceneTransitionKind
    public var transitionDurationSeconds: Double
    public var motionEffect: StillMotionEffect
    public var overlayPlacement: OverlayPlacement
    public var enableLipSyncWithAudio: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        titleOverlay: String = "",
        captionScript: String = "",
        behaviorPrompt: String = "",
        mediaKind: SceneMediaKind = .image,
        mediaFileName: String? = nil,
        referenceImageFileNames: [String] = [],
        generatedVideoFileName: String? = nil,
        durationSeconds: Double = 4.0,
        transition: SceneTransitionKind = .crossDissolve,
        transitionDurationSeconds: Double = 0.5,
        motionEffect: StillMotionEffect = .kenBurnsZoomIn,
        overlayPlacement: OverlayPlacement = .bottom,
        enableLipSyncWithAudio: Bool = true
    ) {
        self.id = id
        self.title = title
        self.titleOverlay = titleOverlay
        self.captionScript = captionScript
        self.behaviorPrompt = behaviorPrompt
        self.mediaKind = mediaKind
        self.mediaFileName = mediaFileName
        self.referenceImageFileNames = referenceImageFileNames
        self.generatedVideoFileName = generatedVideoFileName
        self.durationSeconds = durationSeconds
        self.transition = transition
        self.transitionDurationSeconds = transitionDurationSeconds
        self.motionEffect = motionEffect
        self.overlayPlacement = overlayPlacement
        self.enableLipSyncWithAudio = enableLipSyncWithAudio
    }

    public var allReferenceMediaFileNames: [String] {
        var combined: [String] = []
        if let primary = mediaFileName, !primary.isEmpty {
            combined.append(primary)
        }
        for extra in referenceImageFileNames where !extra.isEmpty && !combined.contains(extra) {
            combined.append(extra)
        }
        return combined
    }

    public func validate(sceneNumber: Int) throws {
        guard durationSeconds >= 0.5 && durationSeconds <= 300.0 else {
            throw VideoStudioError.invalidScene(
                reason: "Scene \(sceneNumber) duration must be between 0.5 and 300 seconds."
            )
        }
        guard transitionDurationSeconds >= 0.0 && transitionDurationSeconds <= min(2.0, durationSeconds / 2.0) else {
            throw VideoStudioError.invalidScene(
                reason: "Scene \(sceneNumber) transition duration must fit within half the scene duration (max 2.0s)."
            )
        }
        let hasMedia = (mediaFileName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            || (generatedVideoFileName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        let hasText = !titleOverlay.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !captionScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasMedia || hasText else {
            throw VideoStudioError.invalidScene(
                reason: "Scene \(sceneNumber) needs either a local image/video file or a title/caption overlay."
            )
        }
    }
}
