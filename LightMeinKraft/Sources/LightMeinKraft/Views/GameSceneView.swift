import SwiftUI
import SceneKit
import AppKit

public struct GameSceneView: NSViewRepresentable {
    @ObservedObject var gameState: GameState

    public func makeCoordinator() -> Coordinator {
        return Coordinator(gameState: gameState)
    }

    public func makeNSView(context: Context) -> CustomSCNView {
        let view = CustomSCNView()
        view.preferredFramesPerSecond = 60
        view.rendersContinuously = true
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false

        let scene = SCNScene()
        view.scene = scene

        let world = VoxelWorld(scene: scene)
        context.coordinator.world = world
        context.coordinator.setupCamera(in: scene)
        context.coordinator.scnView = view

        view.delegate = context.coordinator
        view.inputDelegate = context.coordinator

        // Generate Level 1 by default
        world.generateLevel1()

        return view
    }

    public func updateNSView(_ nsView: CustomSCNView, context: Context) {
        // Track level changes
        if context.coordinator.currentLevelNumber != gameState.currentLevel.levelNumber {
            context.coordinator.currentLevelNumber = gameState.currentLevel.levelNumber
            if gameState.currentLevel.levelNumber == 2 {
                context.coordinator.world?.generateLevel2()
            } else {
                context.coordinator.world?.generateLevel1()
            }
        }
    }

    // MARK: - Coordinator & Renderer Loop

    @MainActor
    public final class Coordinator: NSObject, SCNSceneRendererDelegate, InputEventDelegate {
        var gameState: GameState
        var world: VoxelWorld?
        weak var scnView: CustomSCNView?
        var cameraNode: SCNNode = SCNNode()
        var currentLevelNumber: Int = 1
        private var lastTime: TimeInterval = 0

        init(gameState: GameState) {
            self.gameState = gameState
            self.currentLevelNumber = gameState.currentLevel.levelNumber
            super.init()
        }

        func setupCamera(in scene: SCNScene) {
            let camera = SCNCamera()
            camera.zNear = 0.1
            camera.zFar = 100.0
            camera.fieldOfView = 75.0

            cameraNode.camera = camera
            cameraNode.position = SCNVector3(16, 12, 16)
            scene.rootNode.addChildNode(cameraNode)
        }

        nonisolated public func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            Task { @MainActor in
                self.updateGame(time: time)
            }
        }

        private func updateGame(time: TimeInterval) {
            if lastTime == 0 {
                lastTime = time
                return
            }
            let deltaTime = Float(time - lastTime)
            lastTime = time

            guard gameState.currentScreen == .playing, let world = world else { return }

            let input = InputManager.shared
            let player = gameState.player

            // 1. Gamepad look
            input.pollGamepadLook(player: player, deltaTime: deltaTime)

            // 2. Physics & Player Movement
            VoxelPhysics.update(
                player: player,
                world: world,
                inputDirection: input.movementVector,
                isJumping: input.isJumping,
                isSneaking: input.isSneaking,
                deltaTime: deltaTime
            )

            // 3. Update Camera to follow player's eye
            let eyeY = player.position.y + (player.isSneaking ? 1.4 : 1.65)
            cameraNode.position = SCNVector3(player.position.x, eyeY, player.position.z)
            cameraNode.eulerAngles = SCNVector3(player.pitch, player.yaw, 0)

            // 4. Update Mobs AI
            world.updateMobs(player: player, deltaTime: deltaTime)

            // 5. Check Boss health for HUD
            if let boss = world.mobs.first(where: { $0.type == .frostGrinch }) {
                self.gameState.bossHealth = boss.health
                self.gameState.bossMaxHealth = boss.maxHealth
            } else if self.gameState.currentLevel.levelNumber == 2 {
                self.gameState.bossHealth = nil
            }

            // 6. Check Player Health
            if player.health <= 0 {
                self.gameState.triggerGameOver()
            }

            // 7. Check Level 1 Portal Step-In
            if self.gameState.currentLevel.levelNumber == 1 {
                let pCoord = BlockCoordinate(Int(floor(player.position.x)), Int(floor(player.position.y)), Int(floor(player.position.z)))
                let belowCoord = BlockCoordinate(pCoord.x, pCoord.y - 1, pCoord.z)
                if world.block(at: pCoord) == .portalBlock || world.block(at: belowCoord) == .portalBlock {
                    self.gameState.advanceToLevel2()
                    self.currentLevelNumber = 2
                    world.generateLevel2()
                }
            }
        }

        // MARK: - Input Events

