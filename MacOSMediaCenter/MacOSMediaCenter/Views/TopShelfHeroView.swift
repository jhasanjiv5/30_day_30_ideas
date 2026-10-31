//
//  TopShelfHeroView.swift
//  MacOSMediaCenter
//

import SwiftUI
import ImagePlayground

struct TopShelfHeroView: View {
    let channel: ChannelItem
    let onLaunch: (ChannelItem) -> Void
    let onSelectTitle: (ChannelItem, String) -> Void
    let onArtworkGenerated: (ChannelItem, URL) throws -> Void
    let onKeepGeneratedArtwork: (ChannelItem, Bool) -> Void
    let cachedTitleArtwork: (ChannelItem, ServiceTitle) -> URL?
    let saveTitleArtwork: (ChannelItem, ServiceTitle, Data) throws -> URL
    
    @State private var kenBurnsScale: CGFloat = 1.0
    @State private var kenBurnsOffset: CGSize = .zero
    @State private var isImagePlaygroundPresented = false
    @State private var isTitleDetailsPresented = false
    @State private var artworkSeedChannel: ChannelItem?
    @State private var detailsTitle: ServiceTitle?
    @State private var detailsServiceName = ""
    @State private var detailsServiceTagline = ""
    @State private var artworkError: String?
    @State private var hoveredTitle: ServiceTitle?
    @State private var titleArtworkURL: URL?
    @State private var titleArtworkKey: String?
    @State private var titleArtworkError: String?

    private var bannerTitle: ServiceTitle? {
        hoveredTitle ?? channel.upNextTitles.first ?? channel.recommendedTitles.first
    }

    private var bannerArtworkStatus: String? {
        channel.bannerArtworkStatus ?? titleArtworkError
    }

    private var bannerArtworkURL: URL? {
        if channel.keepsGeneratedHeroArtwork, let heroArtworkURL = channel.heroArtworkURL {
            return heroArtworkURL
        }
        if bannerTitle?.placement == .upNext, let upNextArtworkURL = channel.upNextArtworkURL {
            return upNextArtworkURL
        }
        if titleArtworkKey == bannerTitleKey {
            return titleArtworkURL ?? channel.artworkURL
        }
        return channel.artworkURL
    }

    private var usesWideBannerArtwork: Bool {
        (channel.keepsGeneratedHeroArtwork && channel.heroArtworkURL != nil) ||
            (bannerTitle?.placement == .upNext && channel.upNextArtworkURL != nil) ||
            (titleArtworkKey == bannerTitleKey && titleArtworkURL != nil)
    }

    private var bannerTitleKey: String? {
        bannerTitle.map { "\(channel.id)-\($0.id)" }
    }
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Dynamic Backdrop with Ken Burns animation
            GeometryReader { geo in
                ZStack {
                    HeroBannerArtwork(
                        url: bannerArtworkURL,
                        usesWideArtwork: usesWideBannerArtwork,
                        primaryColor: channel.primaryColor,
                        symbolName: channel.backdropImageName
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .scaleEffect(kenBurnsScale)
                    .offset(kenBurnsOffset)
                    .animation(.easeInOut(duration: 12.0).repeatForever(autoreverses: true), value: kenBurnsScale)
                    .animation(.easeInOut(duration: 0.35), value: channel.id)
                    
                    // Cinematic dark scrim gradients for WCAG text legibility
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.85),
                            Color.black.opacity(0.35),
                            Color.clear
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.75),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            }
            .ignoresSafeArea()
            
