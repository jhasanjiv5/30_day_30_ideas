import AppKit
import PersonalVoiceStudioCore
import SwiftUI

public struct PrivacyAndDataView: View {
    @ObservedObject var store: VoiceStudioStore

    @State private var showDeleteProfileConfirm: Bool = false
    @State private var alsoDeleteImportedModel: Bool = false
    @State private var showClearHistoryConfirm: Bool = false

    public init(store: VoiceStudioStore) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Privacy & Local Storage")
                        .font(.largeTitle.weight(.semibold))
                    Text("Manage on-device recordings, generated audio history, and complete profile deletion.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                StudioCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Strict Offline Operation", systemImage: "hand.raised.fill")
                            .font(.headline)
                            .foregroundStyle(StudioTheme.accent)

                        Text("• All voice recordings, targeted corrections, and generated audio remain on this Mac.\n• The macOS App Sandbox entitlements exclude network client access—no cloud APIs, telemetry, analytics, or user accounts exist.\n• Microphone access is requested only when you press Record.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)

                        if let confirmedAt = store.profile.consent.confirmedAt {
                            Text("Own-voice consent confirmed on \(confirmedAt.formatted(date: .abbreviated, time: .shortened)).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                StudioCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Local Storage Folder")
                                .font(.headline)
                            Spacer()
                            Button("Reveal in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([store.profileStore.paths.rootDirectory])
                            }
                            .buttonStyle(.bordered)
                        }

                        Text(store.profileStore.paths.rootDirectory.path)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)

                        Divider()

                        storageRow("Prompt Recordings (\(store.profile.recordings.count))", bytes: store.storageUsage.recordingsBytes)
                        storageRow("Targeted Corrections (\(store.profile.corrections.count))", bytes: store.storageUsage.correctionsBytes)
                        storageRow("Generated Audio Clips (\(store.profile.generatedHistory.count))", bytes: store.storageUsage.generatedBytes)
                        storageRow("Imported Local Model Files", bytes: store.storageUsage.modelBytes)
                        Divider()
                        storageRow("Total Local Storage", bytes: store.storageUsage.totalBytes, emphasized: true)
                    }
                }

                StudioCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Delete Local Data")
                            .font(.headline)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Clear Generated Audio History")
                                    .font(.subheadline.weight(.medium))
                                Text("Deletes all locally generated clips while keeping your voice profile and prompt recordings.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Clear History", role: .destructive) {
                                showClearHistoryConfirm = true
                            }
                            .buttonStyle(.bordered)
                            .disabled(store.profile.generatedHistory.isEmpty)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Delete Complete Voice Profile")
                                        .font(.subheadline.weight(.medium))
                                    Text("Erases your consent record, all prompt recordings, targeted corrections, and generated clips.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Delete Profile…", role: .destructive) {
                                    showDeleteProfileConfirm = true
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(StudioTheme.danger)
                            }

                            Toggle("Also delete imported local model weights", isOn: $alsoDeleteImportedModel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 920, alignment: .leading)
        }
        .confirmationDialog(
            "Clear all generated audio history?",
            isPresented: $showClearHistoryConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear Generated History", role: .destructive) {
                store.clearGeneratedHistory()
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete complete voice profile and recordings?",
            isPresented: $showDeleteProfileConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Everything Selected", role: .destructive) {
                Task {
                    await store.deleteCompleteProfile(includeImportedModel: alsoDeleteImportedModel)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your local voice recordings, corrections, and generated audio files from this Mac.")
        }
    }

    private func storageRow(_ title: String, bytes: Int64, emphasized: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(emphasized ? .subheadline.weight(.semibold) : .subheadline)
            Spacer()
            Text(StudioTheme.formatBytes(bytes))
                .font((emphasized ? Font.subheadline.weight(.semibold) : Font.subheadline).monospacedDigit())
                .foregroundStyle(emphasized ? .primary : .secondary)
        }
    }
}
