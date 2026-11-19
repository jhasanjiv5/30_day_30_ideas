import EnsembleCore
import Foundation

#if canImport(FoundationModels)
import FoundationModels

@Generable
struct AppleIntelligenceRecapOutput {
    @Guide(description: "Spoiler-free catch-up summary under 60 words using only dialogue before the current timestamp.")
    var summary: String

    @Guide(description: "Up to 4 character names mentioned in the provided transcript.")
    var keyCharacters: [String]
}
#endif

/// Runs strictly ON THE IPHONE ONLY.
/// Always verifies `SystemLanguageModel.default.availability` and falls back to
/// `TemplateRecapGenerator` if Apple Intelligence is unavailable.
struct PhoneRecapService: Sendable {
    var appleIntelligenceStatusLabel: String {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            return "Apple Intelligence Ready"
        case .unavailable(.deviceNotEligible):
            return "Template Fallback (Device Ineligible)"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Template Fallback (Apple Intelligence Off)"
        case .unavailable(.modelNotReady):
            return "Template Fallback (Model Downloading)"
        case .unavailable:
            return "Template Fallback (Unavailable)"
        @unknown default:
            return "Template Fallback"
        }
        #else
        return "Template Fallback (SDK Unavailable)"
        #endif
    }

    func generateRecap(
        participantID: UUID,
        requesterName: String,
        window: SubtitleWindowPayload
    ) async -> RecapPayload {
        #if canImport(FoundationModels)
        if case .available = SystemLanguageModel.default.availability,
           !window.transcriptUpToNow.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            do {
                let session = LanguageModelSession(instructions: """
                    You are a concise movie catch-up assistant. Summarize ONLY what happened in the provided transcript excerpt so far.
                    Never invent future plot events. Keep the summary to 60 words or fewer.
                    """)
                let prompt = """
                    Film: \(window.filmTitle)
                    Current playback position: \(Int(window.currentTimeSeconds)) seconds.
                    Subtitles from 0s up to current moment:
                    \(window.transcriptUpToNow)
                    """
                let response = try await session.respond(
                    to: prompt,
                    generating: AppleIntelligenceRecapOutput.self
                )
                let clamped = TemplateRecapGenerator.clampToWordLimit(response.content.summary, maxWords: 60)
                return RecapPayload(
                    participantID: participantID,
                    requesterName: requesterName,
                    filmID: window.filmID,
                    summary: clamped,
                    keyCharacters: Array(response.content.keyCharacters.prefix(4)),
                    generatedOnDeviceWithAppleIntelligence: true
                )
            } catch {
                // Fall through cleanly to deterministic template fallback
            }
        }
        #endif

        // Deterministic template fallback when Apple Intelligence is unavailable or transcript is empty
        let fallbackCues = window.transcriptUpToNow
            .split(separator: "\n")
            .enumerated()
            .map { index, line in
                SubtitleCue(
                    id: index + 1,
                    startTime: 0,
                    endTime: window.currentTimeSeconds,
                    text: String(line)
                )
            }
        let template = TemplateRecapGenerator.generate(
            filmID: window.filmID,
            filmTitle: window.filmTitle,
            currentTimeSeconds: window.currentTimeSeconds,
            cues: fallbackCues
        )
        return RecapPayload(
            participantID: participantID,
            requesterName: requesterName,
            filmID: window.filmID,
            summary: template.summary,
            keyCharacters: template.keyCharacters,
            generatedOnDeviceWithAppleIntelligence: false
        )
    }
}
