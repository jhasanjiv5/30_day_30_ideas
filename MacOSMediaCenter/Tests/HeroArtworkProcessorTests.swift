import CoreGraphics
import Foundation
import ImageIO
import XCTest
@testable import MacOSMediaCenter

final class HeroArtworkProcessorTests: XCTestCase {
    func testLandscapeArtworkMatchesBannerSpecification() throws {
        try assertBannerSpecification(for: makePNG(width: 1600, height: 900))
    }

    func testPortraitArtworkMatchesBannerSpecification() throws {
        try assertBannerSpecification(for: makePNG(width: 800, height: 1200))
    }

    func testCustomServiceVibeIsInferredWhenNoVibeWasProvided() {
        XCTAssertEqual(
            ChannelVibe.infer(name: "Disney+", url: URL(string: "https://www.disneyplus.com")!),
            "Family adventures & animation"
        )
        XCTAssertEqual(
            ChannelVibe.infer(name: "My Streaming Site", url: URL(string: "https://stream.example.com")!),
            "Recommended picks from My Streaming Site"
        )
    }

    func testCustomServicesGetVibeBasedRecommendations() {
        let familyPicks = ChannelVibe.recommendations(
            for: "My Stream",
            vibe: "Family adventures & animation"
        )
        XCTAssertEqual(familyPicks.count, 3)
        XCTAssertTrue(familyPicks.allSatisfy { $0.placement == .recommended })
        XCTAssertEqual(familyPicks.first?.title, "Bluey")

        XCTAssertEqual(ChannelVibe.category(for: "Live sports & game-day highlights"), "Sports")
    }

    func testPrimeVideoGetsPrimeSpecificVibeRecommendationsAndSearchURL() {
        let url = URL(string: "https://www.primevideo.com")!
        XCTAssertTrue(ChannelVibe.isPrimeVideo(name: "Prime Video", url: url))
        XCTAssertEqual(ChannelVibe.infer(name: "Prime Video", url: url), "Prime Video originals & movies")
        XCTAssertEqual(ChannelVibe.resolvedVibe(
            name: "Prime Video",
            url: url,
            savedVibe: "Binge-worthy series & movies"
        ), "Prime Video originals & movies")

        let recommendations = ChannelVibe.recommendations(
            for: "Prime Video",
            url: url,
            vibe: "Prime Video originals & movies"
        )
        XCTAssertEqual(recommendations.map(\.title), ["The Boys", "Reacher", "Fallout"])
        XCTAssertEqual(recommendations.first?.title, "The Boys")
        let sections = ChannelVibe.titleSections(
            name: "Prime Video",
            recommendations: recommendations,
            explicitUpNextTitle: nil
        )
        XCTAssertEqual(sections.upNext.first?.title, "The Boys")
        XCTAssertEqual(sections.upNext.first?.placement, .upNext)
        XCTAssertEqual(sections.recommended.map(\.title), ["Reacher", "Fallout"])

        let channel = ChannelItem(
            id: "custom-prime-video",
            name: "Prime Video",
            category: "Amazon Originals",
            url: url,
            primaryColor: ChannelVibe.color(name: "Prime Video", url: url),
            iconSystemName: ChannelVibe.icon(name: "Prime Video", url: url),
            tagline: "Prime Video originals & movies",
            aiContextHint: "Prime Video originals & movies",
            backdropImageName: "tv"
        )
        let search = URLComponents(url: channel.searchURL(for: "Reacher"), resolvingAgainstBaseURL: false)
        XCTAssertEqual(search?.host, "www.primevideo.com")
        XCTAssertEqual(search?.path, "/search")
        XCTAssertEqual(search?.queryItems?.first(where: { $0.name == "phrase" })?.value, "Reacher")
    }

    func testJioHotstarGetsItsOwnVibeRecommendationsBannerAndSearchURL() {
        let serviceURL = URL(string: "https://www.jiohotstar.com/in")!
        XCTAssertTrue(ChannelVibe.isJioHotstar(name: "JioHotStar", url: serviceURL))
        XCTAssertEqual(
            ChannelVibe.infer(name: "JioHotStar", url: serviceURL),
            "Indian originals, live sports & entertainment"
        )
        XCTAssertEqual(
            ChannelVibe.resolvedVibe(
                name: "JioHotStar",
                url: serviceURL,
                savedVibe: "Recommended picks from JioHotStar"
            ),
            "Indian originals, live sports & entertainment"
        )

        let recommendations = ChannelVibe.recommendations(
            for: "JioHotStar",
            url: serviceURL,
            vibe: "Some generated model response"
        )
        XCTAssertEqual(
            recommendations.map(\.title),
            ["Criminal Justice", "The Legend of Hanuman", "Special OPS"]
        )
        let sections = ChannelVibe.titleSections(
            name: "JioHotStar",
            recommendations: recommendations,
            explicitUpNextTitle: nil
        )
        XCTAssertEqual(sections.upNext.first?.title, "Criminal Justice")
        XCTAssertEqual(sections.upNext.first?.placement, .upNext)
        XCTAssertEqual(sections.recommended.map(\.title), ["The Legend of Hanuman", "Special OPS"])
        XCTAssertEqual(ChannelVibe.category(name: "JioHotStar", url: serviceURL, vibe: ""), "Indian Entertainment")
        XCTAssertNil(ChannelVibe.resolvedSavedUpNextTitle(
            name: "JioHotStar",
            url: serviceURL,
            vibe: "Indian originals, live sports & entertainment",
            legacyTitle: "Severance",
            explicitTitle: nil
        ))
        XCTAssertEqual(ChannelVibe.resolvedSavedUpNextTitle(
            name: "JioHotStar",
            url: serviceURL,
            vibe: "Indian originals, live sports & entertainment",
            legacyTitle: "Severance",
            explicitTitle: "My manually chosen title"
        ), "My manually chosen title")

        let channel = ChannelItem(
            id: "custom-jiohotstar",
            name: "JioHotStar",
            category: "Indian Entertainment",
            url: URL(string: "https://www.jio.com")!,
            primaryColor: ChannelVibe.color(name: "JioHotStar", url: serviceURL),
            iconSystemName: ChannelVibe.icon(name: "JioHotStar", url: serviceURL),
            tagline: "Indian originals & live sports",
            aiContextHint: "Indian originals, live sports & entertainment",
            backdropImageName: "tv"
        )
        let search = URLComponents(url: channel.searchURL(for: "Criminal Justice"), resolvingAgainstBaseURL: false)
        XCTAssertEqual(search?.host, "www.hotstar.com")
        XCTAssertEqual(search?.path, "/in/search")
        XCTAssertEqual(search?.queryItems?.first(where: { $0.name == "q" })?.value, "Criminal Justice")
    }

