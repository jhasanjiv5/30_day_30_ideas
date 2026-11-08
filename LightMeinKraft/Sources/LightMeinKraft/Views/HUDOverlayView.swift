import SwiftUI

public struct HUDOverlayView: View {
    @ObservedObject var gameState: GameState

    public var body: some View {
        ZStack {
            // 1. Center Crosshair
            Circle()
                .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                .frame(width: 12, height: 12)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 2, height: 16)
                )
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 16, height: 2)
                )

            // 2. Boss Health Bar (Top Center)
            if let bossHp = gameState.bossHealth, let maxHp = gameState.bossMaxHealth, bossHp > 0 {
                VStack(spacing: 4) {
                    Text("❄️ ABOMINABLE FROST GRINCH ❄️")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan)
                        .shadow(color: .black, radius: 2)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.black.opacity(0.7))
                                .frame(height: 14)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, geo.size.width * CGFloat(bossHp / maxHp)), height: 14)

                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color.white.opacity(0.6), lineWidth: 1)
                                .frame(height: 14)
                        }
                    }
                    .frame(width: 380, height: 14)
                }
                .padding(.top, 16)
                .frame(maxHeight: .infinity, alignment: .top)
            }

            // 3. Quest & Objective Tracker (Top Right)
            VStack(alignment: .trailing, spacing: 6) {
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "tree.fill")
                            .foregroundColor(.green)
                        Text(gameState.currentLevel.title)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.yellow)
                    }

                    ForEach(gameState.currentLevel.objectives) { obj in
                        HStack(spacing: 6) {
                            Text(obj.description)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(obj.isComplete ? .green : .white)
                            Text("(\(obj.currentCount)/\(obj.targetCount))")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(obj.isComplete ? .green : .orange)
                            Image(systemName: obj.isComplete ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(obj.isComplete ? .green : .gray)
                                .font(.system(size: 11))
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.65))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                        )
                )

                // Score banner
                HStack(spacing: 12) {
                    Text("SCORE: \(gameState.score)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("MINED: \(gameState.blocksMinedCount)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.cyan)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.6))
                )
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            // 4. Notification Banner (Top Left)
            if let notif = gameState.activeNotification {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.yellow)
                    Text(notif)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.yellow.opacity(0.8), lineWidth: 1.5)
                        )
                )
                .padding(.top, 16)
                .padding(.leading, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // 5. Controls Guide Hint (Bottom Left)
            VStack(alignment: .leading, spacing: 2) {
                Text("WASD: Move • Space: Jump • Shift: Sneak")
                Text("Left Click: Mine / Attack • Right Click: Place / Eat")
                Text("E: Crafting & Inventory • Esc: Pause • 1-9: Hotbar")
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(.white.opacity(0.75))
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.45)))
            .padding(.leading, 16)
            .padding(.bottom, 75)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            // 6. Hearts & Hotbar (Bottom Center)
            VStack(spacing: 6) {
                // Hearts Bar (10 Hearts)
                HStack(spacing: 3) {
                    ForEach(0..<10, id: \.self) { idx in
                        let hp = gameState.player.health
                        let fullLimit = Float((idx + 1) * 2)
                        let halfLimit = Float(idx * 2 + 1)

                        if hp >= fullLimit {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                        } else if hp >= halfLimit {
                            Image(systemName: "heart.lefthalf.filled")
                                .foregroundColor(.red)
                        } else {
                            Image(systemName: "heart")
                                .foregroundColor(.gray.opacity(0.5))
                        }
                    }
                    .font(.system(size: 14))
                    .shadow(color: .black, radius: 2)
                }

                // Selected Item Name Tooltip
                if let sel = gameState.player.selectedItem {
                    Text(sel.item.name)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                        .shadow(color: .black, radius: 2)
                } else {
                    Text("Empty Hand")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }

                // 9-Slot Hotbar
                HStack(spacing: 4) {
                    ForEach(0..<9, id: \.self) { idx in
                        let isSelected = (idx == gameState.player.selectedSlot)
                        let stack = gameState.player.hotbar[idx]

                        ZStack(alignment: .bottomTrailing) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isSelected ? Color.white.opacity(0.25) : Color.black.opacity(0.6))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(isSelected ? Color.white : Color.gray.opacity(0.4), lineWidth: isSelected ? 2.5 : 1)
                                )

                            if let s = stack {
                                Image(systemName: s.item.iconSymbol)
                                    .font(.system(size: 20))
                                    .foregroundColor(itemColor(for: s.item))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                                if s.count > 1 {
                                    Text("\(s.count)")
                                        .font(.system(size: 11, weight: .black, design: .monospaced))
                                        .foregroundColor(.white)
                                        .shadow(color: .black, radius: 2)
                                        .padding(2)
                                }
                            }

                            // Slot number indicator
                            Text("\(idx + 1)")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.8))
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .padding(2)
                        }
                        .frame(width: 44, height: 44)
                        .onTapGesture {
                            gameState.player.selectedSlot = idx
                        }
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .padding(.bottom, 12)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func itemColor(for item: Item) -> Color {
        if let block = item.blockType {
            switch block {
            case .snowGrass: return .white
            case .dirt: return .brown
            case .stone, .cobblestone: return .gray
            case .pineLog: return Color(red: 0.5, green: 0.3, blue: 0.1)
            case .pineLeaves: return .green
            case .pinePlanks: return Color(red: 0.7, green: 0.5, blue: 0.2)
            case .candyCane: return .red
            case .ice: return .cyan
            case .presentRed: return .red
            case .presentGreen: return .green
            case .holidayTorch: return .orange
            case .goldenStar: return .yellow
            case .frostNetherrack: return .purple
            case .gingerbread: return Color(red: 0.8, green: 0.5, blue: 0.2)
            case .portalBlock: return .indigo
            }
        }
        if item.id == Item.candyCaneSword.id { return .red }
        if item.id == Item.woodenPickaxe.id { return .orange }
        if item.id == Item.festiveCookie.id { return .yellow }
        return .white
    }
}
