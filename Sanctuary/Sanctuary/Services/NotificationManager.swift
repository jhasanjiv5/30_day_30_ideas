//
//  NotificationManager.swift
//  Sanctuary
//
//  Nightly Wind-Down Local Notification Scheduler
//

import Foundation
import UserNotifications

public final class NotificationManager {
    public static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    private init() {}

    public func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    public func scheduleNightlyReminder(hour: Int = 21, minute: Int = 0) async {
        center.removePendingNotificationRequests(withIdentifiers: ["nightly_reflection"])

        let content = UNMutableNotificationContent()
        content.title = "Evening Reflection"
        content.subtitle = "Sanctuary Wind-down"
        content.body = "The day is coming to a close. Take 4 quiet turns with your on-device therapist to unwind."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "nightly_reflection", content: content, trigger: trigger)

        try? await center.add(request)
    }

    public func triggerTestNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Evening Reflection"
        content.body = "Time for your 5-minute decompression session before sleep."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "test_notification_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)

        try? await center.add(request)
    }
}
