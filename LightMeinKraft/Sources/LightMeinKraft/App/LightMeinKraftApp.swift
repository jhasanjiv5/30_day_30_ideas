import SwiftUI
import AppKit

@main
struct LightMeinKraftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var gameState = GameState.shared

    var body: some Scene {
        WindowGroup {
            GameContainerView()
                .frame(width: 1280, height: 720)
                .background(WindowAccessor())
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            // File Menu
            CommandGroup(replacing: .newItem) {
                Button("New Game (Level 1)") {
                    gameState.startNewGame(levelNumber: 1)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Restart Level") {
                    gameState.startNewGame(levelNumber: gameState.currentLevel.levelNumber)
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Main Menu") {
                    gameState.currentScreen = .mainMenu
                }
            }

            // Game Menu
            CommandMenu("Game") {
                Button(gameState.currentScreen == .paused ? "Resume Game" : "Pause Game") {
                    if gameState.currentScreen == .playing {
                        gameState.currentScreen = .paused
                    } else if gameState.currentScreen == .paused {
                        gameState.currentScreen = .playing
                    }
                }
                .keyboardShortcut("p", modifiers: .command)

                Button("Crafting & Inventory") {
                    if gameState.currentScreen == .playing {
                        gameState.currentScreen = .inventory
                    } else if gameState.currentScreen == .inventory {
                        gameState.currentScreen = .playing
                    }
                }
                .keyboardShortcut("i", modifiers: .command)

                Divider()

                Button(gameState.isMuted ? "Unmute Audio" : "Mute Audio") {
                    gameState.isMuted.toggle()
                    SoundManager.shared.setMuted(gameState.isMuted)
                }
                .keyboardShortcut("m", modifiers: .command)

                Button("Toggle Fullscreen") {
                    if let window = NSApplication.shared.windows.first {
                        window.toggleFullScreen(nil)
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
            }

            // Levels Menu
            CommandMenu("Levels") {
                Button("Level 1: Snowy Taiga & Star Portal") {
                    gameState.startNewGame(levelNumber: 1)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Level 2: Santa's Frozen Workshop") {
                    gameState.startNewGame(levelNumber: 2)
                }
                .keyboardShortcut("2", modifiers: .command)
            }
        }
    }
}

// Window Accessor Helper
private struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.title = "LightMeinKraft - Christmas Edition"
                window.setContentSize(NSSize(width: 1280, height: 720))
                window.minSize = NSSize(width: 960, height: 540)
                window.contentAspectRatio = NSSize(width: 16, height: 9)
                window.center()
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
