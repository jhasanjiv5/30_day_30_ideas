import PersonalVideoStudioCore
import SwiftUI

public struct ProjectBrowserView: View {
    @ObservedObject private var store: VideoStudioStore
    @State private var newProjectTitle = ""
    @State private var renamingProject: VideoProject?
    @State private var renameDraft = ""
    @State private var projectToDelete: VideoProject?

    public init(store: VideoStudioStore) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Local Video Projects")
                        .font(.title2.weight(.semibold))
                    Text("Projects, imported photos, audio tracks, and renders are stored locally on your Mac.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    TextField("New project name…", text: $newProjectTitle)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                        .onSubmit(createNewProject)
                    Button("Create Project", action: createNewProject)
                        .buttonStyle(.borderedProminent)
                        .disabled(newProjectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Divider()

            if store.projects.isEmpty {
                ContentUnavailableView(
                    "No Local Video Projects Yet",
                    systemImage: "film",
                    description: Text("Create a project above to combine local portraits, scripts, music, and .wav narration from Personal Voice Studio.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.projects) { project in
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(project.title)
                                        .font(.headline)
                                    if store.activeProject?.id == project.id {
                                        Text("Active")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(StudioTheme.accentColor)
                                    }
                                }
                                Text("\(project.scenes.count) scenes · \(project.audioTracks.count) audio track(s) · \(String(format: "%.1fs", project.totalDurationSeconds)) · \(project.renders.count) render(s)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Open") {
                                store.openProject(project)
                            }
                            .buttonStyle(.bordered)

                            Button("Rename") {
                                renamingProject = project
                                renameDraft = project.title
                            }
                            .buttonStyle(.borderless)

                            Button(role: .destructive) {
                                projectToDelete = project
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Delete project and all local media")
                        }
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(24)
        .sheet(item: $renamingProject) { project in
            VStack(alignment: .leading, spacing: 14) {
                Text("Rename Project")
                    .font(.headline)
                TextField("Project title", text: $renameDraft)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("Cancel") {
                        renamingProject = nil
                    }
                    Button("Save") {
                        store.renameProject(id: project.id, newTitle: renameDraft)
                        renamingProject = nil
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20)
            .frame(width: 340)
        }
        .confirmationDialog(
            "Delete Project?",
            isPresented: Binding(
                get: { projectToDelete != nil },
                set: { if !$0 { projectToDelete = nil } }
            ),
            presenting: projectToDelete
        ) { project in
            Button("Delete Project and All Assets", role: .destructive) {
                store.deleteProject(id: project.id)
                projectToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                projectToDelete = nil
            }
        } message: { project in
            Text("This permanently deletes '\(project.title)', its copied images, audio files, and rendered MP4 exports from your Mac.")
        }
    }

    private func createNewProject() {
        let trimmed = newProjectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.createProject(title: trimmed)
        newProjectTitle = ""
    }
}
