import SwiftUI

struct ServiceTitle: Identifiable, Codable {
    enum Placement: String, Codable {
        case upNext = "UP NEXT"
        case recommended = "RECOMMENDED"
    }

    let title: String
    let detail: String
    let placement: Placement

    var id: String { "\(placement.rawValue)-\(title)" }
}

struct ChannelItem: Identifiable {
    let id: String
    let name: String
    var category: String
    let url: URL
    let primaryColor: Color
    let iconSystemName: String
    var tagline: String
    var aiContextHint: String
    let backdropImageName: String
    var heroArtworkURL: URL? = nil
    var keepsGeneratedHeroArtwork: Bool = false
    var upNextTitles: [ServiceTitle] = []
    var recommendedTitles: [ServiceTitle] = []
    var explicitUpNextTitle: String? = nil
    var upNextArtworkURL: URL? = nil
    var bannerArtworkStatus: String? = nil

    func searchURL(for title: String) -> URL {
        let host = url.host?.lowercased() ?? ""
        if ChannelVibe.isJioHotstar(name: name, url: url) {
            var components = URLComponents(string: "https://www.hotstar.com/in/search")
            components?.queryItems = [URLQueryItem(name: "q", value: title)]
            return components?.url ?? url
        }
        let path: String
        let queryName: String

        switch host {
        case "primevideo.com", "www.primevideo.com":
            path = "/search"
            queryName = "phrase"
        case let amazonHost where amazonHost.contains("amazon.") &&
            (url.path.lowercased().contains("/gp/video") || url.path.lowercased().contains("/prime-video")):
            path = "/gp/video/search"
            queryName = "phrase"
        case "www.netflix.com", "netflix.com":
            path = "/search"
            queryName = "q"
        case "tv.apple.com":
            path = "/search"
            queryName = "term"
        case "play.max.com":
            path = "/search"
            queryName = "q"
        case "www.youtube.com", "youtube.com":
            path = "/results"
            queryName = "search_query"
        default:
            return url
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.path = path
        components?.queryItems = [URLQueryItem(name: queryName, value: title)]
        return components?.url ?? url
    }

    var artworkURL: URL? {
        guard let host = url.host else { return nil }
        var components = URLComponents(string: "https://www.google.com/s2/favicons")
        components?.queryItems = [
            URLQueryItem(name: "domain", value: host),
            URLQueryItem(name: "sz", value: "512")
        ]
        return components?.url
    }

    static let fallback = ChannelItem(
        id: "fallback",
        name: "Featured Picks",
        category: "Curated",
        url: URL(string: "https://www.apple.com")!,
        primaryColor: Color(red: 0.29, green: 0.54, blue: 0.95),
        iconSystemName: "sparkles",
        tagline: "Cinematic recommendations and hand-picked highlights",
        aiContextHint: "Mood Match",
        backdropImageName: "photo.artframe"
    )

    static let sampleChannels: [ChannelItem] = [
        ChannelItem(
            id: "netflix",
            name: "Netflix",
            category: "Movies & Series",
            url: URL(string: "https://www.netflix.com")!,
            primaryColor: Color(red: 0.91, green: 0.17, blue: 0.16),
            iconSystemName: "play.tv.fill",
            tagline: "Big-screen storytelling with award-winning drama",
            aiContextHint: "Dark Thrillers",
            backdropImageName: "film",
            upNextTitles: [
                ServiceTitle(title: "The Night Agent", detail: "Continue the story", placement: .upNext)
            ],
            recommendedTitles: [
                ServiceTitle(title: "Mindhunter", detail: "Crime drama", placement: .recommended),
                ServiceTitle(title: "Wednesday", detail: "Mystery series", placement: .recommended),
                ServiceTitle(title: "The Diplomat", detail: "Political thriller", placement: .recommended)
            ]
        ),
        ChannelItem(
            id: "appletv",
            name: "Apple TV+",
            category: "Premium Originals",
            url: URL(string: "https://tv.apple.com")!,
            primaryColor: Color(red: 0.28, green: 0.45, blue: 0.92),
            iconSystemName: "tv.fill",
            tagline: "Cinematic originals designed for a living room glow",
            aiContextHint: "Epic Sci‑Fi",
            backdropImageName: "star.fill",
            upNextTitles: [
                ServiceTitle(title: "Severance", detail: "Continue watching", placement: .upNext)
            ],
            recommendedTitles: [
                ServiceTitle(title: "Foundation", detail: "Sci-fi drama", placement: .recommended),
                ServiceTitle(title: "Silo", detail: "Mystery series", placement: .recommended),
                ServiceTitle(title: "For All Mankind", detail: "Alternate history", placement: .recommended)
            ]
        ),
        ChannelItem(
            id: "max",
            name: "Max",
            category: "HBO & Discovery",
            url: URL(string: "https://play.max.com")!,
            primaryColor: Color(red: 0.63, green: 0.13, blue: 0.69),
            iconSystemName: "sparkle",
            tagline: "Prestige entertainment and true-stories with edge",
            aiContextHint: "Award Season",
            backdropImageName: "sparkles",
            upNextTitles: [
                ServiceTitle(title: "The Last of Us", detail: "Continue watching", placement: .upNext)
            ],
            recommendedTitles: [
                ServiceTitle(title: "House of the Dragon", detail: "Fantasy drama", placement: .recommended),
                ServiceTitle(title: "The White Lotus", detail: "Social satire", placement: .recommended),
                ServiceTitle(title: "The Penguin", detail: "Crime drama", placement: .recommended)
            ]
        ),
        ChannelItem(
            id: "youtube",
            name: "YouTube",
            category: "Creator Picks",
            url: URL(string: "https://www.youtube.com")!,
            primaryColor: Color(red: 0.98, green: 0.33, blue: 0.29),
            iconSystemName: "play.rectangle.fill",
            tagline: "Sharp shorts, creator sketches, and late-night discovery",
            aiContextHint: "Quick Laughs",
            backdropImageName: "video.fill",
            recommendedTitles: [
                ServiceTitle(title: "Key & Peele", detail: "Comedy sketches", placement: .recommended),
                ServiceTitle(title: "Veritasium", detail: "Science & discovery", placement: .recommended),
                ServiceTitle(title: "Kurzgesagt", detail: "Animated explainers", placement: .recommended)
            ]
        )
    ]
}
