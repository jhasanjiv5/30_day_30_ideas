import Testing
@testable import LightMeinKraft
import SceneKit

@Suite("LightMeinKraft Game Architecture Tests")
struct LightMeinKraftTests {

    @Test("Block Type Properties and Hardness")
    func testBlockProperties() {
        let log = BlockType.pineLog
        #expect(log.isSolid == true)
        #expect(log.hardness == 1.0)
        #expect(log.scoreValue == 15)

        let torch = BlockType.holidayTorch
        #expect(torch.isSolid == false)
        #expect(torch.isLightSource == true)
        #expect(torch.lightIntensity == 800)

        let star = BlockType.goldenStar
        #expect(star.isLightSource == true)
        #expect(star.scoreValue == 100)
    }

    @Test("Crafting 1 Log into 4 Planks")
    func testCraftingPlanks() {
        var grid: [ItemStack?] = [nil, nil, nil, nil]
        grid[0] = ItemStack(block: .pineLog, count: 1)

        let match = CraftingSystem.shared.findMatch(for: grid)
        #expect(match != nil)
        #expect(match?.output.item.blockType == .pinePlanks)
        #expect(match?.output.count == 4)
    }

    @Test("Crafting 2 Planks into 4 Sticks")
    func testCraftingSticks() {
        var grid: [ItemStack?] = [nil, nil, nil, nil]
        grid[0] = ItemStack(block: .pinePlanks, count: 1)
        grid[2] = ItemStack(block: .pinePlanks, count: 1)

        let match = CraftingSystem.shared.findMatch(for: grid)
        #expect(match != nil)
        #expect(match?.output.item.id == Item.stick.id)
        #expect(match?.output.count == 4)
    }

    @Test("Crafting Golden Star from Torches and Candy Canes")
    func testCraftingGoldenStar() {
        let grid: [ItemStack?] = [
            ItemStack(block: .holidayTorch, count: 1),
            ItemStack(block: .candyCane, count: 1),
            ItemStack(block: .candyCane, count: 1),
            ItemStack(block: .holidayTorch, count: 1)
        ]

        let match = CraftingSystem.shared.findMatch(for: grid)
        #expect(match != nil)
        #expect(match?.output.item.blockType == .goldenStar)
        #expect(match?.output.count == 1)
    }

    @Test("Player Inventory and Stacking")
    @MainActor
    func testPlayerInventory() {
        let player = Player(position: SCNVector3(0, 0, 0))
        #expect(player.health == 20.0)

        // Add 5 Pine Logs
        let added = player.addItem(ItemStack(block: .pineLog, count: 5))
        #expect(added == true)

        // Damage and heal
        player.takeDamage(6.0)
        #expect(player.health == 14.0)
        player.heal(4.0)
        #expect(player.health == 18.0)
    }

    @Test("Quest Objectives Completion")
    @MainActor
    func testQuestLevel1() {
        var level1 = QuestLevel.level1()
        #expect(level1.levelNumber == 1)
        #expect(level1.isComplete == false)

        for i in 0..<level1.objectives.count {
            level1.objectives[i].currentCount = level1.objectives[i].targetCount
            #expect(level1.objectives[i].isComplete == true)
        }
        #expect(level1.isComplete == true)
    }

    @Test("Block Types Count and Invariants")
    func testAllBlockTypes() {
        #expect(BlockType.allCases.count == 16)
        for block in BlockType.allCases {
            #expect(!block.rawValue.isEmpty)
            #expect(!block.iconSymbol.isEmpty)
        }
    }

    @Test("Mob Damage and Death State")
    func testMobMechanics() {
        let creeper = Mob(type: .snowCreeper, position: SCNVector3(0, 0, 0))
        #expect(creeper.health == 12.0)
        #expect(creeper.isAlive == true)

        let killed = creeper.takeDamage(12.0)
        #expect(killed == true)
        #expect(creeper.isAlive == false)
    }
}
