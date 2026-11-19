import Foundation

public struct RankedMediaItem: Sendable, Identifiable, Equatable {
    public let item: MediaItem
    public let score: Double
    public let meanAffinity: Double
    public let minAffinity: Double
    public let bestSuitedParticipant: RoomParticipant?
    public let whyCaption: String

    public var id: String { item.id }

    public init(
        item: MediaItem,
        score: Double,
        meanAffinity: Double,
        minAffinity: Double,
        bestSuitedParticipant: RoomParticipant?,
        whyCaption: String
    ) {
        self.item = item
        self.score = score
        self.meanAffinity = meanAffinity
        self.minAffinity = minAffinity
        self.bestSuitedParticipant = bestSuitedParticipant
        self.whyCaption = whyCaption
    }
}

public struct QueryIntent: Sendable, Equatable {
    public let rawQuery: String
    public let maxRuntimeMinutes: Int?
    public let isSceneQuery: Bool
    public let searchTerms: String

    public init(rawQuery: String, maxRuntimeMinutes: Int?, isSceneQuery: Bool, searchTerms: String) {
        self.rawQuery = rawQuery
        self.maxRuntimeMinutes = maxRuntimeMinutes
        self.isSceneQuery = isSceneQuery
        self.searchTerms = searchTerms
    }
}

public enum NaturalQueryParser {
    /// Parses queries like "something for all of us under 40 min" or "the part where the dragon appears".
    public static func parse(_ query: String) -> QueryIntent {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        // Extract time budget ("under 40 min", "< 30 minutes", "40m or less")
        var budget: Int?
        let pattern = #"(?:under|less than|within|max|<=|<|about)\s*(\d{1,3})\s*(?:min|mins|minutes|m)\b"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           let range = Range(match.range(at: 1), in: lower) {
            budget = Int(lower[range])
        }

        let sceneMarkers = [
            "the part where", "scene where", "moment when", "moment where",
            "when the", "where the", "jump to", "find the", "dragon", "butterfly",
            "lab", "memory", "catwalk", "bridge", "machine"
        ]
        let isRecommendationRequest = budget != nil
            || lower.contains("for all of us")
            || lower.contains("something to watch")
            || lower.contains("recommend")

        let looksLikeScene = !isRecommendationRequest || sceneMarkers.contains(where: { lower.contains($0) })

        return QueryIntent(
            rawQuery: trimmed,
            maxRuntimeMinutes: budget,
            isSceneQuery: looksLikeScene && budget == nil,
            searchTerms: trimmed
        )
    }
}

public struct GroupRanker: Sendable {
    public let meanWeight: Double
    public let minWeight: Double
    public let limit: Int

    public init(meanWeight: Double = 0.6, minWeight: Double = 0.4, limit: Int = 10) {
        self.meanWeight = meanWeight
        self.minWeight = minWeight
        self.limit = limit
    }

