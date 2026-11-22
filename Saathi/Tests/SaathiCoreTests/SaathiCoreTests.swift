import Foundation
import Testing
@testable import SaathiCore

@Suite("SaathiCore Engine & Multilingual Tests")
struct SaathiCoreTests {

    @Test("Grid snapping outputs deterministic ~250m tile centre never more precise than tile")
    func testGridSnappingPrecision() {
        let preciseA = EphemeralCoordinate(latitude: 15.3425192, longitude: 76.4756128)
        let preciseB = EphemeralCoordinate(latitude: 15.3425987, longitude: 76.4756999)

        let tileA = GeoTileSnapper.snap(preciseA, tileSizeMeters: 250)
        let tileB = GeoTileSnapper.snap(preciseB, tileSizeMeters: 250)

        #expect(tileA == tileB)
        // Tile centre must stay >0m away from exact raw coordinate when points vary inside tile,
        // and rounded to at most 4 decimal places.
        let latDecimals = String(tileA.centerLatitude).split(separator: ".").last?.count ?? 0
        let lonDecimals = String(tileA.centerLongitude).split(separator: ".").last?.count ?? 0
        #expect(latDecimals <= 4)
        #expect(lonDecimals <= 4)
    }

    @Test("Ranker combines distance decay, sitelinks notability, interest, novelty, and >45s dwell boost")
    func testRankerScoringAndDwellBoost() {
        let user = EphemeralCoordinate(latitude: 15.3425, longitude: 76.4756)
        let tile = GeoTileSnapper.snap(user)
        let places = MockFixtures.hampiPlaces(tileID: tile.id, lang: .englishIndia)

        var profile = SessionInterestProfile()
        profile.recordAskedAbout(tags: ["temple", "vijayanagara"])

        let shortDwell = PlaceRanker.rank(
            candidates: places,
            userCoordinate: user,
            interestProfile: profile,
            dwellDurationSeconds: 10
        )
        let longDwell = PlaceRanker.rank(
            candidates: places,
            userCoordinate: user,
            interestProfile: profile,
            dwellDurationSeconds: 60
        )

        #expect(shortDwell.count == 2)
        #expect(longDwell[0].breakdown.dwellComponent > 0)
        #expect(longDwell[0].score > shortDwell[0].score)

        // Marking top place as skipped drops its novelty and moves the second place ahead
        profile.recordSkipped(placeID: longDwell[0].place.id, tags: longDwell[0].place.tags)
        let afterSkip = PlaceRanker.rank(
            candidates: places,
            userCoordinate: user,
            interestProfile: profile,
            dwellDurationSeconds: 60
        )
        #expect(afterSkip.first?.place.id == places[1].id)
    }

    @Test("Interruption budget limits unprompted segments to <=1 per 3 min, gates speech, and honours quiet")
    func testInterruptionBudget() {
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        var budget = InterruptionBudget(minIntervalSeconds: 180)

        #expect(budget.canDeliverUnpromptedSegment(at: t0))

        budget.recordUnpromptedDelivery(at: t0)
        #expect(!budget.canDeliverUnpromptedSegment(at: t0.addingTimeInterval(60)))
        #expect(!budget.canDeliverUnpromptedSegment(at: t0.addingTimeInterval(179)))
        #expect(budget.canDeliverUnpromptedSegment(at: t0.addingTimeInterval(180)))

        // Speaking blocks unprompted delivery
        budget.setUserSpeaking(true)
        #expect(!budget.canDeliverUnpromptedSegment(at: t0.addingTimeInterval(240)))
        budget.setUserSpeaking(false)

        // Quiet for 20 minutes blocks until expiry
        budget.requestQuiet(minutes: 20, now: t0.addingTimeInterval(240))
        #expect(!budget.canDeliverUnpromptedSegment(at: t0.addingTimeInterval(240 + 600)))
        #expect(budget.canDeliverUnpromptedSegment(at: t0.addingTimeInterval(240 + 1200)))
    }

