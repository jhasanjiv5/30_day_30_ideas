//
//  SessionSummarySheet.swift
//  Sanctuary
//
//  Apple Journal Export Sheet & HealthKit Sync
//

import SwiftUI

struct SessionSummarySheet: View {
    let session: JournalSession
    @Environment(\.dismiss) private var dismiss
    @State private var healthLogged: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TONIGHT'S SYNTHESIS")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.indigo)
                            .tracking(1.2)

                        Text("Reflection Journal Card")
                            .font(.system(.title2, design: .serif))
                            .fontWeight(.bold)
                    }

                    // Card Container
                    VStack(alignment: .leading, spacing: 16) {
                        // Core Theme
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CORE THEME")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)

                            Text(session.coreTheme ?? "Evening decompression")
                                .font(.system(.body, design: .serif))
                                .fontWeight(.medium)
                        }

                        Divider()

                        // Key Realization Quote
                        if let quote = session.keyReflection {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("KEY REALIZATION")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)

                                Text(quote)
                                    .font(.system(.body, design: .serif))
                                    .italic()
                                    .foregroundStyle(.indigo)
                                    .padding(.leading, 8)
                                    .overlay(alignment: .leading) {
                                        Rectangle()
                                            .fill(Color.indigo)
                                            .frame(width: 3)
                                    }
                            }
                            Divider()
                        }

                        // Gentle Closing
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CLOSING")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)

                            Text(session.gentleClosing ?? "Rest well tonight.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        // Identified Emotion Chips
                        HStack(spacing: 6) {
                            ForEach(session.emotionsIdentified, id: \.self) { emotion in
                                Text(emotion)
                                    .font(.caption2)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color(.tertiarySystemBackground))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    // Export Buttons Section
                    VStack(spacing: 12) {
                        // 1. One-Tap Export to Apple Journal (App Shortcuts)
                        Button {
                            JournalExportManager.shared.openAppleJournalShortcut(session: session)
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export to Apple Journal")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.indigo)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // 2. iOS System ShareLink
                        ShareLink(
                            item: JournalExportManager.shared.createJournalExportText(session: session),
                            preview: SharePreview("Nightly Reflection", image: Image(systemName: "book.pages"))
                        ) {
                            HStack {
                                Image(systemName: "square.and.arrow.up.circle")
                                Text("Share via System Sheet")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // 3. Apple Health State of Mind Sync
                        if #available(iOS 18.0, *) {
                            Button {
                                Task {
                                    try? await JournalExportManager.shared.logStateOfMind(valence: session.finalValence)
                                    healthLogged = true
                                }
                            } label: {
                                HStack {
                                    Image(systemName: healthLogged ? "checkmark.circle.fill" : "heart.text.square")
                                    Text(healthLogged ? "Logged to Apple Health" : "Sync State of Mind to Health")
                                }
                                .font(.footnote)
                                .foregroundStyle(healthLogged ? .green : .secondary)
                            }
                            .padding(.top, 4)
                        } else {
                            Text("Apple Health State of Mind sync requires iOS 18.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Session Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
