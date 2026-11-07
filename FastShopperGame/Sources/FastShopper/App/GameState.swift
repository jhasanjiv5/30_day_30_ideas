import Foundation
import SwiftUI
import Combine

public enum GamePhase: Equatable {
    case ready
    case playing
    case paused
    case levelCompleted
    case gameOver(reason: String)
    case gameWon
}

@MainActor
public final class GameState: ObservableObject {
    public static let shared = GameState()
    
    // Level & Status
    @Published public var currentLevelIndex: Int = 1
    @Published public var phase: GamePhase = .ready
    @Published public var timeRemaining: TimeInterval = 90.0
    @Published public var score: Int = 0
    @Published public var highScores: Int = 0
    
    // Economy & Inventory
    @Published public var initialCredit: Double = 75.0
    @Published public var remainingCredit: Double = 75.0
    @Published public var shoppingList: [ShoppingTarget] = []
    @Published public var cartItems: [ProductItem] = []
    @Published public var recentBonuses: [String] = []
    
    // AI Copilot
    public let copilot = CopilotReasoner()
    @Published public var copilotAdvice: CopilotAdvice = CopilotAdvice(
        timestamp: Date(),
        headline: "Terminal Ready",
        message: "Start your run to initialize Miracle-84 AI.",
        targetAisle: nil,
        recommendedTier: nil,
        urgency: .normal
    )
    
    // World entities
    public let shelves: [ShelfSection] = StoreMap.makeShelves()
    public let checkouts: [CheckoutCounter] = StoreMap.makeCheckouts()
    public let cartController = CartController()
    
    // Proximity trigger
    @Published public var nearbyItem: ProductItem?
    @Published public var isNearCheckout: Bool = false
    
    public var currentLevelConfig: LevelConfig {
        LevelConfig.levels.first(where: { $0.id == currentLevelIndex }) ?? LevelConfig.levels[0]
    }
    
    public var totalSpent: Double {
        cartItems.reduce(0) { $0 + $1.price }
    }
    
    public var isListCompleted: Bool {
        !shoppingList.isEmpty && shoppingList.allSatisfy { $0.isCompleted }
    }
    
    private init() {
        prepareLevel(index: 1)
    }
    
    public func prepareLevel(index: Int) {
        currentLevelIndex = index
        let config = LevelConfig.levels.first(where: { $0.id == index }) ?? LevelConfig.levels[0]
        
        self.initialCredit = config.initialCredit
        self.remainingCredit = config.initialCredit
        self.timeRemaining = config.timeLimit
        self.cartItems.removeAll()
        self.recentBonuses.removeAll()
        self.phase = .ready
        self.cartController.reset(to: CGPoint(x: 160, y: 160))
        
        // Generate diverse shopping targets
        generateShoppingList(count: config.requiredItemCount)
        
        copilot.update(
            cartPosition: cartController.position,
            shoppingList: shoppingList,
            remainingCredit: remainingCredit,
            initialCredit: initialCredit,
            timeRemaining: timeRemaining,
            shelves: shelves,
            cartItems: cartItems
        )
        self.copilotAdvice = copilot.latestAdvice
    }
    
    private func generateShoppingList(count: Int) {
        var targets: [ShoppingTarget] = []
        let availableCategories = ProductCategory.allCases.shuffled()
        
        for i in 0..<count {
            let cat = availableCategories[i % availableCategories.count]
            let itemsInCat = StoreCatalog.allCatalogItems.filter { $0.category == cat }
            if let chosen = itemsInCat.randomElement() {
                if !targets.contains(where: { $0.targetBaseName == chosen.baseName }) {
                    targets.append(ShoppingTarget(category: cat, targetBaseName: chosen.baseName, emoji: chosen.emoji))
                } else if let alternate = itemsInCat.first(where: { it in !targets.contains(where: { $0.targetBaseName == it.baseName }) }) {
                    targets.append(ShoppingTarget(category: cat, targetBaseName: alternate.baseName, emoji: alternate.emoji))
                }
            }
        }
        self.shoppingList = targets
    }
    
    public func startGame() {
        self.phase = .playing
        AudioSynthesizer.shared.playCopilotBeep()
    }
    
    public func togglePause() {
        if phase == .playing {
            phase = .paused
        } else if phase == .paused {
            phase = .playing
        }
    }
    
    public func tick(deltaTime: TimeInterval) {
        guard phase == .playing else { return }
        
        timeRemaining -= deltaTime
        if timeRemaining <= 0 {
            timeRemaining = 0
            AudioSynthesizer.shared.playFailBuzzer()
            phase = .gameOver(reason: "Christmas Eve Closing Bell! The department store doors locked before you checked out.")
            return
        }
        
        updateProximity()
        
        copilot.update(
            cartPosition: cartController.position,
            shoppingList: shoppingList,
            remainingCredit: remainingCredit,
            initialCredit: initialCredit,
            timeRemaining: timeRemaining,
            shelves: shelves,
            cartItems: cartItems
        )
        self.copilotAdvice = copilot.latestAdvice
    }
    
