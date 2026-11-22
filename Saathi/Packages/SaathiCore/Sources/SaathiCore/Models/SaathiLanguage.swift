import Foundation

public enum SaathiLanguage: String, CaseIterable, Codable, Sendable, Identifiable {
    case englishIndia = "en-IN"
    case hindi = "hi-IN"
    case bengali = "bn-IN"
    case marathi = "mr-IN"
    case telugu = "te-IN"
    case tamil = "ta-IN"
    case gujarati = "gu-IN"
    case kannada = "kn-IN"
    case malayalam = "ml-IN"
    case punjabi = "pa-IN"
    case odia = "or-IN"
    case urdu = "ur-IN"
    case hinglish = "hi-Latn"

    public var id: String { rawValue }

    public var locale: Locale {
        Locale(identifier: rawValue)
    }

    public var baseLanguageCode: String {
        switch self {
        case .hinglish: return "hi"
        default: return String(rawValue.prefix(2))
        }
    }

    public var englishName: String {
        switch self {
        case .englishIndia: return "English (India)"
        case .hindi: return "Hindi"
        case .bengali: return "Bengali"
        case .marathi: return "Marathi"
        case .telugu: return "Telugu"
        case .tamil: return "Tamil"
        case .gujarati: return "Gujarati"
        case .kannada: return "Kannada"
        case .malayalam: return "Malayalam"
        case .punjabi: return "Punjabi"
        case .odia: return "Odia"
        case .urdu: return "Urdu"
        case .hinglish: return "Hinglish (Mixed)"
        }
    }

    public var nativeDisplayName: String {
        switch self {
        case .englishIndia: return "English (India)"
        case .hindi: return "हिन्दी (Hindi)"
        case .bengali: return "বাংলা (Bengali)"
        case .marathi: return "मराठी (Marathi)"
        case .telugu: return "తెలుగు (Telugu)"
        case .tamil: return "தமிழ் (Tamil)"
        case .gujarati: return "ગુજરાતી (Gujarati)"
        case .kannada: return "ಕನ್ನಡ (Kannada)"
        case .malayalam: return "മലയാളം (Malayalam)"
        case .punjabi: return "ਪੰਜਾਬੀ (Punjabi)"
        case .odia: return "ଓଡ଼ିଆ (Odia)"
        case .urdu: return "اردو (Urdu)"
        case .hinglish: return "Hinglish (Mixed Hindi + English)"
        }
    }

    public var isRightToLeft: Bool {
        self == .urdu
    }

    public static func fromDeviceLocale(_ locale: Locale = .current) -> SaathiLanguage {
        let id = locale.identifier
        if let exact = SaathiLanguage(rawValue: id) {
            return exact
        }
        let langCode = locale.language.languageCode?.identifier ?? "en"
        return SaathiLanguage.allCases.first(where: { $0.baseLanguageCode == langCode }) ?? .englishIndia
    }
}

public enum SpeechRecognitionBackend: String, Sendable, Codable, Equatable {
    case speechAnalyzer = "SpeechAnalyzer (On-Device)"
    case sfSpeechRecognizer = "SFSpeechRecognizer"
    case touchOnly = "Touch Input Only"
}

public enum ModelGenerationPath: String, Sendable, Codable, Equatable {
    case directOnDevice = "Direct On-Device FoundationModel"
    case englishThenOnDeviceTranslation = "English Model + On-Device Translation"
    case englishTemplateFallback = "Template Narration (Model Unavailable)"
}

public enum TranslationPackStatus: String, Sendable, Codable, Equatable {
    case notNeeded
    case installed
    case downloadableWithConsent
    case unsupported
}

public enum VoiceSynthesisPath: String, Sendable, Codable, Equatable {
    case enhancedOrPremiumVoice = "Enhanced / Premium Voice"
    case standardVoice = "Standard System Voice"
    case captionsOnly = "Captions Only (No Voice)"
}

public enum LanguageBadge: String, Sendable, Codable, Equatable {
    case fullVoice = "✅ Full Voice"
    case translated = "🟡 Translated"
    case captionsOnly = "📝 Captions Only"
}

public struct LanguageRuntimeSignals: Sendable, Equatable {
    public let speechAnalyzerInstalled: Bool
    public let speechAnalyzerSupported: Bool
    public let legacySpeechRecognizerAvailable: Bool
    public let foundationModelAvailable: Bool
    public let foundationModelSupportsLocale: Bool
    public let translationStatus: TranslationPackStatus
    public let hasEnhancedOrPremiumTTSVoice: Bool
    public let hasAnyTTSVoice: Bool

    public init(
        speechAnalyzerInstalled: Bool,
        speechAnalyzerSupported: Bool,
        legacySpeechRecognizerAvailable: Bool,
        foundationModelAvailable: Bool,
        foundationModelSupportsLocale: Bool,
        translationStatus: TranslationPackStatus,
        hasEnhancedOrPremiumTTSVoice: Bool,
        hasAnyTTSVoice: Bool
    ) {
        self.speechAnalyzerInstalled = speechAnalyzerInstalled
        self.speechAnalyzerSupported = speechAnalyzerSupported
        self.legacySpeechRecognizerAvailable = legacySpeechRecognizerAvailable
        self.foundationModelAvailable = foundationModelAvailable
        self.foundationModelSupportsLocale = foundationModelSupportsLocale
        self.translationStatus = translationStatus
        self.hasEnhancedOrPremiumTTSVoice = hasEnhancedOrPremiumTTSVoice
        self.hasAnyTTSVoice = hasAnyTTSVoice
    }
}