            // Hero Brand & AI Metadata
            VStack(alignment: .leading, spacing: 14) {
                // AI Context Badge
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.yellow)
                    Text(channel.aiContextHint)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                
                if let bannerTitle {
                    Text(bannerTitle.placement.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.78))
                }

                Text(bannerTitle?.title ?? channel.name)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text(bannerTitle?.detail ?? channel.tagline)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: 560, alignment: .leading)

                if let titleArtworkError, bannerTitle != nil, !channel.keepsGeneratedHeroArtwork {
                    Text(titleArtworkError)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.72))
                }

                if let bannerArtworkStatus, !channel.keepsGeneratedHeroArtwork {
                    Text(bannerArtworkStatus)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.72))
                }
                
                HStack(spacing: 16) {
                    Button {
                        if let bannerTitle {
                            onSelectTitle(channel, bannerTitle.title)
                        } else {
                            onLaunch(channel)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text(bannerTitle.map { "Play \($0.title)" } ?? "Watch Now")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        detailsTitle = bannerTitle
                        detailsServiceName = channel.name
                        detailsServiceTagline = channel.tagline
                        isTitleDetailsPresented = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                            Text("Details")
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    if #available(macOS 15.1, *) {
                        Button {
                            artworkSeedChannel = channel
                            artworkError = nil
                            isImagePlaygroundPresented = true
                        } label: {
                            Label("Create Hero Art", systemImage: "sparkles")
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Label("Requires macOS 15.1", systemImage: "sparkles")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    if channel.heroArtworkURL != nil {
                        Button {
                            onKeepGeneratedArtwork(channel, !channel.keepsGeneratedHeroArtwork)
                        } label: {
                            Label(
                                channel.keepsGeneratedHeroArtwork ? "Use Up Next Banner" : "Keep Generated Art",
                                systemImage: channel.keepsGeneratedHeroArtwork ? "arrow.uturn.backward" : "pin.fill"
                            )
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)

                if let artworkError {
                    Text(artworkError)
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.95))
                }

                if !channel.upNextTitles.isEmpty || !channel.recommendedTitles.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(channel.upNextTitles + channel.recommendedTitles) { item in
                                Button {
                                    onSelectTitle(channel, item.title)
                                } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(item.placement.rawValue)
                                            .font(.system(size: 9, weight: .bold))
                                            .tracking(0.8)
                                            .foregroundStyle(.white.opacity(0.68))
                                        Text(item.title)
                                            .font(.system(size: 13, weight: .semibold))
                                            .lineLimit(1)
                                        Text(item.detail)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.white.opacity(0.72))
                                            .lineLimit(1)
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .frame(width: 158, alignment: .leading)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                                .help("Search for \(item.title) on \(channel.name)")
                                .onHover { isHovering in
                                    if isHovering {
                                        hoveredTitle = item
                                    } else if hoveredTitle?.id == item.id {
                                        hoveredTitle = nil
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 700, alignment: .leading)
                }
            }
            .padding(.horizontal, 48)
            .padding(.bottom, 24)
        }
        .onAppear {
            kenBurnsScale = 1.08
            kenBurnsOffset = CGSize(width: -15, height: -10)
        }
        .onChange(of: channel.id) { _ in
            hoveredTitle = nil
            titleArtworkURL = nil
            titleArtworkKey = nil
            titleArtworkError = nil
        }
        .task(id: bannerTitleKey ?? "\(channel.id)-service") {
            guard
                let bannerTitle,
                !(channel.keepsGeneratedHeroArtwork && channel.heroArtworkURL != nil)
            else {
                titleArtworkURL = nil
                titleArtworkKey = nil
                titleArtworkError = nil
                return
            }

            titleArtworkURL = nil
            titleArtworkKey = nil
            titleArtworkError = nil
            do {
                if bannerTitle.placement == .upNext, let upNextURL = channel.upNextArtworkURL {
                    titleArtworkURL = upNextURL
                } else if let cachedURL = cachedTitleArtwork(channel, bannerTitle) {
                    titleArtworkURL = cachedURL
                } else if let imageData = try await TitleArtworkService.artworkData(for: bannerTitle.title) {
                    titleArtworkURL = try saveTitleArtwork(channel, bannerTitle, imageData)
                }
                titleArtworkKey = bannerTitleKey
                if titleArtworkURL == nil {
                    titleArtworkError = "Title artwork is unavailable; showing service artwork."
                }
            } catch {
                titleArtworkKey = bannerTitleKey
                titleArtworkError = "Could not load title artwork; showing service artwork."
                print("Unable to load artwork for \(bannerTitle.title): \(error)")
            }
        }
        .sheet(isPresented: $isTitleDetailsPresented) {
            TitleDetailsSheet(
                title: detailsTitle,
                serviceName: detailsServiceName,
                serviceTagline: detailsServiceTagline
            )
        }
        .modifier(
            ImagePlaygroundSheetModifier(
                isPresented: $isImagePlaygroundPresented,
                concepts: artworkConcepts,
                onCompletion: { url in
                    guard let artworkSeedChannel else { return }
                    do {
                        try onArtworkGenerated(artworkSeedChannel, url)
                        artworkError = nil
                    } catch {
                        artworkError = error.localizedDescription
                    }
                }
            )
        )
    }

    private var artworkConcepts: [String] {
        let seedChannel = artworkSeedChannel ?? channel
        return [
            seedChannel.name,
            seedChannel.aiContextHint,
            seedChannel.tagline,
            "A cinematic streaming hero banner, 8:3 ultra-wide composition for a 3840 by 1440 pixel display. Full-bleed high-detail imagery, dramatic atmospheric lighting, dark gradient fade on the left for readable title text, no words, no lettering, no logos."
        ]
    }
}

private struct TitleDetailsSheet: View {
    let title: ServiceTitle?
    let serviceName: String
    let serviceTagline: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title?.title ?? serviceName)
                        .font(.title2.weight(.bold))

                    Text(title.map { "\($0.placement.rawValue) on \(serviceName)" } ?? serviceName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            if let title {
                Label(title.detail, systemImage: "play.rectangle")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Selected for \(serviceName). Use Play to search this service for the title.")
                    .foregroundStyle(.secondary)
            } else {
                Text(serviceTagline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 240)
    }
}

private struct ImagePlaygroundSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    let concepts: [String]
    let onCompletion: (URL) -> Void

    func body(content: Content) -> some View {
        if #available(macOS 15.1, *) {
            content.imagePlaygroundSheet(
                isPresented: $isPresented,
                concepts: concepts.map(ImagePlaygroundConcept.text),
                onCompletion: onCompletion
            )
        } else {
            content
        }
    }
}
