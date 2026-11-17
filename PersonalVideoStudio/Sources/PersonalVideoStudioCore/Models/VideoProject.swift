import Foundation

public struct VideoProject: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var scriptNotes: String
    public var scenes: [StoryboardScene]
    public var audioTracks: [AudioTrackItem]
    public var exportConfiguration: ExportConfiguration
    public var renders: [RenderedVideoRecord]
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        scriptNotes: String = "",
        scenes: [StoryboardScene] = [],
        audioTracks: [AudioTrackItem] = [],
        exportConfiguration: ExportConfiguration = .default1080pLandscape,
        renders: [RenderedVideoRecord] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.scriptNotes = scriptNotes
        self.scenes = scenes
        self.audioTracks = audioTracks
        self.exportConfiguration = exportConfiguration
        self.renders = renders
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var totalDurationSeconds: Double {
        scenes.reduce(0) { $0 + max(0.5, $1.durationSeconds) }
    }

    public var narrationTrack: AudioTrackItem? {
        audioTracks.first { $0.role == .narration }
    }

    public var musicTrack: AudioTrackItem? {
        audioTracks.first { $0.role == .music }
    }

    public func validateForExport() throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw VideoStudioError.invalidProject(reason: "Project title cannot be empty.")
        }
        guard !scenes.isEmpty else {
            throw VideoStudioError.invalidProject(reason: "Add at least one scene before exporting a video.")
        }
        for (index, scene) in scenes.enumerated() {
            try scene.validate(sceneNumber: index + 1)
        }
        try exportConfiguration.validate()
    }
}

public struct RenderedVideoRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let fileName: String
    public let width: Int
    public let height: Int
    public let frameRate: Int
    public let durationSeconds: Double
    public let fileSizeBytes: Int64
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        fileName: String,
        width: Int,
        height: Int,
        frameRate: Int,
        durationSeconds: Double,
        fileSizeBytes: Int64,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.fileName = fileName
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.durationSeconds = durationSeconds
        self.fileSizeBytes = fileSizeBytes
        self.createdAt = createdAt
    }
}
