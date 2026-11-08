import AppKit
import GameController
import SceneKit

@MainActor
public final class InputManager: ObservableObject {
    public static let shared = InputManager()

    // Keyboard state
    private var keysDown: Set<UInt16> = []
    public var isJumping: Bool = false
    public var isSneaking: Bool = false

    // Movement vector in local space: x = strafe (-1 left, +1 right), z = forward (+1 fwd, -1 back)
    public var movementVector: SCNVector3 = SCNVector3(0, 0, 0)

    // Gamepad
    private var activeController: GCController?

    // Mouse sensitivity
    public var mouseSensitivity: Float = 0.0035

    private init() {
        setupGameController()
    }

    // Key codes
    private struct Key {
        static let w: UInt16 = 13
        static let a: UInt16 = 0
        static let s: UInt16 = 1
        static let d: UInt16 = 2
        static let up: UInt16 = 126
        static let left: UInt16 = 123
        static let down: UInt16 = 125
        static let right: UInt16 = 124
        static let space: UInt16 = 49
        static let shift: UInt16 = 56
        static let rightShift: UInt16 = 60
        static let e: UInt16 = 14
        static let i: UInt16 = 34
        static let esc: UInt16 = 53
        static let num1: UInt16 = 18
        static let num2: UInt16 = 19
        static let num3: UInt16 = 20
        static let num4: UInt16 = 21
        static let num5: UInt16 = 23
        static let num6: UInt16 = 22
        static let num7: UInt16 = 26
        static let num8: UInt16 = 28
        static let num9: UInt16 = 25
    }

    public func handleKeyDown(with event: NSEvent) -> Bool {
        let code = event.keyCode
        keysDown.insert(code)
        updateMovement()

        if code == Key.space {
            isJumping = true
            return true
        }
        if code == Key.shift || code == Key.rightShift {
            isSneaking = true
            return true
        }

        // Hotbar shortcuts 1-9
        if let slot = hotbarSlot(for: code) {
            Task { @MainActor in
                GameState.shared.player.selectedSlot = slot
            }
            return true
        }

        // Inventory toggle
        if code == Key.e || code == Key.i {
            Task { @MainActor in
                let gs = GameState.shared
                if gs.currentScreen == .playing {
                    gs.currentScreen = .inventory
                } else if gs.currentScreen == .inventory {
                    gs.currentScreen = .playing
                }
            }
            return true
        }

        // Pause toggle
        if code == Key.esc {
            Task { @MainActor in
                let gs = GameState.shared
                if gs.currentScreen == .playing {
                    gs.currentScreen = .paused
                } else if gs.currentScreen == .paused || gs.currentScreen == .inventory {
                    gs.currentScreen = .playing
                }
            }
            return true
        }

        return false
    }

    public func handleKeyUp(with event: NSEvent) {
        let code = event.keyCode
        keysDown.remove(code)
        updateMovement()

        if code == Key.space {
            isJumping = false
        }
        if code == Key.shift || code == Key.rightShift {
            isSneaking = false
        }
    }

    private func hotbarSlot(for code: UInt16) -> Int? {
        switch code {
        case Key.num1: return 0
        case Key.num2: return 1
        case Key.num3: return 2
        case Key.num4: return 3
        case Key.num5: return 4
        case Key.num6: return 5
        case Key.num7: return 6
        case Key.num8: return 7
        case Key.num9: return 8
        default: return nil
        }
    }

    private func updateMovement() {
        var strafe: Float = 0
        var fwd: Float = 0

        if keysDown.contains(Key.w) || keysDown.contains(Key.up) { fwd += 1.0 }
        if keysDown.contains(Key.s) || keysDown.contains(Key.down) { fwd -= 1.0 }
        if keysDown.contains(Key.a) || keysDown.contains(Key.left) { strafe -= 1.0 }
        if keysDown.contains(Key.d) || keysDown.contains(Key.right) { strafe += 1.0 }

        // Merge with Gamepad Left Stick if connected
        if let gamepad = activeController?.extendedGamepad {
            let lx = gamepad.leftThumbstick.xAxis.value
            let ly = gamepad.leftThumbstick.yAxis.value
            if abs(lx) > 0.15 { strafe += lx }
            if abs(ly) > 0.15 { fwd += ly }
        }

        movementVector = SCNVector3(strafe, 0, fwd)
    }

    public func handleMouseDelta(dx: Float, dy: Float, player: Player) {
        player.yaw -= dx * mouseSensitivity
        player.pitch = max(-1.45, min(1.45, player.pitch - dy * mouseSensitivity))
    }

    public func handleScrollWheel(deltaY: CGFloat) {
        Task { @MainActor in
            let gs = GameState.shared
            var slot = gs.player.selectedSlot
            if deltaY > 0 {
                slot = (slot - 1 + 9) % 9
            } else if deltaY < 0 {
                slot = (slot + 1) % 9
            }
            gs.player.selectedSlot = slot
        }
    }

    // MARK: - GameController Integration

    private func setupGameController() {
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                if let controller = GCController.controllers().first {
                    self?.configureController(controller)
                }
            }
        }

        if let first = GCController.controllers().first {
            configureController(first)
        }
    }

    private func configureController(_ controller: GCController) {
        self.activeController = controller
        guard let gamepad = controller.extendedGamepad else { return }

        // Jump (Button A)
        gamepad.buttonA.valueChangedHandler = { [weak self] _, _, pressed in
            self?.isJumping = pressed
        }

        // Sneak (Button B)
        gamepad.buttonB.valueChangedHandler = { [weak self] _, _, pressed in
            self?.isSneaking = pressed
        }

        // Inventory toggle (Button X)
        gamepad.buttonX.valueChangedHandler = { _, _, pressed in
            if pressed {
                Task { @MainActor in
                    let gs = GameState.shared
                    gs.currentScreen = (gs.currentScreen == .playing) ? .inventory : .playing
                }
            }
        }

        // Pause (Menu)
        gamepad.buttonMenu.valueChangedHandler = { _, _, pressed in
            if pressed {
                Task { @MainActor in
                    let gs = GameState.shared
                    gs.currentScreen = (gs.currentScreen == .playing) ? .paused : .playing
                }
            }
        }

        // D-Pad for hotbar cycling
        gamepad.dpad.left.valueChangedHandler = { _, _, pressed in
            if pressed {
                Task { @MainActor in
                    let gs = GameState.shared
                    gs.player.selectedSlot = (gs.player.selectedSlot - 1 + 9) % 9
                }
            }
        }
        gamepad.dpad.right.valueChangedHandler = { _, _, pressed in
            if pressed {
                Task { @MainActor in
                    let gs = GameState.shared
                    gs.player.selectedSlot = (gs.player.selectedSlot + 1) % 9
                }
            }
        }
    }

    public func pollGamepadLook(player: Player, deltaTime: Float) {
        guard let gamepad = activeController?.extendedGamepad else { return }
        let rx = gamepad.rightThumbstick.xAxis.value
        let ry = gamepad.rightThumbstick.yAxis.value
        if abs(rx) > 0.1 || abs(ry) > 0.1 {
            let sensitivity: Float = 2.5
            player.yaw -= rx * sensitivity * deltaTime
            player.pitch = max(-1.45, min(1.45, player.pitch + ry * sensitivity * deltaTime))
        }
    }
}
