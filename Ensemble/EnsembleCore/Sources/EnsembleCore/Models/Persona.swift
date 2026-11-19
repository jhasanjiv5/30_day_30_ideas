import Foundation

public struct WatchHistoryEntry: Codable, Sendable, Equatable, Hashable {
    public let title: String
    public let genres: [String]
    public let moodTags: [String]
    public let completionRatio: Double
    public let liked: Bool

    public init(
        title: String,
        genres: [String],
        moodTags: [String],
        completionRatio: Double,
        liked: Bool
    ) {
        self.title = title
        self.genres = genres
        self.moodTags = moodTags
        self.completionRatio = completionRatio
        self.liked = liked
    }
}

public struct Persona: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public let displayName: String
    public let roleLabel: String
    public let avatarSymbol: String
    public let accentHex: String
    public let isChild: Bool
    public let isTeen: Bool
    public let watchHistory: [WatchHistoryEntry]

    public init(
        id: String,
        displayName: String,
        roleLabel: String,
        avatarSymbol: String,
        accentHex: String,
        isChild: Bool,
        isTeen: Bool = false,
        watchHistory: [WatchHistoryEntry]
    ) {
        self.id = id
        self.displayName = displayName
        self.roleLabel = roleLabel
        self.avatarSymbol = avatarSymbol
        self.accentHex = accentHex
        self.isChild = isChild
        self.isTeen = isTeen
        self.watchHistory = watchHistory
    }
}

/// Privacy-preserving normalized taste vector transmitted over Bonjour/Network.framework.
/// Raw watch history NEVER leaves the iPhone.
public struct TasteVector: Codable, Sendable, Equatable, Hashable {
    public let genreWeights: [String: Double]
    public let moodWeights: [String: Double]

    public init(genreWeights: [String: Double], moodWeights: [String: Double]) {
        self.genreWeights = TasteVector.normalize(genreWeights)
        self.moodWeights = TasteVector.normalize(moodWeights)
    }

    public static func normalize(_ raw: [String: Double]) -> [String: Double] {
        let positive = raw.mapValues { max(0.0, $0) }.filter { $0.value > 0 }
        let sum = positive.values.reduce(0.0, +)
        guard sum > 0 else { return [:] }
        return positive.mapValues { $0 / sum }
    }

    /// Computes normalized cosine-like overlap affinity in [0, 1] against a catalogue item.
    public func affinity(for item: MediaItem) -> Double {
        let normalizedGenres = item.genres.map { $0.lowercased() }
        let normalizedMoods = item.moodTags.map { $0.lowercased() }

        let genreScore = normalizedGenres.reduce(0.0) { acc, genre in
            acc + (genreWeights[genre] ?? 0.0)
        }
        let moodScore = normalizedMoods.reduce(0.0) { acc, mood in
            acc + (moodWeights[mood] ?? 0.0)
        }

        // Normalize against typical tag counts so scores fall naturally in [0, 1]
        let scaledGenre = min(1.0, genreScore * 1.45)
        let scaledMood = min(1.0, moodScore * 1.45)
        return min(1.0, max(0.0, 0.65 * scaledGenre + 0.35 * scaledMood))
    }
}

public enum TasteVectorBuilder {
    /// Computes an on-device TasteVector from local watch history JSON.
    public static func compute(from history: [WatchHistoryEntry]) -> TasteVector {
        var genres: [String: Double] = [:]
        var moods: [String: Double] = [:]

        for entry in history {
            let weight = max(0.1, entry.completionRatio) * (entry.liked ? 1.5 : 0.7)
            for genre in entry.genres {
                genres[genre.lowercased(), default: 0.0] += weight
            }
            for mood in entry.moodTags {
                moods[mood.lowercased(), default: 0.0] += weight
            }
        }

        return TasteVector(genreWeights: genres, moodWeights: moods)
    }
}

public enum PersonaLoader {
    public static func loadBundledPersonas() throws -> [Persona] {
        guard let url = Bundle.module.url(forResource: "personas", withExtension: "json") else {
            throw NSError(domain: "EnsembleCore", code: 102, userInfo: [
                NSLocalizedDescriptionKey: "Missing personas.json in EnsembleCore bundle."
            ])
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Persona].self, from: data)
    }
}
