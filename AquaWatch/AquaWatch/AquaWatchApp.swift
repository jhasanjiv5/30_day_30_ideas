//
//  AquaWatchApp.swift
//  AquaWatch Watch App
//
//  Created for watchOS 10 and watchOS 11
//

import SwiftUI
import HealthKit

@main
struct AquaWatchApp: App {
    @StateObject private var motionClassifier = MotionGestureClassifier()
    @StateObject private var healthKitManager = HealthKitManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(motionClassifier)
                .environmentObject(healthKitManager)
                .task {
                    // Request HealthKit read/write permissions on launch
                    _ = await healthKitManager.requestAuthorization()
                    // Start real-time 50Hz CoreMotion gyro monitoring
                    motionClassifier.startMonitoring()
                }
        }
    }
}