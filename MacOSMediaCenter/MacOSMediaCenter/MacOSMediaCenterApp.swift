///
///  MacOSMediaCenterApp.swift
///  MacOSMediaCenter for macOS
///
///  Created for MacBook users seeking a lean-back, cinematic tvOS entertainment hub.
///

import SwiftUI
import AppKit

@main
struct MacOSMediaCenterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1080, minHeight: 680)
                .background(Color.black)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Dashboard") {
                Button("Search Vibes (Spotlight)") {
                    NotificationCenter.default.post(name: .openVibeSearch, object: nil)
                }
                .keyboardShortcut("k", modifiers: [.command])
                
                Button("Return to Home") {
                    NotificationCenter.default.post(name: .returnToDashboard, object: nil)
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first {
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isOpaque = false
            window.backgroundColor = .clear
            window.collectionBehavior = [.fullScreenPrimary]
            window.makeKeyAndOrderFront(nil)
        }
    }
}

extension Notification.Name {
    static let openVibeSearch = Notification.Name("openVibeSearch")
    static let returnToDashboard = Notification.Name("returnToDashboard")
}
