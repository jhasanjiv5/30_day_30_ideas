import SwiftUI
import AppKit

@main
struct FastShopperApp: App {
    @ObservedObject private var state = GameState.shared
    
    init() {
        // Ensure regular macOS app activation for keyboard focus
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    var body: some Scene {
        WindowGroup("FastShopper") {
            GameContainerView()
                .frame(minWidth: 1024, idealWidth: 1280, minHeight: 640, idealHeight: 780)
                .background(Color.black)
                .onAppear {
                    DispatchQueue.main.async {
                        NSApplication.shared.activate(ignoringOtherApps: true)
                        NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
                    }
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Game") {
                    state.startNewGame()
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("Restart Current Level") {
                    state.restartLevel()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
            
            CommandMenu("Game") {
                Button(state.phase == .paused ? "Resume Game" : "Pause Game") {
                    state.togglePause()
                }
                .keyboardShortcut("p", modifiers: [])
                
                Button("Consult Miracle-84 AI") {
                    InputManager.shared.isConsultTriggered = true
                }
                .keyboardShortcut("r", modifiers: [])
                
                Divider()
                
                Button(AudioSynthesizer.shared.isMuted ? "Unmute Audio" : "Mute Audio") {
                    AudioSynthesizer.shared.isMuted.toggle()
                }
                .keyboardShortcut("m", modifiers: [])
            }
        }
    }
}
