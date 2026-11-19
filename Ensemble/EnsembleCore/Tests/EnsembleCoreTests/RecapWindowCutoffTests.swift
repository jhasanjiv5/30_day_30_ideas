import Foundation
import Testing
@testable import EnsembleCore

@Suite("Recap Window Cutoff & Template Fallback Tests")
struct RecapWindowCutoffTests {

    @Test("Phone joining at t=5 min only receives subtitles before 5 min (zero spoilers)")
    func testRecapCutoffAtFiveMinutes() throws {
        let cues = try SRTParser.loadBundledSRT(named: "Sintel")
        let joinTime: TimeInterval = 300.0 // 5 minutes

        let safeCues = RecapWindowExtractor.cuesUpTo(currentTime: joinTime, from: cues)
        let transcript = RecapWindowExtractor.transcriptUpTo(currentTime: joinTime, from: cues)

        // Must include early cues before 300s
        #expect(!safeCues.isEmpty)
        #expect(safeCues.allSatisfy { $0.endTime <= joinTime })

        // Verify post-5-minute spoiler text is completely absent
        let futureCues = cues.filter { $0.endTime > joinTime }
        #expect(!futureCues.isEmpty)
        #expect(!transcript.contains("giant dragon was Scales all along"))
        #expect(!transcript.contains("obsidian pillars"))
        #expect(!transcript.contains("shadow dragon dives"))
    }

    @Test("Template recap fallback succeeds without Apple Intelligence within <=60 words")
    func testTemplateFallbackRecap() throws {
        let cues = try SRTParser.loadBundledSRT(named: "Sintel")
        let result = TemplateRecapGenerator.generate(
            filmID: "sintel",
            filmTitle: "Sintel",
            currentTimeSeconds: 300.0,
            cues: cues
        )

        let wordCount = result.summary.split(whereSeparator: { $0.isWhitespace }).count
        #expect(wordCount > 5 && wordCount <= 60)
        #expect(result.keyCharacters.contains("Sintel"))
        #expect(!result.summary.contains("all along"))
    }
}
