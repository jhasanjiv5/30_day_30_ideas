import SwiftUI
import Translation
import SaathiCore

struct LanguagePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var coordinator: SessionCoordinator
    @State private var capabilities: [LanguagePipelineCapability] = []
    @State private var downloadConfig: TranslationSession.Configuration?
    @State private var downloadBanner: String?

    var body: some View {
        NavigationStack {
            List {
                if let downloadBanner {
                    Section {
                        Text(downloadBanner)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Narration Language (Output)") {
                    ForEach(capabilities) { cap in
                        Button {
                            coordinator.narrationLanguage = cap.language
                            if cap.needsTranslationDownloadConsent {
                                downloadConfig = TranslationSession.Configuration(
                                    source: Locale.Language(identifier: "en"),
                                    target: cap.language.locale.language
                                )
                            }
                        } label: {
                            languageRow(cap: cap, isSelected: coordinator.narrationLanguage == cap.language)
                        }
                        .accessibilityIdentifier("narrationLang_\(cap.language.rawValue)")
                    }
                }

                Section("Listening Language (Voice Commands)") {
                    ForEach(SaathiLanguage.allCases) { lang in
                        Button {
                            coordinator.listeningLanguage = lang
                        } label: {
                            HStack {
                                Text(lang.nativeDisplayName)
                                Spacer()
                                if coordinator.listeningLanguage == lang {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Languages")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                Task { capabilities = await coordinator.evaluateAllLanguageCapabilities() }
            }
            .translationTask(downloadConfig) { _ in
                downloadBanner = "Translation is ready when the selected language pack is available."
                capabilities = await coordinator.evaluateAllLanguageCapabilities()
            }
        }
    }

    private func languageRow(cap: LanguagePipelineCapability, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(cap.language.nativeDisplayName)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                Spacer()
                Text(cap.badge.rawValue)
                    .font(.caption.bold())
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            Text(cap.plainLanguageReason)
                .font(.caption)
                .foregroundStyle(.secondary)

            if cap.needsVoiceDownloadPrompt {
                Text("Tip: Download an Enhanced/Premium voice in iOS Settings → Accessibility → Spoken Content.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}
