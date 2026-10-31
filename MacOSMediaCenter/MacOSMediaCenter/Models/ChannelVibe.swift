import Foundation
import SwiftUI

enum ChannelVibe {
    struct TitleSections {
        let upNext: [ServiceTitle]
        let recommended: [ServiceTitle]
    }

    static func infer(name: String, url: URL) -> String {
        if isJioHotstar(name: name, url: url) {
            return "Indian originals, live sports & entertainment"
        }
        if isPrimeVideo(name: name, url: url) {
            return "Prime Video originals & movies"
        }

        let source = "\(name) \(url.host ?? "")".lowercased()
        let matches: [(keywords: [String], vibe: String)] = [
            (["netflix", "hulu", "max", "hbo"], "Binge-worthy series & movies"),
            (["disney", "pixar", "kids", "family"], "Family adventures & animation"),
            (["youtube", "twitch", "creator"], "Creator picks & trending videos"),
            (["spotify", "apple music", "music", "soundcloud"], "Music, live sessions & new releases"),
            (["espn", "sports", "nba", "nfl", "mlb"], "Live sports & game-day highlights"),
            (["news", "bbc", "cnn", "guardian"], "Live news & current affairs"),
            (["criterion", "mubi", "arthouse"], "Independent films & cinema classics"),
            (["crunchyroll", "anime"], "Anime & animation")
        ]

        return matches.first(where: { entry in
            entry.keywords.contains(where: source.contains)
        })?.vibe ?? "Recommended picks from \(name)"
    }

    static func category(for vibe: String) -> String {
        let value = vibe.lowercased()
        if value.contains("family") || value.contains("animation") || value.contains("kids") {
            return "Family & Animation"
        }
        if value.contains("creator") || value.contains("trending") || value.contains("video") {
            return "Creator Picks"
        }
        if value.contains("music") || value.contains("live sessions") {
            return "Music"
        }
        if value.contains("sport") || value.contains("game-day") {
            return "Sports"
        }
        if value.contains("news") || value.contains("current affairs") {
            return "News & Current Affairs"
        }
        if value.contains("anime") {
            return "Anime"
        }
        if value.contains("independent") || value.contains("cinema") {
            return "Independent Cinema"
        }
        return "Movies & Series"
    }

    static func isPrimeVideo(name: String, url: URL) -> Bool {
        let normalizedName = normalized(name)
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()
        return normalizedName.contains("primevideo")
            || host == "primevideo.com"
            || host.hasSuffix(".primevideo.com")
            || (normalizedName.contains("amazonprime") && host.contains("amazon."))
            || (host.contains("amazon.") && (path.contains("/gp/video") || path.contains("/prime-video")))
    }

    static func isJioHotstar(name: String, url: URL) -> Bool {
        let normalizedName = normalized(name)
        let host = (url.host ?? "").lowercased()
        return normalizedName.contains("jiohotstar")
            || normalizedName == "hotstar"
            || host == "hotstar.com"
            || host.hasSuffix(".hotstar.com")
            || host == "jiohotstar.com"
            || host.hasSuffix(".jiohotstar.com")
    }

