import SwiftUI

public struct PauseMenuView: View {
    @ObservedObject var gameState: GameState

    public var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("❄️ GAME PAUSED ❄️")
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundColor(.yellow)
                        .shadow(color: .black, radius: 4)

                    Text(gameState.currentLevel.title)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }

                VStack(spacing: 12) {
                    Button(action: {
                        gameState.currentScreen = .playing
                    }) {
                        Label("Resume Game", systemImage: "play.fill")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .frame(width: 240, height: 38)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .keyboardShortcut(.space, modifiers: [])

                    Button(action: {
                        gameState.startNewGame(levelNumber: gameState.currentLevel.levelNumber)
                    }) {
                        Label("Restart Level", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .frame(width: 240, height: 38)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)

                    Button(action: {
                        gameState.isMuted.toggle()
                        SoundManager.shared.setMuted(gameState.isMuted)
                    }) {
                        Label(gameState.isMuted ? "Unmute Audio" : "Mute Audio", systemImage: gameState.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .frame(width: 240, height: 38)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)

                    Button(action: {
                        gameState.currentScreen = .mainMenu
                    }) {
                        Label("Main Menu", systemImage: "house.fill")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .frame(width: 240, height: 38)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                // Controls summary
                VStack(spacing: 4) {
                    Text("CONTROLS QUICK REFERENCE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(.yellow.opacity(0.8))
                    Text("WASD: Move  |  Space: Jump  |  Shift: Sneak")
                    Text("Left-Click: Mine / Attack  |  Right-Click: Place / Eat")
                    Text("E: Crafting  |  1-9 or Scroll: Hotbar  |  Esc: Pause")
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .padding(.top, 10)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.1, green: 0.12, blue: 0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                    )
            )
            .frame(maxWidth: 420)
        }
    }
}
