//
//  OrnamentsToolbarView.swift
//  KineScanVisionOS
//
//  Bottom Ornament Toolbar providing quick tactile control of 3D scan sweeps,
//  exploded views, thermal shaders, and spatial annotations.
//

import SwiftUI

struct OrnamentsToolbarView: View {
    @Environment(MachineTwinModel.self) private var model

    var body: some View {
        HStack(spacing: 20) {
            // LiDAR Scan Button
            Button {
                model.startLidarScan()
            } label: {
                Label(model.isScanning ? "Scanning \(Int(model.scanProgress))%" : "3D LiDAR Scan", systemImage: "point.3.filled.connected.trianglepath.dotted")
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isScanning)

            Divider()
                .frame(height: 24)

            // Exploded View Slider
            HStack(spacing: 8) {
                Image(systemName: "square.split.3x3")
                Text("Explode:")
                    .font(.caption)
                Slider(value: Bindable(model).explodeProgress, in: 0...1)
                    .frame(width: 110)
                Text("\(Int(model.explodeProgress * 100))%")
                    .font(.caption2.monospacedDigit())
                    .frame(width: 32)
            }

            Divider()
                .frame(height: 24)

            // Pin Drop Tool
            Button {
                model.isDroppingPin.toggle()
            } label: {
                Label("Anchor Pin", systemImage: model.isDroppingPin ? "pin.fill" : "pin")
            }
            .buttonStyle(.bordered)
            .tint(model.isDroppingPin ? .yellow : .primary)

            // Fault Injection Selector
            Picker("Scenario", selection: Bindable(model).activeFaultScenario) {
                Text("Nominal").tag("nominal")
                Text("Bearing Spall").tag("spindle_spall")
                Text("Valve Stiction").tag("valve_stiction")
                Text("Ballscrew Backlash").tag("ballscrew_backlash")
            }
            .pickerStyle(.menu)
        }
    }
}
