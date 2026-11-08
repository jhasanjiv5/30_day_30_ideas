import Foundation

public struct CraftingRecipe: Sendable {
    public let name: String
    public let pattern: [String?] // 4 elements for 2x2: [0=top-left, 1=top-right, 2=bot-left, 3=bot-right]
    public let output: ItemStack
    public let description: String

    public init(name: String, pattern: [String?], output: ItemStack, description: String) {
        self.name = name
        self.pattern = pattern
        self.output = output
        self.description = description
    }

    public func matches(grid: [ItemStack?]) -> Bool {
        guard grid.count == 4 else { return false }
        for i in 0..<4 {
            let required = pattern[i]
            let actual = grid[i]?.item.id
            if required != actual {
                return false
            }
        }
        return true
    }
}

public final class CraftingSystem: Sendable {
    public static let shared = CraftingSystem()

    public let recipes: [CraftingRecipe]

    private init() {
        var r: [CraftingRecipe] = []

        // 1 Pine Log anywhere -> 4 Pine Planks
        for pos in 0..<4 {
            var pat: [String?] = [nil, nil, nil, nil]
            pat[pos] = BlockType.pineLog.rawValue
            r.append(CraftingRecipe(
                name: "Craft Pine Planks",
                pattern: pat,
                output: ItemStack(block: .pinePlanks, count: 4),
                description: "Turn 1 Log into 4 Planks"
            ))
        }

        // 2 Pine Planks vertical -> 4 Holiday Sticks
        // Col 0: (0, 2)
        r.append(CraftingRecipe(
            name: "Craft Sticks",
            pattern: [BlockType.pinePlanks.rawValue, nil, BlockType.pinePlanks.rawValue, nil],
            output: ItemStack(item: Item.stick, count: 4),
            description: "Planks into 4 Holiday Sticks"
        ))
        // Col 1: (1, 3)
        r.append(CraftingRecipe(
            name: "Craft Sticks",
            pattern: [nil, BlockType.pinePlanks.rawValue, nil, BlockType.pinePlanks.rawValue],
            output: ItemStack(item: Item.stick, count: 4),
            description: "Planks into 4 Holiday Sticks"
        ))

        // 1 Stick + 1 Candy Cane -> 4 Holiday Torches
        r.append(CraftingRecipe(
            name: "Craft Torches",
            pattern: [BlockType.candyCane.rawValue, nil, Item.stick.id, nil],
            output: ItemStack(block: .holidayTorch, count: 4),
            description: "Candy Cane + Stick = 4 Torches"
        ))
        r.append(CraftingRecipe(
            name: "Craft Torches",
            pattern: [nil, BlockType.candyCane.rawValue, nil, Item.stick.id],
            output: ItemStack(block: .holidayTorch, count: 4),
            description: "Candy Cane + Stick = 4 Torches"
        ))

        // 2 Sticks + 2 Planks -> Pine Pickaxe
        r.append(CraftingRecipe(
            name: "Craft Pine Pickaxe",
            pattern: [BlockType.pinePlanks.rawValue, BlockType.pinePlanks.rawValue, Item.stick.id, Item.stick.id],
            output: ItemStack(item: Item.woodenPickaxe, count: 1),
            description: "Sturdy Wooden Pickaxe"
        ))

        // 2 Candy Canes + 1 Stick -> Candy Cane Blade
        r.append(CraftingRecipe(
            name: "Craft Candy Cane Blade",
            pattern: [BlockType.candyCane.rawValue, BlockType.candyCane.rawValue, Item.stick.id, nil],
            output: ItemStack(item: Item.candyCaneSword, count: 1),
            description: "High-damage Festive Weapon"
        ))

        // 4 Candy Canes -> Red Gift Box
        r.append(CraftingRecipe(
            name: "Wrap Red Present",
            pattern: [BlockType.candyCane.rawValue, BlockType.candyCane.rawValue, BlockType.candyCane.rawValue, BlockType.candyCane.rawValue],
            output: ItemStack(block: .presentRed, count: 1),
            description: "Wrap 4 Candy Canes into a Present"
        ))

        // 4 Pine Leaves -> Green Gift Box
        r.append(CraftingRecipe(
            name: "Wrap Green Present",
            pattern: [BlockType.pineLeaves.rawValue, BlockType.pineLeaves.rawValue, BlockType.pineLeaves.rawValue, BlockType.pineLeaves.rawValue],
            output: ItemStack(block: .presentGreen, count: 1),
            description: "Festive Pine Needle Present"
        ))

        // 2 Torches + 2 Candy Canes -> Golden Star
        r.append(CraftingRecipe(
            name: "Forge Golden Star",
            pattern: [BlockType.holidayTorch.rawValue, BlockType.candyCane.rawValue, BlockType.candyCane.rawValue, BlockType.holidayTorch.rawValue],
            output: ItemStack(block: .goldenStar, count: 1),
            description: "Star of Bethlehem / Tree Topper"
        ))

        // 4 Snow Grass / Dirt -> 4 Snowballs
        r.append(CraftingRecipe(
            name: "Pack Snowballs",
            pattern: [BlockType.snowGrass.rawValue, nil, nil, nil],
            output: ItemStack(item: Item.snowball, count: 4),
            description: "Make 4 throwable Snowballs"
        ))

        self.recipes = r
    }

    public func findMatch(for grid: [ItemStack?]) -> CraftingRecipe? {
        for recipe in recipes {
            if recipe.matches(grid: grid) {
                return recipe
            }
        }
        return nil
    }
}
