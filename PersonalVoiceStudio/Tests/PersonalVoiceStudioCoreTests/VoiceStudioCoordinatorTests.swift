import XCTest
@testable import PersonalVoiceStudioCore

@MainActor
final class StubAudioRecorder: AudioRecordingServiceProtocol {
    var isRecording: Bool = false
    var normalizedInputLevel: Float = 0.4
    var elapsedSeconds: TimeInterval = 2.5
    var onInterruption: (@MainActor (StudioError) -> Void)?
    var permissionError: StudioError?
    private var destinationURL: URL?

    func currentAuthorizationStatus() -> MicrophoneAuthorizationStatus {
        permissionError == nil ? .authorized : .denied
    }

    func requestAccessIfNeeded() async throws {
        if let permissionError {
            throw permissionError
        }
    }

    func startRecording(to destinationURL: URL) throws {
        self.destinationURL = destinationURL
        try Data("stub-audio".utf8).write(to: destinationURL)
        isRecording = true
    }

    func stopRecording() -> URL? {
        isRecording = false
        return destinationURL
    }

    func cancelRecording() {
        isRecording = false
        if let destinationURL {
            try? FileManager.default.removeItem(at: destinationURL)
        }
        destinationURL = nil
    }
}

struct StubAudioAnalyzer: AudioAnalyzing {
    func analyzeAudioFile(at url: URL) throws -> AudioMetrics {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw StudioError.audioFileCorruptedOrMissing
        }
        return AudioMetrics(durationSeconds: 3.2, rmsDecibels: -18, peakDecibels: -4, sampleRate: 24_000)
    }

    func assessCapture(metrics: AudioMetrics, minimumExpectedSeconds: Double) -> CaptureAssessment {
        AudioAnalysisService().assessCapture(metrics: metrics, minimumExpectedSeconds: minimumExpectedSeconds)
    }
}

struct StubUnavailableEngine: VoiceSynthesisEngine {
    let descriptor = MLXLocalVoiceEngine().descriptor
    let capabilities = ModelCapabilities.unavailable

    func currentReadiness(localModelDirectory: URL) -> ModelReadinessState {
        .engineNotLinked(guidance: "Offline test stub: model unavailable.")
    }

    func validateLocalModel(at directoryURL: URL) throws -> ValidatedModelBundle {
        try OfflineLocalModelValidator().validate(directoryURL: directoryURL)
    }

    func loadModel(from directoryURL: URL) async throws {
        throw StudioError.modelUnavailable(reason: "Offline test stub: model unavailable.")
    }

    func unloadModel() async {}

    func synthesize(_ request: SynthesisRequest) async throws -> SynthesisResult {
        throw StudioError.modelUnavailable(reason: "Offline test stub: model unavailable.")
    }
}

final class VoiceStudioCoordinatorTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("pvs-coord-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    @MainActor
    func testConsentRequiredBeforeRecordingAndMicDenialSurfacesActionableError() async {
        let paths = LocalStoragePaths(rootDirectory: tempRoot)
        let recorder = StubAudioRecorder()
        let store = VoiceStudioStore(
            profileStore: ProfileStore(paths: paths),
            recorder: recorder,
            engine: StubUnavailableEngine(),
            audioAnalyzer: StubAudioAnalyzer()
        )

        await store.startPromptRecording()
        XCTAssertEqual(store.lastError, .consentRequired)

        store.confirmOwnVoiceConsent()
        recorder.permissionError = .microphonePermissionDenied
        await store.startPromptRecording()
        XCTAssertEqual(store.lastError, .microphonePermissionDenied)
    }

    @MainActor
    func testCorrectionsPersistWithoutRetrainingAndSynthesisNeverMocksAudio() async {
        let paths = LocalStoragePaths(rootDirectory: tempRoot)
        let recorder = StubAudioRecorder()
        let store = VoiceStudioStore(
            profileStore: ProfileStore(paths: paths),
            recorder: recorder,
            engine: StubUnavailableEngine(),
            audioAnalyzer: StubAudioAnalyzer()
        )

        store.confirmOwnVoiceConsent()
        await store.startPromptRecording()
        await store.stopAndSavePromptRecording()

        await store.startCorrectionRecording()
        await store.stopCorrectionDraftRecording()
        store.saveCorrection(targetPhrase: "Alameda", phoneticHint: "ah-luh-MEE-duh", category: .properNoun)
        XCTAssertEqual(store.profile.corrections.count, 1)

        let generated = await store.generateSpeech(text: "Hello from offline test.")
        XCTAssertNil(generated)
        XCTAssertTrue(store.profile.generatedHistory.isEmpty)
        guard case .modelUnavailable = store.lastError else {
            return XCTFail("Expected modelUnavailable error when engine is not ready")
        }
    }
}
