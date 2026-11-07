import Foundation
import CoreGraphics
import GameController
import AppKit

public final class InputManager: ObservableObject {
    public static let shared = InputManager()
    
    // Separate vectors to avoid collision
    private var keyboardVector: CGPoint = .zero
    private var gamepadVector: CGPoint = .zero
    
    public var moveVector: CGPoint {
        if hypot(gamepadVector.x, gamepadVector.y) > 0.15 {
            return gamepadVector
        }
        return keyboardVector
    }
    
    public var isActionTriggered: Bool = false
    public var isConsultTriggered: Bool = false
    public var isPauseTriggered: Bool = false
    public var isMuteTriggered: Bool = false
    
    // Key states
    private var keyUp: Bool = false
    private var keyDown: Bool = false
    private var keyLeft: Bool = false
    private var keyRight: Bool = false
    
    private init() {
        setupGameControllers()
    }
    
    private func setupGameControllers() {
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let controller = notification.object as? GCController {
                self?.configureController(controller)
            }
        }
        
        for controller in GCController.controllers() {
            configureController(controller)
        }
    }
    
    private func configureController(_ controller: GCController) {
        controller.extendedGamepad?.valueChangedHandler = { [weak self] gamepad, _ in
            guard let self = self else { return }
            let x = CGFloat(gamepad.leftThumbstick.xAxis.value)
            let y = CGFloat(gamepad.leftThumbstick.yAxis.value)
            
            if hypot(x, y) > 0.15 {
                self.gamepadVector = CGPoint(x: x, y: y)
            } else {
                self.gamepadVector = .zero
            }
            
            if gamepad.buttonA.isPressed || gamepad.buttonX.isPressed {
                self.isActionTriggered = true
            }
            if gamepad.buttonB.isPressed || gamepad.buttonY.isPressed {
                self.isConsultTriggered = true
            }
            if gamepad.buttonMenu.isPressed {
                self.isPauseTriggered = true
            }
        }
    }
    
    public func handleKeyDown(event: NSEvent) {
        let keyCode = event.keyCode
        let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
        
        // Auto-start game if in ready phase
        Task { @MainActor in
            if GameState.shared.phase == .ready {
                GameState.shared.startGame()
            }
        }
        
        // Movement: Up
        if keyCode == 126 || keyCode == 13 || chars == "w" {
            keyUp = true
        }
        // Movement: Down
        if keyCode == 125 || keyCode == 1 || chars == "s" {
            keyDown = true
        }
        // Movement: Left
        if keyCode == 123 || keyCode == 0 || chars == "a" {
            keyLeft = true
        }
        // Movement: Right
        if keyCode == 124 || keyCode == 2 || chars == "d" {
            keyRight = true
        }
        // Action: Spacebar or Return
        if keyCode == 49 || keyCode == 36 || chars == " " {
            isActionTriggered = true
        }
        // Consult AI: R
        if keyCode == 15 || chars == "r" {
            isConsultTriggered = true
        }
        // Pause: P or Escape
        if keyCode == 35 || keyCode == 53 || chars == "p" {
            isPauseTriggered = true
        }
        // Mute: M
        if keyCode == 46 || chars == "m" {
            isMuteTriggered = true
        }
        
        updateKeyboardVector()
    }
    
    public func handleKeyUp(event: NSEvent) {
        let keyCode = event.keyCode
        let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
        
        if keyCode == 126 || keyCode == 13 || chars == "w" {
            keyUp = false
        }
        if keyCode == 125 || keyCode == 1 || chars == "s" {
            keyDown = false
        }
        if keyCode == 123 || keyCode == 0 || chars == "a" {
            keyLeft = false
        }
        if keyCode == 124 || keyCode == 2 || chars == "d" {
            keyRight = false
        }
        
        updateKeyboardVector()
    }
    
    // Legacy support for direct keyCode calls
    public func handleKeyDown(keyCode: UInt16) {
        Task { @MainActor in
            if GameState.shared.phase == .ready {
                GameState.shared.startGame()
            }
        }
        switch keyCode {
        case 13, 126: keyUp = true
        case 1, 125:  keyDown = true
        case 0, 123:  keyLeft = true
        case 2, 124:  keyRight = true
        case 49, 36:  isActionTriggered = true
        case 15:      isConsultTriggered = true
        case 35, 53:  isPauseTriggered = true
        case 46:      isMuteTriggered = true
        default: break
        }
        updateKeyboardVector()
    }
    
    public func handleKeyUp(keyCode: UInt16) {
        switch keyCode {
        case 13, 126: keyUp = false
        case 1, 125:  keyDown = false
        case 0, 123:  keyLeft = false
        case 2, 124:  keyRight = false
        default: break
        }
        updateKeyboardVector()
    }
    
    private func updateKeyboardVector() {
        var dx: CGFloat = 0
        var dy: CGFloat = 0
        
        if keyLeft { dx -= 1.0 }
        if keyRight { dx += 1.0 }
        if keyDown { dy -= 1.0 }
        if keyUp { dy += 1.0 }
        
        if dx != 0 && dy != 0 {
            dx *= 0.7071
            dy *= 0.7071
        }
        
        self.keyboardVector = CGPoint(x: dx, y: dy)
    }
    
    public func consumeAction() -> Bool {
        let val = isActionTriggered
        isActionTriggered = false
        return val
    }
    
    public func consumeConsult() -> Bool {
        let val = isConsultTriggered
        isConsultTriggered = false
        return val
    }
    
    public func consumePause() -> Bool {
        let val = isPauseTriggered
        isPauseTriggered = false
        return val
    }
    
    public func consumeMute() -> Bool {
        let val = isMuteTriggered
        isMuteTriggered = false
        return val
    }
}