        public func handleLeftClick() {
            guard gameState.currentScreen == .playing, let world = world else { return }

            let player = gameState.player
            let camPos = cameraNode.position
            let lookDir = cameraDirection()

            // 1. Check Mob hit first (Melee Attack)
            for mob in world.mobs where mob.isAlive {
                let dx = Float(mob.position.x - camPos.x)
                let dy = Float((mob.position.y + 0.8) - camPos.y)
                let dz = Float(mob.position.z - camPos.z)
                let dist = sqrt(dx * dx + dy * dy + dz * dz)

                if dist < 4.0 {
                    let toMob = SCNVector3(CGFloat(dx / dist), CGFloat(dy / dist), CGFloat(dz / dist))
                    let dot = Float(lookDir.x * toMob.x + lookDir.y * toMob.y + lookDir.z * toMob.z)
                    if dot > 0.82 {
                        let damage: Float = Float(player.selectedItem?.item.attackDamage ?? 2)
                        let killed = mob.takeDamage(damage)
                        SoundManager.shared.playHurt()

                        if killed {
                            self.gameState.recordMobKilled(mob: mob)
                        }
                        return
                    }
                }
            }

            // 2. Block Mining (Raycast)
            if let hit = VoxelPhysics.raycastBlock(origin: camPos, direction: lookDir, world: world, maxDistance: 5.5) {
                if let removedType = world.removeBlock(at: hit.blockCoord) {
                    _ = player.addItem(ItemStack(block: removedType, count: 1))
                    self.gameState.recordBlockMined(type: removedType)
                }
            }
        }

        public func handleRightClick() {
            guard gameState.currentScreen == .playing, let world = world else { return }

            let player = gameState.player
            guard let selected = player.selectedItem else { return }

            // 1. Food Consumption
            if selected.item.category == .consumable {
                if player.health < player.maxHealth {
                    player.heal(4.0)
                    player.consumeSelected()
                    SoundManager.shared.playCraft()
                    self.gameState.showNotification("Ate \(selected.item.name) (+4 Hearts)!")
                }
                return
            }

            // 2. Block Placement
            if let blockType = selected.item.blockType {
                let camPos = cameraNode.position
                let lookDir = cameraDirection()

                if let hit = VoxelPhysics.raycastBlock(origin: camPos, direction: lookDir, world: world, maxDistance: 5.5) {
                    let placeCoord = hit.placeCoord

                    let pX = Int(floor(player.position.x))
                    let pY1 = Int(floor(player.position.y))
                    let pY2 = Int(floor(player.position.y + 1.0))
                    let pZ = Int(floor(player.position.z))

                    let isInsidePlayer = (placeCoord.x == pX && (placeCoord.y == pY1 || placeCoord.y == pY2) && placeCoord.z == pZ)
                    if !isInsidePlayer || !blockType.isSolid {
                        world.setBlock(at: placeCoord, type: blockType)
                        player.consumeSelected()
                        self.gameState.recordBlockPlaced(type: blockType)
                    }
                }
            }
        }

        private func cameraDirection() -> SCNVector3 {
            let yaw = gameState.player.yaw
            let pitch = gameState.player.pitch
            let cosPitch = cos(pitch)
            return SCNVector3(
                CGFloat(-sin(yaw) * cosPitch),
                CGFloat(sin(pitch)),
                CGFloat(-cos(yaw) * cosPitch)
            )
        }
    }
}

// MARK: - Custom SCNView with Mouse and Keyboard Hooks

@MainActor
public protocol InputEventDelegate: AnyObject {
    func handleLeftClick()
    func handleRightClick()
}

public final class CustomSCNView: SCNView {
    public weak var inputDelegate: InputEventDelegate?
    private var isMouseLocked: Bool = false
    private var trackingArea: NSTrackingArea?

    public override var acceptsFirstResponder: Bool { true }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        updateTrackingAreas()
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let options: NSTrackingArea.Options = [.activeInKeyWindow, .mouseMoved, .cursorUpdate]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        self.trackingArea = area
    }

    public override func keyDown(with event: NSEvent) {
        if !InputManager.shared.handleKeyDown(with: event) {
            super.keyDown(with: event)
        }
    }

    public override func keyUp(with event: NSEvent) {
        InputManager.shared.handleKeyUp(with: event)
    }

    public override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        inputDelegate?.handleLeftClick()
    }

    public override func rightMouseDown(with event: NSEvent) {
        inputDelegate?.handleRightClick()
    }

    public override func scrollWheel(with event: NSEvent) {
        InputManager.shared.handleScrollWheel(deltaY: event.deltaY)
    }

    public override func mouseMoved(with event: NSEvent) {
        guard GameState.shared.currentScreen == .playing else { return }
        let dx = Float(event.deltaX)
        let dy = Float(event.deltaY)
        InputManager.shared.handleMouseDelta(dx: dx, dy: dy, player: GameState.shared.player)
    }

    public override func mouseDragged(with event: NSEvent) {
        mouseMoved(with: event)
    }

    public override func rightMouseDragged(with event: NSEvent) {
        mouseMoved(with: event)
    }
}
