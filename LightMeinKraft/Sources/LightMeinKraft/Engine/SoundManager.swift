import Foundation
import AVFoundation

@MainActor
public final class SoundManager {
    public static let shared = SoundManager()

    private var players: [String: AVAudioPlayer] = [:]
    private var isMuted: Bool = false

    private init() {
        prepareSounds()
    }

    public func setMuted(_ muted: Bool) {
        self.isMuted = muted
    }

    public func playBlockBreak() {
        play(soundKey: "break")
    }

    public func playBlockPlace() {
        play(soundKey: "place")
    }

    public func playHurt() {
        play(soundKey: "hurt")
    }

    public func playStep() {
        play(soundKey: "step")
    }

    public func playCraft() {
        play(soundKey: "craft")
    }

    public func playQuestComplete() {
        play(soundKey: "quest")
    }

    public func playCreeperHiss() {
        play(soundKey: "hiss")
    }

    public func playExplosion() {
        play(soundKey: "explosion")
    }

    public func playMobDefeated() {
        play(soundKey: "defeat")
    }

    public func playFanfare() {
        play(soundKey: "fanfare")
    }

    private func play(soundKey: String) {
        guard !isMuted else { return }
        if let player = players[soundKey] {
            if player.isPlaying {
                player.currentTime = 0
            }
            player.play()
        }
    }

    private func prepareSounds() {
        // Synthesize WAV data for each sound effect
        if let data = synthesizeCrunch(duration: 0.12, sampleRate: 22050) {
            players["break"] = try? AVAudioPlayer(data: data)
            players["break"]?.volume = 0.5
        }
        if let data = synthesizePop(duration: 0.08, sampleRate: 22050) {
            players["place"] = try? AVAudioPlayer(data: data)
            players["place"]?.volume = 0.6
        }
        if let data = synthesizeHurt(duration: 0.25, sampleRate: 22050) {
            players["hurt"] = try? AVAudioPlayer(data: data)
            players["hurt"]?.volume = 0.7
        }
        if let data = synthesizeStep(duration: 0.06, sampleRate: 22050) {
            players["step"] = try? AVAudioPlayer(data: data)
            players["step"]?.volume = 0.3
        }
        if let data = synthesizeChime(duration: 0.18, sampleRate: 22050) {
            players["craft"] = try? AVAudioPlayer(data: data)
            players["craft"]?.volume = 0.6
        }
        if let data = synthesizeArpeggio(sampleRate: 22050) {
            players["quest"] = try? AVAudioPlayer(data: data)
            players["quest"]?.volume = 0.7
        }
        if let data = synthesizeHiss(duration: 1.2, sampleRate: 22050) {
            players["hiss"] = try? AVAudioPlayer(data: data)
            players["hiss"]?.volume = 0.6
        }
        if let data = synthesizeExplosion(duration: 0.6, sampleRate: 22050) {
            players["explosion"] = try? AVAudioPlayer(data: data)
            players["explosion"]?.volume = 0.8
        }
        if let data = synthesizeVictory(sampleRate: 22050) {
            players["defeat"] = try? AVAudioPlayer(data: data)
            players["defeat"]?.volume = 0.8
        }
        if let data = synthesizeJingleBells(sampleRate: 22050) {
            players["fanfare"] = try? AVAudioPlayer(data: data)
            players["fanfare"]?.volume = 0.9
        }
    }

    // MARK: - WAV Audio Synthesizers

