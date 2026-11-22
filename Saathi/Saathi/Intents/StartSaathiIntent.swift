import AppIntents
import Foundation

struct StartSaathiIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Saathi here"
    static let description = IntentDescription("Starts a privacy-first walk companion at your current location. It wraps up when your walk ends.")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Stored as well as posted: on a cold launch the UI isn't subscribed yet when the
        // intent runs, so RootContentView also consumes this on appear.
        PendingStartRequest.isPending = true
        NotificationCenter.default.post(name: .saathiStartIntentTriggered, object: nil)
        return .result(dialog: "Starting Saathi. I'll keep you company until your walk ends.")
    }
}

/// Hand-off from the App Intent to the UI (same process, main actor).
@MainActor
enum PendingStartRequest {
    static var isPending = false

    static func consume() -> Bool {
        defer { isPending = false }
        return isPending
    }
}

struct SaathiAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartSaathiIntent(),
            phrases: [
                "Start \(.applicationName) here",
                "Begin my walk with \(.applicationName)"
            ],
            shortTitle: "Start Saathi here",
            systemImageName: "headphones.circle.fill"
        )
    }
}

extension Notification.Name {
    static let saathiStartIntentTriggered = Notification.Name("SaathiStartIntentTriggered")
}
