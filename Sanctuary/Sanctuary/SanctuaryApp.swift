//
//  SanctuaryApp.swift
//  Sanctuary
//
//  Created for iOS 17/18+ using SwiftUI & SwiftData
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct SanctuaryApp: App {
    // Configure SwiftData container with local hardware encryption (FileProtectionType.complete)
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([
                JournalSession.self,
                ChatMessage.self
            ])
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not initialize SwiftData ModelContainer: \(error)")
        }

        // Request local notification permissions on launch
        Task {
            _ = await NotificationManager.shared.requestAuthorization()
            await NotificationManager.shared.scheduleNightlyReminder(hour: 21, minute: 00)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
