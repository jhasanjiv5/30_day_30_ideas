import Foundation

public struct MorningBriefing: Codable, Sendable {
    public let motive: Motive
    public var todos: [SynthesizedTodo]
    public let summaryInsights: SummaryInsights

    public init(motive: Motive, todos: [SynthesizedTodo], summaryInsights: SummaryInsights) {
        self.motive = motive
        self.todos = todos
        self.summaryInsights = summaryInsights
    }
}

public struct Motive: Codable, Sendable {
    public let headline: String
    public let quote: String
    public let narrative: String
    public let toneTag: String

    public init(headline: String, quote: String, narrative: String, toneTag: String) {
        self.headline = headline
        self.quote = quote
        self.narrative = narrative
        self.toneTag = toneTag
    }
}

public struct SynthesizedTodo: Identifiable, Codable, Sendable {
    public let id: String
    public var title: String
    public let category: String // "crucial", "focus", "quick-win"
    public let source: String   // "reminder", "email", "document"
    public let sourceTitle: String
    public let rationale: String
    public let estimatedMinutes: Int
    public let energyLevel: String
    public let deadline: String?
    public var completed: Bool

    public init(
        id: String,
        title: String,
        category: String,
        source: String,
        sourceTitle: String,
        rationale: String,
        estimatedMinutes: Int,
        energyLevel: String,
        deadline: String? = nil,
        completed: Bool = false
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.source = source
        self.sourceTitle = sourceTitle
        self.rationale = rationale
        self.estimatedMinutes = estimatedMinutes
        self.energyLevel = energyLevel
        self.deadline = deadline
        self.completed = completed
    }
}

public struct SummaryInsights: Codable, Sendable {
    public let totalUnreadEmailsEvaluated: Int
    public let urgentFlagsDetected: Int
    public let topBlocker: String

    public init(totalUnreadEmailsEvaluated: Int, urgentFlagsDetected: Int, topBlocker: String) {
        self.totalUnreadEmailsEvaluated = totalUnreadEmailsEvaluated
        self.urgentFlagsDetected = urgentFlagsDetected
        self.topBlocker = topBlocker
    }
}

public struct ReminderData: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let listName: String
    public let priority: String
    public let dueDate: String?
    public let notes: String?
}

public struct DocumentSnippet: Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let excerpt: String
}
