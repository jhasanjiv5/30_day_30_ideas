import PersonalVoiceStudioCore
import SwiftUI

public enum StudioSection: String, CaseIterable, Identifiable {
    case setup = "Voice Setup"
    case generate = "Generate Speech"
    case corrections = "Corrections"
    case model = "Offline Model"
    case privacy = "Privacy & Data"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .setup: return "mic.and.signal.meter"
        case .generate: return "waveform.badge.plus"
        case .corrections: return "text.bubble"
        case .model: return "cpu"
        case .privacy: return "lock.shield"
        }
    }
}

public struct MainStudioView: View {
    @ObservedObject var store: VoiceStudioStore
    @State private var selectedSection: StudioSection? = .setup

    public init(store: VoiceStudioStore) {
        self.store = store
    }

    public var body: some View {
        NavigationSplitView {
            List(StudioSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.systemImage)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 215, max: 250)
            .safeAreaInset(edge: .bottom) {
                sidebarStatusFooter
            }
        } detail: {
            VStack(spacing: 0) {
                if let error = store.lastError {
                    bannerView(
                        message: error.localizedDescription,
                        isError: true,
                        onDismiss: { store.dismissError() }
                    )
                } else if let status = store.statusBannerMessage {
                    bannerView(
                        message: status,
                        isError: false,
                        onDismiss: { store.dismissStatusBanner() }
                    )
                }

                Group {
                    switch selectedSection ?? .setup {
                    case .setup:
                        VoiceSetupView(store: store)
                    case .generate:
                        SpeechGenerationView(
                            store: store,
                            onOpenModelSetup: { selectedSection = .model }
                        )
                    case .corrections:
                        CorrectionsView(store: store)
                    case .model:
                        ModelSetupView(store: store)
                    case .privacy:
                        PrivacyAndDataView(store: store)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 920, minHeight: 620)
    }

    private var sidebarStatusFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            HStack(spacing: 6) {
                Circle()
                    .fill(store.readiness.isReadyForInference ? StudioTheme.success : StudioTheme.warning)
                    .frame(width: 8, height: 8)
                Text(store.readiness.isReadyForInference ? "Model Ready" : "Model Unavailable")
                    .font(.caption.weight(.medium))
            }
            Text("Offline Only • On-Device")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func bannerView(message: String, isError: Bool, onDismiss: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isError ? "exclamationmark.octagon.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? StudioTheme.danger : StudioTheme.success)
            Text(message)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Dismiss") {
                onDismiss()
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isError ? StudioTheme.danger.opacity(0.10) : StudioTheme.success.opacity(0.10))
    }
}
