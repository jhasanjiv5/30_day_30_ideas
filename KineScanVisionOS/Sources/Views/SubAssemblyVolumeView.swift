//
//  SubAssemblyVolumeView.swift
//  KineScanVisionOS
//
//  Dedicated visionOS Volumetric Window (.windowStyle(.volumetric))
//  for 1:1 scale hands-on tabletop inspection.
//

import SwiftUI
import RealityKit

struct SubAssemblyVolumeView: View {
    let partId: String
    @Environment(MachineTwinModel.self) private var model
    @State private var rotationAngle: Double = 0

    var body: some View {
        VStack {
            RealityView { content in
                let subPart = RealityKitTwinBuilder.createIsolatedPartEntity(for: partId)
                subPart.name = "IsolatedPart"
                content.add(subPart)
            } update: { content in
                if let part = content.entities.first {
                    part.transform.rotation = simd_quatf(angle: Float(rotationAngle), axis: [0, 1, 0])
                }
            }
            .gesture(
                RotateGesture3D()
                    .onChanged { value in
                        rotationAngle += value.rotation.angle.radians * 0.02
                    }
            )

            HStack {
                VStack(alignment: .leading) {
                    Text(model.getPartName(for: partId))
                        .font(.headline)
                    Text("1:1 Volumetric Inspection")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Slider(value: $rotationAngle, in: 0...Double.pi * 2)
                    .frame(width: 140)
            }
            .padding()
            .glassBackgroundEffect()
        }
        .padding()
    }
}
