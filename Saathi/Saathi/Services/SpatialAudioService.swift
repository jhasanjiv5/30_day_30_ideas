import Foundation
import AVFAudio
import CoreMotion
import SaathiCore

/// Handles AVAudioSession (background audio + ducking), AVSpeechSynthesizer (with enhanced/Personal Voice
/// + IPA lexicon), AVAudioEnvironmentNode spatial positioning, and AirPods head gestures (nod/shake).
@MainActor
@Observable
final class SpatialAudioService: NSObject, AVSpeechSynthesizerDelegate {
    enum HeadGesture: Sendable {
        case nodYes
        case shakeNo
    }

    private let synthesizer = AVSpeechSynthesizer()
    private let motionManager = CMHeadphoneMotionManager()
    /// Owns the AVAudioEngine → player → environment-node graph used for spatial speech.
    @ObservationIgnored private let spatialRenderer = SpatialSpeechRenderer()

    private(set) var isSpeaking: Bool = false
    private(set) var isSpatialHeadTrackingActive: Bool = false
    private(set) var lastRelativeAzimuthDegrees: Double = 0
    private(set) var personalVoiceAuthorized: Bool = false

    private var headYawRadians: Double = 0
    private var lexicon: PronunciationLexicon?
    private var onHeadGesture: (@MainActor (HeadGesture) -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
        if let url = Bundle.main.url(forResource: "pronunciations", withExtension: "json") {
            lexicon = try? PronunciationLexicon.load(from: url)
        }
    }

    func configureAudioSession() async {
        await Task.detached(priority: .userInitiated) {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(
                    .playAndRecord,
                    mode: .spokenAudio,
                    options: [.duckOthers, .allowBluetoothHFP, .allowBluetoothA2DP, .defaultToSpeaker]
                )
            } catch {
                // Audio continues via captions if hardware session configuration fails.
                return
            }

            if #available(iOS 27.0, *) {
                await withCheckedContinuation { continuation in
                    session.activate { _, _ in
                        continuation.resume()
                    }
                }
            } else {
                do {
                    try session.setActive(true)
                } catch {
                    // Audio continues via captions if hardware session activation fails.
                }
            }
        }.value
    }
    func requestPersonalVoiceIfNeeded() async {
        let status = AVSpeechSynthesizer.personalVoiceAuthorizationStatus
        if status == .authorized {
            personalVoiceAuthorized = true
            return
        }
        if status == .notDetermined {
            let result = await Self.requestPersonalVoice()
            personalVoiceAuthorized = (result == .authorized)
        }
    }

    /// The authorization callback arrives on a background queue; build it outside the
    /// main actor so Swift 6 doesn't trap on an isolation check.
    private nonisolated static func requestPersonalVoice() async -> AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus {
        await withCheckedContinuation { continuation in
            AVSpeechSynthesizer.requestPersonalVoiceAuthorization { newStatus in
                continuation.resume(returning: newStatus)
            }
        }
    }

    func bestVoice(for language: SaathiLanguage) -> AVSpeechSynthesisVoice? {
        if personalVoiceAuthorized,
           let personal = AVSpeechSynthesisVoice.speechVoices().first(where: {
               $0.voiceTraits.contains(.isPersonalVoice) && $0.language.hasPrefix(language.baseLanguageCode)
           }) {
            return personal
        }
        let matching = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.lowercased().hasPrefix(language.baseLanguageCode)
        }
        return matching.first(where: { $0.quality == .premium })
            ?? matching.first(where: { $0.quality == .enhanced })
            ?? matching.first
            ?? AVSpeechSynthesisVoice(language: language.rawValue)
    }

    func startHeadphoneMotion(onGesture: @escaping @MainActor (HeadGesture) -> Void) {
        self.onHeadGesture = onGesture
        guard motionManager.isDeviceMotionAvailable else {
            isSpatialHeadTrackingActive = false
            return
        }
        isSpatialHeadTrackingActive = true
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.headYawRadians = motion.attitude.yaw
            // Simple pitch/yaw angular-rate heuristic for nod (yes) vs shake (no)
            if abs(motion.rotationRate.x) > 2.2 && abs(motion.rotationRate.y) < 0.9 {
                self.onHeadGesture?(.nodYes)
            } else if abs(motion.rotationRate.y) > 2.4 && abs(motion.rotationRate.x) < 0.9 {
                self.onHeadGesture?(.shakeNo)
            }
        }
    }

    func stopHeadphoneMotion() {
        motionManager.stopDeviceMotionUpdates()
        isSpatialHeadTrackingActive = false
        onHeadGesture = nil
    }

    func updateSpatialLandmarkBearing(
        userCoordinate: EphemeralCoordinate?,
        landmarkCoordinate: EphemeralCoordinate?
    ) {
        guard let userCoordinate, let landmarkCoordinate else { return }
        let worldBearingDeg = userCoordinate.bearingDegrees(to: landmarkCoordinate)
        let headDeg = headYawRadians * 180.0 / .pi
        let relativeDeg = (worldBearingDeg - headDeg).truncatingRemainder(dividingBy: 360.0)
        lastRelativeAzimuthDegrees = relativeDeg

        let rad = Float(relativeDeg * .pi / 180.0)
        let radius: Float = 2.0
        spatialRenderer.player.position = AVAudio3DPoint(
            x: sin(rad) * radius,
            y: 0,
            z: -cos(rad) * radius
        )
    }

    func speak(_ text: String, language: SaathiLanguage) {
        stopSpeaking()
        guard let voice = bestVoice(for: language) else {
            // Captions-only fallback when no TTS voice is installed
            return
        }
        let attributed = attributedSpeechString(for: text)
        let utterance = AVSpeechUtterance(attributedString: attributed)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.98
        utterance.prefersAssistiveTechnologySettings = true
        isSpeaking = true

        guard isSpatialHeadTrackingActive else {
            synthesizer.speak(utterance)
            return
        }
        // With AirPods: render the speech into PCM buffers and play them through the
        // environment node, so the voice comes from the landmark's direction.
        // (Plain synthesizer.speak() bypasses the 3D graph entirely.)
        let renderer = spatialRenderer
        renderer.beginUtterance()
        synthesizer.write(utterance) { @Sendable [weak self] buffer in
            let finished = renderer.schedule(buffer)
            if finished {
                Task { @MainActor in self?.isSpeaking = false }
            }
        }
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        spatialRenderer.stop()
        isSpeaking = false
    }

    private func attributedSpeechString(for text: String) -> NSAttributedString {
        let mutable = NSMutableAttributedString(string: text)
        guard let entries = lexicon?.entries else { return mutable }
        for entry in entries {
            let range = (text as NSString).range(of: entry.term, options: .caseInsensitive)
            if range.location != NSNotFound {
                mutable.addAttribute(
                    NSAttributedString.Key(AVSpeechSynthesisIPANotationAttribute),
                    value: entry.ipa,
                    range: range
                )
            }
        }
        return mutable
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}

