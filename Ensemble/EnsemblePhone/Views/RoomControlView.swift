import EnsembleCore
import SwiftUI

struct RoomControlView: View {
    @Bindable var model: PhoneAppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                personaHeader
                roomPresenceToggle
                querySection
                actionButtons
                if !model.tvInstalledApps.isEmpty {
                    connectedTVAppsCard
                }
                if let recap = model.latestRecap {
                    recapPreviewCard(recap)
                }
                tasteVectorPrivacyCard
            }
            .padding(20)
        }
        .navigationTitle("Living Room")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Switch Profile") {
                    model.switchPersona()
                }
            }
        }
    }

    private var personaHeader: some View {
        HStack(spacing: 14) {
            if let persona = model.selectedPersona {
                Image(systemName: persona.avatarSymbol)
                    .font(.system(size: 34))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(persona.displayName)
                        .font(.title3.bold())
                    Text("\(connectionLabel) · \(model.appleIntelligenceBadge)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private var connectionLabel: String {
        switch model.connectionState {
        case .connected(let name): return "Connected to \(name)"
        case .searching: return "Searching _ensemble._tcp…"
        case .disconnected: return "Disconnected"
        }
    }

    private var roomPresenceToggle: some View {
        Button {
            model.toggleRoomPresence()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.isInRoom ? "I'm here" : "I left")
                        .font(.title2.bold())
                    Text(model.isInRoom
                         ? "Sending heartbeat every 2s · Tap to leave room"
                         : "Tap to join Apple TV room and rank together")
                        .font(.subheadline)
                        .opacity(0.85)
                }
                Spacer()
                Image(systemName: model.isInRoom ? "checkmark.circle.fill" : "person.crop.circle.badge.minus")
                    .font(.system(size: 30))
            }
            .foregroundStyle(.white)
            .padding(20)
            .background(model.isInRoom ? Color.blue : Color.secondary, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private var querySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ask or Find a Moment")
                .font(.headline)

            HStack(spacing: 10) {
                TextField("e.g. \"the part where the dragon appears\"", text: $model.queryText)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.send)
                    .onSubmit {
                        model.sendQueryToTV()
                    }

                Button {
                    model.speechService.toggleDictation { transcript in
                        model.queryText = transcript
                    }
                } label: {
                    Image(systemName: model.speechService.isRecording ? "mic.fill" : "mic")
                        .frame(width: 44, height: 44)
                        .background(
                            model.speechService.isRecording ? Color.red.opacity(0.18) : Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }
                .accessibilityLabel("Dictate query")
            }

            if let speechErr = model.speechService.errorMessage {
                Text(speechErr)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    suggestionButton("something for all of us under 40 min")
                    suggestionButton("the part where the dragon appears")
                    suggestionButton("robotic bridge memory lab")
                }
            }
        }
    }

    private func suggestionButton(_ text: String) -> some View {
        Button(text) {
            model.queryText = text
            model.sendQueryToTV()
        }
        .font(.caption)
        .buttonStyle(.bordered)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                model.requestCatchMeUp()
            } label: {
                Label("Catch me up", systemImage: "text.bubble")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)

            Button {
                if model.queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    model.playTopPickOnTV()
                } else {
                    model.sendQueryToTV()
                }
            } label: {
                Label("Play on TV", systemImage: "tv.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var connectedTVAppsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Installed Apps on Apple TV")
                .font(.headline)
            let installed = model.tvInstalledApps.filter(\.isInstalled).map(\.displayName)
            Text(installed.isEmpty
                 ? "Only Ensemble direct streams detected."
                 : installed.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func recapPreviewCard(_ recap: RecapPayload) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Spoiler-Free Recap")
                    .font(.headline)
                Spacer()
                Text(recap.generatedOnDeviceWithAppleIntelligence ? "FoundationModels" : "Template")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(recap.summary)
                .font(.subheadline)
            if !recap.keyCharacters.isEmpty {
                Text("Characters: \(recap.keyCharacters.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var tasteVectorPrivacyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shared Taste Vector (Privacy-Preserving)")
                .font(.headline)
            Text("Only normalized weights leave this device; raw watch history stays local.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let vector = model.computedTasteVector {
                let topGenres = vector.genreWeights
                    .sorted { $0.value > $1.value }
                    .prefix(4)
                    .map { "\($0.key): \(Int(($0.value * 100).rounded()))%" }
                    .joined(separator: " · ")
                Text(topGenres)
                    .font(.caption.monospaced())
                    .foregroundStyle(.primary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
