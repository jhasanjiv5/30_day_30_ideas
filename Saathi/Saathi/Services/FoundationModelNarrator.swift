import Foundation
import SaathiCore

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Fact-grounded narration engine backed by Apple's on-device `FoundationModels`.
/// Falls back cleanly to deterministic template narration built solely from retrieved facts
/// whenever `SystemLanguageModel.default` is unavailable or doesn't support the target locale.
@MainActor
final class FoundationModelNarrator {
    struct AvailabilityInfo: Sendable {
        let isAvailable: Bool
        let reason: String
        func supportsLocale(_ locale: Locale) -> Bool {
            #if canImport(FoundationModels)
            return SystemLanguageModel.default.supportsLocale(locale)
            #else
            return false
            #endif
        }
    }

    func checkAvailability() -> AvailabilityInfo {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            return AvailabilityInfo(isAvailable: true, reason: "On-device Apple Intelligence ready")
        case .unavailable(.deviceNotEligible):
            return AvailabilityInfo(isAvailable: false, reason: "Device not eligible for Apple Intelligence; using fact templates.")
        case .unavailable(.modelNotReady):
            return AvailabilityInfo(isAvailable: false, reason: "On-device model downloading; using fact templates.")
        case .unavailable(let other):
            return AvailabilityInfo(isAvailable: false, reason: "Model unavailable (\(other)); using fact templates.")
        @unknown default:
            return AvailabilityInfo(isAvailable: false, reason: "Model status unknown; using fact templates.")
        }
        #else
        return AvailabilityInfo(isAvailable: false, reason: "FoundationModels SDK unavailable; using fact templates.")
        #endif
    }

    func generateNarration(
        for rankedPlace: RankedPlace,
        memories: [PersonalMemoryItem],
        curatedNotice: CuratedNotice?,
        narrationLanguage: SaathiLanguage,
        userQuestion: String?,
        isUnprompted: Bool,
        areaFraming: String? = nil
    ) async -> NarrationSegment {
        let place = rankedPlace.place
        // Photos must be near this place; calendar and journaling items carry no location,
        // so they are general session context (previously they were silently dropped).
        let matchingMemories = memories.filter { mem in
            guard let coord = mem.approximateCoordinate else { return true }
            return coord.distanceMeters(to: place.coordinate) <= 300
        }

        #if canImport(FoundationModels)
        if !preferTemplateNarration, case .available = SystemLanguageModel.default.availability {
            let directLocaleSupported = SystemLanguageModel.default.supportsLocale(narrationLanguage.locale)
            let promptLanguage = directLocaleSupported ? narrationLanguage : .englishIndia

            let queryPrompt: String
            if let userQuestion, !userQuestion.isEmpty {
                queryPrompt = "Answer this visitor question about \(place.title) using only tool facts: \"\(userQuestion)\""
            } else if let areaFraming {
                // Quiet stretch between landmarks: talk about the wider area like a friend would.
                queryPrompt = "The visitor is walking between landmarks. Tell them about \(place.title), which is \(areaFraming), using only NearbyPlacesTool facts. Make clear it is not right here. No follow-up question."
            } else {
                queryPrompt = "Narrate \(place.title) (~ \(Int(rankedPlace.distanceMeters)) meters away) using NearbyPlacesTool and any matching PersonalMemoriesTool item. Include one brief optional follow-up prompt like 'Want the full story?'"
            }

            // A guide that goes silent is worse than a plainer one: cap the model call and
            // fall back to the fact template if it is slow or fails.
            if let output = try? await Self.withTimeout(seconds: modelTimeoutSeconds, operation: {
                try await Self.modelNarration(
                    place: place,
                    memories: matchingMemories,
                    curatedNotice: curatedNotice,
                    promptLanguage: promptLanguage,
                    prompt: queryPrompt
                )
            }) {
                return NarrationSegment(
                    placeID: place.id,
                    placeTitle: place.title,
                    spokenText: output.spoken,
                    captionText: output.spoken,
                    followUpPrompt: areaFraming == nil ? output.followUp : nil,
                    citations: place.citations + (curatedNotice.map { [$0.citation] } ?? []),
                    referencedMemoryIDs: matchingMemories.map(\.id),
                    languageCode: promptLanguage.rawValue,
                    isUnprompted: isUnprompted
                )
            }
        }
        #endif

        return templateNarration(
            place: place,
            distanceMeters: rankedPlace.distanceMeters,
            memories: areaFraming == nil ? matchingMemories : [],
            curatedNotice: curatedNotice,
            language: narrationLanguage,
            userQuestion: userQuestion,
            isUnprompted: isUnprompted,
            areaFraming: areaFraming
        )
    }

    /// Mock mode uses the deterministic template so demos and UI tests are reproducible
    /// and don't depend on whether the host Mac exposes Apple Intelligence to the simulator.
    var preferTemplateNarration = false
    var modelTimeoutSeconds: Double = 8

    struct ModelOutput: Sendable {
        let spoken: String
        let followUp: String?
    }

    private nonisolated static func withTimeout<T: Sendable>(
        seconds: Double,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw CancellationError()
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw CancellationError() }
            return first
        }
    }

    #if canImport(FoundationModels)
    private nonisolated static func modelNarration(
        place: PlaceCandidate,
        memories: [PersonalMemoryItem],
        curatedNotice: CuratedNotice?,
        promptLanguage: SaathiLanguage,
        prompt: String
    ) async throws -> ModelOutput {
        let session = LanguageModelSession(
            tools: [
                NearbyPlacesTool(places: [place]),
                PersonalMemoriesTool(memories: memories),
                CuratedNoticeTool(notice: curatedNotice)
            ],
            instructions: """
            You are Saathi, a warm, concise audio companion for historic places.
            STRICT RULES:
            1. State ONLY facts returned by your tools (NearbyPlacesTool, PersonalMemoriesTool, CuratedNoticeTool).
            2. Never invent dates, rulers, dimensions, or stories from memory.
            3. If a user asks something not covered by tool facts, respond exactly: "I don't have a source for that."
            4. Keep spoken narration between 20 and 60 seconds (55 to 120 words).
            5. Preserve all proper place names, numbers, and dates accurately.
            6. Write in \(promptLanguage.englishName).
            """
        )
        let output = try await session.respond(to: prompt, generating: GeneratedNarrationOutput.self).content
        return ModelOutput(spoken: output.spokenNarration, followUp: output.followUpQuestion)
    }
    #endif

    private func templateNarration(
        place: PlaceCandidate,
        distanceMeters: Double,
        memories: [PersonalMemoryItem],
        curatedNotice: CuratedNotice?,
        language: SaathiLanguage,
        userQuestion: String?,
        isUnprompted: Bool,
        areaFraming: String? = nil
    ) -> NarrationSegment {
        if let question = userQuestion,
           !question.isEmpty,
           !question.localizedCaseInsensitiveContains("photo"),
           !question.localizedCaseInsensitiveContains("where"),
           !place.summary.localizedCaseInsensitiveContains(question.split(separator: " ").first ?? "") {
            // English source string; translated downstream like every other English segment.
            let noSource = "I don't have a source for that."
            return NarrationSegment(
                placeID: place.id,
                placeTitle: place.title,
                spokenText: noSource,
                captionText: noSource,
                followUpPrompt: nil,
                citations: place.citations,
                languageCode: SaathiLanguage.englishIndia.rawValue,
                isUnprompted: false
            )
        }

        // If the source article is already in the narration language (e.g. hi.wikipedia.org),
        // keep the template free of English words so it needs no translation.
        let summaryInNarrationLanguage = place.sourceLanguageCode == language.baseLanguageCode
            && language != .englishIndia
            && areaFraming == nil // the framing is English, so the whole segment is translated
        var parts: [String]
        if let areaFraming {
            parts = ["Around you: \(place.title), \(areaFraming). \(place.summary)"]
        } else if summaryInNarrationLanguage {
            parts = ["\(place.title). \(place.summary)"]
        } else {
            parts = ["\(place.title) (\(Int(distanceMeters)) m away). \(place.summary)"]
        }
        if let firstMem = memories.first, !summaryInNarrationLanguage {
            parts.append("Your memory here: \(firstMem.detail)")
        }
        if let notice = curatedNotice {
            parts.append("Local notice: \(notice.headline) — \(notice.summary)")
        }
        let combined = parts.joined(separator: " ")

        // Template text is English; label it honestly so the coordinator translates it
        // instead of handing English text to a Hindi/Tamil/... voice.
        return NarrationSegment(
            placeID: place.id,
            placeTitle: place.title,
            spokenText: combined,
            captionText: combined,
            followUpPrompt: areaFraming == nil ? "Want the full story?" : nil,
            citations: place.citations + (curatedNotice.map { [$0.citation] } ?? []),
            referencedMemoryIDs: summaryInNarrationLanguage ? [] : memories.map(\.id),
            languageCode: summaryInNarrationLanguage ? language.rawValue : SaathiLanguage.englishIndia.rawValue,
            isUnprompted: isUnprompted
        )
    }
}

