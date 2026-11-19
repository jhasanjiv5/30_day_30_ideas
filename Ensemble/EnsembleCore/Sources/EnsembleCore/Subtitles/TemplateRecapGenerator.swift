import Foundation

public struct TemplateRecapResult: Sendable, Equatable {
    public let summary: String
    public let keyCharacters: [String]
}

/// Deterministic fallback recap generator used whenever Apple Intelligence (`FoundationModels`)
/// is unavailable (e.g., unsupported hardware, disabled in Settings, or model downloading).
/// Guarantees <= 60 words and strictly uses only subtitles from `0...currentTime`.
public enum TemplateRecapGenerator {
    private static let knownCharactersByFilm: [String: [String]] = [
        "sintel": ["Sintel", "Scales", "Shaman", "Gatekeeper"],
        "big-buck-bunny": ["Buck", "Frank", "Rinky", "Gamera", "Butterfly"],
        "tears-of-steel": ["Thom", "Celia", "Barley", "Tech Head"],
        "elephants-dream": ["Proog", "Emo"]
    ]

    public static func generate(
        filmID: String,
        filmTitle: String,
        currentTimeSeconds: TimeInterval,
        cues: [SubtitleCue]
    ) -> TemplateRecapResult {
        let safeCues = RecapWindowExtractor.cuesUpTo(currentTime: currentTimeSeconds, from: cues)
        let joined = safeCues.map(\.text).joined(separator: " ")

        let minutes = Int(currentTimeSeconds) / 60
        let seconds = Int(currentTimeSeconds) % 60
        let timestampLabel = String(format: "%d:%02d", minutes, seconds)

        let characters = extractCharacters(filmID: filmID, from: joined)

        guard !safeCues.isEmpty else {
            return TemplateRecapResult(
                summary: "Just starting \(filmTitle) at \(timestampLabel). No dialogue has occurred yet, so you have not missed any story beats.",
                keyCharacters: characters
            )
        }

        // Pick opening cue and most recent safe cue before currentTime
        let firstBeat = cleanSnippet(safeCues.first?.text ?? "")
        let latestBeat = cleanSnippet(safeCues.last?.text ?? "")

        let characterNote = characters.isEmpty
            ? ""
            : " Featuring \(characters.prefix(3).joined(separator: ", "))."

        let rawSummary: String
        if safeCues.count == 1 || firstBeat == latestBeat {
            rawSummary = "So far in \(filmTitle) (up to \(timestampLabel)): \(firstBeat).\(characterNote)"
        } else {
            rawSummary = "So far in \(filmTitle) (up to \(timestampLabel)): began with \"\(firstBeat)\" and just reached \"\(latestBeat)\".\(characterNote)"
        }

        return TemplateRecapResult(
            summary: clampToWordLimit(rawSummary, maxWords: 60),
            keyCharacters: characters
        )
    }

    public static func clampToWordLimit(_ text: String, maxWords: Int = 60) -> String {
        let words = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard words.count > maxWords else { return text }
        return words.prefix(maxWords).joined(separator: " ") + "…"
    }

    private static func extractCharacters(filmID: String, from transcript: String) -> [String] {
        let lower = transcript.lowercased()
        if let candidates = knownCharactersByFilm[filmID] {
            let matched = candidates.filter { lower.contains($0.lowercased()) }
            if !matched.isEmpty {
                return Array(matched.prefix(4))
            }
        }
        // Fallback capitalized name extraction from safe transcript only
        let tokens = transcript.split(whereSeparator: { !$0.isLetter }).map(String.init)
        let ignored: Set<String> = ["The", "A", "An", "You", "I", "We", "It", "My", "This", "That", "What", "Where"]
        var seen: [String] = []
        for token in tokens where token.first?.isUppercase == true && token.count > 2 && !ignored.contains(token) {
            if !seen.contains(token) {
                seen.append(token)
            }
            if seen.count >= 3 { break }
        }
        return seen
    }

    private static func cleanSnippet(_ text: String) -> String {
        let stripped = text
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let words = stripped.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if words.count <= 12 {
            return stripped
        }
        return words.prefix(12).joined(separator: " ") + "…"
    }
}
