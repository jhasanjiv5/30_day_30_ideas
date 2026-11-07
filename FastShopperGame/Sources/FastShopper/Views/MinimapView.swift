import SwiftUI

public struct MinimapView: View {
    @ObservedObject var state: GameState
    
    private let mapWidth: CGFloat = 160
    private let mapHeight: CGFloat = 105
    
    private var scaleX: CGFloat { mapWidth / StoreMap.worldWidth }
    private var scaleY: CGFloat { mapHeight / StoreMap.worldHeight }
    
    public var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("STORE RADAR")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            
            ZStack(alignment: .bottomLeading) {
                // Background floor
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.6))
                    .frame(width: mapWidth, height: mapHeight)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.2), lineWidth: 1))
                
                // Shelves
                ForEach(state.shelves) { shelf in
                    let x = shelf.rect.minX * scaleX
                    let y = shelf.rect.minY * scaleY
                    let w = shelf.rect.width * scaleX
                    let h = shelf.rect.height * scaleY
                    
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(hex: shelf.colorHex).opacity(0.6))
                        .frame(width: w, height: h)
                        .position(x: x + w / 2, y: mapHeight - (y + h / 2))
                }
                
                // Checkout counters
                ForEach(state.checkouts) { counter in
                    let x = counter.rect.minX * scaleX
                    let y = counter.rect.minY * scaleY
                    let w = counter.rect.width * scaleX
                    let h = counter.rect.height * scaleY
                    
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.green.opacity(0.7))
                        .frame(width: w, height: h)
                        .position(x: x + w / 2, y: mapHeight - (y + h / 2))
                }
                
                // Player cart dot
                let playerX = state.cartController.position.x * scaleX
                let playerY = state.cartController.position.y * scaleY
                
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 6, height: 6)
                    .shadow(color: .cyan, radius: 4)
                    .position(x: playerX, y: mapHeight - playerY)
            }
            .frame(width: mapWidth, height: mapHeight)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
}