    @Test("Episode builder contains zero coordinates and preserves citations and PhotoKit IDs")
    func testEpisodeBuilderContainsZeroCoordinates() {
        let cite = FactCitation(
            provider: .wikipedia,
            title: "Vittala Temple, Hampi",
            urlString: "https://en.wikipedia.org/wiki/Vittala_Temple,_Hampi",
            languageCode: "en"
        )
        let segment = NarrationSegment(
            placeID: "hampi_stone_chariot",
            placeTitle: "Stone Chariot, Vittala Temple",
            spokenText: "Built in the 16th century under Krishnadevaraya near 15.3425, 76.4756.",
            captionText: "Built in the 16th century.",
            citations: [cite],
            referencedMemoryIDs: ["mem_photo_hampi_01"],
            languageCode: "en-IN",
            isUnprompted: true
        )
        let memories = MockFixtures.samplePersonalMemories()
        let episode = EpisodeBuilder.build(
            segments: [segment],
            referencedMemories: memories,
            language: .englishIndia
        )

        #expect(!episode.stops.isEmpty)
        #expect(!episode.stops[0].citations.isEmpty)
        #expect(episode.linkedPhotoLocalIdentifiers.contains("MOCK-PHASSET-HAMPI-001"))

        let encoder = JSONEncoder()
        let data = try! encoder.encode(episode)
        let serialized = String(data: data, encoding: .utf8)!
        #expect(PrivacyContainerScanner.containsCoordinateLeak(in: serialized) == nil)
    }

    @Test("Capability matrix selects expected pipeline per mocked language runtime signals")
    func testCapabilityMatrixSelection() {
        let fullSignals = LanguageRuntimeSignals(
            speechAnalyzerInstalled: true,
            speechAnalyzerSupported: true,
            legacySpeechRecognizerAvailable: true,
            foundationModelAvailable: true,
            foundationModelSupportsLocale: true,
            translationStatus: .notNeeded,
            hasEnhancedOrPremiumTTSVoice: true,
            hasAnyTTSVoice: true
        )
        let enCap = CapabilityMatrixEvaluator.evaluate(language: .englishIndia, signals: fullSignals)
        #expect(enCap.badge == .fullVoice)
        #expect(enCap.speechBackend == .speechAnalyzer)
        #expect(enCap.modelPath == .directOnDevice)

        let translatedSignals = LanguageRuntimeSignals(
            speechAnalyzerInstalled: false,
            speechAnalyzerSupported: false,
            legacySpeechRecognizerAvailable: true,
            foundationModelAvailable: true,
            foundationModelSupportsLocale: false,
            translationStatus: .downloadableWithConsent,
            hasEnhancedOrPremiumTTSVoice: false,
            hasAnyTTSVoice: true
        )
        let taCap = CapabilityMatrixEvaluator.evaluate(language: .tamil, signals: translatedSignals)
        #expect(taCap.badge == .translated)
        #expect(taCap.speechBackend == .sfSpeechRecognizer)
        #expect(taCap.modelPath == .englishThenOnDeviceTranslation)
        #expect(taCap.needsTranslationDownloadConsent)

        let captionsOnlySignals = LanguageRuntimeSignals(
            speechAnalyzerInstalled: false,
            speechAnalyzerSupported: false,
            legacySpeechRecognizerAvailable: false,
            foundationModelAvailable: false,
            foundationModelSupportsLocale: false,
            translationStatus: .unsupported,
            hasEnhancedOrPremiumTTSVoice: false,
            hasAnyTTSVoice: false
        )
        let orCap = CapabilityMatrixEvaluator.evaluate(language: .odia, signals: captionsOnlySignals)
        #expect(orCap.badge == .captionsOnly)
        #expect(orCap.speechBackend == .touchOnly)
        #expect(orCap.voicePath == .captionsOnly)
    }

