//
//  HealthKitAnalyticsView.swift
//  Sanctuary
//
//  Apple Health State of Mind Integration Dashboard
//

import SwiftUI
import SwiftData

struct HealthKitAnalyticsView: View {
    @Query(sort: \JournalSession.timestamp, order: .reverse) private var sessions: [JournalSession]
    @State private var isAuthorized: Bool = false

    var averageValence: Double {
        guard !sessions.isEmpty else { return 0.0 }
        let total = sessions.reduce(0.0) { $0 + $1.finalValence }
        return total / Double(sessions.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Stat Cards
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AVERAGE VALENCE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)

                        Text("\(averageValence >= 0 ? "+" : "")\(String(format: "%.2f", averageValence))")
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(.indigo)

                        Text(averageValence > 0.1 ? "Generally Pleasant" : "Mixed / Unwinding")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("TOTAL LOGS")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)

                        Text("\(sessions.count)")
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(.primary)

                        Text("Stored via SwiftData")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // HealthKit Permission Box
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "heart.text.square.fill")
                            .font(.title2)
                            .foregroundStyle(.pink)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Health • State of Mind")
                                .font(.headline)
                            Text("HKCategoryTypeIdentifierStateOfMind")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("Because Apple limits third-party apps from silently writing entries to the Apple Journal app, Sanctuary logs your emotional valence directly into Apple Health. The Journal app natively references this database to suggest reflection prompts.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)

                    if #available(iOS 18.0, *) {
                        Button {
                            Task {
                                isAuthorized = await JournalExportManager.shared.requestAuthorization()
                            }
                        } label: {
                            Text(isAuthorized ? "HealthKit Authorized" : "Authorize Apple Health")
                                .font(.footnote.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(isAuthorized ? Color.green.opacity(0.15) : Color.indigo)
                                .foregroundStyle(isAuthorized ? Color.green : Color.white)
                                .clipShape(Capsule())
                        }
                    } else {
                        Text("Apple Health State of Mind requires iOS 18.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))

                // Valence History List
                VStack(alignment: .leading, spacing: 12) {
                    Text("RECENT CHECK-INS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)

                    ForEach(sessions.prefix(7)) { session in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.footnote)
                                    .fontWeight(.medium)

                                Text(session.coreTheme ?? "Evening check-in")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text("\(session.finalValence >= 0 ? "+" : "")\(String(format: "%.2f", session.finalValence))")
                                .font(.footnote.bold().monospacedDigit())
                                .foregroundStyle(session.finalValence >= 0 ? .green : .orange)
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .padding()
        }
        .navigationTitle("State of Mind")
    }
}
