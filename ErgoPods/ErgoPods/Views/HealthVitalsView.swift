//
//  HealthVitalsView.swift
//  ErgoPods
//
//  Apple HealthKit Activity Rings & Vitals Synchronization
//

import SwiftUI

struct HealthVitalsView: View {
    @EnvironmentObject var health: AppleHealthKitManager
    @EnvironmentObject var motion: HeadphoneMotionManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Heart Rate Vitals Card
                VStack(spacing: 8) {
                    HStack {
                        Label("Heart Rate Vitals", systemImage: "heart.fill")
                            .font(.headline)
                            .foregroundColor(.pink)
                        Spacer()
                        Text(health.currentHeartRate > 105 ? "High BPM • Rest Advised" : "Normal Autonomic Tone")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(health.currentHeartRate > 105 ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
                            .foregroundColor(health.currentHeartRate > 105 ? .red : .green)
                            .cornerRadius(8)
                    }
                    
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(Int(health.currentHeartRate))")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        Text("BPM")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Resting: \(Int(health.restingHeartRate)) BPM")
                            Text("HRV: 48 ms")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
                
                // Continuous Sitting Duration
                VStack(spacing: 8) {
                    HStack {
                        Label("Continuous Sitting", systemImage: "chair.fill")
                            .font(.headline)
                            .foregroundColor(.blue)
                        Spacer()
                        Text("\(Int(motion.continuousSittingSeconds / 60)) / 50 min")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: min(1.0, (motion.continuousSittingSeconds / 60.0) / 50.0))
                        .tint(motion.continuousSittingSeconds / 60.0 >= 50 ? .red : .blue)
                    
                    HStack {
                        Text(motion.continuousSittingSeconds / 60.0 >= 50
                             ? "Sedentary threshold reached. Time to stand & stretch!"
                             : "Healthy intervertebral disc hydration.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Stood Up") {
                            motion.resetSittingTimer()
                        }
                        .font(.caption.bold())
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
                
                // Workday Steps Pedometer
                VStack(spacing: 8) {
                    HStack {
                        Label("Workday Walking Steps", systemImage: "figure.walk")
                            .font(.headline)
                            .foregroundColor(.green)
                        Spacer()
                        Text("\(health.stepCountToday) / 8,000")
                            .font(.headline.monospaced())
                    }
                    
                    ProgressView(value: min(1.0, Double(health.stepCountToday) / 8000.0))
                        .tint(.green)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
            }
            .padding()
        }
    }
}
