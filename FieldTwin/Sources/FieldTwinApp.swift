import SwiftUI

@main
struct FieldTwinApp: App {
    @State private var engine = SpatialMCPEngine()
    @State private var companionSync = NearbyCompanionSync()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(engine)
                .environment(companionSync)
                .preferredColorScheme(.dark)
        }
    }
}
