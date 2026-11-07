import Foundation
import CoreGraphics

public final class CartController {
    public var position: CGPoint = CGPoint(x: 160, y: 160)
    public var velocity: CGPoint = .zero
    public var rotation: CGFloat = 0.0 // radians
    
    public var currentSpeed: CGFloat {
        hypot(velocity.x, velocity.y)
    }
    
    private let maxSpeed: CGFloat = 360.0
    private let accelerationRate: CGFloat = 750.0
    private let dragFactor: CGFloat = 0.91
    private let brakeFactor: CGFloat = 0.80
    private let cartRadius: CGFloat = 22.0
    
    public init(startPosition: CGPoint = CGPoint(x: 160, y: 160)) {
        self.position = startPosition
    }
    
    public func reset(to startPosition: CGPoint = CGPoint(x: 160, y: 160)) {
        self.position = startPosition
        self.velocity = .zero
        self.rotation = 0.0
    }
    
    public func update(deltaTime: TimeInterval, inputVector: CGPoint, isBraking: Bool, shelves: [ShelfSection], checkouts: [CheckoutCounter]) {
        let dt = CGFloat(deltaTime)
        
        // 1. Acceleration
        if hypot(inputVector.x, inputVector.y) > 0.05 {
            velocity.x += inputVector.x * accelerationRate * dt
            velocity.y += inputVector.y * accelerationRate * dt
            
            // Smoothly rotate toward movement direction
            let targetAngle = atan2(inputVector.y, inputVector.x)
            var angleDiff = targetAngle - rotation
            while angleDiff > .pi { angleDiff -= 2 * .pi }
            while angleDiff < -.pi { angleDiff += 2 * .pi }
            rotation += angleDiff * min(dt * 12.0, 1.0)
        }
        
        // 2. Drag & Braking
        let drag = isBraking ? brakeFactor : dragFactor
        velocity.x *= pow(drag, dt * 60.0)
        velocity.y *= pow(drag, dt * 60.0)
        
        // 3. Clamp speed
        let speed = hypot(velocity.x, velocity.y)
        if speed > maxSpeed {
            let scale = maxSpeed / speed
            velocity.x *= scale
            velocity.y *= scale
        } else if speed < 2.0 {
            velocity = .zero
        }
        
        // 4. Proposed new position
        var newX = position.x + velocity.x * dt
        var newY = position.y + velocity.y * dt
        
        // 5. Store perimeter bounds
        let minX = cartRadius + 20
        let maxX = StoreMap.worldWidth - cartRadius - 20
        let minY = cartRadius + 20
        let maxY = StoreMap.worldHeight - cartRadius - 20
        
        if newX < minX { newX = minX; velocity.x *= -0.3; AudioSynthesizer.shared.playCartBump() }
        if newX > maxX { newX = maxX; velocity.x *= -0.3; AudioSynthesizer.shared.playCartBump() }
        if newY < minY { newY = minY; velocity.y *= -0.3; AudioSynthesizer.shared.playCartBump() }
        if newY > maxY { newY = maxY; velocity.y *= -0.3; AudioSynthesizer.shared.playCartBump() }
        
        // 6. Shelf Obstacle Collisions (AABB with circle)
        for shelf in shelves {
            let expandedRect = shelf.rect.insetBy(dx: -cartRadius, dy: -cartRadius)
            if expandedRect.contains(CGPoint(x: newX, y: newY)) {
                // Find closest edge to push out
                let leftDist = abs(newX - expandedRect.minX)
                let rightDist = abs(newX - expandedRect.maxX)
                let bottomDist = abs(newY - expandedRect.minY)
                let topDist = abs(newY - expandedRect.maxY)
                let minDist = min(leftDist, rightDist, bottomDist, topDist)
                
                if minDist == leftDist {
                    newX = expandedRect.minX
                    velocity.x = -abs(velocity.x) * 0.4
                } else if minDist == rightDist {
                    newX = expandedRect.maxX
                    velocity.x = abs(velocity.x) * 0.4
                } else if minDist == bottomDist {
                    newY = expandedRect.minY
                    velocity.y = -abs(velocity.y) * 0.4
                } else {
                    newY = expandedRect.maxY
                    velocity.y = abs(velocity.y) * 0.4
                }
                AudioSynthesizer.shared.playCartBump()
            }
        }
        
        // 7. Checkout Counters (solid front registers)
        for counter in checkouts {
            let solidRect = counter.rect.insetBy(dx: -cartRadius, dy: -cartRadius)
            if solidRect.contains(CGPoint(x: newX, y: newY)) {
                if newY < counter.rect.midY {
                    newY = solidRect.minY
                    velocity.y = -abs(velocity.y) * 0.4
                } else {
                    newY = solidRect.maxY
                    velocity.y = abs(velocity.y) * 0.4
                }
                AudioSynthesizer.shared.playCartBump()
            }
        }
        
        self.position = CGPoint(x: newX, y: newY)
    }
}