/// Schedules synthesized speech buffers onto the 3D player node. AVSpeechSynthesizer.write
/// delivers buffers on an arbitrary thread, so this type is lock-protected and not actor-bound.
final class SpatialSpeechRenderer: @unchecked Sendable {
    private let engine = AVAudioEngine()
    let player = AVAudioPlayerNode()
    private let environment = AVAudioEnvironmentNode()
    private let lock = NSLock()
    private var connectedFormat: AVAudioFormat?

    init() {
        engine.attach(environment)
        engine.attach(player)
        // HRTF rendering is what makes a mono voice sound like it comes from a direction on headphones.
        player.renderingAlgorithm = .HRTFHQ
        engine.connect(player, to: environment, format: nil)
        engine.connect(environment, to: engine.mainMixerNode, format: nil)
    }

    func beginUtterance() {
        lock.lock(); defer { lock.unlock() }
        player.stop()
    }

    /// Returns true when the synthesizer signals the end of the utterance (empty buffer).
    func schedule(_ buffer: AVAudioBuffer) -> Bool {
        guard let pcm = buffer as? AVAudioPCMBuffer else { return false }
        guard pcm.frameLength > 0 else { return true }
        lock.lock(); defer { lock.unlock() }
        if connectedFormat != pcm.format {
            // Speech is mono; the environment node only spatializes mono inputs.
            engine.disconnectNodeOutput(player)
            engine.connect(player, to: environment, format: pcm.format)
            connectedFormat = pcm.format
        }
        if !engine.isRunning {
            do { try engine.start() } catch { return true }
        }
        player.scheduleBuffer(pcm, completionHandler: nil)
        if !player.isPlaying { player.play() }
        return false
    }

    func stop() {
        lock.lock(); defer { lock.unlock() }
        player.stop()
    }
}
