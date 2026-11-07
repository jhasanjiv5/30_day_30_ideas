import Foundation
import CoreGraphics

public enum ProductCategory: String, CaseIterable, Codable {
    case toys = "1984 Toys & Arcade"
    case bakery = "Holiday Bakery"
    case spirits = "Eggnog & Drinks"
    case feast = "Christmas Feast"
    case confections = "NYC Confections"
    case electronics = "Vintage Tech & Tapes"
    case decor = "5th Ave Holiday Decor"
    
    public var icon: String {
        switch self {
        case .toys: return "🧸"
        case .bakery: return "🍪"
        case .spirits: return "🥛"
        case .feast: return "🍗"
        case .confections: return "🍬"
        case .electronics: return "📼"
        case .decor: return "🎄"
        }
    }
    
    public var aisleNumber: Int {
        switch self {
        case .toys: return 1
        case .bakery: return 2
        case .spirits: return 3
        case .feast: return 4
        case .confections: return 5
        case .electronics: return 6
        case .decor: return 7
        }
    }
}

public enum BrandTier: String, CaseIterable, Codable {
    case budget = "Canal St. Saver"
    case standard = "5th Ave Classic"
    case gourmet = "Saks Luxury Edition"
    
    public var multiplier: Double {
        switch self {
        case .budget: return 0.75
        case .standard: return 1.0
        case .gourmet: return 1.70
        }
    }
    
    public var qualityBadge: String {
        switch self {
        case .budget: return "🏷 Canal St."
        case .standard: return "✨ 5th Ave"
        case .gourmet: return "👑 Saks Luxury"
        }
    }
    
    public var scoreMultiplier: Int {
        switch self {
        case .budget: return 120
        case .standard: return 240
        case .gourmet: return 500
        }
    }
}

public struct ProductItem: Identifiable, Equatable, Hashable {
    public let id: UUID
    public let baseName: String
    public let category: ProductCategory
    public let tier: BrandTier
    public let basePrice: Double
    public let emoji: String
    public let recipeTag: String?
    
    public var price: Double {
        let raw = basePrice * tier.multiplier
        return (raw * 100).rounded() / 100
    }
    
    public var fullName: String {
        "\(tier.rawValue) \(baseName)"
    }
    
    public init(id: UUID = UUID(), baseName: String, category: ProductCategory, tier: BrandTier, basePrice: Double, emoji: String, recipeTag: String? = nil) {
        self.id = id
        self.baseName = baseName
        self.category = category
        self.tier = tier
        self.basePrice = basePrice
        self.emoji = emoji
        self.recipeTag = recipeTag
    }
}

public struct ShoppingTarget: Identifiable, Equatable {
    public let id: UUID
    public let category: ProductCategory
    public let targetBaseName: String
    public let emoji: String
    public var acquiredProduct: ProductItem?
    
    public var isCompleted: Bool {
        acquiredProduct != nil
    }
    
    public init(id: UUID = UUID(), category: ProductCategory, targetBaseName: String, emoji: String, acquiredProduct: ProductItem? = nil) {
        self.id = id
        self.category = category
        self.targetBaseName = targetBaseName
        self.emoji = emoji
        self.acquiredProduct = acquiredProduct
    }
}
