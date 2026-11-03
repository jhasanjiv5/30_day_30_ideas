import Foundation
import BackgroundTasks
import os.log

public final class BackgroundProcessingManager {
    public static let shared = BackgroundProcessingManager()
    public static let taskIdentifier = "com.daybreak.nightlySynthesis"
    private let logger = Logger(subsystem: "com.daybreak", category: "BackgroundTasks")

    private init() {}

    public func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            self.handleNightlySynthesis(task: processingTask)
        }
    }

    public func scheduleNextNightlyProcessing() {
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = true // Runs while phone charges overnight
        
        var calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.day? += 1
        components.hour = 3
        components.minute = 30
        request.earliestBeginDate = calendar.date(from: components)

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Scheduled nightly BGProcessingTask for \(String(describing: request.earliestBeginDate))")
        } catch {
            logger.error("Failed to submit BGProcessingTask: \(error.localizedDescription)")
        }
    }

    private func handleNightlySynthesis(task: BGProcessingTask) {
        scheduleNextNightlyProcessing()

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        task.expirationHandler = {
            self.logger.warning("Background task expiring. Halting inference.")
            queue.cancelAllOperations()
        }

        queue.addOperation {
            Task {
                do {
                    // Check available memory before loading 4-bit weights
                    let availableBytes = os_proc_available_memory()
                    let availableMB = availableBytes / (1024 * 1024)
                    
                    guard availableMB > 850 else {
                        self.logger.error("Insufficient RAM (\(availableMB) MB). Deferring to morning launch to avoid Jetsam kill.")
                        task.setTaskCompleted(success: false)
                        return
                    }

                    let reminders = try await EventKitRemindersProvider.shared.fetchIncompleteReminders()
                    let documents = try await SecurityScopedDocumentManager.shared.readDesignatedFolder()

                    let briefing = try await OnDeviceLLMEngine.shared.generateMorningBriefing(
                        reminders: reminders,
                        documents: documents
                    )

                    try WidgetDataStore.shared.saveBriefing(briefing)

                    // Schedule local notification for exact 7:00 AM delivery
                    LocalNotificationManager.shared.scheduleMorningDelivery(
                        headline: briefing.motive.headline,
                        quote: briefing.motive.quote
                    )

                    task.setTaskCompleted(success: true)
                } catch {
                    self.logger.error("Nightly synthesis failed: \(error.localizedDescription)")
                    task.setTaskCompleted(success: false)
                }
            }
        }
    }
}
