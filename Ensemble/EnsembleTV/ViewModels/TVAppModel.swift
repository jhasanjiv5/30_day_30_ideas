import AVKit
import EnsembleCore
import Foundation
import Observation

@MainActor
@Observable
final class TVAppModel {
    private(set) var catalogue: [MediaItem] = []
    private(set) var participants: [RoomParticipant] = []
    private(set) var rankedItems: [RankedMediaItem] = []
    private(set) var maxRuntimeFilter: Int?
    private(set) var activeQueryBanner: String?
    private(set) var installedAppStatuses: [InstalledAppStatus] = []
    var filterToInstalledAppsOnly: Bool = false

    var activePlaybackItem: MediaItem?
    var avPlayer: AVPlayer?
    var currentPlaybackSeconds: Double = 0
    var lateJoinerPrompt: RoomParticipant?
    var activeRecapOverlay: RecapPayload?
    var externalHandoffBanner: String?
    var showAboutSheet: Bool = false

    private let server = TVBonjourServer()
    private let installedAppsService = TVInstalledAppsService()
    private let ranker = GroupRanker(meanWeight: 0.6, minWeight: 0.4, limit: 10)
    private var presenceTracker = PresenceTracker(timeoutSeconds: WireMessage.presenceTimeoutSeconds)
    private var sceneIndex: TVSceneIndex?
    private var presenceTask: Task<Void, Never>?
    private var playbackObserverToken: Any?
    private var recapDismissTask: Task<Void, Never>?
    private var toastDismissTask: Task<Void, Never>?

    init() {
        let loaded = (try? CatalogueLoader.loadBundledCatalogue()) ?? []
        self.catalogue = loaded
        self.sceneIndex = TVSceneIndex(catalogue: loaded)
        self.installedAppStatuses = installedAppsService.scanInstalledApps()
        refreshRecommendations()
    }

    var installedAppIDSet: Set<StreamingAppID> {
        Set(installedAppStatuses.filter(\.isInstalled).map(\.appID))
    }

    func rescanInstalledApps() {
        installedAppStatuses = installedAppsService.scanInstalledApps()
        refreshRecommendations()
        for participant in participants {
            server.send(.installedApps(installedAppStatuses), to: participant.id)
        }
    }

    func toggleInstalledAppsFilter() {
        filterToInstalledAppsOnly.toggle()
        refreshRecommendations()
    }

