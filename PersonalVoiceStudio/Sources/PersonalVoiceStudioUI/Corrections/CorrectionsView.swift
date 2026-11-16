import PersonalVoiceStudioCore
import SwiftUI

public struct CorrectionsView: View {
    @ObservedObject var store: VoiceStudioStore
    @ObservedObject var recorder: AudioRecorderService
    @ObservedObject var playback: AudioPlaybackService

    @State private var targetPhrase: String = ""
    @State private var phoneticHint: String = ""
    @State private var selectedCategory: CorrectionCategory = .pronunciation

    public init(store: VoiceStudioStore) {
        self.store = store
        self.recorder = (store.recorder as? AudioRecorderService) ?? AudioRecorderService()
        self.playback = store.playback
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Targeted Pronunciation & Phrasing")
                        .font(.largeTitle.weight(.semibold))
                    Text("Record specific words, names, or phrases that need clearer pronunciation.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                StudioCard {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(StudioTheme.accent)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Local Profile Material (No Automatic Retraining)")
                                .font(.headline)
                            Text(
                                store.capabilities.supportsCorrectionConditioning
                                ? "Saved corrections are available locally to the active engine."
                                : "In this MVP, targeted corrections are stored locally as profile material for review and future local conditioning or fine-tuning. They do not automatically retrain model weights."
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                if !store.profile.consent.confirmedOwnVoice {
                    StudioCard {
                        Text("Confirm your own-voice consent in Voice Setup before recording targeted corrections.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    newCorrectionCard
                }

                savedCorrectionsCard
            }
            .padding(24)
            .frame(maxWidth: 920, alignment: .leading)
        }
    }

    private var newCorrectionCard: some View {
        let isRecordingDraft = store.activeRecordingTarget == .correctionDraft
        let hasDraft = store.pendingCorrectionDraftURL != nil
        let isPlayingDraft = playback.activeClipIdentifier == "correction-draft" && playback.isPlaying

        return StudioCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Record a Targeted Correction")
                    .font(.headline)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Word or Phrase")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("e.g., Alameda Corridor, schedule, or specific name", text: $targetPhrase)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Category")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Picker("Category", selection: $selectedCategory) {
                            ForEach(CorrectionCategory.allCases) { category in
                                Text(category.rawValue).tag(category)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 170)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Spoken Note or Stress Hint (Optional)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("e.g., Pause slightly before the second syllable; soft 'ch'", text: $phoneticHint)
                        .textFieldStyle(.roundedBorder)
                }

                AudioLevelMeterView(
                    level: isRecordingDraft ? recorder.normalizedInputLevel : 0,
                    isRecording: isRecordingDraft,
                    elapsedSeconds: isRecordingDraft
                        ? recorder.elapsedSeconds
                        : (store.pendingCorrectionDraftMetrics?.durationSeconds ?? 0)
                )

                HStack(spacing: 10) {
                    if isRecordingDraft {
                        Button {
                            Task {
                                await store.stopCorrectionDraftRecording()
                            }
                        } label: {
                            Label("Stop Recording", systemImage: "stop.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    } else {
                        Button {
                            Task {
                                await store.startCorrectionRecording()
                            }
                        } label: {
                            Label(hasDraft ? "Redo Example" : "Record Example", systemImage: "mic.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(StudioTheme.accent)
                        .disabled(store.activeRecordingTarget != nil)
                    }

                    if hasDraft {
                        Button {
                            store.toggleCorrectionDraftPlayback()
                        } label: {
                            Label(isPlayingDraft ? "Pause" : "Replay", systemImage: isPlayingDraft ? "pause.fill" : "play.fill")
                        }
                        .buttonStyle(.bordered)

                        Button("Discard Take", role: .destructive) {
                            store.discardCorrectionDraft()
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    Button("Save Correction Locally") {
                        store.saveCorrection(
                            targetPhrase: targetPhrase,
                            phoneticHint: phoneticHint,
                            category: selectedCategory
                        )
                        if store.lastError == nil {
                            targetPhrase = ""
                            phoneticHint = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(StudioTheme.accent)
                    .disabled(!hasDraft || targetPhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRecordingDraft)
                }

                if let assessment = store.pendingCorrectionDraftAssessment {
                    Text("\(assessment.headline) — \(assessment.detail)")
                        .font(.caption)
                        .foregroundStyle(assessment.needsAttention ? StudioTheme.warning : .secondary)
                }
            }
        }
    }

    private var savedCorrectionsCard: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Saved Local Corrections (\(store.profile.corrections.count))")
                    .font(.headline)

                if store.profile.corrections.isEmpty {
                    Text("No targeted corrections recorded yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                } else {
                    ForEach(store.profile.corrections) { item in
                        let id = "correction-\(item.id.uuidString)"
                        let isPlaying = playback.activeClipIdentifier == id && playback.isPlaying

                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(item.targetPhrase)
                                        .font(.body.weight(.semibold))
                                    Text(item.category.rawValue)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.secondary.opacity(0.14)))
                                }

                                if !item.phoneticHint.isEmpty {
                                    Text(item.phoneticHint)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Text("\(String(format: "%.1fs", item.durationSeconds)) • Stored locally \(item.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                store.toggleCorrectionPlayback(item)
                            } label: {
                                Label(isPlaying ? "Pause" : "Replay", systemImage: isPlaying ? "pause.fill" : "play.fill")
                            }
                            .buttonStyle(.bordered)

                            Button(role: .destructive) {
                                store.deleteCorrection(id: item.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)

                        if item.id != store.profile.corrections.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}
