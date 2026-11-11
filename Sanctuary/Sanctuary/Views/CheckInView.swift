//
//  CheckInView.swift
//  Sanctuary
//
//  Evening Mood Check-in & Session Launch
//

import SwiftUI

struct CheckInView: View {
    @Bindable var viewModel: TherapySessionViewModel
    @State private var valence: Double = -0.2
    @State private var selectedEmotion: String = "Reflective"
    @State private var isShowingChat: Bool = false

    let emotions = ["Exhausted", "Overwhelmed", "Anxious", "Restless", "Reflective", "Quiet", "Relieved", "Grateful", "Content"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Calm Hero Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("EVENING DECOMPRESSION")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.indigo)
                        .tracking(1.2)

                    Text("Quiet your mind before sleep.")
                        .font(.system(.title2, design: .serif))
                        .fontWeight(.bold)

                    Text("Take 4 gentle, spacious turns with your on-device Rogerian therapist. Completely private, never counters your feelings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }

                // Apple Health State of Mind Slider
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("State of Mind", systemImage: "heart.fill")
                            .font(.headline)
                            .foregroundStyle(.pink)

                        Spacer()

                        Text("Valence: \(valence >= 0 ? "+" : "")\(String(format: "%.2f", valence))")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Unpleasant")
                            .font(.caption)
                            .foregroundStyle(valence < -0.2 ? .orange : .secondary)
                        Spacer()
                        Text("Neutral")
                            .font(.caption)
                            .foregroundStyle(abs(valence) <= 0.2 ? .primary : .secondary)
                        Spacer()
                        Text("Pleasant")
                            .font(.caption)
                            .foregroundStyle(valence > 0.2 ? .green : .secondary)
                    }

                    Slider(value: $valence, in: -1.0...1.0, step: 0.05)
                        .tint(.indigo)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))

                // Emotion Chips
                VStack(alignment: .leading, spacing: 12) {
                    Text("What feeling best describes tonight?")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    FlowLayout(spacing: 8) {
                        ForEach(emotions, id: \.self) { emotion in
                            Button {
                                selectedEmotion = emotion
                            } label: {
                                Text(emotion)
                                    .font(.footnote)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedEmotion == emotion ? Color.indigo : Color(.secondarySystemBackground))
                                    .foregroundStyle(selectedEmotion == emotion ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Privacy Callout
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.title3)
                        .foregroundStyle(.green)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("100% On-Device Neural Model")
                            .font(.footnote.weight(.semibold))
                        Text("All thoughts stay in encrypted local memory. Zero cloud transmission.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Launch Button
                Button {
                    viewModel.startSession(initialValence: valence, emotionTag: selectedEmotion)
                    isShowingChat = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Enter Evening Sanctuary")
                            .font(.headline)
                        Image(systemName: "arrow.right")
                        Spacer()
                    }
                    .padding()
                    .background(Color.indigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .indigo.opacity(0.3), radius: 8, y: 4)
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Sanctuary")
        .navigationDestination(isPresented: $isShowingChat) {
            ChatSessionView(viewModel: viewModel)
        }
    }
}

// Simple FlowLayout for emotion tag wrapping
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowMaxH: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width {
                currentX = 0
                currentY += rowMaxH + spacing
                rowMaxH = 0
            }
            rowMaxH = max(rowMaxH, size.height)
            currentX += size.width + spacing
        }
        height = currentY + rowMaxH
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var rowMaxH: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += rowMaxH + spacing
                rowMaxH = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            rowMaxH = max(rowMaxH, size.height)
            currentX += size.width + spacing
        }
    }
}
