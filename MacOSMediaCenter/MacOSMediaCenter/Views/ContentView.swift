//
//  ContentView.swift
//  MacOSMediaCenter
//

import SwiftUI

struct ContentView: View {
    @StateObject private var model = ChannelStore()
    @StateObject private var vibeEngine = CoreMLVibeEngine()
    @Namespace private var heroNamespace
    
    @State private var activeChannel: ChannelItem? = nil
    @State private var activeDestinationURL: URL?
    @State private var focusedChannel: ChannelItem? = nil
    @State private var isVibeSearchPresented: Bool = false
    
    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.03, blue: 0.05).ignoresSafeArea()
            
            if let active = activeChannel {
                // MARK: In-Window Theater Mode (WKWebView)
                PlayerView(
                    channel: active,
                    destinationURL: activeDestinationURL,
                    namespace: heroNamespace,
                    onDismiss: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                            activeChannel = nil
                            activeDestinationURL = nil
                        }
                    }
                )
                .transition(.identity)
            } else {
                // MARK: tvOS Dashboard Layout
                VStack(spacing: 0) {
                    // Top Shelf (45% viewport height)
                    TopShelfHeroView(
                        channel: focusedChannel ?? visibleChannels.first ?? ChannelItem.fallback,
                        onLaunch: { channel in
                            launchChannel(channel)
                        },
                        onSelectTitle: { channel, title in
                            launchChannel(channel, destinationURL: channel.searchURL(for: title))
                        },
                        onArtworkGenerated: { channel, sourceURL in
                            try model.saveHeroArtwork(for: channel, from: sourceURL)
                            focusedChannel = model.channels.first { $0.id == channel.id }
                        },
                        onKeepGeneratedArtwork: { channel, shouldKeep in
                            model.setKeepGeneratedHeroArtwork(shouldKeep, for: channel)
                            focusedChannel = model.channels.first { $0.id == channel.id }
                        },
                        cachedTitleArtwork: { channel, title in
                            model.cachedTitleArtwork(for: channel, title: title)
                        },
                        saveTitleArtwork: { channel, title, data in
                            try model.saveTitleArtwork(for: channel, title: title, data: data)
                        }
                    )
                    .frame(maxHeight: .infinity)
                    
                    // Channel Dock (55% viewport height)
                    TileGridView(
                        channels: visibleChannels,
                        focusedChannel: $focusedChannel,
                        namespace: heroNamespace,
                        onSelect: { channel in
                            launchChannel(channel)
                        },
                        onAddCustom: {
                            model.showAddSheet = true
                        },
                        onRemove: { channel in
                            try model.removeCustomChannel(id: channel.id)
                            if focusedChannel?.id == channel.id {
                                focusedChannel = visibleChannels.first
                            }
                        }
                    )
                    .frame(height: 280)
                    .padding(.bottom, 20)
                }
                .transition(.opacity)
            }
            
            // Spotlight Vibe Search Overlay
            if isVibeSearchPresented {
                VibeSearchModal(
                    engine: vibeEngine,
                    channels: visibleChannels,
                    isPresented: $isVibeSearchPresented,
                    onSelectChannel: { channel in
                        launchChannel(channel)
                    }
                )
            }
        }
        .sheet(isPresented: $model.showAddSheet) {
            AddServiceSheet { name, url, upNextTitle in
                let channel = try model.addCustomChannel(name: name, url: url, upNextTitle: upNextTitle)
                focusedChannel = channel
                Task {
                    do {
                        try await model.populateCustomService(for: channel.id)
                    } catch {
                        print("Unable to populate recommendations and banner for \(channel.name): \(error)")
                    }
                    focusedChannel = model.channels.first { $0.id == channel.id }
                }
            }
        }
        .onAppear {
            if focusedChannel == nil {
                focusedChannel = visibleChannels.first
            }
            for channel in model.channels where
                channel.id.hasPrefix("custom-") &&
                    (channel.upNextTitles.isEmpty || channel.upNextArtworkURL == nil)
            {
                Task {
                    do {
                        try await model.populateCustomService(for: channel.id)
                        if focusedChannel?.id == channel.id {
                            focusedChannel = model.channels.first { $0.id == channel.id }
                        }
                    } catch {
                        print("Unable to load saved service banner for \(channel.name): \(error)")
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openVibeSearch)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isVibeSearchPresented.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .returnToDashboard)) { _ in
            if activeChannel != nil {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    activeChannel = nil
                    activeDestinationURL = nil
                }
            }
        }
    }

    private var visibleChannels: [ChannelItem] {
        model.channels.isEmpty ? [ChannelItem.fallback] : model.channels
    }
    
    private func launchChannel(_ channel: ChannelItem, destinationURL: URL? = nil) {
        withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
            activeChannel = channel
            activeDestinationURL = destinationURL
        }
    }
}
