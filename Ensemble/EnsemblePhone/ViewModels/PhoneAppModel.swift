import EnsembleCore
import Foundation
import Observation

@MainActor
@Observable
final class PhoneAppModel {
    let personas: [Persona]
    let participantID = UUID()

    var selectedPersona: Persona?
    var computedTasteVector: TasteVector?
    var isInRoom: Bool = false
    var queryText: String = ""
    var connectionState: PhoneBonjourClient.ConnectionState = .disconnected
    var tvInstalledApps: [InstalledAppStatus] = []
    var latestRecap: RecapPayload?
    var statusBanner: String?

    let speechService = SpeechDictationService()
    private let client = PhoneBonjourClient()
    private let recapService = PhoneRecapService()

    init() {
        self.personas = (try? PersonaLoader.loadBundledPersonas()) ?? []
        client.onStateChange = { [weak self] state in
            self?.connectionState = state
            if case .connected = state, self?.isInRoom == true {
                self?.sendJoinPacket()
            }
        }
        client.onMessage = { [weak self] message in
            self?.handleServerMessage(message)
        }
    }

    var appleIntelligenceBadge: String {
        recapService.appleIntelligenceStatusLabel
    }

    func selectPersona(_ persona: Persona) {
        selectedPersona = persona
        // Privacy rule: watch history is reduced to a normalized taste vector on-device
        computedTasteVector = TasteVectorBuilder.compute(from: persona.watchHistory)
        client.startBrowsing()
    }

    func switchPersona() {
        if isInRoom {
            toggleRoomPresence()
        }
        selectedPersona = nil
        computedTasteVector = nil
        latestRecap = nil
    }

    func toggleRoomPresence() {
        guard selectedPersona != nil else { return }
        if isInRoom {
            isInRoom = false
            client.stopHeartbeat()
            client.send(.leave(LeavePayload(participantID: participantID)))
            statusBanner = "Left the living room."
        } else {
            isInRoom = true
            sendJoinPacket()
            client.startHeartbeat(participantID: participantID)
            statusBanner = "Joined Apple TV room (heartbeat every 2s)."
        }
    }

    func sendQueryToTV() {
        let trimmed = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !isInRoom {
            toggleRoomPresence()
        }
        client.send(.query(QueryPayload(participantID: participantID, text: trimmed)))
        statusBanner = "Sent query to Apple TV."
    }

    func requestCatchMeUp() {
        if !isInRoom {
            toggleRoomPresence()
        }
        client.send(.command(CommandPayload(kind: .requestRecapContext, participantID: participantID)))
        statusBanner = "Requested spoiler-free subtitle window from Apple TV…"
    }

    func playTopPickOnTV(itemID: String? = nil, targetAppID: StreamingAppID? = nil) {
        if !isInRoom {
            toggleRoomPresence()
        }
        client.send(.command(CommandPayload(
            kind: .playItem,
            participantID: participantID,
            itemID: itemID,
            targetAppID: targetAppID
        )))
        statusBanner = "Sent Play command to Apple TV."
    }

    private func sendJoinPacket() {
        guard let persona = selectedPersona, let vector = computedTasteVector else { return }
        let join = JoinPayload(
            participantID: participantID,
            displayName: persona.displayName,
            avatarSymbol: persona.avatarSymbol,
            accentHex: persona.accentHex,
            isChild: persona.isChild,
            isTeen: persona.isTeen,
            tasteVector: vector
        )
        client.send(.join(join))
    }

    private func handleServerMessage(_ message: WireMessage) {
        switch message {
        case .installedApps(let apps):
            self.tvInstalledApps = apps
        case .subtitleWindow(let window):
            guard let persona = selectedPersona else { return }
            Task {
                let recap = await recapService.generateRecap(
                    participantID: participantID,
                    requesterName: persona.displayName,
                    window: window
                )
                self.latestRecap = recap
                self.client.send(.recap(recap))
                self.statusBanner = "Sent ≤60-word recap to Apple TV overlay."
            }
        default:
            break
        }
    }
}
