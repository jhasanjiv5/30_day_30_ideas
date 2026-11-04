//
//  ContentView.swift
//  AquaWatch Watch App
//

import SwiftUI
import WatchKit

struct ContentView: View {
    @EnvironmentObject var motionClassifier: MotionGestureClassifier
    @EnvironmentObject var healthKitManager: HealthKitManager
    
    @State private var todayTotalMl: Int = 1250
    @State private var dailyGoalMl: Int = 2500
    @State private var showVerificationSheet = false
    @State private var lastLoggedMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    // Circular Progress Ring
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 10)
                        
                        Circle()
                            .trim(from: 0, to: min(1.0, Double(todayTotalMl) / Double(dailyGoalMl)))
                            .stroke(
                                LinearGradient(colors: [.cyan, .mint], startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.6), value: todayTotalMl)
                        
                        VStack(spacing: 1) {
                            Text("\(todayTotalMl)")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text("/ \(dailyGoalMl) ml")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 95, height: 95)
                    .padding(.top, 4)
                    
                    // Live Gyro Readings
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("PITCH")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.1f°", motionClassifier.currentPitch))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                        
                        HStack {
                            Text("ROLL")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.1f°", motionClassifier.currentRoll))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.mint)
                        }
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    
                    // 1-Tap Quick Add Button
                    Button {
                        logWaterAmount(250, source: "Manual 1-Tap")
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Quick +250ml")
                        }
                        .font(.system(size: 12, weight: .bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)

                    NavigationLink {
                        AboutAquaWatchView()
                    } label: {
                        Label("Why AquaWatch?", systemImage: "heart.text.square")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    
                    if let msg = lastLoggedMessage {
                        Text(msg)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.mint)
                            .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 6)
            }
            .navigationTitle("AquaWatch")
            .sheet(isPresented: $showVerificationSheet) {
                AutoLogVerificationView(
                    classifier: motionClassifier,
                    isPresented: $showVerificationSheet
                ) { confirmedMl, beverage in
                    logWaterAmount(
                        confirmedMl,
                        source: "Wrist Motion Auto-Log (\(beverage.rawValue))"
                    )
                }
            }
            .onChange(of: motionClassifier.detectedGesture != nil) { _, isDetected in
                if isDetected {
                    showVerificationSheet = true
                }
            }
        }
    }
    
    private func logWaterAmount(_ ml: Int, source: String) {
        WKInterfaceDevice.current().play(.success)
        todayTotalMl += ml
        lastLoggedMessage = "Logged +\(ml)ml (\(source))"
        
        Task {
            do {
                try await healthKitManager.logWater(milliliters: ml)
            } catch {
                print("Failed to save to HealthKit: \(error)")
            }
        }
    }
}