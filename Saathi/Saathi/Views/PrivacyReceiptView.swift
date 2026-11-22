import SwiftUI
import SaathiCore

struct PrivacyReceiptView: View {
    @Bindable var coordinator: SessionCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label("privacy_receipt_title", systemImage: "checkmark.shield.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.green)

                if let receipt = coordinator.privacyReceipt {
                    VStack(spacing: 12) {
                        receiptRow(
                            label: "Location active duration",
                            value: "\(Int(receipt.locationDurationSeconds)) s"
                        )
                        receiptRow(
                            label: NSLocalizedString("coordinates_stored_label", comment: ""),
                            value: "\(receipt.coordinatesStoredCount)",
                            identifier: "coordinatesStoredValue"
                        )
                        receiptRow(
                            label: "Personal items referenced",
                            value: "\(receipt.personalItemsReferencedCount)"
                        )
                        receiptRow(
                            label: "Anonymous tile lookups",
                            value: "\(receipt.anonymousTileLookupsCount)"
                        )
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                    if !receipt.queriedTileIDs.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Queried ~250 m Tile IDs")
                                .font(.headline)
                            ForEach(receipt.queriedTileIDs, id: \.self) { tileID in
                                Text(tileID)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                    }
                }

                // Required card with deep link to app Settings page to revoke location access
                VStack(alignment: .leading, spacing: 10) {
                    Text("Turn off location access")
                        .font(.headline)
                    Text("iOS apps cannot revoke their own permission programmatically. Tap below to review or turn off location access in Settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        coordinator.locationManager.openAppSettings()
                    } label: {
                        Label("turn_off_location_access", systemImage: "gear")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("openSettingsLocationButton")
                }
                .padding()
                .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))

                Button {
                    coordinator.proceedToEpisode()
                } label: {
                    Text("Continue to Memory Episode")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("continueToEpisodeButton")
            }
            .padding()
        }
        .navigationTitle(Text("privacy_receipt_title"))
        .navigationBarBackButtonHidden()
    }

    private func receiptRow(label: String, value: String, identifier: String? = nil) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.headline.monospacedDigit())
                .accessibilityIdentifier(identifier ?? label)
        }
    }
}
