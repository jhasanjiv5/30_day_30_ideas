import Foundation
import SwiftUI
import AVFAudio
import Translation
import SaathiCore

/// TranslationSession isn't annotated Sendable. Saathi uses each session from a single task,
/// strictly sequentially (processTranslationQueue awaits each translate call), so crossing
/// from the main actor into its async API is safe here.
extension TranslationSession: @retroactive @unchecked Sendable {}

/// Tunables from `Config/SaathiConfig.json` (ranker weights, interruption budget, radii).
/// Previously the file shipped in the bundle but nothing read it.
struct SaathiAppConfig: Decodable, Sendable {
    let tileSizeMeters: Double
    let maxCandidateRadiusMeters: Double
    let interruptionBudgetSeconds: Double
    let dwellThresholdSeconds: Double
    let rankerWeights: RankerWeights
    /// Silence (seconds) after which Saathi talks about the wider area between landmarks.
    let companionIdleSeconds: Double?
    /// Radius for "around you" places used in those quiet stretches.
    let areaRadiusMeters: Double?
    /// When to ask "Shall I wrap up your walk?" and when to end on its own.
    let walkEnd: WalkEndDetector.Settings?

    var companionIdleSecondsValue: Double { companionIdleSeconds ?? 240 }
    var areaRadiusMetersValue: Double { areaRadiusMeters ?? 5_000 }
    var walkEndSettings: WalkEndDetector.Settings { walkEnd ?? .default }

    static let fallback = SaathiAppConfig(
        tileSizeMeters: GeoTileSnapper.defaultTileSizeMeters,
        maxCandidateRadiusMeters: PlaceRanker.defaultMaxRadiusMeters,
        interruptionBudgetSeconds: 180,
        dwellThresholdSeconds: PlaceRanker.defaultDwellThresholdSeconds,
        rankerWeights: .default,
        companionIdleSeconds: nil,
        areaRadiusMeters: nil,
        walkEnd: nil
    )

    static func load(bundle: Bundle = .main) -> SaathiAppConfig {
        guard let url = bundle.url(forResource: "SaathiConfig", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(SaathiAppConfig.self, from: data) else {
            return .fallback
        }
        return config
    }
}

enum SessionPhase: Equatable {
    case idle
    case requestingPermission
    case active
    case pausedQuiet
    case ending
    case wiped
    case episodeDecision
}

@MainActor
@Observable
final class SessionCoordinator {
    private(set) var phase: SessionPhase = .idle
    var touchModeEnabled: Bool = false
    var narrationLanguage: SaathiLanguage
    var listeningLanguage: SaathiLanguage
    var secondaryEpisodeLanguage: SaathiLanguage?

    /// Open-ended walk: no duration is chosen up front. The walk ends when the Apple Watch /
    /// iPhone workout ends, when motion says the walk is over (after asking), or on "End".
    private(set) var elapsedSeconds: TimeInterval = 0
    private(set) var quietRemainingSeconds: TimeInterval = 0
    private(set) var liveWalkStats: WalkLiveStats = .zero
    private(set) var walkSummary: WalkSummary?

    private(set) var nearbyRankedPlaces: [RankedPlace] = []
    private(set) var segments: [NarrationSegment] = []
    private(set) var pendingHeadGesturePrompt: String?
    private(set) var statusBanner: String?

    enum PromptKind: Equatable {
        case fullStory
        case wrapUpWalk
    }
    private(set) var pendingPromptKind: PromptKind?

    private(set) var privacyReceipt: PrivacyReceipt?
    private(set) var generatedEpisode: MemoryEpisode?
    private(set) var episodeStatusMessage: String?

    /// Pending translation config when `TranslationSession` needs to run in SwiftUI context
    var pendingTranslationConfig: TranslationSession.Configuration?

    let locationManager: LocationSessionManager
    let narrator = FoundationModelNarrator()
    let speechService = SpeechCommandService()
    let audioService = SpatialAudioService()
    let personalService = PersonalContextService()
    let episodeStorage = EpisodeStorageService()
    let sourceClient: PublicSourceClient

