import PersonalVideoStudioCore
import PersonalVideoStudioUI
import SwiftUI

@main
struct PersonalVideoStudioApp: App {
    @StateObject private var store = VideoStudioStore()

    var body: some Scene {
        WindowGroup("Personal Video Studio") {
            MainStudioView(store: store)
        }
        .defaultSize(width: 1180, height: 780)
    }
}
