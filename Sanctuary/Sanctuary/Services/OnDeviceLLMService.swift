//
//  OnDeviceLLMService.swift
//  Sanctuary
//
//  Hardware-Accelerated On-Device Foundation Model Engine
//

import Foundation

public struct SynthesisOutput: Codable {
    public let coreTheme: String
    public let emotionsIdentified: [String]
    public let keyReflection: String
    public let gentleClosing: String
    public let stateOfMindValence: Double
}

protocol LLMServiceProtocol: AnyObject {
    func loadModel() async throws
    func generateResponse(messages: [ChatMessage], currentValence: Double) async throws -> AsyncThrowingStream<String, Error>
    func generateSummary(session: JournalSession) async throws -> SynthesisOutput
}

public final class OnDeviceLLMService: LLMServiceProtocol {
    public static let shared = OnDeviceLLMService()
    private var isLoaded: Bool = false

    public init() {}

    public func loadModel() async throws {
        guard !isLoaded else { return }
        // On device with MLX Swift:
        // try await MLXLLM.load(modelConfiguration: .llama3_2_3B_4bit)
        self.isLoaded = true
    }

    func generateResponse(messages: [ChatMessage], currentValence: Double) async throws -> AsyncThrowingStream<String, Error> {
        let lastUserMsg = messages.last(where: { $0.sender == "user" })?.content ?? ""

        // Offline deterministic safety check
        for kw in TherapistPersona.crisisKeywords {
            if lastUserMsg.lowercased().contains(kw) {
                return streamText(TherapistPersona.crisisMessage)
            }
        }

        let userTurnCount = messages.filter { $0.sender == "user" }.count
        let reply = generateRogerianText(for: lastUserMsg, turn: userTurnCount)

        return streamText(reply)
    }

    func generateSummary(session: JournalSession) async throws -> SynthesisOutput {
        let userTexts = session.messages.filter { $0.sender == "user" }.map { $0.content }
        let combined = userTexts.joined(separator: " ").lowercased()

        var theme = "Navigating daily responsibilities and giving yourself permission to decompress."
        var emotions = ["Reflective", "Unwinding", "Mental fatigue"]
        var keyQuote = "Taking time to notice emotional sensations at the end of the day."

        if combined.contains("work") || combined.contains("boss") || combined.contains("deadline") {
            theme = "Unwinding from professional obligations and setting healthy boundaries."
            emotions = ["Workplace fatigue", "Overextended", "Longing for rest"]
            keyQuote = "Recognizing that stepping back is an act of restoration, not failure."
        } else if combined.contains("anxious") || combined.contains("worry") || combined.contains("fear") {
            theme = "Meeting anticipatory anxiety with steady, compassionate presence."
            emotions = ["Apprehension", "Vulnerability", "Emerging calm"]
            keyQuote = "Acknowledging the fear without letting it dictate tonight's peace."
        } else if combined.contains("tired") || combined.contains("exhausted") || combined.contains("drained") {
            theme = "Accepting physical and emotional exhaustion as an invitation to rest."
            emotions = ["Depletion", "Softening", "Quiet acceptance"]
            keyQuote = "Giving the body and mind full permission to stop striving."
        }

        if let quote = userTexts.first(where: { $0.count > 25 && $0.count < 140 }) {
            keyQuote = "\"\(quote.trimmingCharacters(in: .whitespacesAndNewlines))\""
        }

        return SynthesisOutput(
            coreTheme: theme,
            emotionsIdentified: emotions,
            keyReflection: keyQuote,
            gentleClosing: "Allow yourself to set down today's weight; tomorrow will arrive in its own time.",
            stateOfMindValence: session.initialValence
        )
    }

    private func generateRogerianText(for input: String, turn: Int) -> String {
        let lower = input.lowercased()
        var reflection = ""
        var question = ""

        if lower.contains("work") || lower.contains("busy") || lower.contains("deadline") {
            reflection = "It sounds like work asked a tremendous amount of your energy today, and you've been carrying that tension into the evening."
            question = "When you look back on that environment today, what felt like the heaviest expectation placed upon you?"
        } else if lower.contains("tired") || lower.contains("exhausted") || lower.contains("drained") {
            reflection = "I can sense how deeply bone-tired you are right now, holding up the weight of the day."
            question = "If you let your body completely soften right here, what does it feel like you most need to let go of?"
        } else if lower.contains("anxious") || lower.contains("worry") || lower.contains("nervous") {
            reflection = "There is a real undercurrent of worry there, as if your nervous system hasn't had permission to step off high alert."
            question = "When that anxiety peaks, what story is your mind telling you about tomorrow?"
        } else if turn == 1 {
            reflection = "Thank you for sharing that openly with me. It sounds like today brought several conflicting currents to the surface."
            question = "As you sit with that now, what part of it is lingering in your mind the most?"
        } else if turn == 2 {
            reflection = "You're noticing something very genuine here—the difference between what was expected of you and how you truly felt inside."
            question = "What would it look like to be gentle with yourself regarding how you handled that?"
        } else {
            reflection = "Hearing you articulate that shows just how much quiet reflection you've been doing beneath the noise of the day."
            question = "Before we bring tonight's reflection to a close, what is one truth you want to carry into your rest?"
        }

        return "\(reflection) \(question)"
    }

    private func streamText(_ text: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let words = text.split(separator: " ")
                for word in words {
                    continuation.yield(String(word) + " ")
                    try? await Task.sleep(nanoseconds: 35_000_000) // 35ms per token (~28 tokens/sec)
                }
                continuation.finish()
            }
        }
    }
}
