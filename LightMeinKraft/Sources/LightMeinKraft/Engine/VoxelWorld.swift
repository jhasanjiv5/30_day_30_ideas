import Foundation
import SceneKit
import AppKit

@MainActor
public final class VoxelWorld {
    public let scene: SCNScene
    public let worldNode: SCNNode
    public let mobsNode: SCNNode
    public let particlesNode: SCNNode

    public private(set) var blocks: [BlockCoordinate: BlockType] = [:]
    private var blockNodes: [BlockCoordinate: SCNNode] = [:]
    public private(set) var mobs: [Mob] = []

    public let width: Int = 36
    public let depth: Int = 36
    public let height: Int = 16

    private var snowParticleSystem: SCNParticleSystem?
    private var sharedBoxGeometry: SCNBox?

    public init(scene: SCNScene) {
        self.scene = scene
        self.worldNode = SCNNode()
        self.mobsNode = SCNNode()
        self.particlesNode = SCNNode()

        scene.rootNode.addChildNode(worldNode)
        scene.rootNode.addChildNode(mobsNode)
        scene.rootNode.addChildNode(particlesNode)

        setupEnvironment()
    }

    private func setupEnvironment() {
        // Ambient Light
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 400
        ambientLight.color = NSColor(calibratedRed: 0.8, green: 0.85, blue: 0.95, alpha: 1.0)
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        // Sunlight / Directional Moon
        let sunLight = SCNLight()
        sunLight.type = .directional
        sunLight.intensity = 900
        sunLight.castsShadow = true
        sunLight.shadowMode = .deferred
        sunLight.shadowSampleCount = 4
        sunLight.shadowRadius = 3.0
        sunLight.color = NSColor(calibratedRed: 0.95, green: 0.95, blue: 1.0, alpha: 1.0)

        let sunNode = SCNNode()
        sunNode.light = sunLight
        sunNode.eulerAngles = SCNVector3(-0.9, 0.6, 0)
        scene.rootNode.addChildNode(sunNode)

        // Snow Particle System
        let snow = SCNParticleSystem()
        snow.particleSize = 0.08
        snow.particleColor = NSColor.white
        snow.birthRate = 250
        snow.particleLifeSpan = 6.0
        snow.speedFactor = 1.0
        snow.emitterShape = SCNBox(width: 45, height: 1, length: 45, chamferRadius: 0)
        snow.particleVelocity = 4.0
        snow.particleVelocityVariation = 1.5
        snow.acceleration = SCNVector3(0.5, -4.5, 0.2)
        snow.isAffectedByGravity = true

        let snowNode = SCNNode()
        snowNode.position = SCNVector3(Float(width) / 2.0, 18.0, Float(depth) / 2.0)
        snowNode.addParticleSystem(snow)
        particlesNode.addChildNode(snowNode)
        self.snowParticleSystem = snow
    }

    public func clear() {
        worldNode.enumerateChildNodes { node, _ in node.removeFromParentNode() }
        mobsNode.enumerateChildNodes { node, _ in node.removeFromParentNode() }
        blocks.removeAll()
        blockNodes.removeAll()
        mobs.removeAll()
    }

    // MARK: - Level 1 Generation: Winter Taiga

