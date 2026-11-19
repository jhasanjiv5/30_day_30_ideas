import Foundation

public struct SubtitleCue: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: Int
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let text: String

    public init(id: Int, startTime: TimeInterval, endTime: TimeInterval, text: String) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
}

public struct SubtitleWindow: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public let filmID: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let text: String

    public init(
        id: String,
        filmID: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String
    ) {
        self.id = id
        self.filmID = filmID
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
}

public enum SRTParser {
    /// Parses standard SubRip (.srt) text into timestamped `SubtitleCue` values.
    public static func parse(_ rawSRT: String) -> [SubtitleCue] {
        let normalized = rawSRT
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let blocks = normalized.components(separatedBy: "\n\n")
        var cues: [SubtitleCue] = []
        var fallbackIndex = 1

        for block in blocks {
            let lines = block
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map { String($0).trimmingCharacters(in: .whitespaces) }

            guard !lines.isEmpty else { continue }

            var timeLineIndex = 0
            var cueIndex = fallbackIndex
            if let parsedIndex = Int(lines[0]), lines.count >= 2, lines[1].contains("-->") {
                cueIndex = parsedIndex
                timeLineIndex = 1
            } else if !lines[0].contains("-->") {
                continue
            }

            guard timeLineIndex < lines.count else { continue }
            let timeParts = lines[timeLineIndex].components(separatedBy: "-->")
            guard timeParts.count == 2,
                  let start = parseTimestamp(timeParts[0]),
                  let end = parseTimestamp(timeParts[1]) else {
                continue
            }

            let textLines = lines.dropFirst(timeLineIndex + 1)
            let cleanedText = textLines
                .joined(separator: " ")
                .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !cleanedText.isEmpty else { continue }
            cues.append(SubtitleCue(id: cueIndex, startTime: start, endTime: end, text: cleanedText))
            fallbackIndex += 1
        }

        return cues.sorted { $0.startTime < $1.startTime }
    }

    /// Parses `HH:MM:SS,mmm` or `HH:MM:SS.mmm` into seconds.
    public static func parseTimestamp(_ raw: String) -> TimeInterval? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        let components = trimmed.split(separator: ":")
        guard components.count == 3,
              let hours = Double(components[0]),
              let minutes = Double(components[1]),
              let seconds = Double(components[2]) else {
            return nil
        }
        return hours * 3600.0 + minutes * 60.0 + seconds
    }

    /// Groups cues into ~30-second sliding/bucketed windows for hybrid scene search.
    public static func buildWindows(
        cues: [SubtitleCue],
        filmID: String,
        windowDuration: TimeInterval = 30.0
    ) -> [SubtitleWindow] {
        guard !cues.isEmpty else { return [] }
        var windows: [SubtitleWindow] = []
        var bucketCues: [SubtitleCue] = []
        var bucketStart = cues[0].startTime

        for cue in cues {
            if !bucketCues.isEmpty && (cue.startTime - bucketStart) >= windowDuration {
                let text = bucketCues.map(\.text).joined(separator: " ")
                let end = bucketCues.last?.endTime ?? (bucketStart + windowDuration)
                windows.append(
                    SubtitleWindow(
                        id: "\(filmID)-\(Int(bucketStart))",
                        filmID: filmID,
                        startTime: bucketStart,
                        endTime: end,
                        text: text
                    )
                )
                bucketCues = [cue]
                bucketStart = cue.startTime
            } else {
                bucketCues.append(cue)
            }
        }

        if !bucketCues.isEmpty {
            let text = bucketCues.map(\.text).joined(separator: " ")
            let end = bucketCues.last?.endTime ?? (bucketStart + windowDuration)
            windows.append(
                SubtitleWindow(
                    id: "\(filmID)-\(Int(bucketStart))",
                    filmID: filmID,
                    startTime: bucketStart,
                    endTime: end,
                    text: text
                )
            )
        }

        return windows
    }

    public static func loadBundledSRT(named resourceName: String) throws -> [SubtitleCue] {
        let candidates = [
            Bundle.module.url(forResource: resourceName, withExtension: "srt", subdirectory: "Subtitles"),
            Bundle.module.url(forResource: resourceName, withExtension: "srt")
        ]
        guard let url = candidates.compactMap({ $0 }).first else {
            throw NSError(domain: "EnsembleCore", code: 103, userInfo: [
                NSLocalizedDescriptionKey: "Missing subtitle resource \(resourceName).srt"
            ])
        }
        let raw = try String(contentsOf: url, encoding: .utf8)
        return parse(raw)
    }
}

public enum RecapWindowExtractor {
    /// Strict spoiler-free cutoff: returns ONLY cues completely spoken at or before `currentTime`.
    /// Any cue with `endTime > currentTime` (or `startTime > currentTime`) is excluded.
    public static func cuesUpTo(currentTime: TimeInterval, from cues: [SubtitleCue]) -> [SubtitleCue] {
        let clamped = max(0.0, currentTime)
        return cues.filter { $0.endTime <= clamped }
    }

    public static func transcriptUpTo(currentTime: TimeInterval, from cues: [SubtitleCue]) -> String {
        cuesUpTo(currentTime: currentTime, from: cues)
            .map(\.text)
            .joined(separator: "\n")
    }
}
