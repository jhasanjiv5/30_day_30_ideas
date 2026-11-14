import SwiftUI
import ColdTwinCore

struct CSVImportReviewView: View {
    @EnvironmentObject private var store: ColdTwinStore
    @Environment(\.dismiss) private var dismiss
    let csvText: String

    private var rows: [CSVPreviewRow] {
        CSVImporter().parse(
            csvText: csvText,
            assets: store.assets,
            existingReadings: store.readings
        )
    }

    private var validCount: Int {
        rows.filter(\.isValid).count
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Required columns: timestamp, asset_id, temperature, unit. Optional: event.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let inventoryError = store.inventoryError {
                    Label(inventoryError, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
                if rows.isEmpty {
                    ContentUnavailableView(
                        "No CSV rows to preview",
                        systemImage: "tablecells",
                        description: Text("Check the required column names and make sure the file contains data rows.")
                    )
                } else {
                    Text("\(validCount) valid · \(rows.count - validCount) skipped")
                        .font(.headline)
                    List(rows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Row \(row.rowNumber)")
                                Spacer()
                                Label(
                                    row.isValid ? "Ready" : (row.isDuplicate ? "Duplicate" : "Invalid"),
                                    systemImage: row.isValid ? "checkmark.circle" : "exclamationmark.circle"
                                )
                                .foregroundStyle(row.isValid ? .green : .orange)
                            }
                            Text("\(row.timestampRaw) · \(row.assetIdRaw) · \(row.temperatureRaw) °\(row.unitRaw)")
                                .font(.caption)
                            ForEach(row.errors, id: \.self) { error in
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            if !row.eventRaw.isEmpty {
                                Text("Event: \(row.eventRaw)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding()
            .navigationTitle("Review CSV Import")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import \(validCount) Rows") {
                        if store.importRows(rows) {
                            dismiss()
                        }
                    }
                    .disabled(validCount == 0)
                }
            }
        }
        .frame(minWidth: 560, minHeight: 420)
    }
}
