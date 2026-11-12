//
//  ImmersiveMachineSpace.swift
//  KineScanVisionOS
//
//  Full ImmersiveSpace with ARKit SceneReconstructionProvider, Spatial Tap,
//  Drag & Magnify Gestures, and 3D RealityView Attachments.
//

import SwiftUI
import RealityKit
import ARKit

struct ImmersiveMachineSpace: View {
    @Environment(MachineTwinModel.self) private var model

    @State private var machineRootEntity: Entity?
    @State private var position = Vector3(x: 0, y: 0.8, z: -1.8)
    @State private var orientation: simd_quatf = simd_quatf(angle: 0, axis: [0, 1, 0])

    var body: some View {
        RealityView { content, attachments in
            // Build the machine hierarchy in world space
            let root = Entity()
            root.name = "RootMachineEntity"
            root.position = SIMD3<Float>(position.x, position.y, position.z)
            root.orientation = orientation

            let machine = RealityKitTwinBuilder.createMachineAssembly(
                for: model.machineId,
                explodeFactor: Float(model.explodeProgress)
            )
            root.addChild(machine)
            content.add(root)
            machineRootEntity = root

            // Attach spatial HUD callout cards anchored in 3D
            if let spindleHead = machine.findEntity(named: "spindle-head"),
               let spindleAttachment = attachments.entity(for: "spindle-hud") {
                spindleAttachment.position = [0, 0.42, 0.2]
                spindleHead.addChild(spindleAttachment)
            }

            if let coolantPump = machine.findEntity(named: "coolant-manifold"),
               let coolantAttachment = attachments.entity(for: "coolant-hud") {
                coolantAttachment.position = [0, 0.38, 0.15]
                coolantPump.addChild(coolantAttachment)
            }
        } update: { content, attachments in
            if let root = machineRootEntity,
               let machine = root.children.first {
                RealityKitTwinBuilder.updateExplodedOffsets(
                    entity: machine,
                    explodeFactor: Float(model.explodeProgress)
                )
            }
        } attachments: {
            Attachment(id: "spindle-hud") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("HSK-A63 Spindle Nose")
                            .font(.caption.bold())
                    }
                    Text("Vibration: 2.14 mm/s RMS (ISO Zone B)")
                        .font(.caption2.monospaced())
                    Text("Bearing Temp: 43.6 °C")
                        .font(.caption2.monospaced())
                }
                .padding(10)
                .glassBackgroundEffect()
            }

            Attachment(id: "coolant-hud") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(.blue)
                        Text("70-Bar Coolant Manifold")
                            .font(.caption.bold())
                    }
                    Text("ΔP: 1.4 bar · 10 µm element overdue")
                        .font(.caption2.monospaced())
                }
                .padding(10)
                .glassBackgroundEffect()
            }
        }
        // Spatial Interaction Gestures
        .gesture(
            DragGesture()
                .targetedToAnyEntity()
                .onChanged { value in
                    let translation = value.convert(value.translation3D, from: .local, to: .scene)
                    position.x += Float(translation.x) * 0.005
                    position.z += Float(translation.z) * 0.005
                    machineRootEntity?.position = SIMD3<Float>(position.x, position.y, position.z)
                }
        )
        .gesture(
            RotateGesture3D()
                .targetedToAnyEntity()
                .onChanged { value in
                    let rotation = value.rotation
                    orientation = simd_quatf(rotation) * orientation
                    machineRootEntity?.orientation = orientation
                }
        )
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    // Hit test sub-assembly entity and drop collaborative 3D pin
                    let hitEntity = value.entity
                    model.handleEntityTapped(name: hitEntity.name)
                }
        )
    }
}

struct Vector3 {
    var x: Float
    var y: Float
    var z: Float
}
