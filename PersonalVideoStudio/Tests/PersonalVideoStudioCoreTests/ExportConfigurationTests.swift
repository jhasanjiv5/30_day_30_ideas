import XCTest
@testable import PersonalVideoStudioCore

final class ExportConfigurationTests: XCTestCase {
    func testLandscapeAndPortraitPixelDimensions() throws {
        let landscape1080 = ExportConfiguration(aspectRatio: .landscape16x9, resolution: .fullHD1080p, frameRate: .fps30)
        XCTAssertEqual(landscape1080.pixelWidth, 1920)
        XCTAssertEqual(landscape1080.pixelHeight, 1080)
        try landscape1080.validate()

        let portrait1080 = ExportConfiguration(aspectRatio: .portrait9x16, resolution: .fullHD1080p, frameRate: .fps24)
        XCTAssertEqual(portrait1080.pixelWidth, 1080)
        XCTAssertEqual(portrait1080.pixelHeight, 1920)
        try portrait1080.validate()

        let portrait720 = ExportConfiguration(aspectRatio: .portrait9x16, resolution: .hd720p, frameRate: .fps60)
        XCTAssertEqual(portrait720.pixelWidth, 720)
        XCTAssertEqual(portrait720.pixelHeight, 1280)
        try portrait720.validate()
    }

    func testAudioTrackTrimValidation() throws {
        let valid = AudioTrackItem(
            role: .narration,
            displayName: "PVS Export",
            fileName: "narration.wav",
            sourceFormat: "WAV",
            sourceDurationSeconds: 12.0,
            trimStartSeconds: 1.0,
            trimEndSeconds: 10.0,
            volume: 1.0
        )
        try valid.validate()
        XCTAssertEqual(valid.trimmedDurationSeconds, 9.0, accuracy: 0.001)

        let invalid = AudioTrackItem(
            role: .music,
            displayName: "Bad Trim",
            fileName: "music.m4a",
            sourceFormat: "M4A",
            sourceDurationSeconds: 10.0,
            trimStartSeconds: 8.0,
            trimEndSeconds: 4.0
        )
        XCTAssertThrowsError(try invalid.validate())
    }

    func testProjectValidationRejectsEmptyStoryboard() {
        let project = VideoProject(title: "Empty")
        XCTAssertThrowsError(try project.validateForExport()) { error in
            guard case VideoStudioError.invalidProject = error else {
                return XCTFail("Expected invalidProject error")
            }
        }
    }
}
