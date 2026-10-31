import AppKit
import SwiftUI

struct HeroBannerArtwork: View {
    let url: URL?
    let usesWideArtwork: Bool
    let primaryColor: Color
    let symbolName: String

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let url, url.isFileURL {
                    if let image = NSImage(contentsOf: url) {
                        artwork(Image(nsImage: image), size: geometry.size)
                    } else {
                        fallback(size: geometry.size)
                    }
                } else {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            artwork(image, size: geometry.size)
                        } else {
                            fallback(size: geometry.size)
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
    }

    @ViewBuilder
    private func artwork(_ image: Image, size: CGSize) -> some View {
        if usesWideArtwork {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
        } else {
            ZStack {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .blur(radius: 42)
                    .opacity(0.4)

                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 300, height: 300)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 100)
                    .shadow(color: primaryColor.opacity(0.65), radius: 32)
            }
        }
    }

    private func fallback(size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [primaryColor.opacity(0.72), Color.black.opacity(0.25)],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            Image(systemName: symbolName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 220, height: 220)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 140)
                .foregroundStyle(.white.opacity(0.25))
        }
        .frame(width: size.width, height: size.height)
    }
}
