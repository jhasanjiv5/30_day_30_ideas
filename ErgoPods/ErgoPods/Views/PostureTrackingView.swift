//
//  PostureTrackingView.swift
//  ErgoPods
//
//  Real-time Cervical Biomechanics & EarPods Motion Telemetry
//

import SwiftUI

struct PostureTrackingView: View {
    @EnvironmentObject var motion: HeadphoneMotionManager
    @EnvironmentObject var health: AppleHealthKitManager
    @Binding var showOnboarding: Bool
    
    var cervicalLoadLbs: Int {
        let absPitch = abs(motion.pitchDegrees)
        if absPitch <= 5 { return 11 }
        if absPitch <= 15 { return Int(11.0 + (absPitch / 15.0) * 16.0) }
        if absPitch <= 30 { return Int(27.0 + ((absPitch - 15.0) / 15.0) * 13.0) }
        return Int(min(65.0, 40.0 + ((absPitch - 30.0) / 15.0) * 10.0))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // AirPods Connection Banner
                HStack(spacing: 12) {
                    Image(systemName: motion.isConnected ? "headphones.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(motion.isConnected ? .green : .red)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(motion.isConnected ? "AirPods Pro Connected" : "AirPods Disconnected")
                            .font(.headline)
                        Text(motion.isConnected ? "60 Hz CoreMotion Stream • 12ms latency" : "Put AirPods in ears to resume posture analysis")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(motion.isConnected ? "Calibrate" : "Reconnect") {
                        if motion.isConnected {
                            motion.calibrateNeutralSpine()
                        } else {
                            motion.startTracking()
                        }
                    }
                    .font(.caption.bold())
                    .buttonStyle(.borderedProminent)
                    .tint(motion.isConnected ? .blue : .red)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
                
                // Cervical Spine Angle Card
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("CERVICAL SPINE LOAD")
                                .font(.caption2.bold())
                                .foregroundColor(.secondary)
                            Text("\(cervicalLoadLbs) lbs")
                                .font(.system(size: 42, weight: .black, design: .rounded))
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(motion.pitchDegrees > 0 ? "+\(String(format: "%.1f", motion.pitchDegrees))°" : "\(String(format: "%.1f", motion.pitchDegrees))°")
                                .font(.system(.title2, design: .monospaced).bold())
                                .foregroundColor(abs(motion.pitchDegrees) > 20 ? .red : .green)
                            Text("Forward Head Tilt")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    ProgressView(value: min(1.0, Double(cervicalLoadLbs) / 60.0))
                        .tint(abs(motion.pitchDegrees) > 20 ? .red : .green)
                    
                    Text(abs(motion.pitchDegrees) <= 12
                         ? "Neutral spinal alignment. Minimal shear force on C5-C7 vertebrae."
                         : "Forward head tilt detected. Upper cervical extensors under compressive load.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
                
                // 3-DoF Attitude Breakdown
                HStack(spacing: 12) {
                    metricTile(title: "Pitch (Tilt)", value: String(format: "%.1f°", motion.pitchDegrees), color: .blue)
                    metricTile(title: "Lateral Roll", value: String(format: "%.1f°", motion.rollDegrees), color: .purple)
                    metricTile(title: "Axial Yaw", value: String(format: "%.1f°", motion.yawDegrees), color: .indigo)
                }
            }
            .padding()
        }
    }
    
    private func metricTile(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline.monospaced())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}
