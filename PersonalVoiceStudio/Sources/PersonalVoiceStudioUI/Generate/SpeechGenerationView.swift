import AppKit
import PersonalVoiceStudioCore
import SwiftUI
import UniformTypeIdentifiers

public struct SpeechGenerationView: View {
    @ObservedObject var store: VoiceStudioStore
    @ObservedObject var playback: AudioPlaybackService
    var onOpenModelSetup: () -> Void

    @State private var inputText: String = ""
    @State private var selectedLanguage: String = "English"
    @State private var speakingRate: Double = 1.0
    @State private var sentencePauseSeconds: Double = 0.35
    @State private var selectedStylePresetID: String = ""
    @State private var selectedExportFormat: ExportAudioFormat = .wav

    public init(store: VoiceStudioStore, onOpenModelSetup: @escaping () -> Void) {
        self.store = store
        self.playback = store.playback
        self.onOpenModelSetup = onOpenModelSetup
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerAndDisclosure
                readinessBanner
                editorCard
                historySection
            }
            .padding(24)
            .frame(maxWidth: 920, alignment: .leading)
        }
        .onAppear {
            if let firstLang = store.capabilities.supportedLanguages.first {
                selectedLanguage = firstLang
            }
            if let firstStyle = store.capabilities.supportedStylePresets.first {
                selectedStylePresetID = firstStyle.id
            }
        }
    }

    private var headerAndDisclosure: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Generate Speech")
                .font(.largeTitle.weight(.semibold))
            Text("Generated audio is synthesized locally on this Mac from your reference recordings. It is an approximation—not an exact replica of your voice.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var readinessBanner: some View {
        if !store.readiness.isReadyForInference {
            StudioCard {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundStyle(StudioTheme.warning)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.readiness.statusTitle)
                            .font(.headline)
                        Text(store.readiness.statusDetail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Button("Open Offline Model Setup") {
                                onOpenModelSetup()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(StudioTheme.accent)
                        }
                        .padding(.top, 2)
                    }
                }
            }
        }
    }

    private var editorCard: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Script to Speak")
                        .font(.headline)
                    Spacer()
                    Text("\(inputText.trimmingCharacters(in: .whitespacesAndNewlines).count) characters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextEditor(text: $inputText)
                    .font(.body)
                    .frame(minHeight: 130, maxHeight: 220)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )

                referenceSelectionRow
                supportedControlsSection

                HStack {
                    if store.isGenerating {
                        ProgressView()
                            .controlSize(.small)
                        Text("Synthesizing locally on-device…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        Task {
                            _ = await store.generateSpeech(
                                text: inputText,
                                language: selectedLanguage,
                                speakingRate: store.capabilities.supportsSpeakingRate ? speakingRate : nil,
                                sentencePauseSeconds: store.capabilities.supportsPauseControl ? sentencePauseSeconds : nil,
                                stylePresetID: store.capabilities.supportedStylePresets.isEmpty ? nil : selectedStylePresetID
                            )
                        }
                    } label: {
                        Label(
                            store.profile.generatedHistory.isEmpty ? "Generate Audio" : "Generate / Regenerate Audio",
                            systemImage: "waveform"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(StudioTheme.accent)
                    .disabled(!canGenerate)
                }
            }
        }
    }

    private var referenceSelectionRow: some View {
        let usablePrompts = store.prompts.filter { prompt in
            guard let rec = store.profile.recordings[prompt.id] else { return false }
            return rec.captureAssessment.status != .silentOrTooQuiet
        }

        return HStack(spacing: 12) {
            Text("Reference Voice Clip:")
                .font(.subheadline.weight(.medium))
            if usablePrompts.isEmpty {
                Text("No reference recordings yet. Record at least one prompt in Voice Setup.")
                    .font(.subheadline)
                    .foregroundStyle(StudioTheme.warning)
            } else {
                Picker("Reference Clip", selection: Binding(
                    get: { store.effectiveReferencePromptID ?? usablePrompts.first?.id ?? "" },
                    set: { store.setPrimaryReferencePrompt($0) }
                )) {
                    ForEach(usablePrompts) { prompt in
                        let dur = store.profile.recordings[prompt.id]?.durationSeconds ?? 0
                        Text("Prompt \(prompt.index + 1): \(prompt.title) (\(String(format: "%.1fs", dur)))")
                            .tag(prompt.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 380)
            }
        }
    }

    @ViewBuilder
    private var supportedControlsSection: some View {
        let caps = store.capabilities
        if caps.supportsZeroShotVoiceCloning {
            VStack(alignment: .leading, spacing: 10) {
                Divider()
                Text("Model-Supported Generation Controls")
                    .font(.subheadline.weight(.semibold))

                if caps.supportedLanguages.count > 1 {
                    Picker("Language", selection: $selectedLanguage) {
                        ForEach(caps.supportedLanguages, id: \.self) { lang in
                            Text(lang).tag(lang)
                        }
                    }
                    .frame(maxWidth: 260)
                }

                if caps.supportsSpeakingRate {
                    HStack {
                        Text("Speaking Rate")
                            .frame(width: 130, alignment: .leading)
                        Slider(value: $speakingRate, in: caps.speakingRateRange, step: 0.05)
                        Text(String(format: "%.2fx", speakingRate))
                            .font(.caption.monospacedDigit())
                            .frame(width: 48, alignment: .trailing)
                    }
                }

                if caps.supportsPauseControl {
                    HStack {
                        Text("Sentence Pause")
                            .frame(width: 130, alignment: .leading)
                        Slider(value: $sentencePauseSeconds, in: caps.pauseDurationRange, step: 0.05)
                        Text(String(format: "%.2fs", sentencePauseSeconds))
                            .font(.caption.monospacedDigit())
                            .frame(width: 48, alignment: .trailing)
                    }
                }

                if !caps.supportedStylePresets.isEmpty {
                    Picker("Style", selection: $selectedStylePresetID) {
                        ForEach(caps.supportedStylePresets) { preset in
                            Text(preset.name).tag(preset.id)
                        }
                    }
                    .frame(maxWidth: 280)
                }

                if !caps.supportsSpeakingRate && !caps.supportsPauseControl && caps.supportedStylePresets.isEmpty {
                    Text("The active zero-shot model (\(store.engine.descriptor.targetModelName)) synthesizes directly from your reference clip and does not expose separate rate, pause, or style parameters.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var historySection: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Generated Audio Clips (\(store.profile.generatedHistory.count))")
                        .font(.headline)
                    Spacer()

                    Picker("Export Format", selection: $selectedExportFormat) {
                        ForEach(ExportAudioFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 210)

                    if !store.profile.generatedHistory.isEmpty {
                        Button("Clear History", role: .destructive) {
                            store.clearGeneratedHistory()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if store.profile.generatedHistory.isEmpty {
                    Text("No generated audio clips yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(store.profile.generatedHistory) { clip in
                        generatedClipRow(clip)
                        if clip.id != store.profile.generatedHistory.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func generatedClipRow(_ clip: GeneratedSpeechClip) -> some View {
        let identifier = "generated-\(clip.id.uuidString)"
        let isActive = playback.activeClipIdentifier == identifier
        let isPlaying = isActive && playback.isPlaying

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(clip.textPreview)
                        .font(.body.weight(.medium))
                    Text("\(StudioTheme.formatDuration(clip.durationSeconds)) • \(clip.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                HStack(spacing: 8) {
                    Button {
                        store.toggleGeneratedPlayback(clip)
                    } label: {
                        Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(.bordered)

                    if isActive {
                        Button {
                            playback.stop()
                        } label: {
                            Image(systemName: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        presentExportPanel(for: clip)
                    } label: {
                        Label("Export…", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        inputText = clip.fullText
                    } label: {
                        Label("Load into Editor", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        store.deleteGeneratedClip(id: clip.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }

            if isActive, playback.duration > 0 {
                HStack(spacing: 10) {
                    Text(StudioTheme.formatDuration(playback.currentTime))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Slider(
                        value: Binding(
                            get: { playback.currentTime },
                            set: { playback.seek(to: $0) }
                        ),
                        in: 0...max(playback.duration, 0.01)
                    )
                    Text(StudioTheme.formatDuration(playback.duration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var canGenerate: Bool {
        !store.isGenerating
            && store.readiness.isReadyForInference
            && store.effectiveReferencePromptID != nil
            && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func presentExportPanel(for clip: GeneratedSpeechClip) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [selectedExportFormat == .wav ? .wav : .mpeg4Audio]
        panel.nameFieldStringValue = "personal-voice-output.\(selectedExportFormat.fileExtension)"
        panel.title = "Export Generated Audio"

        if panel.runModal() == .OK, let destinationURL = panel.url {
            Task {
                _ = await store.exportGeneratedClip(clip, to: destinationURL, format: selectedExportFormat)
            }
        }
    }
}