    private var interestProfile = SessionInterestProfile()
    private var budget = InterruptionBudget(minIntervalSeconds: 180)
    private var referencedMemories: [PersonalMemoryItem] = []
    private var sessionClockTask: Task<Void, Never>?
    private var sessionStartedAt: Date?
    private var walkEndDetector: WalkEndDetector?
    private var lastSpokenAt = Date()
    private var promptShownAt: Date?
    private var isFetchingAreaContext = false
    #if os(iOS)
    let walkMonitor = WalkActivityMonitor()
    #endif
    private var lastMovementTimestamp = Date()
    private var lastAnchorCoordinate: EphemeralCoordinate?
    private var currentActivePlace: RankedPlace?
    /// True while a narration is being generated/spoken; stops overlapping unprompted segments
    /// when several location updates arrive during one slow model call.
    private var isNarrating = false
    /// English segments waiting for on-device translation into the narration language.
    private var translationQueue: [NarrationSegment] = []
    private let config = SaathiAppConfig.load()
    private let mockMode: Bool

    init(
        mockMode: Bool = false,
        initialNarrationLanguage: SaathiLanguage = .fromDeviceLocale(),
        initialListeningLanguage: SaathiLanguage = .fromDeviceLocale()
    ) {
        self.mockMode = mockMode
        self.narrationLanguage = initialNarrationLanguage
        self.listeningLanguage = initialListeningLanguage
        self.locationManager = LocationSessionManager(mockMode: mockMode)

        // Tile cache is memory-only and session-scoped (see PublicSourceClient.resetSession).
        self.sourceClient = PublicSourceClient(mockMode: mockMode)
        narrator.preferTemplateNarration = mockMode
    }

    func startSession() async {
        guard phase == .idle else { return }
        phase = .requestingPermission
        let startedAt = Date()
        sessionStartedAt = startedAt
        elapsedSeconds = 0
        liveWalkStats = .zero
        walkSummary = nil
        lastSpokenAt = startedAt
        pendingPromptKind = nil
        pendingHeadGesturePrompt = nil
        walkEndDetector = WalkEndDetector(sessionStart: startedAt, settings: config.walkEndSettings)
        segments.removeAll()
        referencedMemories.removeAll()
        nearbyRankedPlaces.removeAll()
        translationQueue.removeAll()
        currentActivePlace = nil
        isNarrating = false
        interestProfile = SessionInterestProfile()
        // Mock mode compresses time so a demo walk shows several narrations in a minute.
        budget = InterruptionBudget(minIntervalSeconds: mockMode ? 6 : config.interruptionBudgetSeconds)
        await sourceClient.resetSession()
        personalService.resetSessionCache()

        phase = .active
        locationManager.start { [weak self] coordinate in
            guard let self else { return }
            Task { await self.onLocationUpdated(coordinate) }
        }
        startSessionClock()
        startWalkMonitoring(from: startedAt)

        Task { [weak self] in
            await self?.startAudioAndSpeechServices()
        }
    }

    // MARK: - Walk monitoring (Apple Watch / iPhone workout + motion)

    private func startWalkMonitoring(from startedAt: Date) {
        #if os(iOS)
        guard !mockMode else { return }
        Task { [weak self] in
            guard let self else { return }
            if !self.walkMonitor.healthAuthorizationRequested {
                await self.walkMonitor.requestHealthAuthorization()
            }
            guard self.phase == .active || self.phase == .pausedQuiet else { return }
            self.walkMonitor.start(
                sessionStart: startedAt,
                onLiveStats: { [weak self] stats in
                    self?.liveWalkStats = WalkLiveStats(steps: stats.steps, distanceMeters: stats.distanceMeters)
                },
                onMotion: { [weak self] state in
                    self?.walkEndDetector?.recordMotion(state, at: Date())
                },
                onWorkoutEnded: { [weak self] in
                    guard let self else { return }
                    // The Apple Watch / iPhone Outdoor Walk ended: wrap up and make the episode.
                    _ = self.walkEndDetector?.recordWorkoutEnded()
                    Task { await self.endSession(reason: .workoutEnded) }
                }
            )
        }
        #endif
    }

