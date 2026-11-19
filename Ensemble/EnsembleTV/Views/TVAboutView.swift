import EnsembleCore
import SwiftUI

struct TVAboutView: View {
    let catalogue: [MediaItem]
    @Environment(\.dismiss) private var dismiss

    private var licensedFilms: [MediaItem] {
        catalogue.filter { $0.license != nil }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Architecture") {
                    Text("Ensemble runs strictly on your local Wi-Fi network via Bonjour (_ensemble._tcp) and on-device Intelligence. Raw watch history never leaves any iPhone.")
                    Text("Apple Intelligence (FoundationModels) executes solely on eligible iPhones; Apple TV receives only the 60-word summary and character list.")
                }

                Section("Creative Commons Blender Open Movies") {
                    ForEach(licensedFilms) { film in
                        if let license = film.license {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(film.title) (\(film.year))")
                                    .font(.headline)
                                Text(license.attribution)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                Text("\(license.licenseName) · \(license.licenseURL)")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationTitle("About Ensemble")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