    private func updateProximity() {
        let cartPos = cartController.position
        
        var nearAnyCounter = false
        for counter in checkouts {
            let counterCenter = CGPoint(x: counter.rect.midX, y: counter.rect.midY)
            if hypot(cartPos.x - counterCenter.x, cartPos.y - counterCenter.y) < 110.0 {
                nearAnyCounter = true
                break
            }
        }
        self.isNearCheckout = nearAnyCounter
        
        var foundItem: ProductItem? = nil
        for shelf in shelves {
            let shelfCenter = CGPoint(x: shelf.rect.midX, y: shelf.rect.midY)
            if hypot(cartPos.x - shelfCenter.x, cartPos.y - shelfCenter.y) < 115.0 {
                if let target = shoppingList.first(where: { !$0.isCompleted && $0.category == shelf.category }) {
                    foundItem = shelf.availableItems.first(where: { $0.baseName == target.targetBaseName })
                }
                if foundItem == nil {
                    foundItem = shelf.availableItems.first
                }
                break
            }
        }
        self.nearbyItem = foundItem
    }
    
    public func performAction() {
        guard phase == .playing else { return }
        
        if isNearCheckout {
            attemptCheckout()
            return
        }
        
        if let item = nearbyItem {
            collectItem(item)
        }
    }
    
    public func collectItem(_ item: ProductItem) {
        if remainingCredit < item.price {
            AudioSynthesizer.shared.playWarning()
            copilotAdvice = CopilotAdvice(
                timestamp: Date(),
                headline: "Not Enough Credit!",
                message: "Cannot afford \(item.fullName) ($\(String(format: "%.2f", item.price))). Only $\(String(format: "%.2f", remainingCredit)) credit left!",
                targetAisle: item.category.aisleNumber,
                recommendedTier: .budget,
                urgency: .alert
            )
            return
        }
        
        if let index = shoppingList.firstIndex(where: { !$0.isCompleted && $0.targetBaseName == item.baseName }) {
            shoppingList[index].acquiredProduct = item
            cartItems.append(item)
            remainingCredit = max(0, (remainingCredit - item.price * 100).rounded() / 100)
            score += item.tier.scoreMultiplier
            
            AudioSynthesizer.shared.playPickup()
            checkForHolidaySynergies(justAdded: item)
        } else {
            cartItems.append(item)
            remainingCredit = max(0, (remainingCredit - item.price * 100).rounded() / 100)
            score += 60
            AudioSynthesizer.shared.playPickup()
        }
    }
    
    private func checkForHolidaySynergies(justAdded: ProductItem) {
        let currentCartNames = Set(cartItems.map { $0.baseName })
        
        if currentCartNames.contains("Creamy Spiced Eggnog") && currentCartNames.contains("Glazed Gingerbread Man") {
            let bonusTag = "Yuletide Cheer Combo (+450 pts)"
            if !recentBonuses.contains(bonusTag) {
                recentBonuses.append(bonusTag)
                score += 450
                copilotAdvice = CopilotAdvice(
                    timestamp: Date(),
                    headline: "🎄 Holiday Synergy Unlocked!",
                    message: "Eggnog + Gingerbread Man combo: +450 Points!",
                    targetAisle: nil,
                    recommendedTier: nil,
                    urgency: .suggestion
                )
            }
        }
        
        if currentCartNames.contains("Walkman Portable Cassette") && currentCartNames.contains("Polaroid 600 Camera") {
            let bonusTag = "Radical 1984 Tech Duo (+550 pts)"
            if !recentBonuses.contains(bonusTag) {
                recentBonuses.append(bonusTag)
                score += 550
            }
        }
        
        if currentCartNames.contains("Carved Wooden Nutcracker") && currentCartNames.contains("Cabbage Patch Doll") {
            let bonusTag = "Christmas Morning Joy (+500 pts)"
            if !recentBonuses.contains(bonusTag) {
                recentBonuses.append(bonusTag)
                score += 500
            }
        }
    }
    
    public func attemptCheckout() {
        if !isListCompleted {
            AudioSynthesizer.shared.playWarning()
            let missing = shoppingList.filter { !$0.isCompleted }.map { $0.targetBaseName }.joined(separator: ", ")
            copilotAdvice = CopilotAdvice(
                timestamp: Date(),
                headline: "Presents Missing on List!",
                message: "Gift wrapper says you still need: [\(missing)] before paying!",
                targetAisle: nil,
                recommendedTier: nil,
                urgency: .alert
            )
            return
        }
        
        if totalSpent > initialCredit {
            AudioSynthesizer.shared.playFailBuzzer()
            phase = .gameOver(reason: "Exceeded Holiday Credit! You spent $\(String(format: "%.2f", totalSpent)) of your $\(String(format: "%.2f", initialCredit)) credit limit.")
            return
        }
        
        // Checkout SUCCESS
        AudioSynthesizer.shared.playCashRegister()
        AudioSynthesizer.shared.playWinFanfare()
        
        let timeBonus = Int(timeRemaining) * 30
        let budgetEfficiencyBonus = Int((1.0 - (remainingCredit / initialCredit)) * 600)
        let levelClearBonus = currentLevelIndex * 1200
        let roundScore = timeBonus + budgetEfficiencyBonus + levelClearBonus
        score += roundScore
        if score > highScores { highScores = score }
        
        recentBonuses.append("Time Remaining Bonus: +\(timeBonus) pts")
        recentBonuses.append("5th Ave Budget Efficiency: +\(budgetEfficiencyBonus) pts")
        recentBonuses.append("Holiday Level Cleared: +\(levelClearBonus) pts")
        
        if currentLevelIndex >= 3 {
            phase = .gameWon
        } else {
            phase = .levelCompleted
        }
    }
    
    public func nextLevel() {
        if currentLevelIndex < 3 {
            prepareLevel(index: currentLevelIndex + 1)
            startGame()
        }
    }
    
    public func restartLevel() {
        prepareLevel(index: currentLevelIndex)
        startGame()
    }
    
    public func startNewGame() {
        score = 0
        prepareLevel(index: 1)
        startGame()
    }
}
