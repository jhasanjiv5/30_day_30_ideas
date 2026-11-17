import XCTest
@testable import PersonalVideoStudioCore

final class CalibrationAndRequirementsTests: XCTestCase {
    func testPortraitCalibrationFlagsMissingFaceAndLowResolution() {
        let noFace = PortraitAndAudioCalibrator.assessPortrait(
            fileName: "landscape.jpg",
            pixelWidth: 1920,
            pixelHeight: 1080,
            detectedFaceCount: 0,
            primaryFaceBox: nil,
            hasMouthLandmarks: false
        )
        XCTAssertEqual(noFace.status, .warning)
        XCTAssertTrue(noFace.summary.contains("No face detected"))

        let lowRes = PortraitAndAudioCalibrator.assessPortrait(
            fileName: "tiny.jpg",
            pixelWidth: 320,
            pixelHeight: 320,
            detectedFaceCount: 1,
            primaryFaceBox: NormalizedFaceRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
            hasMouthLandmarks: true
        )
        XCTAssertEqual(lowRes.status, .warning)
        XCTAssertTrue(lowRes.summary.contains("Low resolution"))

        let passing = PortraitAndAudioCalibrator.assessPortrait(
            fileName: "guitarist.jpg",
            pixelWidth: 1280,
            pixelHeight: 720,
            detectedFaceCount: 1,
            primaryFaceBox: NormalizedFaceRect(x: 0.3, y: 0.3, width: 0.35, height: 0.4),
            hasMouthLandmarks: true
        )
        XCTAssertEqual(passing.status, .pass)
        XCTAssertTrue(passing.hasMouthLandmarks)
    }

    func testAudioCalibrationExtracts10HzEnvelopeAndFlagsSilence() {
        let silentSamples = Array(repeating: Float(0.0001), count: 16_000)
        let silent = PortraitAndAudioCalibrator.assessAudioSamples(
            fileName: "quiet.wav",
            durationSeconds: 1.0,
            sampleRate: 16_000,
            monoSamples: silentSamples
        )
        XCTAssertEqual(silent.status, .warning)
        XCTAssertEqual(silent.energyEnvelope10Hz.count, 10)

        let loudSamples = (0..<16_000).map { idx in
            Float(0.25 * sin(Double(idx) * 0.08))
        }
        let passing = PortraitAndAudioCalibrator.assessAudioSamples(
            fileName: "vocals.wav",
            durationSeconds: 1.0,
            sampleRate: 16_000,
            monoSamples: loudSamples
        )
        XCTAssertEqual(passing.status, .pass)
        XCTAssertEqual(passing.energyEnvelope10Hz.count, 10)
        XCTAssertGreaterThan(passing.energyEnvelope10Hz.first ?? 0, 0.1)
    }

    func testVideoGenerationRequirementsReportChecksHardwareAndInputs() {
        let scene = StoryboardScene(
            title: "Guitar Scene",
            behaviorPrompt: "Woman strumming acoustic guitar and singing",
            mediaKind: .image,
            mediaFileName: "woman.jpg"
        )
        let track = AudioTrackItem(
            role: .music,
            displayName: "Song",
            fileName: "song.wav",
            sourceFormat: "WAV",
            sourceDurationSeconds: 12.0
        )
        let project = VideoProject(title: "Music Video", scenes: [scene], audioTracks: [track])

        let report = VideoGenerationRequirementsChecker.evaluate(
            isAppleSilicon: true,
            unifiedMemoryGB: 32,
            freeDiskBytes: 50 * 1024 * 1024 * 1024,
            modelReadiness: .engineNotLinked(guidance: "Runtime unlinked"),
            activeProject: project,
            selectedScene: scene,
            isRuntimeLinked: false
        )

        XCTAssertFalse(report.isReadyForAIGeneration)
        XCTAssertEqual(report.items.first(where: { $0.id == "arch" })?.isSatisfied, true)
        XCTAssertEqual(report.items.first(where: { $0.id == "ram" })?.isSatisfied, true)
        XCTAssertEqual(report.items.first(where: { $0.id == "disk" })?.isSatisfied, true)
        XCTAssertEqual(report.items.first(where: { $0.id == "scene-inputs" })?.isSatisfied, true)
        XCTAssertEqual(report.items.first(where: { $0.id == "runtime" })?.isSatisfied, false)
    }
}
