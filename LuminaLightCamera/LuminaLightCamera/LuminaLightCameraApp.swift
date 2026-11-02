//
//  LuminaLightCameraApp.swift
//  LuminaLightCamera
//
//  Created by Sanjiv Jha on 02.11.2026.
//

// LuminaLightCameraApp.swift
// Main entry point for iOS 17/18 SwiftUI App
import SwiftUI

@main
struct LuminaLightCameraApp: App {
    var body: some Scene {
        WindowGroup {
            CameraLightScannerView()
                .preferredColorScheme(.dark)
                .ignoresSafeArea()
        }
    }
}
