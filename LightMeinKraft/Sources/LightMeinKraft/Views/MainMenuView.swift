import SwiftUI

public struct MainMenuView: View {
    @ObservedObject var gameState: GameState
    @State private var showingHowToPlay: Bool = false

    public var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 28) {
                headerView
                levelCardsView
                bottomButtonsView
            }
            .padding(30)

            if showingHowToPlay {
                howToPlayOverlay
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.1, blue: 0.22),
                Color(red: 0.08, green: 0.18, blue: 0.32),
                Color(red: 0.15, green: 0.08, blue: 0.25)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                    .font(.system(size: 32))
                Text("LightMeinKraft")
                    .font(.system(size: 44, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: .cyan.opacity(0.8), radius: 10)
                Image(systemName: "snowflake")
                    .foregroundColor(.cyan)
                    .font(.system(size: 32))
            }

            Text("🎄 A FESTIVE 3D VOXEL MAC ADVENTURE 🎄")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(.yellow)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.red.opacity(0.8))
                )
        }
    }

    private var levelCardsView: some View {
        HStack(spacing: 20) {
            level1Card
            level2Card
        }
    }

    private var level1Card: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "tree.fill")
                    .foregroundColor(.green)
                Text("LEVEL 1")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.yellow)
            }

            Text("Snowy Taiga & Star Portal")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            Text("Gather snowy pine logs, mine candy canes, craft tools, and activate the Golden Star Portal!")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(3)

            Spacer()

            Button("Play Level 1") {
                gameState.startNewGame(levelNumber: 1)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(18)
        .frame(width: 250, height: 210)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.5))
        )
    }

    private var level2Card: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("LEVEL 2")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.yellow)
            }

            Text("Santa's Frozen Workshop")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            Text("Brave the Frost Netherrack, defeat the Abominable Frost Grinch, and place the Star of Wonder atop the Grand Tree!")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(3)

            Spacer()

            Button("Play Level 2") {
                gameState.startNewGame(levelNumber: 2)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .padding(18)
        .frame(width: 250, height: 210)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.5))
        )
    }

    private var bottomButtonsView: some View {
        HStack(spacing: 16) {
            Button(action: {
                showingHowToPlay.toggle()
            }) {
                Label("How to Play", systemImage: "questionmark.circle")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
            }
            .buttonStyle(.bordered)
            .tint(.cyan)

            Button(action: {
                gameState.isMuted.toggle()
                SoundManager.shared.setMuted(gameState.isMuted)
            }) {
                Label(gameState.isMuted ? "Sound: Off" : "Sound: On", systemImage: gameState.isMuted ? "speaker.slash" : "speaker.wave.2")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
            }
            .buttonStyle(.bordered)
            .tint(.yellow)

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Label("Quit", systemImage: "xmark.circle")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }

    private var howToPlayOverlay: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture { showingHowToPlay = false }

            VStack(spacing: 16) {
                Text("HOW TO PLAY LIGHTMEINKRAFT")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundColor(.yellow)

                VStack(alignment: .leading, spacing: 8) {
                    Text("🎮 CONTROLS:")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                    Text("• WASD / Arrow Keys: Move forward, left, backward, right")
                    Text("• Mouse Look: Look around & aim crosshair")
                    Text("• Left Click: Mine voxel blocks & attack hostile mobs")
                    Text("• Right Click: Place selected block / eat gingerbread cookies")
                    Text("• Space: Jump  |  Shift: Sneak / slow walk")
                    Text("• E / I: Open 2x2 Crafting Grid & Inventory")
                    Text("• 1-9 or Scroll Wheel: Select active Hotbar slot")
                    Text("• Esc: Pause Game")
                    Text("• Gamepad: Full native Xbox / PlayStation controller support!")

                    Divider().background(Color.gray)

                    Text("🎄 2 FESTIVE LEVELS:")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                    Text("• Level 1: Mine 5 Pine Logs, craft Planks & Torches, mine Candy Canes, and place the Star Portal to advance!")
                    Text("• Level 2: Enter Santa's Frozen Workshop, mine frost blocks, defeat the Abominable Frost Grinch, and place the Golden Star on the Grand Tree to save Christmas!")
                }
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white)
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))

                Button("Close") {
                    showingHowToPlay = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            }
            .padding(24)
            .frame(maxWidth: 520)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.1, green: 0.12, blue: 0.18))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyan, lineWidth: 1.5))
            )
        }
    }
}