    public func generateLevel1() {
        clear()
        scene.fogColor = NSColor(calibratedRed: 0.75, green: 0.82, blue: 0.92, alpha: 1.0)
        scene.fogStartDistance = 22.0
        scene.fogEndDistance = 45.0
        scene.background.contents = NSColor(calibratedRed: 0.72, green: 0.80, blue: 0.92, alpha: 1.0)

        // 1. Terrain generation with rolling snowy hills and a frozen pond
        for x in 0..<width {
            for z in 0..<depth {
                let fx = Float(x)
                let fz = Float(z)
                let hill = sin(fx * 0.22) * 1.8 + cos(fz * 0.25) * 1.5
                let groundY = Int(5.0 + hill)

                // Frozen lake in center-left
                let dx = fx - 10.0
                let dz = fz - 24.0
                let isLake = (dx * dx + dz * dz) < 28.0

                for y in 0...groundY {
                    let coord = BlockCoordinate(x, y, z)
                    if y == groundY {
                        if isLake && y <= 5 {
                            setBlockSilently(at: coord, type: .ice)
                        } else {
                            setBlockSilently(at: coord, type: .snowGrass)
                        }
                    } else if y >= groundY - 2 {
                        setBlockSilently(at: coord, type: .dirt)
                    } else if y >= 1 {
                        setBlockSilently(at: coord, type: (y % 2 == 0) ? .stone : .cobblestone)
                    } else {
                        setBlockSilently(at: coord, type: .stone)
                    }
                }

                // Candy Cane veins
                if (x % 9 == 0) && (z % 8 == 0) && !isLake {
                    let caneY = groundY + 1
                    setBlockSilently(at: BlockCoordinate(x, caneY, z), type: .candyCane)
                    setBlockSilently(at: BlockCoordinate(x, caneY + 1, z), type: .candyCane)
                }
            }
        }

        // 2. Plant Festive Pine Trees
        let treePositions = [
            (8, 12), (14, 8), (22, 14), (26, 24), (18, 28), (6, 28), (28, 8)
        ]
        for (tx, tz) in treePositions {
            plantPineTree(atX: tx, atZ: tz, height: 5)
        }

        // 3. Scatter Holiday Gift Boxes under trees
        setBlockSilently(at: BlockCoordinate(9, 6, 12), type: .presentRed)
        setBlockSilently(at: BlockCoordinate(7, 6, 12), type: .presentGreen)
        setBlockSilently(at: BlockCoordinate(23, 6, 14), type: .presentRed)
        setBlockSilently(at: BlockCoordinate(27, 6, 24), type: .presentGreen)

        // 4. Star Portal Foundation Shrine (in clearing at 16, 16)
        buildPortalShrine(centerX: 16, centerZ: 16)

        // 5. Spawn Friendly Snowman and Patrolling Snow Creepers
        spawnMob(type: .holidaySnowman, at: SCNVector3(14, 7, 14))
        spawnMob(type: .snowCreeper, at: SCNVector3(24, 7, 10))
        spawnMob(type: .snowCreeper, at: SCNVector3(10, 7, 26))
        spawnMob(type: .snowCreeper, at: SCNVector3(26, 7, 28))

        // Render all blocks to SceneKit
        rebuildMesh()
    }

    // MARK: - Level 2 Generation: Santa's Frozen Workshop

    public func generateLevel2() {
        clear()
        scene.fogColor = NSColor(calibratedRed: 0.15, green: 0.12, blue: 0.28, alpha: 1.0)
        scene.fogStartDistance = 18.0
        scene.fogEndDistance = 40.0
        scene.background.contents = NSColor(calibratedRed: 0.12, green: 0.10, blue: 0.22, alpha: 1.0)

        // 1. Frozen Nether floor and Gingerbread fortress walls
        for x in 0..<width {
            for z in 0..<depth {
                // Floor
                let coord = BlockCoordinate(x, 4, z)
                let isCandyPattern = ((x + z) % 6 == 0)
                setBlockSilently(at: coord, type: isCandyPattern ? .candyCane : .frostNetherrack)
                setBlockSilently(at: BlockCoordinate(x, 3, z), type: .stone)

                // Fortress border walls
                if x == 0 || x == width - 1 || z == 0 || z == depth - 1 {
                    for y in 5...9 {
                        setBlockSilently(at: BlockCoordinate(x, y, z), type: (y % 2 == 0) ? .gingerbread : .frostNetherrack)
                    }
                }

                // Decorative pillars
                if (x % 8 == 0) && (z % 8 == 0) && x > 2 && x < width - 2 && z > 2 && z < depth - 2 {
                    for y in 5...8 {
                        setBlockSilently(at: BlockCoordinate(x, y, z), type: .candyCane)
                    }
                    setBlockSilently(at: BlockCoordinate(x, 9, z), type: .holidayTorch)
                }
            }
        }

        // 2. The Grand Central Christmas Tree (Needs the Star atop it to win!)
        buildGrandChristmasTree(centerX: 18, centerZ: 18)

        // 3. Scatter Presents & Ice crystals around the tree
        setBlockSilently(at: BlockCoordinate(16, 5, 17), type: .presentRed)
        setBlockSilently(at: BlockCoordinate(20, 5, 17), type: .presentGreen)
        setBlockSilently(at: BlockCoordinate(17, 5, 20), type: .presentRed)
        setBlockSilently(at: BlockCoordinate(19, 5, 20), type: .presentGreen)
        setBlockSilently(at: BlockCoordinate(15, 5, 15), type: .holidayTorch)
        setBlockSilently(at: BlockCoordinate(21, 5, 15), type: .holidayTorch)

        // 4. Spawn Boss: The Abominable Frost Grinch!
        spawnMob(type: .frostGrinch, at: SCNVector3(18, 5, 24))

        // Also spawn 2 guardian Snow Creepers
        spawnMob(type: .snowCreeper, at: SCNVector3(12, 5, 12))
        spawnMob(type: .snowCreeper, at: SCNVector3(24, 5, 12))

        // Render all blocks to SceneKit
        rebuildMesh()
    }

