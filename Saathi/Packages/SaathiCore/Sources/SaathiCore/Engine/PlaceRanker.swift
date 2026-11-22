import Foundation

public struct RankerWeights: Sendable, Codable, Equatable {
    public let distanceWeight: Double
    public let notabilityWeight: Double
    public let interestWeight: Double
    public let noveltyWeight: Double
    public let dwellBoostWeight: Double

    public static let `default` = RankerWeights(
        distanceWeight: 0.30,
        notabilityWeight: 0.25,
        interestWeight: 0.20,
        noveltyWeight: 0.15,
        dwellBoostWeight: 0.10
    )

    public init(
        distanceWeight: Double,
        notabilityWeight: Double,
        interestWeight: Double,
        noveltyWeight: Double,
        dwellBoostWeight: Double
    ) {
        self.distanceWeight = distanceWeight
        self.notabilityWeight = notabilityWeight
        self.interestWeight = interestWeight
        self.noveltyWeight = noveltyWeight
        self.dwellBoostWeight = dwellBoostWeight
    }
}

public struct SessionInterestProfile: Sendable, Equatable {
    public private(set) var tagAffinity: [String: Double] = [:]
    public private(set) var toldPlaceIDs: Set<String> = []
    public private(set) var skippedPlaceIDs: Set<String> = []

    public init() {}

    public mutating func recordAskedAbout(tags: [String]) {
        for tag in tags {
            let key = tag.lowercased()
            tagAffinity[key] = min(1.0, (tagAffinity[key] ?? 0.3) + 0.35)
        }
    }

    public mutating func recordTold(placeID: String, tags: [String]) {
        toldPlaceIDs.insert(placeID)
        for tag in tags {
            let key = tag.lowercased()
            tagAffinity[key] = min(1.0, (tagAffinity[key] ?? 0.2) + 0.10)
        }
    }

    public mutating func recordSkipped(placeID: String, tags: [String]) {
        skippedPlaceIDs.insert(placeID)
        for tag in tags {
            let key = tag.lowercased()
            tagAffinity[key] = max(-0.5, (tagAffinity[key] ?? 0.0) - 0.30)
        }
    }
}

public struct RankedPlace: Sendable, Equatable {
    public let place: PlaceCandidate
    public let distanceMeters: Double
    public let score: Double
    public let breakdown: ScoreBreakdown

    public struct ScoreBreakdown: Sendable, Equatable {
        public let distanceComponent: Double
        public let notabilityComponent: Double
        public let interestComponent: Double
        public let noveltyComponent: Double
        public let dwellComponent: Double
    }
}

/// Pure Swift ranker:
/// score = distance decay + notability (sitelinks) + session interest + novelty + dwell boost (>45s)
public enum PlaceRanker {
    public static let defaultMaxRadiusMeters: Double = 300.0
    public static let defaultDwellThresholdSeconds: TimeInterval = 45.0

    public static func rank(
        candidates: [PlaceCandidate],
        userCoordinate: EphemeralCoordinate,
        interestProfile: SessionInterestProfile,
        dwellDurationSeconds: TimeInterval,
        maxRadiusMeters: Double = defaultMaxRadiusMeters,
        dwellThresholdSeconds: TimeInterval = defaultDwellThresholdSeconds,
        weights: RankerWeights = .default
    ) -> [RankedPlace] {
        candidates.compactMap { place in
            let distance = userCoordinate.distanceMeters(to: place.coordinate)
            guard distance <= maxRadiusMeters else { return nil }

            // 1. Distance decay [0, 1]
            let distanceNormalized = max(0.0, 1.0 - (distance / maxRadiusMeters))

            // 2. Notability via Wikidata sitelinks (log-scaled, saturating around 100 sitelinks)
            let sitelinkScore = min(1.0, log10(Double(max(1, place.sitelinksCount)) + 1.0) / 2.0)

            // 3. Session interest (mean tag affinity, neutral 0.5 baseline)
            let tagScores = place.tags.compactMap { interestProfile.tagAffinity[$0.lowercased()] }
            let interestNormalized: Double
            if tagScores.isEmpty {
                interestNormalized = 0.5
            } else {
                let avg = tagScores.reduce(0.0, +) / Double(tagScores.count)
                interestNormalized = max(0.0, min(1.0, 0.5 + avg))
            }

            // 4. Novelty (1.0 if not yet told, 0.05 if already told, 0.0 if skipped)
            let noveltyNormalized: Double
            if interestProfile.skippedPlaceIDs.contains(place.id) {
                noveltyNormalized = 0.0
            } else if interestProfile.toldPlaceIDs.contains(place.id) {
                noveltyNormalized = 0.05
            } else {
                noveltyNormalized = 1.0
            }

            // 5. Dwell boost (1.0 if user paused > 45s near the stop, else 0.0)
            let dwellNormalized = (dwellDurationSeconds > dwellThresholdSeconds && distance <= 80.0) ? 1.0 : 0.0

            let distPart = distanceNormalized * weights.distanceWeight
            let notePart = sitelinkScore * weights.notabilityWeight
            let intPart = interestNormalized * weights.interestWeight
            let novPart = noveltyNormalized * weights.noveltyWeight
            let dwellPart = dwellNormalized * weights.dwellBoostWeight

            let total = distPart + notePart + intPart + novPart + dwellPart

            return RankedPlace(
                place: place,
                distanceMeters: distance,
                score: total,
                breakdown: RankedPlace.ScoreBreakdown(
                    distanceComponent: distPart,
                    notabilityComponent: notePart,
                    interestComponent: intPart,
                    noveltyComponent: novPart,
                    dwellComponent: dwellPart
                )
            )
        }
        .sorted { $0.score > $1.score }
    }
}
