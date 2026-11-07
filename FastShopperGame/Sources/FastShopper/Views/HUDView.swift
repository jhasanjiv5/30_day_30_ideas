import SwiftUI

public struct HUDView: View {
    @ObservedObject var state: GameState
    
    public var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 20)
                .padding(.top, 16)
            
            Spacer()
            
            actionPromptBar
                .padding(.bottom, 24)
        }
        .allowsHitTesting(true)
    }
    
    private var topBar: some View {
        HStack(alignment: .top, spacing: 16) {
            // Level & 1984 Location
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("🎄 NYC 1984")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(Color(hex: "#F59E0B"))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#78350F").opacity(0.6))
                        .cornerRadius(4)
                    
                    Text(state.currentLevelConfig.title.uppercased())
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(Color(hex: state.currentLevelConfig.themeColorHex))
                }
                
                HStack(spacing: 12) {
                    Label("\(state.score)", systemImage: "sparkles")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#FDE047"))
                    
                    if state.highScores > 0 {
                        Text("Record: \(state.highScores)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#B45309").opacity(0.4), lineWidth: 1.5))
            
            Spacer()
            
            // Closing Time Countdown
            HStack(spacing: 8) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(timerColor)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("CLOSING BELL")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    Text(String(format: "%02d:%02d", Int(state.timeRemaining) / 60, Int(state.timeRemaining) % 60))
                        .font(.system(size: 20, weight: .heavy, design: .monospaced))
                        .foregroundColor(timerColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(timerColor.opacity(0.5), lineWidth: 1.5))
            
            Spacer()
            
            // Holiday Credit
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Text("CREDIT:")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    Text("$\(String(format: "%.2f", state.remainingCredit))")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(state.remainingCredit < 15 ? .orange : Color(hex: "#4ADE80"))
                    Text("/ $\(String(format: "%.2f", state.initialCredit))")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 7)
                        
                        let ratio = min(max(state.totalSpent / state.initialCredit, 0), 1.0)
                        Capsule()
                            .fill(LinearGradient(colors: [Color(hex: "#10B981"), Color(hex: "#F59E0B"), Color(hex: "#EF4444")], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(ratio), height: 7)
                    }
                }
                .frame(width: 150, height: 7)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#10B981").opacity(0.3), lineWidth: 1))
        }
    }
    
    private var timerColor: Color {
        if state.timeRemaining < 15.0 {
            return Color(hex: "#EF4444")
        } else if state.timeRemaining < 30.0 {
            return Color(hex: "#F59E0B")
        } else {
            return Color(hex: "#FDE047")
        }
    }
    
    private var actionPromptBar: some View {
        HStack {
            if state.isNearCheckout {
                HStack(spacing: 12) {
                    Text("🎁")
                        .font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.isListCompleted ? "GIFT WRAP & REGISTER OPEN" : "PRESENTS STILL MISSING!")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundColor(state.isListCompleted ? Color(hex: "#4ADE80") : Color(hex: "#F59E0B"))
                        Text(state.isListCompleted ? "Press [SPACE] or Click to Wrap & Pay" : "Fulfill all gifts on your Christmas list first!")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                    }
                    Button(action: { state.attemptCheckout() }) {
                        Text("WRAP & PAY")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(state.isListCompleted ? Color(hex: "#16A34A") : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(!state.isListCompleted)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#16A34A"), lineWidth: 2))
            } else if let item = state.nearbyItem {
                HStack(spacing: 12) {
                    Text(item.emoji)
                        .font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(item.fullName)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            Text(item.tier.qualityBadge)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(hex: "#F59E0B"))
                        }
                        Text("Price: $\(String(format: "%.2f", item.price)) • Press [SPACE] to Put in Cart")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    Button(action: { state.collectItem(item) }) {
                        Text("TAKE")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(hex: "#DC2626"))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#DC2626").opacity(0.8), lineWidth: 2))
            } else {
                HStack(spacing: 14) {
                    Text("Controls: [W A S D / Arrows] Steer Cart • [SPACE] Grab / Pay • [R] Miracle-84 AI • [P] Pause")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(10)
            }
        }
    }
}
