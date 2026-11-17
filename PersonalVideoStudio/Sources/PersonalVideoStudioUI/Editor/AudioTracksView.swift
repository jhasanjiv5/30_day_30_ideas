import PersonalVideoStudioCore
import SwiftUI
import UniformTypeIdentifiers

public struct AudioTracksView: View {
    @ObservedObject private var store: VideoStudioStore
    @State private var importingRole: AudioTrackRole?

    public init(store: VideoStudioStore) {
        self.store = store
    }

    public var body: some View {
        Group {
            if let project = store.activeProject {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Audio & Narration")
                                .font(.title2.weight(.semibold))
                            Text("Import local .wav narration (including PersonalVoiceStudio exports) and background music. No microphone permission is required.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Import Narration…") {
                            importingRole = .narration
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Import Music…") {
                            importingRole = .music
                        }
                        .buttonStyle(.bordered)
                    }

                    Divider()

                    if project.audioTracks.isEmpty {
                        ContentUnavailableView(
                            "No Audio Tracks Added",
                            systemImage: "waveform.path",
                            description: Text("Import a .wav narration clip from PersonalVoiceStudio or pick a local music file (.wav, .m4a, .mp3) to sync with your storyboard.")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(spacing: 14) {
                                ForEach(project.audioTracks) { track in
                                    AudioTrackCardView(
                                        track: track,
                                        isPlaying: store.audioPlayback.isPlaying && store.audioPlayback.playingTrackID == track.id,
                                        onTogglePlay: { store.toggleAudioPlayback(for: track) },
                                        onUpdate: { store.updateAudioTrack($0) },
                                        onRemove: { store.removeAudioTrack(id: track.id) }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(24)
                .fileImporter(
                    isPresented: Binding(
                        get: { importingRole != nil },
                        set: { if !$0 { importingRole = nil } }
                    ),
                    allowedContentTypes: [.audio],
                    allowsMultipleSelection: false
                ) { result in
                    guard let role = importingRole else { return }
                    importingRole = nil
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            Task {
                                await store.importAudioTrack(from: url, role: role)
                            }
                        }
                    case .failure(let error):
                        store.lastErrorMessage = error.localizedDescription
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Project Selected",
                    systemImage: "waveform",
                    description: Text("Open or create a project first to attach narration and music.")
                )
            }
        }
    }
}

private struct AudioTrackCardView: View {
    let track: AudioTrackItem
    let isPlaying: Bool
    let onTogglePlay: () -> Void
    let onUpdate: (AudioTrackItem) -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(track.role.displayName): \(track.displayName)")
                        .font(.headline)
                    Text("\(track.sourceFormat) · \(Int(track.sampleRate)) Hz · Source \(String(format: "%.1fs", track.sourceDurationSeconds)) · Trimmed \(String(format: "%.1fs", track.trimmedDurationSeconds))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(isPlaying ? "Stop" : "Preview", action: onTogglePlay)
                    .buttonStyle(.bordered)
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Volume: \(Int((track.volume * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                    Slider(
                        value: Binding(
                            get: { track.volume },
                            set: { newVal in
                                var copy = track
                                copy.volume = newVal
                                onUpdate(copy)
                            }
                        ),
                        in: 0.0...1.25,
                        step: 0.05
                    )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Trim In: \(String(format: "%.1fs", track.trimStartSeconds))")
                        .font(.caption.monospacedDigit())
                    Slider(
                        value: Binding(
                            get: { track.trimStartSeconds },
                            set: { newVal in
                                var copy = track
                                copy.trimStartSeconds = min(newVal, max(0, copy.trimEndSeconds - 0.5))
                                onUpdate(copy)
                            }
                        ),
                        in: 0.0...max(0.5, track.sourceDurationSeconds - 0.5),
                        step: 0.5
                    )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Trim Out: \(String(format: "%.1fs", track.trimEndSeconds))")
                        .font(.caption.monospacedDigit())
                    Slider(
                        value: Binding(
                            get: { track.trimEndSeconds },
                            set: { newVal in
                                var copy = track
                                copy.trimEndSeconds = max(newVal, copy.trimStartSeconds + 0.5)
                                onUpdate(copy)
                            }
                        ),
                        in: 0.5...max(0.5, track.sourceDurationSeconds),
                        step: 0.5
                    )
                }
            }
        }
        .padding(16)
        .background(StudioTheme.surfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}
