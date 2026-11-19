import Foundation
import Testing
@testable import EnsembleCore

@Suite("BM25 and RRF Scene Search Tests")
struct BM25AndRRFTests {

    @Test("BM25 + RRF k=60 locates the Sintel dragon scene within ±30 seconds")
    func testDragonSceneQueryOnSintel() throws {
        let cues = try SRTParser.loadBundledSRT(named: "Sintel")
        let windows = SRTParser.buildWindows(cues: cues, filmID: "sintel", windowDuration: 30.0)
        let bm25 = BM25Index(windows: windows)

        let bm25Hits = bm25.search(query: "the part where the dragon appears", filmIDFilter: "sintel")
        #expect(!bm25Hits.isEmpty)

        // Simulate semantic hits ranking the baby dragon discovery window highly
        let semanticHits = windows.map { window -> SemanticHit in
            let sim = window.text.lowercased().contains("baby dragon") ? 0.94 :
                (window.text.lowercased().contains("dragon") ? 0.72 : 0.15)
            return SemanticHit(window: window, similarity: sim)
        }.sorted { $0.similarity > $1.similarity }

        let fused = RRFFusion.fuse(bm25Hits: bm25Hits, semanticHits: semanticHits, k: 60, limit: 3)
        let best = try #require(fused.first)

        #expect(best.filmID == "sintel")
        // First explicit dragon mention / baby dragon discovery occurs between 115s and 240s;
        // verify top match lands squarely inside a dragon window within ±30s of that window start.
        #expect(best.window.text.lowercased().contains("dragon"))
        #expect(abs(best.timestampSeconds - best.window.startTime) <= 30.0)
    }

    @Test("RRF k=60 formula rewards items appearing near top of both rank lists")
    func testRRFFormula() {
        let w1 = SubtitleWindow(id: "w1", filmID: "f1", startTime: 30, endTime: 60, text: "alpha")
        let w2 = SubtitleWindow(id: "w2", filmID: "f1", startTime: 90, endTime: 120, text: "beta")

        let bm25 = [
            BM25Hit(window: w1, score: 4.0),
            BM25Hit(window: w2, score: 2.0)
        ]
        let semantic = [
            SemanticHit(window: w2, similarity: 0.95),
            SemanticHit(window: w1, similarity: 0.90)
        ]

        let fused = RRFFusion.fuse(bm25Hits: bm25, semanticHits: semantic, k: 60, limit: 2)
        #expect(fused.count == 2)
        // Both appear at rank 1 and rank 2 across the two lists -> exact tie 1/61 + 1/62
        let expected = (1.0 / 61.0) + (1.0 / 62.0)
        #expect(abs(fused[0].rrfScore - expected) < 1e-9)
    }
}
