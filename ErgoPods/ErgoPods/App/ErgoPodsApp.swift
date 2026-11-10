//
//  ErgoPodsApp.swift
//  ErgoPods
//
//  Created for iOS 18+ (Xcode 16+)
//  AI Posture Corrector & Real-Time Physiotherapist using AirPods CoreMotion
//

import SwiftUI

@main
struct ErgoPodsApp: App {
    @StateObject private var motionManager = HeadphoneMotionManager()
    @StateObject private var healthManager = AppleHealthKitManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(motionManager)
                .environmentObject(healthManager)
                .preferredColorScheme(.dark)
        }
    }
}
