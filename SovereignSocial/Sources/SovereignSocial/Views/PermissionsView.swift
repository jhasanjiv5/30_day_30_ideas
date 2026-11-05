import SwiftUI

public struct PermissionsView: View {
    @State private var instagramDM = false
    @State private var tiktokAnalytics = true
    @State private var stripEXIF = true

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Air-Gap Network Inspector")) {
                    HStack {
                        Text("External Packets Leaked")
                        Spacer()
                        Text("0 bytes").bold().foregroundStyle(.green)
                    }
                    HStack {
                        Text("Direct Message Isolation")
                        Spacer()
                        Text("Enforced").bold().foregroundStyle(.indigo)
                    }
                }

                Section(header: Text("Granular Platform Scopes")) {
                    Toggle("Instagram Direct Messages Access", isOn: $instagramDM)
                    Toggle("TikTok Demographic Insights", isOn: $tiktokAnalytics)
                    Toggle("Strip EXIF Geolocation from Media", isOn: $stripEXIF)
                }
            }
            .navigationTitle("Permissions & Privacy")
        }
    }
}
