import express, { Request, Response } from 'express';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import { GoogleGenAI, Type } from '@google/genai';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = Number(process.env.PORT) || 3000;

app.use(express.json());

// Initialize Google GenAI with required telemetry User-Agent
const ai = new GoogleGenAI({
  apiKey: process.env.GEMINI_API_KEY,
  httpOptions: {
    headers: {
      'User-Agent': 'aistudio-build',
    },
  },
});

// API Route: Generate authentic Goethe flashcards
app.post('/api/generate-cards', async (req: Request, res: Response): Promise<void> => {
  try {
    const { level = 'B1', count = 6, topic = 'general', model = 'gemini-3.8-flash' } = req.body;

    const safeLevel = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'].includes(level) ? level : 'B1';
    const cardCount = Math.min(Math.max(Number(count) || 6, 2), 12);
    const selectedModel = model === 'gemini-3.1-flash-lite' ? 'gemini-3.1-flash-lite' : 'gemini-3.8-flash';

    if (!process.env.GEMINI_API_KEY) {
      res.status(503).json({
        error: 'GEMINI_API_KEY is not configured on the server. Please check your environment variables.',
      });
      return;
    }

    const prompt = `You are a distinguished lexicographer at the Goethe-Institut and an expert bilingual German-Hindi linguist.
Generate exactly ${cardCount} high-yield vocabulary flashcards strictly conforming to the official CEFR Goethe-Zertifikat ${safeLevel} vocabulary catalog.
${topic && topic !== 'general' ? `Focus specifically on the topic or domain: "${topic}".` : 'Select high-frequency, authentic Goethe exam vocabulary across diverse practical domains.'}

Strict Rules:
1. For nouns, include standard definite article ("der", "die", or "das") and standard German plural notation (e.g. "die Entscheidung, -en", "der Bahnhof, -¨e", "das Zimmer, -").
2. For verbs, specify reflexivity and required prepositions/cases if applicable (e.g. "sich bewerben um (+ Akk)" or "abhängen von (+ Dat)").
3. For Hindi meanings, provide authentic Devanagari script along with an accurate Latin/Roman transliteration.
4. For German synonyms, provide 2 to 3 genuine German synonyms or close semantic equivalents suitable for Goethe level ${safeLevel}.
5. Provide a contextual clarification example sentence in natural German, accompanied by a precise Hindi translation.
6. Provide a concise grammatical or usage note (e.g. gender, irregularity, case governance, idiomatic use).`;

    const response = await ai.models.generateContent({
      model: selectedModel,
      contents: prompt,
      config: {
        systemInstruction: 'You produce authentic, highly accurate German-Hindi language learning materials strictly aligned with Goethe-Institut CEFR standards.',
        temperature: 0.4,
        responseMimeType: 'application/json',
        responseSchema: {
          type: Type.ARRAY,
          items: {
            type: Type.OBJECT,
            properties: {
              germanWord: {
                type: Type.STRING,
                description: 'The German lemma with article and plural for nouns (e.g. "die Entscheidung, -en") or verb with prep.',
              },
              article: {
                type: Type.STRING,
                description: 'Definite article ("der", "die", "das") or empty string if not a noun.',
              },
              plural: {
                type: Type.STRING,
                description: 'Plural ending notation (e.g. "-en", "-¨e", "-s", "-") or empty.',
              },
              partOfSpeech: {
                type: Type.STRING,
                description: 'One of: "noun", "verb", "adjective", "adverb", "phrase".',
              },
              hindiMeaning: {
                type: Type.STRING,
                description: 'Devanagari Hindi translation.',
              },
              hindiTransliteration: {
                type: Type.STRING,
                description: 'Latin/Romanized transliteration of the Hindi translation.',
              },
              synonyms: {
                type: Type.ARRAY,
                items: { type: Type.STRING },
                description: '2-3 Goethe level appropriate German synonyms.',
              },
              germanExample: {
                type: Type.STRING,
                description: 'Example clarification sentence in German.',
              },
              hindiExample: {
                type: Type.STRING,
                description: 'Accurate Hindi translation of the example sentence.',
              },
              grammarNote: {
                type: Type.STRING,
                description: 'Brief grammatical tip, case governance, or usage context.',
              },
            },
            required: ['germanWord', 'partOfSpeech', 'hindiMeaning', 'hindiTransliteration', 'synonyms', 'germanExample', 'hindiExample'],
          },
        },
      },
    });

    const text = response.text || '[]';
    const parsedData = JSON.parse(text);

    // Format into Flashcard objects with SM-2 state
    const now = new Date().toISOString();
    const formattedCards = parsedData.map((item: any, idx: number) => ({
      id: `ai-${Date.now()}-${idx}`,
      germanWord: String(item.germanWord || '').trim(),
      article: (['der', 'die', 'das'].includes(item.article) ? item.article : '') as 'der' | 'die' | 'das' | '',
      plural: String(item.plural || '').trim(),
      partOfSpeech: (['noun', 'verb', 'adjective', 'adverb', 'phrase'].includes(item.partOfSpeech) ? item.partOfSpeech : 'noun'),
      hindiMeaning: String(item.hindiMeaning || '').trim(),
      hindiTransliteration: String(item.hindiTransliteration || '').trim(),
      level: safeLevel,
      synonyms: Array.isArray(item.synonyms) ? item.synonyms.map(String) : [],
      germanExample: String(item.germanExample || '').trim(),
      hindiExample: String(item.hindiExample || '').trim(),
      grammarNote: String(item.grammarNote || '').trim(),
      interval: 0,
      repetitions: 0,
      easeFactor: 2.5,
      dueDate: now,
      createdAt: now,
      isCustom: true,
    }));

    res.json({ cards: formattedCards, level: safeLevel, count: formattedCards.length });
  } catch (error: any) {
    console.error('Error generating Goethe flashcards with Gemini:', error);
    res.status(500).json({
      error: error?.message || 'Failed to generate flashcards from Gemini',
    });
  }
});

// Health check endpoint
app.get('/api/health', (_req, res) => {
  res.json({
    status: 'ok',
    hasGeminiKey: Boolean(process.env.GEMINI_API_KEY),
    timestamp: new Date().toISOString(),
  });
});

// Setup Vite middleware in dev or static files in production
async function startServer() {
  const isProd = process.env.NODE_ENV === 'production';

  if (!isProd) {
    const { createServer: createViteServer } = await import('vite');
    const vite = await createViteServer({
      server: {
        middlewareMode: true,
        host: '0.0.0.0',
        port: PORT,
      },
      appType: 'spa',
    });

    app.use(vite.middlewares);
  } else {
    const distPath = path.resolve(__dirname, 'dist');
    app.use(express.static(distPath));
    app.get('*', (_req, res) => {
      res.sendFile(path.resolve(distPath, 'index.html'));
    });
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Goethe Anki Server running on http://0.0.0.0:${PORT} (${isProd ? 'production' : 'development'})`);
  });
}

startServer();
