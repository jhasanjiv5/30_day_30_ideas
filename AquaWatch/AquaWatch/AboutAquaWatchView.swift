import SwiftUI

struct AboutAquaWatchView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Label("Why AquaWatch?", systemImage: "drop.fill")
                    .font(.headline)
                    .foregroundColor(.cyan)

                Text("Hydration is easy to overlook when logging takes effort. AquaWatch aims to make it simpler by recognizing drinking-like wrist motion and letting you confirm a drink, while keeping a quick manual log available.")
                    .font(.footnote)

                Label("Your hydration, in Health", systemImage: "heart.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.mint)

                Text("With your permission, confirmed water entries are saved as dietary water in Apple Health. That gives you one place to review hydration alongside information from your other health apps and can make longer-term habits easier to notice.")
                    .font(.footnote)

                Text("AquaWatch is a tracking aid, not medical advice. This prototype records water entries; it does not assess hydration needs or diagnose health conditions.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
        .navigationTitle("About")
    }
}
