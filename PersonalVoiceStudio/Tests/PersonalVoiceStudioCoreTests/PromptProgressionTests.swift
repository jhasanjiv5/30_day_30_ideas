import XCTest
@testable import PersonalVoiceStudioCore

final class PromptProgressionTests: XCTestCase {
    func testGuidedCatalogVarietyAndNonCopyrightedMaterial() {
        let prompts = GuidedPromptCatalog.allPrompts
        XCTAssertGreaterThanOrEqual(prompts.count, 15)

        let lengthClasses = Set(prompts.map(\.lengthClass))
        XCTAssertTrue(lengthClasses.contains(.short))
        XCTAssertTrue(lengthClasses.contains(.medium))
        XCTAssertTrue(lengthClasses.contains(.long))

        let combinedText = prompts.map(\.text).joined(separator: " ")
        XCTAssertTrue(combinedText.contains("?"))
        XCTAssertTrue(combinedText.contains("!"))
        XCTAssertTrue(combinedText.contains("—"))
        XCTAssertTrue(combinedText.contains(":"))
        XCTAssertTrue(combinedText.range(of: #"\d+"#, options: .regularExpression) != nil)
    }

    @MainActor
    func testPauseAndResumeAndNextUnrecordedProgression() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("pvs-prog-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let paths = LocalStoragePaths(rootDirectory: tempRoot)
        let store = VoiceStudioStore(
            profileStore: ProfileStore(paths: paths),
            recorder: StubAudioRecorder(),
            engine: StubUnavailableEngine(),
            audioAnalyzer: StubAudioAnalyzer()
        )

        store.confirmOwnVoiceConsent(displayName: "Test Speaker")
        XCTAssertEqual(store.currentPrompt.index, 0)

        await store.startPromptRecording()
        await store.stopAndSavePromptRecording()
        XCTAssertEqual(store.recordedPromptCount, 1)

        store.advanceToNextUnrecordedPrompt()
        XCTAssertEqual(store.currentPrompt.index, 1)

        store.pauseSetup()
        XCTAssertTrue(store.profile.setupPaused)
        XCTAssertTrue(store.canResumeSetup)

        let reloaded = VoiceStudioStore(
            profileStore: ProfileStore(paths: paths),
            recorder: StubAudioRecorder(),
            engine: StubUnavailableEngine(),
            audioAnalyzer: StubAudioAnalyzer()
        )
        XCTAssertEqual(reloaded.currentPrompt.index, 1)
        XCTAssertTrue(reloaded.canResumeSetup)
        reloaded.resumeSetup()
        XCTAssertFalse(reloaded.profile.setupPaused)
    }
}
