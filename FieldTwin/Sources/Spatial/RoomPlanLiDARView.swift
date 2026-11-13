import SwiftUI
import SceneKit
#if canImport(RoomPlan)
import RoomPlan
#endif

struct RoomPlanLiDARView: UIViewRepresentable {
    let devices: [SpatialDevice]
    let selectedDeviceId: String?
    let viewLayer: ViewLayerMode
    let onSelectDevice: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelectDevice: onSelectDevice)
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor(red: 0.043, green: 0.063, blue: 0.094, alpha: 1.0)
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X

        let scene = SCNScene()
        view.scene = scene
        setupStudioLighting(in: scene)
        setupFloorGrid(in: scene)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 45
        cameraNode.position = SCNVector3(2.4, 1.8, 2.7)
        cameraNode.look(at: SCNVector3(0, 0.85, 0))
        scene.rootNode.addChildNode(cameraNode)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        context.coordinator.scnView = view

        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        guard let scene = view.scene else { return }
        context.coordinator.onSelectDevice = onSelectDevice

        // Refresh device nodes cleanly
        scene.rootNode.childNodes
            .filter { $0.name?.hasPrefix("device_") == true }
            .forEach { $0.removeFromParentNode() }

        for device in devices {
            let node = buildDeviceNode(device, isSelected: device.id == selectedDeviceId, viewLayer: viewLayer)
            scene.rootNode.addChildNode(node)
        }
    }

    private func setupStudioLighting(in scene: SCNScene) {
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 1100
        key.light?.color = UIColor(red: 1.0, green: 0.95, blue: 0.88, alpha: 1.0)
        key.position = SCNVector3(3, 5, 3)
        key.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(key)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 420
        ambient.light?.color = UIColor(red: 0.58, green: 0.77, blue: 0.98, alpha: 1.0)
        scene.rootNode.addChildNode(ambient)
    }

    private func setupFloorGrid(in scene: SCNScene) {
        let floor = SCNFloor()
        floor.reflectivity = 0.08
        floor.firstMaterial?.diffuse.contents = UIColor(red: 0.08, green: 0.11, blue: 0.15, alpha: 1.0)
        let floorNode = SCNNode(geometry: floor)
        scene.rootNode.addChildNode(floorNode)
    }

    private func buildDeviceNode(_ device: SpatialDevice, isSelected: Bool, viewLayer: ViewLayerMode) -> SCNNode {
        let root = SCNNode()
        root.name = "device_\(device.id)"
        root.position = SCNVector3(device.position.x, device.position.y, device.position.z)

        let box = SCNBox(
            width: CGFloat(device.bounds.x),
            height: CGFloat(device.bounds.y),
            length: CGFloat(device.bounds.z),
            chamferRadius: 0.015
        )
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.roughness.contents = 0.45
        mat.metalness.contents = 0.65

        if viewLayer == .thermal {
            let t = min(1.0, max(0.0, (device.temperatureC - 18.0) / 68.0))
            mat.diffuse.contents = UIColor(red: t, green: 0.35 * (1 - t), blue: 1.0 - t, alpha: 1.0)
            mat.emission.contents = UIColor(red: t * 0.45, green: 0.08, blue: 0.12, alpha: 1.0)
        } else {
            mat.diffuse.contents = UIColor(red: 0.17, green: 0.22, blue: 0.30, alpha: viewLayer == .lidar ? 0.55 : 1.0)
        }
        box.materials = [mat]

        let meshNode = SCNNode(geometry: box)
        meshNode.name = "device_\(device.id)"
        root.addChildNode(meshNode)

        if isSelected || device.status != .nominal || viewLayer == .lidar {
            let wire = SCNBox(
                width: CGFloat(device.bounds.x + 0.04),
                height: CGFloat(device.bounds.y + 0.04),
                length: CGFloat(device.bounds.z + 0.04),
                chamferRadius: 0
            )
            let wireMat = SCNMaterial()
            wireMat.fillMode = .lines
            wireMat.diffuse.contents = statusColor(device.status, isSelected: isSelected)
            wire.materials = [wireMat]
            root.addChildNode(SCNNode(geometry: wire))
        }

        return root
    }

    private func statusColor(_ status: DeviceHealth, isSelected: Bool) -> UIColor {
        if isSelected { return .systemCyan }
        switch status {
        case .critical: return .systemRed
        case .elevated: return .systemOrange
        case .isolated: return .systemTeal
        case .nominal: return .systemGreen
        }
    }

    final class Coordinator: NSObject {
        weak var scnView: SCNView?
        var onSelectDevice: (String) -> Void

        init(onSelectDevice: @escaping (String) -> Void) {
            self.onSelectDevice = onSelectDevice
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = scnView else { return }
            let loc = gesture.location(in: view)
            let hits = view.hitTest(loc, options: nil)
            for hit in hits {
                var node: SCNNode? = hit.node
                while let current = node {
                    if let name = current.name, name.hasPrefix("device_") {
                        let devId = String(name.dropFirst("device_".count))
                        onSelectDevice(devId)
                        return
                    }
                    node = current.parent
                }
            }
        }
    }
}
