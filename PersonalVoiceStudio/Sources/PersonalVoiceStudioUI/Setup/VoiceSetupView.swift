import PersonalVoiceStudioCore
import SwiftUI

public struct VoiceSetupView: View {
    @ObservedObject var store: VoiceStudioStore
    @ObservedObject var recorder: AudioRecorderService
    @ObservedObject var playback: AudioPlaybackService

    public init(store: VoiceStudioStore) {
        self.store = store
        self.recorder = (store.recorder as? AudioRecorderService) ?? AudioRecorderService()
        self.playback = store.playback
    }

    public var body: some View {
        if !store.profile.consent.confirmedOwnVoice {
            ConsentGateView(store: store)
        } else {
            setupContent
        }
    }

    private var setupContent: some View {
        let prompt = store.currentPrompt
        let recording = store.currentPromptRecording
        let isRecordingThisPrompt = store.activeRecordingTarget == .prompt(promptID: prompt.id)
        let playbackID = "prompt-\(prompt.id)"
        let isPlayingThisPrompt = playback.activeClipIdentifier == playbackID && playback.isPlaying

        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerSection
                promptRail
                promptStudioCard(
                    prompt: prompt,
                    recording: recording,
                    isRecordingThisPrompt: isRecordingThisPrompt,
                    isPlayingThisPrompt: isPlayingThisPrompt
                )
            }
            .padding(24)
            .frame(maxWidth: 920, alignment: .leading)
        }
    }

    private var headerSection: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Voice Profile Setup — \(store.profile.displayName)")
                            .font(.title2.weight(.semibold))
                        Text("\(store.recordedPromptCount) of \(store.prompts.count) prompts recorded (\(StudioTheme.formatDuration(store.profile.totalRecordedDuration)) total audio)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    if store.profile.setupPaused {
                        Button("Resume Setup") {
                            store.resumeSetup()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(StudioTheme.accent)
                    } else {
                        Button("Pause & Save Progress") {
                            store.pauseSetup()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                ProgressView(value: store.setupProgressFraction)
                    .tint(StudioTheme.accent)

                if store.profile.setupCompleted {
                    Label("All \(store.prompts.count) guided prompts recorded locally. You can still redo any prompt or set a preferred reference clip.", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(StudioTheme.success)
                }
            }
        }
    }

    private var promptRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.prompts) { item in
                    let isSelected = item.index == store.currentPrompt.index
                    let rec = store.profile.recordings[item.id]

                    Button {
                        store.jumpToPrompt(index: item.index)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: iconName(for: rec))
                                .foregroundStyle(iconColor(for: rec, isSelected: isSelected))
                            Text("\(item.index + 1)")
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isSelected ? StudioTheme.accent.opacity(0.18) : Color(nsColor: .controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(isSelected ? StudioTheme.accent : Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help(item.title)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func promptStudioCard(
        prompt: RecordingPrompt,
        recording: PromptRecording?,
        isRecordingThisPrompt: Bool,
        isPlayingThisPrompt: Bool
    ) -> some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Prompt \(prompt.index + 1) of \(store.prompts.count) • \(prompt.category)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(StudioTheme.accent)
                    Spacer()
                    Text("\(prompt.lengthClass.displayLabel) length")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.secondary.opacity(0.12)))
                }

                Text(prompt.text)
                    .font(.title2.weight(.medium))
                    .lineSpacing(5)
                    .textSelection(.enabled)
                    .padding(.vertical, 6)

                Text("Speech focus: \(prompt.phoneticFocus)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                AudioLevelMeterView(
                    level: isRecordingThisPrompt ? recorder.normalizedInputLevel : 0,
                    isRecording: isRecordingThisPrompt,
                    elapsedSeconds: isRecordingThisPrompt ? recorder.elapsedSeconds : (recording?.durationSeconds ?? 0)
                )

                HStack(spacing: 10) {
                    if isRecordingThisPrompt {
                        Button {
                            Task {
                                await store.stopAndSavePromptRecording()
                            }
                        } label: {
                            Label("Stop Recording", systemImage: "stop.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    } else {
                        Button {
                            Task {
                                await store.startPromptRecording()
                            }
                        } label: {
                            Label(recording == nil ? "Record Prompt" : "Redo Recording", systemImage: "mic.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(StudioTheme.accent)
                        .disabled(store.activeRecordingTarget != nil)
                    }

                    if recording != nil {
                        Button {
                            store.togglePromptPlayback(promptID: prompt.id)
                        } label: {
                            Label(isPlayingThisPrompt ? "Pause" : "Replay", systemImage: isPlayingThisPrompt ? "pause.fill" : "play.fill")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isRecordingThisPrompt)

                        Button(role: .destructive) {
                            store.deletePromptRecording(promptID: prompt.id)
                        } label: {
                            Label("Delete Take", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isRecordingThisPrompt)
                    }

                    Spacer()

                    Button("Previous") {
                        store.goToPreviousPrompt()
                    }
                    .disabled(prompt.index == 0 || isRecordingThisPrompt)

                    Button(recording == nil ? "Skip for Now" : "Continue") {
                        store.advanceToNextUnrecordedPrompt()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(StudioTheme.accent)
                    .disabled(isRecordingThisPrompt)
                }

                if let recording {
                    Divider()
                    captureFeedbackRow(recording: recording, promptID: prompt.id)
                }
            }
        }
    }

    private func captureFeedbackRow(recording: PromptRecording, promptID: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: recording.captureAssessment.needsAttention ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(recording.captureAssessment.needsAttention ? StudioTheme.warning : StudioTheme.success)

                VStack(alignment: .leading, spacing: 2) {
                    Text(recording.captureAssessment.headline)
                        .font(.subheadline.weight(.semibold))
                    Text(recording.captureAssessment.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                let isPrimary = store.effectiveReferencePromptID == promptID
                Button(isPrimary ? "Primary Reference" : "Use as Reference") {
                    store.setPrimaryReferencePrompt(promptID)
                }
                .buttonStyle(.bordered)
                .disabled(isPrimary || recording.captureAssessment.status == .silentOrTooQuiet)
            }

            Text(CaptureAssessment.disclaimer)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func iconName(for recording: PromptRecording?) -> String {
        guard let recording else { return "circle" }
        return recording.captureAssessment.needsAttention ? "exclamationmark.circle.fill" : "checkmark.circle.fill"
    }

    private func iconColor(for recording: PromptRecording?, isSelected: Bool) -> Color {
        guard let recording else {
            return isSelected ? StudioTheme.accent : .secondary
        }
        return recording.captureAssessment.needsAttention ? StudioTheme.warning : StudioTheme.success
    }
}
