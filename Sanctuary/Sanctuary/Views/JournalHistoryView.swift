//
//  JournalHistoryView.swift
//  Sanctuary
//
//  SwiftData Encrypted History of Past Nightly Sessions
//

import SwiftUI
import SwiftData

struct JournalHistoryView: View {
    @Query(sort: \JournalSession.timestamp, order: .reverse) private var sessions: [JournalSession]
    @Environment(\.modelContext) private var modelContext
    @State private var searchText: String = ""

    var filteredSessions: [JournalSession] {
        if searchText.isEmpty {
            return sessions
        }
        return sessions.filter {
            ($0.coreTheme?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            ($0.keyReflection?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        Group {
            if filteredSessions.isEmpty {
                ContentUnavailableView(
                    "No Reflections Yet",
                    systemImage: "book.pages",
                    description: Text("Complete your first nightly reflection to build your Apple Journal vault.")
                )
            } else {
                List {
                    ForEach(filteredSessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(session.timestamp.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Spacer()

                                    Text(session.valenceCategory)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.indigo.opacity(0.12))
                                        .foregroundStyle(.indigo)
                                        .clipShape(Capsule())
                                }

                                Text(session.coreTheme ?? "Evening Reflection")
                                    .font(.headline)
                                    .lineLimit(2)

                                if let quote = session.keyReflection {
                                    Text(quote)
                                        .font(.subheadline)
                                        .italic()
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete(perform: deleteSessions)
                }
                .searchable(text: $searchText, prompt: "Search themes or realizations")
            }
        }
        .navigationTitle("Journal Vault")
    }

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredSessions[index])
        }
        try? modelContext.save()
    }
}

struct SessionDetailView: View {
    let session: JournalSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Metadata Bar
                HStack {
                    Label(session.timestamp.formatted(date: .long, time: .shortened), systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Valence: \(String(format: "%.2f", session.finalValence))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.indigo)
                }

                // Core Theme
                VStack(alignment: .leading, spacing: 6) {
                    Text("CORE THEME")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)

                    Text(session.coreTheme ?? "Reflection")
                        .font(.system(.title3, design: .serif))
                }

                if let quote = session.keyReflection {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("KEY REALIZATION")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)

                        Text(quote)
                            .font(.system(.body, design: .serif))
                            .italic()
                            .foregroundStyle(.indigo)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                // Transcript
                VStack(alignment: .leading, spacing: 10) {
                    Text("CONVERSATION TRANSCRIPT")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)

                    ForEach(session.messages) { msg in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(msg.sender.capitalized)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(msg.isUser ? .indigo : .secondary)

                            Text(msg.content)
                                .font(.footnote)
                        }
                        .padding(.vertical, 2)
                    }
                }

                // Export Button
                Button {
                    JournalExportManager.shared.openAppleJournalShortcut(session: session)
                } label: {
                    Label("Export to Apple Journal", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.indigo)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding()
        }
        .navigationTitle("Reflection")
        .navigationBarTitleDisplayMode(.inline)
    }
}
