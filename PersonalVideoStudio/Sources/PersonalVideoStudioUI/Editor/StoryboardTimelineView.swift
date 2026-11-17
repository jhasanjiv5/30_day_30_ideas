import PersonalVideoStudioCore
import SwiftUI
import UniformTypeIdentifiers

public struct StoryboardTimelineView: View {
    @ObservedObject private var store: VideoStudioStore
    @State private var isImportingMedia = false

    public init(store: VideoStudioStore) {
        self.store = store
    }

    public var body: some View {
        Group {
            if let project = store.activeProject {
                HSplitView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Storyboard")
                                    .font(.title3.weight(.semibold))
                                Text("\(project.scenes.count) scene(s) · \(String(format: "%.1fs", project.totalDurationSeconds)) total")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Add Title Scene") {
                                store.addEmptyScene(title: "Title Card")
                            }
                            .buttonStyle(.bordered)
                            Button("Import Media…") {
                                isImportingMedia = true
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        if project.scenes.isEmpty {
                            ContentUnavailableView(
                                "Empty Storyboard",
                                systemImage: "photo.on.rectangle.angled",
                                description: Text("Import portrait images or video clips from your Mac, or add a title scene to start composing.")
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            List(selection: $store.selectedSceneID) {
                                ForEach(Array(project.scenes.enumerated()), id: \.element.id) { index, scene in
                                    SceneRowView(index: index, scene: scene) {
                                        store.removeScene(id: scene.id)
                                    }
                                    .tag(scene.id)
                                }
                                .onMove { from, to in
                                    store.moveScenes(fromOffsets: from, toOffset: to)
                                }
                            }
                            .listStyle(.inset)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Project Script Notes")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            TextEditor(
                                text: Binding(
                                    get: { store.activeProject?.scriptNotes ?? "" },
                                    set: { store.updateScriptNotes($0) }
                                )
                            )
                            .font(.callout)
                            .frame(height: 82)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                            )
                        }
                    }
                    .padding(18)
                    .frame(minWidth: 360)

                    SceneInspectorView(store: store)
                        .frame(minWidth: 340, maxWidth: 440)
                }
                .fileImporter(
                    isPresented: $isImportingMedia,
                    allowedContentTypes: [.image, .movie],
                    allowsMultipleSelection: true
                ) { result in
                    switch result {
                    case .success(let urls):
                        for url in urls {
                            store.addSceneWithVisualMedia(from: url)
                        }
                    case .failure(let error):
                        store.lastErrorMessage = error.localizedDescription
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Project Selected",
                    systemImage: "folder.badge.questionmark",
                    description: Text("Create or open a project in Projects to edit its storyboard.")
                )
            }
        }
    }
}

private struct SceneRowView: View {
    let index: Int
    let scene: StoryboardScene
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", index + 1))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(scene.title.isEmpty ? "Untitled Scene" : scene.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text("\(scene.mediaKind.displayName) · \(String(format: "%.1fs", scene.durationSeconds)) · \(scene.motionEffect.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove scene")
        }
        .padding(.vertical, 4)
    }
}
