import Foundation
import os

#if canImport(MLXAudioCore) && canImport(MLXAudioTTS)
import MLXAudioCore
import MLXAudioTTS
#endif

public final class MLXLocalVoiceEngine: VoiceSynthesisEngine, @unchecked Sendable {
    public let descriptor = ModelEngineDescriptor(
        id: "mlx-qwen3-tts-0.6b-base",
        displayName: "Qwen3-TTS 12Hz 0.6B Base (MLX Apple Silicon)",
        enginePackageName: "mlx-audio-swift (MLXAudioCore + MLXAudioTTS)",
        enginePackageURL: "https://github.com/Blaizzy/mlx-audio-swift",
        engineLicense: "MIT License",
        targetModelName: "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-8bit",
        targetModelVersion: "12Hz-0.6B-Base",
        modelLicense: "Apache License 2.0",
        attributionNotice: "Inference via mlx-audio-swift (MIT, Prince Canuma / Blaizzy & contributors) on Apple MLX (MIT). Model weights: Qwen3-TTS-12Hz-0.6B-Base by Qwen Team, Alibaba Group (Apache-2.0)."
    )

    private let validator: OfflineLocalModelValidator
    private let diskChecker: DiskSpaceChecking
    private let audioAnalyzer: AudioAnalyzing
    private let logger = Logger(subsystem: "com.local.PersonalVoiceStudio", category: "Inference")

    private let stateLock = NSLock()
    private var loadedDirectoryPath: String?

    #if canImport(MLXAudioCore) && canImport(MLXAudioTTS) && arch(arm64)
    private var loadedModel: (any SpeechGenerationModel)?
    #endif

    public init(
        validator: OfflineLocalModelValidator = OfflineLocalModelValidator(),
        diskChecker: DiskSpaceChecking = DiskSpaceChecker(),
        audioAnalyzer: AudioAnalyzing = AudioAnalysisService()
    ) {
        self.validator = validator
        self.diskChecker = diskChecker
        self.audioAnalyzer = audioAnalyzer
    }

    public var isEnginePackageLinked: Bool {
        #if canImport(MLXAudioCore) && canImport(MLXAudioTTS)
        return true
        #else
        return false
        #endif
    }

