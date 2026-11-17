import XCTest
@testable import PersonalVideoStudioCore

final class SceneValidationAndTimelineTests: XCTestCase {
    func testEmptyMediaAndEmptyTextFailsSceneValidation() {
        let scene = StoryboardScene(title: "Blank", titleOverlay: "  ", captionScript: "", mediaFileName: nil)
        XCTAssertThrowsError(try scene.validate(sceneNumber: 1)) { error in
            guard case VideoStudioError.invalidScene = error else {
                return XCTFail("Expected invalidScene error")
            }
        }
    }

    func testInvalidTransitionDurationFailsValidation() {
        let scene = StoryboardScene(
            title: "Short Scene",
            titleOverlay: "Intro",
            durationSeconds: 1.0,
            transition: .crossDissolve,
            transitionDurationSeconds: 1.5
        )
        XCTAssertThrowsError(try scene.validate(sceneNumber: 1))
    }

    func testTimelineSlicesAndActiveSceneLookup() {
        let s1 = StoryboardScene(title: "One", titleOverlay: "1", durationSeconds: 3.0)
        let s2 = StoryboardScene(title: "Two", titleOverlay: "2", durationSeconds: 5.0)
        let project = VideoProject(title: "Timeline Test", scenes: [s1, s2])

        let slices = CompositionPreviewBuilder.timelineSlices(for: project)
        XCTAssertEqual(slices.count, 2)
        XCTAssertEqual(slices[0].startTimeSeconds, 0.0, accuracy: 0.001)
        XCTAssertEqual(slices[0].endTimeSeconds, 3.0, accuracy: 0.001)
        XCTAssertEqual(slices[1].startTimeSeconds, 3.0, accuracy: 0.001)
        XCTAssertEqual(slices[1].endTimeSeconds, 8.0, accuracy: 0.001)

        let lookup = CompositionPreviewBuilder.activeScene(at: 5.5, in: project)
        XCTAssertEqual(lookup?.slice.scene.id, s2.id)
        XCTAssertEqual(lookup?.localProgress ?? 0, 0.5, accuracy: 0.001)
    }
}
