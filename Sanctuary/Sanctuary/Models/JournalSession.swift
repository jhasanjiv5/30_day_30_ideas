//
//  JournalSession.swift
//  Sanctuary
//
//  SwiftData Model with Complete Hardware Encryption
//

import Foundation
import SwiftData

@Model
final class JournalSession {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    @Relationship(deleteRule: .cascade) var messages: [ChatMessage]
    var coreTheme: String?
    var emotionsIdentified: [String]
    var keyReflection: String?
    var gentleClosing: String?
    var initialValence: Double // -1.0 (Unpleasant) to +1.0 (Pleasant)
    var finalValence: Double
    var isExportedToJournal: Bool
    var isLoggedToHealth: Bool
    var durationSeconds: Int

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        messages: [ChatMessage] = [],
        initialValence: Double = 0.0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.messages = messages
        self.emotionsIdentified = []
        self.initialValence = initialValence
        self.finalValence = initialValence
        self.isExportedToJournal = false
        self.isLoggedToHealth = false
        self.durationSeconds = 0
    }

    var valenceCategory: String {
        let v = finalValence
        if v > 0.4 { return "Very Pleasant" }
        if v > 0.1 { return "Slightly Pleasant" }
        if v > -0.2 { return "Neutral / Mixed" }
        if v > -0.5 { return "Slightly Unpleasant" }
        return "Unpleasant"
    }
}

@Model
final class ChatMessage {
    var id: UUID
    var sender: String // "user" or "therapist"
    var content: String
    var timestamp: Date

    init(id: UUID = UUID(), sender: String, content: String, timestamp: Date = Date()) {
        self.id = id
        self.sender = sender
        self.content = content
        self.timestamp = timestamp
    }

    var isUser: Bool {
        sender == "user"
    }
}
