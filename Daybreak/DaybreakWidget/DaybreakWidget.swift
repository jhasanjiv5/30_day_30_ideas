import WidgetKit
import SwiftUI
import AppIntents

struct MorningTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> BriefingEntry {
        BriefingEntry(date: Date(), briefing: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (BriefingEntry) -> Void) {
        let entry = BriefingEntry(date: Date(), briefing: WidgetDataStore.shared.loadBriefing())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BriefingEntry>) -> Void) {
        let entry = BriefingEntry(date: Date(), briefing: WidgetDataStore.shared.loadBriefing())
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct BriefingEntry: TimelineEntry {
    let date: Date
    let briefing: MorningBriefing?
}

struct DaybreakWidget: Widget {
    let kind: String = "DaybreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MorningTimelineProvider()) { entry in
            DaybreakWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Daily Morning Motive")
        .description("Displays your on-device morning motive and top priorities.")
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryRectangular])
    }
}

struct DaybreakWidgetEntryView: View {
    var entry: BriefingEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sun.horizon.fill")
                    .foregroundStyle(.orange)
                Text("DAYBREAK")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(entry.briefing?.motive.headline ?? "Ready for Today")
                    .font(.caption2.bold())
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }

            if let tasks = entry.briefing?.todos.prefix(2) {
                ForEach(tasks) { task in
                    HStack(spacing: 8) {
                        Button(intent: ToggleTaskCompletionIntent(taskId: task.id)) {
                            Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.completed ? .green : .secondary)
                        }
                        .buttonStyle(.plain)

                        Text(task.title)
                            .font(.subheadline)
                            .strikethrough(task.completed)
                            .foregroundStyle(task.completed ? .secondary : .primary)
                            .lineLimit(1)
                    }
                }
            } else {
                Text("Synthesizing your daily briefing...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}
