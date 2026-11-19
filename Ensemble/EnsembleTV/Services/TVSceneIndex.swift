import EnsembleCore
import Foundation
import NaturalLanguage

/// Hybrid scene index on Apple TV:
/// - Parses bundled .srt files into ~30-second windows
/// - Combines lexical BM25 with NLEmbedding.sentenceEmbedding cosine similarity
/// - Fuses rankings using Reciprocal Rank Fusion (RRF, k = 60)
struct TVSceneIndex: Sendable {
    private let cuesByFilmID: [String: [SubtitleCue]]
    private let windows: [SubtitleWindow]
    private let bm25: BM25Index
    private let sentenceVectors: [String: [Double]]

    init(catalogue: [MediaItem]) {
        var loadedCues: [String: [SubtitleCue]] = [:]
        var allWindows: [SubtitleWindow] = []

        for item in catalogue {
            guard let resource = item.subtitleResource,
                  let cues = try? SRTParser.loadBundledSRT(named: resource) else {
                continue
            }
            loadedCues[item.id] = cues
            allWindows.append(contentsOf: SRTParser.buildWindows(cues: cues, filmID: item.id, windowDuration: 30.0))
        }

        self.cuesByFilmID = loadedCues
        self.windows = allWindows
        self.bm25 = BM25Index(windows: allWindows)

        let embedding = NLEmbedding.sentenceEmbedding(for: .english)
        var vectors: [String: [Double]] = [:]
        if let embedding {
            for window in allWindows {
                if let vec = embedding.vector(for: window.text) {
                    vectors[window.id] = vec
                }
            }
        }
        self.sentenceVectors = vectors
    }

    func cues(for filmID: String) -> [SubtitleCue] {
        cuesByFilmID[filmID] ?? []
    }

    func findBestMoment(query: String, preferredFilmID: String? = nil) -> SceneMatch? {
        let bm25Hits = bm25.search(query: query, filmIDFilter: preferredFilmID, limit: 25)

        var semanticHits: [SemanticHit] = []
        if let embedding = NLEmbedding.sentenceEmbedding(for: .english),
           let queryVector = embedding.vector(for: query) {
            let candidates = preferredFilmID == nil
                ? windows
                : windows.filter { $0.filmID == preferredFilmID }

            semanticHits = candidates.compactMap { window in
                guard let vec = sentenceVectors[window.id] else { return nil }
                let sim = Self.cosineSimilarity(queryVector, vec)
                return SemanticHit(window: window, similarity: sim)
            }
            .sorted { $0.similarity > $1.similarity }
            .prefix(25)
            .map { $0 }
        } else {
            // Fallback semantic proxy when running in environments without downloaded NLEmbedding assets
            semanticHits = bm25Hits.map { SemanticHit(window: $0.window, similarity: $0.score) }
        }

        return RRFFusion.fuse(bm25Hits: bm25Hits, semanticHits: semanticHits, k: 60, limit: 1).first
    }

    private static func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0.0 }
        var dot = 0.0
        var magA = 0.0
        var magB = 0.0
        for i in a.indices {
            dot += a[i] * b[i]
            magA += a[i] * a[i]
            magB += b[i] * b[i]
        }
        let denom = sqrt(magA) * sqrt(magB)
        return denom > 0 ? dot / denom : 0.0
    }
}
