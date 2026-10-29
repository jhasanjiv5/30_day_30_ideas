//
//  ArtworkAnalysis.swift
//  ArtLens
//
//  Created for iOS 17.0+ / Swift Observation
//  Complete Codable data models for Stage-Aware Artistic Critique, Originality, IP, and Valuation
//

import Foundation

/// Detected artistic progression stages
public enum PaintingStage: String, CaseIterable, Codable {
    case sketch = "Sketch"
    case blockIn = "Block-in"
    case color = "Color"
    case rendering = "Rendering"
    case finalPolish = "Final Polish"
    
    public var stageIndex: Int {
        switch self {
        case .sketch: return 1
        case .blockIn: return 2
        case .color: return 3
        case .rendering: return 4
        case .finalPolish: return 5
        }
    }
    
    public var stageScopeNote: String {
        switch self {
        case .sketch:
            return "Evaluating composition, proportions, perspective & linear gestures only."
        case .blockIn:
            return "Evaluating 2–3 tonal values, silhouette clarity, and mass structure."
        case .color:
            return "Evaluating palette gamut, warm/cool balance, and ambient occlusion."
        case .rendering:
            return "Evaluating edge transitions (hard/soft/lost), form turning & surface texture."
        case .finalPolish:
            return "Evaluating visual hierarchy, focal sharpening, contrast punch & varnishing."
        }
    }
}

/// Comprehensive analysis payload returned by the vision critique engine
public struct ArtworkAnalysis: Codable, Identifiable {
    public var id: UUID = UUID()
    public let timestamp: Date
    public let detectedStage: PaintingStage
    public let stageConfidence: Double // 0 - 100
    public let medium: String // e.g. "Oil on Linen", "Digital Illustration", "Watercolor"
    public let valuation: CommercialValuation
    public let kpi: KPIScores
    public let actionableNextStep: String
    public let webVisualMatches: [WebVisualMatch]
    public let detailedBreakdown: DetailedBreakdown
    
    public init(
        timestamp: Date = Date(),
        detectedStage: PaintingStage,
        stageConfidence: Double,
        medium: String,
        valuation: CommercialValuation,
        kpi: KPIScores,
        actionableNextStep: String,
        webVisualMatches: [WebVisualMatch],
        detailedBreakdown: DetailedBreakdown
    ) {
        self.timestamp = timestamp
        self.detectedStage = detectedStage
        self.stageConfidence = stageConfidence
        self.medium = medium
        self.valuation = valuation
        self.kpi = kpi
        self.actionableNextStep = actionableNextStep
        self.webVisualMatches = webVisualMatches
        self.detailedBreakdown = detailedBreakdown
    }
}

/// Commercial market pricing and historical auction comps
public struct CommercialValuation: Codable {
    public let estimatedMin: Double
    public let estimatedMax: Double
    public let formattedRange: String // e.g. "$550 – $850"
    public let rationale: String
    public let completedProjectedValuation: String // e.g. "$1,800 – $2,600"
    public let marketComps: [MarketComp]
    
    public init(
        estimatedMin: Double,
        estimatedMax: Double,
        formattedRange: String,
        rationale: String,
        completedProjectedValuation: String,
        marketComps: [MarketComp] = []
    ) {
        self.estimatedMin = estimatedMin
        self.estimatedMax = estimatedMax
        self.formattedRange = formattedRange
        self.rationale = rationale
        self.completedProjectedValuation = completedProjectedValuation
        self.marketComps = marketComps
    }
}

public struct MarketComp: Codable, Identifiable {
    public var id: String { referenceArt }
    public let referenceArt: String
    public let price: String
    public let marketplace: String
}

/// Top-level KPI metrics displayed in the 3 Apple-styled capsules
public struct KPIScores: Codable {
    public let noveltyScore: Int       // 0–100% (Derived from 100 - highest online similarity)
    public let ipRiskScore: Int        // 0–100% (0 = safe, 100 = blatant copyright infringement)
    public let stageStatus: String     // e.g. "Values Locked", "Needs Proportion Fix", "Ready for Polish"
    
    public var isOriginalWork: Bool {
        noveltyScore >= 75
    }
    
    public var ipStatusCategory: String {
        if ipRiskScore <= 15 {
            return "Clear"
        } else if ipRiskScore <= 50 {
            return "Caution"
        } else {
            return "Infringement Flag"
        }
    }
}

/// Web visual similarity matches from reverse image lookup
public struct WebVisualMatch: Codable, Identifiable {
    public var id: String { title + artistOrSource }
    public let title: String
    public let artistOrSource: String
    public let similarityPercent: Int
    public let matchCategory: String  // e.g. "Composition", "Palette", "Stylistic", "Subject"
    public let provenanceSummary: String
    public let thumbnailURL: String?
}

/// Deep dive report sections
public struct DetailedBreakdown: Codable {
    public let compositionCritique: CompositionCritique
    public let ipComplianceReport: IPComplianceReport
    public let stageChecklist: [ChecklistItem]
}

public struct CompositionCritique: Codable {
    public let focalPointAnalysis: String
    public let valueStructure: String
    public let balanceAndRhythm: String
    public let geometricGuidance: String
}

public struct IPComplianceReport: Codable {
    public let verdict: String
    public let flaggedElements: [String]
    public let commercialSafetyAssessment: String
    public let fairUseConsiderations: String
}

public struct ChecklistItem: Codable, Identifiable {
    public var id: String { item }
    public let item: String
    public let status: ChecklistStatus // passed, attention, pending
    public let note: String
}

public enum ChecklistStatus: String, Codable {
    case passed = "passed"
    case attention = "attention"
    case pending = "pending"
}
