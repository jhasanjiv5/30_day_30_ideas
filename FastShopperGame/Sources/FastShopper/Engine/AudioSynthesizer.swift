import Foundation
import AVFoundation

public final class AudioSynthesizer {
    public static let shared = AudioSynthesizer()
    
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let format: AVAudioFormat
    
    public var isMuted: Bool = false {
        didSet {
            playerNode.volume = isMuted ? 0.0 : 0.85
        }
    }
    
    private init() {
        guard let standardFormat = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 1) else {
            fatalError("Could not create audio format")
        }
        self.format = standardFormat
        
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: standardFormat)
        playerNode.volume = 0.85
        
        do {
            try engine.start()
        } catch {
            print("Audio engine start error: \(error.localizedDescription)")
        }
    }
    
    // Generate a tone buffer with ADSR envelope
    private func makeToneBuffer(frequencies: [Float], duration: Double, type: WaveType = .sine) -> AVAudioPCMBuffer? {
        let sampleRate = Float(format.sampleRate)
        let frameCount = AVAudioFrameCount(sampleRate * Float(duration))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        
        guard let channelData = buffer.floatChannelData?[0] else { return nil }
        
        let freqCount = frequencies.count
        let segmentFrames = frameCount / AVAudioFrameCount(max(freqCount, 1))
        
        for frame in 0..<Int(frameCount) {
            let freqIndex = min(frame / Int(segmentFrames), freqCount - 1)
            let freq = frequencies[freqIndex]
            let time = Float(frame) / sampleRate
            
            // Envelope
            let attackFrames = Int(sampleRate * 0.02)
            let releaseFrames = Int(sampleRate * 0.06)
            var envelope: Float = 1.0
            
            if frame < attackFrames {
                envelope = Float(frame) / Float(attackFrames)
            } else if frame > Int(frameCount) - releaseFrames {
                envelope = Float(Int(frameCount) - frame) / Float(releaseFrames)
            }
            
            let sample: Float
            switch type {
            case .sine:
                sample = sin(2.0 * Float.pi * freq * time)
            case .square:
                sample = sin(2.0 * Float.pi * freq * time) >= 0 ? 0.6 : -0.6
            case .triangle:
                let t = (freq * time).truncatingRemainder(dividingBy: 1.0)
                sample = (abs(t - 0.5) * 4.0 - 1.0) * 0.8
            }
            
            channelData[frame] = sample * envelope * 0.35
        }
        
        return buffer
    }
    
    private enum WaveType {
        case sine
        case square
        case triangle
    }
    
    private func playBuffer(_ buffer: AVAudioPCMBuffer?) {
        guard !isMuted, let buffer = buffer else { return }
        if !engine.isRunning {
            try? engine.start()
        }
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }
    
    // Holiday Sleigh Bell Chime on gift grab
    public func playPickup() {
        let buf = makeToneBuffer(frequencies: [1318.51, 1567.98, 2093.00, 2637.02], duration: 0.22, type: .triangle)
        playBuffer(buf)
    }
    
    // 1980s Department Store Cash Register & Brass Bell
    public func playCashRegister() {
        let buf = makeToneBuffer(frequencies: [1046.50, 1318.51, 1567.98, 2093.00], duration: 0.40, type: .sine)
        playBuffer(buf)
    }
    
    public func playWarning() {
        let buf = makeToneBuffer(frequencies: [370.0, 293.66], duration: 0.16, type: .square)
        playBuffer(buf)
    }
    
    // 1984 CRT Terminal Radio Chime
    public func playCopilotBeep() {
        let buf = makeToneBuffer(frequencies: [880.0, 1174.66], duration: 0.14, type: .triangle)
        playBuffer(buf)
    }
    
    // "Jingle Bells" Victory Motif: E - E - E, E - E - E, E - G - C - D - E
    public func playWinFanfare() {
        let e4: Float = 659.25
        let g4: Float = 783.99
        let c4: Float = 523.25
        let d4: Float = 587.33
        let highC: Float = 1046.50
        
        let buf = makeToneBuffer(frequencies: [e4, e4, e4, e4, g4, c4, d4, e4, highC], duration: 0.85, type: .sine)
        playBuffer(buf)
    }
    
    public func playFailBuzzer() {
        let buf = makeToneBuffer(frequencies: [220.0, 164.81, 110.0], duration: 0.45, type: .square)
        playBuffer(buf)
    }
    
    public func playCartBump() {
        let buf = makeToneBuffer(frequencies: [100.0, 80.0], duration: 0.08, type: .triangle)
        playBuffer(buf)
    }
}
