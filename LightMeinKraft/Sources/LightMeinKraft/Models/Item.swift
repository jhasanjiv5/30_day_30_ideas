import Foundation

public enum ItemCategory: String, Sendable {
    case block
    case tool
    case weapon
    case consumable
    case quest
}

public struct Item: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let category: ItemCategory
    public let blockType: BlockType?
    public let attackDamage: Int
    public let maxStack: Int
    public let iconSymbol: String

    public init(
        id: String,
        name: String,
        category: ItemCategory,
        blockType: BlockType? = nil,
        attackDamage: Int = 1,
        maxStack: Int = 64,
        iconSymbol: String = "cube"
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.blockType = blockType
        self.attackDamage = attackDamage
        self.maxStack = maxStack
        self.iconSymbol = iconSymbol
    }

    public static func from(block: BlockType) -> Item {
        return Item(
            id: block.rawValue,
            name: block.rawValue,
            category: .block,
            blockType: block,
            attackDamage: 1,
            maxStack: 64,
            iconSymbol: block.iconSymbol
        )
    }

    // Special items
    public static let stick = Item(
        id: "stick",
        name: "Holiday Stick",
        category: .tool,
        attackDamage: 2,
        iconSymbol: "pencil.line"
    )

    public static let woodenPickaxe = Item(
        id: "wooden_pickaxe",
        name: "Pine Pickaxe",
        category: .tool,
        attackDamage: 3,
        iconSymbol: "hammer.fill"
    )

    public static let candyCaneSword = Item(
        id: "candy_cane_sword",
        name: "Candy Cane Blade",
        category: .weapon,
        attackDamage: 7,
        iconSymbol: "shield.slash.fill"
    )

    public static let festiveCookie = Item(
        id: "festive_cookie",
        name: "Gingerbread Cookie",
        category: .consumable,
        attackDamage: 1,
        maxStack: 16,
        iconSymbol: "fork.knife"
    )

    public static let snowball = Item(
        id: "snowball",
        name: "Snowball",
        category: .weapon,
        attackDamage: 3,
        maxStack: 16,
        iconSymbol: "circle.circle"
    )
}

public struct ItemStack: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var item: Item
    public var count: Int

    public init(item: Item, count: Int = 1) {
        self.item = item
        self.count = count
    }

    public init(block: BlockType, count: Int = 1) {
        self.item = Item.from(block: block)
        self.count = count
    }
}
