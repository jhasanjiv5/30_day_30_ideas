import PersonalVoiceStudioCore
import PersonalVoiceStudioUI
import SwiftUI

@main
struct PersonalVoiceStudioApp: App {
    @StateObject private var store = VoiceStudioStore()

    var body: some Scene {
        WindowGroup("Personal Voice Studio") {
            MainStudioView(store: store)
        }
        .defaultSize(width: 1040, height: 720)
    }
}
