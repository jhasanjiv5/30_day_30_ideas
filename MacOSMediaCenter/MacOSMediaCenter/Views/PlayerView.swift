//
//  PlayerView.swift
//  MacOSMediaCenter
//

import SwiftUI

struct PlayerView: View {
    let channel: ChannelItem
    let destinationURL: URL?
    let namespace: Namespace.ID
    let onDismiss: () -> Void

    @State private var canGoBack: Bool = false
    @State private var showHUD: Bool = false
    @State private var hudTimer: Timer? = nil
    @StateObject private var playbackController = WebViewContainer.WebViewPlaybackController()

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Full-Bleed WKWebView
            WebViewContainer(
                url: destinationURL ?? channel.url,
                canGoBack: $canGoBack,
                playbackController: playbackController
            )
                .ignoresSafeArea()
                .matchedGeometryEffect(id: channel.id, in: namespace)

            // Auto-Hiding Frosted Glass HUD
            if showHUD {
                HStack(spacing: 16) {
                    // Back to Dashboard (Esc)
                    Button(action: dismissPlayer) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .bold))
                            Text("Dashboard")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Text(channel.name)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))

                    Spacer()
                }
                .padding(.top, 24)
                .padding(.horizontal, 28)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // Auto-show HUD on mouse movement, fade out after 3.0s
        .onContinuousHover { phase in
            switch phase {
            case .active:
                withAnimation(.easeInOut(duration: 0.2)) {
                    showHUD = true
                }
                resetHUDTimer()
            case .ended:
                withAnimation(.easeInOut(duration: 0.2)) {
                    showHUD = false
                }
            }
        }
        // Escape keyboard shortcut
        .background(
            Button("") {
                dismissPlayer()
            }
            .keyboardShortcut(.escape, modifiers: [])
            .opacity(0)
        )
        .onDisappear {
            playbackController.stopPlayback()
        }
    }

    private func dismissPlayer() {
        playbackController.stopPlayback()
        onDismiss()
    }

    private func resetHUDTimer() {
        hudTimer?.invalidate()
        hudTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.35)) {
                showHUD = false
            }
        }
    }
}
