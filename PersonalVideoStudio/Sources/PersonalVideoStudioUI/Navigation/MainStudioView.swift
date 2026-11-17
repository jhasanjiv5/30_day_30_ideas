import PersonalVideoStudioCore
import SwiftUI

public struct MainStudioView: View {
    @ObservedObject private var store: VideoStudioStore

    public init(store: VideoStudioStore) {
        self.store = store
    }

    public var body: some View {
        NavigationSplitView {
            List(StudioNavigationSection.allCases, selection: $store.selectedSection) { section in
                Label(section.rawValue, systemImage: iconName(for: section))
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 260)

            VStack(alignment: .leading, spacing: 6) {
                Divider()
                if let project = store.activeProject {
                    Text("Active Project")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(project.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text("\(project.scenes.count) scene(s) • \(String(format: "%.1fs", project.totalDurationSeconds))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No active project")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        } detail: {
            VStack(spacing: 0) {
                if let errorMessage = store.lastErrorMessage {
                    StatusBannerView(
                        message: errorMessage,
                        isError: true,
                        onDismiss: { store.clearBannerMessages() }
                    )
                } else if let statusMessage = store.lastStatusMessage {
                    StatusBannerView(
                        message: statusMessage,
                        isError: false,
                        onDismiss: { store.clearBannerMessages() }
                    )
                }

                Group {
                    switch store.selectedSection {
                    case .projects:
                        ProjectBrowserView(store: store)
                    case .storyboard:
                        StoryboardTimelineView(store: store)
                    case .audio:
                        AudioTracksView(store: store)
                    case .previewExport:
                        PreviewAndExportView(store: store)
                    case .aiModels:
                        AIModelSetupView(store: store)
                    case .privacy:
                        PrivacyAndStorageView(store: store)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 980, minHeight: 680)
    }

    private func iconName(for section: StudioNavigationSection) -> String {
        switch section {
        case .projects: return "folder"
        case .storyboard: return "film.stack"
        case .audio: return "waveform"
        case .previewExport: return "play.rectangle"
        case .aiModels: return "cpu"
        case .privacy: return "lock.shield"
        }
    }
}

private struct StatusBannerView: View {
    let message: String
    let isError: Bool
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? StudioTheme.dangerColor : StudioTheme.readyColor)
            Text(message)
                .font(.callout)
                .lineLimit(2)
            Spacer()
            Button("Dismiss", action: onDismiss)
                .buttonStyle(.borderless)
                .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            (isError ? StudioTheme.dangerColor : StudioTheme.readyColor).opacity(0.10)
        )
    }
}
