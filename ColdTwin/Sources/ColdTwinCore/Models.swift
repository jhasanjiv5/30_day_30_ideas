import Foundation

public enum AssetType: String, Codable, CaseIterable, Sendable {
    case cooler
    case freezer
}

public enum TemperatureUnit: String, Codable, CaseIterable, Sendable {
    case celsius = "C"
    case fahrenheit = "F"

    public func toCelsius(_ value: Double) -> Double {
        switch self {
        case .celsius: return value
        case .fahrenheit: return (value - 32.0) * 5.0 / 9.0
        }
    }

    public func fromCelsius(_ celsius: Double) -> Double {
        switch self {
        case .celsius: return celsius
        case .fahrenheit: return (celsius * 9.0 / 5.0) + 32.0
        }
    }
}

public enum RangeSource: String, Codable, Sendable {
    case illustrativeDefault = "illustrative_default"
    case userConfigured = "user_configured"
}

public enum AssetStatus: String, Codable, Sendable {
    case normal = "Normal"
    case watch = "Watch"
    case investigate = "Investigate"
    case insufficientData = "Insufficient data"
}

public enum EventCategory: String, Codable, CaseIterable, Sendable {
    case doorOpen = "door_open"
    case stockDelivery = "stock_delivery"
    case defrost = "defrost"
    case cleaning = "cleaning"
    case sensorCheck = "sensor_check"
    case other = "other"
}

public enum SkillLevel: String, Codable, CaseIterable, Hashable, Sendable {
    case basicInspection = "basic inspection"
    case refrigerationTechnician = "refrigeration technician"
}

public enum ToolItem: String, Codable, CaseIterable, Hashable, Sendable {
    case flashlight = "flashlight"
    case calibratedThermometer = "calibrated thermometer"
    case gasketCard = "gasket card"
    case multimeter = "multimeter"
}

public struct Site: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var location: String
    public var isDemo: Bool
    public let createdAt: Date

    public init(id: String, name: String, location: String, isDemo: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.location = location
        self.isDemo = isDemo
        self.createdAt = createdAt
    }
}

public struct Asset: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var siteId: String
    public var name: String
    public var assetType: AssetType
    public var preferredUnit: TemperatureUnit
    public var rangeMinC: Double
    public var rangeMaxC: Double
    public var rangeSource: RangeSource
    public var isDemo: Bool

    public init(
        id: String,
        siteId: String,
        name: String,
        assetType: AssetType,
        preferredUnit: TemperatureUnit = .celsius,
        rangeMinC: Double? = nil,
        rangeMaxC: Double? = nil,
        rangeSource: RangeSource = .illustrativeDefault,
        isDemo: Bool = false
    ) {
        self.id = id
        self.siteId = siteId
        self.name = name
        self.assetType = assetType
        self.preferredUnit = preferredUnit
        let defaults = assetType == .cooler ? (1.0, 5.0) : (-22.0, -15.0)
        self.rangeMinC = rangeMinC ?? defaults.0
        self.rangeMaxC = rangeMaxC ?? defaults.1
        self.rangeSource = rangeSource
        self.isDemo = isDemo
    }
}

public struct TemperatureReading: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let assetId: String
    public let originalValue: Double
    public let originalUnit: TemperatureUnit
    public let normalizedCelsius: Double
    public let originalTimestamp: String
    public let timestamp: Date
    public let sourceLabel: String
    public let isDemo: Bool

    public init(
        id: String = UUID().uuidString,
        assetId: String,
        originalValue: Double,
        originalUnit: TemperatureUnit,
        originalTimestamp: String,
        timestamp: Date,
        sourceLabel: String = "Manual",
        isDemo: Bool = false
    ) {
        self.id = id
        self.assetId = assetId
        self.originalValue = originalValue
        self.originalUnit = originalUnit
        self.normalizedCelsius = originalUnit.toCelsius(originalValue)
        self.originalTimestamp = originalTimestamp
        self.timestamp = timestamp
        self.sourceLabel = sourceLabel
        self.isDemo = isDemo
    }
}

public struct RecordedEvent: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let assetId: String
    public let originalTimestamp: String
    public let timestamp: Date
    public let category: EventCategory
    public let note: String
    public let isDemo: Bool

    public init(
        id: String = UUID().uuidString,
        assetId: String,
        originalTimestamp: String,
        timestamp: Date,
        category: EventCategory,
        note: String,
        isDemo: Bool = false
    ) {
        self.id = id
        self.assetId = assetId
        self.originalTimestamp = originalTimestamp
        self.timestamp = timestamp
        self.category = category
        self.note = note
        self.isDemo = isDemo
    }
}

public struct Observation: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let kind: String
    public let description: String
    public let readingIds: [String]
    public let eventIds: [String]
    public let timestamp: String
}

public struct CheckRequirements: Codable, Hashable, Sendable {
    public let estimatedMinutes: Int
    public let skills: [SkillLevel]
    public let tools: [ToolItem]
    public let risk: String
}

public struct ExpectedResults: Codable, Hashable, Sendable {
    public let supportsHypothesis: String
    public let weakensHypothesis: String
}

public struct DiagnosisOption: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let hypothesis: String
    public var status: String
    public var priorityLabel: String
    public var availabilityStatus: String
    public var plainLanguageExplanation: String
    public var supportingObservationIds: [String]
    public let conflictingObservationIds: [String]
    public let assumptions: [String]
    public var missingInformation: [String]
    public let counterfactualPrediction: String
    public let nextCheck: String
    public let expectedResults: ExpectedResults
    public let requirements: CheckRequirements
    public var priorityFactors: [String]
    public var rankScore: Int
    public let isConfirmedDiagnosis: Bool = false
}

public struct ResourceContext: Codable, Hashable, Sendable {
    public var availableMinutes: Int?
    public var availableSkills: [SkillLevel]
    public var availableTools: [ToolItem]

    public init(availableMinutes: Int? = 15, availableSkills: [SkillLevel] = [.basicInspection], availableTools: [ToolItem] = [.flashlight]) {
        self.availableMinutes = availableMinutes
        self.availableSkills = availableSkills
        self.availableTools = availableTools
    }
}

public struct CheckRecord: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let analysisId: String
    public let assetId: String
    public let optionId: String
    public let optionTitle: String
    public let performedAt: Date
    public let outcome: String
    public let notes: String

    public init(
        id: String = UUID().uuidString,
        analysisId: String,
        assetId: String,
        optionId: String,
        optionTitle: String,
        performedAt: Date = Date(),
        outcome: String,
        notes: String
    ) {
        self.id = id
        self.analysisId = analysisId
        self.assetId = assetId
        self.optionId = optionId
        self.optionTitle = optionTitle
        self.performedAt = performedAt
        self.outcome = outcome
        self.notes = notes
    }
}

public struct Analysis: Identifiable, Codable, Sendable {
    public let id: String
    public let assetId: String
    public let generatedAt: Date
    public let statusAtAnalysis: AssetStatus
    public let summary: String
    public let dataQualityNotes: [String]
    public let observations: [Observation]
    public var options: [DiagnosisOption]

    public init(
        id: String,
        assetId: String,
        generatedAt: Date,
        statusAtAnalysis: AssetStatus,
        summary: String,
        dataQualityNotes: [String],
        observations: [Observation],
        options: [DiagnosisOption]
    ) {
        self.id = id
        self.assetId = assetId
        self.generatedAt = generatedAt
        self.statusAtAnalysis = statusAtAnalysis
        self.summary = summary
        self.dataQualityNotes = dataQualityNotes
        self.observations = observations
        self.options = options
    }
}
