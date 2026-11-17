import AVKit
import PersonalVideoStudioCore
import SwiftUI

public struct PreviewAndExportView: View {
    @ObservedObject private var store: VideoStudioStore
    @State private var scrubSeconds: Double = 0
    @State private var selectedRenderForPlayback: RenderedVideoRecord?

    public init(store: VideoStudioStore) {
        self.store = store
    }

    public var body: some View {
        Group {
            if let project = store.activeProject {
                HSplitView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Composition Preview")
                            .font(.title2.weight(.semibold))

                        if let render = selectedRenderForPlayback {
                            let url = store.storagePaths.renderFileURL(projectID: project.id, fileName: render.fileName)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Playing Export: \(render.fileName)")
                                        .font(.caption.weight(.medium))
                                    Spacer()
                                    Button("Back to Storyboard Preview") {
                                        selectedRenderForPlayback = nil
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.caption)
                                }
                                VideoPlayer(player: AVPlayer(url: url))
                                    .frame(minHeight: 320, maxHeight: 420)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        } else {
                            StoryboardFramePreviewView(
                                project: project,
                                storagePaths: store.storagePaths,
                                currentTimeSeconds: scrubSeconds
                            )
                            .frame(minHeight: 300, maxHeight: 420)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Timeline Scrub")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(String(format: "%.1fs", scrubSeconds)) / \(String(format: "%.1fs", project.totalDurationSeconds))")
                                    .font(.caption.monospacedDigit())
                            }
                            Slider(
                                value: $scrubSeconds,
                                in: 0...max(0.5, project.totalDurationSeconds),
                                step: 0.1
                            )
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Local Exports (\(project.renders.count))")
                                .font(.headline)

                            if project.renders.isEmpty {
                                Text("No local MP4 renders yet. Configure your aspect ratio on the right and click Export MP4.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                List(project.renders) { render in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(render.fileName)
                                                .font(.subheadline.weight(.medium))
                                            Text("\(render.width)×\(render.height) · \(render.frameRate) fps · \(String(format: "%.1fs", render.durationSeconds))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Button("Play") {
                                            selectedRenderForPlayback = render
                                        }
                                        .buttonStyle(.bordered)
                                        Button("Reveal") {
                                            store.revealRenderInFinder(render)
                                        }
                                        .buttonStyle(.borderless)
                                        Button(role: .destructive) {
                                            if selectedRenderForPlayback?.id == render.id {
                                                selectedRenderForPlayback = nil
                                            }
                                            store.deleteRender(render)
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                    .padding(.vertical, 3)
                                }
                                .listStyle(.inset)
                                .frame(minHeight: 120)
                            }
                        }
                    }
                    .padding(20)
                    .frame(minWidth: 460)

                    ExportSidebarView(store: store, config: project.exportConfiguration)
                        .frame(minWidth: 280, maxWidth: 340)
                }
            } else {
                ContentUnavailableView(
                    "No Active Project",
                    systemImage: "play.rectangle",
                    description: Text("Select or create a project before previewing and exporting.")
                )
            }
        }
    }
}

private struct StoryboardFramePreviewView: View {
    let project: VideoProject
    let storagePaths: LocalStoragePaths
    let currentTimeSeconds: Double

    var body: some View {
        let active = CompositionPreviewBuilder.activeScene(at: currentTimeSeconds, in: project)
        let aspect: CGFloat = project.exportConfiguration.aspectRatio == .landscape16x9 ? (16.0 / 9.0) : (9.0 / 16.0)

        GeometryReader { _ in
            ZStack {
                Color.black.opacity(0.92)

                if let active {
                    let scene = active.slice.scene
                    if scene.mediaKind == .image,
                       let fileName = scene.mediaFileName,
                       let nsImage = NSImage(contentsOf: storagePaths.mediaFileURL(projectID: project.id, fileName: fileName)) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(1.0 + active.localProgress * 0.04)
                    } else if scene.mediaKind == .video, let fileName = scene.mediaFileName {
                        VStack(spacing: 8) {
                            Image(systemName: "film")
                                .font(.largeTitle)
                                .foregroundStyle(.white.opacity(0.75))
                            Text("Video Clip: \(fileName)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }

                    if !scene.titleOverlay.isEmpty || !scene.captionScript.isEmpty {
                        VStack {
                            if scene.overlayPlacement == .bottom || scene.overlayPlacement == .center {
                                Spacer()
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                if !scene.titleOverlay.isEmpty {
                                    Text(scene.titleOverlay)
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(.white)
                                }
                                if !scene.captionScript.isEmpty {
                                    Text(scene.captionScript)
                                        .font(.callout)
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color.black.opacity(0.55))
                            if scene.overlayPlacement == .top || scene.overlayPlacement == .center {
                                Spacer()
                            }
                        }
                    }
                } else {
                    Text("Add scenes in Storyboard to preview frames.")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .aspectRatio(aspect, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ExportSidebarView: View {
    @ObservedObject var store: VideoStudioStore
    let config: ExportConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Export Settings")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Aspect Ratio Preset")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Picker(
                    "Aspect Ratio",
                    selection: Binding(
                        get: { config.aspectRatio },
                        set: { next in
                            var updated = config
                            updated.aspectRatio = next
                            store.updateExportConfiguration(updated)
                        }
                    )
                ) {
                    ForEach(ExportAspectRatio.allCases, id: \.self) { ratio in
                        Text(ratio.displayName).tag(ratio)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Resolution")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Picker(
                    "Resolution",
                    selection: Binding(
                        get: { config.resolution },
                        set: { next in
                            var updated = config
                            updated.resolution = next
                            store.updateExportConfiguration(updated)
                        }
                    )
                ) {
                    ForEach(ExportResolutionTier.allCases, id: \.self) { tier in
                        Text(tier.displayName).tag(tier)
                    }
                }
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Frame Rate")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Picker(
                    "Frame Rate",
                    selection: Binding(
                        get: { config.frameRate },
                        set: { next in
                            var updated = config
                            updated.frameRate = next
                            store.updateExportConfiguration(updated)
                        }
                    )
                ) {
                    ForEach(ExportFrameRate.allCases, id: \.self) { fps in
                        Text(fps.displayName).tag(fps)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Toggle(
                "Include Narration & Music Mix",
                isOn: Binding(
                    get: { config.includeAudioMix },
                    set: { next in
                        var updated = config
                        updated.includeAudioMix = next
                        store.updateExportConfiguration(updated)
                    }
                )
            )

            Text("Output Dimensions: \(config.pixelWidth) × \(config.pixelHeight) px (.mp4)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Divider()

            if store.isExporting {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: store.exportProgress.fractionCompleted)
                    Text(store.exportProgress.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Cancel Export", role: .destructive) {
                        store.cancelExport()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Button("Export Local MP4") {
                    store.startExport()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()
        }
        .padding(20)
    }
}