    @Test("Translation guard preserves proper names, numbers, and dates for English to Hindi and Tamil")
    func testTranslationGuardPreservesProperNamesAndNumbers() {
        let source = "In 1534, Krishnadevaraya expanded Vittala Temple in Hampi with 56 granite pillars."
        let protected = TranslationGuard.protect(
            text: source,
            properNames: ["Vittala", "Hampi", "Krishnadevaraya"]
        )

        // Simulated translated sentence with placeholders and localized digits
        let simulatedHindi = "१५३४ में __SAATHI_NAME_2__ ने __SAATHI_NAME_1__ में __SAATHI_NAME_0__ का विस्तार किया (56 स्तंभ)।"
        let restoredHindi = TranslationGuard.restore(
            translatedText: simulatedHindi,
            context: protected,
            targetLanguage: .hindi
        )

        #expect(restoredHindi.contains("Vittala"))
        #expect(restoredHindi.contains("Hampi"))
        #expect(restoredHindi.contains("Krishnadevaraya"))
        #expect(TranslationGuard.convertIndicDigitsToASCII(restoredHindi).contains("1534"))
        #expect(restoredHindi.contains("56"))
    }

    @Test("Voice command grammar parses Hindi, Hinglish, and English fallback commands")
    func testVoiceCommandGrammarHindiAndHinglish() {
        #expect(VoiceCommandGrammar.parse("aur batao", language: .hindi) == .tellMeMore)
        #expect(VoiceCommandGrammar.parse("chup 15 minute", language: .hinglish) == .quiet(minutes: 15))
        #expect(VoiceCommandGrammar.parse("baad mein", language: .hindi) == .quiet(minutes: 20))
        #expect(VoiceCommandGrammar.parse("yahan kya photo li", language: .hinglish) == .whatDidIPhotographHere)
        #expect(VoiceCommandGrammar.parse("band karo", language: .hindi) == .endSession)
        #expect(VoiceCommandGrammar.parse("skip", language: .tamil) == .skip)
    }
}

@Suite("Open-ended walk: end detection, walk summary, episode")
struct WalkSessionTests {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let settings = WalkEndDetector.Settings(
        stationaryAskAfterSeconds: 600,
        vehicleAskAfterSeconds: 120,
        autoEndAfterAskSeconds: 300,
        maxSessionSeconds: 6 * 3600
    )

    @Test("Apple Watch / iPhone workout ending ends the walk immediately")
    func workoutEndEndsWalk() {
        var detector = WalkEndDetector(sessionStart: start, settings: settings)
        #expect(detector.recordWorkoutEnded() == .end(.workoutEnded))
    }

    @Test("Walking keeps going; a short pause at a monument does not end the walk")
    func shortPauseKeepsGoing() {
        var detector = WalkEndDetector(sessionStart: start, settings: settings)
        detector.recordMotion(.walking, at: start)
        detector.recordMotion(.stationary, at: start.addingTimeInterval(60))
        #expect(detector.evaluate(at: start.addingTimeInterval(60 + 300)) == .keepGoing)
    }

    @Test("Long stationary stretch asks first, then ends if nobody answers")
    func stationaryAsksThenEnds() {
        var detector = WalkEndDetector(sessionStart: start, settings: settings)
        detector.recordMotion(.stationary, at: start)
        #expect(detector.evaluate(at: start.addingTimeInterval(599)) == .keepGoing)
        #expect(detector.evaluate(at: start.addingTimeInterval(600)) == .askToWrapUp(.stoppedMoving))
        #expect(detector.evaluate(at: start.addingTimeInterval(700)) == .keepGoing)
        #expect(detector.evaluate(at: start.addingTimeInterval(900)) == .end(.stoppedMoving))
    }

