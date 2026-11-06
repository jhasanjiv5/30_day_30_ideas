import Foundation
import SwiftUI

public enum RoomCategory: String, Codable, CaseIterable {
    case livingRoom = "Living Room"
    case homeOffice = "Home Office"
    case bedroom = "Bedroom"
    case studio = "Studio / Dining"
}

public struct ClutterItem: Identifiable, Codable {
    public let id: String
    public let label: String
    public let category: String
    public let boundingBox: BoundingBox
    public let recommendation: String
    public let spaceImpact: String
    public var potentialResaleValue: Double?
    public var isCleared: Bool = false

    public struct BoundingBox: Codable {
        public let x: Double // % 0-100
        public let y: Double
        public let w: Double
        public let h: Double
    }
}

public struct StagedItem: Identifiable, Codable {
    public let id: String
    public let name: String
    public let brand: String
    public let retailer: String
    public let category: String
    public var price: Double
    public let currency: String
    public let rating: Double
    public let reviewCount: Int
    public let dimensions: String
    public let material: String
    public let color: String
    public let buyUrl: String
    public let thumbnail: String
    public let spatialPosition: SpatialPosition
    public let reason: String
    public var inPlan: Bool

    public struct SpatialPosition: Codable {
        public let x: Double // %
        public let y: Double
        public let depth3D: Double
    }
}

public struct ReasoningStep: Identifiable, Codable {
    public let id = UUID()
    public let step: Int
    public let title: String
    public let detail: String
    public let durationMs: Int
    public var status: String
}

public struct RoomDimensions: Codable {
    public let widthFt: Double
    public let lengthFt: Double
    public let ceilingFt: Double
    public let sqFt: Double
}

public struct EnhancementMetrics: Codable {
    public let luxImprovement: String
    public let colorTone: String
    public let clutterReduction: Int
    public let acousticsNote: String
}

public struct Room: Identifiable, Codable {
    public let id: String
    public var name: String
    public var subtitle: String
    public var category: RoomCategory
    public var beforeImage: String
    public var afterImage: String
    public var dimensions: RoomDimensions
    public var spaceRecoveredSqFt: Double
    public var spaceRecoveredPercent: Double
    public var declutterItems: [ClutterItem]
    public var stagedItems: [StagedItem]
    public var enhancementMetrics: EnhancementMetrics
    public var reasoningSteps: [ReasoningStep]
}
