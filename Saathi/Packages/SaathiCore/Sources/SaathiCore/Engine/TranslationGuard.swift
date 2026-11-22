import Foundation

public struct PronunciationEntry: Sendable, Codable, Equatable {
    public let term: String
    public let ipa: String
    public let transliteration: String
    public let localScripts: [String: String]

    public init(term: String, ipa: String, transliteration: String, localScripts: [String: String]) {
        self.term = term
        self.ipa = ipa
        self.transliteration = transliteration
        self.localScripts = localScripts
    }
}

public struct PronunciationLexicon: Sendable, Codable, Equatable {
    public let entries: [PronunciationEntry]

    public init(entries: [PronunciationEntry]) {
        self.entries = entries
    }

    public static func load(from url: URL) throws -> PronunciationLexicon {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(PronunciationLexicon.self, from: data)
    }

    public func entry(for term: String) -> PronunciationEntry? {
        entries.first { term.localizedCaseInsensitiveContains($0.term) }
    }

    /// Formats a proper name for captions: preserves original script plus transliteration.
    public func captionDisplay(for originalName: String, language: SaathiLanguage) -> String {
        guard let matched = entry(for: originalName),
              let localScript = matched.localScripts[language.rawValue] else {
            return originalName
        }
        if originalName.contains(localScript) {
            return originalName
        }
        return "\(localScript) (\(matched.transliteration))"
    }
}

/// Guards proper names, numbers, and dates across English -> Target Language translation.
public enum TranslationGuard {
    public struct ProtectedContext: Sendable, Equatable {
        public let tokenizedText: String
        public let placeholders: [String: String]
        public let expectedNumbersAndDates: [String]
    }

    public static func protect(
        text: String,
        properNames: [String]
    ) -> ProtectedContext {
        var working = text
        var placeholders: [String: String] = [:]

        // 1. Protect proper names first (longest first to avoid partial overlap)
        let sortedNames = properNames.sorted { $0.count > $1.count }
        for (idx, name) in sortedNames.enumerated() where !name.isEmpty {
            let token = "__SAATHI_NAME_\(idx)__"
            if working.contains(name) {
                working = working.replacingOccurrences(of: name, with: token)
                placeholders[token] = name
            }
        }

        // 2. Record all ASCII numbers/years/dates to verify invariance post-translation
        let expectedNumbers = extractNumbersAndYears(from: text)

        return ProtectedContext(
            tokenizedText: working,
            placeholders: placeholders,
            expectedNumbersAndDates: expectedNumbers
        )
    }

    public static func restore(
        translatedText: String,
        context: ProtectedContext,
        lexicon: PronunciationLexicon? = nil,
        targetLanguage: SaathiLanguage = .englishIndia
    ) -> String {
        var restored = translatedText
        for (token, originalName) in context.placeholders {
            let display = lexicon?.captionDisplay(for: originalName, language: targetLanguage) ?? originalName
            restored = restored.replacingOccurrences(of: token, with: display)
        }

        // Verify numbers/years survived; if translation altered or dropped a year/number, append verified values.
        let normalizedASCII = convertIndicDigitsToASCII(restored)
        var missingNumbers: [String] = []
        for number in context.expectedNumbersAndDates where !normalizedASCII.contains(number) {
            missingNumbers.append(number)
        }
        if !missingNumbers.isEmpty {
            restored += " [\(missingNumbers.joined(separator: ", "))]"
        }
        return restored
    }

    public static func extractNumbersAndYears(from text: String) -> [String] {
        let pattern = #"\b\d+(?:[.,/:-]\d+)*\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }

    public static func convertIndicDigitsToASCII(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            // Normalize Devanagari, Bengali, Gurmukhi, Gujarati, Oriya, Tamil, Telugu, Kannada, Malayalam, Arabic-Indic digits
            if let digit = normalizedDigit(scalar) {
                scalars.append(UnicodeScalar(48 + digit)!)
            } else {
                scalars.append(scalar)
            }
        }
        return String(scalars)
    }

    private static func normalizedDigit(_ scalar: UnicodeScalar) -> Int? {
        let v = scalar.value
        let ranges: [ClosedRange<UInt32>] = [
            0x0966...0x096F, // Devanagari
            0x09E6...0x09EF, // Bengali
            0x0A66...0x0A6F, // Gurmukhi
            0x0AE6...0x0AEF, // Gujarati
            0x0B66...0x0B6F, // Odia
            0x0BE6...0x0BEF, // Tamil
            0x0C66...0x0C6F, // Telugu
            0x0CE6...0x0CEF, // Kannada
            0x0D66...0x0D6F, // Malayalam
            0x0660...0x0669, // Arabic-Indic
            0x06F0...0x06F9  // Extended Arabic-Indic (Urdu)
        ]
        for r in ranges where r.contains(v) {
            return Int(v - r.lowerBound)
        }
        return nil
    }
}