    private func plantPineTree(atX x: Int, atZ z: Int, height: Int) {
        // Find ground height
        var groundY = 5
        for y in stride(from: 12, through: 0, by: -1) {
            if let b = blocks[BlockCoordinate(x, y, z)], b.isSolid {
                groundY = y
                break
            }
        }

        // Trunk
        for y in 1...height {
            setBlockSilently(at: BlockCoordinate(x, groundY + y, z), type: .pineLog)
        }

        // Conical pine foliage with snow dusting
        let topY = groundY + height
        // Base ring (3x3)
        for dx in -2...2 {
            for dz in -2...2 {
                if abs(dx) + abs(dz) <= 3 {
                    setBlockSilently(at: BlockCoordinate(x + dx, topY - 1, z + dz), type: .pineLeaves)
                    setBlockSilently(at: BlockCoordinate(x + dx, topY, z + dz), type: .pineLeaves)
                }
            }
        }
        // Middle ring (2x2)
        for dx in -1...1 {
            for dz in -1...1 {
                setBlockSilently(at: BlockCoordinate(x + dx, topY + 1, z + dz), type: .pineLeaves)
            }
        }
        // Top tip
        setBlockSilently(at: BlockCoordinate(x, topY + 2, z), type: .pineLeaves)
    }

    private func buildGrandChristmasTree(centerX: Int, centerZ: Int) {
        let baseY = 5
        let trunkHeight = 8

        // Sturdy Trunk
        for y in 0..<trunkHeight {
            setBlockSilently(at: BlockCoordinate(centerX, baseY + y, centerZ), type: .pineLog)
        }

        // Layer 1 (Wide 5x5)
        for dx in -3...3 {
            for dz in -3...3 {
                if abs(dx) + abs(dz) <= 4 {
                    setBlockSilently(at: BlockCoordinate(centerX + dx, baseY + 3, centerZ + dz), type: .pineLeaves)
                    setBlockSilently(at: BlockCoordinate(centerX + dx, baseY + 4, centerZ + dz), type: .pineLeaves)
                }
            }
        }

        // Layer 2 (3x3)
        for dx in -2...2 {
            for dz in -2...2 {
                if abs(dx) + abs(dz) <= 3 {
                    setBlockSilently(at: BlockCoordinate(centerX + dx, baseY + 5, centerZ + dz), type: .pineLeaves)
                    setBlockSilently(at: BlockCoordinate(centerX + dx, baseY + 6, centerZ + dz), type: .pineLeaves)
                }
            }
        }

        // Layer 3 (Tapered top)
        for dx in -1...1 {
            for dz in -1...1 {
                setBlockSilently(at: BlockCoordinate(centerX + dx, baseY + 7, centerZ + dz), type: .pineLeaves)
            }
        }
        setBlockSilently(at: BlockCoordinate(centerX, baseY + 8, centerZ), type: .pineLeaves)

        // Ornaments (Candy Canes and Holiday Torches embedded in leaves)
        setBlockSilently(at: BlockCoordinate(centerX + 2, baseY + 4, centerZ), type: .candyCane)
        setBlockSilently(at: BlockCoordinate(centerX - 2, baseY + 4, centerZ), type: .candyCane)
        setBlockSilently(at: BlockCoordinate(centerX, baseY + 4, centerZ + 2), type: .holidayTorch)
        setBlockSilently(at: BlockCoordinate(centerX, baseY + 4, centerZ - 2), type: .holidayTorch)
    }

