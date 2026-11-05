import SwiftUI

public struct SchedulerView: View {
    @EnvironmentObject var scheduler: PostSchedulerStore

    public var body: some View {
        NavigationStack {
            List(scheduler.posts) { post in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(post.platform).font(.caption.bold()).foregroundStyle(.indigo)
                        Spacer()
                        Label("Safe", systemImage: "shield.checkmark.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                    Text(post.hook).font(.headline)
                    Text(post.caption).font(.subheadline).foregroundStyle(.secondary)
                    HStack {
                        Label(post.scheduledTime, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(post.pillar).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
            .navigationTitle("Schedule & Privacy")
        }
    }
}
