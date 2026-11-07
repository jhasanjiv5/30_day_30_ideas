import Foundation
import CoreGraphics

public struct CopilotAdvice: Identifiable, Equatable {
    public let id = UUID()
    public let timestamp: Date
    public let headline: String
    public let message: String
    public let targetAisle: Int?
    public let recommendedTier: BrandTier?
    public let urgency: UrgencyLevel
    
    public enum UrgencyLevel {
        case normal
        case suggestion
        case alert
        case victory
    }
}

public class CopilotReasoner {
    public var assistantName: String = "Miracle-84 AI"
    public private(set) var latestAdvice: CopilotAdvice
    public private(set) var thoughtLog: [String] = []
    
    public init() {
        self.latestAdvice = CopilotAdvice(
            timestamp: Date(),
            headline: "Macy's Herald Sq. Terminal Online",
            message: "Merry Christmas, pal! I'm your Miracle-84 AI holiday concierge. Snow's falling heavy on Broadway. Check your holiday gift list and steer through the aisles!",
            targetAisle: nil,
            recommendedTier: nil,
            urgency: .normal
        )
        self.thoughtLog.append("Miracle-84 mainframe boot OK. Holiday crowds mapped. Tracking cart across Herald Square floor.")
    }
    
    public func update(
        cartPosition: CGPoint,
        shoppingList: [ShoppingTarget],
        remainingCredit: Double,
        initialCredit: Double,
        timeRemaining: TimeInterval,
        shelves: [ShelfSection],
        cartItems: [ProductItem]
    ) {
        let uncompleted = shoppingList.filter { !$0.isCompleted }
        
        // 1. All gifts secured
        if uncompleted.isEmpty {
            let advice = CopilotAdvice(
                timestamp: Date(),
                headline: "All Gifts Bagged! Rush to Gift Wrap & Pay!",
                message: "Every gift on your list is in the cart! Sprint to Registers 1-4 at the south exit before Christmas Eve closing bells chime!",
                targetAisle: nil,
                recommendedTier: nil,
                urgency: .victory
            )
            setAdvice(advice, thought: "All targets fulfilled. Rerouting cart to nearest holiday wrapping counter.")
            return
        }
        
        // 2. Urgent Time Warning
        if timeRemaining < 15.0 {
            let advice = CopilotAdvice(
                timestamp: Date(),
                headline: "CRITICAL: \(Int(timeRemaining))s Before Store Closes!",
                message: "Closing time is here! Dash straight to Aisle \(uncompleted.first?.category.aisleNumber ?? 1) for \(uncompleted.first?.targetBaseName ?? "gift")! Don't look back!",
                targetAisle: uncompleted.first?.category.aisleNumber,
                recommendedTier: .budget,
                urgency: .alert
            )
            setAdvice(advice, thought: "Time emergency: Manhattan shoppers packing the exits. Recommending direct sprint.")
            return
        }
        
        // 3. Find closest missing target
        var closestTarget: ShoppingTarget?
        var closestDistance: CGFloat = .infinity
        var targetAisleNum: Int = 1
        
        for target in uncompleted {
            let matchingShelves = shelves.filter { $0.category == target.category }
            for shelf in matchingShelves {
                let shelfCenter = CGPoint(x: shelf.rect.midX, y: shelf.rect.midY)
                let dist = hypot(cartPosition.x - shelfCenter.x, cartPosition.y - shelfCenter.y)
                if dist < closestDistance {
                    closestDistance = dist
                    closestTarget = target
                    targetAisleNum = shelf.aisle
                }
            }
        }
        
        guard let currentTarget = closestTarget else { return }
        
        // 4. Budget & Tier Optimization Reasoning (1980s NYC flavor)
        let remainingItemCount = max(uncompleted.count, 1)
        let averageBudgetPerItem = remainingCredit / Double(remainingItemCount)
        
        let recommendedTier: BrandTier
        let tierRationale: String
        
        if averageBudgetPerItem > 32.0 {
            recommendedTier = .gourmet
            tierRationale = "Big holiday surplus ($\(String(format: "%.2f", remainingCredit)) left)! Upgrade to Saks 5th Ave Luxury Edition for maximum festive score bonus!"
        } else if averageBudgetPerItem < 12.0 {
            recommendedTier = .budget
            tierRationale = "Tight holiday budget ($\(String(format: "%.2f", remainingCredit)) remaining). Pick Canal St. Savers to keep from overspending your credit!"
        } else {
            recommendedTier = .standard
            tierRationale = "Budget is on track for 5th Avenue Classic gifts."
        }
        
        // 5. Check Holiday Combo Synergy
        var synergyHint = ""
        let acquiredNames = cartItems.map { $0.baseName }
        if acquiredNames.contains("Creamy Spiced Eggnog") && currentTarget.targetBaseName == "Glazed Gingerbread Man" {
            synergyHint = " 🎄 Holiday Synergy: Eggnog + Gingerbread Man triggers 'Yuletide Cheer' (+450 pts)!"
        } else if acquiredNames.contains("Walkman Portable Cassette") && currentTarget.targetBaseName == "Polaroid 600 Camera" {
            synergyHint = " 📼 80s Tech Synergy: Walkman + Polaroid triggers 'Radical Christmas '84' (+550 pts)!"
        }
        
        let distancePaces = Int(closestDistance / 20.0)
        let advice = CopilotAdvice(
            timestamp: Date(),
            headline: "Target: \(currentTarget.emoji) \(currentTarget.targetBaseName)",
            message: "Aisle \(targetAisleNum) (\(currentTarget.category.rawValue)), approx \(distancePaces) paces away. \(tierRationale)\(synergyHint)",
            targetAisle: targetAisleNum,
            recommendedTier: recommendedTier,
            urgency: .suggestion
        )
        
        setAdvice(advice, thought: "Calculated vector toward Aisle \(targetAisleNum) (\(currentTarget.targetBaseName)). Suggesting \(recommendedTier.rawValue).")
    }
    
    private func setAdvice(_ advice: CopilotAdvice, thought: String) {
        if latestAdvice.headline != advice.headline || latestAdvice.urgency != advice.urgency {
            self.latestAdvice = advice
            self.thoughtLog.append(thought)
            if self.thoughtLog.count > 6 {
                self.thoughtLog.removeFirst()
            }
        }
    }
    
    public func consultOnDemand(
        cartPosition: CGPoint,
        shoppingList: [ShoppingTarget],
        remainingCredit: Double,
        timeRemaining: TimeInterval
    ) -> String {
        let uncompleted = shoppingList.filter { !$0.isCompleted }
        if uncompleted.isEmpty {
            return "All holiday presents secured! Steer south to Santa's Gift Wrap & Registers before midnight strikes!"
        }
        let names = uncompleted.map { "\($0.emoji) \($0.targetBaseName)" }.joined(separator: ", ")
        let avg = remainingCredit / Double(uncompleted.count)
        return "1984 Herald Sq. Dispatch: You still need [\(names)]. Remaining credit: $\(String(format: "%.2f", remainingCredit)) ($\(String(format: "%.2f", avg))/gift). Clock has \(Int(timeRemaining))s left. Stay on the throttle!"
    }
}
