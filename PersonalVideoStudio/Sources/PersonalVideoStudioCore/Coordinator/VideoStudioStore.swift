import AppKit
import Foundation
import OSLog

public enum StudioNavigationSection: String, CaseIterable, Identifiable, Sendable {
    case projects = "Projects"
    case storyboard = "Storyboard"
    case audio = "Audio & Narration"
    case previewExport = "Preview & Export"
    case aiModels = "Local AI Models"
    case privacy = "Privacy & Storage"

    public var id: String { rawValue }
}

@MainActor
public final class VideoStudioStore: ObservableObject {
    @Published public private(set) var projects: [VideoProject] = []
    @Published public var activeProject: VideoProject?
    @Published public var selectedSceneID: UUID?
    @Published public var selectedSection: StudioNavigationSection = .projects

    @Published public private(set) var modelReadiness: ModelReadinessState = .weightsMissing(guidance: "")
    @Published public private(set) var modelCapabilities: VideoModelCapabilities = .unavailable
    @Published public private(set) var requirementsReport: VideoGenerationRequirementsReport
    @Published public private(set) var portraitCalibrations: [UUID: PortraitCalibrationResult] = [:]
    @Published public private(set) var audioCalibrations: [UUID: AudioSyncCalibrationResult] = [:]
    @Published public private(set) var isCalibrating = false
    @Published public private(set) var isGeneratingScene = false
    @Published public private(set) var generationProgress = VideoRenderProgress(fractionCompleted: 0, statusMessage: "")
    @Published public private(set) var isExporting = false
    @Published public private(set) var exportProgress = VideoRenderProgress(fractionCompleted: 0, statusMessage: "")
    @Published public var lastErrorMessage: String?
    @Published public var lastStatusMessage: String?

    public let storagePaths: LocalStoragePaths
    public let audioPlayback: AudioPlaybackService

    private let projectStore: ProjectStore
    private let mediaImportService: MediaImportService
    private let renderer: VideoRenderingEngine
    private let sceneGenerationEngine: SceneGenerationEngine
    private let modelValidator: OfflineVideoModelValidator
    private let calibrator: PortraitAndAudioCalibrating
    private let diskChecker: DiskSpaceChecking
    private let logger = Logger(subsystem: "com.local.PersonalVideoStudio", category: "VideoStudioStore")

    private var activeExportTask: Task<Void, Never>?

    public init(
        storagePaths: LocalStoragePaths = .defaultAppSupportPaths(),
        renderer: VideoRenderingEngine = AVFoundationVideoRenderer(),
        sceneGenerationEngine: SceneGenerationEngine = LocalSceneGenerationEngine(),
        audioInspector: AudioAssetInspecting = AudioAssetInspector(),
        calibrator: PortraitAndAudioCalibrating = PortraitAndAudioCalibrator(),
        diskChecker: DiskSpaceChecking = DiskSpaceChecker()
    ) {
        self.storagePaths = storagePaths
        self.projectStore = ProjectStore(paths: storagePaths)
        self.mediaImportService = MediaImportService(paths: storagePaths, diskChecker: diskChecker, audioInspector: audioInspector)
        self.renderer = renderer
        self.sceneGenerationEngine = sceneGenerationEngine
        self.modelValidator = OfflineVideoModelValidator(diskChecker: diskChecker)
        self.calibrator = calibrator
        self.diskChecker = diskChecker
        self.audioPlayback = AudioPlaybackService()
        self.requirementsReport = VideoGenerationRequirementsChecker.evaluate(
            freeDiskBytes: 0,
            modelReadiness: .weightsMissing(guidance: ""),
            activeProject: nil,
            selectedScene: nil
        )

        loadInitialState()
    }

    public var engineDescriptor: VideoModelEngineDescriptor {
        sceneGenerationEngine.descriptor
    }

    public func loadInitialState() {
        do {
            try storagePaths.ensureRootDirectoriesExist()
            projects = try projectStore.listProjects()
            if activeProject == nil, let first = projects.first {
                activeProject = first
                selectedSceneID = first.scenes.first?.id
            }
            refreshModelReadiness()
        } catch {
            lastErrorMessage = error.localizedDescription
            logger.error("Failed loading initial workspace state.")
        }
    }

