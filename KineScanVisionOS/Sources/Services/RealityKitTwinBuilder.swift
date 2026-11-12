//
//  RealityKitTwinBuilder.swift
//  KineScanVisionOS
//
//  Procedural 3D RealityKit ModelEntity Generator with PBR Materials,
//  Hierarchical Child Socketing, and Exploded View Offsets.
//

import RealityKit
import UIKit

public struct RealityKitTwinBuilder {
    public static func createMachineAssembly(for machineId: String, explodeFactor: Float = 0.0) -> Entity {
        let machineRoot = Entity()
        machineRoot.name = machineId

        // 1. Bed Base
        let bedMesh = MeshResource.generateBox(width: 1.8, height: 0.32, depth: 1.6)
        var bedMat = PhysicallyBasedMaterial()
        bedMat.baseColor = .init(tint: UIColor(red: 0.15, green: 0.16, blue: 0.18, alpha: 1.0))
        bedMat.roughness = 0.75
        bedMat.metallic = 0.35
        let bedEntity = ModelEntity(mesh: bedMesh, materials: [bedMat])
        bedEntity.name = "cast-bed"
        bedEntity.position = [0, 0.16, 0]
        bedEntity.generateCollisionShapes(recursive: false)
        machineRoot.addChild(bedEntity)

        // 2. Column
        let colMesh = MeshResource.generateBox(width: 1.1, height: 1.4, depth: 0.55)
        var colMat = PhysicallyBasedMaterial()
        colMat.baseColor = .init(tint: UIColor(red: 0.22, green: 0.24, blue: 0.27, alpha: 1.0))
        colMat.roughness = 0.55
        colMat.metallic = 0.50
        let colEntity = ModelEntity(mesh: colMesh, materials: [colMat])
        colEntity.name = "column-gantry"
        colEntity.position = [0, 0.95 + (explodeFactor * 0.4), -0.45 - (explodeFactor * 0.3)]
        colEntity.generateCollisionShapes(recursive: false)
        machineRoot.addChild(colEntity)

        // 3. Spindle Head (Carbide Nose + Motor)
        let spindleRoot = Entity()
        spindleRoot.name = "spindle-head"
        spindleRoot.position = [0, 1.1 + (explodeFactor * 0.5), 0.1 + (explodeFactor * 0.4)]

        let spindleBodyMesh = MeshResource.generateBox(width: 0.58, height: 0.52, depth: 0.48)
        var spindleMat = PhysicallyBasedMaterial()
        spindleMat.baseColor = .init(tint: UIColor(red: 0.78, green: 0.80, blue: 0.84, alpha: 1.0))
        spindleMat.roughness = 0.25
        spindleMat.metallic = 0.90
        let spindleBody = ModelEntity(mesh: spindleBodyMesh, materials: [spindleMat])
        spindleRoot.addChild(spindleBody)

        let noseMesh = MeshResource.generateCylinder(height: 0.28, radius: 0.12)
        let noseEntity = ModelEntity(mesh: noseMesh, materials: [spindleMat])
        noseEntity.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        noseEntity.position = [0, -0.05, 0.28]
        spindleRoot.addChild(noseEntity)
        spindleRoot.generateCollisionShapes(recursive: true)
        machineRoot.addChild(spindleRoot)

        // 4. Rotary Trunnion Table
        let tableMesh = MeshResource.generateCylinder(height: 0.14, radius: 0.38)
        var tableMat = PhysicallyBasedMaterial()
        tableMat.baseColor = .init(tint: UIColor(red: 0.72, green: 0.75, blue: 0.78, alpha: 1.0))
        tableMat.roughness = 0.45
        tableMat.metallic = 0.65
        let tableEntity = ModelEntity(mesh: tableMesh, materials: [tableMat])
        tableEntity.name = "rotary-table"
        tableEntity.position = [0, 0.38 + (explodeFactor * 0.25), 0.42 + (explodeFactor * 0.55)]
        tableEntity.generateCollisionShapes(recursive: false)
        machineRoot.addChild(tableEntity)

        // 5. Coolant Manifold
        let coolantMesh = MeshResource.generateBox(width: 0.32, height: 0.42, depth: 0.62)
        var brassMat = PhysicallyBasedMaterial()
        brassMat.baseColor = .init(tint: UIColor(red: 0.85, green: 0.68, blue: 0.35, alpha: 1.0))
        brassMat.roughness = 0.35
        brassMat.metallic = 0.85
        let coolantEntity = ModelEntity(mesh: coolantMesh, materials: [brassMat])
        coolantEntity.name = "coolant-manifold"
        coolantEntity.position = [0.82 + (explodeFactor * 0.6), 0.48 + (explodeFactor * 0.15), -0.2]
        coolantEntity.generateCollisionShapes(recursive: false)
        machineRoot.addChild(coolantEntity)

        return machineRoot
    }

    public static func updateExplodedOffsets(entity: Entity, explodeFactor: Float) {
        if let col = entity.findEntity(named: "column-gantry") {
            col.position = [0, 0.95 + (explodeFactor * 0.4), -0.45 - (explodeFactor * 0.3)]
        }
        if let spindle = entity.findEntity(named: "spindle-head") {
            spindle.position = [0, 1.1 + (explodeFactor * 0.5), 0.1 + (explodeFactor * 0.4)]
        }
        if let table = entity.findEntity(named: "rotary-table") {
            table.position = [0, 0.38 + (explodeFactor * 0.25), 0.42 + (explodeFactor * 0.55)]
        }
        if let coolant = entity.findEntity(named: "coolant-manifold") {
            coolant.position = [0.82 + (explodeFactor * 0.6), 0.48 + (explodeFactor * 0.15), -0.2]
        }
    }

    public static func createIsolatedPartEntity(for partId: String) -> Entity {
        let root = Entity()
        let mesh = MeshResource.generateCylinder(height: 0.35, radius: 0.18)
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: UIColor(red: 0.85, green: 0.70, blue: 0.35, alpha: 1.0))
        mat.roughness = 0.28
        mat.metallic = 0.85
        let model = ModelEntity(mesh: mesh, materials: [mat])
        model.position = [0, 0.18, 0]
        root.addChild(model)
        return root
    }
}