    func testTitleArtworkSearchRequiresAnExactTitleMatch() {
        XCTAssertTrue(TitleArtworkService.isExactTitleMatch(
            requested: "The Legend of Hanuman",
            result: "The Legend Of Hanuman"
        ))
        XCTAssertFalse(TitleArtworkService.isExactTitleMatch(
            requested: "Criminal Justice",
            result: "Criminal Justice: Adhura Sach"
        ))
    }

    func testServiceLogoPrefersHighResolutionWebsiteIcon() {
        let pageURL = URL(string: "https://stream.example.com/watch")!
        let html = """
        <link rel="icon" href="/favicon.ico" sizes="16x16">
        <link sizes="512x512" href="/brand.png" rel="icon">
        <link href="/touch-icon.png" rel="apple-touch-icon">
        """

        XCTAssertEqual(
            ServiceLogoService.preferredIconURL(in: html, baseURL: pageURL)?.absoluteString,
            "https://stream.example.com/touch-icon.png"
        )
    }

    func testServiceLogoIgnoresUnsafeAndUnrelatedLinks() {
        let pageURL = URL(string: "https://stream.example.com")!
        let html = """
        <link rel="stylesheet" href="/theme.css">
        <link rel="icon" href="javascript:alert(1)" sizes="1024x1024">
        <link rel="icon" href="/favicon.png" sizes="32x32">
        """

        XCTAssertEqual(
            ServiceLogoService.preferredIconURL(in: html, baseURL: pageURL)?.absoluteString,
            "https://stream.example.com/favicon.png"
        )
    }

    func testUnknownServiceDoesNotReceiveAppleTVOrOtherUnverifiedTitles() {
        XCTAssertTrue(ChannelVibe.recommendations(
            for: "My Streaming Site",
            url: URL(string: "https://stream.example.com")!,
            vibe: "Recommended picks from My Streaming Site"
        ).isEmpty)
    }

    func testUnknownServiceGetsGeneratedOrHonestFallbackShelfItems() {
        let suggestions = ServiceRecommendationGenerator.parse(
            "1. Example Drama\n- Another Show\nExample Drama",
            serviceName: "My Streaming Site"
        )
        XCTAssertEqual(suggestions.map(\.title), ["Example Drama", "Another Show"])
        XCTAssertTrue(suggestions.allSatisfy {
            $0.detail == "Suggested to search on My Streaming Site"
        })

        let fallback = ServiceRecommendationGenerator.fallback(for: "My Streaming Site")
        XCTAssertEqual(fallback.first?.title, "Browse My Streaming Site")
        XCTAssertEqual(fallback.first?.detail, "Explore the catalog for a title to watch")

        let sections = ChannelVibe.titleSections(
            name: "My Streaming Site",
            recommendations: fallback,
            explicitUpNextTitle: nil
        )
        XCTAssertEqual(sections.upNext.first?.title, "Browse My Streaming Site")
        XCTAssertEqual(sections.upNext.first?.placement, .upNext)
        XCTAssertEqual(sections.upNext.first?.detail, "Explore the catalog for a title to watch")
    }

    private func assertBannerSpecification(for sourceData: Data) throws {
        let banner = try HeroArtworkProcessor.jpegData(from: sourceData)
        XCTAssertLessThanOrEqual(banner.count, HeroArtworkProcessor.maximumFileSize)
        XCTAssertEqual(Array(banner.prefix(2)), [0xFF, 0xD8])

        guard
            let source = CGImageSourceCreateWithData(banner as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            XCTFail("Output JPEG could not be decoded")
            return
        }
        XCTAssertEqual(image.width, HeroArtworkProcessor.width)
        XCTAssertEqual(image.height, HeroArtworkProcessor.height)
    }

    private func makePNG(width: Int, height: Int) throws -> Data {
        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ),
            let image = context.makeImage()
        else {
            throw NSError(domain: "HeroArtworkProcessorTests", code: 1)
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
            throw NSError(domain: "HeroArtworkProcessorTests", code: 2)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "HeroArtworkProcessorTests", code: 3)
        }
        return data as Data
    }
}
