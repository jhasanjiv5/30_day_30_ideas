//
//  AIModelTier.swift
//  ArtLens
//
//  Created for iOS 17.0+ / Swift 5.9+
//  Stage-Aware Visual Intelligence Cost & Quality Selector
//

import SwiftUI

/// Selects how detailed the on-device critique should be.
public enum AIModelTier: String, CaseIterable, Identifiable, Codable {
    case budgetFlash = "budget_flash"
    case balanced = "balanced"
    case deepReasoning = "deep_reasoning"
    
    public var id: String { rawValue }
    
    /// Display name rendered in the floating glass capsule and picker menu
    public var displayName: String {
        switch self {
        case .budgetFlash:
            return "Flash"
        case .balanced:
            return "Balanced"
        case .deepReasoning:
            return "Deep Reasoning"
        }
    }
    
    /// Short label for the minimalist viewfinder pill
    public var capsuleTitle: String {
        switch self {
        case .budgetFlash:
            return "⚡ Quick • On-device"
        case .balanced:
            return "⚖️ Balanced • On-device"
        case .deepReasoning:
            return "🧠 Detailed • On-device"
        }
    }
    
    /// There is no per-scan API charge for on-device analysis.
    public var costPerScan: Double {
        0
    }
    
    /// Processing description for the selected reasoning style.
    public var costDescription: String {
        "On-device · no API charge"
    }
    
    /// SF Symbol icon name
    public var systemIcon: String {
        switch self {
        case .budgetFlash:
            return "bolt.fill"
        case .balanced:
            return "scale.3d"
        case .deepReasoning:
            return "brain.head.profile"
        }
    }
    
    /// Technical summary of analytical capabilities
    public var summary: String {
        switch self {
        case .budgetFlash:
            return "Concise visual feedback and one focused next step."
        case .balanced:
            return "Balanced feedback on stage, composition, and next steps."
        case .deepReasoning:
            return "More detailed visual critique and a fuller stage checklist."
        }
    }
    
    /// The local Apple model used for all reasoning styles.
    public var apiModelIdentifier: String {
        "Apple Foundation Models"
    }
}