    private func buildPortalShrine(centerX: Int, centerZ: Int) {
        let y = 6
        // Platform
        for dx in -2...2 {
            for dz in -2...2 {
                setBlockSilently(at: BlockCoordinate(centerX + dx, y, centerZ + dz), type: .cobblestone)
            }
        }
        // Corner pillars with torches
        setBlockSilently(at: BlockCoordinate(centerX - 2, y + 1, centerZ - 2), type: .candyCane)
        setBlockSilently(at: BlockCoordinate(centerX - 2, y + 2, centerZ - 2), type: .holidayTorch)

        setBlockSilently(at: BlockCoordinate(centerX + 2, y + 1, centerZ - 2), type: .candyCane)
        setBlockSilently(at: BlockCoordinate(centerX + 2, y + 2, centerZ - 2), type: .holidayTorch)

        setBlockSilently(at: BlockCoordinate(centerX - 2, y + 1, centerZ + 2), type: .candyCane)
        setBlockSilently(at: BlockCoordinate(centerX - 2, y + 2, centerZ + 2), type: .holidayTorch)

        setBlockSilently(at: BlockCoordinate(centerX + 2, y + 1, centerZ + 2), type: .candyCane)
        setBlockSilently(at: BlockCoordinate(centerX + 2, y + 2, centerZ + 2), type: .holidayTorch)

        // Portal Base Frame in Center
        setBlockSilently(at: BlockCoordinate(centerX - 1, y + 1, centerZ), type: .cobblestone)
        setBlockSilently(at: BlockCoordinate(centerX + 1, y + 1, centerZ), type: .cobblestone)
        setBlockSilently(at: BlockCoordinate(centerX, y + 1, centerZ), type: .portalBlock)
    }

    // MARK: - Voxel Access & Node Management

    public func block(at coord: BlockCoordinate) -> BlockType? {
        return blocks[coord]
    }

    public func setBlockSilently(at coord: BlockCoordinate, type: BlockType) {
        blocks[coord] = type
    }

    public func setBlock(at coord: BlockCoordinate, type: BlockType) {
        blocks[coord] = type
        if let existingNode = blockNodes[coord] {
            existingNode.removeFromParentNode()
        }
        let node = createBlockNode(coord: coord, type: type)
        worldNode.addChildNode(node)
        blockNodes[coord] = node
    }

    public func removeBlock(at coord: BlockCoordinate) -> BlockType? {
        guard let type = blocks.removeValue(forKey: coord) else { return nil }
        if let node = blockNodes.removeValue(forKey: coord) {
            spawnBreakParticles(at: SCNVector3(Float(coord.x) + 0.5, Float(coord.y) + 0.5, Float(coord.z) + 0.5), color: type.lightColor)
            node.removeFromParentNode()
        }
        return type
    }

    private func rebuildMesh() {
        blockNodes.values.forEach { $0.removeFromParentNode() }
        blockNodes.removeAll()

        for (coord, type) in blocks {
            // Only render blocks that have at least one exposed face
            if isExposed(coord: coord) {
                let node = createBlockNode(coord: coord, type: type)
                worldNode.addChildNode(node)
                blockNodes[coord] = node
            }
        }
    }

