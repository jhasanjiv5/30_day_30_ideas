//
//  JournalExportManager.swift
//  Sanctuary
//
//  Apple HealthKit (HKStateOfMind) and Apple Journal Integration
//

import Foundation
import HealthKit
import UIKit

public final class JournalExportManager {
    public static let shared = JournalExportManager()
    private let healthStore = HKHealthStore()

    private init() {}

    /// Requests authorization to write State of Mind to Apple Health
    public func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        guard #available(iOS 18.0, *) else { return false }

        let stateOfMindIdentifier = HKCategoryTypeIdentifier(rawValue: HKDataTypeIdentifierStateOfMind)
        let stateOfMindType = HKCategoryType(stateOfMindIdentifier)
        do {
            try await healthStore.requestAuthorization(toShare: [stateOfMindType], read: [])
            return true
        } catch {
            print("HealthKit Authorization error: \(error)")
            return false
        }
    }

    /// Direct write to Apple Health State of Mind
    @available(iOS 18.0, *)
    public func logStateOfMind(valence: Double) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let sample = HKStateOfMind(
            date: Date(),
            kind: .momentaryEmotion,
            valence: max(-1.0, min(1.0, valence)),
            labels: [],
            associations: [.community, .work]
        )
        try await healthStore.save(sample)
    }

    /// Formats structured Markdown for Apple Journal & Apple Notes
    func createJournalExportText(session: JournalSession) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let dateStr = formatter.string(from: session.timestamp)
        let emotionsList = session.emotionsIdentified.joined(separator: " · ")

        return """
        # 🌙 Nightly Reflection • \(dateStr)

        **Core Theme:**
        \(session.coreTheme ?? "Evening decompression and self-reflection.")

        **State of Mind (HealthKit):**
        \(session.valenceCategory) (\(session.finalValence >= 0 ? "+" : "")\(String(format: "%.2f", session.finalValence))) · \(emotionsList)

        **Key Realization:**
        > \(session.keyReflection ?? "Taking time to notice emotional sensations at the end of the day.")

        **Therapist Closing:**
        *\(session.gentleClosing ?? "Rest well tonight. You have done enough.")*

        ---

        ### Reflection Transcript (Private On-Device Archive)
        \(session.messages.map { "**\($0.sender.capitalized):** \($0.content)" }.joined(separator: "\n\n"))

        *Logged privately via Sanctuary on-device neural foundation model.*
        """
    }

    /// Triggers Apple Shortcuts to pass text directly to Apple Journal app
    @MainActor
    func openAppleJournalShortcut(session: JournalSession) {
        let text = createJournalExportText(session: session)
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "shortcuts://run-shortcut?name=Log%20to%20Apple%20Journal&input=\(encoded)") else {
            return
        }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}