    private static func normalized(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    static func resolvedVibe(name: String, url: URL, savedVibe: String?) -> String {
        if isJioHotstar(name: name, url: url) || isPrimeVideo(name: name, url: url) {
            return infer(name: name, url: url)
        }
        guard let savedVibe, !savedVibe.isEmpty, !isLegacyInferredVibe(savedVibe) else {
            return infer(name: name, url: url)
        }
        return savedVibe
    }

    static func isLegacyInferredVibe(_ vibe: String) -> Bool {
        let normalized = vibe.lowercased()
        return normalized == "your service"
            || normalized == "binge-worthy series & movies"
            || normalized.hasPrefix("recommended picks from ")
    }

    static func recommendations(for name: String, vibe: String) -> [ServiceTitle] {
        recommendations(for: name, url: nil, vibe: vibe)
    }

    static func recommendations(for name: String, url: URL?, vibe: String) -> [ServiceTitle] {
        let value = "\(name) \(vibe)".lowercased()
        let picks: [(String, String)]

        let matchesJioHotstar = url.map { isJioHotstar(name: name, url: $0) }
            ?? (normalized(name).contains("jiohotstar") || normalized(name) == "hotstar")
        let matchesPrimeVideo = url.map { isPrimeVideo(name: name, url: $0) }
            ?? normalized(name).contains("primevideo")

        if matchesJioHotstar {
            picks = [
                ("Criminal Justice", "Indian legal crime drama"),
                ("The Legend of Hanuman", "Indian animated epic"),
                ("Special OPS", "Indian espionage thriller")
            ]
        } else if matchesPrimeVideo {
            picks = [
                ("The Boys", "Superhero satire"),
                ("Reacher", "Action thriller"),
                ("Fallout", "Post-apocalyptic adventure")
            ]
        } else if value.contains("family") || value.contains("animation") || value.contains("kids") || value.contains("disney") {
            picks = [
                ("Bluey", "Family animation"),
                ("Percy Jackson and the Olympians", "Fantasy adventure"),
                ("The Mandalorian", "Sci-fi adventure")
            ]
        } else if value.contains("creator") || value.contains("youtube") || value.contains("trending") {
            picks = [
                ("Key & Peele", "Comedy sketches"),
                ("Veritasium", "Science & discovery"),
                ("Kurzgesagt", "Animated explainers")
            ]
        } else if value.contains("music") || value.contains("spotify") {
            picks = [
                ("Song Exploder", "Artists unpack their music"),
                ("The Voice", "Live music competition"),
                ("Daisy Jones & the Six", "Music drama")
            ]
        } else if value.contains("sport") || value.contains("espn") || value.contains("game-day") {
            picks = [
                ("Welcome to Wrexham", "Football documentary"),
                ("Formula 1: Drive to Survive", "Motorsport series"),
                ("Quarterback", "Behind the game")
            ]
        } else if value.contains("news") || value.contains("current affairs") {
            picks = [
                ("The Daily Show", "News satire"),
                ("The Newsroom", "Newsroom drama"),
                ("Last Week Tonight with John Oliver", "Current affairs")
            ]
        } else if value.contains("anime") {
            picks = [
                ("One Piece", "Anime adventure"),
                ("Demon Slayer: Kimetsu no Yaiba", "Anime action"),
                ("Frieren: Beyond Journey's End", "Fantasy anime")
            ]
        } else if value.contains("independent") || value.contains("cinema") {
            picks = [
                ("The Bear", "Independent drama"),
                ("Fargo", "Crime anthology"),
                ("Atlanta", "Comedy-drama")
            ]
        } else if value.contains("thrill") || value.contains("crime") || value.contains("dark") {
            picks = [
                ("Mindhunter", "Crime drama"),
                ("Wednesday", "Mystery series"),
                ("The Diplomat", "Political thriller")
            ]
        } else {
            return []
        }

        return picks.map {
            ServiceTitle(title: $0.0, detail: $0.1, placement: .recommended)
        }
    }

    static func titleSections(
        name: String,
        recommendations: [ServiceTitle],
        explicitUpNextTitle: String?
    ) -> TitleSections {
        let trimmedExplicitTitle = explicitUpNextTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let explicitTitle = trimmedExplicitTitle.flatMap { title in
            title.isEmpty ? nil : title
        }

        let nextTitle = explicitTitle ?? recommendations.first?.title
        let nextDetail = recommendations.first(where: { $0.title == nextTitle })?.detail
        let upNext = nextTitle.map {
            [
                ServiceTitle(
                    title: $0,
                    detail: explicitTitle == nil ? (nextDetail ?? "Recommended for you") : "Up next on \(name)",
                    placement: .upNext
                )
            ]
        } ?? []
        return TitleSections(
            upNext: upNext,
            recommended: recommendations.filter { $0.title != nextTitle }
        )
    }

    static func resolvedSavedUpNextTitle(
        name: String,
        url: URL,
        vibe: String,
        legacyTitle: String?,
        explicitTitle: String?
    ) -> String? {
        if let explicitTitle, !explicitTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return explicitTitle
        }
        guard let legacyTitle else { return nil }
        if isJioHotstar(name: name, url: url) || isPrimeVideo(name: name, url: url) {
            let knownTitles = recommendations(for: name, url: url, vibe: vibe).map(\.title)
            return knownTitles.first(where: { $0.caseInsensitiveCompare(legacyTitle) == .orderedSame })
        }
        return legacyTitle
    }

    static func category(name: String, url: URL, vibe: String) -> String {
        if isJioHotstar(name: name, url: url) {
            return "Indian Entertainment"
        }
        return isPrimeVideo(name: name, url: url) ? "Amazon Originals" : category(for: vibe)
    }

    static func color(name: String, url: URL) -> Color {
        if isJioHotstar(name: name, url: url) {
            return Color(red: 0.34, green: 0.20, blue: 0.72)
        }
        if isPrimeVideo(name: name, url: url) {
            return Color(red: 0.0, green: 0.55, blue: 0.78)
        }
        return Color(red: 0.42, green: 0.34, blue: 0.76)
    }

    static func icon(name: String, url: URL) -> String {
        if isJioHotstar(name: name, url: url) {
            return "sparkles.tv"
        }
        return isPrimeVideo(name: name, url: url) ? "play.tv.fill" : "play.rectangle.on.rectangle.fill"
    }
}
