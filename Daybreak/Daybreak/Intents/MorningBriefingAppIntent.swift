import AppIntents
import WidgetKit

public struct GenerateMorningBriefingIntent: AppIntent {
    public static var title: LocalizedStringResource = "Synthesize Morning Motive"
    public static var description = IntentDescription("Runs on-device AI model to extract daily motive and tasks.")
    public static var openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let reminders = try await EventKitRemindersProvider.shared.fetchIncompleteReminders()
        let documents = try await SecurityScopedDocumentManager.shared.readDesignatedFolder()

        let briefing = try await OnDeviceLLMEngine.shared.generateMorningBriefing(
            reminders: reminders,
            documents: documents
        )

        try WidgetDataStore.shared.saveBriefing(briefing)
        WidgetCenter.shared.reloadAllTimelines()

        return .result(
            dialog: IntentDialog("Good morning! Your focus: \(briefing.motive.headline)")
        )
    }
}

public struct ToggleTaskCompletionIntent: AppIntent {
    public static var title: LocalizedStringResource = "Toggle Task Completion"

    @Parameter(title: "Task ID")
    public var taskId: String

    public init() {}
    public init(taskId: String) {
        self.taskId = taskId
    }

    public func perform() async throws -> some IntentResult {
        WidgetDataStore.shared.toggleTask(id: taskId)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
