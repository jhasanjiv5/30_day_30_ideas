import SwiftUI
import BackgroundTasks
import UserNotifications

@main
struct DaybreakApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Register Background Tasks
        BackgroundProcessingManager.shared.registerBackgroundTask()
        
        // Request Notification Permissions
        LocalNotificationManager.shared.requestAuthorization()
        
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        BackgroundProcessingManager.shared.scheduleNextNightlyProcessing()
    }
}
