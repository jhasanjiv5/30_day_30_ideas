import AVFoundation
import Foundation
import os

public enum MicrophoneAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

@MainActor
public protocol AudioRecordingServiceProtocol: AnyObject {
    var isRecording: Bool { get }
    var normalizedInputLevel: Float { get }
    var elapsedSeconds: TimeInterval { get }
    var onInterruption: (@MainActor (StudioError) -> Void)? { get set }

    func currentAuthorizationStatus() -> MicrophoneAuthorizationStatus
    func requestAccessIfNeeded() async throws
    func startRecording(to destinationURL: URL) throws
    func stopRecording() -> URL?
    func cancelRecording()
}

@MainActor
public final class AudioRecorderService: NSObject, AudioRecordingServiceProtocol, ObservableObject {
    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var normalizedInputLevel: Float = 0.0
    @Published public private(set) var elapsedSeconds: TimeInterval = 0.0

    public var onInterruption: (@MainActor (StudioError) -> Void)?

    private var recorder: AVAudioRecorder?
    private var activeURL: URL?
    private var meterTimer: Timer?
    private var disconnectObserver: NSObjectProtocol?
    private let logger = Logger(subsystem: "com.local.PersonalVoiceStudio", category: "AudioRecorder")

    public override init() {
        super.init()
    }

    public func currentAuthorizationStatus() -> MicrophoneAuthorizationStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }

    public func requestAccessIfNeeded() async throws {
        switch currentAuthorizationStatus() {
        case .authorized:
            return
        case .denied:
            throw StudioError.microphonePermissionDenied
        case .restricted:
            throw StudioError.microphonePermissionRestricted
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if !granted {
                throw StudioError.microphonePermissionDenied
            }
        }
    }

    public func startRecording(to destinationURL: URL) throws {
        guard !isRecording else {
            throw StudioError.recordingAlreadyInProgress
        }

        let parent = destinationURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parent.path) {
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        }

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 24_000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        let newRecorder: AVAudioRecorder
        do {
            newRecorder = try AVAudioRecorder(url: destinationURL, settings: settings)
        } catch {
            throw StudioError.recordingFailedToStart(reason: error.localizedDescription)
        }

        newRecorder.delegate = self
        newRecorder.isMeteringEnabled = true

        guard newRecorder.prepareToRecord(), newRecorder.record() else {
            throw StudioError.recordingFailedToStart(reason: "Audio hardware did not begin capture.")
        }

        self.recorder = newRecorder
        self.activeURL = destinationURL
        self.isRecording = true
        self.elapsedSeconds = 0
        self.normalizedInputLevel = 0

        startMetering()
        observeAudioHardwareDisconnect()
        logger.debug("Started microphone capture.")
    }

    public func stopRecording() -> URL? {
        cleanupObserversAndTimer()
        let url = activeURL
        recorder?.stop()
        recorder = nil
        activeURL = nil
        isRecording = false
        normalizedInputLevel = 0
        logger.debug("Stopped microphone capture.")
        return url
    }

    public func cancelRecording() {
        cleanupObserversAndTimer()
        let url = activeURL
        recorder?.stop()
        recorder = nil
        activeURL = nil
        isRecording = false
        elapsedSeconds = 0
        normalizedInputLevel = 0

        if let url, FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        logger.debug("Cancelled microphone capture.")
    }

    private func startMetering() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let recorder = self.recorder, self.isRecording else { return }
                recorder.updateMeters()
                self.elapsedSeconds = recorder.currentTime
                let power = recorder.averagePower(forChannel: 0)
                // Map -60 dBFS..0 dBFS into 0.0..1.0 for UI meter feedback.
                let clamped = max(-60.0, min(0.0, power))
                self.normalizedInputLevel = (clamped + 60.0) / 60.0
            }
        }
    }

    private func observeAudioHardwareDisconnect() {
        removeDisconnectObserver()
        disconnectObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureDevice.wasDisconnectedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isRecording else { return }
                self.cancelRecording()
                self.onInterruption?(.recordingInterrupted(reason: "Audio input device disconnected"))
            }
        }
    }

    private func cleanupObserversAndTimer() {
        meterTimer?.invalidate()
        meterTimer = nil
        removeDisconnectObserver()
    }

    private func removeDisconnectObserver() {
        if let observer = disconnectObserver {
            NotificationCenter.default.removeObserver(observer)
            disconnectObserver = nil
        }
    }
}

extension AudioRecorderService: AVAudioRecorderDelegate {
    nonisolated public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        let message = error?.localizedDescription ?? "Audio encoding error"
        Task { @MainActor [weak self] in
            guard let self, self.isRecording else { return }
            self.cancelRecording()
            self.onInterruption?(.recordingInterrupted(reason: message))
        }
    }

    nonisolated public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            Task { @MainActor [weak self] in
                guard let self, self.isRecording else { return }
                self.cancelRecording()
                self.onInterruption?(.recordingInterrupted(reason: "Recorder stopped unexpectedly"))
            }
        }
    }
}
