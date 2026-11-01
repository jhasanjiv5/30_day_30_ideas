//
//  CookingModeView.swift
//  CookLens
//

import SwiftUI
import AVFoundation

struct CookingModeView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    @State private var currentStepIndex = 0
    @State private var isSpeaking = false
    private let synthesizer = AVSpeechSynthesizer()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Progress Bar
                ProgressView(value: Double(currentStepIndex + 1), total: Double(recipe.steps.count))
                    .tint(.green)
                    .padding(.horizontal)

                HStack {
                    Text("Step \(currentStepIndex + 1) of \(recipe.steps.count)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)

                Spacer()

                // Active Step Content
                VStack(spacing: 16) {
                    Text(recipe.steps[currentStepIndex])
                        .font(.title2.weight(.medium))
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal)

                Spacer()

                // Audio Voice Assist & Navigation Controls
                HStack(spacing: 20) {
                    Button {
                        readStepAloud(recipe.steps[currentStepIndex])
                    } label: {
                        Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                            .font(.title2)
                            .padding()
                            .background(Color(.secondarySystemBackground), in: Circle())
                    }

                    Button {
                        if currentStepIndex > 0 { currentStepIndex -= 1 }
                    } label: {
                        Text("Previous")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(currentStepIndex == 0)

                    Button {
                        if currentStepIndex < recipe.steps.count - 1 {
                            currentStepIndex += 1
                        } else {
                            dismiss()
                        }
                    } label: {
                        Text(currentStepIndex == recipe.steps.count - 1 ? "Finish Cook!" : "Next Step")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle(recipe.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func readStepAloud(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        synthesizer.speak(utterance)
        isSpeaking = true
    }
}
