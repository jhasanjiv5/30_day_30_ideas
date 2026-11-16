import PersonalVoiceStudioCore
import SwiftUI

public struct ConsentGateView: View {
    @ObservedObject var store: VoiceStudioStore
    @State private var displayName: String = ""
    @State private var ownVoiceChecked: Bool = false
    @State private var localOnlyChecked: Bool = false

    public init(store: VoiceStudioStore) {
        self.store = store
        _displayName = State(initialValue: store.profile.displayName)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Before You Record")
                        .font(.largeTitle.weight(.semibold))
                    Text("Personal Voice Studio creates a local voice profile strictly on this Mac. Review and confirm how your voice data is handled.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                StudioCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("On-Device Privacy Guarantees", systemImage: "lock.shield")
                            .font(.headline)
                            .foregroundStyle(StudioTheme.accent)

                        privacyPoint(
                            title: "Your voice stays on this Mac",
                            detail: "Guided prompt recordings, pronunciation corrections, and generated audio are stored exclusively inside your local Application Support folder."
                        )
                        privacyPoint(
                            title: "No network, cloud, or telemetry",
                            detail: "This app has no user accounts, no remote APIs, no analytics, and no outbound network permission in its macOS App Sandbox."
                        )
                        privacyPoint(
                            title: "Full deletion anytime",
                            detail: "You can delete individual recordings, clear generated history, or erase your entire voice profile from Privacy & Data."
                        )
                    }
                }

                StudioCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Local Profile Name")
                            .font(.headline)

                        TextField("My Personal Voice", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 340)

                        Divider()

                        Toggle(isOn: $ownVoiceChecked) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("I confirm I am creating this profile exclusively from my own voice.")
                                    .font(.body.weight(.medium))
                                Text("Do not record or clone someone else's voice without explicit legal consent.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Toggle(isOn: $localOnlyChecked) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("I understand recordings and generated audio remain stored locally on this Mac.")
                                    .font(.body.weight(.medium))
                                Text("Microphone permission will only be requested when you click Record.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack {
                            Spacer()
                            Button("Confirm & Start Voice Setup") {
                                store.confirmOwnVoiceConsent(displayName: displayName)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(StudioTheme.accent)
                            .disabled(!ownVoiceChecked || !localOnlyChecked)
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }

    private func privacyPoint(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
