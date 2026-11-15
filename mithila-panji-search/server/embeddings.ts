import { GoogleGenAI } from '@google/genai';
import { isGeminiConfigured } from './ai.ts';

export const EMBEDDING_MODEL = 'gemini-embedding-001';
export const EMBEDDING_DIMENSIONS = 768;
export const VECTOR_INDEX_NAME = 'person_embedding';

export function isEmbeddingRateLimitError(err: unknown): boolean {
  return (
    typeof err === 'object' &&
    err !== null &&
    'status' in err &&
    (err.status === 429 || err.status === '429')
  );
}

export interface PersonEmbeddingProfile {
  nameRoman: string;
  nameDevanagari: string;
  villageRoman: string;
  villageDevanagari: string;
  titles: string;
  mools: string[];
  gotras: string[];
  parents: string[];
  children: string[];
  recordedSiblings: string[];
  inferredSiblings: string[];
}

export function buildPersonEmbeddingProfile(profile: PersonEmbeddingProfile): string {
  const lines = [
    `Name: ${[profile.nameRoman, profile.nameDevanagari].filter(Boolean).join(' · ')}`,
    profile.villageRoman || profile.villageDevanagari
      ? `Recorded village: ${[profile.villageRoman, profile.villageDevanagari]
          .filter(Boolean)
          .join(' · ')}`
      : '',
    profile.titles ? `Recorded titles: ${profile.titles}` : '',
    profile.mools.length > 0 ? `Inferred mool: ${profile.mools.join(', ')}` : '',
    profile.gotras.length > 0 ? `Inferred gotra: ${profile.gotras.join(', ')}` : '',
    profile.parents.length > 0 ? `Documented parents: ${profile.parents.join(', ')}` : '',
    profile.children.length > 0 ? `Documented children: ${profile.children.join(', ')}` : '',
    profile.recordedSiblings.length > 0
      ? `Documented siblings: ${profile.recordedSiblings.join(', ')}`
      : '',
    profile.inferredSiblings.length > 0
      ? `Possible siblings sharing a documented parent: ${profile.inferredSiblings.join(', ')}`
      : '',
  ];

  return lines.filter(Boolean).join('\n');
}

export async function embedTexts(
  texts: string[],
  taskType: 'RETRIEVAL_DOCUMENT' | 'RETRIEVAL_QUERY'
): Promise<number[][]> {
  if (!isGeminiConfigured()) {
    throw new Error('Set GEMINI_API_KEY to create genealogy embeddings.');
  }
  if (texts.length === 0) return [];

  const ai = new GoogleGenAI({
    apiKey: process.env.GEMINI_API_KEY,
    httpOptions: { timeout: 30000 },
  });
  const response = await ai.models.embedContent({
    model: EMBEDDING_MODEL,
    contents: texts,
    config: { taskType, outputDimensionality: EMBEDDING_DIMENSIONS },
  });
  const embeddings = response.embeddings ?? [];
  if (embeddings.length !== texts.length) {
    throw new Error(
      `Gemini returned ${embeddings.length} embeddings for ${texts.length} profiles.`
    );
  }

  return embeddings.map((embedding, index) => {
    const vector = embedding.values ?? [];
    if (vector.length !== EMBEDDING_DIMENSIONS || vector.some((value) => !Number.isFinite(value))) {
      throw new Error(`Gemini returned an invalid embedding at batch position ${index + 1}.`);
    }
    return vector;
  });
}