    public func refreshModelReadiness() {
        let modelDir = storagePaths.importedVideoModelDirectory
        modelReadiness = sceneGenerationEngine.currentReadiness(modelDirectory: modelDir)
        modelCapabilities = sceneGenerationEngine.currentCapabilities(modelDirectory: modelDir)
        refreshRequirements()
    }

    public func refreshRequirements() {
        let freeBytes = (try? diskChecker.availableBytes(at: storagePaths.rootDirectory)) ?? 0
        let selectedScene = activeProject?.scenes.first(where: { $0.id == selectedSceneID }) ?? activeProject?.scenes.first
        requirementsReport = VideoGenerationRequirementsChecker.evaluate(
            freeDiskBytes: freeBytes,
            modelReadiness: modelReadiness,
            activeProject: activeProject,
            selectedScene: selectedScene,
            isRuntimeLinked: modelReadiness.isReadyForInference
        )
    }

    public func createProject(title: String) {
        clearBannerMessages()
        do {
            let project = try projectStore.createProject(title: title)
            projects = try projectStore.listProjects()
            activeProject = project
            selectedSceneID = nil
            selectedSection = .storyboard
            refreshRequirements()
            lastStatusMessage = "Created local project '\(project.title)'."
            logger.info("Created project id=\(project.id.uuidString, privacy: .public)")
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func openProject(_ project: VideoProject) {
        clearBannerMessages()
        do {
            let loaded = try projectStore.loadProject(id: project.id)
            activeProject = loaded
            selectedSceneID = loaded.scenes.first?.id
            selectedSection = .storyboard
            refreshRequirements()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func renameProject(id: UUID, newTitle: String) {
        clearBannerMessages()
        do {
            let renamed = try projectStore.renameProject(id: id, newTitle: newTitle)
            projects = try projectStore.listProjects()
            if activeProject?.id == id {
                activeProject = renamed
            }
            lastStatusMessage = "Renamed project."
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func deleteProject(id: UUID) {
        clearBannerMessages()
        do {
            audioPlayback.stop()
            try projectStore.deleteProject(id: id)
            projects = try projectStore.listProjects()
            if activeProject?.id == id {
                activeProject = projects.first
                selectedSceneID = activeProject?.scenes.first?.id
            }
            refreshRequirements()
            lastStatusMessage = "Deleted local project and its imported media."
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func addEmptyScene(title: String = "New Scene") {
        guard var project = activeProject else { return }
        clearBannerMessages()
        let scene = StoryboardScene(title: title, titleOverlay: title)
        project.scenes.append(scene)
        persistActiveProject(project)
        selectedSceneID = scene.id
    }

    public func addSceneWithVisualMedia(from sourceURL: URL) {
        guard var project = activeProject else { return }
        clearBannerMessages()
        do {
            let imported = try mediaImportService.importVisualMedia(from: sourceURL, into: project.id)
            let baseName = sourceURL.deletingPathExtension().lastPathComponent
            let scene = StoryboardScene(
                title: baseName.isEmpty ? "Scene \(project.scenes.count + 1)" : baseName,
                titleOverlay: "",
                mediaKind: imported.mediaKind,
                mediaFileName: imported.fileName,
                durationSeconds: 4.0,
                motionEffect: imported.mediaKind == .image ? .kenBurnsZoomIn : .none
            )
            project.scenes.append(scene)
            persistActiveProject(project)
            selectedSceneID = scene.id
            lastStatusMessage = "Imported local \(imported.mediaKind.displayName.lowercased())."
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func replaceSceneMedia(sceneID: UUID, from sourceURL: URL) {
        guard var project = activeProject,
              let index = project.scenes.firstIndex(where: { $0.id == sceneID }) else { return }
        clearBannerMessages()
        do {
            let imported = try mediaImportService.importVisualMedia(from: sourceURL, into: project.id)
            project.scenes[index].mediaKind = imported.mediaKind
            project.scenes[index].mediaFileName = imported.fileName
            project.scenes[index].generatedVideoFileName = nil
            portraitCalibrations.removeValue(forKey: sceneID)
            persistActiveProject(project)
            lastStatusMessage = "Updated scene media."
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func addReferenceImageToScene(sceneID: UUID, from sourceURL: URL) {
        guard var project = activeProject,
              let index = project.scenes.firstIndex(where: { $0.id == sceneID }) else { return }
        clearBannerMessages()
        do {
            let imported = try mediaImportService.importVisualMedia(from: sourceURL, into: project.id)
            guard imported.mediaKind == .image else {
                throw VideoStudioError.mediaImportFailed(reason: "Reference portraits must be still images (PNG, JPEG, HEIC).")
            }
            project.scenes[index].referenceImageFileNames.append(imported.fileName)
            persistActiveProject(project)
            lastStatusMessage = "Added reference portrait image to scene."
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func removeReferenceImageFromScene(sceneID: UUID, fileName: String) {
        guard var project = activeProject,
              let index = project.scenes.firstIndex(where: { $0.id == sceneID }) else { return }
        project.scenes[index].referenceImageFileNames.removeAll { $0 == fileName }
        persistActiveProject(project)
    }

    public func calibrateScenePortrait(sceneID: UUID) {
        guard let project = activeProject,
              let scene = project.scenes.first(where: { $0.id == sceneID }),
              let fileName = scene.mediaFileName,
              scene.mediaKind == .image else {
            lastErrorMessage = "Select a scene with an imported still portrait image to calibrate."
            return
        }
        clearBannerMessages()
        let url = storagePaths.mediaFileURL(projectID: project.id, fileName: fileName)
        do {
            let result = try calibrator.calibratePortrait(at: url)
            portraitCalibrations[sceneID] = result
            lastStatusMessage = result.summary
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func calibrateProjectAudioAndPortraits() async {
        guard let project = activeProject else {
            lastErrorMessage = "Create or open a project before running calibration."
            return
        }
        clearBannerMessages()
        isCalibrating = true
        defer { isCalibrating = false }

        var calibratedCount = 0
        for scene in project.scenes where scene.mediaKind == .image {
            if let fileName = scene.mediaFileName {
                let url = storagePaths.mediaFileURL(projectID: project.id, fileName: fileName)
                if let result = try? calibrator.calibratePortrait(at: url) {
                    portraitCalibrations[scene.id] = result
                    calibratedCount += 1
                }
            }
        }

        for track in project.audioTracks {
            let audioURL = storagePaths.audioFileURL(projectID: project.id, fileName: track.fileName)
            if let result = try? await calibrator.calibrateAudioTrack(at: audioURL) {
                audioCalibrations[track.id] = result
                calibratedCount += 1
            }
        }

        refreshRequirements()
        lastStatusMessage = calibratedCount > 0
            ? "Calibrated \(calibratedCount) portrait/audio asset(s) locally."
            : "No portrait images or audio tracks found in the active project to calibrate."
    }

    public func generateAIScene(sceneID: UUID) async {
        guard var project = activeProject,
              let index = project.scenes.firstIndex(where: { $0.id == sceneID }) else { return }
        clearBannerMessages()

        let scene = project.scenes[index]
        let refURLs = scene.allReferenceMediaFileNames.map {
            storagePaths.mediaFileURL(projectID: project.id, fileName: $0)
        }
        let drivingTrack = project.narrationTrack ?? project.musicTrack
        let audioURL = drivingTrack.map { storagePaths.audioFileURL(projectID: project.id, fileName: $0.fileName) }
        let outputName = "gen-\(scene.id.uuidString.prefix(8))-\(Int(Date().timeIntervalSince1970)).mp4"
        let outputURL = storagePaths.generatedClipURL(projectID: project.id, fileName: outputName)

        let request = SceneGenerationRequest(
            referenceImageURLs: refURLs,
            behaviorPrompt: scene.behaviorPrompt,
            drivingAudioURL: audioURL,
            outputVideoURL: outputURL,
            aspectRatio: project.exportConfiguration.aspectRatio,
            targetFrameRate: project.exportConfiguration.frameRate.rawValue,
            durationSeconds: scene.durationSeconds,
            enableLipSync: scene.enableLipSyncWithAudio
        )

        isGeneratingScene = true
        generationProgress = VideoRenderProgress(fractionCompleted: 0.05, statusMessage: "Preparing Visual-Text + Lip-Sync request…")

        do {
            let result = try await sceneGenerationEngine.generateSceneClip(request) { [weak self] update in
                Task { @MainActor [weak self] in
                    self?.generationProgress = update
                }
            }
            project.scenes[index].generatedVideoFileName = result.generatedClipURL.lastPathComponent
            persistActiveProject(project)
            lastStatusMessage = "Generated scene clip locally with \(result.modelIdentifier)."
        } catch {
            lastErrorMessage = error.localizedDescription
        }
        isGeneratingScene = false
    }

    public func updateScene(_ updatedScene: StoryboardScene) {
        guard var project = activeProject,
              let index = project.scenes.firstIndex(where: { $0.id == updatedScene.id }) else { return }
        project.scenes[index] = updatedScene
        persistActiveProject(project)
    }

    public func moveScenes(fromOffsets: IndexSet, toOffset: Int) {
        guard var project = activeProject else { return }
        var reordered = project.scenes
        let movingItems = fromOffsets.sorted().map { reordered[$0] }
        for index in fromOffsets.sorted(by: >) {
            reordered.remove(at: index)
        }
        let adjustedTarget = min(toOffset, reordered.count)
        reordered.insert(contentsOf: movingItems, at: adjustedTarget)
        project.scenes = reordered
        persistActiveProject(project)
    }

    public func removeScene(id: UUID) {
        guard var project = activeProject else { return }
        project.scenes.removeAll { $0.id == id }
        portraitCalibrations.removeValue(forKey: id)
        if selectedSceneID == id {
            selectedSceneID = project.scenes.first?.id
        }
        persistActiveProject(project)
    }

    public func importAudioTrack(from sourceURL: URL, role: AudioTrackRole) async {
        guard var project = activeProject else { return }
        clearBannerMessages()
        do {
            let track = try await mediaImportService.importAudioTrack(from: sourceURL, role: role, into: project.id)
            project.audioTracks.removeAll { $0.role == role }
            project.audioTracks.append(track)
            persistActiveProject(project)
            let audioURL = storagePaths.audioFileURL(projectID: project.id, fileName: track.fileName)
            if let cal = try? await calibrator.calibrateAudioTrack(at: audioURL) {
                audioCalibrations[track.id] = cal
            }
            lastStatusMessage = "Imported \(role.displayName.lowercased()) (\(track.sourceFormat))."
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func updateAudioTrack(_ updatedTrack: AudioTrackItem) {
        guard var project = activeProject,
              let index = project.audioTracks.firstIndex(where: { $0.id == updatedTrack.id }) else { return }
        project.audioTracks[index] = updatedTrack
        persistActiveProject(project)
    }

    public func removeAudioTrack(id: UUID) {
        guard var project = activeProject else { return }
        if audioPlayback.playingTrackID == id {
            audioPlayback.stop()
        }
        project.audioTracks.removeAll { $0.id == id }
        audioCalibrations.removeValue(forKey: id)
        persistActiveProject(project)
    }

    public func toggleAudioPlayback(for track: AudioTrackItem) {
        guard let project = activeProject else { return }
        clearBannerMessages()
        let url = storagePaths.audioFileURL(projectID: project.id, fileName: track.fileName)
        do {
            try audioPlayback.togglePlayback(trackID: track.id, fileURL: url, volume: track.volume)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func updateExportConfiguration(_ config: ExportConfiguration) {
        guard var project = activeProject else { return }
        project.exportConfiguration = config
        persistActiveProject(project)
    }

    public func updateScriptNotes(_ notes: String) {
        guard var project = activeProject else { return }
        project.scriptNotes = notes
        persistActiveProject(project)
    }

    public func startExport() {
        guard let project = activeProject, !isExporting else { return }
        clearBannerMessages()

        do {
            try project.validateForExport()
        } catch {
            lastErrorMessage = error.localizedDescription
            return
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let safeSlug = project.title
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        let fileName = "\(safeSlug.isEmpty ? "render" : safeSlug)-\(timestamp).mp4"
        let outputURL = storagePaths.renderFileURL(projectID: project.id, fileName: fileName)

        isExporting = true
        exportProgress = VideoRenderProgress(fractionCompleted: 0.01, statusMessage: "Starting local export…")

        let renderer = self.renderer
        let paths = self.storagePaths

        activeExportTask = Task { [weak self] in
            guard let self else { return }
            do {
                let record = try await renderer.render(
                    project: project,
                    storagePaths: paths,
                    outputURL: outputURL
                ) { [weak self] progressUpdate in
                    Task { @MainActor [weak self] in
                        self?.exportProgress = progressUpdate
                    }
                }
                if var latestProject = try? self.projectStore.loadProject(id: project.id) {
                    latestProject.renders.insert(record, at: 0)
                    try? self.projectStore.saveProject(latestProject)
                    self.activeProject = latestProject
                    self.projects = (try? self.projectStore.listProjects()) ?? self.projects
                }
                self.isExporting = false
                self.lastStatusMessage = "Exported \(record.fileName) locally."
                self.logger.info("Completed local MP4 export for project id=\(project.id.uuidString, privacy: .public)")
            } catch {
                self.isExporting = false
                if case VideoStudioError.exportCancelled = error {
                    self.lastStatusMessage = "Export cancelled."
                } else {
                    self.lastErrorMessage = error.localizedDescription
                }
            }
        }
    }

    public func cancelExport() {
        activeExportTask?.cancel()
        activeExportTask = nil
    }

    public func deleteRender(_ record: RenderedVideoRecord) {
        guard let project = activeProject else { return }
        clearBannerMessages()
        do {
            let updated = try projectStore.deleteRender(projectID: project.id, renderID: record.id)
            activeProject = updated
            projects = try projectStore.listProjects()
            lastStatusMessage = "Deleted rendered video '\(record.fileName)'."
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func importVideoModelFolder(from sourceURL: URL) {
        clearBannerMessages()
        do {
            let bundle = try modelValidator.importModelDirectory(
                from: sourceURL,
                into: storagePaths.importedVideoModelDirectory
            )
            refreshModelReadiness()
            lastStatusMessage = "Validated and stored local model folder (\(bundle.modelArchitecture))."
        } catch {
            lastErrorMessage = error.localizedDescription
            refreshModelReadiness()
        }
    }

    public func removeImportedVideoModel() {
        clearBannerMessages()
        do {
            try projectStore.deleteImportedVideoModel()
            refreshModelReadiness()
            lastStatusMessage = "Removed imported local model weights."
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func totalStorageUsedBytes() -> Int64 {
        projectStore.directorySizeBytes(at: storagePaths.rootDirectory)
    }

    public func projectStorageUsedBytes(for projectID: UUID) -> Int64 {
        projectStore.directorySizeBytes(at: storagePaths.projectDirectory(for: projectID))
    }

    public func revealStorageInFinder() {
        do {
            try storagePaths.ensureRootDirectoriesExist()
            NSWorkspace.shared.activateFileViewerSelecting([storagePaths.rootDirectory])
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func revealRenderInFinder(_ record: RenderedVideoRecord) {
        guard let project = activeProject else { return }
        let url = storagePaths.renderFileURL(projectID: project.id, fileName: record.fileName)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    public func clearBannerMessages() {
        lastErrorMessage = nil
        lastStatusMessage = nil
    }

    private func persistActiveProject(_ project: VideoProject) {
        do {
            try projectStore.saveProject(project)
            activeProject = try projectStore.loadProject(id: project.id)
            projects = try projectStore.listProjects()
            refreshRequirements()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}
