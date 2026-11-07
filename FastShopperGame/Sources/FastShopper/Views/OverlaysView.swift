import SwiftUI

public struct OverlaysView: View {
    @ObservedObject var state: GameState
    
    public var body: some View {
        ZStack {
            switch state.phase {
            case .ready:
                readyOverlay
            case .paused:
                pausedOverlay
            case .levelCompleted:
                levelCompletedOverlay
            case .gameOver(let reason):
                gameOverOverlay(reason: reason)
            case .gameWon:
                gameWonOverlay
            case .playing:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: state.phase)
    }
    
    // MARK: - Ready / Start Screen
    private var readyOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    state.startGame()
                }
            
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Text("🎄")
                        Text("FAST SHOPPER '84")
                            .font(.system(size: 36, weight: .black, design: .serif))
                            .foregroundStyle(LinearGradient(colors: [Color(hex: "#FDE047"), Color(hex: "#EF4444"), Color(hex: "#F59E0B")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Text("🎅")
                    }
                    
                    Text("Christmas Eve in New York City • Department Store Frenzy")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundColor(Color(hex: "#FEF08A"))
                }
                
                // Current Level Card
                VStack(spacing: 12) {
                    Text(state.currentLevelConfig.title)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundColor(Color(hex: state.currentLevelConfig.themeColorHex))
                    
                    Text(state.currentLevelConfig.subtitle)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text(state.currentLevelConfig.locationNote)
                        .font(.system(size: 11, weight: .medium, design: .serif))
                        .italic()
                        .foregroundColor(.gray)
                    
                    Divider().background(Color(hex: "#B45309").opacity(0.4))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Push your vintage chrome cart through festive aisles", systemImage: "cart.fill")
                        Label("Find every holiday present on your Christmas list", systemImage: "checklist")
                        Label("Balance Canal St. savers vs Saks 5th Ave luxury with Miracle-84 AI", systemImage: "sparkles")
                        Label("Rush to Santa's Gift Wrap & Registers before closing bells toll!", systemImage: "bell.badge.fill")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#E5E7EB"))
                }
                .padding(22)
                .background(Color(hex: "#1F2937").opacity(0.85))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#D97706"), lineWidth: 1.5))
                .frame(width: 480)
                
                Button(action: { state.startGame() }) {
                    VStack(spacing: 4) {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill")
                            Text("ENTER DEPARTMENT STORE")
                                .font(.system(size: 15, weight: .black, design: .serif))
                        }
                        Text("Press [SPACE / ARROW KEYS] or Click Anywhere to Start")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#FEF08A"))
                    }
                    .frame(width: 380)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#16A34A"))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: Color(hex: "#16A34A").opacity(0.5), radius: 8)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Paused Screen
    private var pausedOverlay: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("❄️ SHOPPING PAUSED")
                    .font(.system(size: 30, weight: .black, design: .serif))
                    .foregroundColor(Color(hex: "#FEF08A"))
                
                VStack(spacing: 12) {
                    Button(action: { state.togglePause() }) {
                        Text("RESUME SHOPPING [P / ESC]")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 240)
                            .padding(.vertical, 10)
                            .background(Color(hex: "#2563EB"))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { state.restartLevel() }) {
                        Text("RESTART THIS LEVEL")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 240)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.15))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { AudioSynthesizer.shared.isMuted.toggle() }) {
                        Text(AudioSynthesizer.shared.isMuted ? "UNMUTE HOLIDAY AUDIO [M]" : "MUTE AUDIO [M]")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(30)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#B45309").opacity(0.5), lineWidth: 1.5))
        }
    }
    
    // MARK: - Level Completed Screen
    private var levelCompletedOverlay: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            
            VStack(spacing: 18) {
                Text("🎁 PRESENTS WRAPPED & PAID!")
                    .font(.system(size: 32, weight: .black, design: .serif))
                    .foregroundColor(Color(hex: "#4ADE80"))
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Holiday Budget Spent:")
                        Spacer()
                        Text("$\(String(format: "%.2f", state.totalSpent)) / $\(String(format: "%.2f", state.initialCredit))")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                    HStack {
                        Text("Remaining Credit Saved:")
                        Spacer()
                        Text("$\(String(format: "%.2f", state.remainingCredit))")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#4ADE80"))
                    }
                    HStack {
                        Text("Time Before Closing:")
                        Spacer()
                        Text("\(Int(state.timeRemaining)) seconds")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#FDE047"))
                    }
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    Text("Holiday Bonuses Earned:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    
                    ForEach(state.recentBonuses, id: \.self) { bonus in
                        Text("★ \(bonus)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(hex: "#FDE047"))
                    }
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    HStack {
                        Text("Total Holiday Score:")
                            .font(.system(size: 14, weight: .bold))
                        Spacer()
                        Text("\(state.score)")
                            .font(.system(size: 19, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: "#FDE047"))
                    }
                }
                .padding(18)
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
                .frame(width: 440)
                
                Button(action: { state.nextLevel() }) {
                    Text("HEAD TO NEXT NYC STORE ➔")
                        .font(.system(size: 14, weight: .black, design: .serif))
                        .frame(width: 280)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#16A34A"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(26)
            .background(.ultraThinMaterial)
            .cornerRadius(18)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: "#16A34A"), lineWidth: 2))
        }
    }
    
    // MARK: - Game Over Screen
    private func gameOverOverlay(reason: String) -> some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("❄️ CHRISTMAS RUN FAILED")
                    .font(.system(size: 32, weight: .black, design: .serif))
                    .foregroundColor(Color(hex: "#EF4444"))
                
                Text(reason)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
                
                VStack(spacing: 8) {
                    Text("Score: \(state.score)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "#FDE047"))
                    
                    Text("Presents secured: \(state.shoppingList.filter { $0.isCompleted }.count) of \(state.shoppingList.count)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Button(action: { state.restartLevel() }) {
                    Text("TRY RUN AGAIN ⟳")
                        .font(.system(size: 14, weight: .black, design: .serif))
                        .frame(width: 220)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#DC2626"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(30)
            .background(.ultraThinMaterial)
            .cornerRadius(18)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: "#DC2626").opacity(0.7), lineWidth: 1.5))
        }
    }
    
    // MARK: - Game Won Screen
    private var gameWonOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            
            VStack(spacing: 22) {
                Text("🎅 MANHATTAN CHRISTMAS HERO '84!")
                    .font(.system(size: 30, weight: .black, design: .serif))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "#FDE047"), Color(hex: "#EF4444"), Color(hex: "#4ADE80")], startPoint: .topLeading, endPoint: .bottomTrailing))
                
                Text("Macy's, Bloomingdale's & Saks 5th Ave Conquered Before Midnight!")
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundColor(.white)
                
                VStack(spacing: 12) {
                    Text("FINAL HOLIDAY SCORE")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    
                    Text("\(state.score)")
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "#FDE047"))
                    
                    Text("Miracle-84 AI: 'You saved Christmas in New York, pal!'")
                        .font(.system(size: 11, design: .serif))
                        .foregroundColor(Color(hex: "#FEF08A"))
                }
                .padding(20)
                .background(Color.white.opacity(0.06))
                .cornerRadius(14)
                .frame(width: 450)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#D97706"), lineWidth: 1.5))
                
                Button(action: { state.startNewGame() }) {
                    Text("PLAY CHRISTMAS RUN AGAIN 🎄")
                        .font(.system(size: 14, weight: .black, design: .serif))
                        .frame(width: 280)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#16A34A"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
    }
}
