import Foundation
import SceneKit

public enum BlockFace: String, CaseIterable, Sendable {
    case top
    case bottom
    case side
    case front
    case back
    case left
    case right
}

public enum BlockType: String, CaseIterable, Identifiable, Sendable {
    case snowGrass = "Snowy Grass"
    case dirt = "Dirt"
    case stone = "Stone"
    case cobblestone = "Cobblestone"
    case pineLog = "Pine Log"
    case pineLeaves = "Pine Leaves"
    case pinePlanks = "Pine Planks"
    case candyCane = "Candy Cane"
    case ice = "Ice"
    case presentRed = "Red Gift Box"
    case presentGreen = "Green Gift Box"
    case holidayTorch = "Holiday Torch"
    case goldenStar = "Golden Star"
    case frostNetherrack = "Frost Netherrack"
    case gingerbread = "Gingerbread Block"
    case portalBlock = "Star Portal"

    public var id: String { rawValue }

    public var isSolid: Bool {
        switch self {
        case .holidayTorch, .portalBlock:
            return false
        default:
            return true
        }
    }

    public var isLightSource: Bool {
        switch self {
        case .holidayTorch, .goldenStar, .portalBlock:
            return true
        default:
            return false
        }
    }

    public var lightIntensity: CGFloat {
        switch self {
        case .holidayTorch: return 800
        case .goldenStar: return 1200
        case .portalBlock: return 1000
        default: return 0
        }
    }

    public var lightColor: NSColor {
        switch self {
        case .holidayTorch: return NSColor.systemOrange
        case .goldenStar: return NSColor.systemYellow
        case .portalBlock: return NSColor.systemPurple
        default: return .white
        }
    }

    public var hardness: Float {
        switch self {
        case .holidayTorch, .goldenStar, .portalBlock: return 0.1
        case .pineLeaves: return 0.2
        case .dirt, .snowGrass, .ice: return 0.5
        case .pinePlanks, .gingerbread, .presentRed, .presentGreen: return 0.8
        case .pineLog, .candyCane: return 1.0
        case .stone, .cobblestone, .frostNetherrack: return 1.5
        }
    }

    public var scoreValue: Int {
        switch self {
        case .snowGrass, .dirt: return 5
        case .stone, .cobblestone: return 10
        case .pineLog: return 15
        case .pineLeaves: return 2
        case .pinePlanks: return 8
        case .candyCane: return 25
        case .ice: return 10
        case .presentRed, .presentGreen: return 50
        case .holidayTorch: return 20
        case .gingerbread: return 30
        case .frostNetherrack: return 20
        case .goldenStar: return 100
        case .portalBlock: return 150
        }
    }

    public var iconSymbol: String {
        switch self {
        case .snowGrass: return "snowflake"
        case .dirt: return "square.fill"
        case .stone: return "cube.fill"
        case .cobblestone: return "circle.grid.2x2.fill"
        case .pineLog: return "cylinder.fill"
        case .pineLeaves: return "tree.fill"
        case .pinePlanks: return "rectangle.split.2x1.fill"
        case .candyCane: return "candybarphone"
        case .ice: return "snowflake.circle.fill"
        case .presentRed: return "gift.fill"
        case .presentGreen: return "gift"
        case .holidayTorch: return "flame.fill"
        case .goldenStar: return "star.fill"
        case .frostNetherrack: return "diamond.fill"
        case .gingerbread: return "heart.fill"
        case .portalBlock: return "sparkles"
        }
    }
}
