import SwiftUI

public struct MorningDashboardView: View {
    @State private var briefing: MorningBriefing? = WidgetDataStore.shared.loadBriefing()
    @State private var isRefreshing = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let briefing = briefing {
                        MotiveCardView(motive: briefing.motive)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("TODAY'S PRIORITIES")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(briefing.todos.filter { $0.completed }.count)/\(briefing.todos.count) Done")
                                    .font(.caption.bold())
                                    .foregroundStyle(.orange)
                            }

                            ForEach(briefing.todos) { todo in
                                TaskRowView(task: todo) {
                                    WidgetDataStore.shared.toggleTask(id: todo.id)
                                    self.briefing = WidgetDataStore.shared.loadBriefing()
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    } else {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Synthesizing your daily briefing...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(40)
                    }
                }
                .padding()
            }
            .navigationTitle("Good Morning")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: refreshBriefing) {
                        Image(systemName: "sparkles")
                    }
                }
            }
        }
        .onAppear {
            if briefing == nil {
                refreshBriefing()
            }
        }
    }

    private func refreshBriefing() {
        Task {
            isRefreshing = true
            let reminders = (try? await EventKitRemindersProvider.shared.fetchIncompleteReminders()) ?? []
            let documents = (try? await SecurityScopedDocumentManager.shared.readDesignatedFolder()) ?? []
            let newBriefing = try? await OnDeviceLLMEngine.shared.generateMorningBriefing(
                reminders: reminders,
                documents: documents
            )
            if let newBriefing = newBriefing {
                try? WidgetDataStore.shared.saveBriefing(newBriefing)
                self.briefing = newBriefing
            }
            isRefreshing = false
        }
    }
}
