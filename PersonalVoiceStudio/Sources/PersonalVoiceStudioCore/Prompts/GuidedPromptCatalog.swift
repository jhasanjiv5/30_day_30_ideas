import Foundation

public enum GuidedPromptCatalog {
    public static let allPrompts: [RecordingPrompt] = [
        RecordingPrompt(
            id: "prompt-01",
            index: 0,
            title: "Natural Warm-Up",
            category: "Conversational Baseline",
            text: "Good morning. Take a calm breath, speak at your normal pace, and let the room settle.",
            phoneticFocus: "Neutral vowels, gentle stops (/g/, /k/, /t/), and steady phrasing.",
            recommendedMinimumSeconds: 3.0,
            lengthClass: .medium
        ),
        RecordingPrompt(
            id: "prompt-02",
            index: 1,
            title: "Short Direct Statement",
            category: "Short Phrase",
            text: "I'll check the schedule right now.",
            phoneticFocus: "Contractions, /tʃ/ (ch), and brisk end cadence.",
            recommendedMinimumSeconds: 1.4,
            lengthClass: .short
        ),
        RecordingPrompt(
            id: "prompt-03",
            index: 2,
            title: "Consonant Clusters",
            category: "Articulation & Clusters",
            text: "Strong spring breezes swept across three splintered wooden bridges before twilight.",
            phoneticFocus: "Initial and medial clusters (str, spr, br, sw, thr, spl, tw).",
            recommendedMinimumSeconds: 3.5,
            lengthClass: .medium
        ),
        RecordingPrompt(
            id: "prompt-04",
            index: 3,
            title: "Sibilants & Fricatives",
            category: "High-Frequency Consonants",
            text: "She chose six fresh peaches, shaved thin ginger slices, and zipped the canvas satchel shut.",
            phoneticFocus: "Contrast between /ʃ/ (sh), /s/, /z/, /tʃ/ (ch), /dʒ/ (j), and /f/-/v/.",
            recommendedMinimumSeconds: 4.0,
            lengthClass: .medium
        ),
        RecordingPrompt(
            id: "prompt-05",
            index: 4,
            title: "Numbers, Time & Currency",
            category: "Numerals & Formatting",
            text: "Flight 204 departs at 3:15 PM from Gate 19, and the upgraded luggage fee is $48.75.",
            phoneticFocus: "Cardinals, ordinals, clock time, and decimal currency reading.",
            recommendedMinimumSeconds: 4.0,
            lengthClass: .medium
        ),
        RecordingPrompt(
            id: "prompt-06",
            index: 5,
            title: "Question Intonation",
            category: "Prosody & Pitch Rise",
            text: "Did you remember to lock the side workshop, or should we walk back and check?",
            phoneticFocus: "Rising yes/no inflection followed by an alternative clause.",
            recommendedMinimumSeconds: 3.0,
            lengthClass: .medium
        ),
        RecordingPrompt(
            id: "prompt-07",
            index: 6,
            title: "Em-Dashes & Contrast",
            category: "Punctuation & Pauses",
            text: "The prototype wasn't broken—it was simply waiting for a quieter microphone and clearer input.",
            phoneticFocus: "Em-dash pause timing and contrastive stress on \"wasn't\" vs. \"simply\".",
            recommendedMinimumSeconds: 3.5,
            lengthClass: .medium
        ),
        RecordingPrompt(
            id: "prompt-08",
            index: 7,
            title: "Lists & Parentheticals",
            category: "Complex Punctuation",
            text: "Pack three essentials: a notebook (lined or blank), two reliable pens, and a spare battery.",
            phoneticFocus: "Colon pause, pitch drop inside parentheses, and serial list rhythm.",
            recommendedMinimumSeconds: 3.8,
            lengthClass: .medium
        ),
        RecordingPrompt(
            id: "prompt-09",
            index: 8,
            title: "Brief Confirmation",
            category: "Short Phrase",
            text: "Wait—did that just work?",
            phoneticFocus: "Short attentive utterance with an abrupt pause and rising question tail.",
            recommendedMinimumSeconds: 1.2,
            lengthClass: .short
        ),
        RecordingPrompt(
            id: "prompt-10",
            index: 9,
            title: "Quoted Dialogue",
            category: "Expressive Framing",
            text: "\"Keep your shoulders relaxed,\" the coach reminded everyone, \"and finish every phrase cleanly!\"",
            phoneticFocus: "Quoted cadence shift, attribution drop, and firm final exclamation.",
            recommendedMinimumSeconds: 3.8,
            lengthClass: .medium
        ),
        RecordingPrompt(
            id: "prompt-11",
            index: 10,
            title: "Liquids, Glides & Diphthongs",
            category: "Vowel Transitions",
            text: "Clear yellow oil lamps glowed along the narrow gravel lane while royal owls flew overhead.",
            phoneticFocus: "Smooth /l/, /r/, /w/, /j/ transitions and diphthongs (/ɔɪ/, /aʊ/, /oʊ/).",
            recommendedMinimumSeconds: 4.0,
            lengthClass: .medium
        ),
        RecordingPrompt(
            id: "prompt-12",
            index: 11,
            title: "Nasals & Voiced Stops",
            category: "Resonance & Clarity",
            text: "Many engineers examine humming motors during long mornings to pinpoint minor timing vibrations.",
            phoneticFocus: "Nasal consonants (/m/, /n/, /ŋ/) paired with voiced stops (/b/, /d/, /g/).",
            recommendedMinimumSeconds: 3.8,
            lengthClass: .medium
        ),
        RecordingPrompt(
            id: "prompt-13",
            index: 12,
            title: "Dates & Hyphenated Terms",
            category: "Structured Text",
            text: "On October 14, 2026, our cross-platform team tested a twenty-four-bit, low-latency audio pipeline.",
            phoneticFocus: "Calendar date phrasing, compound modifiers, and crisp multi-syllable words.",
            recommendedMinimumSeconds: 4.5,
            lengthClass: .long
        ),
        RecordingPrompt(
            id: "prompt-14",
            index: 13,
            title: "Measurements & Percentages",
            category: "Technical Numerals",
            text: "The sensor moved 12.5 kilometers in 0.8 hours, maintaining 98.4% signal stability under load.",
            phoneticFocus: "Decimals, percentage reading, and technical noun clarity.",
            recommendedMinimumSeconds: 4.5,
            lengthClass: .long
        ),
        RecordingPrompt(
            id: "prompt-15",
            index: 14,
            title: "Multi-Clause Explanation",
            category: "Long Narrative Flow",
            text: "Whenever you switch rooms, take two seconds to check how close you sit to the desk, because reflections off bare walls and glass windows can noticeably color the tone of your recording.",
            phoneticFocus: "Sustained breath support, subordinate clauses, and natural mid-sentence inflection.",
            recommendedMinimumSeconds: 7.0,
            lengthClass: .long
        ),
        RecordingPrompt(
            id: "prompt-16",
            index: 15,
            title: "Th-Sounds & Velars",
            category: "Dental Fricatives",
            text: "Both brothers thought carefully through the thick leather catalog before picking anything green.",
            phoneticFocus: "Voiceless /θ/ vs. voiced /ð/ (th) alongside velar stops (/k/, /g/).",
            recommendedMinimumSeconds: 3.8,
            lengthClass: .medium
        ),
        RecordingPrompt(
            id: "prompt-17",
            index: 16,
            title: "Short Command Sequence",
            category: "Short Phrase",
            text: "Pause here. Check the levels. Continue when ready.",
            phoneticFocus: "Three crisp, separated sentences with full stops.",
            recommendedMinimumSeconds: 2.2,
            lengthClass: .short
        ),
        RecordingPrompt(
            id: "prompt-18",
            index: 17,
            title: "Closing Reflection",
            category: "Natural Wrap-Up",
            text: "That covers today's recording session—thank you for taking the time to speak clearly, naturally, and at your own steady rhythm.",
            phoneticFocus: "Balanced conversational wrap-up with serial commas and gentle downward close.",
            recommendedMinimumSeconds: 5.0,
            lengthClass: .long
        )
    ]

    public static func prompt(for id: String) -> RecordingPrompt? {
        allPrompts.first { $0.id == id }
    }
}
