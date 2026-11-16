import XCTest
@testable import PersonalVoiceStudioCore

final class ProfilePersistenceAndDeletionTests: XCTestCase {
    private var tempRoot: URL!
    private var paths: LocalStoragePaths!
    private var profileStore: ProfileStore!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("pvs-persist-\(UUID().uuidString)", isDirectory: true)
        paths = LocalStoragePaths(rootDirectory: tempRoot)
        profileStore = ProfileStore(paths: paths)
        try paths.ensureDirectoriesExist()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testSaveLoadAndGranularDeletion() throws {
        var profile = VoiceProfile(displayName: "Alex Local")
        profile.consent = ConsentRecord(confirmedOwnVoice: true, confirmedAt: Date())

        let recURL = paths.promptRecordingURL(fileName: "prompt-01.wav")
        try Data("wav-bytes".utf8).write(to: recURL)
        profile.recordings["prompt-01"] = PromptRecording(
            promptID: "prompt-01",
            audioFileName: "prompt-01.wav",
            durationSeconds: 3.2,
            rmsDecibels: -18,
            peakDecibels: -3,
            sampleRate: 24_000,
            captureAssessment: CaptureAssessment(status: .ok, headline: "OK", detail: "Captured")
        )

        let corURL = paths.correctionAudioURL(fileName: "cor-1.wav")
        try Data("cor-bytes".utf8).write(to: corURL)
        let correction = PronunciationCorrection(
            targetPhrase: "Alameda",
            phoneticHint: "ah-luh-MEE-duh",
            category: .properNoun,
            audioFileName: "cor-1.wav",
            durationSeconds: 1.4,
            captureAssessment: CaptureAssessment(status: .ok, headline: "OK", detail: "Captured")
        )
        profile.corrections.append(correction)

        let genURL = paths.generatedAudioURL(fileName: "gen-1.wav")
        try Data("gen-bytes".utf8).write(to: genURL)
        profile.generatedHistory.append(
            GeneratedSpeechClip(
                fullText: "Hello locally",
                audioFileName: "gen-1.wav",
                durationSeconds: 1.8,
                sampleRate: 24_000,
                modelIdentifier: "test-model"
            )
        )

        try profileStore.saveProfile(profile)

        let loaded = try XCTUnwrap(profileStore.loadProfile())
        XCTAssertEqual(loaded.displayName, "Alex Local")
        XCTAssertTrue(loaded.consent.confirmedOwnVoice)
        XCTAssertEqual(loaded.recordings.count, 1)
        XCTAssertEqual(loaded.corrections.count, 1)
        XCTAssertEqual(loaded.generatedHistory.count, 1)

        try profileStore.clearAllGeneratedAudioFiles()
        XCTAssertFalse(FileManager.default.fileExists(atPath: genURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: recURL.path))

        try profileStore.deleteCompleteProfileAndData(includeImportedModel: true)
        XCTAssertNil(try profileStore.loadProfile())
        XCTAssertFalse(FileManager.default.fileExists(atPath: recURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: corURL.path))
    }
}
