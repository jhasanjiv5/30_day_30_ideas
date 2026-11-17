import XCTest
@testable import PersonalVideoStudioCore

private struct MockVideoRenderingEngine: VideoRenderingEngine {
    let shouldFail: Bool

    func render(
        project: VideoProject,
        storagePaths: LocalStoragePaths,
        outputURL: URL,
        progress: @escaping @Sendable (VideoRenderProgress) -> Void
    ) async throws -> RenderedVideoRecord {
        if shouldFail {
            throw VideoStudioError.exportFailed(reason: "Simulated encoder failure")
        }
        progress(VideoRenderProgress(fractionCompleted: 0.5, statusMessage: "Halfway"))
        try Data("mock-mp4".utf8).write(to: outputURL)
        progress(VideoRenderProgress(fractionCompleted: 1.0, statusMessage: "Done"))
        return RenderedVideoRecord(
            fileName: outputURL.lastPathComponent,
            width: project.exportConfiguration.pixelWidth,
            height: project.exportConfiguration.pixelHeight,
            frameRate: project.exportConfiguration.frameRate.rawValue,
            durationSeconds: project.totalDurationSeconds,
            fileSizeBytes: 8
        )
    }
}

@MainActor
final class VideoStudioCoordinatorTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("pvid-coord-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testProjectWorkflowSceneReorderMockExportAndHonestAIGate() async throws {
        let paths = LocalStoragePaths(rootDirectory: tempRoot)
        let store = VideoStudioStore(
            storagePaths: paths,
            renderer: MockVideoRenderingEngine(shouldFail: false),
            sceneGenerationEngine: LocalSceneGenerationEngine(
                isAppleSilicon: true,
                physicalMemoryGB: 32,
                isRuntimeLinked: false
            )
        )

        store.createProject(title: "Guitar Portrait Video")
        XCTAssertEqual(store.projects.count, 1)
        XCTAssertNotNil(store.activeProject)

        store.addEmptyScene(title: "Verse 1")
        store.addEmptyScene(title: "Chorus")
        XCTAssertEqual(store.activeProject?.scenes.map(\.title), ["Verse 1", "Chorus"])

        if var scene = store.activeProject?.scenes.first {
            scene.behaviorPrompt = "Woman strumming acoustic guitar with hand movement and lip-syncing to vocals."
            store.updateScene(scene)
            await store.generateAIScene(sceneID: scene.id)
            XCTAssertNotNil(store.lastErrorMessage)
            XCTAssertNil(store.activeProject?.scenes.first?.generatedVideoFileName)
        }

        store.moveScenes(fromOffsets: IndexSet(integer: 1), toOffset: 0)
        XCTAssertEqual(store.activeProject?.scenes.map(\.title), ["Chorus", "Verse 1"])

        store.startExport()
        try await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertFalse(store.isExporting)
        XCTAssertEqual(store.activeProject?.renders.count, 1)
        XCTAssertNil(store.lastErrorMessage)
    }
}
