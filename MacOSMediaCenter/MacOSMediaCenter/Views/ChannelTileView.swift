//
//  ChannelTileView.swift
//  MacOSMediaCenter
//

import SwiftUI

struct ChannelTileView: View {
    let channel: ChannelItem
    let isFocused: Bool
    let namespace: Namespace.ID
    let onSelect: () -> Void
    let onRemove: (() -> Void)?
    
    @State private var isHovered: Bool = false
    @State private var pitch: Double = 0.0 // X-axis tilt
    @State private var yaw: Double = 0.0   // Y-axis tilt
    @State private var sheenOffset: CGPoint = CGPoint(x: 0.5, y: 0.5)
    @State private var serviceLogoURL: URL?
    
    var body: some View {
        Button(action: onSelect) {
            ZStack {
                // Card Background & Brand Gradient
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                channel.primaryColor.opacity(0.85),
                                channel.primaryColor.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Use the service's own website icon rather than a generated symbol.
                VStack(spacing: 7) {
                    AsyncImage(url: serviceLogoURL ?? channel.artworkURL) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFit()
                                .padding(7)
                        } else {
                            Text(serviceInitials)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(channel.primaryColor)
                        }
                    }
                    .frame(width: 58, height: 58)
                    .background(.white, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .accessibilityLabel("\(channel.name) logo")
                    
                    Text(channel.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Text(channel.category)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                
                // Specular Light Sheen Overlay
                if isHovered || isFocused {
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            Color.white.opacity(0.08),
                            Color.clear
                        ],
                        center: UnitPoint(x: sheenOffset.x, y: sheenOffset.y),
                        startRadius: 0,
                        endRadius: 120
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .blendMode(.overlay)
                }
                
                // Apple TV Focus Ring
                if isFocused {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white, lineWidth: 3)
                        .shadow(color: .white.opacity(0.5), radius: 8)
                }
            }
            .frame(width: 190, height: 145)
            .matchedGeometryEffect(id: channel.id, in: namespace)
            // 3D Parallax Rotation
            .rotation3DEffect(
                .degrees(pitch),
                axis: (x: 1, y: 0, z: 0)
            )
            .rotation3DEffect(
                .degrees(yaw),
                axis: (x: 0, y: 1, z: 0)
            )
            .scaleEffect(isHovered || isFocused ? 1.08 : 1.0)
            .shadow(
                color: Color.black.opacity(isHovered || isFocused ? 0.6 : 0.25),
                radius: isHovered || isFocused ? 20 : 8,
                x: 0,
                y: isHovered || isFocused ? 12 : 4
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isHovered)
            .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isFocused)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(.black.opacity(0.65), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(8)
                .help("Remove \(channel.name)")
                .accessibilityLabel("Remove \(channel.name)")
            }
        }
        .task(id: channel.id) {
            serviceLogoURL = await ServiceLogoService.logoURL(for: channel.url) ?? channel.artworkURL
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                isHovered = true
                let normX = (location.x / 190.0) - 0.5
                let normY = (location.y / 145.0) - 0.5
                
                // Compute subtle 3D tilt angles (max ±10 degrees)
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 20)) {
                    yaw = normX * 18.0
                    pitch = -normY * 18.0
                    sheenOffset = CGPoint(x: location.x / 190.0, y: location.y / 145.0)
                }
            case .ended:
                isHovered = false
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    yaw = 0
                    pitch = 0
                    sheenOffset = CGPoint(x: 0.5, y: 0.5)
                }
            }
        }
    }

    private var serviceInitials: String {
        let initials = channel.name
            .split(whereSeparator: { $0.isWhitespace || $0 == "+" })
            .compactMap(\.first)
            .prefix(2)
        return initials.map(String.init).joined().uppercased()
    }
}
