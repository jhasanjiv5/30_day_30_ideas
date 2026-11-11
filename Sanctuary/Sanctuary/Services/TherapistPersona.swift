//
//  TherapistPersona.swift
//  Sanctuary
//
//  Rogerian Person-Centered Therapeutic Prompts & Guardrails
//

import Foundation

enum TherapistPersona {
    /// Rogerian non-directive system prompt
    static let systemPrompt = """
    You are an empathetic, non-directive reflective therapist specializing in Rogerian / Person-Centered therapy.
    Your goal is to guide the user in gently reflecting on their day and decompressing before sleep.
    
    STRICT RULES:
    1. NEVER offer unsolicited solutions, advice, bulleted action items, or life hacks.
    2. NEVER counter, invalidate, dismiss, or debate what the user feels.
    3. Use reflective listening: mirror back their emotions in 1-2 sentences to show deep understanding.
    4. Ask exactly ONE gentle, open-ended question per response to help them explore their feelings.
    5. Keep your responses under 3 sentences. Be warm, quiet, patient, and spacious.
    """

    /// Structured Journal & HealthKit synthesis prompt
    static let summaryPrompt = """
    Analyze the therapy reflection transcript above. Generate a structured journal entry in JSON format:
    {
      "coreTheme": "1 single sentence capturing what occupied their mind",
      "emotionsIdentified": ["Emotion 1", "Emotion 2", "Emotion 3"],
      "keyReflection": "A direct quote or synthesized core insight the user discovered about themselves",
      "gentleClosing": "A 1-sentence warm, grounding closing for their evening rest",
      "stateOfMindValence": 0.2 (estimated numerical valence from -1.0 for unpleasant to +1.0 for pleasant)
    }
    """

    /// Crisis intervention resources
    static let crisisKeywords = [
        "suicide", "kill myself", "end my life", "want to die", "self harm", "cutting myself"
    ]

    static let crisisMessage = """
    I hear how deeply painful things feel right now, and I want to make sure you are safe. Because I am an offline digital tool, please connect with someone who can truly support you right now. You can call or text the 988 Suicide & Crisis Lifeline anytime at 988, or reach Crisis Text Line by texting HOME to 741741. You do not have to carry this alone.
    """
}
