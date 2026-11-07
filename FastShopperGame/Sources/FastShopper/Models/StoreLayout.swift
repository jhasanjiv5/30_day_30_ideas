import Foundation
import CoreGraphics

public struct ShelfSection: Identifiable {
    public let id: Int
    public let aisle: Int
    public let category: ProductCategory
    public let rect: CGRect
    public let label: String
    public let colorHex: String
    public let availableItems: [ProductItem]
}

public struct CheckoutCounter: Identifiable {
    public let id: Int
    public let rect: CGRect
    public let registerNumber: Int
    public let name: String
    public let isExpress: Bool
}

public struct StoreCatalog {
    public static let allCatalogItems: [ProductItem] = [
        // 1984 Toys & Arcade
        ProductItem(baseName: "Cabbage Patch Doll", category: .toys, tier: .budget, basePrice: 22.00, emoji: "👶", recipeTag: "Holiday Morning"),
        ProductItem(baseName: "Cabbage Patch Doll", category: .toys, tier: .standard, basePrice: 32.00, emoji: "👶", recipeTag: "Holiday Morning"),
        ProductItem(baseName: "Cabbage Patch Doll", category: .toys, tier: .gourmet, basePrice: 52.00, emoji: "👶", recipeTag: "Holiday Morning"),
        
        ProductItem(baseName: "Rubik's Revenge Cube", category: .toys, tier: .budget, basePrice: 8.00, emoji: "🧩", recipeTag: "Stocking Stuffer"),
        ProductItem(baseName: "Rubik's Revenge Cube", category: .toys, tier: .standard, basePrice: 14.00, emoji: "🧩", recipeTag: "Stocking Stuffer"),
        
        ProductItem(baseName: "Teddy Ruxpin", category: .toys, tier: .standard, basePrice: 38.00, emoji: "🧸", recipeTag: "Holiday Morning"),
        ProductItem(baseName: "Teddy Ruxpin", category: .toys, tier: .gourmet, basePrice: 64.00, emoji: "🧸", recipeTag: "Holiday Morning"),

        // Holiday Bakery
        ProductItem(baseName: "Glazed Gingerbread Man", category: .bakery, tier: .budget, basePrice: 4.50, emoji: "🍪", recipeTag: "Yuletide Treat"),
        ProductItem(baseName: "Glazed Gingerbread Man", category: .bakery, tier: .standard, basePrice: 7.00, emoji: "🍪", recipeTag: "Yuletide Treat"),
        ProductItem(baseName: "Glazed Gingerbread Man", category: .bakery, tier: .gourmet, basePrice: 12.00, emoji: "🍪", recipeTag: "Yuletide Treat"),

        ProductItem(baseName: "NYC Panettone Loaf", category: .bakery, tier: .budget, basePrice: 10.00, emoji: "🍞", recipeTag: "Holiday Feast"),
        ProductItem(baseName: "NYC Panettone Loaf", category: .bakery, tier: .standard, basePrice: 18.00, emoji: "🍞", recipeTag: "Holiday Feast"),
        ProductItem(baseName: "NYC Panettone Loaf", category: .bakery, tier: .gourmet, basePrice: 30.00, emoji: "🍞", recipeTag: "Holiday Feast"),

        ProductItem(baseName: "Peppermint Candy Canes", category: .bakery, tier: .budget, basePrice: 3.50, emoji: "🦯", recipeTag: "Stocking Stuffer"),
        ProductItem(baseName: "Peppermint Candy Canes", category: .bakery, tier: .standard, basePrice: 6.00, emoji: "🦯", recipeTag: "Stocking Stuffer"),

        // Eggnog & Drinks
        ProductItem(baseName: "Creamy Spiced Eggnog", category: .spirits, tier: .budget, basePrice: 5.50, emoji: "🥛", recipeTag: "Yuletide Treat"),
        ProductItem(baseName: "Creamy Spiced Eggnog", category: .spirits, tier: .standard, basePrice: 9.00, emoji: "🥛", recipeTag: "Yuletide Treat"),
        ProductItem(baseName: "Creamy Spiced Eggnog", category: .spirits, tier: .gourmet, basePrice: 16.00, emoji: "🥛", recipeTag: "Yuletide Treat"),

        ProductItem(baseName: "Hot Mulled Cider", category: .spirits, tier: .standard, basePrice: 7.50, emoji: "☕️", recipeTag: "Warm Hearth"),
        ProductItem(baseName: "Vintage Champagne '82", category: .spirits, tier: .standard, basePrice: 28.00, emoji: "🍾", recipeTag: "Manhattan Gala"),
        ProductItem(baseName: "Vintage Champagne '82", category: .spirits, tier: .gourmet, basePrice: 48.00, emoji: "🍾", recipeTag: "Manhattan Gala"),

        // Christmas Feast
        ProductItem(baseName: "Honey-Glazed Holiday Ham", category: .feast, tier: .budget, basePrice: 18.00, emoji: "🍖", recipeTag: "Holiday Feast"),
        ProductItem(baseName: "Honey-Glazed Holiday Ham", category: .feast, tier: .standard, basePrice: 28.00, emoji: "🍖", recipeTag: "Holiday Feast"),
        ProductItem(baseName: "Honey-Glazed Holiday Ham", category: .feast, tier: .gourmet, basePrice: 46.00, emoji: "🍖", recipeTag: "Holiday Feast"),

        ProductItem(baseName: "Roast Heritage Turkey", category: .feast, tier: .standard, basePrice: 32.00, emoji: "🍗", recipeTag: "Holiday Feast"),
        ProductItem(baseName: "Roast Heritage Turkey", category: .feast, tier: .gourmet, basePrice: 54.00, emoji: "🍗", recipeTag: "Holiday Feast"),

        // NYC Confections
        ProductItem(baseName: "Fifth Ave Truffle Tin", category: .confections, tier: .budget, basePrice: 10.00, emoji: "🍫", recipeTag: "Stocking Stuffer"),
        ProductItem(baseName: "Fifth Ave Truffle Tin", category: .confections, tier: .standard, basePrice: 18.00, emoji: "🍫", recipeTag: "Stocking Stuffer"),
        ProductItem(baseName: "Fifth Ave Truffle Tin", category: .confections, tier: .gourmet, basePrice: 32.00, emoji: "🍫", recipeTag: "Stocking Stuffer"),

        ProductItem(baseName: "Roasted Street Chestnuts", category: .confections, tier: .standard, basePrice: 8.00, emoji: "🌰", recipeTag: "Warm Hearth"),

        // Vintage Tech & Tapes
        ProductItem(baseName: "Walkman Portable Cassette", category: .electronics, tier: .budget, basePrice: 28.00, emoji: "📼", recipeTag: "80s Tech"),
        ProductItem(baseName: "Walkman Portable Cassette", category: .electronics, tier: .standard, basePrice: 45.00, emoji: "📼", recipeTag: "80s Tech"),
        ProductItem(baseName: "Walkman Portable Cassette", category: .electronics, tier: .gourmet, basePrice: 75.00, emoji: "📼", recipeTag: "80s Tech"),

        ProductItem(baseName: "Polaroid 600 Camera", category: .electronics, tier: .standard, basePrice: 38.00, emoji: "📷", recipeTag: "80s Tech"),
        ProductItem(baseName: "Polaroid 600 Camera", category: .electronics, tier: .gourmet, basePrice: 62.00, emoji: "📷", recipeTag: "80s Tech"),

        ProductItem(baseName: "Holiday Vinyl Record '84", category: .electronics, tier: .standard, basePrice: 15.00, emoji: "💿", recipeTag: "Yuletide Treat"),

        // 5th Ave Holiday Decor
        ProductItem(baseName: "Carved Wooden Nutcracker", category: .decor, tier: .budget, basePrice: 16.00, emoji: "💂", recipeTag: "Holiday Morning"),
        ProductItem(baseName: "Carved Wooden Nutcracker", category: .decor, tier: .standard, basePrice: 26.00, emoji: "💂", recipeTag: "Holiday Morning"),
        ProductItem(baseName: "Carved Wooden Nutcracker", category: .decor, tier: .gourmet, basePrice: 44.00, emoji: "💂", recipeTag: "Holiday Morning"),

        ProductItem(baseName: "Glass Central Park Snowglobe", category: .decor, tier: .standard, basePrice: 22.00, emoji: "🔮", recipeTag: "Stocking Stuffer"),
        ProductItem(baseName: "Cashmere Winter Scarf", category: .decor, tier: .standard, basePrice: 30.00, emoji: "🧣", recipeTag: "Warm Hearth"),
        ProductItem(baseName: "Cashmere Winter Scarf", category: .decor, tier: .gourmet, basePrice: 58.00, emoji: "🧣", recipeTag: "Warm Hearth")
    ]
}

