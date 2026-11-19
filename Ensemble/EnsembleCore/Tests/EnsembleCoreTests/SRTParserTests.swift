import Foundation
import Testing
@testable import EnsembleCore

@Suite("SRTParser Tests")
struct SRTParserTests {

    @Test("Parses multiline SRT blocks and strips HTML tags")
    func testParseSRT() {
        let sample = """
        1
        00:00:05,500 --> 00:00:12,250
        <i>Sintel</i> climbs the snowy ridge.

        2
        00:00:36,000 --> 00:00:44,000
        She discovers a baby dragon named Scales.
        """

        let cues = SRTParser.parse(sample)
        #expect(cues.count == 2)
        #expect(cues[0].id == 1)
        #expect(abs(cues[0].startTime - 5.5) < 0.001)
        #expect(abs(cues[0].endTime - 12.25) < 0.001)
        #expect(cues[0].text == "Sintel climbs the snowy ridge.")
        #expect(cues[1].text == "She discovers a baby dragon named Scales.")
    }

    @Test("Builds ~30-second windows from bundled Sintel subtitles")
    func testBuildWindowsFromBundledSintel() throws {
        let cues = try SRTParser.loadBundledSRT(named: "Sintel")
        #expect(cues.count >= 12)

        let windows = SRTParser.buildWindows(cues: cues, filmID: "sintel", windowDuration: 30.0)
        #expect(windows.count >= 10)
        #expect(windows.allSatisfy { $0.filmID == "sintel" && !$0.text.isEmpty })
    }
}
