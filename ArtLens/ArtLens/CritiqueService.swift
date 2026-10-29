import Foundation
import FoundationModels
import ImageIO
import UIKit

@MainActor
public final class CritiqueService {
    public static let shared = CritiqueService()

    private init() {}

    public func analyzeArtwork(image: UIImage, tier: AIModelTier) async throws -> ArtworkAnalysis {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw CritiqueServiceError.modelUnavailable(model.availability)
        }

        guard let cgImage = image.cgImage else {
            throw CritiqueServiceError.invalidImage
        }

        let session = LanguageModelSession(
            model: model,
            instructions: """
            You are an art tutor. Critique only visible features of the supplied artwork.
            Be specific, constructive, respectful, and transparent about uncertainty.
            Do not identify an artist or infer authorship. Do not claim copyright or
            legal clearance. Do not estimate sale prices or invent market comparisons.
            Do not claim to have searched the web. Scores are subjective visual
            impressions, not verified originality or legal-risk measurements.
            """
        )
        let prompt = Prompt {
            """
            Analyze this artwork image. Give a \(tier.promptStyle) critique.
            Assess the painting stage (choose exactly one: Sketch, Block-in, Color,
            Rendering, Final Polish), visible medium if reasonably apparent, focal
            point, value structure, balance and rhythm, and geometric guidance.
            Give one practical next step. Provide a subjective visual-distinctiveness
            score and visual-similarity caution score from 0 to 100; these are not
            web-verified originality or legal-risk scores. Give one short checklist
            item for each status: passed, attention, and pending. If uncertain, say so.
            """
            Attachment(cgImage, orientation: image.imageOrientation.cgImageOrientation)
        }
        let response = try await session.respond(to: prompt, generating: ArtworkCritiqueOutput.self)
        let result = response.content

        guard let stage = PaintingStage.allCases.first(where: {
            $0.rawValue.caseInsensitiveCompare(result.detectedStage.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
        }) else {
            throw CritiqueServiceError.invalidStage(result.detectedStage)
        }

        let distinctiveness = min(max(result.visualDistinctiveness, 0), 100)
        let similarityCaution = min(max(result.visualSimilarityCaution, 0), 100)
        let flaggedElements = result.flaggedVisualElements
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.isEmpty && $0.lowercased() != "none" }

        return ArtworkAnalysis(
            detectedStage: stage,
            stageConfidence: Double(min(max(result.stageConfidence, 0), 100)),
            medium: result.medium,
            valuation: CommercialValuation(
                estimatedMin: 0,
                estimatedMax: 0,
                formattedRange: "Not assessed",
                rationale: "A visual language model cannot establish market value without reliable sales comparables.",
                completedProjectedValuation: "Not assessed",
                marketComps: []
            ),
            kpi: KPIScores(
                noveltyScore: distinctiveness,
                ipRiskScore: similarityCaution,
                stageStatus: result.stageStatus
            ),
            actionableNextStep: result.actionableNextStep,
            webVisualMatches: [],
            detailedBreakdown: DetailedBreakdown(
                compositionCritique: CompositionCritique(
                    focalPointAnalysis: result.focalPointAnalysis,
                    valueStructure: result.valueStructure,
                    balanceAndRhythm: result.balanceAndRhythm,
                    geometricGuidance: result.geometricGuidance
                ),
                ipComplianceReport: IPComplianceReport(
                    verdict: "Visual-only assessment; this is not copyright or legal advice.",
                    flaggedElements: flaggedElements,
                    commercialSafetyAssessment: "Not assessed. No rights or commercial-use checks were performed.",
                    fairUseConsiderations: "Not assessed. Consult a qualified legal professional for rights questions."
                ),
                stageChecklist: [
                    ChecklistItem(item: result.passedItem, status: .passed, note: "Identified by on-device visual analysis."),
                    ChecklistItem(item: result.attentionItem, status: .attention, note: "Review this area in the artwork."),
                    ChecklistItem(item: result.pendingItem, status: .pending, note: "Suggested next step for the current stage.")
                ]
            )
        )
    }
}

private enum CritiqueServiceError: LocalizedError {
    case modelUnavailable(SystemLanguageModel.Availability)
    case invalidImage
    case invalidStage(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(.unavailable(.deviceNotEligible)):
            "This device does not support Apple Intelligence. Try a compatible iPhone or iPad."
        case .modelUnavailable(.unavailable(.appleIntelligenceNotEnabled)):
            "Turn on Apple Intelligence in Settings to analyze artwork."
        case .modelUnavailable(.unavailable(.modelNotReady)):
            "The Apple Intelligence model is not ready yet. Finish downloading it in Settings and try again."
        case .modelUnavailable(.available):
            "The Apple Intelligence model is unavailable right now. Try again shortly."
        case .invalidImage:
            "The captured image could not be read. Please capture the artwork again."
        case .invalidStage(let stage):
            "The analysis returned an unknown artwork stage (\(stage)). Please try again."
        default:
            "Apple Intelligence could not complete the analysis. Please try again."
        }
    }
}

@Generable
private struct ArtworkCritiqueOutput {
    @Guide(description: "Exactly one of: Sketch, Block-in, Color, Rendering, Final Polish.")
    var detectedStage: String
    @Guide(description: "Confidence from 0 to 100.")
    var stageConfidence: Int
    var medium: String
    @Guide(description: "Subjective visual distinctiveness from 0 to 100. Not web verified.")
    var visualDistinctiveness: Int
    @Guide(description: "Subjective visual similarity caution from 0 to 100. Not a legal risk score.")
    var visualSimilarityCaution: Int
    var stageStatus: String
    var actionableNextStep: String
    var focalPointAnalysis: String
    var valueStructure: String
    var balanceAndRhythm: String
    var geometricGuidance: String
    @Guide(description: "Visible elements that could benefit from rights review, one per line. Write None if there are none.")
    var flaggedVisualElements: String
    var passedItem: String
    var attentionItem: String
    var pendingItem: String
}

private extension UIImage.Orientation {
    var cgImageOrientation: CGImagePropertyOrientation {
        switch self {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .upMirrored: .upMirrored
        case .downMirrored: .downMirrored
        case .leftMirrored: .leftMirrored
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}

private extension AIModelTier {
    var promptStyle: String {
        switch self {
        case .budgetFlash:
            "a concise"
        case .balanced:
            "a balanced"
        case .deepReasoning:
            "a detailed, step-by-step"
        }
    }
}
