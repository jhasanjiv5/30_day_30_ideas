import XCTest
@testable import PersonalVideoStudioCore

final class ProjectPersistenceAndDeletionTests: XCTestCase {
    private var tempRoot: URL!
    private var paths: LocalStoragePaths!
    private var store: ProjectStore!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("pvid-persist-\(UUID().uuidString)", isDirectory: true)
        paths = LocalStoragePaths(rootDirectory: tempRoot)
        store = ProjectStore(paths: paths)
        try paths.ensureRootDirectoriesExist()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testCreateLoadRenameAndGranularDeletion() throws {
        var project = try store.createProject(title: "Acoustic Session")
        let mediaURL = paths.mediaFileURL(projectID: project.id, fileName: "portrait.png")
        try Data("png-bytes".utf8).write(to: mediaURL)

        let renderURL = paths.renderFileURL(projectID: project.id, fileName: "export-1.mp4")
        try Data("mp4-bytes".utf8).write(to: renderURL)

        project.scenes.append(
            StoryboardScene(
                title: "Opening Portrait",
                titleOverlay: "Acoustic Session",
                mediaKind: .image,
                mediaFileName: "portrait.png",
                durationSeconds: 5.0
            )
        )
        project.renders.append(
            RenderedVideoRecord(
                fileName: "export-1.mp4",
                width: 1920,
                height: 1080,
                frameRate: 30,
                durationSeconds: 5.0,
                fileSizeBytes: 9
            )
        )
        try store.saveProject(project)

        let loaded = try store.loadProject(id: project.id)
        XCTAssertEqual(loaded.title, "Acoustic Session")
        XCTAssertEqual(loaded.scenes.count, 1)
        XCTAssertEqual(loaded.renders.count, 1)

        let renamed = try store.renameProject(id: project.id, newTitle: "Acoustic Session Final")
        XCTAssertEqual(renamed.title, "Acoustic Session Final")

        let afterRenderDelete = try store.deleteRender(projectID: project.id, renderID: project.renders[0].id)
        XCTAssertTrue(afterRenderDelete.renders.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: renderURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: mediaURL.path))

        try store.deleteProject(id: project.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.projectDirectory(for: project.id).path))
        XCTAssertThrowsError(try store.loadProject(id: project.id)) { error in
            guard case VideoStudioError.projectNotFound = error else {
                return XCTFail("Expected projectNotFound error")
            }
        }
    }
}
