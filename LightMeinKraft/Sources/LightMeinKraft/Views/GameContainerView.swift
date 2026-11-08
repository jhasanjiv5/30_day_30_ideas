import SwiftUI

public struct GameContainerView: View {
    @ObservedObject var gameState: GameState = GameState.shared

    public init() {}

    public var body: some View {
        ZStack {
            if gameState.currentScreen == .mainMenu {
                MainMenuView(gameState: gameState)
            } else {
                // 3D SceneKit Voxel Engine
                GameSceneView(gameState: gameState)
                    .ignoresSafeArea()

                // HUD Overlay (Crosshair, Hearts, Hotbar, Quests, Boss HP)
                if gameState.currentScreen == .playing {
                    HUDOverlayView(gameState: gameState)
                }

                // Inventory & 2x2 Crafting Screen
                if gameState.currentScreen == .inventory {
                    InventoryView(gameState: gameState)
                }

                // Pause Menu
                if gameState.currentScreen == .paused {
                    PauseMenuView(gameState: gameState)
                }

                // Game Over (Loss)
                if gameState.currentScreen == .gameOver {
                    GameOverView(gameState: gameState, isVictory: false)
                }

                // Victory (Win)
                if gameState.currentScreen == .victory {
                    GameOverView(gameState: gameState, isVictory: true)
                }
            }
        }
        .frame(minWidth: 960, minHeight: 600)
    }
}
