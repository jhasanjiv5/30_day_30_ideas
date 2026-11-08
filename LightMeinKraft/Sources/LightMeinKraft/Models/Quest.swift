import Foundation

public struct Objective: Identifiable, Sendable {
    public let id: String
    public let description: String
    public let targetCount: Int
    public var currentCount: Int

    public var isComplete: Bool {
        return currentCount >= targetCount
    }

    public init(id: String, description: String, targetCount: Int, currentCount: Int = 0) {
        self.id = id
        self.description = description
        self.targetCount = targetCount
        self.currentCount = currentCount
    }
}

public struct QuestLevel: Identifiable, Sendable {
    public var id: Int { levelNumber }
    public let levelNumber: Int
    public let title: String
    public let subtitle: String
    public let story: String
    public var objectives: [Objective]

    public var isComplete: Bool {
        return objectives.allSatisfy { $0.isComplete }
    }

    public static func level1() -> QuestLevel {
        return QuestLevel(
            levelNumber: 1,
            title: "Level 1: Snowy Taiga & Star Portal",
            subtitle: "Gather winter resources & ignite the Portal",
            story: "You awake in a snowy taiga forest. To reach Santa's North Pole Workshop, gather snowy pine wood, craft festive torches, and forge the Golden Star to activate the Star Portal!",
            objectives: [
                Objective(id: "mine_wood", description: "Mine 5 Pine Logs", targetCount: 5),
                Objective(id: "craft_planks", description: "Craft 8 Pine Planks", targetCount: 8),
                Objective(id: "mine_candy", description: "Mine 4 Candy Cane Blocks", targetCount: 4),
                Objective(id: "craft_torches", description: "Craft 4 Holiday Torches", targetCount: 4),
                Objective(id: "activate_portal", description: "Craft & Place the Golden Star Portal", targetCount: 1)
            ]
        )
    }

    public static func level2() -> QuestLevel {
        return QuestLevel(
            levelNumber: 2,
            title: "Level 2: Santa's Frozen Workshop",
            subtitle: "Defeat the Frost Grinch & Place the Star of Wonder",
            story: "You emerge into the Frozen Workshop! The Abominable Frost Grinch has cursed Santa's realm. Defeat the boss, retrieve the Star of Wonder, and place it atop the Grand Christmas Tree to save Christmas!",
            objectives: [
                Objective(id: "mine_frost", description: "Mine 6 Frost Netherrack or Gingerbread", targetCount: 6),
                Objective(id: "defeat_boss", description: "Defeat the Abominable Frost Grinch", targetCount: 1),
                Objective(id: "place_star", description: "Place the Golden Star atop the Grand Tree", targetCount: 1)
            ]
        )
    }
}
