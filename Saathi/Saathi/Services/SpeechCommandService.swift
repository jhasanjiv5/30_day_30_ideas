import Foundation
import AVFAudio
import Speech
import SaathiCore

/// On-device speech recognition service.
/// Prefers iOS 26 `SpeechAnalyzer` + `SpeechTranscriber`, falls back to `SFSpeechRecognizer`,
/// and degrades cleanly to touch-only input if the locale is unavailable.
@MainActor
@Observable
final class SpeechCommandService {
    private(set) var isListening: Bool = false
    private(set) var liveTranscript: String = ""
    private(set) var activeBackend: SpeechRecognitionBackend = .touchOnly

    private var audioEngine: AVAudioEngine?
    private var analyzerTask: Task<Void, Never>?
    private var sfTask: SFSpeechRecognitionTask?
    private var sfRequest: SFSpeechAudioBufferRecognitionRequest?

    private nonisolated static func requestSpeechRecognitionAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private nonisolated static func makeRecognitionTask(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        onResult: @escaping @MainActor (_ text: String, _ isFinal: Bool) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, _ in
            guard let result else { return }
            // Copy the Sendable values out before hopping to the main actor;
            // SFSpeechRecognitionResult itself is not Sendable.
            let text = result.bestTranscription.formattedString
            let isFinal = result.isFinal
            Task { @MainActor in
                onResult(text, isFinal)
            }
        }
    }

    // MARK: - Audio taps
    //
    // AVAudioNode tap blocks run on Core Audio's own thread. A closure written inside this
    // @MainActor class is inferred to be main-actor isolated, and Swift 6 traps
    // (`_dispatch_assert_queue_fail`) when such a closure runs off the main thread.
    // Building the taps in `nonisolated` helpers keeps the closures non-isolated.

    private nonisolated static func installRecognitionTap(
        on node: AVAudioInputNode,
        format: AVAudioFormat,
        request: SFSpeechAudioBufferRecognitionRequest
    ) {
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
    }

    private nonisolated static func installAnalyzerTap(
        on node: AVAudioInputNode,
        inputFormat: AVAudioFormat,
        analyzerFormat: AVAudioFormat?,
        continuation: AsyncStream<AnalyzerInput>.Continuation
    ) {
        let target = analyzerFormat.flatMap { $0 == inputFormat ? nil : $0 }
        let converter = target.flatMap { AVAudioConverter(from: inputFormat, to: $0) }
        node.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { buffer, _ in
            guard let converter, let target else {
                continuation.yield(AnalyzerInput(buffer: buffer))
                return
            }
            let ratio = target.sampleRate / inputFormat.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
            guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
            var delivered = false
            var conversionError: NSError?
            converter.convert(to: output, error: &conversionError) { _, status in
                if delivered {
                    status.pointee = .noDataNow
                    return nil
                }
                delivered = true
                status.pointee = .haveData
                return buffer
            }
            if conversionError == nil, output.frameLength > 0 {
                continuation.yield(AnalyzerInput(buffer: output))
            }
        }
    }

    func evaluateBackend(for language: SaathiLanguage) async -> SpeechRecognitionBackend {
        if SpeechTranscriber.isAvailable {
            let supported = await SpeechTranscriber.supportedLocales.contains {
                $0.language.languageCode?.identifier == language.baseLanguageCode
            }
            if supported {
                return .speechAnalyzer
            }
        }
        // Spec: speech stays on-device. Only use the legacy recognizer when it can run locally;
        // otherwise audio would be sent to Apple's servers, so fall back to touch input.
        if let recognizer = SFSpeechRecognizer(locale: language.locale),
           recognizer.isAvailable,
           recognizer.supportsOnDeviceRecognition {
            return .sfSpeechRecognizer
        }
        return .touchOnly
    }

    func startListening(
        language: SaathiLanguage,
        onCommand: @escaping @MainActor (SaathiVoiceCommand) -> Void,
        onSpeakingStateChanged: @escaping @MainActor (Bool) -> Void
    ) async {
        stopListening()

        guard await requestMicrophonePermission() else {
            activeBackend = .touchOnly
            return
        }

        let authStatus = await Self.requestSpeechRecognitionAuthorization()
        guard authStatus == .authorized else {
            activeBackend = .touchOnly
            return
        }

        let backend = await evaluateBackend(for: language)
        activeBackend = backend
        guard backend != .touchOnly else { return }

        isListening = true
        if backend == .speechAnalyzer {
            await startSpeechAnalyzer(language: language, onCommand: onCommand, onSpeakingStateChanged: onSpeakingStateChanged)
        } else {
            startLegacyRecognizer(language: language, onCommand: onCommand, onSpeakingStateChanged: onSpeakingStateChanged)
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func stopListening() {
        isListening = false
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        analyzerTask?.cancel()
        analyzerTask = nil
        sfRequest?.endAudio()
        sfTask?.cancel()
        sfRequest = nil
        sfTask = nil
    }

    private func startSpeechAnalyzer(
        language: SaathiLanguage,
        onCommand: @escaping @MainActor (SaathiVoiceCommand) -> Void,
        onSpeakingStateChanged: @escaping @MainActor (Bool) -> Void
    ) async {
        let transcriber = SpeechTranscriber(
            locale: language.locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()

        let engine = AVAudioEngine()
        self.audioEngine = engine
        let inputNode = engine.inputNode
        let format = inputNode.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            activeBackend = .touchOnly
            isListening = false
            return
        }

        // The analyzer wants its own audio format; convert microphone buffers to it.
        let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        try? await analyzer.prepareToAnalyze(in: analyzerFormat ?? format)

        Self.installAnalyzerTap(on: inputNode, inputFormat: format, analyzerFormat: analyzerFormat, continuation: inputBuilder)
        try? engine.start()

        analyzerTask = Task { [weak self] in
            async let streamRun: Void = {
                try? await analyzer.start(inputSequence: inputSequence)
            }()

            do {
                for try await result in transcriber.results {
                    guard let self, self.isListening else { break }
                    let text = String(result.text.characters)
                    self.liveTranscript = text
                    onSpeakingStateChanged(!result.isFinal && !text.isEmpty)
                    if result.isFinal && !text.isEmpty {
                        let cmd = VoiceCommandGrammar.parse(text, language: language)
                        onCommand(cmd)
                    }
                }
            } catch {
                self?.activeBackend = .touchOnly
            }
            _ = await streamRun
        }
    }

    private func startLegacyRecognizer(
        language: SaathiLanguage,
        onCommand: @escaping @MainActor (SaathiVoiceCommand) -> Void,
        onSpeakingStateChanged: @escaping @MainActor (Bool) -> Void
    ) {
        guard let recognizer = SFSpeechRecognizer(locale: language.locale),
              recognizer.supportsOnDeviceRecognition else {
            activeBackend = .touchOnly
            isListening = false
            return
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        self.sfRequest = request

        let engine = AVAudioEngine()
        self.audioEngine = engine
        let node = engine.inputNode
        let format = node.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            activeBackend = .touchOnly
            isListening = false
            return
        }

        Self.installRecognitionTap(on: node, format: format, request: request)
        try? engine.start()

        sfTask = Self.makeRecognitionTask(recognizer: recognizer, request: request) { [weak self] text, isFinal in
            guard let self else { return }
            self.liveTranscript = text
            onSpeakingStateChanged(!isFinal)
            if isFinal {
                onCommand(VoiceCommandGrammar.parse(text, language: language))
            }
        }
    }
}
