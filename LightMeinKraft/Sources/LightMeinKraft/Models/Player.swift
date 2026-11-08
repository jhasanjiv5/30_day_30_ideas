import Foundation
import SceneKit

public final class Player: ObservableObject {
    @Published public var position: SCNVector3
    @Published public var velocity: SCNVector3 = SCNVector3(0, 0, 0)
    @Published public var yaw: Float = 0.0     // Radians
    @Published public var pitch: Float = 0.0   // Radians

    @Published public var health: Float = 20.0
    public let maxHealth: Float = 20.0
    @Published public var warmth: Float = 100.0 // Decreases in freezing water
    public let maxWarmth: Float = 100.0

    @Published public var isOnGround: Bool = true
    @Published public var isSneaking: Bool = false

    // Hotbar (9 slots)
    @Published public var hotbar: [ItemStack?] = Array(repeating: nil, count: 9)
    @Published public var selectedSlot: Int = 0

    // Main Inventory (27 slots)
    @Published public var inventory: [ItemStack?] = Array(repeating: nil, count: 27)

    // 2x2 Crafting Grid (4 slots) + 1 Result slot
    @Published public var craftingGrid: [ItemStack?] = Array(repeating: nil, count: 4)
    @Published public var craftingResult: ItemStack? = nil

    public var selectedItem: ItemStack? {
        guard selectedSlot >= 0 && selectedSlot < hotbar.count else { return nil }
        return hotbar[selectedSlot]
    }

    public init(position: SCNVector3 = SCNVector3(16, 12, 16)) {
        self.position = position
        setupStarterInventory()
    }

    public func setupStarterInventory() {
        hotbar[0] = ItemStack(item: Item.woodenPickaxe, count: 1)
        hotbar[1] = ItemStack(item: Item.stick, count: 2)
        hotbar[2] = ItemStack(block: .pineLog, count: 3)
        hotbar[3] = ItemStack(item: Item.festiveCookie, count: 5)
    }

    public func addItem(_ stack: ItemStack) -> Bool {
        var remaining = stack.count

        // 1. Try to merge into existing hotbar stacks
        for i in 0..<hotbar.count {
            if var existing = hotbar[i], existing.item.id == stack.item.id {
                let space = stack.item.maxStack - existing.count
                if space > 0 {
                    let toAdd = min(space, remaining)
                    existing.count += toAdd
                    remaining -= toAdd
                    hotbar[i] = existing
                    if remaining <= 0 { return true }
                }
            }
        }

        // 2. Try to merge into existing inventory stacks
        for i in 0..<inventory.count {
            if var existing = inventory[i], existing.item.id == stack.item.id {
                let space = stack.item.maxStack - existing.count
                if space > 0 {
                    let toAdd = min(space, remaining)
                    existing.count += toAdd
                    remaining -= toAdd
                    inventory[i] = existing
                    if remaining <= 0 { return true }
                }
            }
        }

        // 3. Put into empty hotbar slot
        for i in 0..<hotbar.count {
            if hotbar[i] == nil {
                hotbar[i] = ItemStack(item: stack.item, count: remaining)
                return true
            }
        }

        // 4. Put into empty inventory slot
        for i in 0..<inventory.count {
            if inventory[i] == nil {
                inventory[i] = ItemStack(item: stack.item, count: remaining)
                return true
            }
        }

        return false
    }

    public func consumeSelected() {
        guard selectedSlot >= 0 && selectedSlot < hotbar.count, var stack = hotbar[selectedSlot] else { return }
        stack.count -= 1
        if stack.count <= 0 {
            hotbar[selectedSlot] = nil
        } else {
            hotbar[selectedSlot] = stack
        }
    }

    public func takeDamage(_ amount: Float) {
        health = max(0, health - amount)
    }

    public func heal(_ amount: Float) {
        health = min(maxHealth, health + amount)
    }

    public func updateCrafting() {
        if let recipe = CraftingSystem.shared.findMatch(for: craftingGrid) {
            craftingResult = recipe.output
        } else {
            craftingResult = nil
        }
    }

    public func takeCraftingResult() -> Bool {
        guard let result = craftingResult else { return false }
        if addItem(result) {
            // Deduct 1 from each populated crafting slot
            for i in 0..<craftingGrid.count {
                if var item = craftingGrid[i] {
                    item.count -= 1
                    craftingGrid[i] = item.count > 0 ? item : nil
                }
            }
            updateCrafting()
            return true
        }
        return false
    }
}
