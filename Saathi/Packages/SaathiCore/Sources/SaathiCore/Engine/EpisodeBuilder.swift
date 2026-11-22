import Foundation

public struct EpisodeStop: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let placeName: String
    public let visitedAt: Date
    public let summary: String
    public let citations: [FactCitation]

    public init(
        id: UUID = UUID(),
        placeName: String,
        visitedAt: Date,
        summary: String,
        citations: [FactCitation]
    ) {
        self.id = id
        self.placeName = placeName
        self.visitedAt = visitedAt
        self.summary = summary
        self.citations = citations
    }
}

public struct MemoryEpisode: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let createdAt: Date
    public let languageCode: String
    public let secondaryLanguageCode: String?
    public let script: String
    public let secondaryScript: String?
    public let stops: [EpisodeStop]
    public let personalMomentDescriptions: [String]
    /// PhotoKit asset local identifiers only — never file copies and never GPS metadata.
    public let linkedPhotoLocalIdentifiers: [String]
    public let closingReflection: String
    public let estimatedDurationSeconds: Int
    /// Walk totals (distance, duration, steps). Never a route.
    public let walkSummary: WalkSummary?

    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        languageCode: String,
        secondaryLanguageCode: String? = nil,
        script: String,
        secondaryScript: String? = nil,
        stops: [EpisodeStop],
        personalMomentDescriptions: [String],
        linkedPhotoLocalIdentifiers: [String],
        closingReflection: String,
        estimatedDurationSeconds: Int,
        walkSummary: WalkSummary? = nil
    ) {
        self.walkSummary = walkSummary
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.languageCode = languageCode
        self.secondaryLanguageCode = secondaryLanguageCode
        self.script = script
        self.secondaryScript = secondaryScript
        self.stops = stops
        self.personalMomentDescriptions = personalMomentDescriptions
        self.linkedPhotoLocalIdentifiers = linkedPhotoLocalIdentifiers
        self.closingReflection = closingReflection
        self.estimatedDurationSeconds = estimatedDurationSeconds
    }
}

public enum EpisodeDecision: String, Sendable, Codable {
    case keepOnDevice
    case saveToICloud
    case discard
}

/// Builds a 3-5 minute Memory Episode containing strictly ZERO coordinates.
public enum EpisodeBuilder {
    public static func build(
        segments: [NarrationSegment],
        referencedMemories: [PersonalMemoryItem],
        language: SaathiLanguage,
        secondaryLanguage: SaathiLanguage? = nil,
        sessionDate: Date = Date(),
        walkSummary: WalkSummary? = nil
    ) -> MemoryEpisode {
        let orderedSegments = segments.sorted { $0.timestamp < $1.timestamp }

        var seenPlaces = Set<String>()
        var stops: [EpisodeStop] = []
        for seg in orderedSegments {
            if !seenPlaces.contains(seg.placeID) {
                seenPlaces.insert(seg.placeID)
                stops.append(
                    EpisodeStop(
                        // Scrub every persisted text field, not just the final script:
                        // model output may echo coordinates.
                        placeName: sanitizeCoordinates(from: seg.placeTitle),
                        visitedAt: seg.timestamp,
                        summary: sanitizeCoordinates(from: seg.spokenText),
                        citations: seg.citations
                    )
                )
            }
        }

        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let startDate = walkSummary?.startedAt ?? sessionDate
        var intro = "Welcome back to your Saathi walk from \(formatter.string(from: startDate)). Today you explored \(stops.count) historic stop\(stops.count == 1 ? "" : "s")."
        if let walkSummary {
            intro += " " + walkSummary.spokenSummary()
        }

        var bodySections: [String] = [intro]
        for (index, stop) in stops.enumerated() {
            let timeText = formatter.string(from: stop.visitedAt)
            bodySections.append("Stop \(index + 1): \(stop.placeName) at \(timeText). \(stop.summary)")
        }

        let momentTexts = referencedMemories.map { "\($0.title): \($0.detail)" }
        if !momentTexts.isEmpty {
            bodySections.append("Personal moments along the way: " + momentTexts.joined(separator: " "))
        }

        let closing = "Wherever you walk next, these quiet stones keep their stories ready for you. Take a breath, and carry today's curiosity forward."
        bodySections.append(closing)

        let fullScript = sanitizeCoordinates(from: bodySections.joined(separator: "\n\n"))
        let photoIDs = Array(Set(referencedMemories.compactMap(\.photoLocalIdentifier)))

        // Estimate ~130 spoken words per minute; target 180-300s bounds for player display
        let wordCount = fullScript.split(whereSeparator: \.isWhitespace).count
        let rawSeconds = max(180, min(300, Int(Double(wordCount) / 2.2)))

        let titlePlace = stops.first?.placeName ?? "Historic Walk"
        return MemoryEpisode(
            title: "\(titlePlace) Memory Episode",
            createdAt: sessionDate,
            languageCode: language.rawValue,
            secondaryLanguageCode: secondaryLanguage?.rawValue,
            script: fullScript,
            secondaryScript: nil,
            stops: stops,
            personalMomentDescriptions: momentTexts.map { sanitizeCoordinates(from: $0) },
            linkedPhotoLocalIdentifiers: photoIDs,
            closingReflection: closing,
            estimatedDurationSeconds: rawSeconds,
            walkSummary: walkSummary
        )
    }

    /// Defense-in-depth scrubbing to guarantee zero lat/lon substrings enter the episode.
    public static func sanitizeCoordinates(from text: String) -> String {
        let pattern = #"-?\d{1,3}\.\d{3,}\s*[,°]\s*-?\d{1,3}\.\d{3,}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "[location omitted]")
    }
}
