import Foundation
import SceneKit

public struct BlockCoordinate: Hashable, Sendable {
    public let x: Int
    public let y: Int
    public let z: Int

    public init(_ x: Int, _ y: Int, _ z: Int) {
        self.x = x
        self.y = y
        self.z = z
    }
}

@MainActor
public final class VoxelPhysics {
    public static let gravity: Float = -22.0
    public static let jumpSpeed: Float = 8.5
    public static let moveSpeed: Float = 6.0
    public static let sneakSpeed: Float = 3.0

    public static let playerWidth: CGFloat = 0.6
    public static let playerHeight: CGFloat = 1.8

    public static func update(
        player: Player,
        world: VoxelWorld,
        inputDirection: SCNVector3,
        isJumping: Bool,
        isSneaking: Bool,
        deltaTime: Float
    ) {
        let dt = min(deltaTime, 0.05) // Prevent huge deltas

        // Horizontal velocity from input relative to player yaw
        let yaw = player.yaw
        let forward = SCNVector3(-sin(yaw), 0, -cos(yaw))
        let right = SCNVector3(cos(yaw), 0, -sin(yaw))

        let speed = CGFloat(isSneaking ? sneakSpeed : moveSpeed)
        let targetVelX = (forward.x * inputDirection.z + right.x * inputDirection.x) * speed
        let targetVelZ = (forward.z * inputDirection.z + right.z * inputDirection.x) * speed

        // Smooth horizontal acceleration
        let accel = CGFloat(15.0)
        let cdt = CGFloat(dt)
        player.velocity.x += (targetVelX - player.velocity.x) * min(1.0, accel * cdt)
        player.velocity.z += (targetVelZ - player.velocity.z) * min(1.0, accel * cdt)

        // Vertical velocity (gravity)
        player.velocity.y += CGFloat(gravity * dt)
        if player.velocity.y < -30.0 { player.velocity.y = -30.0 }

        // Jump
        if isJumping && player.isOnGround {
            player.velocity.y = CGFloat(jumpSpeed)
            player.isOnGround = false
            SoundManager.shared.playStep()
        }

        // Apply movement with AABB collision resolution on each axis
        var pos = player.position

        // 1. Move X
        let newX = pos.x + player.velocity.x * cdt
        if !collides(at: SCNVector3(newX, pos.y, pos.z), world: world) {
            pos.x = newX
        } else {
            player.velocity.x = 0
        }

        // 2. Move Z
        let newZ = pos.z + player.velocity.z * cdt
        if !collides(at: SCNVector3(pos.x, pos.y, newZ), world: world) {
            pos.z = newZ
        } else {
            player.velocity.z = 0
        }

        // 3. Move Y
        let newY = pos.y + player.velocity.y * cdt
        if !collides(at: SCNVector3(pos.x, newY, pos.z), world: world) {
            pos.y = newY
            player.isOnGround = false
        } else {
            if player.velocity.y < 0 {
                player.isOnGround = true
                // Fall damage if high velocity
                if player.velocity.y < -18.0 {
                    let damage = Float(-player.velocity.y - 18.0) * 0.8
                    player.takeDamage(damage)
                    SoundManager.shared.playHurt()
                }
            }
            player.velocity.y = 0
        }

        // Footstep sounds when moving on ground
        let horizDist = sqrt(player.velocity.x * player.velocity.x + player.velocity.z * player.velocity.z)
        if player.isOnGround && horizDist > 1.5 {
            if Float.random(in: 0...1) < dt * 3.5 {
                SoundManager.shared.playStep()
            }
        }

        // Update player position
        player.position = pos
    }

    public static func collides(at pos: SCNVector3, world: VoxelWorld) -> Bool {
        let halfW = playerWidth / 2.0
        let minX = Int(floor(pos.x - halfW))
        let maxX = Int(floor(pos.x + halfW))
        let minY = Int(floor(pos.y))
        let maxY = Int(floor(pos.y + playerHeight))
        let minZ = Int(floor(pos.z - halfW))
        let maxZ = Int(floor(pos.z + halfW))

        for x in minX...maxX {
            for y in minY...maxY {
                for z in minZ...maxZ {
                    if let block = world.block(at: BlockCoordinate(x, y, z)), block.isSolid {
                        return true
                    }
                }
            }
        }
        return false
    }

    public struct RaycastHit {
        public let blockCoord: BlockCoordinate
        public let placeCoord: BlockCoordinate
        public let blockType: BlockType
        public let distance: Float
    }

    public static func raycastBlock(
        origin: SCNVector3,
        direction: SCNVector3,
        world: VoxelWorld,
        maxDistance: Float = 6.0
    ) -> RaycastHit? {
        let step: CGFloat = 0.05
        var current = origin
        var prevCoord = BlockCoordinate(Int(floor(origin.x)), Int(floor(origin.y)), Int(floor(origin.z)))
        var traveled: CGFloat = 0.0

        let normDir = normalize(direction)

        while traveled < CGFloat(maxDistance) {
            current = SCNVector3(
                current.x + normDir.x * step,
                current.y + normDir.y * step,
                current.z + normDir.z * step
            )
            traveled += step

            let coord = BlockCoordinate(Int(floor(current.x)), Int(floor(current.y)), Int(floor(current.z)))
            if let block = world.block(at: coord) {
                return RaycastHit(
                    blockCoord: coord,
                    placeCoord: prevCoord,
                    blockType: block,
                    distance: Float(traveled)
                )
            }
            prevCoord = coord
        }
        return nil
    }

    public static func normalize(_ v: SCNVector3) -> SCNVector3 {
        let len = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
        if len == 0 { return SCNVector3(0, 0, 1) }
        return SCNVector3(v.x / len, v.y / len, v.z / len)
    }
}