public struct StoreMap {
    public static let worldWidth: CGFloat = 1600
    public static let worldHeight: CGFloat = 1050
    
    public static func makeShelves() -> [ShelfSection] {
        var sections: [ShelfSection] = []
        let categories = ProductCategory.allCases
        
        let startX: CGFloat = 260
        let spacingX: CGFloat = 175
        let shelfWidth: CGFloat = 90
        let shelfHeightTop: CGFloat = 280
        let shelfHeightBottom: CGFloat = 280
        let bottomShelfY: CGFloat = 280
        let topShelfY: CGFloat = 680
        
        for (index, cat) in categories.enumerated() {
            let xPos = startX + CGFloat(index) * spacingX
            let catItems = StoreCatalog.allCatalogItems.filter { $0.category == cat }
            
            // South shelf
            sections.append(ShelfSection(
                id: (index + 1) * 10 + 1,
                aisle: cat.aisleNumber,
                category: cat,
                rect: CGRect(x: xPos - shelfWidth / 2, y: bottomShelfY, width: shelfWidth, height: shelfHeightBottom),
                label: "Aisle \(cat.aisleNumber): \(cat.rawValue) 🎄",
                colorHex: colorForCategory(cat),
                availableItems: catItems
            ))
            
            // North shelf
            sections.append(ShelfSection(
                id: (index + 1) * 10 + 2,
                aisle: cat.aisleNumber,
                category: cat,
                rect: CGRect(x: xPos - shelfWidth / 2, y: topShelfY, width: shelfWidth, height: shelfHeightTop),
                label: "Aisle \(cat.aisleNumber): \(cat.rawValue) ✨",
                colorHex: colorForCategory(cat),
                availableItems: catItems
            ))
        }
        
        return sections
    }
    
