//
//  AirPodsOnboardingView.swift
//  ErgoPods
//
//  Interactive AirPods Sensor Onboarding & Diagnostic Verification
//

import SwiftUI

struct AirPodsOnboardingView: View {
    @EnvironmentObject var motion: HeadphoneMotionManager
    @Binding var isPresented: Bool
    @State private var step = 1
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "headphones.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
                
                VStack(spacing: 6) {
                    Text("AirPods Sensor Calibration")
                        .font(.title2.bold())
                    Text("Live 60 Hz CoreMotion Diagnostics")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Live Sensor Telemetry
                HStack(spacing: 16) {
                    VStack {
                        Text("Pitch (Tilt)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f°", motion.pitchDegrees))
                            .font(.headline.monospaced())
                    }
                    VStack {
                        Text("Lateral Roll")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f°", motion.rollDegrees))
                            .font(.headline.monospaced())
                    }
                    VStack {
                        Text("Axial Yaw")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f°", motion.yawDegrees))
                            .font(.headline.monospaced())
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                
                // 3-Step Verification List
                VStack(alignment: .leading, spacing: 12) {
                    testRow(stepNum: 1, title: "Sit Tall (Neutral Spine)", isDone: abs(motion.pitchDegrees) <= 6)
                    testRow(stepNum: 2, title: "Nod Down (> 15°)", isDone: motion.pitchDegrees > 15)
                    testRow(stepNum: 3, title: "Turn Head Right (> 12°)", isDone: abs(motion.yawDegrees) > 12)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                
                Spacer()
                
                Button("Complete Onboarding & Start Monitoring") {
                    motion.calibrateNeutralSpine()
                    isPresented = false
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(16)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { isPresented = false }
                }
            }
        }
    }
    
    private func testRow(stepNum: Int, title: String, isDone: Bool) -> some View {
        HStack {
            Text("\(stepNum)")
                .font(.caption.bold())
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.blue.opacity(0.2)))
                .foregroundColor(.blue)
            Text(title)
                .font(.subheadline)
            Spacer()
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isDone ? .green : .secondary)
        }
    }
}
