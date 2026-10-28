export type GoetheLevel = 'A1' | 'A2' | 'B1' | 'B2' | 'C1' | 'C2';

export type StudyDirection = 'DE_TO_HI' | 'HI_TO_DE';

export type AnkiRating = 'again' | 'hard' | 'good' | 'easy';

export interface Flashcard {
  id: string;
  germanWord: string;         // e.g. "die Entscheidung, -en"
  article: 'der' | 'die' | 'das' | '';
  plural?: string;            // e.g. "-en", "-¨e", "-s"
  partOfSpeech: 'noun' | 'verb' | 'adjective' | 'adverb' | 'phrase';
  hindiMeaning: string;       // e.g. "निर्णय / फ़ैसला"
  hindiTransliteration: string; // e.g. "Nirnay / Faisla"
  level: GoetheLevel;
  synonyms: string[];         // German synonyms suitable for the Goethe level
  germanExample: string;      // Contextual clarification sentence in German
  hindiExample: string;       // Hindi translation of the example sentence
  grammarNote?: string;       // e.g. "Akkusativ + an", "trennbare Verben"
  
  // SM-2 Spaced Repetition fields
  interval: number;           // Interval in days (0 = learning/again)
  repetitions: number;        // Number of consecutive correct reviews
  easeFactor: number;         // Default 2.5, minimum 1.3
  dueDate: string;            // ISO Date string for when card is due
  lastReviewed?: string;      // ISO Date string
  createdAt?: string;
  isCustom?: boolean;         // Generated via Gemini
}

export interface LevelInfo {
  level: GoetheLevel;
  title: string;
  certificate: string;
  description: string;
  vocabularyGoal: string;
}

export const GOETHE_LEVELS_INFO: Record<GoetheLevel, LevelInfo> = {
  A1: {
    level: 'A1',
    title: 'Breakthrough',
    certificate: 'Goethe-Zertifikat A1 (Start Deutsch 1)',
    description: 'Basic everyday expressions, greetings, ordering food, numbers, and personal details.',
    vocabularyGoal: '~650 words',
  },
  A2: {
    level: 'A2',
    title: 'Waystage',
    certificate: 'Goethe-Zertifikat A2',
    description: 'Everyday situations, immediate surroundings, shopping, work, and routine tasks.',
    vocabularyGoal: '~1,200 words',
  },
  B1: {
    level: 'B1',
    title: 'Threshold',
    certificate: 'Goethe-Zertifikat B1 (Zertifikat Deutsch)',
    description: 'Independent user, expressing opinions, plans, experiences, job, and current affairs.',
    vocabularyGoal: '~2,400 words',
  },
  B2: {
    level: 'B2',
    title: 'Vantage',
    certificate: 'Goethe-Zertifikat B2',
    description: 'Complex texts, abstract subjects, professional discussions, and spontaneous fluency.',
    vocabularyGoal: '~4,000 words',
  },
  C1: {
    level: 'C1',
    title: 'Effective Operational Proficiency',
    certificate: 'Goethe-Zertifikat C1',
    description: 'Academic discourse, subtle nuances, idiomatic phrasing, and flexible expression.',
    vocabularyGoal: '~6,000+ words',
  },
  C2: {
    level: 'C2',
    title: 'Mastery',
    certificate: 'Goethe-Zertifikat C2 (GDS)',
    description: 'Native-equivalent precision, sophisticated literary expressions, and exact nuances.',
    vocabularyGoal: '~8,000+ words',
  },
};
