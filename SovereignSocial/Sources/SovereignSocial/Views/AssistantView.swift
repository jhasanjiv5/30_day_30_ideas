import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct AssistantView: View {
    @EnvironmentObject var reasoning: OnDeviceReasoningModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var queryText = "Plan a launch campaign"

    private var secondaryBackgroundColor: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Image(systemName: "cpu")
                            .font(.title2)
                            .foregroundStyle(.indigo)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("Apple Foundation Models")
                                    .font(.subheadline).bold()
                                Text(reasoning.isModelAvailable ? "Ready" : "Unavailable")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background((reasoning.isModelAvailable ? Color.green : Color.orange).opacity(0.2))
                                    .foregroundStyle(reasoning.isModelAvailable ? .green : .orange)
                                    .clipShape(Capsule())
                            }
                            Text(reasoning.availabilityMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !reasoning.isModelAvailable {
                                Button("Check availability again") {
                                    reasoning.updateAvailability()
                                }
                                .font(.caption)
                            }
                        }
                        Spacer()
                    }
                    .padding()
                    .background(secondaryBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    TextField("Ask for a campaign or content idea", text: $queryText, axis: .vertical)
                        .lineLimit(1...3)
                        .textFieldStyle(.roundedBorder)
                        .disabled(reasoning.isThinking)

                    if reasoning.isThinking {
                        ProgressView("Generating on device…")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !reasoning.streamedOutput.isEmpty {
                        Text(.init(reasoning.streamedOutput))
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(secondaryBackgroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    if let errorMessage = reasoning.errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("On-Device Brain")
            .onAppear {
                reasoning.updateAvailability()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    reasoning.updateAvailability()
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Generate Strategy") {
                        Task {
                            await reasoning.generateStrategy(for: .sample, query: queryText)
                        }
                    }
                    .disabled(!reasoning.isModelAvailable || reasoning.isThinking || queryText.isEmpty)
                }
            }
        }
    }
}