    private func makeWAVHeader(dataSize: Int, sampleRate: Int, channels: Int = 1, bitsPerSample: Int = 16) -> Data {
        var header = Data()
        let byteRate = sampleRate * channels * (bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let totalSize = 36 + dataSize

        header.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        header.append(contentsOf: withUnsafeBytes(of: UInt32(totalSize).littleEndian) { Array($0) })
        header.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"

        header.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        header.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) }) // Subchunk1Size
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // PCM
        header.append(contentsOf: withUnsafeBytes(of: UInt16(channels).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt32(byteRate).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt16(blockAlign).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian) { Array($0) })

        header.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        header.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })

        return header
    }

    private func synthesizeCrunch(duration: Float, sampleRate: Int) -> Data? {
        let sampleCount = Int(Float(sampleRate) * duration)
        var samples = [Int16]()
        samples.reserveCapacity(sampleCount)

        for i in 0..<sampleCount {
            let progress = Float(i) / Float(sampleCount)
            let env = 1.0 - progress
            let noise = Float.random(in: -1.0...1.0)
            let lowTone = sin(Float(i) * 0.08) * 0.3
            let sample = Int16(clamping: Int((noise * 0.7 + lowTone) * env * 18000))
            samples.append(sample)
        }

        let byteCount = sampleCount * 2
        var data = makeWAVHeader(dataSize: byteCount, sampleRate: sampleRate)
        samples.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }

    private func synthesizePop(duration: Float, sampleRate: Int) -> Data? {
        let sampleCount = Int(Float(sampleRate) * duration)
        var samples = [Int16]()
        samples.reserveCapacity(sampleCount)

        for i in 0..<sampleCount {
            let progress = Float(i) / Float(sampleCount)
            let env = pow(1.0 - progress, 2.0)
            let freq = 600.0 - (progress * 300.0)
            let sample = Int16(clamping: Int(sin(Float(i) * Float(2.0 * .pi) * freq / Float(sampleRate)) * env * 22000))
            samples.append(sample)
        }

        let byteCount = sampleCount * 2
        var data = makeWAVHeader(dataSize: byteCount, sampleRate: sampleRate)
        samples.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }

    private func synthesizeHurt(duration: Float, sampleRate: Int) -> Data? {
        let sampleCount = Int(Float(sampleRate) * duration)
        var samples = [Int16]()
        samples.reserveCapacity(sampleCount)

        for i in 0..<sampleCount {
            let progress = Float(i) / Float(sampleCount)
            let env = 1.0 - progress
            let freq = 180.0 - (progress * 100.0)
            let sample = Int16(clamping: Int(sin(Float(i) * Float(2.0 * .pi) * freq / Float(sampleRate)) * env * 24000))
            samples.append(sample)
        }

        let byteCount = sampleCount * 2
        var data = makeWAVHeader(dataSize: byteCount, sampleRate: sampleRate)
        samples.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }

    private func synthesizeStep(duration: Float, sampleRate: Int) -> Data? {
        let sampleCount = Int(Float(sampleRate) * duration)
        var samples = [Int16]()
        samples.reserveCapacity(sampleCount)

        for i in 0..<sampleCount {
            let progress = Float(i) / Float(sampleCount)
            let env = 1.0 - progress
            let noise = Float.random(in: -1.0...1.0)
            let sample = Int16(clamping: Int(noise * env * 8000))
            samples.append(sample)
        }

        let byteCount = sampleCount * 2
        var data = makeWAVHeader(dataSize: byteCount, sampleRate: sampleRate)
        samples.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }

    private func synthesizeChime(duration: Float, sampleRate: Int) -> Data? {
        let sampleCount = Int(Float(sampleRate) * duration)
        var samples = [Int16]()
        samples.reserveCapacity(sampleCount)

        for i in 0..<sampleCount {
            let progress = Float(i) / Float(sampleCount)
            let env = 1.0 - progress
            let s1 = sin(Float(i) * Float(2.0 * .pi) * 880.0 / Float(sampleRate))
            let s2 = sin(Float(i) * Float(2.0 * .pi) * 1320.0 / Float(sampleRate))
            let sample = Int16(clamping: Int((s1 * 0.6 + s2 * 0.4) * env * 16000))
            samples.append(sample)
        }

        let byteCount = sampleCount * 2
        var data = makeWAVHeader(dataSize: byteCount, sampleRate: sampleRate)
        samples.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }

    private func synthesizeArpeggio(sampleRate: Int) -> Data? {
        // C - E - G - C arpeggio
        let notes: [Float] = [523.25, 659.25, 783.99, 1046.50]
        let noteDuration = 0.08
        let totalCount = Int(Double(sampleRate) * noteDuration * Double(notes.count))
        var samples = [Int16]()
        samples.reserveCapacity(totalCount)

        let noteSamples = Int(Double(sampleRate) * noteDuration)
        for (idx, freq) in notes.enumerated() {
            for i in 0..<noteSamples {
                let progress = Float(i) / Float(noteSamples)
                let env = 1.0 - (progress * 0.7)
                let s = sin(Float(idx * noteSamples + i) * Float(2.0 * .pi) * freq / Float(sampleRate))
                samples.append(Int16(clamping: Int(s * env * 18000)))
            }
        }

        let byteCount = samples.count * 2
        var data = makeWAVHeader(dataSize: byteCount, sampleRate: sampleRate)
        samples.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }

    private func synthesizeHiss(duration: Float, sampleRate: Int) -> Data? {
        let sampleCount = Int(Float(sampleRate) * duration)
        var samples = [Int16]()
        samples.reserveCapacity(sampleCount)

        for i in 0..<sampleCount {
            let progress = Float(i) / Float(sampleCount)
            let env = 0.2 + (progress * 0.8) // Gets louder
            let noise = Float.random(in: -1.0...1.0)
            let sample = Int16(clamping: Int(noise * env * 15000))
            samples.append(sample)
        }

        let byteCount = sampleCount * 2
        var data = makeWAVHeader(dataSize: byteCount, sampleRate: sampleRate)
        samples.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }

    private func synthesizeExplosion(duration: Float, sampleRate: Int) -> Data? {
        let sampleCount = Int(Float(sampleRate) * duration)
        var samples = [Int16]()
        samples.reserveCapacity(sampleCount)

        for i in 0..<sampleCount {
            let progress = Float(i) / Float(sampleCount)
            let env = pow(1.0 - progress, 1.5)
            let noise = Float.random(in: -1.0...1.0)
            let low = sin(Float(i) * 0.03) * 0.6
            let sample = Int16(clamping: Int((noise * 0.7 + low) * env * 28000))
            samples.append(sample)
        }

        let byteCount = sampleCount * 2
        var data = makeWAVHeader(dataSize: byteCount, sampleRate: sampleRate)
        samples.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }

    private func synthesizeVictory(sampleRate: Int) -> Data? {
        // High triumph notes
        let notes: [Float] = [587.33, 659.25, 783.99, 1174.66]
        let noteDuration = 0.12
        var samples = [Int16]()

        let noteSamples = Int(Double(sampleRate) * noteDuration)
        for freq in notes {
            for i in 0..<noteSamples {
                let env = 1.0 - (Float(i) / Float(noteSamples) * 0.5)
                let s = sin(Float(i) * Float(2.0 * .pi) * freq / Float(sampleRate))
                samples.append(Int16(clamping: Int(s * env * 20000)))
            }
        }

        let byteCount = samples.count * 2
        var data = makeWAVHeader(dataSize: byteCount, sampleRate: sampleRate)
        samples.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }

    private func synthesizeJingleBells(sampleRate: Int) -> Data? {
        // "Jingle bells, jingle bells, jingle all the way" (E E E, E E E, E G C D E)
        let melody: [(freq: Float, dur: Double)] = [
            (659.25, 0.15), (659.25, 0.15), (659.25, 0.30),
            (659.25, 0.15), (659.25, 0.15), (659.25, 0.30),
            (659.25, 0.15), (783.99, 0.15), (523.25, 0.20), (587.33, 0.15), (659.25, 0.40)
        ]
        var samples = [Int16]()

        for (freq, dur) in melody {
            let noteSamples = Int(Double(sampleRate) * dur)
            for i in 0..<noteSamples {
                let progress = Float(i) / Float(noteSamples)
                let env = 1.0 - progress
                // Bright square / chime waveform
                let sine = sin(Float(i) * Float(2.0 * .pi) * freq / Float(sampleRate))
                let overtone = sin(Float(i) * Float(4.0 * .pi) * freq / Float(sampleRate)) * 0.3
                samples.append(Int16(clamping: Int((sine + overtone) * env * 16000)))
            }
            // Small pause between notes
            let pauseSamples = Int(Double(sampleRate) * 0.03)
            samples.append(contentsOf: [Int16](repeating: 0, count: pauseSamples))
        }

        let byteCount = samples.count * 2
        var data = makeWAVHeader(dataSize: byteCount, sampleRate: sampleRate)
        samples.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }
}