    public static func makeCheckouts() -> [CheckoutCounter] {
        return [
            CheckoutCounter(id: 1, rect: CGRect(x: 390, y: 110, width: 145, height: 75), registerNumber: 1, name: "GIFT WRAP & PAY #1 🎁", isExpress: true),
            CheckoutCounter(id: 2, rect: CGRect(x: 610, y: 110, width: 145, height: 75), registerNumber: 2, name: "SANTA'S EXPRESS #2 🎄", isExpress: false),
            CheckoutCounter(id: 3, rect: CGRect(x: 830, y: 110, width: 145, height: 75), registerNumber: 3, name: "5th AVE CASHIER #3 ✨", isExpress: false),
            CheckoutCounter(id: 4, rect: CGRect(x: 1050, y: 110, width: 145, height: 75), registerNumber: 4, name: "HERALD SQ REGISTER #4 🎅", isExpress: true)
        ]
    }
    
    private static func colorForCategory(_ category: ProductCategory) -> String {
        switch category {
        case .toys: return "#E74C3C"        // Christmas Red
        case .bakery: return "#D4AF37"      // Warm Gold
        case .spirits: return "#27AE60"     // Pine Forest Green
        case .feast: return "#C0392B"       // Cranberry
        case .confections: return "#F39C12" // Golden Amber
        case .electronics: return "#2980B9" // 80s Retro Blue
        case .decor: return "#8E44AD"       // Regal Velvet Purple
        }
    }
}