    private func isExposed(coord: BlockCoordinate) -> Bool {
        let neighbors = [
            BlockCoordinate(coord.x + 1, coord.y, coord.z),
            BlockCoordinate(coord.x - 1, coord.y, coord.z),
            BlockCoordinate(coord.x, coord.y + 1, coord.z),
            BlockCoordinate(coord.x, coord.y - 1, coord.z),
            BlockCoordinate(coord.x, coord.y, coord.z + 1),
            BlockCoordinate(coord.x, coord.y, coord.z - 1)
        ]
        for n in neighbors {
            if blocks[n] == nil || blocks[n]?.isSolid == false {
                return true
            }
        }
        return false
    }

    private func createBlockNode(coord: BlockCoordinate, type: BlockType) -> SCNNode {
        let box = SCNBox(width: 1.0, height: 1.0, length: 1.0, chamferRadius: 0.0)

        // Materials: [Front, Right, Back, Left, Top, Bottom]
        let topMat = TextureGenerator.shared.material(for: type, face: .top)
        let botMat = TextureGenerator.shared.material(for: type, face: .bottom)
        let sideMat = TextureGenerator.shared.material(for: type, face: .side)
        box.materials = [sideMat, sideMat, sideMat, sideMat, topMat, botMat]

        let node = SCNNode(geometry: box)
        node.position = SCNVector3(Float(coord.x) + 0.5, Float(coord.y) + 0.5, Float(coord.z) + 0.5)

        // Point light for glowing blocks
        if type.isLightSource {
            let light = SCNLight()
            light.type = .omni
            light.intensity = type.lightIntensity
            light.color = type.lightColor
            light.attenuationStartDistance = 0.5
            light.attenuationEndDistance = 6.0
            let lightNode = SCNNode()
            lightNode.light = light
            node.addChildNode(lightNode)
        }

        return node
    }

