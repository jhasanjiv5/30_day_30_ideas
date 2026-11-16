import AppKit
import PersonalVoiceStudioCore
import SwiftUI

public struct ModelSetupView: View {
    @ObservedObject var store: VoiceStudioStore

    public init(store: VoiceStudioStore) {
        self.store = store
    }

    public var body: some View {
        let descriptor = store.engine.descriptor

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Offline On-Device Model")
                        .font(.largeTitle.weight(.semibold))
                    Text("No network downloads, remote APIs, or macOS system voice fallbacks are used.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                StudioCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label(store.readiness.statusTitle, systemImage: store.readiness.isReadyForInference ? "checkmark.seal.fill" : "cpu")
                                .font(.headline)
                                .foregroundStyle(store.readiness.isReadyForInference ? StudioTheme.success : StudioTheme.warning)
                            Spacer()
                            Button("Refresh Status") {
                                store.refreshModelReadiness()
                            }
                            .buttonStyle(.bordered)
                        }

                        Text(store.readiness.statusDetail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if case .ready(let bundle) = store.readiness {
                            Divider()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Validated Model Type: \(bundle.modelType)")
                                    .font(.caption.weight(.medium))
                                Text("Weight Files: \(bundle.weightFiles.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Tokenizer Files: \(bundle.tokenizerFiles.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Total Size: \(StudioTheme.formatBytes(bundle.totalSizeBytes))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack(spacing: 12) {
                            Button {
                                pickLocalModelDirectory()
                            } label: {
                                Label(
                                    store.isImportingModel ? "Validating & Importing…" : "Import Local Model Folder…",
                                    systemImage: "folder.badge.plus"
                                )
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(StudioTheme.accent)
                            .disabled(store.isImportingModel)

                            if store.profile.importedModelDirectoryName != nil || store.storageUsage.modelBytes > 0 {
                                Button("Remove Imported Model", role: .destructive) {
                                    Task {
                                        await store.removeImportedModel()
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(store.isImportingModel)
                            }
                        }
                        .padding(.top, 4)
                    }
                }

                StudioCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Selected Open Model & License Details")
                            .font(.headline)

                        detailRow(label: "Inference Package", value: "\(descriptor.enginePackageName) — \(descriptor.engineLicense)")
                        detailRow(label: "Model Weights", value: "\(descriptor.targetModelName) — \(descriptor.modelLicense)")
                        detailRow(label: "Attribution", value: descriptor.attributionNotice)

                        Divider()

                        Text("Offline Setup Procedure")
                            .font(.subheadline.weight(.semibold))
                        Text("1. Open PersonalVoiceStudio.xcodeproj in Xcode on an Apple Silicon Mac and link \(descriptor.enginePackageURL) (MLXAudioCore + MLXAudioTTS).\n2. Outside the app, obtain an unpacked Apache-2.0 MLX copy of \(descriptor.targetModelName) containing config.json, tokenizer files, and .safetensors weights.\n3. Click \"Import Local Model Folder…\" above to validate and copy the folder into local Application Support storage.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 920, alignment: .leading)
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }

    private func pickLocalModelDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Select Unpacked Local MLX Model Folder"
        panel.prompt = "Import Folder"

        if panel.runModal() == .OK, let selectedURL = panel.url {
            Task {
                let scoped = selectedURL.startAccessingSecurityScopedResource()
                defer {
                    if scoped {
                        selectedURL.stopAccessingSecurityScopedResource()
                    }
                }
                await store.importLocalModelFolder(from: selectedURL)
            }
        }
    }
}
