import AVFoundation
import Foundation
import Observation
import Speech

@MainActor
@Observable
final class SpeechDictationService {
    private(set) var isRecording = false
    private(set) var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    func toggleDictation(onTranscript: @escaping @MainActor (String) -> Void) {
        if isRecording {
            stop()
            return
        }

        Task {
            let authorized = await requestAuthorization()
            guard authorized else {
                errorMessage = "Enable Speech Recognition & Microphone in Settings to dictate queries."
                return
            }
            startRecording(onTranscript: onTranscript)
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func requestAuthorization() async -> Bool {
        let speechOK = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechOK else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    private func startRecording(onTranscript: @escaping @MainActor (String) -> Void) {
        stop()
        errorMessage = nil

        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "On-device speech recognizer is currently unavailable."
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
            self.recognitionRequest = request

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
                errorMessage = "No active microphone input format is available on this device."
                stop()
                return
            }

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                request.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let result {
                        onTranscript(result.bestTranscription.formattedString)
                        if result.isFinal {
                            self.stop()
                        }
                    }
                    if let error {
                        self.errorMessage = error.localizedDescription
                        self.stop()
                    }
                }
            }
        } catch {
            errorMessage = "Could not start microphone dictation."
            stop()
        }
    }
}
