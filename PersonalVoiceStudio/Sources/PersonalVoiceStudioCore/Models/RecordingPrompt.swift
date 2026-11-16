import Foundation

public enum PromptLengthClass: String, Codable, Equatable, Sendable, CaseIterable {
    case short
    case medium
    case long

    public var displayLabel: String {
        switch self {
        case .short: return "Short"
        case .medium: return "Medium"
        case .long: return "Long"
        }
    }
}

public struct RecordingPrompt: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let index: Int
    public let title: String
    public let category: String
    public let text: String
    public let phoneticFocus: String
    public let recommendedMinimumSeconds: Double
    public let lengthClass: PromptLengthClass

    public init(
        id: String,
        index: Int,
        title: String,
        category: String,
        text: String,
        phoneticFocus: String,
        recommendedMinimumSeconds: Double,
        lengthClass: PromptLengthClass
    ) {
        self.id = id
        self.index = index
        self.title = title
        self.category = category
        self.text = text
        self.phoneticFocus = phoneticFocus
        self.recommendedMinimumSeconds = recommendedMinimumSeconds
        self.lengthClass = lengthClass
    }
}
