import SwiftUI

public struct InventoryView: View {
    @ObservedObject var gameState: GameState
    @State private var selectedStack: ItemStack? = nil

    public var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    gameState.currentScreen = .playing
                }

            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "cube.box.fill")
                        .foregroundColor(.yellow)
                    Text("CRAFTING & INVENTORY")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Button("Close (E)") {
                        gameState.currentScreen = .playing
                    }
                    .keyboardShortcut("e", modifiers: [])
                    .buttonStyle(.borderedProminent)
                    .tint(.red.opacity(0.8))
                }
                .padding(.horizontal)

                Divider().background(Color.gray)

                // Crafting Area (2x2 Grid + Arrow + Output)
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("2x2 CRAFTING")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)

                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                craftingSlotView(index: 0)
                                craftingSlotView(index: 1)
                            }
                            HStack(spacing: 4) {
                                craftingSlotView(index: 2)
                                craftingSlotView(index: 3)
                            }
                        }
                    }

                    Image(systemName: "arrow.right")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("RESULT")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)

                        ZStack(alignment: .bottomTrailing) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(gameState.player.craftingResult != nil ? Color.green.opacity(0.3) : Color.black.opacity(0.5))
                                .frame(width: 56, height: 56)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(gameState.player.craftingResult != nil ? Color.green : Color.gray.opacity(0.5), lineWidth: 2)
                                )

                            if let res = gameState.player.craftingResult {
                                Image(systemName: res.item.iconSymbol)
                                    .font(.system(size: 26))
                                    .foregroundColor(.yellow)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                                Text("\(res.count)")
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(4)
                            }
                        }
                        .frame(width: 56, height: 56)
                        .onTapGesture {
                            if let result = gameState.player.craftingResult {
                                let item = result.item
                                let count = result.count
                                if gameState.player.takeCraftingResult() {
                                    gameState.recordItemCrafted(item: item, count: count)
                                }
                            }
                        }
                    }

                    // Recipe Helper / Auto-Crafting Shortcuts
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HOLIDAY RECIPES")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.yellow)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                recipeRow(title: "1 Log ➔ 4 Planks", desc: "Place 1 Log in crafting")
                                recipeRow(title: "2 Planks ➔ 4 Sticks", desc: "Stack 2 Planks vertically")
                                recipeRow(title: "Candy + Stick ➔ 4 Torches", desc: "Torch recipe")
                                recipeRow(title: "Planks + Sticks ➔ Pickaxe", desc: "Mining tool")
                                recipeRow(title: "Candy + Stick ➔ Blade", desc: "Strong festive weapon")
                                recipeRow(title: "2 Torches + 2 Candy ➔ Golden Star", desc: "Required for Portal & Level 2!")
                            }
                        }
                        .frame(maxHeight: 120)
                    }
                    .frame(maxWidth: 240)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.4)))
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))

                // Main Inventory (3 rows of 9)
                VStack(alignment: .leading, spacing: 6) {
                    Text("INVENTORY")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)

                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 4) {
                            ForEach(0..<9, id: \.self) { col in
                                let idx = row * 9 + col
                                inventorySlotView(index: idx)
                            }
                        }
                    }
                }

                // Hotbar (1 row of 9)
                VStack(alignment: .leading, spacing: 6) {
                    Text("HOTBAR")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)

                    HStack(spacing: 4) {
                        ForEach(0..<9, id: \.self) { idx in
                            hotbarSlotView(index: idx)
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                    )
            )
            .frame(maxWidth: 580)
        }
    }

    private func craftingSlotView(index: Int) -> some View {
        let stack = gameState.player.craftingGrid[index]
        return ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(0.6))
                .frame(width: 44, height: 44)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.4), lineWidth: 1))

            if let s = stack {
                Image(systemName: s.item.iconSymbol)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if s.count > 1 {
                    Text("\(s.count)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(2)
                }
            }
        }
        .frame(width: 44, height: 44)
        .onTapGesture {
            // Click to return item to inventory
            if let s = gameState.player.craftingGrid[index] {
                if gameState.player.addItem(s) {
                    gameState.player.craftingGrid[index] = nil
                    gameState.player.updateCrafting()
                }
            }
        }
    }

    private func inventorySlotView(index: Int) -> some View {
        let stack = gameState.player.inventory[index]
        return slotBox(stack: stack) {
            // Move into crafting grid or hotbar
            if let s = stack {
                moveItemToCrafting(stack: s, fromInventoryIndex: index)
            }
        }
    }

    private func hotbarSlotView(index: Int) -> some View {
        let stack = gameState.player.hotbar[index]
        return slotBox(stack: stack) {
            if let s = stack {
                moveItemToCrafting(stack: s, fromHotbarIndex: index)
            }
        }
    }

    private func slotBox(stack: ItemStack?, onTap: @escaping () -> Void) -> some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(0.5))
                .frame(width: 44, height: 44)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3), lineWidth: 1))

            if let s = stack {
                Image(systemName: s.item.iconSymbol)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if s.count > 1 {
                    Text("\(s.count)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(2)
                }
            }
        }
        .frame(width: 44, height: 44)
        .onTapGesture(perform: onTap)
    }

    private func moveItemToCrafting(stack: ItemStack, fromInventoryIndex: Int? = nil, fromHotbarIndex: Int? = nil) {
        // Find empty slot in 2x2 grid
        for i in 0..<4 {
            if gameState.player.craftingGrid[i] == nil {
                gameState.player.craftingGrid[i] = ItemStack(item: stack.item, count: 1)
                if let invIdx = fromInventoryIndex {
                    var s = gameState.player.inventory[invIdx]!
                    s.count -= 1
                    gameState.player.inventory[invIdx] = s.count > 0 ? s : nil
                } else if let hotIdx = fromHotbarIndex {
                    var s = gameState.player.hotbar[hotIdx]!
                    s.count -= 1
                    gameState.player.hotbar[hotIdx] = s.count > 0 ? s : nil
                }
                gameState.player.updateCrafting()
                break
            }
        }
    }

    private func recipeRow(title: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(desc)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.gray)
        }
    }
}