    public var isAppleSilicon: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }

    public var capabilities: ModelCapabilities {
        #if canImport(MLXAudioCore) && canImport(MLXAudioTTS) && arch(arm64)
        return ModelCapabilities(
            supportsZeroShotVoiceCloning: true,
            supportsSpeakingRate: false,
            supportsPauseControl: false,
            supportedStylePresets: [],
            supportsCorrectionConditioning: false,
            supportedLanguages: ["English"]
        )
        #else
        return .unavailable
        #endif
    }

    public func currentReadiness(localModelDirectory: URL) -> ModelReadinessState {
        guard isAppleSilicon else {
            return .unsupportedArchitecture(
                guidance: "On-device MLX Apple Silicon inference requires an Apple Silicon Mac (arm64). System voices are never substituted for personal voice cloning."
            )
        }

        let validatedBundle: ValidatedModelBundle?
        do {
            validatedBundle = try validator.validate(directoryURL: localModelDirectory)
        } catch let studioError as StudioError {
            if case .invalidModelDirectory(let reason) = studioError {
                let isEmpty = !FileManager.default.fileExists(atPath: localModelDirectory.path)
                    || ((try? FileManager.default.contentsOfDirectory(atPath: localModelDirectory.path).isEmpty) ?? true)
                if isEmpty {
                    validatedBundle = nil
                } else {
                    return .invalidBundle(reason: reason)
                }
            } else {
                validatedBundle = nil
            }
        } catch {
            validatedBundle = nil
        }

        guard isEnginePackageLinked else {
            let bundleNote = validatedBundle == nil
                ? "Local weights have also not been imported yet."
                : "Your local model weights are validated and ready once the Swift package is linked."
            return .engineNotLinked(
                guidance: "The mlx-audio-swift package (MIT) is not linked into this build yet. \(bundleNote) Follow README.md to add https://github.com/Blaizzy/mlx-audio-swift (MLXAudioCore + MLXAudioTTS) in Xcode and import local Apache-2.0 Qwen3-TTS weights. No system TTS or mock voice is substituted."
            )
        }

        guard let bundle = validatedBundle else {
            return .weightsMissing(
                guidance: "No local model weights found. Download Qwen3-TTS-12Hz-0.6B-Base-8bit (Apache-2.0) externally, then click \"Import Local Model Folder…\" to validate and store it offline."
            )
        }

        return .ready(bundle: bundle)
    }

    public func validateLocalModel(at directoryURL: URL) throws -> ValidatedModelBundle {
        try validator.validate(directoryURL: directoryURL)
    }

    public func loadModel(from directoryURL: URL) async throws {
        let readiness = currentReadiness(localModelDirectory: directoryURL)
        guard case .ready(let bundle) = readiness else {
            throw StudioError.modelUnavailable(reason: readiness.statusDetail)
        }

        #if canImport(MLXAudioCore) && canImport(MLXAudioTTS) && arch(arm64)
        let alreadyLoaded = stateLock.withLock {
            loadedDirectoryPath == bundle.directoryPath && loadedModel != nil
        }
        if alreadyLoaded { return }

        logger.info("Loading validated local TTS model from disk.")
        do {
            let model = try await TTS.loadModel(modelRepo: bundle.directoryPath)
            stateLock.withLock {
                self.loadedModel = model
                self.loadedDirectoryPath = bundle.directoryPath
            }
        } catch {
            throw StudioError.modelUnavailable(reason: "Could not initialize local MLX model: \(error.localizedDescription)")
        }
        #else
        throw StudioError.modelUnavailable(reason: readiness.statusDetail)
        #endif
    }

    public func unloadModel() async {
        stateLock.withLock {
            loadedDirectoryPath = nil
            #if canImport(MLXAudioCore) && canImport(MLXAudioTTS) && arch(arm64)
            loadedModel = nil
            #endif
        }
    }

    public func synthesize(_ request: SynthesisRequest) async throws -> SynthesisResult {
        let trimmedText = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw StudioError.emptyInputText
        }

        guard FileManager.default.fileExists(atPath: request.referenceSample.audioURL.path) else {
            throw StudioError.missingReferenceRecording
        }

        try diskChecker.ensureSufficientSpace(
            at: request.outputWAVURL.deletingLastPathComponent(),
            requiredBytes: 26_214_400 // 25 MB safety margin
        )

        #if canImport(MLXAudioCore) && canImport(MLXAudioTTS) && arch(arm64)
        let model: (any SpeechGenerationModel)? = stateLock.withLock { loadedModel }
        guard let model else {
            throw StudioError.modelUnavailable(
                reason: "Local model is not loaded. Validate and load local weights in Model Setup first."
            )
        }

        do {
            let (_, refAudio) = try loadAudioArray(
                from: request.referenceSample.audioURL,
                sampleRate: model.sampleRate
            )

            let generated = try await model.generate(
                text: trimmedText,
                voice: nil,
                refAudio: refAudio,
                refText: request.referenceSample.transcript,
                language: request.language
            )

            let outputDir = request.outputWAVURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: outputDir.path) {
                try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
            }

            try AudioUtils.writeWavFile(
                samples: generated.asArray(Float.self),
                sampleRate: Double(model.sampleRate),
                fileURL: request.outputWAVURL
            )

            let metrics = try audioAnalyzer.analyzeAudioFile(at: request.outputWAVURL)
            logger.info("Completed on-device speech synthesis.")
            return SynthesisResult(
                audioURL: request.outputWAVURL,
                durationSeconds: metrics.durationSeconds,
                sampleRate: metrics.sampleRate,
                modelIdentifier: descriptor.id
            )
        } catch let studioError as StudioError {
            throw studioError
        } catch {
            throw StudioError.synthesisFailed(reason: error.localizedDescription)
        }
        #else
        throw StudioError.modelUnavailable(
            reason: "On-device MLX voice cloning engine is not available in this build. Link mlx-audio-swift on Apple Silicon and import local Qwen3-TTS weights. System voices are never substituted."
        )
        #endif
    }
}
