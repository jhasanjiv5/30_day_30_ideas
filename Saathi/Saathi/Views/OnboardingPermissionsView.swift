import SwiftUI
import SaathiCore

#if canImport(JournalingSuggestions)
import JournalingSuggestions
#endif

struct OnboardingPermissionsView: View {
    @Bindable var coordinator: SessionCoordinator
    @State private var showLanguagePicker = false
    @State private var showCapabilityDebug = false
    @State private var showJournalingPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                languageSummaryCard
                personalOptInsSection
                walkEndSection
                startButton
                attributionFooter
            }
            .padding()
        }
        .navigationTitle(Text("app_title"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Capability Debug") {
                    showCapabilityDebug = true
                }
                .accessibilityIdentifier("capabilityDebugButton")
            }
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerView(coordinator: coordinator)
        }
        .sheet(isPresented: $showCapabilityDebug) {
            CapabilityMatrixDebugView(coordinator: coordinator)
        }
        #if canImport(JournalingSuggestions)
        .journalingSuggestionsPicker(isPresented: $showJournalingPicker) { suggestion in
            coordinator.personalService.addUserSelectedJournalingItem(
                title: suggestion.title,
                detail: "Selected from Journaling Suggestions",
                date: suggestion.date?.start ?? Date()
            )
        }
        #endif
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Privacy-First Audio Guide", systemImage: "headphones.circle.fill")
                .font(.headline)
                .foregroundStyle(Color.accentColor)

            Text("Saathi narrates nearby history in your ear using only on-device intelligence and ~250 m tile lookups. Coordinates stay in memory and are wiped when your walk ends.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Say \"Hey Siri, Start Saathi here\" or tap Start Walk below. \"Allow Once\" works fully.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var languageSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Narration & Listening Languages")
                        .font(.headline)
                    Text("Speak: \(coordinator.narrationLanguage.nativeDisplayName)")
                        .font(.subheadline)
                    Text("Listen: \(coordinator.listeningLanguage.nativeDisplayName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Choose") {
                    showLanguagePicker = true
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("openLanguagePickerButton")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var personalOptInsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Optional On-Device Memories")
                .font(.headline)

            Toggle(isOn: Binding(
                get: { coordinator.personalService.photosOptIn },
                set: { newVal in
                    if newVal {
                        Task { _ = await coordinator.personalService.requestPhotosAuthorization() }
                    } else {
                        coordinator.personalService.photosOptIn = false
                    }
                }
            )) {
                Label("Match Nearby Photos (PhotoKit)", systemImage: "photo.on.rectangle")
            }
            .accessibilityIdentifier("photosOptInToggle")

            Toggle(isOn: Binding(
                get: { coordinator.personalService.calendarOptIn },
                set: { newVal in
                    if newVal {
                        Task { _ = await coordinator.personalService.requestCalendarAuthorization() }
                    } else {
                        coordinator.personalService.calendarOptIn = false
                    }
                }
            )) {
                Label("Include Today's Calendar (EventKit)", systemImage: "calendar")
            }
            .accessibilityIdentifier("calendarOptInToggle")

            Toggle(isOn: Bindable(coordinator.personalService).journalingOptIn) {
                Label("Journaling Suggestions (User-Picked Only)", systemImage: "book.pages")
            }
            .accessibilityIdentifier("journalingOptInToggle")

            if coordinator.personalService.journalingOptIn {
                Button("Pick Moments from Journaling Suggestions") {
                    showJournalingPicker = true
                }
                .buttonStyle(.bordered)
            }

            Toggle(isOn: $coordinator.touchModeEnabled) {
                Label("Start in Touch Mode (Silent / Captions)", systemImage: "hand.tap")
            }
            .accessibilityIdentifier("touchModeToggle")
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    /// No duration to pick: the walk ends when it really ends.
    private var walkEndSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Your walk, your pace", systemImage: "applewatch")
                .font(.headline)
            Text("No timer to set. Saathi keeps you company while you walk and wraps up on its own when your Apple Watch or iPhone Outdoor Walk ends, when you've stopped walking for a while (it asks first), or when you tap End. Your episode then includes your walk's distance, time and steps. Saathi reads totals only, never your route.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier("walkEndExplainer")
    }

    private var startButton: some View {
        Button {
            Task {
                await coordinator.startSession()
            }
        } label: {
            Label("start_walk", systemImage: "figure.walk")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("startWalkButton")
    }

    private var attributionFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sources & Licences")
                .font(.caption.bold())
            Text("Historical text: Wikipedia (CC BY-SA 4.0) & Wikidata (CC0 1.0). Map & POI data: OpenStreetMap contributors (ODbL 1.0).")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
