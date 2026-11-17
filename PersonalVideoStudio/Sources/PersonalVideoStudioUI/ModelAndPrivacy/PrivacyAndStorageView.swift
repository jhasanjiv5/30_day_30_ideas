import PersonalVideoStudioCore
import SwiftUI

public struct PrivacyAndStorageView: View {
    @ObservedObject private var store: VideoStudioStore
    @State private var projectToDelete: VideoProject?

    public init(store: VideoStudioStore) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Privacy & Local Storage")
                        .font(.title2.weight(.semibold))
                    Text("Personal Video Studio operates strictly offline. No accounts, cloud inference, network entitlements, or telemetry are included.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("On-Device Storage Folder")
                        .font(.headline)
                    Text(store.storagePaths.rootDirectory.path)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)

                    Text("Total Disk Used: \(formattedBytes(store.totalStorageUsedBytes()))")
                        .font(.callout.monospacedDigit())

                    HStack(spacing: 12) {
                        Button("Reveal in Finder") {
                            store.revealStorageInFinder()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Remove Imported Model Folder", role: .destructive) {
                            store.removeImportedVideoModel()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 4)
                }
                .padding(16)
                .background(StudioTheme.surfaceBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Project Disk Footprint & Granular Deletion")
                        .font(.headline)

                    if store.projects.isEmpty {
                        Text("No local projects stored.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.projects) { project in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.title)
                                        .font(.subheadline.weight(.medium))
                                    Text("\(formattedBytes(store.projectStorageUsedBytes(for: project.id))) · \(project.scenes.count) scene(s) · \(project.renders.count) render(s)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Delete Project…", role: .destructive) {
                                    projectToDelete = project
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                }
            }
            .padding(24)
        }
        .confirmationDialog(
            "Delete Project?",
            isPresented: Binding(
                get: { projectToDelete != nil },
                set: { if !$0 { projectToDelete = nil } }
            ),
            presenting: projectToDelete
        ) { project in
            Button("Delete Project and Local Assets", role: .destructive) {
                store.deleteProject(id: project.id)
                projectToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                projectToDelete = nil
            }
        } message: { project in
            Text("Permanently removes '\(project.title)' and all copied media, audio, and renders from Application Support.")
        }
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