#if canImport(FoundationModels)
@Generable
struct GeneratedNarrationOutput {
    @Guide(description: "20-60 second conversational audio narration strictly grounded in retrieved facts.")
    var spokenNarration: String

    @Guide(description: "Short optional yes/no question for head gesture confirmation, e.g. 'Want the full story?'.")
    var followUpQuestion: String?
}

struct NearbyPlacesTool: Tool {
    let places: [PlaceCandidate]
    var name: String { "nearbyPlaces" }
    var description: String { "Returns verified Wikipedia, Wikidata, and OpenStreetMap facts for nearby historic places." }

    @Generable
    struct Arguments: Codable {
        @Guide(description: "Place title or 'all' to retrieve verified facts.")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        let matching = places.filter {
            arguments.query.lowercased() == "all" || $0.title.localizedCaseInsensitiveContains(arguments.query)
        }
        let target = matching.isEmpty ? places : matching
        let text = target.map { place in
            let sources = place.citations.map(\.provider.rawValue).joined(separator: ", ")
            return "\(place.title): \(place.summary) [Sources: \(sources)]"
        }.joined(separator: "\n")
        return text.isEmpty ? "No nearby verified places found." : text
    }
}

struct PersonalMemoriesTool: Tool {
    let memories: [PersonalMemoryItem]
    var name: String { "personalMemories" }
    var description: String { "Returns user-opted-in on-device Photos, Calendar, and Journaling items near the current stop." }

    @Generable
    struct Arguments: Codable {
        @Guide(description: "Filter kind: 'all', 'photo', 'calendar', or 'journal'.")
        var kind: String
    }

    func call(arguments: Arguments) async throws -> String {
        if memories.isEmpty {
            return "No opted-in personal memories matched this stop."
        }
        let text = memories.map { "\($0.kind.rawValue): \($0.title) — \($0.detail)" }.joined(separator: "\n")
        return text
    }
}

struct CuratedNoticeTool: Tool {
    let notice: CuratedNotice?
    var name: String { "curatedNotice" }
    var description: String { "Returns optional curated local heritage notice if enabled." }

    @Generable
    struct Arguments: Codable {
        var check: Bool
    }

    func call(arguments: Arguments) async throws -> String {
        guard let notice else { return "No active curated local notice." }
        return "\(notice.headline): \(notice.summary) [Source: \(notice.citation.title)]"
    }
}
#endif
