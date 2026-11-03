import UserNotifications

public final class LocalNotificationManager {
    public static let shared = LocalNotificationManager()

    private init() {}

    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if granted {
                print("Notification permissions granted.")
            }
        }
    }

    public func scheduleMorningDelivery(headline: String, quote: String) {
        let content = UNMutableNotificationContent()
        content.title = "☀️ " + headline
        content.body = quote
        content.sound = .default
        content.categoryIdentifier = "MORNING_BRIEFING"

        var dateComponents = DateComponents()
        dateComponents.hour = 7
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyMorningBriefing", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }
}
