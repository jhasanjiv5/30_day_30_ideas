import SwiftUI
import SpriteKit
import AppKit

public struct GameContainerView: View {
    @ObservedObject var state = GameState.shared
    @State private var scene: GameScene?
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // First-Responder Key Event Interceptor
            KeyResponderView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // SpriteKit Canvas
            if let scene = scene {
                SpriteView(scene: scene, options: [.shouldCullNonVisibleNodes])
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }
            
            // HUD Layer
            HUDView(state: state)
            
            // Copilot & Shopping List Sidebars
            CopilotHUDView(state: state)
            
            // Minimap Radar (Bottom-Right)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    MinimapView(state: state)
                        .padding(.trailing, 20)
                        .padding(.bottom, 60)
                }
            }
            
            // Modal Overlays (Start, Paused, Level Win, Game Over, Victory)
            OverlaysView(state: state)
        }
        .frame(minWidth: 1024, minHeight: 640)
        .onAppear {
            setupScene()
            setupInputMonitors()
        }
    }
    
    private func setupScene() {
        let sc = GameScene(size: CGSize(width: StoreMap.worldWidth, height: StoreMap.worldHeight))
        sc.scaleMode = .resizeFill
        self.scene = sc
    }
    
    private func setupInputMonitors() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            InputManager.shared.handleKeyDown(event: event)
            return event
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event in
            InputManager.shared.handleKeyUp(event: event)
            return event
        }
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                if GameState.shared.phase == .playing {
                    GameState.shared.phase = .paused
                }
            }
        }
    }
}
