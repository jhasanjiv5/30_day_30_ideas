import Foundation
import SceneKit

public enum MobType: String, Sendable {
    case snowCreeper = "Snow Creeper"
    case frostGrinch = "Abominable Frost Grinch"
    case holidaySnowman = "Festive Snowman"
}

public final class Mob: Identifiable {
    public let id = UUID()
    public let type: MobType
    public var position: SCNVector3
    public var velocity: SCNVector3 = SCNVector3(0, 0, 0)
    public var health: Float
    public let maxHealth: Float
    public var isAlive: Bool { health > 0 }
    public var isHostile: Bool
    public var node: SCNNode?

    // Creeper specific
    public var fuseTimer: Float = 0.0
    public var isFusing: Bool = false
    public let fuseDuration: Float = 1.5

    // Boss specific
    public var attackCooldown: Float = 0.0

    public init(type: MobType, position: SCNVector3) {
        self.type = type
        self.position = position
        switch type {
        case .snowCreeper:
            self.health = 12.0
            self.maxHealth = 12.0
            self.isHostile = true
        case .frostGrinch:
            self.health = 50.0
            self.maxHealth = 50.0
            self.isHostile = true
        case .holidaySnowman:
            self.health = 20.0
            self.maxHealth = 20.0
            self.isHostile = false
        }
    }

    public func takeDamage(_ amount: Float) -> Bool {
        health = max(0, health - amount)
        // Flash red
        if let node = node {
            let redAction = SCNAction.sequence([
                SCNAction.customAction(duration: 0.15) { node, _ in
                    node.geometry?.firstMaterial?.multiply.contents = NSColor.systemRed
                },
                SCNAction.customAction(duration: 0.15) { node, _ in
                    node.geometry?.firstMaterial?.multiply.contents = NSColor.white
                }
            ])
            node.runAction(redAction)
        }
        return !isAlive
    }
}
