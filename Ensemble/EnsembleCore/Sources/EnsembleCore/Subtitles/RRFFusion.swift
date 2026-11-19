import Foundation

public struct SemanticHit: Sendable, Equatable {
    public let window: SubtitleWindow
    public let similarity: Double

    public init(window: SubtitleWindow, similarity: Double) {
        self.window = window
        self.similarity = similarity
    }
}

public struct SceneMatch: Sendable, Equatable {
    public let filmID: String
    public let timestampSeconds: TimeInterval
    public let window: SubtitleWindow
    public let rrfScore: Double

    public init(filmID: String, timestampSeconds: TimeInterval, window: SubtitleWindow, rrfScore: Double) {
        self.filmID = filmID
        self.timestampSeconds = timestampSeconds
        self.window = window
        self.rrfScore = rrfScore
    }
}

/// Reciprocal Rank Fusion (RRF, k = 60) combining lexical BM25 and NLEmbedding semantic rankings.
public enum RRFFusion {
    public static func fuse(
        bm25Hits: [BM25Hit],
        semanticHits: [SemanticHit],
        k: Int = 60,
        limit: Int = 5
    ) -> [SceneMatch] {
        var scoresByWindowID: [String: Double] = [:]
        var windowByID: [String: SubtitleWindow] = [:]

        for (index, hit) in bm25Hits.enumerated() {
            let rank = index + 1
            let contribution = 1.0 / Double(k + rank)
            scoresByWindowID[hit.window.id, default: 0.0] += contribution
            windowByID[hit.window.id] = hit.window
        }

        for (index, hit) in semanticHits.enumerated() {
            let rank = index + 1
            let contribution = 1.0 / Double(k + rank)
            scoresByWindowID[hit.window.id, default: 0.0] += contribution
            windowByID[hit.window.id] = hit.window
        }

        let sorted = scoresByWindowID.sorted { lhs, rhs in
            if abs(lhs.value - rhs.value) > 1e-9 {
                return lhs.value > rhs.value
            }
            return lhs.key < rhs.key
        }

        return sorted.prefix(limit).compactMap { entry in
            guard let window = windowByID[entry.key] else { return nil }
            return SceneMatch(
                filmID: window.filmID,
                timestampSeconds: window.startTime,
                window: window,
                rrfScore: entry.value
            )
        }
    }
}
