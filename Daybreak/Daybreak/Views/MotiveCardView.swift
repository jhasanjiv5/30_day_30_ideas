import SwiftUI
import AVFoundation

public struct MotiveCardView: View {
    public let motive: Motive
    private let synthesizer = AVSpeechSynthesizer()

    public init(motive: Motive) {
        self.motive = motive
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(motive.toneTag.uppercased())
                    .font(.caption2.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.2))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())

                Spacer()

                Button(action: speakBriefing) {
                    Label("Listen", systemImage: "speaker.wave.2.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            Text(motive.headline)
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(motive.narrative)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
                .lineSpacing(3)

            Text(motive.quote)
                .font(.caption.italic())
                .foregroundStyle(.orange.opacity(0.9))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [.orange.opacity(0.85), .red.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .orange.opacity(0.25), radius: 15, x: 0, y: 8)
    }

    private func speakBriefing() {
        let text = "Good morning. \(motive.headline). \(motive.narrative) Remember: \(motive.quote)"
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }
}
