import Foundation

public enum SaathiVoiceCommand: Sendable, Equatable {
    case tellMeMore
    case skip
    case quiet(minutes: Int)
    case whatDidIPhotographHere
    case whereIsIt
    case endSession
    case resumeNarration
    case freeQuestion(String)
}

public enum VoiceCommandGrammar {
    public static func parse(_ transcript: String, language: SaathiLanguage) -> SaathiVoiceCommand {
        let normalized = transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalized.isEmpty else {
            return .freeQuestion("")
        }

        // Check target language grammar + always accept English fallback
        if matchesEndSession(normalized, language: language) {
            return .endSession
        }
        if let quietMinutes = matchesQuiet(normalized, language: language) {
            return .quiet(minutes: quietMinutes)
        }
        if matchesResume(normalized, language: language) {
            return .resumeNarration
        }
        if matchesSkip(normalized, language: language) {
            return .skip
        }
        if matchesTellMeMore(normalized, language: language) {
            return .tellMeMore
        }
        if matchesPhotographQuestion(normalized, language: language) {
            return .whatDidIPhotographHere
        }
        if matchesWhereIsIt(normalized, language: language) {
            return .whereIsIt
        }

        return .freeQuestion(transcript.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func matchesTellMeMore(_ text: String, language: SaathiLanguage) -> Bool {
        let english = ["tell me more", "full story", "more details", "continue"]
        let perLang: [SaathiLanguage: [String]] = [
            .hindi: ["aur batao", "और बताओ", "विस्तार", "पूरा बताओ", "iske baare mein aur"],
            .hinglish: ["aur batao", "more batao", "full story batao", "iske baare mein aur"],
            .tamil: ["மேலும் சொல்", "மேலும் கூறு", "melum sol"],
            .urdu: ["مزید بتائیں", "aur batayein", "mazeed"],
            .bengali: ["আরও বলো", "aro bolo"],
            .marathi: ["अजून सांगा", "ajun sanga"],
            .telugu: ["ఇంకా చెప్పు", "inka cheppu"],
            .gujarati: ["વધુ કહો", "vadhu kaho"],
            .kannada: ["ಇನ್ನಷ್ಟು ಹೇಳು", "innashtu helu"],
            .malayalam: ["കൂടുതൽ പറയൂ"],
            .punjabi: ["ਹੋਰ ਦੱਸੋ"],
            .odia: ["ଆହୁରି କୁହ"]
        ]
        return containsAny(text, patterns: english + (perLang[language] ?? []))
    }

    private static func matchesSkip(_ text: String, language: SaathiLanguage) -> Bool {
        let english = ["skip", "next place", "move on"]
        let perLang: [SaathiLanguage: [String]] = [
            .hindi: ["आगे बढ़ो", "छोड़ो", "aage badho", "skip karo", "agla"],
            .hinglish: ["skip karo", "aage badho", "next karo", "chhodo"],
            .tamil: ["தவிர்", "அடுத்தது"],
            .urdu: ["آگے بڑھیں", "چھوڑیں", "aage badhein"],
            .bengali: ["এড়িয়ে যাও", "পরেরটা"],
            .marathi: ["पुढे जा"]
        ]
        return containsAny(text, patterns: english + (perLang[language] ?? []))
    }

    private static func matchesQuiet(_ text: String, language: SaathiLanguage) -> Int? {
        let triggers = [
            "quiet", "mute", "be silent", "pause",
            "chup", "चुप", "शांत", "baad mein", "बाद में",
            "அமைதி", "خاموش", "چپ", "নীরব", "शांत रहा"
        ]
        guard containsAny(text, patterns: triggers) else { return nil }
        return extractFirstInteger(from: text) ?? 20
    }

    private static func matchesResume(_ text: String, language: SaathiLanguage) -> Bool {
        let patterns = ["resume", "start talking", "unmute", "फिर शुरू", "bolna shuru", "தொடர்", "دوبارہ شروع"]
        return containsAny(text, patterns: patterns)
    }

    private static func matchesPhotographQuestion(_ text: String, language: SaathiLanguage) -> Bool {
        let english = ["what did i photograph", "my photo", "photos here", "picture here"]
        let perLang: [SaathiLanguage: [String]] = [
            .hindi: ["यहाँ क्या फोटो", "क्या तस्वीर", "yahan kya photo", "meri photo"],
            .hinglish: ["yahan kya photo li", "meri photos dikhao", "kya click kiya"],
            .tamil: ["இங்கு என்ன புகைப்படம்", "என் படம்"],
            .urdu: ["یہاں کیا تصویر", "میری تصویر"]
        ]
        return containsAny(text, patterns: english + (perLang[language] ?? []))
    }

    private static func matchesWhereIsIt(_ text: String, language: SaathiLanguage) -> Bool {
        let english = ["where is it", "which direction", "how far"]
        let perLang: [SaathiLanguage: [String]] = [
            .hindi: ["कहाँ है", "किधर है", "kahan hai", "kidhar hai"],
            .hinglish: ["kahan hai", "kidhar hai", "kitni door"],
            .tamil: ["எங்கே உள்ளது", "எந்த திசை"],
            .urdu: ["کہاں ہے", "کس طرف"]
        ]
        return containsAny(text, patterns: english + (perLang[language] ?? []))
    }

    private static func matchesEndSession(_ text: String, language: SaathiLanguage) -> Bool {
        let english = ["end session", "stop saathi", "finish walk", "stop walk"]
        let perLang: [SaathiLanguage: [String]] = [
            .hindi: ["बंद करो", "सत्र समाप्त", "band karo", "khatam"],
            .hinglish: ["band karo", "session khatam", "end karo", "stop karo"],
            .tamil: ["அமர்வை முடி", "நிறுத்து"],
            .urdu: ["سیشن ختم", "بند کریں"]
        ]
        return containsAny(text, patterns: english + (perLang[language] ?? []))
    }

    private static func containsAny(_ text: String, patterns: [String]) -> Bool {
        patterns.contains { text.contains($0.lowercased()) }
    }

    private static func extractFirstInteger(from text: String) -> Int? {
        let tokens = text.components(separatedBy: CharacterSet.decimalDigits.inverted)
        for token in tokens where !token.isEmpty {
            if let value = Int(token), value > 0 {
                return value
            }
        }
        return nil
    }
}
