import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first {
            configureWindow(window)
        }
    }

    public func applicationDidResignActive(_ notification: Notification) {
        // Auto-pause game when window loses focus
        Task { @MainActor in
            let gs = GameState.shared
            if gs.currentScreen == .playing {
                gs.currentScreen = .paused
            }
        }
    }

    public func applicationDidHide(_ notification: Notification) {
        Task { @MainActor in
            let gs = GameState.shared
            if gs.currentScreen == .playing {
                gs.currentScreen = .paused
            }
        }
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    private func configureWindow(_ window: NSWindow) {
        window.title = "LightMeinKraft - Christmas Edition"
        window.setContentSize(NSSize(width: 1280, height: 720))
        window.minSize = NSSize(width: 960, height: 540)
        window.contentAspectRatio = NSSize(width: 16, height: 9)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}
