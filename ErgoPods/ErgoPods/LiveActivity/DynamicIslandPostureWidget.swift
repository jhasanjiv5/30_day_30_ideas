//
//  DynamicIslandPostureWidget.swift
//  ErgoPods
//
//  ActivityKit & WidgetKit implementation for iOS 18+ Dynamic Island
//

import ActivityKit
import WidgetKit
import SwiftUI

public struct PostureActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var pitchAngle: Double
        public var sittingMinutes: Int
        public var isSeverePosture: Bool
        public var heartRate: Double
    }
    public var userName: String
}

public struct DynamicIslandPostureWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: PostureActivityAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "headphones")
                    .foregroundColor(context.state.isSeverePosture ? .red : .green)
                VStack(alignment: .leading) {
                    Text(context.state.isSeverePosture ? "Tech Neck Detected: Tilt Up" : "Spine Aligned")
                        .font(.headline)
                    Text("\(context.state.sittingMinutes)m seated • \(Int(context.state.heartRate)) BPM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .activityBackgroundTint(.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("\(Int(context.state.pitchAngle))° Pitch", systemImage: "headphones")
                        .font(.caption2)
                        .foregroundColor(context.state.isSeverePosture ? .red : .green)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.sittingMinutes)m sit")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.isSeverePosture ? "⚠️ Roll shoulders back and tuck chin" : "Optimal ergonomic posture")
                        .font(.caption)
                }
            } compactLeading: {
                Image(systemName: "headphones")
                    .foregroundColor(context.state.isSeverePosture ? .red : .green)
            } compactTrailing: {
                Text("\(Int(context.state.pitchAngle))°")
                    .font(.caption2.bold())
            } minimal: {
                Image(systemName: "headphones")
                    .foregroundColor(context.state.isSeverePosture ? .red : .green)
            }
        }
    }
}
