import SwiftUI

struct TrustCalibratedAROverlay: View {
    let proposal: MCPProposal
    let onApprove: (String) -> Void
    let onDismiss: () -> Void

    @State private var holdProgress: CGFloat = 0
    @State private var isHolding: Bool = false
    @State private var holdTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(proposal.riskTier.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tierColor)
                Spacer()
                Text("Score \(Int(proposal.confidence * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(proposal.title)
                    .font(.headline)
                Text("\(proposal.deviceName) · \(proposal.toolName)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.cyan)
            }

            Text(proposal.rationale)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Blast radius")
                    .font(.caption.weight(.semibold))
                ForEach(proposal.blastRadius, id: \.self) { impact in
                    Text("– \(impact)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Rollback: \(proposal.rollbackPlan)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if proposal.riskTier == .tier3HoldPhysical {
                HStack(spacing: 10) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.red.opacity(0.22))
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.red.opacity(0.75))
                                .frame(width: geo.size.width * holdProgress)
                        }
                        Text(isHolding ? "Confirming actuation..." : "Hold 1.2s to Actuate")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .frame(height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.red.opacity(0.55), lineWidth: 1)
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !isHolding { startHold() }
                            }
                            .onEnded { _ in
                                cancelHold()
                            }
                    )

                    Button("Cancel", action: onDismiss)
                        .buttonStyle(.bordered)
                }
            } else {
                HStack(spacing: 10) {
                    Button {
                        onApprove("iPad AR Gate")
                    } label: {
                        Label("Approve & Actuate", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Dismiss", action: onDismiss)
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(16)
        .background(Color(red: 0.067, green: 0.094, blue: 0.153))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(tierColor.opacity(0.45), lineWidth: 1)
        )
    }

    private var tierColor: Color {
        switch proposal.riskTier {
        case .tier1AutoRead: return .green
        case .tier2TapConfirm: return .orange
        case .tier3HoldPhysical: return .red
        }
    }

    private func startHold() {
        isHolding = true
        holdProgress = 0
        holdTask?.cancel()
        holdTask = Task {
            let steps = 24
            for i in 1...steps {
                if Task.isCancelled { return }
                try? await Task.sleep(for: .milliseconds(50))
                holdProgress = CGFloat(i) / CGFloat(steps)
            }
            if !Task.isCancelled {
                isHolding = false
                holdProgress = 0
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                onApprove("iPad AR Gate")
            }
        }
    }

    private func cancelHold() {
        holdTask?.cancel()
        isHolding = false
        holdProgress = 0
    }
}
