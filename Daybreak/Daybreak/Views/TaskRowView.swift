import SwiftUI

public struct TaskRowView: View {
    public let task: SynthesizedTodo
    public let onToggle: () -> Void

    public init(task: SynthesizedTodo, onToggle: @escaping () -> Void) {
        self.task = task
        self.onToggle = onToggle
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.completed ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(task.category.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(categoryColor.opacity(0.15))
                        .foregroundStyle(categoryColor)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    if let deadline = task.deadline {
                        Text(deadline)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("~\(task.estimatedMinutes)m")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(task.completed)
                    .foregroundStyle(task.completed ? .secondary : .primary)

                Text("From: \(task.sourceTitle)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var categoryColor: Color {
        switch task.category {
        case "crucial": return .red
        case "focus": return .orange
        default: return .green
        }
    }
}

public struct DataSourcesView: View {
    public var body: some View {
        NavigationStack {
            List {
                Section("Native Connectors") {
                    Label("Apple Reminders (EventKit)", systemImage: "checklist")
                    Label("In-App Email Sync (OAuth)", systemImage: "envelope.fill")
                    Label("Security-Scoped Folder (Files)", systemImage: "folder.fill")
                }
            }
            .navigationTitle("Data Sources")
        }
    }
}

public struct SettingsView: View {
    @AppStorage("wakeupTime") private var wakeupTime = "07:00"

    public var body: some View {
        NavigationStack {
            Form {
                Section("Daily Briefing Schedule") {
                    HStack {
                        Text("Morning Delivery")
                        Spacer()
                        Text(wakeupTime + " AM").bold()
                    }
                }
                Section("On-Device Engine") {
                    Text("Model: 4-bit Llama 3.2 1B Instruct (MLX Swift)")
                    Text("Execution: Overnight charging (BGProcessingTask)")
                }
            }
            .navigationTitle("Configuration")
        }
    }
}
