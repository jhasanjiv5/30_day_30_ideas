//
//  ArtLensApp.swift
//  ArtLens
//
//  Created by Sanjiv Jha on 29.10.2026.
//

import SwiftUI

@main
struct ArtLensApp: App {
    var body: some Scene {
        WindowGroup {
            MainCameraView()
                .preferredColorScheme(.dark)
        }
    }
}
