//
//  KineScanVisionOSApp.swift
//  KineScanVisionOS
//
//  Created for visionOS 2.0+ (Apple Vision Pro)
//  Industrial 3D Machine Scanner & Collaborative Twin
//

import SwiftUI
import RealityKit

@main
struct KineScanVisionOSApp: App {
    @State private var model = MachineTwinModel(
        machineId: "hmc-500x",
        machineName: "5-Axis Horizontal Machining Center",
        modelNumber: "HMC-500X",
        serialNumber: "MK-500X-88412",
        protocolEndpoint: "opc.tcp://10.24.18.42:4840/cell04/hmc500x"
    )
    
    @State private var immersionStyle: ImmersionStyle = .mixed

    var body: some SwiftUI.Scene {
        // Primary 2D Spatial Dashboard Window
        WindowGroup(id: "MachineDashboard") {
            ContentView()
                .environment(model)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1280, height: 800)

        // 3D Volumetric Window for tabletop sub-assembly inspection (1:1 scale)
        WindowGroup(id: "SubAssemblyVolume", for: String.self) { $partId in
            SubAssemblyVolumeView(partId: partId ?? "spindle-head")
                .environment(model)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.65, height: 0.65, depth: 0.65, in: .meters)

        // Full Mixed-Immersion RealityKit Space (Anchored on factory floor)
        ImmersiveSpace(id: "MachineTwinImmersiveSpace") {
            ImmersiveMachineSpace()
                .environment(model)
        }
        .immersionStyle(selection: $immersionStyle, in: .mixed, .progressive, .full)
    }
}
