import EventKit

public final class EventKitRemindersProvider {
    public static let shared = EventKitRemindersProvider()
    private let eventStore = EKEventStore()

    private init() {}

    public func requestAccess() async throws -> Bool {
        if #available(iOS 17.0, *) {
            return try await eventStore.requestFullAccessToReminders()
        } else {
            return try await eventStore.requestAccess(to: .reminder)
        }
    }

    public func fetchIncompleteReminders() async throws -> [ReminderData] {
        let authorized = try await requestAccess()
        guard authorized else { return [] }

        let calendars = eventStore.calendars(for: .reminder)
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
            calendars: calendars
        )

        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { ekReminders in
                guard let ekReminders = ekReminders else {
                    continuation.resume(returning: [])
                    return
                }

                let items = ekReminders.map { reminder in
                    ReminderData(
                        id: reminder.calendarItemIdentifier,
                        title: reminder.title ?? "Untitled Reminder",
                        listName: reminder.calendar?.title ?? "Reminders",
                        priority: reminder.priority > 0 ? (reminder.priority <= 4 ? "High" : "Medium") : "Low",
                        dueDate: reminder.dueDateComponents?.date?.formatted(),
                        notes: reminder.notes
                    )
                }
                continuation.resume(returning: items)
            }
        }
    }
}
