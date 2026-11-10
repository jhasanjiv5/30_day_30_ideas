import FirebaseCore
import SwiftUI

@main
struct SnippetAIApp: App {
    init() {
        if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            VideoSummarizerView()
        }
    }
}
