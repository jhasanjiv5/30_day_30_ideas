//
//  RoutineSettingsView.swift
//  Sanctuary
//
//  Evening Habit & Notification Schedule Settings
//

import SwiftUI

struct RoutineSettingsView: View {
    @State private var reminderDate: Date = {
        var comp = DateComponents()
        comp.hour = 21
        comp.minute = 0
        return Calendar.current.date(from: comp) ?? Date()
    }()
    @State private var notificationsEnabled: Bool = true
    @State private var testSent: Bool = false

    var body: some View {
        Form {
            Section("Nightly Habit Loop") {
                Toggle("Enable Evening Reminder", isOn: $notificationsEnabled)
                    .tint(.indigo)

                if notificationsEnabled {
                    DatePicker("Check-in Time", selection: $reminderDate, displayedComponents: .hourAndMinute)
                        .onChange(of: reminderDate) { _, newDate in
                            let comp = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                            Task {
                                await NotificationManager.shared.scheduleNightlyReminder(
                                    hour: comp.hour ?? 21,
                                    minute: comp.minute ?? 0
                                )
                            }
                        }
                }
            }

            Section("Test Reminder") {
                Button {
                    Task {
                        await NotificationManager.shared.triggerTestNotification()
                        testSent = true
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        testSent = false
                    }
                } label: {
                    HStack {
                        Image(systemName: "bell.badge")
                        Text(testSent ? "Notification Dispatched!" : "Trigger Test Notification (2s)")
                    }
                }
            }

            Section("Apple Ecosystem Integration") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Apple Journal Shortcuts")
                        .font(.headline)
                    Text("To log directly into Apple Journal with 1 tap, install the 'Log to Apple Journal' action in the iOS Shortcuts app. Sanctuary automatically routes Markdown payloads into it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
                .padding(.vertical, 4)
            }

            Section("Privacy & Architecture") {
                LabeledContent("Model Execution", value: "On-Device Neural Engine")
                LabeledContent("Local Storage", value: "SwiftData (Hardware Encrypted)")
                LabeledContent("Cloud Transmissions", value: "0 bytes")
                LabeledContent("Therapeutic Method", value: "Rogerian Person-Centered")
            }
        }
        .navigationTitle("Routine")
    }
}