    /// Runs once a second: elapsed clock, quiet-mode countdown, walk-end checks and the
    /// "keep the user company" cadence between landmarks.
    private func startSessionClock() {
        sessionClockTask?.cancel()
        sessionClockTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.phase == .active || self.phase == .pausedQuiet else { break }
                tick += 1
                if let start = self.sessionStartedAt {
                    self.elapsedSeconds = Date().timeIntervalSince(start)
                }
                if self.mockMode {
                    // Simulated pedometer (~1.3 m/s, ~1.4 steps/s) so the demo shows live stats.
                    self.liveWalkStats = WalkLiveStats(
                        steps: Int(self.elapsedSeconds * 1.4),
                        distanceMeters: self.elapsedSeconds * 1.3
                    )
                }
                self.tickQuietMode()
                self.expireUnansweredStoryPrompt()
                await self.evaluateWalkEnd()
                if tick % (self.mockMode ? 3 : 10) == 0 {
                    await self.maybeKeepCompany()
                }
            }
        }
    }

    /// "Want the full story?" is an offer, not a question that must be answered:
    /// drop it after a while so the banner doesn't linger for the rest of the walk.
    private func expireUnansweredStoryPrompt() {
        guard pendingPromptKind == .fullStory, let shownAt = promptShownAt else { return }
        if Date().timeIntervalSince(shownAt) >= (mockMode ? 6 : 45) {
            pendingPromptKind = nil
            pendingHeadGesturePrompt = nil
            promptShownAt = nil
        }
    }

    private func tickQuietMode() {
        guard phase == .pausedQuiet else { return }
        if quietRemainingSeconds > 1 {
            quietRemainingSeconds -= 1
        } else {
            budget.cancelQuiet()
            quietRemainingSeconds = 0
            phase = .active
            statusBanner = nil
        }
    }

    private func evaluateWalkEnd() async {
        guard var detector = walkEndDetector else { return }
        let decision = detector.evaluate(at: Date())
        walkEndDetector = detector
        switch decision {
        case .keepGoing:
            break
        case .askToWrapUp(let reason):
            let question = reason == .leftByVehicle
                ? "Looks like you're travelling now. Shall I wrap up your walk?"
                : "You've been resting a while. Shall I wrap up your walk?"
            pendingPromptKind = .wrapUpWalk
            pendingHeadGesturePrompt = question
            statusBanner = question
            if !touchModeEnabled { audioService.speak(question, language: .englishIndia) }
        case .end(let reason):
            await endSession(reason: reason)
        }
    }

    /// Between landmarks, keep talking about the wider area so the user isn't left in silence:
    /// if nothing was said for `companionIdleSeconds`, narrate a notable place a few km away.
    private func maybeKeepCompany() async {
        // An unanswered "Want the full story?" must not silence the companion;
        // only a pending "wrap up your walk?" question holds narration back.
        guard phase == .active,
              !isNarrating,
              !isFetchingAreaContext,
              pendingPromptKind != .wrapUpWalk,
              Date().timeIntervalSince(lastSpokenAt) >= (mockMode ? 8 : config.companionIdleSecondsValue),
              budget.canDeliverUnpromptedSegment(),
              let coordinate = locationManager.currentCoordinate else { return }

        isFetchingAreaContext = true
        defer { isFetchingAreaContext = false }
        guard let (_, areaPlaces) = try? await sourceClient.fetchAreaContext(
            near: coordinate,
            preferredLanguage: narrationLanguage,
            radiusMeters: Int(config.areaRadiusMetersValue)
        ) else { return }

        let candidates = PlaceRanker.rank(
            candidates: areaPlaces,
            userCoordinate: coordinate,
            interestProfile: interestProfile,
            dwellDurationSeconds: 0,
            maxRadiusMeters: config.areaRadiusMetersValue,
            weights: config.rankerWeights
        ).filter { !interestProfile.toldPlaceIDs.contains($0.place.id) && $0.distanceMeters > config.maxCandidateRadiusMeters }

        guard let pick = candidates.first, phase == .active, budget.canDeliverUnpromptedSegment() else { return }
        let bearing = coordinate.bearingDegrees(to: pick.place.coordinate)
        let framing = "\(CompassDirection.spokenDistance(meters: pick.distanceMeters)) to your \(CompassDirection.spoken(bearingDegrees: bearing))"
        budget.recordUnpromptedDelivery()
        await deliverNarration(for: pick, userQuestion: nil, isUnprompted: true, areaFraming: framing)
    }

    private func startAudioAndSpeechServices() async {
        await audioService.configureAudioSession()

        guard phase == .active || phase == .pausedQuiet else { return }

        audioService.startHeadphoneMotion { [weak self] gesture in
            guard let self else { return }
            Task { await self.handleHeadGesture(gesture) }
        }

        guard !mockMode else { return }

        await speechService.startListening(
            language: listeningLanguage,
            onCommand: { [weak self] cmd in
                guard let self else { return }
                Task { await self.handleVoiceCommand(cmd) }
            },
            onSpeakingStateChanged: { [weak self] speaking in
                self?.budget.setUserSpeaking(speaking)
            }
        )
    }

    func endSession(reason: WalkEndReason = .userEnded) async {
        guard phase == .active || phase == .pausedQuiet else { return }
        phase = .ending
        sessionClockTask?.cancel()
        sessionClockTask = nil
        pendingPromptKind = nil
        pendingHeadGesturePrompt = nil

        speechService.stopListening()
        audioService.stopSpeaking()
        audioService.stopHeadphoneMotion()
        personalService.resetSessionCache()

        let duration = locationManager.stopAndWipe()
        let endedAt = Date()
        let startedAt = sessionStartedAt ?? endedAt.addingTimeInterval(-duration)

        // Walk totals from the Apple Watch / iPhone workout, else the pedometer.
        #if os(iOS)
        if mockMode {
            walkSummary = WalkSummary(
                startedAt: startedAt,
                endedAt: endedAt,
                source: .iPhonePedometer,
                distanceMeters: liveWalkStats.distanceMeters,
                steps: liveWalkStats.steps,
                endReason: reason
            )
        } else {
            walkSummary = await walkMonitor.buildSummary(endedAt: endedAt, reason: reason)
            walkMonitor.stop()
        }
        #else
        walkSummary = WalkSummary(startedAt: startedAt, endedAt: endedAt, source: .sessionClockOnly, endReason: reason)
        #endif
        walkEndDetector = nil
        let lookups = await sourceClient.lookupCountAndTiles()
        await sourceClient.resetSession()
        translationQueue.removeAll()
        pendingTranslationConfig = nil

        // Measure, don't assume: scan the app container for persisted coordinates.
        let storedCoordinateFindings = Self.scanContainerForCoordinates()
        if !storedCoordinateFindings.isEmpty {
            statusBanner = "Privacy check found \(storedCoordinateFindings.count) stored coordinate(s)."
        }

        privacyReceipt = PrivacyReceipt(
            sessionStartedAt: Date().addingTimeInterval(-duration),
            sessionEndedAt: Date(),
            locationDurationSeconds: duration,
            coordinatesStoredCount: storedCoordinateFindings.count,
            personalItemsReferencedCount: referencedMemories.count,
            anonymousTileLookupsCount: lookups.count,
            queriedTileIDs: lookups.tileIDs
        )

        generatedEpisode = EpisodeBuilder.build(
            segments: segments,
            referencedMemories: referencedMemories,
            language: narrationLanguage,
            secondaryLanguage: secondaryEpisodeLanguage,
            sessionDate: startedAt,
            walkSummary: walkSummary
        )
        phase = .wiped
    }

    func proceedToEpisode() {
        phase = .episodeDecision
    }

    func finalizeEpisode(decision: EpisodeDecision) async {
        guard let episode = generatedEpisode else {
            phase = .idle
            return
        }
        do {
            switch decision {
            case .keepOnDevice:
                _ = try episodeStorage.saveLocally(episode)
                episodeStatusMessage = "Saved on this iPhone (0 coordinates)."
            case .saveToICloud:
                try await episodeStorage.saveToICloud(episode)
                episodeStatusMessage = "Saved to private iCloud (0 coordinates)."
            case .discard:
                generatedEpisode = nil
                episodeStatusMessage = "Episode discarded."
            }
        } catch {
            episodeStatusMessage = "Save error: \(error.localizedDescription)"
        }
        phase = .idle
    }

    func handleVoiceCommand(_ command: SaathiVoiceCommand) async {
        switch command {
        case .tellMeMore:
            if let top = currentActivePlace ?? nearbyRankedPlaces.first {
                interestProfile.recordAskedAbout(tags: top.place.tags)
                await deliverNarration(for: top, userQuestion: nil, isUnprompted: false)
            }
        case .skip:
            if let current = currentActivePlace ?? nearbyRankedPlaces.first {
                interestProfile.recordSkipped(placeID: current.place.id, tags: current.place.tags)
                audioService.stopSpeaking()
                pendingHeadGesturePrompt = nil
                rerankCurrentPlaces()
                if let next = nearbyRankedPlaces.first {
                    await deliverNarration(for: next, userQuestion: nil, isUnprompted: false)
                }
            }
        case .quiet(let minutes):
            budget.requestQuiet(minutes: minutes)
            quietRemainingSeconds = TimeInterval(minutes * 60)
            audioService.stopSpeaking()
            pendingHeadGesturePrompt = nil
            phase = .pausedQuiet
            statusBanner = "Quiet for \(minutes) min"
        case .resumeNarration:
            budget.cancelQuiet()
            quietRemainingSeconds = 0
            phase = .active
            statusBanner = nil
        case .whatDidIPhotographHere:
            let photos = await personalService.fetchOnDeviceMemories(
                near: locationManager.currentCoordinate,
                mockMode: mockMode
            ).filter { $0.kind == .photo }
            if let first = photos.first, let target = currentActivePlace ?? nearbyRankedPlaces.first {
                referencedMemories.append(first)
                await deliverNarration(for: target, userQuestion: "What did I photograph here?", isUnprompted: false)
            } else {
                let msg = "No opted-in photos found within 300 m of here."
                statusBanner = msg
                if !touchModeEnabled { audioService.speak(msg, language: narrationLanguage) }
            }
        case .whereIsIt:
            if let target = currentActivePlace ?? nearbyRankedPlaces.first,
               let userCoord = locationManager.currentCoordinate {
                let bearing = Int(userCoord.bearingDegrees(to: target.place.coordinate))
                let dist = Int(target.distanceMeters)
                let msg = "\(target.place.title) is \(dist) meters away at bearing \(bearing)°."
                statusBanner = msg
                audioService.updateSpatialLandmarkBearing(
                    userCoordinate: userCoord,
                    landmarkCoordinate: target.place.coordinate
                )
                if !touchModeEnabled { audioService.speak(msg, language: narrationLanguage) }
            }
        case .endSession:
            await endSession()
        case .freeQuestion(let q):
            guard !q.isEmpty else { return }
            if let target = currentActivePlace ?? nearbyRankedPlaces.first {
                interestProfile.recordAskedAbout(tags: target.place.tags)
                await deliverNarration(for: target, userQuestion: q, isUnprompted: false)
            }
        }
    }

    /// Answers to the on-screen / spoken yes-no prompt: nod or "Yes" button = yes.
    func handleHeadGesture(_ gesture: SpatialAudioService.HeadGesture) async {
        guard pendingHeadGesturePrompt != nil else { return }
        let kind = pendingPromptKind ?? .fullStory
        pendingHeadGesturePrompt = nil
        pendingPromptKind = nil
        switch (kind, gesture) {
        case (.wrapUpWalk, .nodYes):
            await endSession(reason: walkEndReasonForPrompt())
        case (.wrapUpWalk, .shakeNo):
            walkEndDetector?.userDeclinedWrapUp(at: Date())
            statusBanner = nil
        case (.fullStory, .nodYes):
            await handleVoiceCommand(.tellMeMore)
        case (.fullStory, .shakeNo):
            await handleVoiceCommand(.skip)
        }
    }

    private func walkEndReasonForPrompt() -> WalkEndReason {
        walkEndDetector?.currentState == .automotive ? .leftByVehicle : .stoppedMoving
    }

    func evaluateAllLanguageCapabilities() async -> [LanguagePipelineCapability] {
        let modelInfo = narrator.checkAvailability()
        var capabilities: [LanguagePipelineCapability] = []
        for lang in SaathiLanguage.allCases {
            let speechBackend = await speechService.evaluateBackend(for: lang)
            let hasVoice = audioService.bestVoice(for: lang) != nil
            let hasEnhanced = AVSpeechSynthesisVoice.speechVoices().contains {
                $0.language.lowercased().hasPrefix(lang.baseLanguageCode) &&
                ($0.quality == .enhanced || $0.quality == .premium)
            }
            let signals = LanguageRuntimeSignals(
                speechAnalyzerInstalled: speechBackend == .speechAnalyzer,
                speechAnalyzerSupported: speechBackend == .speechAnalyzer,
                legacySpeechRecognizerAvailable: speechBackend == .sfSpeechRecognizer,
                foundationModelAvailable: modelInfo.isAvailable,
                foundationModelSupportsLocale: modelInfo.supportsLocale(lang.locale),
                translationStatus: lang == .englishIndia ? .notNeeded : .downloadableWithConsent,
                hasEnhancedOrPremiumTTSVoice: hasEnhanced,
                hasAnyTTSVoice: hasVoice
            )
            capabilities.append(CapabilityMatrixEvaluator.evaluate(language: lang, signals: signals))
        }
        return capabilities
    }

    private func onLocationUpdated(_ coordinate: EphemeralCoordinate) async {
        if let anchor = lastAnchorCoordinate {
            if coordinate.distanceMeters(to: anchor) > 15 {
                lastAnchorCoordinate = coordinate
                lastMovementTimestamp = Date()
            }
        } else {
            lastAnchorCoordinate = coordinate
            lastMovementTimestamp = Date()
        }

        do {
            let (_, places) = try await sourceClient.fetchPlaces(
                near: coordinate,
                preferredLanguage: narrationLanguage,
                tileSizeMeters: config.tileSizeMeters
            )
            let dwell = Date().timeIntervalSince(lastMovementTimestamp)
            let ranked = rank(places, from: coordinate, dwell: dwell)
            nearbyRankedPlaces = ranked

            if let top = ranked.first,
               !isNarrating,
               budget.canDeliverUnpromptedSegment(),
               !interestProfile.toldPlaceIDs.contains(top.place.id) {
                // Reserve the budget slot before the (slow) model call so concurrent
                // location updates can't start a second unprompted segment.
                budget.recordUnpromptedDelivery()
                await deliverNarration(for: top, userQuestion: nil, isUnprompted: true)
            }
        } catch {
            statusBanner = "Place lookup offline; using cached facts."
        }
    }

    private func rerankCurrentPlaces() {
        guard let coord = locationManager.currentCoordinate else { return }
        let raw = nearbyRankedPlaces.map(\.place)
        let dwell = Date().timeIntervalSince(lastMovementTimestamp)
        nearbyRankedPlaces = rank(raw, from: coord, dwell: dwell)
    }

    private func rank(_ places: [PlaceCandidate], from coordinate: EphemeralCoordinate, dwell: TimeInterval) -> [RankedPlace] {
        PlaceRanker.rank(
            candidates: places,
            userCoordinate: coordinate,
            interestProfile: interestProfile,
            dwellDurationSeconds: dwell,
            maxRadiusMeters: config.maxCandidateRadiusMeters,
            dwellThresholdSeconds: config.dwellThresholdSeconds,
            weights: config.rankerWeights
        )
    }

    private func deliverNarration(
        for ranked: RankedPlace,
        userQuestion: String?,
        isUnprompted: Bool,
        areaFraming: String? = nil
    ) async {
        currentActivePlace = ranked
        isNarrating = true
        lastSpokenAt = Date()
        defer {
            isNarrating = false
            lastSpokenAt = Date()
        }
        // Location-less items (calendar, journaling) are offered once per session;
        // photos are re-offered because they are matched to the place being narrated.
        let localMemories = await personalService.fetchOnDeviceMemories(
            near: locationManager.currentCoordinate,
            mockMode: mockMode
        ).filter { $0.approximateCoordinate != nil || !referencedMemories.contains($0) }

        let segment = await narrator.generateNarration(
            for: ranked,
            memories: localMemories,
            curatedNotice: nil,
            narrationLanguage: narrationLanguage,
            userQuestion: userQuestion,
            isUnprompted: isUnprompted,
            areaFraming: areaFraming
        )

        // The session may have ended while the model was generating.
        guard phase == .active || phase == .pausedQuiet else { return }

        segments.insert(segment, at: 0)
        interestProfile.recordTold(placeID: ranked.place.id, tags: ranked.place.tags)
        for memID in segment.referencedMemoryIDs {
            if let item = localMemories.first(where: { $0.id == memID }),
               !referencedMemories.contains(item) {
                referencedMemories.append(item)
            }
        }

        // Don't overwrite a pending "wrap up your walk?" question with "want the full story?".
        if pendingPromptKind != .wrapUpWalk {
            pendingHeadGesturePrompt = segment.followUpPrompt
            pendingPromptKind = segment.followUpPrompt == nil ? nil : .fullStory
            promptShownAt = segment.followUpPrompt == nil ? nil : Date()
        }
        audioService.updateSpatialLandmarkBearing(
            userCoordinate: locationManager.currentCoordinate,
            landmarkCoordinate: ranked.place.coordinate
        )
        if needsTranslation(segment), mockMode {
            // Mock mode stays offline and prompt-free (demos, UI tests, screenshots):
            // no language-pack download sheet. Real sessions translate on-device.
            statusBanner = "Mock mode: English text is not translated here. On a device it is translated on-device into \(narrationLanguage.englishName)."
            if !touchModeEnabled { audioService.speak(segment.spokenText, language: .englishIndia) }
        } else if needsTranslation(segment) {
            // Speak only after on-device translation (handled by LiveSessionView's translationTask).
            enqueueTranslation(segment)
        } else if !touchModeEnabled {
            audioService.speak(segment.spokenText, language: language(of: segment))
        }
    }

    // MARK: - On-device translation (English generation -> narration language)

    private func language(of segment: NarrationSegment) -> SaathiLanguage {
        SaathiLanguage(rawValue: segment.languageCode) ?? narrationLanguage
    }

    /// Hinglish listeners get English as-is; every other Indian language is translated
    /// when the model (or template fallback) produced English.
    private func needsTranslation(_ segment: NarrationSegment) -> Bool {
        guard narrationLanguage != .englishIndia, narrationLanguage != .hinglish else { return false }
        return language(of: segment).baseLanguageCode != narrationLanguage.baseLanguageCode
    }

    private func enqueueTranslation(_ segment: NarrationSegment) {
        translationQueue.append(segment)
        let target = narrationLanguage.locale.language
        if pendingTranslationConfig?.target == target {
            pendingTranslationConfig?.invalidate() // re-run the existing task for the new item
        } else {
            pendingTranslationConfig = TranslationSession.Configuration(
                source: Locale.Language(identifier: "en"),
                target: target
            )
        }
    }

    /// Called from `.translationTask` in LiveSessionView with a ready TranslationSession.
    func processTranslationQueue(using session: TranslationSession) async {
        while !translationQueue.isEmpty {
            let original = translationQueue.removeFirst()
            let properNames = [original.placeTitle]
            let protected = TranslationGuard.protect(text: original.spokenText, properNames: properNames)
            do {
                let response = try await session.translate(protected.tokenizedText)
                let restored = TranslationGuard.restore(
                    translatedText: response.targetText,
                    context: protected,
                    targetLanguage: narrationLanguage
                )
                let translated = NarrationSegment(
                    id: original.id,
                    placeID: original.placeID,
                    placeTitle: original.placeTitle,
                    spokenText: restored,
                    captionText: restored,
                    followUpPrompt: original.followUpPrompt,
                    citations: original.citations,
                    referencedMemoryIDs: original.referencedMemoryIDs,
                    languageCode: narrationLanguage.rawValue,
                    timestamp: original.timestamp,
                    isUnprompted: original.isUnprompted
                )
                if let idx = segments.firstIndex(where: { $0.id == original.id }) {
                    segments[idx] = translated
                }
                if !touchModeEnabled && (phase == .active || phase == .pausedQuiet) {
                    audioService.speak(translated.spokenText, language: narrationLanguage)
                }
            } catch {
                statusBanner = "\(narrationLanguage.englishName) translation pack unavailable; narrating in English."
                if !touchModeEnabled && (phase == .active || phase == .pausedQuiet) {
                    audioService.speak(original.spokenText, language: .englishIndia)
                }
            }
        }
    }

    // MARK: - Privacy self-check

    private static func scanContainerForCoordinates() -> [PrivacyContainerFinding] {
        let fm = FileManager.default
        var dirs: [URL] = []
        for searchPath in [FileManager.SearchPathDirectory.documentDirectory, .libraryDirectory] {
            if let url = fm.urls(for: searchPath, in: .userDomainMask).first { dirs.append(url) }
        }
        dirs.append(fm.temporaryDirectory)
        return PrivacyContainerScanner.scanDirectories(dirs)
    }

}

/// Live walk numbers shown during the session (pedometer, or simulated in mock mode).
struct WalkLiveStats: Equatable, Sendable {
    var steps: Int
    var distanceMeters: Double
    static let zero = WalkLiveStats(steps: 0, distanceMeters: 0)
}
