import SwiftUI

public struct CopilotHUDView: View {
    @ObservedObject var state: GameState
    @State private var isThoughtsExpanded: Bool = false
    
    public var body: some View {
        HStack(alignment: .top) {
            // LEFT PANEL: Dynamic 1984 Christmas Gift List
            shoppingListCard
                .frame(width: 255)
                .padding(.leading, 20)
                .padding(.top, 80)
            
            Spacer()
            
            // RIGHT PANEL: Miracle-84 AI Holiday Concierge
            copilotReasonerCard
                .frame(width: 320)
                .padding(.trailing, 20)
                .padding(.top, 80)
        }
    }
    
    // MARK: - Christmas Gift List Card
    private var shoppingListCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("🎁 CHRISTMAS LIST")
                    .font(.system(size: 12, weight: .black, design: .serif))
                    .foregroundColor(Color(hex: "#FEF08A"))
                Spacer()
                Text("\(state.shoppingList.filter { $0.isCompleted }.count)/\(state.shoppingList.count) GIFTS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#4ADE80"))
            }
            .padding(.bottom, 2)
            
            Divider().background(Color(hex: "#B45309").opacity(0.4))
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(state.shoppingList) { target in
                        HStack(spacing: 10) {
                            Text(target.emoji)
                                .font(.system(size: 18))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(target.targetBaseName)
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundColor(target.isCompleted ? .gray : .white)
                                    .strikethrough(target.isCompleted)
                                
                                Text("Aisle \(target.category.aisleNumber) • \(target.category.rawValue)")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(Color(hex: "#D1D5DB"))
                            }
                            
                            Spacer()
                            
                            if let acquired = target.acquiredProduct {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color(hex: "#4ADE80"))
                                        .font(.system(size: 13))
                                    Text("$\(String(format: "%.2f", acquired.price))")
                                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                        .foregroundColor(Color(hex: "#4ADE80"))
                                }
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray.opacity(0.6))
                                    .font(.system(size: 13))
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(target.isCompleted ? Color(hex: "#166534").opacity(0.2) : Color.white.opacity(0.04))
                        .cornerRadius(6)
                    }
                }
            }
            .frame(maxHeight: 280)
            
            // Cart total
            HStack {
                Text("Cart Total:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
                Spacer()
                Text("$\(String(format: "%.2f", state.totalSpent))")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#FDE047"))
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#B45309").opacity(0.4), lineWidth: 1.5))
    }
    
    // MARK: - Miracle-84 AI Card
    private var copilotReasonerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(urgencyColor)
                        .frame(width: 8, height: 8)
                    Text("🎅 \(state.copilot.assistantName)")
                        .font(.system(size: 12, weight: .black, design: .serif))
                        .foregroundColor(Color(hex: "#FEF08A"))
                }
                Spacer()
                Text("MACY'S CRT '84")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#F59E0B"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#78350F").opacity(0.4))
                    .cornerRadius(4)
            }
            
            Divider().background(Color(hex: "#B45309").opacity(0.4))
            
            // Headline & Message
            VStack(alignment: .leading, spacing: 6) {
                Text(state.copilotAdvice.headline)
                    .font(.system(size: 12.5, weight: .bold, design: .serif))
                    .foregroundColor(urgencyColor)
                
                Text(state.copilotAdvice.message)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.92))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(urgencyColor.opacity(0.12))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(urgencyColor.opacity(0.35), lineWidth: 1))
            
            // Recommended Tier badge
            if let recTier = state.copilotAdvice.recommendedTier {
                HStack(spacing: 6) {
                    Text("Suggested Tier:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                    Text(recTier.qualityBadge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "#FDE047"))
                }
            }
            
            // Model Trace
            Button(action: { isThoughtsExpanded.toggle() }) {
                HStack {
                    Image(systemName: isThoughtsExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                    Text("1984 Mainframe Trace (\(state.copilot.thoughtLog.count))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                    Spacer()
                }
                .foregroundColor(Color(hex: "#F59E0B"))
            }
            .buttonStyle(.plain)
            
            if isThoughtsExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(state.copilot.thoughtLog.suffix(3), id: \.self) { thought in
                        Text("• \(thought)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Color(hex: "#D1D5DB"))
                    }
                }
                .padding(6)
                .background(Color.black.opacity(0.35))
                .cornerRadius(6)
            }
            
            // Consult Action Button
            Button(action: {
                AudioSynthesizer.shared.playCopilotBeep()
                state.copilotAdvice = CopilotAdvice(
                    timestamp: Date(),
                    headline: "Miracle-84 Live Advice",
                    message: state.copilot.consultOnDemand(
                        cartPosition: state.cartController.position,
                        shoppingList: state.shoppingList,
                        remainingCredit: state.remainingCredit,
                        timeRemaining: state.timeRemaining
                    ),
                    targetAisle: nil,
                    recommendedTier: nil,
                    urgency: .suggestion
                )
            }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Consult Miracle-84 [R]")
                        .font(.system(size: 11, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Color(hex: "#D97706").opacity(0.3))
                .foregroundColor(Color(hex: "#FDE047"))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#D97706").opacity(0.6), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#B45309").opacity(0.4), lineWidth: 1.5))
    }
    
    private var urgencyColor: Color {
        switch state.copilotAdvice.urgency {
        case .normal: return Color(hex: "#38BDF8")
        case .suggestion: return Color(hex: "#FDE047")
        case .alert: return Color(hex: "#F87171")
        case .victory: return Color(hex: "#4ADE80")
        }
    }
}
