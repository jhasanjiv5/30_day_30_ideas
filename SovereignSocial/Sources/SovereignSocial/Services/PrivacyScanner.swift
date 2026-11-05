import Foundation

public struct PrivacyScanResult {
    public let score: Int
    public let flags: [String]
    public let isSafe: Bool
}

public struct PrivacyScanner {
    public static func scan(text: String) -> PrivacyScanResult {
        var flags: [String] = []

        // Phone number check
        if text.range(of: #"\b\d{3}[-.]?\d{3}[-.]?\d{4}\b"#, options: .regularExpression) != nil {
            flags.append("Personal phone number detected. Replace with bio contact link.")
        }

        // Residential address check
        if text.range(of: #"\b\d{1,5}\s+([A-Za-z]+\s+){1,3}(Street|St|Ave|Avenue|Drive|Dr|Road|Rd)\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            flags.append("Residential address pattern detected. Anti-doxxing shield triggered.")
        }

        let score = max(0, 100 - (flags.count * 35))
        return PrivacyScanResult(score: score, flags: flags, isSafe: flags.isEmpty)
    }
}
