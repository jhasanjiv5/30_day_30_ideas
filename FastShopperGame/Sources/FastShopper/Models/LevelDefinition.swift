import Foundation

public struct LevelConfig: Identifiable {
    public let id: Int
    public let title: String
    public let subtitle: String
    public let locationNote: String
    public let initialCredit: Double
    public let timeLimit: TimeInterval
    public let requiredItemCount: Int
    public let themeColorHex: String
    
    public static let levels: [LevelConfig] = [
        LevelConfig(
            id: 1,
            title: "Level 1: Macy's Herald Square Rush (1984)",
            subtitle: "3 Gifts • $75.00 Credit • 90 Seconds",
            locationNote: "Herald Square, NYC • Christmas Eve 9:00 AM",
            initialCredit: 75.00,
            timeLimit: 90.0,
            requiredItemCount: 3,
            themeColorHex: "#D42426"
        ),
        LevelConfig(
            id: 2,
            title: "Level 2: Bloomingdale's Blizzard Frenzy",
            subtitle: "5 Gifts • $160.00 Credit • 75 Seconds",
            locationNote: "59th & Lexington • Snow piling up on yellow cabs outside",
            initialCredit: 160.00,
            timeLimit: 75.0,
            requiredItemCount: 5,
            themeColorHex: "#D4AF37"
        ),
        LevelConfig(
            id: 3,
            title: "Level 3: Saks Fifth Ave Midnight Miracle",
            subtitle: "7 Gifts • $350.00 Credit • 60 Seconds",
            locationNote: "Rockefeller Center & 5th Ave • Final countdown before midnight!",
            initialCredit: 350.00,
            timeLimit: 60.0,
            requiredItemCount: 7,
            themeColorHex: "#1E824C"
        )
    ]
}
