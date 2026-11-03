import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MorningDashboardView()
                .tabItem {
                    Label("Morning Motive", systemImage: "sun.horizon.fill")
                }
                .tag(0)

            DataSourcesView()
                .tabItem {
                    Label("Data Sources", systemImage: "tray.full.fill")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Schedule & AI", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .tint(.orange)
    }
}