public struct LanguagePipelineCapability: Sendable, Equatable, Identifiable {
    public var id: String { language.rawValue }
    public let language: SaathiLanguage
    public let speechBackend: SpeechRecognitionBackend
    public let modelPath: ModelGenerationPath
    public let translationStatus: TranslationPackStatus
    public let voicePath: VoiceSynthesisPath
    public let badge: LanguageBadge
    public let plainLanguageReason: String
    public let needsVoiceDownloadPrompt: Bool
    public let needsTranslationDownloadConsent: Bool

    public init(
        language: SaathiLanguage,
        speechBackend: SpeechRecognitionBackend,
        modelPath: ModelGenerationPath,
        translationStatus: TranslationPackStatus,
        voicePath: VoiceSynthesisPath,
        badge: LanguageBadge,
        plainLanguageReason: String,
        needsVoiceDownloadPrompt: Bool,
        needsTranslationDownloadConsent: Bool
    ) {
        self.language = language
        self.speechBackend = speechBackend
        self.modelPath = modelPath
        self.translationStatus = translationStatus
        self.voicePath = voicePath
        self.badge = badge
        self.plainLanguageReason = plainLanguageReason
        self.needsVoiceDownloadPrompt = needsVoiceDownloadPrompt
        self.needsTranslationDownloadConsent = needsTranslationDownloadConsent
    }
}

public enum CapabilityMatrixEvaluator {
    public static func evaluate(
        language: SaathiLanguage,
        signals: LanguageRuntimeSignals
    ) -> LanguagePipelineCapability {
        // 1. Speech recognition stage
        let speechBackend: SpeechRecognitionBackend
        if signals.speechAnalyzerInstalled || signals.speechAnalyzerSupported {
            speechBackend = .speechAnalyzer
        } else if signals.legacySpeechRecognizerAvailable {
            speechBackend = .sfSpeechRecognizer
        } else {
            speechBackend = .touchOnly
        }

        // 2. Language model stage
        let modelPath: ModelGenerationPath
        let needsTranslationConsent: Bool
        if signals.foundationModelAvailable && signals.foundationModelSupportsLocale {
            modelPath = .directOnDevice
            needsTranslationConsent = false
        } else if signals.foundationModelAvailable &&
            (signals.translationStatus == .installed || signals.translationStatus == .downloadableWithConsent) {
            modelPath = .englishThenOnDeviceTranslation
            needsTranslationConsent = (signals.translationStatus == .downloadableWithConsent)
        } else {
            modelPath = .englishTemplateFallback
            needsTranslationConsent = false
        }

        // 3. Text-to-speech stage
        let voicePath: VoiceSynthesisPath
        let needsVoicePrompt: Bool
        if signals.hasEnhancedOrPremiumTTSVoice {
            voicePath = .enhancedOrPremiumVoice
            needsVoicePrompt = false
        } else if signals.hasAnyTTSVoice {
            voicePath = .standardVoice
            needsVoicePrompt = true
        } else {
            voicePath = .captionsOnly
            needsVoicePrompt = true
        }

        // Badge + plain-language reason
        let badge: LanguageBadge
        let reason: String

        if voicePath == .captionsOnly {
            badge = .captionsOnly
            reason = "No system voice installed for \(language.englishName); captions and touch mode active."
        } else if modelPath == .directOnDevice && speechBackend != .touchOnly {
            badge = .fullVoice
            reason = "Direct on-device narration, voice commands, and spoken audio ready."
        } else if modelPath == .englishThenOnDeviceTranslation {
            badge = .translated
            if needsTranslationConsent {
                reason = "Generates in English on-device and translates after you download the \(language.englishName) pack."
            } else {
                reason = "Generates in English on-device and translates offline to \(language.englishName)."
            }
        } else if language == .hinglish {
            badge = .translated
            reason = "Uses Hinglish mixed phrasing with English/Hindi fallback commands."
        } else {
            badge = voicePath == .captionsOnly ? .captionsOnly : .translated
            reason = "Uses fact-grounded template narration with \(voicePath.rawValue.lowercased())."
        }

        return LanguagePipelineCapability(
            language: language,
            speechBackend: speechBackend,
            modelPath: modelPath,
            translationStatus: signals.translationStatus,
            voicePath: voicePath,
            badge: badge,
            plainLanguageReason: reason,
            needsVoiceDownloadPrompt: needsVoicePrompt,
            needsTranslationDownloadConsent: needsTranslationConsent
        )
    }
}

public enum CapabilityMatrixMarkdownExporter {
    public static func exportMarkdown(
        capabilities: [LanguagePipelineCapability],
        deviceDescription: String
    ) -> String {
        var lines = [
            "### Saathi Device Capability Matrix (\(deviceDescription))",
            "",
            "| Language | Locale | Speech Input | Model Path | TTS Voice | Status | Notes |",
            "| :--- | :--- | :--- | :--- | :--- | :--- | :--- |"
        ]
        for cap in capabilities {
            lines.append(
                "| \(cap.language.englishName) | `\(cap.language.rawValue)` | \(cap.speechBackend.rawValue) | \(cap.modelPath.rawValue) | \(cap.voicePath.rawValue) | \(cap.badge.rawValue) | \(cap.plainLanguageReason) |"
            )
        }
        return lines.joined(separator: "\n")
    }
}
