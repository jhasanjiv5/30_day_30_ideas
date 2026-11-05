import Foundation
import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
public final class OnDeviceReasoningModel: ObservableObject {
    @Published public private(set) var isThinking = false
    @Published public private(set) var streamedOutput = ""
    @Published public private(set) var isModelAvailable = false
    @Published public private(set) var availabilityMessage = ""
    @Published public private(set) var errorMessage: String?

    public init() {
        updateAvailability()
    }

    public func updateAvailability() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                isModelAvailable = true
                availabilityMessage = "Apple Foundation Models is ready on this device."
            case .unavailable(.deviceNotEligible):
                isModelAvailable = false
                availabilityMessage = "This device does not support Apple Intelligence Foundation Models."
            case .unavailable(.appleIntelligenceNotEnabled):
                isModelAvailable = false
                availabilityMessage = "Enable Apple Intelligence in Settings to use the on-device model."
            case .unavailable(.modelNotReady):
                isModelAvailable = false
                availabilityMessage = "The on-device model is not ready yet. Check Apple Intelligence setup and try again."
            @unknown default:
                isModelAvailable = false
                availabilityMessage = "Apple Foundation Models is currently unavailable."
            }
        } else {
            isModelAvailable = false
            availabilityMessage = "Apple Foundation Models requires iOS 26 or macOS 26 or later."
        }
        #else
        isModelAvailable = false
        availabilityMessage = "Apple Foundation Models is not available on this platform."
        #endif
    }

    public func generateStrategy(for business: BusinessProfile, query: String) async {
        guard !isThinking else { return }

        updateAvailability()
        streamedOutput = ""
        errorMessage = nil

        guard isModelAvailable else {
            errorMessage = availabilityMessage
            return
        }

        isThinking = true
        defer { isThinking = false }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let session = LanguageModelSession(
                instructions: """
                You are a practical social media strategist for small businesses.
                Generate concise, actionable content ideas using the supplied profile and request.
                Never suggest sharing a private home address, personal phone number, or identifying
                residential location. Do not invent business facts. Do not reveal private reasoning.
                """
            )
            let prompt = """
            Create a social media strategy for this business.

            Business: \(business.name)
            Industry: \(business.industry)
            Niche: \(business.niche)
            Audience: \(business.targetAudience)
            Unique selling proposition: \(business.usp)
            Brand voice: \(business.brandVoice)
            Home-based business: \(business.isHomeBased ? "Yes" : "No")
            Platforms: \(business.platforms.joined(separator: ", "))

            Request: \(query)

            Give a concise three-day starter cadence with a post concept, a safe hook, and a
            privacy-conscious call to action for each day.
            """

            do {
                for try await response in session.streamResponse(to: prompt) {
                    streamedOutput = response.content
                }
                if streamedOutput.isEmpty {
                    errorMessage = "The on-device model returned an empty response. Try again."
                }
            } catch {
                errorMessage = "Strategy generation failed: \(error.localizedDescription)"
            }
        }
        #endif
    }
}
