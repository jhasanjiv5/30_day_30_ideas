import SwiftUI

@main
struct EnsembleTVApp: App {
    @State private var appModel = TVAppModel()

    var body: some Scene {
        WindowGroup {
            TVHomeView(model: appModel)
                .task {
                    appModel.startServices()
                }
        }
    }
}
