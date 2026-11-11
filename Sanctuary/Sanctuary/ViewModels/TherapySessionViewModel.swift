//
//  TherapySessionViewModel.swift
//  Sanctuary
//
//  Turn-Based Rogerian Session Manager
//

import SwiftUI
import SwiftData

@Observable
final class TherapySessionViewModel {
    var currentSession: JournalSession?
    var userInput: String = ""
    var isGenerating: Bool = false
    var streamingResponse: String = ""
    var sessionCompleted: Bool = false
    var maxUserTurns: Int = 4

    private let llmService: LLMServiceProtocol
    private var modelContext: ModelContext?

    init(llmService: LLMServiceProtocol = OnDeviceLLMService.shared) {
        self.llmService = llmService
    }

    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }

    var userTurnCount: Int {
        currentSession?.messages.filter { $0.sender == "user" }.count ?? 0
    }

    func startSession(initialValence: Double, emotionTag: String) {
        let session = JournalSession(initialValence: initialValence)
        session.emotionsIdentified = [emotionTag]

        let greeting = ChatMessage(
            sender: "therapist",
            content: "I'm here with you in this quiet space. Looking back over your day, what felt the most prominent or heavy?"
        )
        session.messages.append(greeting)

        modelContext?.insert(session)
        self.currentSession = session
        self.sessionCompleted = false
        self.streamingResponse = ""
    }

    func sendMessage() async {
        guard let session = currentSession, !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let text = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        userInput = ""

        let userMessage = ChatMessage(sender: "user", content: text)
        session.messages.append(userMessage)

        if userTurnCount >= maxUserTurns {
            await wrapUpSession()
            return
        }

        isGenerating = true
        streamingResponse = ""

        do {
            let stream = try await llmService.generateResponse(
                messages: session.messages,
                currentValence: session.initialValence
            )

            for try await token in stream {
                streamingResponse += token
            }

            let therapistMessage = ChatMessage(sender: "therapist", content: streamingResponse.trimmingCharacters(in: .whitespacesAndNewlines))
            session.messages.append(therapistMessage)
        } catch {
            let fallback = ChatMessage(sender: "therapist", content: "Take your time. I'm here listening whenever you feel ready.")
            session.messages.append(fallback)
        }

        streamingResponse = ""
        isGenerating = false
        try? modelContext?.save()
    }

    func wrapUpSession() async {
        guard let session = currentSession else { return }
        isGenerating = true

        do {
            let synthesis = try await llmService.generateSummary(session: session)
            session.coreTheme = synthesis.coreTheme
            session.emotionsIdentified = synthesis.emotionsIdentified
            session.keyReflection = synthesis.keyReflection
            session.gentleClosing = synthesis.gentleClosing
            session.finalValence = synthesis.stateOfMindValence
            session.durationSeconds = max(180, session.messages.count * 30)

            // Attempt automatic HealthKit logging
            if #available(iOS 18.0, *) {
                try? await JournalExportManager.shared.logStateOfMind(valence: session.finalValence)
                session.isLoggedToHealth = true
            }
        } catch {
            session.coreTheme = "Evening decompression and self-reflection."
            session.keyReflection = "Taking time to notice emotional sensations at the end of the day."
            session.gentleClosing = "Rest well tonight. You have done enough."
        }

        isGenerating = false
        sessionCompleted = true
        try? modelContext?.save()
    }
}