    private func spawnBreakParticles(at pos: SCNVector3, color: NSColor) {
        let p = SCNParticleSystem()
        p.particleSize = 0.06
        p.particleColor = color
        p.birthRate = 60
        p.particleLifeSpan = 0.4
        p.emissionDuration = 0.1
        p.loops = false
        p.particleVelocity = 2.5
        p.particleVelocityVariation = 1.0
        p.spreadingAngle = 180
        p.isAffectedByGravity = true

        let pNode = SCNNode()
        pNode.position = pos
        pNode.addParticleSystem(p)
        particlesNode.addChildNode(pNode)

        // Auto remove after completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            pNode.removeFromParentNode()
        }
    }

    // MARK: - Mobs

    public func spawnMob(type: MobType, at pos: SCNVector3) {
        let mob = Mob(type: type, position: pos)
        let node = createMobNode(mob: mob)
        node.position = pos
        mobsNode.addChildNode(node)
        mob.node = node
        mobs.append(mob)
    }

    private func createMobNode(mob: Mob) -> SCNNode {
        let root = SCNNode()

        switch mob.type {
        case .snowCreeper:
            // Creeper body (green cube)
            let bodyGeo = SCNBox(width: 0.7, height: 1.2, length: 0.7, chamferRadius: 0.05)
            let bodyMat = SCNMaterial()
            bodyMat.diffuse.contents = NSColor(calibratedRed: 0.2, green: 0.75, blue: 0.3, alpha: 1.0)
            bodyGeo.materials = [bodyMat]
            let bodyNode = SCNNode(geometry: bodyGeo)
            bodyNode.position = SCNVector3(0, 0.6, 0)
            root.addChildNode(bodyNode)

            // Creeper head (cube with face)
            let headGeo = SCNBox(width: 0.7, height: 0.7, length: 0.7, chamferRadius: 0.05)
            let headMat = SCNMaterial()
            headMat.diffuse.contents = NSColor(calibratedRed: 0.18, green: 0.68, blue: 0.25, alpha: 1.0)
            headGeo.materials = [headMat]
            let headNode = SCNNode(geometry: headGeo)
            headNode.position = SCNVector3(0, 1.45, 0)
            root.addChildNode(headNode)

            // Festive Santa Hat on Creeper!
            let hatGeo = SCNCone(topRadius: 0.02, bottomRadius: 0.4, height: 0.5)
            let hatMat = SCNMaterial()
            hatMat.diffuse.contents = NSColor.systemRed
            hatGeo.materials = [hatMat]
            let hatNode = SCNNode(geometry: hatGeo)
            hatNode.position = SCNVector3(0, 1.95, 0)
            root.addChildNode(hatNode)

            // White pompom
            let pomGeo = SCNSphere(radius: 0.08)
            let pomMat = SCNMaterial()
            pomMat.diffuse.contents = NSColor.white
            pomGeo.materials = [pomMat]
            let pomNode = SCNNode(geometry: pomGeo)
            pomNode.position = SCNVector3(0, 2.22, 0)
            root.addChildNode(pomNode)

        case .frostGrinch:
            // Giant Frost Grinch Boss (3 blocks tall!)
            let bodyGeo = SCNBox(width: 1.4, height: 2.0, length: 1.4, chamferRadius: 0.1)
            let bodyMat = SCNMaterial()
            bodyMat.diffuse.contents = NSColor(calibratedRed: 0.3, green: 0.8, blue: 0.85, alpha: 1.0)
            bodyMat.emission.contents = NSColor(calibratedRed: 0.1, green: 0.4, blue: 0.5, alpha: 1.0)
            bodyGeo.materials = [bodyMat]
            let bodyNode = SCNNode(geometry: bodyGeo)
            bodyNode.position = SCNVector3(0, 1.0, 0)
            root.addChildNode(bodyNode)

            // Head
            let headGeo = SCNBox(width: 1.1, height: 1.1, length: 1.1, chamferRadius: 0.1)
            let headMat = SCNMaterial()
            headMat.diffuse.contents = NSColor(calibratedRed: 0.25, green: 0.75, blue: 0.8, alpha: 1.0)
            headGeo.materials = [headMat]
            let headNode = SCNNode(geometry: headGeo)
            headNode.position = SCNVector3(0, 2.3, 0)
            root.addChildNode(headNode)

            // Glowing Horns/Crown
            let crownGeo = SCNCone(topRadius: 0.05, bottomRadius: 0.2, height: 0.6)
            let crownMat = SCNMaterial()
            crownMat.diffuse.contents = NSColor.systemPurple
            crownGeo.materials = [crownMat]
            let horn1 = SCNNode(geometry: crownGeo)
            horn1.position = SCNVector3(-0.35, 3.0, 0)
            let horn2 = SCNNode(geometry: crownGeo)
            horn2.position = SCNVector3(0.35, 3.0, 0)
            root.addChildNode(horn1)
            root.addChildNode(horn2)

        case .holidaySnowman:
            // Bottom sphere
            let b1 = SCNSphere(radius: 0.55)
            let m1 = SCNMaterial()
            m1.diffuse.contents = NSColor.white
            b1.materials = [m1]
            let n1 = SCNNode(geometry: b1)
            n1.position = SCNVector3(0, 0.55, 0)
            root.addChildNode(n1)

            // Top sphere
            let b2 = SCNSphere(radius: 0.4)
            b2.materials = [m1]
            let n2 = SCNNode(geometry: b2)
            n2.position = SCNVector3(0, 1.35, 0)
            root.addChildNode(n2)

            // Carrot nose
            let noseGeo = SCNCone(topRadius: 0.02, bottomRadius: 0.08, height: 0.25)
            let noseMat = SCNMaterial()
            noseMat.diffuse.contents = NSColor.systemOrange
            noseGeo.materials = [noseMat]
            let noseNode = SCNNode(geometry: noseGeo)
            noseNode.position = SCNVector3(0, 1.35, 0.45)
            noseNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
            root.addChildNode(noseNode)

            // Red Scarf
            let scarfGeo = SCNTorus(ringRadius: 0.38, pipeRadius: 0.08)
            let scarfMat = SCNMaterial()
            scarfMat.diffuse.contents = NSColor.systemRed
            scarfGeo.materials = [scarfMat]
            let scarfNode = SCNNode(geometry: scarfGeo)
            scarfNode.position = SCNVector3(0, 1.05, 0)
            root.addChildNode(scarfNode)
        }

        return root
    }

    public func updateMobs(player: Player, deltaTime: Float) {
        let dt = min(deltaTime, 0.05)

        for mob in mobs where mob.isAlive {
            guard let node = mob.node else { continue }

            let dx = Float(player.position.x - mob.position.x)
            let dz = Float(player.position.z - mob.position.z)
            let dist = sqrt(dx * dx + dz * dz)

            if mob.type == .snowCreeper {
                // Creeper AI: Pursues player when within 12 blocks
                if dist < 12.0 {
                    let angle = atan2(dx, dz)
                    node.eulerAngles.y = CGFloat(angle)

                    if dist < 2.5 {
                        // In fuse range!
                        if !mob.isFusing {
                            mob.isFusing = true
                            SoundManager.shared.playCreeperHiss()
                        }
                        mob.fuseTimer += dt

                        // Swell animation & flashing
                        let scale = CGFloat(1.0 + Float(sin(Double(mob.fuseTimer) * 15.0)) * 0.15)
                        node.scale = SCNVector3(scale, scale, scale)

                        if mob.fuseTimer >= mob.fuseDuration {
                            // BOOM!
                            explodeCreeper(mob: mob, player: player)
                            continue
                        }
                    } else {
                        // Reset fuse if player ran away
                        mob.fuseTimer = max(0, mob.fuseTimer - dt * 2.0)
                        mob.isFusing = false
                        node.scale = SCNVector3(1, 1, 1)

                        // Walk toward player
                        let speed: Float = 2.2
                        let mx = CGFloat((dx / dist) * speed * dt)
                        let mz = CGFloat((dz / dist) * speed * dt)
                        mob.position.x += mx
                        mob.position.z += mz
                        node.position = mob.position
                    }
                }
            } else if mob.type == .frostGrinch {
                // Boss AI: Pursues player, attacks, has high HP
                if dist < 20.0 {
                    let angle = atan2(dx, dz)
                    node.eulerAngles.y = CGFloat(angle)

                    let speed: Float = 1.8
                    let mx = CGFloat((dx / dist) * speed * dt)
                    let mz = CGFloat((dz / dist) * speed * dt)
                    mob.position.x += mx
                    mob.position.z += mz
                    node.position = mob.position

                    // Melee attack if close
                    mob.attackCooldown += dt
                    if dist < 2.2 && mob.attackCooldown > 1.2 {
                        mob.attackCooldown = 0.0
                        player.takeDamage(4.0)
                        SoundManager.shared.playHurt()
                    }
                }
            }
        }

        // Remove dead mobs
        mobs.removeAll { mob in
            if !mob.isAlive {
                mob.node?.removeFromParentNode()
                return true
            }
            return false
        }
    }

    private func explodeCreeper(mob: Mob, player: Player) {
        SoundManager.shared.playExplosion()
        spawnBreakParticles(at: mob.position, color: NSColor.systemRed)

        let dx = Float(player.position.x - mob.position.x)
        let dy = Float(player.position.y - mob.position.y)
        let dz = Float(player.position.z - mob.position.z)
        let dist = sqrt(dx * dx + dy * dy + dz * dz)

        // Damage player based on proximity
        if dist < 4.0 {
            let dmg = max(2.0, (4.0 - dist) * 4.0)
            player.takeDamage(dmg)
            SoundManager.shared.playHurt()
            // Knockback
            player.velocity.x += CGFloat((dx / dist) * 8.0)
            player.velocity.y += 6.0
            player.velocity.z += CGFloat((dz / dist) * 8.0)
        }

        // Drop candy cane!
        _ = player.addItem(ItemStack(block: .candyCane, count: 2))

        mob.health = 0
        mob.node?.removeFromParentNode()
    }
}
