import Foundation
import os

public enum RecordingSessionTarget: Equatable, Sendable {
    case prompt(promptID: String)
    case correctionDraft
}

@MainActor
public final class VoiceStudioStore: ObservableObject {
    @Published public private(set) var profile: VoiceProfile
    @Published public private(set) var prompts: [RecordingPrompt] = GuidedPromptCatalog.allPrompts
    @Published public private(set) var readiness: ModelReadinessState
    @Published public private(set) var capabilities: ModelCapabilities
    @Published public private(set) var storageUsage: StorageUsageSummary
    @Published public private(set) var isGenerating: Bool = false
    @Published public private(set) var isImportingModel: Bool = false
    @Published public private(set) var activeRecordingTarget: RecordingSessionTarget?
    @Published public private(set) var pendingCorrectionDraftURL: URL?
    @Published public private(set) var pendingCorrectionDraftMetrics: AudioMetrics?
    @Published public private(set) var pendingCorrectionDraftAssessment: CaptureAssessment?
    @Published public var lastError: StudioError?
    @Published public var statusBannerMessage: String?

    public let profileStore: ProfileStore
    public let recorder: AudioRecordingServiceProtocol
    public let playback: AudioPlaybackService
    public let engine: VoiceSynthesisEngine
    public let audioAnalyzer: AudioAnalyzing
    public let exportService: AudioExportService
    public let diskChecker: DiskSpaceChecking
    public let modelValidator: OfflineLocalModelValidator

    private var pendingRecordingURL: URL?
    private let logger = Logger(subsystem: "com.local.PersonalVoiceStudio", category: "Store")

    public init(
        profileStore: ProfileStore = ProfileStore(paths: LocalStoragePaths.defaultAppSupportPaths()),
        recorder: AudioRecordingServiceProtocol? = nil,
        playback: AudioPlaybackService? = nil,
        engine: VoiceSynthesisEngine = MLXLocalVoiceEngine(),
        audioAnalyzer: AudioAnalyzing = AudioAnalysisService(),
        exportService: AudioExportService? = nil,
        diskChecker: DiskSpaceChecking = DiskSpaceChecker(),
        modelValidator: OfflineLocalModelValidator? = nil
    ) {
        self.profileStore = profileStore
        self.recorder = recorder ?? AudioRecorderService()
        self.playback = playback ?? AudioPlaybackService()
        self.engine = engine
        self.audioAnalyzer = audioAnalyzer
        self.diskChecker = diskChecker
        self.exportService = exportService ?? AudioExportService(diskChecker: diskChecker)
        self.modelValidator = modelValidator ?? OfflineLocalModelValidator(diskChecker: diskChecker)

        do {
            try profileStore.paths.ensureDirectoriesExist()
            self.profile = try profileStore.loadProfile() ?? VoiceProfile()
        } catch let studioError as StudioError {
            self.profile = VoiceProfile()
            self.lastError = studioError
        } catch {
            self.profile = VoiceProfile()
            self.lastError = .persistenceFailed(reason: error.localizedDescription)
        }

        self.readiness = engine.currentReadiness(localModelDirectory: profileStore.paths.importedModelDirectory)
        self.capabilities = engine.capabilities
        self.storageUsage = profileStore.computeStorageUsage()

        self.recorder.onInterruption = { [weak self] interruptionError in
            guard let self else { return }
            self.activeRecordingTarget = nil
            self.pendingRecordingURL = nil
            self.lastError = interruptionError
        }
    }

    // MARK: - Computed Progress & State

    public var currentPrompt: RecordingPrompt {
        let clamped = max(0, min(profile.currentPromptIndex, prompts.count - 1))
        return prompts[clamped]
    }

    public var currentPromptRecording: PromptRecording? {
        profile.recordings[currentPrompt.id]
    }

    public var recordedPromptCount: Int {
        profile.recordings.count
    }

    public var setupProgressFraction: Double {
        guard !prompts.isEmpty else { return 0 }
        return Double(recordedPromptCount) / Double(prompts.count)
    }

    public var canResumeSetup: Bool {
        profile.consent.confirmedOwnVoice && !profile.setupCompleted && recordedPromptCount > 0
    }

