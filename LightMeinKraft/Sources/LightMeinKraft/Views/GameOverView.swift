import SwiftUI

public struct GameOverView: View {
    @ObservedObject var gameState: GameState
    public let isVictory: Bool

    public var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                if isVictory {
                    VStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.yellow)
                            .shadow(color: .yellow, radius: 15)

                        Text("CHRISTMAS SAVED!")
                            .font(.system(size: 34, weight: .black, design: .monospaced))
                            .foregroundColor(.yellow)
                            .shadow(color: .orange, radius: 10)

                        Text("You placed the Star of Wonder atop the Grand Tree and banished the Frost Grinch!")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "skull.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.red)

                        Text("YOU DIED!")
                            .font(.system(size: 38, weight: .black, design: .monospaced))
                            .foregroundColor(.red)
                            .shadow(color: .red, radius: 10)

                        Text("The winter cold or festive mobs overcame you...")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                // Stats Card
                VStack(spacing: 8) {
                    statRow(label: "FINAL SCORE", value: "\(gameState.score)", color: .yellow)
                    statRow(label: "BLOCKS MINED", value: "\(gameState.blocksMinedCount)", color: .cyan)
                    statRow(label: "MOBS DEFEATED", value: "\(gameState.mobsDefeatedCount)", color: .green)
                    statRow(label: "LEVEL REACHED", value: "Level \(gameState.currentLevel.levelNumber)", color: .purple)
                }
                .padding(16)
                .frame(width: 300)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isVictory ? Color.yellow.opacity(0.5) : Color.red.opacity(0.5), lineWidth: 1.5)
                        )
                )

                // Actions
                HStack(spacing: 16) {
                    Button(action: {
                        gameState.startNewGame(levelNumber: isVictory ? 1 : gameState.currentLevel.levelNumber)
                    }) {
                        Label(isVictory ? "Play Again" : "Respawn", systemImage: isVictory ? "arrow.clockwise" : "heart.fill")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .frame(width: 140, height: 38)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isVictory ? .green : .red)

                    Button(action: {
                        gameState.currentScreen = .mainMenu
                    }) {
                        Label("Main Menu", systemImage: "house.fill")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .frame(width: 140, height: 38)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(red: 0.08, green: 0.1, blue: 0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isVictory ? Color.yellow : Color.red.opacity(0.6), lineWidth: 2)
                    )
            )
            .frame(maxWidth: 480)
        }
    }

    private func statRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(color)
        }
    }
}
