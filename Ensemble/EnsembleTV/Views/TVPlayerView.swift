import AVKit
import EnsembleCore
import SwiftUI

struct TVPlayerView: View {
    @Bindable var model: TVAppModel
    let item: MediaItem

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let player = model.avPlayer {
                AVPlayerControllerRepresentable(player: player)
                    .ignoresSafeArea()
            }

            VStack(alignment: .trailing, spacing: 20) {
                if let newcomer = model.lateJoinerPrompt {
                    HStack(spacing: 20) {
                        Image(systemName: newcomer.avatarSymbol)
                            .font(.title2)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(newcomer.displayName) just joined")
                                .font(.headline)
                            Text("Send a spoiler-free recap up to this moment?")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Button("Catch up?") {
                            model.requestRecapForLateJoiner(newcomer)
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Dismiss") {
                            model.dismissLateJoinerPrompt()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(24)
                    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 20))
                }

                if let recap = model.activeRecapOverlay {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Catch-up for \(recap.requesterName)")
                                .font(.headline)
                            Spacer()
                            Text(recap.generatedOnDeviceWithAppleIntelligence ? "Apple Intelligence" : "Template Recap")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(recap.summary)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                        if !recap.keyCharacters.isEmpty {
                            Text("Characters: \(recap.keyCharacters.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: 640, alignment: .leading)
                    .padding(28)
                    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 22))
                    .transition(.opacity)
                }
            }
            .padding(48)
        }
        .onExitCommand {
            model.closePlayer()
        }
    }
}

private struct AVPlayerControllerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
    }
}
