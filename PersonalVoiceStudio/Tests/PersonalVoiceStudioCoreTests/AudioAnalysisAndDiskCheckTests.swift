import XCTest
@testable import PersonalVoiceStudioCore

final class AudioAnalysisAndDiskCheckTests: XCTestCase {
    func testCaptureAssessmentDetectsSilentShortClippingAndValidClips() {
        let analyzer = AudioAnalysisService()

        let silent = AudioMetrics(durationSeconds: 2.0, rmsDecibels: -70, peakDecibels: -60, sampleRate: 24_000)
        XCTAssertEqual(analyzer.assessCapture(metrics: silent, minimumExpectedSeconds: 3.0).status, .silentOrTooQuiet)

        let tooShort = AudioMetrics(durationSeconds: 0.7, rmsDecibels: -20, peakDecibels: -6, sampleRate: 24_000)
        XCTAssertEqual(analyzer.assessCapture(metrics: tooShort, minimumExpectedSeconds: 3.0).status, .unusuallyShort)

        let clipping = AudioMetrics(durationSeconds: 3.5, rmsDecibels: -8, peakDecibels: -0.1, sampleRate: 24_000)
        XCTAssertEqual(analyzer.assessCapture(metrics: clipping, minimumExpectedSeconds: 3.0).status, .clippingDetected)

        let valid = AudioMetrics(durationSeconds: 3.5, rmsDecibels: -18, peakDecibels: -4.0, sampleRate: 24_000)
        XCTAssertEqual(analyzer.assessCapture(metrics: valid, minimumExpectedSeconds: 3.0).status, .ok)
    }

    func testDiskSpaceCheckerThrowsWhenInsufficientSpace() {
        let lowSpaceChecker = DiskSpaceChecker { _ in
            5 * 1_048_576 // 5 MB available
        }

        XCTAssertThrowsError(
            try lowSpaceChecker.ensureSufficientSpace(
                at: FileManager.default.temporaryDirectory,
                requiredBytes: 25 * 1_048_576
            )
        ) { error in
            guard case StudioError.insufficientDiskSpace(let requiredMB, let availableMB) = error else {
                return XCTFail("Expected insufficientDiskSpace error")
            }
            XCTAssertEqual(requiredMB, 25)
            XCTAssertEqual(availableMB, 5)
        }
    }
}
