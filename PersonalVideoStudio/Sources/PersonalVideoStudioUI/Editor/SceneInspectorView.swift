import PersonalVideoStudioCore
import SwiftUI
import UniformTypeIdentifiers

public struct SceneInspectorView: View {
    @ObservedObject private var store: VideoStudioStore
    @State private var isReplacingMedia = false
    @State private var isAddingReferencePortrait = false

    public init(store: VideoStudioStore) {
        self.store = store
    }

    private var selectedScene: StoryboardScene? {
        guard let project = store.activeProject,
              let sceneID = store.selectedSceneID else { return nil }
        return project.scenes.first { $0.id == sceneID }
    }

    public var body: some View {
        ScrollView {
            if let scene = selectedScene {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Scene Inspector")
                        .font(.title3.weight(.semibold))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Scene Label")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        TextField("Scene label", text: binding(for: scene, keyPath: \.title))
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Primary Subject Image or Video")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        HStack {
                            Text(scene.mediaFileName ?? "No media attached (text-only card)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Button("Choose Media…") {
                                isReplacingMedia = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Additional Reference People (\(scene.referenceImageFileNames.count))")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Add Person…") {
                                isAddingReferencePortrait = true
                            }
                            .buttonStyle(.bordered)
                        }
                        if !scene.referenceImageFileNames.isEmpty {
                            ForEach(scene.referenceImageFileNames, id: \.self) { fileName in
                                HStack {
                                    Text(fileName)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer()
                                    Button(role: .destructive) {
                                        store.removeReferenceImageFromScene(sceneID: scene.id, fileName: fileName)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Portrait Calibration (Face & Mouth Landmarks)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Calibrate Portrait") {
                                store.calibrateScenePortrait(sceneID: scene.id)
                            }
                            .buttonStyle(.bordered)
                            .disabled(scene.mediaKind != .image || scene.mediaFileName == nil)
                        }
                        if let calibration = store.portraitCalibrations[scene.id] {
                            Text(calibration.summary)
                                .font(.caption2)
                                .foregroundStyle(calibration.status == .pass ? StudioTheme.readyColor : StudioTheme.warningColor)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Subject Behavior & Scene Prompt (Visual-Text)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        TextEditor(text: binding(for: scene, keyPath: \.behaviorPrompt))
                            .font(.callout)
                            .frame(height: 74)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                            )
                        Text("Example: Woman strumming an acoustic guitar with natural hand motion in warm stage light, lip-syncing to the music.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Toggle(
                        "Lip-Sync Subject to Supplied Audio Track",
                        isOn: binding(for: scene, keyPath: \.enableLipSyncWithAudio)
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Button(store.isGeneratingScene ? "Generating Scene…" : "Generate Visual-Text + Lip-Sync Scene") {
                            Task {
                                await store.generateAIScene(sceneID: scene.id)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.isGeneratingScene)

                        if let generatedClip = scene.generatedVideoFileName {
                            Text("Generated clip ready: \(generatedClip)")
                                .font(.caption)
                                .foregroundStyle(StudioTheme.readyColor)
                        } else if !store.modelCapabilities.supportsImageToVideo {
                            Text("Capability-gated: requires a linked local MLX/CoreML Visual-Text + Lip-Sync backend and imported offline weights. See Local AI Models.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Duration")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f sec", scene.durationSeconds))
                                .font(.caption.monospacedDigit())
                        }
                        Slider(
                            value: binding(for: scene, keyPath: \.durationSeconds),
                            in: 1.0...30.0,
                            step: 0.5
                        )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Fallback Still-Image Motion")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Picker("Motion", selection: binding(for: scene, keyPath: \.motionEffect)) {
                            ForEach(StillMotionEffect.allCases, id: \.self) { effect in
                                Text(effect.displayName).tag(effect)
                            }
                        }
                        .labelsHidden()
                        .disabled(scene.mediaKind == .video)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Transition Into Scene")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Picker("Transition", selection: binding(for: scene, keyPath: \.transition)) {
                            ForEach(SceneTransitionKind.allCases, id: \.self) { kind in
                                Text(kind.displayName).tag(kind)
                            }
                        }
                        .labelsHidden()
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title Overlay")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        TextField("Optional on-screen title…", text: binding(for: scene, keyPath: \.titleOverlay))
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Caption / Lyric Script")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        TextField("Optional subtitle or lyric line…", text: binding(for: scene, keyPath: \.captionScript))
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Overlay Placement")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Picker("Placement", selection: binding(for: scene, keyPath: \.overlayPlacement)) {
                            ForEach(OverlayPlacement.allCases, id: \.self) { placement in
                                Text(placement.displayName).tag(placement)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }
                .padding(18)
                .fileImporter(
                    isPresented: $isReplacingMedia,
                    allowedContentTypes: [.image, .movie],
                    allowsMultipleSelection: false
                ) { result in
                    if case .success(let urls) = result, let url = urls.first {
                        store.replaceSceneMedia(sceneID: scene.id, from: url)
                    }
                }
                .fileImporter(
                    isPresented: $isAddingReferencePortrait,
                    allowedContentTypes: [.image],
                    allowsMultipleSelection: false
                ) { result in
                    if case .success(let urls) = result, let url = urls.first {
                        store.addReferenceImageToScene(sceneID: scene.id, from: url)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Select a Scene",
                    systemImage: "slider.horizontal.3",
                    description: Text("Choose a scene on the left to edit its behavior prompt, reference people, motion, and overlays.")
                )
                .padding(24)
            }
        }
    }

    private func binding<Value>(
        for scene: StoryboardScene,
        keyPath: WritableKeyPath<StoryboardScene, Value>
    ) -> Binding<Value> {
        Binding(
            get: {
                store.activeProject?.scenes.first(where: { $0.id == scene.id })?[keyPath: keyPath] ?? scene[keyPath: keyPath]
            },
            set: { newValue in
                var copy = store.activeProject?.scenes.first(where: { $0.id == scene.id }) ?? scene
                copy[keyPath: keyPath] = newValue
                store.updateScene(copy)
            }
        )
    }
}