    @Test("Walking again cancels the pending wrap-up question")
    func walkingCancelsQuestion() {
        var detector = WalkEndDetector(sessionStart: start, settings: settings)
        detector.recordMotion(.stationary, at: start)
        #expect(detector.evaluate(at: start.addingTimeInterval(600)) == .askToWrapUp(.stoppedMoving))
        detector.recordMotion(.walking, at: start.addingTimeInterval(650))
        #expect(!detector.isAwaitingWrapUpAnswer)
        #expect(detector.evaluate(at: start.addingTimeInterval(1_000)) == .keepGoing)
    }

    @Test("Getting into a vehicle asks sooner")
    func vehicleAsksSooner() {
        var detector = WalkEndDetector(sessionStart: start, settings: settings)
        detector.recordMotion(.automotive, at: start)
        #expect(detector.evaluate(at: start.addingTimeInterval(120)) == .askToWrapUp(.leftByVehicle))
    }

    @Test("Saying no snoozes the question; an active workout suppresses the stationary rule")
    func declineAndWorkoutActive() {
        var detector = WalkEndDetector(sessionStart: start, settings: settings)
        detector.recordMotion(.stationary, at: start)
        _ = detector.evaluate(at: start.addingTimeInterval(600))
        detector.userDeclinedWrapUp(at: start.addingTimeInterval(610))
        #expect(detector.evaluate(at: start.addingTimeInterval(1_000)) == .keepGoing)

        var withWorkout = WalkEndDetector(sessionStart: start, settings: settings)
        withWorkout.setWorkoutActive(true)
        withWorkout.recordMotion(.stationary, at: start)
        #expect(withWorkout.evaluate(at: start.addingTimeInterval(3_000)) == .keepGoing)
    }

    @Test("Safety cap ends the walk so location never runs indefinitely")
    func safetyCap() {
        var detector = WalkEndDetector(sessionStart: start, settings: settings)
        detector.recordMotion(.walking, at: start)
        #expect(detector.evaluate(at: start.addingTimeInterval(6 * 3600)) == .end(.safetyCap))
    }

    @Test("Walk summary reads naturally and the episode carries it without coordinates")
    func summaryInEpisode() throws {
        let summary = WalkSummary(
            startedAt: start,
            endedAt: start.addingTimeInterval(95 * 60),
            source: .appleWatchWorkout,
            distanceMeters: 4_230,
            steps: 6_120,
            activeEnergyKilocalories: 310,
            elevationGainMeters: 38,
            endReason: .workoutEnded
        )
        let spoken = summary.spokenSummary()
        #expect(spoken.contains("4.2 kilometres"))
        #expect(spoken.contains("1 hour 35 minutes"))
        #expect(spoken.contains("climbing 38 metres"))
        #expect(spoken.contains("Apple Watch"))

        let segment = NarrationSegment(
            placeID: "p1", placeTitle: "Stone Chariot", spokenText: "A 16th-century shrine.",
            captionText: "A 16th-century shrine.", citations: [], languageCode: "en-IN", isUnprompted: true
        )
        let episode = EpisodeBuilder.build(
            segments: [segment], referencedMemories: [], language: .englishIndia,
            sessionDate: start, walkSummary: summary
        )
        #expect(episode.walkSummary == summary)
        #expect(episode.script.contains("4.2 kilometres"))
        let json = String(data: try JSONEncoder().encode(episode), encoding: .utf8)!
        #expect(PrivacyContainerScanner.containsCoordinateLeak(in: json) == nil)
    }

    @Test("Compass phrasing for places farther away")
    func compassPhrasing() {
        #expect(CompassDirection.spoken(bearingDegrees: 0) == "north")
        #expect(CompassDirection.spoken(bearingDegrees: 44) == "north-east")
        #expect(CompassDirection.spoken(bearingDegrees: 350) == "north")
        #expect(CompassDirection.spoken(bearingDegrees: 225) == "south-west")
        #expect(CompassDirection.spokenDistance(meters: 420) == "about 400 metres")
        #expect(CompassDirection.spokenDistance(meters: 2_340) == "about 2.3 kilometres")
    }
}
