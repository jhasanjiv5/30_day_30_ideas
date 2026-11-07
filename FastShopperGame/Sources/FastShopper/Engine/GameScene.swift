import Foundation
import SpriteKit
import SwiftUI

public class GameScene: SKScene {
    private var lastUpdateTime: TimeInterval = 0
    private var blinkTimer: TimeInterval = 0
    
    // Nodes
    private var worldNode = SKNode()
    private var playerCartNode = SKNode()
    private var cartBasketNode = SKShapeNode()
    private var guidanceArrowNode = SKNode()
    private var shelfNodes: [SKShapeNode] = []
    private var fairyLightNodes: [SKShapeNode] = []
    private var snowflakeNodes: [SKNode] = []
    private var itemNodesInCart: [SKLabelNode] = []
    
    public override func didMove(to view: SKView) {
        // Deep 1980s NYC department store ambiance
        self.backgroundColor = SKColor(red: 0.08, green: 0.10, blue: 0.12, alpha: 1.0)
        self.anchorPoint = CGPoint(x: 0, y: 0)
        
        addChild(worldNode)
        
        build1984HolidayDepartmentStore()
        buildSnowfall()
        buildPlayerCart()
        buildGuidanceArrow()
    }
    
    private func build1984HolidayDepartmentStore() {
        // 1. Festive 1984 Terrazzo & Burgundy Floor Tiles
        let tileSize: CGFloat = 80.0
        let cols = Int(StoreMap.worldWidth / tileSize) + 1
        let rows = Int(StoreMap.worldHeight / tileSize) + 1
        
        for r in 0..<rows {
            for c in 0..<cols {
                let rect = CGRect(x: CGFloat(c) * tileSize, y: CGFloat(r) * tileSize, width: tileSize, height: tileSize)
                let tile = SKShapeNode(rect: rect)
                let isAlt = (r + c) % 2 == 0
                // Deep emerald green and rich holiday wine burgundy
                tile.fillColor = isAlt ? SKColor(red: 0.10, green: 0.18, blue: 0.13, alpha: 1.0)
                                       : SKColor(red: 0.16, green: 0.08, blue: 0.10, alpha: 1.0)
                // Vintage brass inlay lines
                tile.strokeColor = SKColor(red: 0.55, green: 0.45, blue: 0.25, alpha: 0.35)
                tile.lineWidth = 1.0
                tile.zPosition = -10
                worldNode.addChild(tile)
            }
        }
        
        // 2. Outer Store Walls with Brass Border
        let bounds = SKShapeNode(rect: CGRect(x: 10, y: 10, width: StoreMap.worldWidth - 20, height: StoreMap.worldHeight - 20), cornerRadius: 8)
        bounds.strokeColor = SKColor(red: 0.85, green: 0.72, blue: 0.35, alpha: 0.9)
        bounds.lineWidth = 5
        bounds.fillColor = .clear
        bounds.zPosition = -5
        worldNode.addChild(bounds)
        
        // 3. Department Shelves with Pine Garlands & Fairy Lights
        for shelf in StoreMap.makeShelves() {
            // Walnut wood base
            let shelfNode = SKShapeNode(rect: shelf.rect, cornerRadius: 8)
            shelfNode.fillColor = SKColor(red: 0.18, green: 0.13, blue: 0.12, alpha: 1.0)
            shelfNode.strokeColor = SKColor(hex: shelf.colorHex)
            shelfNode.lineWidth = 2.5
            shelfNode.zPosition = 5
            
            // Warm shadow
            let shadow = SKShapeNode(rect: shelf.rect.offsetBy(dx: 4, dy: -4), cornerRadius: 8)
            shadow.fillColor = SKColor.black.withAlphaComponent(0.45)
            shadow.strokeColor = .clear
            shadow.zPosition = 4
            worldNode.addChild(shadow)
            
            // Pine Garland overlay along the shelf border
            let garland = SKShapeNode(rect: shelf.rect.insetBy(dx: -3, dy: -3), cornerRadius: 9)
            garland.fillColor = .clear
            garland.strokeColor = SKColor(red: 0.12, green: 0.42, blue: 0.18, alpha: 0.6)
            garland.lineWidth = 3.5
            garland.zPosition = 6
            worldNode.addChild(garland)
            
            // Blinking Christmas Fairy Lights along shelf edges
            let lightPoints: [CGPoint] = [
                CGPoint(x: shelf.rect.minX + 8, y: shelf.rect.maxY - 10),
                CGPoint(x: shelf.rect.midX, y: shelf.rect.maxY - 10),
                CGPoint(x: shelf.rect.maxX - 8, y: shelf.rect.maxY - 10),
                CGPoint(x: shelf.rect.minX + 8, y: shelf.rect.minY + 10),
                CGPoint(x: shelf.rect.midX, y: shelf.rect.minY + 10),
                CGPoint(x: shelf.rect.maxX - 8, y: shelf.rect.minY + 10)
            ]
            let lightColors: [SKColor] = [
                SKColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 0.9), // Ruby Red
                SKColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 0.9), // Emerald Green
                SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.9) // Golden Glow
            ]
            
            for (idx, pt) in lightPoints.enumerated() {
                let lightBulb = SKShapeNode(circleOfRadius: 3.5)
                lightBulb.position = pt
                lightBulb.fillColor = lightColors[idx % lightColors.count]
                lightBulb.strokeColor = SKColor.white
                lightBulb.lineWidth = 0.5
                lightBulb.zPosition = 8
                worldNode.addChild(lightBulb)
                fairyLightNodes.append(lightBulb)
            }
            
            // Vintage Brass Label Plate
            let labelPlate = SKShapeNode(rectOf: CGSize(width: shelf.rect.width - 8, height: 26), cornerRadius: 4)
            labelPlate.fillColor = SKColor(red: 0.25, green: 0.18, blue: 0.08, alpha: 0.95)
            labelPlate.strokeColor = SKColor(red: 0.85, green: 0.70, blue: 0.30, alpha: 0.8)
            labelPlate.lineWidth = 1.0
            labelPlate.position = CGPoint(x: shelf.rect.midX, y: shelf.rect.midY)
            labelPlate.zPosition = 6
            worldNode.addChild(labelPlate)
            
            let label = SKLabelNode(fontNamed: "Georgia-Bold")
            label.text = shelf.label
            label.fontSize = 10.5
            label.fontColor = SKColor(red: 1.0, green: 0.95, blue: 0.8, alpha: 1.0)
            label.position = CGPoint(x: shelf.rect.midX, y: shelf.rect.midY)
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.zPosition = 7
            worldNode.addChild(label)
            
            // Available 1984 Gift Emojis
            let items = shelf.availableItems
            let spacing = shelf.rect.height / CGFloat(items.count + 1)
            for (idx, item) in items.enumerated() {
                let emojiNode = SKLabelNode(text: item.emoji)
                emojiNode.fontSize = 18
                emojiNode.position = CGPoint(x: shelf.rect.midX, y: shelf.rect.minY + CGFloat(idx + 1) * spacing)
                emojiNode.verticalAlignmentMode = .center
                emojiNode.zPosition = 8
                worldNode.addChild(emojiNode)
            }
            
            worldNode.addChild(shelfNode)
            shelfNodes.append(shelfNode)
        }
        
        // 4. Gift Wrap & Express Cashier Counters
        for counter in StoreMap.makeCheckouts() {
            let counterNode = SKShapeNode(rect: counter.rect, cornerRadius: 6)
            counterNode.fillColor = SKColor(red: 0.32, green: 0.10, blue: 0.12, alpha: 1.0) // Burgundy velvet
            counterNode.strokeColor = SKColor(red: 0.95, green: 0.80, blue: 0.35, alpha: 0.95) // Gold
            counterNode.lineWidth = 2.5
            counterNode.zPosition = 5
            worldNode.addChild(counterNode)
            
            let regLabel = SKLabelNode(fontNamed: "Georgia-Bold")
            regLabel.text = counter.name
            regLabel.fontSize = 11.5
            regLabel.fontColor = SKColor(red: 1.0, green: 0.95, blue: 0.85, alpha: 1.0)
            regLabel.position = CGPoint(x: counter.rect.midX, y: counter.rect.midY)
            regLabel.verticalAlignmentMode = .center
            regLabel.zPosition = 6
            worldNode.addChild(regLabel)
        }
        
        // 5. Store Entrance Header
        let marquee = SKLabelNode(fontNamed: "Georgia-Bold")
        marquee.text = "★ MACY'S HERALD SQUARE • CHRISTMAS EVE 1984 ★"
        marquee.fontSize = 14
        marquee.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.40, alpha: 1.0)
        marquee.position = CGPoint(x: 320, y: 65)
        marquee.zPosition = 2
        worldNode.addChild(marquee)
    }
    
    private func buildSnowfall() {
        // Falling snowflakes drifting across the department store windows
        for _ in 0..<50 {
            let flake = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.5...3.0))
            flake.fillColor = SKColor(white: 1.0, alpha: CGFloat.random(in: 0.4...0.85))
            flake.strokeColor = .clear
            flake.position = CGPoint(
                x: CGFloat.random(in: 0...StoreMap.worldWidth),
                y: CGFloat.random(in: 0...StoreMap.worldHeight)
            )
            flake.zPosition = 35
            worldNode.addChild(flake)
            snowflakeNodes.append(flake)
        }
    }
    
    private func buildPlayerCart() {
        playerCartNode.position = CGPoint(x: 160, y: 160)
        playerCartNode.zPosition = 20
        
        // Shopper in 1984 NYC Winter Wool Coat & Beanie
        let coatNode = SKShapeNode(rectOf: CGSize(width: 16, height: 26), cornerRadius: 5)
        coatNode.fillColor = SKColor(red: 0.55, green: 0.15, blue: 0.18, alpha: 1.0) // Vintage Red Wool Coat
        coatNode.strokeColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.8)
        coatNode.lineWidth = 1.0
        coatNode.position = CGPoint(x: -14, y: 0)
        playerCartNode.addChild(coatNode)
        
        let beanieNode = SKShapeNode(circleOfRadius: 13)
        beanieNode.fillColor = SKColor(red: 0.15, green: 0.35, blue: 0.20, alpha: 1.0) // Forest Green Beanie
        beanieNode.strokeColor = SKColor(red: 0.85, green: 0.75, blue: 0.4, alpha: 1.0)
        beanieNode.lineWidth = 1.5
        beanieNode.position = CGPoint(x: -16, y: 0)
        playerCartNode.addChild(beanieNode)
        
        // Classic Chrome Shopping Cart Basket
        let basketRect = CGRect(x: 0, y: -16, width: 38, height: 32)
        cartBasketNode = SKShapeNode(rect: basketRect, cornerRadius: 4)
        cartBasketNode.fillColor = SKColor(red: 0.85, green: 0.88, blue: 0.95, alpha: 0.35)
        cartBasketNode.strokeColor = SKColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 1.0)
        cartBasketNode.lineWidth = 2.0
        playerCartNode.addChild(cartBasketNode)
        
        // Red Velvet Holiday Bow on Front of Cart
        let redBow = SKLabelNode(text: "🎀")
        redBow.fontSize = 18
        redBow.position = CGPoint(x: 36, y: 0)
        redBow.verticalAlignmentMode = .center
        redBow.horizontalAlignmentMode = .center
        redBow.zPosition = 26
        playerCartNode.addChild(redBow)
        
        // Handle bar in Brass/Gold
        let handleBar = SKShapeNode(rectOf: CGSize(width: 4, height: 34), cornerRadius: 2)
        handleBar.fillColor = SKColor(red: 0.9, green: 0.75, blue: 0.3, alpha: 1.0)
        handleBar.strokeColor = .clear
        handleBar.position = CGPoint(x: 0, y: 0)
        playerCartNode.addChild(handleBar)
        
        // Cart wheels (4 corners)
        let wheelOffsets: [CGPoint] = [
            CGPoint(x: 6, y: 16), CGPoint(x: 30, y: 16),
            CGPoint(x: 6, y: -16), CGPoint(x: 30, y: -16)
        ]
        for offset in wheelOffsets {
            let wheel = SKShapeNode(rectOf: CGSize(width: 6, height: 4), cornerRadius: 1)
            wheel.fillColor = SKColor.black
            wheel.strokeColor = .clear
            wheel.position = offset
            playerCartNode.addChild(wheel)
        }
        
        worldNode.addChild(playerCartNode)
    }
    
    private func buildGuidanceArrow() {
        let arrow = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 28, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 9))
        path.addLine(to: CGPoint(x: 6, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -9))
        path.closeSubpath()
        arrow.path = path
        arrow.fillColor = SKColor(red: 1.0, green: 0.85, blue: 0.30, alpha: 0.9) // Holiday Gold
        arrow.strokeColor = SKColor.white
        arrow.lineWidth = 1.2
        
        guidanceArrowNode.addChild(arrow)
        guidanceArrowNode.zPosition = 15
        worldNode.addChild(guidanceArrowNode)
    }
    
    public override func keyDown(with event: NSEvent) {
        InputManager.shared.handleKeyDown(event: event)
    }
    
    public override func keyUp(with event: NSEvent) {
        InputManager.shared.handleKeyUp(event: event)
    }
    
    public override func mouseDown(with event: NSEvent) {
        if let view = self.view {
            view.window?.makeFirstResponder(view)
        }
        let state = GameState.shared
        if state.phase == .ready {
            state.startGame()
        } else if state.phase == .playing {
            state.performAction()
        }
    }
    
    public override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            return
        }
        let dt = min(currentTime - lastUpdateTime, 0.1)
        lastUpdateTime = currentTime
        
        let state = GameState.shared
        guard state.phase == .playing else { return }
        
        // Update Christmas Fairy Lights Twinkle
        blinkTimer += dt
        if blinkTimer > 0.4 {
            blinkTimer = 0
            for light in fairyLightNodes {
                light.alpha = CGFloat.random(in: 0.3...1.0)
            }
        }
        
        // Animate Gentle Snowfall
        for flake in snowflakeNodes {
            flake.position.y -= CGFloat(dt * 35.0)
            flake.position.x += CGFloat(sin(currentTime * 2.0 + Double(flake.position.y)) * 0.5)
            if flake.position.y < 0 {
                flake.position.y = StoreMap.worldHeight
                flake.position.x = CGFloat.random(in: 0...StoreMap.worldWidth)
            }
        }
        
        // Handle input consumption
        let input = InputManager.shared
        if input.consumeAction() {
            state.performAction()
        }
        if input.consumeConsult() {
            AudioSynthesizer.shared.playCopilotBeep()
            state.copilotAdvice = CopilotAdvice(
                timestamp: Date(),
                headline: "Miracle-84 Live Advice",
                message: state.copilot.consultOnDemand(
                    cartPosition: state.cartController.position,
                    shoppingList: state.shoppingList,
                    remainingCredit: state.remainingCredit,
                    timeRemaining: state.timeRemaining
                ),
                targetAisle: nil,
                recommendedTier: nil,
                urgency: .suggestion
            )
        }
        if input.consumePause() {
            state.togglePause()
        }
        if input.consumeMute() {
            AudioSynthesizer.shared.isMuted.toggle()
        }
        
        // Cart physics update
        state.cartController.update(
            deltaTime: dt,
            inputVector: input.moveVector,
            isBraking: false,
            shelves: state.shelves,
            checkouts: state.checkouts
        )
        
        // Tick game logic
        state.tick(deltaTime: dt)
        
        // Update visual nodes
        playerCartNode.position = state.cartController.position
        playerCartNode.zRotation = state.cartController.rotation
        
        // Update visual cart contents
        updateCartVisuals(cartItems: state.cartItems)
        
        // Update AI Guidance Arrow
        updateGuidanceWaypoint(cartPos: state.cartController.position, list: state.shoppingList)
        
        // Camera smooth tracking
        centerCameraOn(point: state.cartController.position)
    }
    
    private func updateCartVisuals(cartItems: [ProductItem]) {
        let maxVisible = 6
        let itemsToShow = Array(cartItems.suffix(maxVisible))
        
        if itemsToShow.count != itemNodesInCart.count {
            itemNodesInCart.forEach { $0.removeFromParent() }
            itemNodesInCart.removeAll()
            
            for (idx, item) in itemsToShow.enumerated() {
                let lbl = SKLabelNode(text: item.emoji)
                lbl.fontSize = 11
                let col = idx % 2
                let row = idx / 2
                lbl.position = CGPoint(x: 10 + CGFloat(row) * 10, y: -8 + CGFloat(col) * 12)
                lbl.zPosition = 25
                playerCartNode.addChild(lbl)
                itemNodesInCart.append(lbl)
            }
        }
    }
    
    private func updateGuidanceWaypoint(cartPos: CGPoint, list: [ShoppingTarget]) {
        guard let nextTarget = list.first(where: { !$0.isCompleted }) else {
            // Point to nearest checkout
            if let counter = StoreMap.makeCheckouts().first {
                pointGuidanceArrow(from: cartPos, to: CGPoint(x: counter.rect.midX, y: counter.rect.midY))
            }
            return
        }
        
        // Find shelf for target
        if let shelf = StoreMap.makeShelves().first(where: { $0.category == nextTarget.category }) {
            pointGuidanceArrow(from: cartPos, to: CGPoint(x: shelf.rect.midX, y: shelf.rect.midY))
        }
    }
    
    private func pointGuidanceArrow(from: CGPoint, to: CGPoint) {
        guidanceArrowNode.position = CGPoint(x: from.x + 35 * cos(atan2(to.y - from.y, to.x - from.x)),
                                             y: from.y + 35 * sin(atan2(to.y - from.y, to.x - from.x)))
        guidanceArrowNode.zRotation = atan2(to.y - from.y, to.x - from.x)
    }
    
    private func centerCameraOn(point: CGPoint) {
        guard let view = self.view else { return }
        let viewW = view.bounds.width
        let viewH = view.bounds.height
        
        let targetX = viewW / 2 - point.x
        let targetY = viewH / 2 - point.y
        
        let minX = viewW - StoreMap.worldWidth
        let minY = viewH - StoreMap.worldHeight
        
        let clampedX = min(0, max(minX, targetX))
        let clampedY = min(0, max(minY, targetY))
        
        worldNode.position = CGPoint(x: clampedX, y: clampedY)
    }
}

// Color hex helper
extension SKColor {
    convenience init(hex: String) {
        var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cString.hasPrefix("#") { cString.remove(at: cString.startIndex) }
        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)
        let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
