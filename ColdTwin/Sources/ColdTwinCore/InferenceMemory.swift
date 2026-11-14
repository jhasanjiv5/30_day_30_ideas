import Foundation

public enum UserAssessmentOverride: String, Codable, CaseIterable, Equatable, Sendable {
    case automatic
    case possible
    case needsMoreEvidence
}

public struct InferenceFeedback: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let assetID: String
    public let hypothesisID: String
    public let assessment: UserAssessmentOverride
    public let recordedAt: Date

    public init(
        id: String = UUID().uuidString,
        assetID: String,
        hypothesisID: String,
        assessment: UserAssessmentOverride,
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.assetID = assetID
        self.hypothesisID = hypothesisID
        self.assessment = assessment
        self.recordedAt = recordedAt
    }
}

public struct InferenceMemory: Codable, Equatable, Sendable {
    public var customRules: [String]
    public var assessmentOverrides: [String: UserAssessmentOverride]
    public var feedback: [InferenceFeedback]
    public var externalModels: [ExternalModelProfile]
    public var selectedExternalModelID: String?

    public init(
        customRules: [String] = [],
        assessmentOverrides: [String: UserAssessmentOverride] = [:],
        feedback: [InferenceFeedback] = [],
        externalModels: [ExternalModelProfile] = [],
        selectedExternalModelID: String? = nil
    ) {
        self.customRules = customRules
        self.assessmentOverrides = assessmentOverrides
        self.feedback = feedback
        self.externalModels = externalModels
        self.selectedExternalModelID = selectedExternalModelID
    }

    private enum CodingKeys: String, CodingKey {
        case customRules
        case assessmentOverrides
        case feedback
        case externalModels
        case selectedExternalModelID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        customRules = try container.decodeIfPresent([String].self, forKey: .customRules) ?? []
        assessmentOverrides = try container.decodeIfPresent(
            [String: UserAssessmentOverride].self,
            forKey: .assessmentOverrides
        ) ?? [:]
        feedback = try container.decodeIfPresent([InferenceFeedback].self, forKey: .feedback) ?? []
        externalModels = try container.decodeIfPresent([ExternalModelProfile].self, forKey: .externalModels) ?? []
        selectedExternalModelID = try container.decodeIfPresent(String.self, forKey: .selectedExternalModelID)
    }
}

public struct ExternalModelProfile: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var name: String
    public var baseURL: String
    public var modelID: String

    public init(
        id: String = UUID().uuidString,
        name: String,
        baseURL: String,
        modelID: String
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.modelID = modelID
    }
}

public struct LocalInferenceMemoryStore {
    private let defaults: UserDefaults
    private let storageKey: String

    public init(
        defaults: UserDefaults = .standard,
        storageKey: String = "ColdTwin.localInferenceMemory"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    public func load() throws -> InferenceMemory {
        guard let data = defaults.data(forKey: storageKey) else {
            return InferenceMemory()
        }
        return try JSONDecoder().decode(InferenceMemory.self, from: data)
    }

    public func save(_ memory: InferenceMemory) throws {
        let data = try JSONEncoder().encode(memory)
        defaults.set(data, forKey: storageKey)
    }
}