    func startServices() {
        rescanInstalledApps()
        server.onMessage = { [weak self] message, senderID in
            self?.handleWireMessage(message, senderID: senderID)
        }
        server.start()

        presenceTask?.cancel()
        presenceTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { break }
                let expired = self.presenceTracker.pruneExpired(at: .now)
                if !expired.isEmpty {
                    self.participants = self.presenceTracker.participants
                    self.refreshRecommendations()
                }
            }
        }
    }

    /// Plays directly inside Ensemble if a stream URL is available (when `preferredAppID` is nil or `.ensemble`),
    /// or hands off directly to the installed external Apple TV app via its deep link / universal link.
    func launchItem(_ item: MediaItem, preferredAppID: StreamingAppID? = nil, seekToSeconds: Double? = nil) {
        if let seekToSeconds, item.streamURL != nil {
            play(item: item, seekToSeconds: seekToSeconds)
            return
        }

        if let preferredAppID, preferredAppID != .ensemble,
           let provider = item.providers.first(where: { $0.appID == preferredAppID }) {
            Task {
                await openExternalProvider(provider, title: item.title)
            }
            return
        }

        if item.streamURL != nil {
            play(item: item, seekToSeconds: seekToSeconds)
            return
        }

        if let provider = item.preferredProvider(installedApps: installedAppIDSet) {
            Task {
                await openExternalProvider(provider, title: item.title)
            }
        }
    }

    func openExternalProvider(_ provider: MediaProviderLink, title: String) async {
        externalHandoffBanner = "Opening \"\(title)\" in \(provider.appID.displayName)…"
        let opened = await installedAppsService.openInExternalApp(provider)
        if !opened {
            externalHandoffBanner = "\(provider.appID.displayName) is not installed on this Apple TV."
        }
    }

    func play(item: MediaItem, seekToSeconds: Double? = nil) {
        guard let urlString = item.streamURL, let url = URL(string: urlString) else {
            return
        }

        cleanupPlayerObserver()
        let player = AVPlayer(url: url)
        self.avPlayer = player
        self.activePlaybackItem = item
        self.currentPlaybackSeconds = seekToSeconds ?? 0

        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        playbackObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.currentPlaybackSeconds = time.seconds.isFinite ? time.seconds : 0
            }
        }

        if let seekToSeconds, seekToSeconds > 0 {
            let target = CMTime(seconds: seekToSeconds, preferredTimescale: 600)
            player.seek(to: target, toleranceBefore: .seconds(2), toleranceAfter: .seconds(2)) { _ in
                player.play()
            }
        } else {
            player.play()
        }
    }

    func closePlayer() {
        avPlayer?.pause()
        cleanupPlayerObserver()
        avPlayer = nil
        activePlaybackItem = nil
        lateJoinerPrompt = nil
        activeRecapOverlay = nil
    }

    func requestRecapForLateJoiner(_ participant: RoomParticipant) {
        lateJoinerPrompt = nil
        sendSubtitleWindow(to: participant.id)
    }

    func dismissLateJoinerPrompt() {
        lateJoinerPrompt = nil
    }

    func clearTimeBudget() {
        maxRuntimeFilter = nil
        activeQueryBanner = nil
        refreshRecommendations()
    }

    var rowHeaderTitle: String {
        GroupRanker.rowTitle(for: participants)
    }

    private func handleWireMessage(_ message: WireMessage, senderID: UUID?) {
        let wasAlreadyPresent: Bool
        if case .join(let payload) = message {
            wasAlreadyPresent = participants.contains(where: { $0.id == payload.participantID })
        } else {
            wasAlreadyPresent = true
        }

        let groupChanged = presenceTracker.apply(message, at: .now)
        if groupChanged {
            participants = presenceTracker.participants
            refreshRecommendations()

            if case .join(let payload) = message {
                server.send(.installedApps(installedAppStatuses), to: payload.participantID)
                if !wasAlreadyPresent,
                   activePlaybackItem != nil,
                   let newcomer = participants.first(where: { $0.id == payload.participantID }) {
                    showLateJoinerToast(for: newcomer)
                }
            }
        }

        switch message {
        case .query(let payload):
            handleQuery(payload)
        case .command(let cmd):
            handleCommand(cmd)
        case .recap(let recap):
            showRecapOverlay(recap)
        default:
            break
        }
    }

    private func handleQuery(_ payload: QueryPayload) {
        let intent = NaturalQueryParser.parse(payload.text)

        if let budget = intent.maxRuntimeMinutes {
            maxRuntimeFilter = budget
            activeQueryBanner = "Filtered: under \(budget) min — \"\(payload.text)\""
            refreshRecommendations()
            return
        }

        if intent.isSceneQuery,
           let match = sceneIndex?.findBestMoment(
               query: payload.text,
               preferredFilmID: activePlaybackItem?.id
           ),
           let targetItem = catalogue.first(where: { $0.id == match.filmID }) {
            activeQueryBanner = "Jumping to \(targetItem.title) at \(formatTimestamp(match.timestampSeconds))"
            if activePlaybackItem?.id == targetItem.id, let player = avPlayer {
                let cmTime = CMTime(seconds: match.timestampSeconds, preferredTimescale: 600)
                player.seek(to: cmTime, toleranceBefore: .seconds(2), toleranceAfter: .seconds(2))
            } else {
                play(item: targetItem, seekToSeconds: match.timestampSeconds)
            }
            return
        }

        activeQueryBanner = "Ranked for: \"\(payload.text)\""
        rankedItems = ranker.rank(
            catalogue: catalogue,
            participants: participants,
            maxRuntimeMinutes: maxRuntimeFilter,
            moodBoostQuery: payload.text,
            installedAppIDs: filterToInstalledAppsOnly ? installedAppIDSet : nil
        )
    }

    private func handleCommand(_ cmd: CommandPayload) {
        switch cmd.kind {
        case .playItem:
            if let itemID = cmd.itemID,
               let item = catalogue.first(where: { $0.id == itemID }) {
                launchItem(item, preferredAppID: cmd.targetAppID, seekToSeconds: cmd.timestampSeconds)
            } else if let firstMatch = rankedItems.first?.item {
                launchItem(firstMatch, preferredAppID: cmd.targetAppID, seekToSeconds: cmd.timestampSeconds)
            }
        case .jumpToScene:
            if let itemID = cmd.itemID,
               let item = catalogue.first(where: { $0.id == itemID }),
               let ts = cmd.timestampSeconds {
                play(item: item, seekToSeconds: ts)
            }
        case .requestRecapContext:
            sendSubtitleWindow(to: cmd.participantID)
        case .clearTimeBudget:
            clearTimeBudget()
        }
    }

    private func sendSubtitleWindow(to participantID: UUID) {
        guard let item = activePlaybackItem else { return }
        let cues = sceneIndex?.cues(for: item.id) ?? []
        let safeTranscript = RecapWindowExtractor.transcriptUpTo(
            currentTime: currentPlaybackSeconds,
            from: cues
        )
        let payload = SubtitleWindowPayload(
            filmID: item.id,
            filmTitle: item.title,
            currentTimeSeconds: currentPlaybackSeconds,
            transcriptUpToNow: safeTranscript
        )
        server.send(.subtitleWindow(payload), to: participantID)
    }

    private func showLateJoinerToast(for participant: RoomParticipant) {
        lateJoinerPrompt = participant
        toastDismissTask?.cancel()
        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            self?.lateJoinerPrompt = nil
        }
    }

    private func showRecapOverlay(_ recap: RecapPayload) {
        activeRecapOverlay = recap
        recapDismissTask?.cancel()
        recapDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(12))
            guard !Task.isCancelled else { return }
            self?.activeRecapOverlay = nil
        }
    }

    private func refreshRecommendations() {
        rankedItems = ranker.rank(
            catalogue: catalogue,
            participants: participants,
            maxRuntimeMinutes: maxRuntimeFilter,
            installedAppIDs: filterToInstalledAppsOnly ? installedAppIDSet : nil
        )
    }

    private func cleanupPlayerObserver() {
        if let token = playbackObserverToken, let player = avPlayer {
            player.removeTimeObserver(token)
        }
        playbackObserverToken = nil
    }

    private func formatTimestamp(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