    /// Ranks catalogue items for the active room participants using:
    /// score = 0.6 * mean(userAffinity) + 0.4 * min(userAffinity)
    /// Applies hard filters for youngest participant age rating, optional time budget,
    /// and optionally restricts to media playable on apps installed on the TV.
    public func rank(
        catalogue: [MediaItem],
        participants: [RoomParticipant],
        maxRuntimeMinutes: Int? = nil,
        moodBoostQuery: String? = nil,
        installedAppIDs: Set<StreamingAppID>? = nil
    ) -> [RankedMediaItem] {
        let maxRating = AgeRating.maxAllowed(for: participants)
        let queryTokens = Set(
            (moodBoostQuery ?? "")
                .lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
        )

        let filtered = catalogue.filter { item in
            guard item.ageRating <= maxRating else { return false }
            if let budget = maxRuntimeMinutes, item.runtimeMinutes > budget {
                return false
            }
            if let installedAppIDs, !installedAppIDs.isEmpty {
                let playableInApp = item.isPlayableInApp && installedAppIDs.contains(.ensemble)
                let hasInstalledProvider = item.providers.contains(where: { installedAppIDs.contains($0.appID) })
                guard playableInApp || hasInstalledProvider else { return false }
            }
            return true
        }

        if participants.isEmpty {
            return filtered.prefix(limit).map { item in
                let playableBonus = item.isPlayable ? 0.15 : 0.0
                return RankedMediaItem(
                    item: item,
                    score: 0.5 + playableBonus,
                    meanAffinity: 0.5,
                    minAffinity: 0.5,
                    bestSuitedParticipant: nil,
                    whyCaption: "\(item.genres.prefix(2).joined(separator: " · ")) · \(item.runtimeMinutes) min"
                )
            }
        }

        let ranked: [RankedMediaItem] = filtered.map { item in
            let affinities: [(RoomParticipant, Double)] = participants.map { participant in
                (participant, participant.tasteVector.affinity(for: item))
            }

            let values = affinities.map(\.1)
            let mean = values.reduce(0.0, +) / Double(values.count)
            let minimum = values.min() ?? 0.0

            // Optional light query keyword boost when a non-scene group query mentions mood/genre
            let queryOverlap = queryTokens.isEmpty ? 0.0 : {
                let itemTokens = Set(
                    (item.genres + item.moodTags + [item.title])
                        .flatMap { $0.lowercased().split(whereSeparator: { !$0.isLetter }) }
                        .map(String.init)
                )
                let hits = queryTokens.intersection(itemTokens).count
                return min(0.12, Double(hits) * 0.06)
            }()

            let score = meanWeight * mean + minWeight * minimum + queryOverlap
            let bestPair = affinities.max(by: { $0.1 < $1.1 })
            let why = buildWhyCaption(
                item: item,
                affinities: affinities,
                best: bestPair?.0,
                maxRuntimeMinutes: maxRuntimeMinutes
            )

            return RankedMediaItem(
                item: item,
                score: score,
                meanAffinity: mean,
                minAffinity: minimum,
                bestSuitedParticipant: bestPair?.0,
                whyCaption: why
            )
        }

        return Array(
            ranked
                .sorted { lhs, rhs in
                    if abs(lhs.score - rhs.score) > 0.0001 {
                        return lhs.score > rhs.score
                    }
                    if lhs.item.isPlayable != rhs.item.isPlayable {
                        return lhs.item.isPlayable && !rhs.item.isPlayable
                    }
                    return lhs.item.title < rhs.item.title
                }
                .prefix(limit)
        )
    }

    public static func rowTitle(for participants: [RoomParticipant]) -> String {
        switch participants.count {
        case 0:
            return "Featured Open Cinema"
        case 1:
            return "For \(participants[0].displayName)"
        case 2:
            return "For \(participants[0].displayName) & \(participants[1].displayName)"
        default:
            let head = participants.dropLast().map(\.displayName).joined(separator: ", ")
            return "For \(head) & \(participants.last!.displayName)"
        }
    }

    private func buildWhyCaption(
        item: MediaItem,
        affinities: [(RoomParticipant, Double)],
        best: RoomParticipant?,
        maxRuntimeMinutes: Int?
    ) -> String {
        guard let best else {
            return "\(item.genres.first ?? "Feature") · \(item.runtimeMinutes) min"
        }

        let matchedGenres = item.genres.filter { genre in
            (best.tasteVector.genreWeights[genre.lowercased()] ?? 0) > 0.12
        }
        let matchedMood = item.moodTags.first { mood in
            (best.tasteVector.moodWeights[mood.lowercased()] ?? 0) > 0.12
        }

        let hook = matchedGenres.first ?? matchedMood ?? item.genres.first ?? "storytelling"
        let everyoneHappy = (affinities.map(\.1).min() ?? 0) >= 0.30

        if let budget = maxRuntimeMinutes {
            return "Best for \(best.displayName)'s \(hook.lowercased()) taste · fits under \(budget)m"
        }
        if affinities.count > 1 && everyoneHappy {
            return "Top pick for \(best.displayName) (\(hook.lowercased())) & fits the room"
        }
        return "Most suits \(best.displayName)'s \(hook.lowercased()) taste"
    }
}
