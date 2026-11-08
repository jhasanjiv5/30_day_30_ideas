import Foundation
import Combine
import SceneKit

public enum GameScreen: Equatable {
    case mainMenu
    case playing
    case paused
    case inventory
    case gameOver
    case victory
}

@MainActor
public final class GameState: ObservableObject {
    public static let shared = GameState()

    @Published public var currentScreen: GameScreen = .mainMenu
    @Published public var player: Player = Player()
    @Published public var currentLevel: QuestLevel = QuestLevel.level1()
    @Published public var score: Int = 0
    @Published public var blocksMinedCount: Int = 0
    @Published public var mobsDefeatedCount: Int = 0
    @Published public var isMuted: Bool = false
    @Published public var activeNotification: String? = nil
    @Published public var bossHealth: Float? = nil
    @Published public var bossMaxHealth: Float? = nil

    private var notificationTimer: AnyCancellable?

    public init() {}

    public func startNewGame(levelNumber: Int = 1) {
        player = Player(position: SCNVector3(16, 12, 16))
        score = 0
        blocksMinedCount = 0
        mobsDefeatedCount = 0
        bossHealth = nil
        bossMaxHealth = nil

        if levelNumber == 1 {
            currentLevel = QuestLevel.level1()
            showNotification("Level 1: Winter Wonderland! Mine wood & ignite the Star Portal.")
        } else {
            currentLevel = QuestLevel.level2()
            showNotification("Level 2: Santa's Frozen Workshop! Defeat the Grinch & save Christmas!")
        }
        currentScreen = .playing
    }

    public func advanceToLevel2() {
        score += 500
        currentLevel = QuestLevel.level2()
        player.position = SCNVector3(16, 12, 16)
        showNotification("Portal Activated! Entering Santa's Frozen Nether Workshop...")
        SoundManager.shared.playFanfare()
    }

    public func showNotification(_ message: String, duration: TimeInterval = 3.5) {
        activeNotification = message
        notificationTimer?.cancel()
        notificationTimer = Just(())
            .delay(for: .seconds(duration), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.activeNotification = nil
            }
    }

    public func recordBlockMined(type: BlockType) {
        blocksMinedCount += 1
        score += type.scoreValue
        SoundManager.shared.playBlockBreak()

        // Update objectives
        if currentLevel.levelNumber == 1 {
            if type == .pineLog {
                advanceObjective(id: "mine_wood")
            } else if type == .candyCane {
                advanceObjective(id: "mine_candy")
            }
        } else if currentLevel.levelNumber == 2 {
            if type == .frostNetherrack || type == .gingerbread {
                advanceObjective(id: "mine_frost")
            }
        }
    }

    public func recordBlockPlaced(type: BlockType) {
        SoundManager.shared.playBlockPlace()

        if currentLevel.levelNumber == 1 {
            if type == .holidayTorch {
                advanceObjective(id: "craft_torches")
            } else if type == .portalBlock || type == .goldenStar {
                advanceObjective(id: "activate_portal")
                showNotification("Star Portal placed! Press Enter or step inside to enter Level 2!")
            }
        } else if currentLevel.levelNumber == 2 {
            if type == .goldenStar {
                advanceObjective(id: "place_star")
                triggerVictory()
            }
        }
    }

    public func recordItemCrafted(item: Item, count: Int) {
        if item.blockType == .pinePlanks {
            advanceObjective(id: "craft_planks", count: count)
        } else if item.blockType == .holidayTorch {
            advanceObjective(id: "craft_torches", count: count)
        }
        SoundManager.shared.playCraft()
    }

    public func recordMobKilled(mob: Mob) {
        mobsDefeatedCount += 1
        score += (mob.type == .frostGrinch ? 1000 : 150)
        SoundManager.shared.playMobDefeated()

        if mob.type == .frostGrinch {
            bossHealth = 0
            advanceObjective(id: "defeat_boss")
            showNotification("Frost Grinch Defeated! The Star of Wonder is yours! Place it on the tree!")
            _ = player.addItem(ItemStack(block: .goldenStar, count: 1))
        }
    }

    public func advanceObjective(id: String, count: Int = 1) {
        for i in 0..<currentLevel.objectives.count {
            if currentLevel.objectives[i].id == id {
                currentLevel.objectives[i].currentCount += count
                if currentLevel.objectives[i].isComplete {
                    showNotification("Quest Updated: \(currentLevel.objectives[i].description) Complete!")
                    SoundManager.shared.playQuestComplete()
                }
                break
            }
        }

        // Check level 1 unlock
        if currentLevel.levelNumber == 1 && currentLevel.isComplete {
            showNotification("Level 1 Complete! Step into the Star Portal to enter Level 2!")
        }
    }

    public func triggerGameOver() {
        currentScreen = .gameOver
        SoundManager.shared.playHurt()
    }

    public func triggerVictory() {
        score += 2000
        currentScreen = .victory
        SoundManager.shared.playFanfare()
    }
}