    public var effectiveReferencePromptID: String? {
        if let chosen = profile.primaryReferencePromptID,
           profile.recordings[chosen] != nil {
            return chosen
        }
        // Prefer the longest usable recording that isn't silent.
        let candidates = profile.recordings.values.filter {
            $0.captureAssessment.status != .silentOrTooQuiet
        }
        return candidates.max(by: { $0.durationSeconds < $1.durationSeconds })?.promptID
    }

    // MARK: - Consent & Profile

    public func confirmOwnVoiceConsent(displayName: String? = nil) {
        if let displayName {
            let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                profile.displayName = trimmed
            }
        }
        profile.consent.confirmedOwnVoice = true
        profile.consent.confirmedAt = Date()
        persistProfile()
    }

    public func updateDisplayName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        profile.displayName = trimmed
        persistProfile()
    }

    // MARK: - Guided Prompt Navigation

    public func jumpToPrompt(index: Int) {
        guard prompts.indices.contains(index) else { return }
        profile.currentPromptIndex = index
        profile.setupPaused = false
        persistProfile()
    }

    public func goToPreviousPrompt() {
        jumpToPrompt(index: max(0, profile.currentPromptIndex - 1))
    }

    public func goToNextPrompt() {
        jumpToPrompt(index: min(prompts.count - 1, profile.currentPromptIndex + 1))
    }

    public func advanceToNextUnrecordedPrompt() {
        if let nextAfterCurrent = prompts.firstIndex(where: {
            $0.index > profile.currentPromptIndex && profile.recordings[$0.id] == nil
        }) {
            jumpToPrompt(index: nextAfterCurrent)
            return
        }

        if let firstMissing = prompts.firstIndex(where: { profile.recordings[$0.id] == nil }) {
            jumpToPrompt(index: firstMissing)
            return
        }

        profile.setupCompleted = true
        profile.setupPaused = false
        persistProfile()
    }

    public func pauseSetup() {
        if recorder.isRecording {
            recorder.cancelRecording()
            activeRecordingTarget = nil
            pendingRecordingURL = nil
        }
        playback.stop()
        profile.setupPaused = true
        persistProfile()
        statusBannerMessage = "Setup paused locally. You can resume from prompt \(profile.currentPromptIndex + 1) anytime."
    }

    public func resumeSetup() {
        profile.setupPaused = false
        persistProfile()
    }

    // MARK: - Prompt Recording

    public func startPromptRecording() async {
        guard profile.consent.confirmedOwnVoice else {
            lastError = .consentRequired
            return
        }

        playback.stop()
        do {
            try diskChecker.ensureSufficientSpace(
                at: profileStore.paths.promptRecordingsDirectory,
                requiredBytes: 15_728_640 // 15 MB minimum headroom
            )
            try await recorder.requestAccessIfNeeded()

            let prompt = currentPrompt
            let fileName = "\(prompt.id)-\(UUID().uuidString.prefix(8)).wav"
            let destinationURL = profileStore.paths.promptRecordingURL(fileName: fileName)
            try recorder.startRecording(to: destinationURL)
            pendingRecordingURL = destinationURL
            activeRecordingTarget = .prompt(promptID: prompt.id)
            lastError = nil
        } catch let studioError as StudioError {
            lastError = studioError
        } catch {
            lastError = .recordingFailedToStart(reason: error.localizedDescription)
        }
    }

    public func stopAndSavePromptRecording() async {
        guard case .prompt(let promptID) = activeRecordingTarget else { return }
        let stoppedURL = recorder.stopRecording() ?? pendingRecordingURL
        activeRecordingTarget = nil
        pendingRecordingURL = nil

        guard let recordedURL = stoppedURL else {
            lastError = .audioFileCorruptedOrMissing
            return
        }

        let prompt = prompts.first(where: { $0.id == promptID }) ?? currentPrompt
        let analyzer = self.audioAnalyzer
        let minSeconds = prompt.recommendedMinimumSeconds

        do {
            let (metrics, assessment) = try await Task.detached(priority: .userInitiated) {
                let metrics = try analyzer.analyzeAudioFile(at: recordedURL)
                let assessment = analyzer.assessCapture(metrics: metrics, minimumExpectedSeconds: minSeconds)
                return (metrics, assessment)
            }.value

            if let previous = profile.recordings[prompt.id] {
                try? profileStore.deletePromptRecordingFile(named: previous.audioFileName)
            }

            let entry = PromptRecording(
                promptID: prompt.id,
                audioFileName: recordedURL.lastPathComponent,
                durationSeconds: metrics.durationSeconds,
                rmsDecibels: metrics.rmsDecibels,
                peakDecibels: metrics.peakDecibels,
                sampleRate: metrics.sampleRate,
                captureAssessment: assessment
            )
            profile.recordings[prompt.id] = entry
            if profile.recordings.count == prompts.count {
                profile.setupCompleted = true
            }
            profile.setupPaused = false
            persistProfile()
        } catch let studioError as StudioError {
            lastError = studioError
        } catch {
            lastError = .audioFileCorruptedOrMissing
        }
    }

    public func deletePromptRecording(promptID: String) {
        playback.stop()
        guard let existing = profile.recordings.removeValue(forKey: promptID) else { return }
        try? profileStore.deletePromptRecordingFile(named: existing.audioFileName)
        if profile.primaryReferencePromptID == promptID {
            profile.primaryReferencePromptID = nil
        }
        profile.setupCompleted = profile.recordings.count == prompts.count
        persistProfile()
    }

    public func setPrimaryReferencePrompt(_ promptID: String) {
        guard profile.recordings[promptID] != nil else { return }
        profile.primaryReferencePromptID = promptID
        persistProfile()
    }

    // MARK: - Targeted Pronunciation Corrections

    public func startCorrectionRecording() async {
        guard profile.consent.confirmedOwnVoice else {
            lastError = .consentRequired
            return
        }
        playback.stop()
        discardCorrectionDraft()

        do {
            try diskChecker.ensureSufficientSpace(
                at: profileStore.paths.correctionsDirectory,
                requiredBytes: 10_485_760
            )
            try await recorder.requestAccessIfNeeded()

            let fileName = "correction-\(UUID().uuidString.prefix(8)).wav"
            let url = profileStore.paths.correctionAudioURL(fileName: fileName)
            try recorder.startRecording(to: url)
            pendingRecordingURL = url
            activeRecordingTarget = .correctionDraft
            lastError = nil
        } catch let studioError as StudioError {
            lastError = studioError
        } catch {
            lastError = .recordingFailedToStart(reason: error.localizedDescription)
        }
    }

    public func stopCorrectionDraftRecording() async {
        guard activeRecordingTarget == .correctionDraft else { return }
        let stoppedURL = recorder.stopRecording() ?? pendingRecordingURL
        activeRecordingTarget = nil
        pendingRecordingURL = nil

        guard let url = stoppedURL else {
            lastError = .audioFileCorruptedOrMissing
            return
        }

        let analyzer = self.audioAnalyzer
        do {
            let (metrics, assessment) = try await Task.detached(priority: .userInitiated) {
                let metrics = try analyzer.analyzeAudioFile(at: url)
                let assessment = analyzer.assessCapture(metrics: metrics, minimumExpectedSeconds: 0.9)
                return (metrics, assessment)
            }.value
            pendingCorrectionDraftURL = url
            pendingCorrectionDraftMetrics = metrics
            pendingCorrectionDraftAssessment = assessment
        } catch let studioError as StudioError {
            lastError = studioError
        } catch {
            lastError = .audioFileCorruptedOrMissing
        }
    }

    public func discardCorrectionDraft() {
        playback.stop()
        if let draftURL = pendingCorrectionDraftURL {
            try? FileManager.default.removeItem(at: draftURL)
        }
        pendingCorrectionDraftURL = nil
        pendingCorrectionDraftMetrics = nil
        pendingCorrectionDraftAssessment = nil
    }

    public func saveCorrection(
        targetPhrase: String,
        phoneticHint: String,
        category: CorrectionCategory
    ) {
        let cleanedPhrase = targetPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedPhrase.isEmpty else {
            lastError = .emptyInputText
            return
        }
        guard let draftURL = pendingCorrectionDraftURL,
              let metrics = pendingCorrectionDraftMetrics,
              let assessment = pendingCorrectionDraftAssessment else {
            lastError = .audioFileCorruptedOrMissing
            return
        }

        let item = PronunciationCorrection(
            targetPhrase: cleanedPhrase,
            phoneticHint: phoneticHint.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            audioFileName: draftURL.lastPathComponent,
            durationSeconds: metrics.durationSeconds,
            captureAssessment: assessment
        )
        profile.corrections.insert(item, at: 0)
        pendingCorrectionDraftURL = nil
        pendingCorrectionDraftMetrics = nil
        pendingCorrectionDraftAssessment = nil
        persistProfile()
        statusBannerMessage = "Correction saved locally as profile reference material (no automatic model retraining)."
    }

    public func deleteCorrection(id: UUID) {
        playback.stop()
        guard let idx = profile.corrections.firstIndex(where: { $0.id == id }) else { return }
        let removed = profile.corrections.remove(at: idx)
        try? profileStore.deleteCorrectionAudioFile(named: removed.audioFileName)
        persistProfile()
    }

    // MARK: - Playback

    public func togglePromptPlayback(promptID: String) {
        guard let rec = profile.recordings[promptID] else { return }
        let url = profileStore.paths.promptRecordingURL(fileName: rec.audioFileName)
        togglePlayback(url: url, identifier: "prompt-\(promptID)")
    }

    public func toggleCorrectionDraftPlayback() {
        guard let url = pendingCorrectionDraftURL else { return }
        togglePlayback(url: url, identifier: "correction-draft")
    }

    public func toggleCorrectionPlayback(_ correction: PronunciationCorrection) {
        let url = profileStore.paths.correctionAudioURL(fileName: correction.audioFileName)
        togglePlayback(url: url, identifier: "correction-\(correction.id.uuidString)")
    }

    public func toggleGeneratedPlayback(_ clip: GeneratedSpeechClip) {
        let url = profileStore.paths.generatedAudioURL(fileName: clip.audioFileName)
        togglePlayback(url: url, identifier: "generated-\(clip.id.uuidString)")
    }

    private func togglePlayback(url: URL, identifier: String) {
        if playback.activeClipIdentifier == identifier {
            if playback.isPlaying {
                playback.pause()
            } else {
                playback.resume()
            }
            return
        }

        do {
            try playback.play(url: url, clipIdentifier: identifier)
            lastError = nil
        } catch let studioError as StudioError {
            lastError = studioError
        } catch {
            lastError = .playbackFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Offline Model Management & Speech Synthesis

    public func refreshModelReadiness() {
        readiness = engine.currentReadiness(localModelDirectory: profileStore.paths.importedModelDirectory)
        capabilities = engine.capabilities
        storageUsage = profileStore.computeStorageUsage()
    }

    public func importLocalModelFolder(from sourceDirectoryURL: URL) async {
        isImportingModel = true
        lastError = nil
        let destination = profileStore.paths.importedModelDirectory
        let validator = self.modelValidator

        do {
            let bundle = try await Task.detached(priority: .userInitiated) {
                try validator.importModelDirectory(from: sourceDirectoryURL, into: destination)
            }.value

            profile.importedModelDirectoryName = sourceDirectoryURL.lastPathComponent
            persistProfile()
            refreshModelReadiness()

            if case .ready = readiness {
                try await engine.loadModel(from: destination)
            }
            statusBannerMessage = "Validated and imported local model folder (\(bundle.weightFiles.count) weight file(s))."
        } catch let studioError as StudioError {
            lastError = studioError
        } catch {
            lastError = .invalidModelDirectory(reason: error.localizedDescription)
        }

        isImportingModel = false
    }

    public func removeImportedModel() async {
        await engine.unloadModel()
        do {
            try profileStore.clearImportedModelFiles()
            profile.importedModelDirectoryName = nil
            persistProfile()
            refreshModelReadiness()
            statusBannerMessage = "Removed local model weights from Application Support."
        } catch let studioError as StudioError {
            lastError = studioError
        } catch {
            lastError = .persistenceFailed(reason: error.localizedDescription)
        }
    }

    public func generateSpeech(
        text: String,
        language: String = "English",
        speakingRate: Double? = nil,
        sentencePauseSeconds: Double? = nil,
        stylePresetID: String? = nil
    ) async -> GeneratedSpeechClip? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = .emptyInputText
            return nil
        }

        guard let refID = effectiveReferencePromptID,
              let refRecording = profile.recordings[refID],
              let refPrompt = prompts.first(where: { $0.id == refID }) else {
            lastError = .missingReferenceRecording
            return nil
        }

        guard case .ready = readiness else {
            lastError = .modelUnavailable(reason: readiness.statusDetail)
            return nil
        }

        playback.stop()
        isGenerating = true
        lastError = nil
        defer { isGenerating = false }

        let outputFileName = "speech-\(UUID().uuidString.prefix(8)).wav"
        let outputURL = profileStore.paths.generatedAudioURL(fileName: outputFileName)
        let refURL = profileStore.paths.promptRecordingURL(fileName: refRecording.audioFileName)

        let request = SynthesisRequest(
            text: trimmed,
            referenceSample: ReferenceAudioSample(audioURL: refURL, transcript: refPrompt.text),
            outputWAVURL: outputURL,
            language: language,
            speakingRate: capabilities.supportsSpeakingRate ? speakingRate : nil,
            sentencePauseSeconds: capabilities.supportsPauseControl ? sentencePauseSeconds : nil,
            stylePresetID: capabilities.supportedStylePresets.isEmpty ? nil : stylePresetID
        )

        do {
            try await engine.loadModel(from: profileStore.paths.importedModelDirectory)
            let result = try await engine.synthesize(request)
            let clip = GeneratedSpeechClip(
                fullText: trimmed,
                audioFileName: result.audioURL.lastPathComponent,
                durationSeconds: result.durationSeconds,
                sampleRate: result.sampleRate,
                modelIdentifier: result.modelIdentifier,
                speakingRate: request.speakingRate,
                sentencePauseSeconds: request.sentencePauseSeconds,
                stylePresetID: request.stylePresetID
            )
            profile.generatedHistory.insert(clip, at: 0)
            persistProfile()
            logger.info("Stored generated speech clip locally.")
            return clip
        } catch let studioError as StudioError {
            try? FileManager.default.removeItem(at: outputURL)
            lastError = studioError
            return nil
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            lastError = .synthesisFailed(reason: error.localizedDescription)
            return nil
        }
    }

    public func exportGeneratedClip(
        _ clip: GeneratedSpeechClip,
        to destinationURL: URL,
        format: ExportAudioFormat
    ) async -> Bool {
        let sourceURL = profileStore.paths.generatedAudioURL(fileName: clip.audioFileName)
        do {
            try await exportService.export(sourceWAVURL: sourceURL, to: destinationURL, format: format)
            statusBannerMessage = "Exported audio locally as \(format.fileExtension.uppercased())."
            return true
        } catch let studioError as StudioError {
            lastError = studioError
            return false
        } catch {
            lastError = .exportFailed(reason: error.localizedDescription)
            return false
        }
    }

    public func deleteGeneratedClip(id: UUID) {
        playback.stop()
        guard let idx = profile.generatedHistory.firstIndex(where: { $0.id == id }) else { return }
        let clip = profile.generatedHistory.remove(at: idx)
        try? profileStore.deleteGeneratedAudioFile(named: clip.audioFileName)
        persistProfile()
    }

    public func clearGeneratedHistory() {
        playback.stop()
        do {
            try profileStore.clearAllGeneratedAudioFiles()
            profile.generatedHistory.removeAll()
            persistProfile()
            statusBannerMessage = "Cleared all generated audio history."
        } catch let studioError as StudioError {
            lastError = studioError
        } catch {
            lastError = .persistenceFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Complete Deletion

    public func deleteCompleteProfile(includeImportedModel: Bool = false) async {
        if recorder.isRecording {
            recorder.cancelRecording()
        }
        playback.stop()
        discardCorrectionDraft()
        activeRecordingTarget = nil
        pendingRecordingURL = nil

        if includeImportedModel {
            await engine.unloadModel()
        }

        do {
            try profileStore.deleteCompleteProfileAndData(includeImportedModel: includeImportedModel)
            profile = VoiceProfile()
            refreshModelReadiness()
            statusBannerMessage = includeImportedModel
                ? "Deleted voice profile, recordings, generated clips, and imported model files."
                : "Deleted voice profile, recordings, corrections, and generated clips."
        } catch let studioError as StudioError {
            lastError = studioError
        } catch {
            lastError = .persistenceFailed(reason: error.localizedDescription)
        }
    }

    public func dismissError() {
        lastError = nil
    }

    public func dismissStatusBanner() {
        statusBannerMessage = nil
    }

    private func persistProfile() {
        do {
            try profileStore.saveProfile(profile)
            storageUsage = profileStore.computeStorageUsage()
        } catch let studioError as StudioError {
            lastError = studioError
        } catch {
            lastError = .persistenceFailed(reason: error.localizedDescription)
        }
    }
}
