import PersonalVideoStudioCore
import SwiftUI

public struct AIModelSetupView: View {
    @ObservedObject private var store: VideoStudioStore
    @State private var isPickingFolder = false

    public init(store: VideoStudioStore) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Local AI Models, Calibration & Requirements")
                        .font(.title2.weight(.semibold))
                    Text("Weights are never downloaded inside the sandboxed app. Run the external Python downloader script, import the folder offline, and calibrate your portrait and audio tracks.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // 1. Offline Model Import & Status
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: store.modelReadiness.isReadyForInference ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(store.modelReadiness.isReadyForInference ? StudioTheme.readyColor : StudioTheme.warningColor)
                        Text(store.modelReadiness.statusTitle)
                            .font(.headline)
                    }
                    Text(store.modelReadiness.statusDetail)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Button("Import Local Model Folder…") {
                            isPickingFolder = true
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Remove Imported Model", role: .destructive) {
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

                // 2. Video Generation Requirements Checklist
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Video Generation Requirements")
                            .font(.headline)
                        Spacer()
                        Button("Refresh Checks") {
                            store.refreshModelReadiness()
                        }
                        .buttonStyle(.bordered)
                    }

                    Text("Hardware: \(store.requirementsReport.hardwareArchitectureName) · \(store.requirementsReport.unifiedMemoryGB) GB RAM · \(String(format: "%.1f GB", store.requirementsReport.freeDiskSpaceGB)) free disk")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    ForEach(store.requirementsReport.items) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: item.isSatisfied ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(item.isSatisfied ? StudioTheme.readyColor : StudioTheme.warningColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline.weight(.medium))
                                Text(item.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(16)
                .background(StudioTheme.surfaceBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )

                // 3. Portrait & Audio Calibration
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Portrait & Audio Calibration")
                            .font(.headline)
                        Spacer()
                        Button(store.isCalibrating ? "Calibrating…" : "Calibrate Active Project") {
                            Task {
                                await store.calibrateProjectAudioAndPortraits()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.isCalibrating || store.activeProject == nil)
                    }
                    Text("Uses Apple Vision face/mouth landmark detection and AVFoundation audio energy analysis locally to verify framing, resolution, RMS level, and beat-sync envelope.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let project = store.activeProject {
                        ForEach(project.scenes) { scene in
                            if let cal = store.portraitCalibrations[scene.id] {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: cal.status == .pass ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundStyle(cal.status == .pass ? StudioTheme.readyColor : StudioTheme.warningColor)
                                    Text("\(scene.title): \(cal.summary)")
                                        .font(.caption)
                                }
                            }
                        }
                        ForEach(project.audioTracks) { track in
                            if let cal = store.audioCalibrations[track.id] {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: cal.status == .pass ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundStyle(cal.status == .pass ? StudioTheme.readyColor : StudioTheme.warningColor)
                                    Text("\(track.displayName): \(cal.summary)")
                                        .font(.caption)
                                }
                            }
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

                // 4. External Model Download Instructions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Offline Model Download Script (External to App)")
                        .font(.headline)
                    Text("Run the included script in Terminal from PersonalVideoStudio/ to fetch open-weight Visual-Text I2V + Audio Lip-Sync models and generate model_manifest.json:")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("bash Scripts/download_offline_models.sh wan2.1-echomimic")
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Text("Then click Import Local Model Folder… above and choose ~/Downloads/PersonalVideoStudio-OfflineModels.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .fileImporter(
            isPresented: $isPickingFolder,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let folderURL = urls.first {
                    store.importVideoModelFolder(from: folderURL)
                }
            case .failure(let error):
                store.lastErrorMessage = error.localizedDescription
            }
        }
    }
}
