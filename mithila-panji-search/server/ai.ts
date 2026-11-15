import { GoogleGenAI, ThinkingLevel, Type } from '@google/genai';
import {
  buildDeterministicExplanationFromLineage,
  buildDeterministicSearchAnswer,
} from '../src/lib/explainLineage.ts';
import type {
  AiExplanationPayload,
  LineageGraph,
  QueryInterpretation,
  SearchAnswerPayload,
  SearchCandidate,
  SearchFilters,
} from '../src/types/panji.ts';

const DEFAULT_MODEL = process.env.GEMINI_MODEL || 'gemini-4-hydrogen';

export function isGeminiConfigured(): boolean {
  const key = (process.env.GEMINI_API_KEY || '').trim();
  return Boolean(key && key !== 'MY_GEMINI_API_KEY' && key !== 'undefined');
}

function createClient(): GoogleGenAI {
  return new GoogleGenAI({
    apiKey: process.env.GEMINI_API_KEY,
    httpOptions: {
      timeout: 25000,
      headers: {
        'User-Agent': 'aistudio-build',
      },
    },
  });
}

export async function interpretQueryWithGemini(
  rawQuery: string,
  gotraNamesList: string[]
): Promise<QueryInterpretation | null> {
  if (!isGeminiConfigured()) return null;
  const trimmed = rawQuery.trim().slice(0, 240);
  if (!trimmed) return null;

  const gotraNames = gotraNamesList.join(', ');
  const ai = createClient();

  try {
    const response = await ai.models.generateContent({
      model: DEFAULT_MODEL,
      contents: `Interpret this genealogy search query against the Mithila Panji corpus:\nQuery: ${JSON.stringify(trimmed)}`,
      config: {
        thinkingConfig: { thinkingLevel: ThinkingLevel.LOW },
        systemInstruction: [
          'You extract structured search terms from a user query for the Mithila-Panji genealogy dataset.',
          'Return ONLY fields explicitly indicated by the query. Never invent names, villages, mools, or gotras not implied by the user query.',
          `Known canonical gotras (romanized): ${gotraNames}.`,
          'Put person names, titles, or honorifics in personTerms (short words). Put place/village names in villageHint, mool names in moolHint, and gotra names in gotraHint.',
          'Strip conversational filler like "I am looking for", "who is", "ancestors of".',
        ].join(' '),
        responseMimeType: 'application/json',
        responseSchema: {
          type: Type.OBJECT,
          properties: {
            personTerms: {
              type: Type.ARRAY,
              items: { type: Type.STRING },
              description: 'Name or title tokens to search for.',
            },
            villageHint: {
              type: Type.STRING,
              description: 'Optional village or place name mentioned in query.',
            },
            moolHint: {
              type: Type.STRING,
              description: 'Optional mool name mentioned in query.',
            },
            gotraHint: {
              type: Type.STRING,
              description: 'Optional gotra name mentioned in query.',
            },
            note: {
              type: Type.STRING,
              description: 'Short plain-English summary of how the query was interpreted.',
            },
          },
          required: ['personTerms'],
        },
      },
    });

    const text = (response.text ?? '').trim();
    if (!text) return null;
    const parsed = JSON.parse(text) as {
      personTerms?: string[];
      villageHint?: string;
      moolHint?: string;
      gotraHint?: string;
      note?: string;
    };

    const personTerms = Array.isArray(parsed.personTerms)
      ? parsed.personTerms.map((t) => String(t).trim()).filter(Boolean).slice(0, 8)
      : [];

    return {
      originalQuery: rawQuery,
      personTerms,
      villageHint: parsed.villageHint?.trim() || undefined,
      moolHint: parsed.moolHint?.trim() || undefined,
      gotraHint: parsed.gotraHint?.trim() || undefined,
      strategy: 'gemini',
      note: parsed.note?.trim() || 'Interpreted with Gemini assistant',
    };
  } catch (err) {
    console.warn('[ai] Query interpretation fallback to deterministic:', (err as Error).message);
    return null;
  }
}

export async function summarizeSearchWithGemini(
  query: string,
  candidates: SearchCandidate[],
  totalMatches: number,
  appliedFilters: SearchFilters = {}
): Promise<SearchAnswerPayload> {
  const deterministic = buildDeterministicSearchAnswer(
    query,
    candidates,
    totalMatches,
    appliedFilters
  );

  if (!isGeminiConfigured()) {
    return deterministic;
  }

  const topRecords = candidates.slice(0, 6);
  const compactContext = {
    query: query.trim().slice(0, 240),
    appliedFilters,
    totalMatches,
    topRecords: topRecords.map((c) => ({
      id: c.person.id,
      name_roman: c.person.name_roman,
      name_dev: c.person.name_dev,
      village_roman: c.person.village_roman,
      village_dev: c.person.village_dev,
      titles: c.person.titles,
      source_ref: c.person.source_ref,
      inferredMool: c.person.inferredMool?.name_roman || null,
      inferredGotras: c.person.inferredGotras.map((g) => g.name_roman),
      parents: c.connections.parentLabels ?? [],
      children: c.connections.childLabels ?? [],
      parentCount: c.connections.parentCount,
      childCount: c.connections.childCount,
      explicitSiblingCount: c.connections.explicitSiblingCount,
      evidence: c.evidence.map((e) => `${e.basis}:${e.reason}`),
    })),
  };

  const ai = createClient();

  try {
    const response = await ai.models.generateContent({
      model: DEFAULT_MODEL,
      contents: `Answer the user's genealogy search question concisely in 2-3 sentences using ONLY the retrieved records below:\n${JSON.stringify(compactContext)}`,
      config: {
        thinkingConfig: { thinkingLevel: ThinkingLevel.LOW },
        systemInstruction: [
          'You answer a genealogy search query using ONLY the retrieved Mithila-Panji records provided in JSON.',
          'CRITICAL RULES:',
          '1. Write a clear, helpful 2 to 3 sentence answer (no bullet points, no markdown headings).',
          '2. Select the most relevant records and facts (name, village, source_ref, documented parents/children, and clearly qualified inferred mool/gotra).',
          '3. NEVER invent people, dates, villages, gotras, parent-child ties, or historical claims not present in the JSON.',
          '4. If totalMatches is 0, say plainly in 2 sentences that no matching records appear in this partial 2009 Panji extract and suggest broadening the search.',
          '5. Never mention databases, Cypher, Neo4j, or JSON.',
        ].join(' '),
        responseMimeType: 'application/json',
        responseSchema: {
          type: Type.OBJECT,
          properties: {
            answer: {
              type: Type.STRING,
              description: 'A concise 2-3 sentence grounded answer referencing retrieved records.',
            },
            citedIds: {
              type: Type.ARRAY,
              items: { type: Type.STRING },
              description: 'Record IDs from topRecords directly relied on for this answer.',
            },
          },
          required: ['answer', 'citedIds'],
        },
      },
    });

    const text = (response.text ?? '').trim();
    if (!text) return deterministic;
    const parsed = JSON.parse(text) as { answer?: string; citedIds?: string[] };
    const answerText = (parsed.answer || '').trim();
    if (!answerText) return deterministic;

    const validMap = new Map(topRecords.map((c) => [c.person.id, c.person]));
    const citedRecords = (Array.isArray(parsed.citedIds) ? parsed.citedIds : [])
      .map((id) => validMap.get(String(id).trim()))
      .filter((p): p is NonNullable<typeof p> => Boolean(p))
      .slice(0, 4)
      .map((p) => ({
        id: p.id,
        label: p.label,
        source_ref: p.source_ref,
      }));

    return {
      mode: 'gemini',
      text: answerText,
      citedRecords: citedRecords.length > 0 ? citedRecords : deterministic.citedRecords,
    };
  } catch (err) {
    console.warn('[ai] Search answer fallback to deterministic:', (err as Error).message);
    return deterministic;
  }
}

export async function explainLineageWithGemini(
  lineage: LineageGraph,
  query: string | undefined
): Promise<AiExplanationPayload> {
  const deterministic = buildDeterministicExplanationFromLineage(lineage, query);

  if (!isGeminiConfigured()) {
    return deterministic;
  }

  const ai = createClient();

  const compactContext = {
    query: query ? query.slice(0, 200) : undefined,
    focusPerson: lineage.focusPerson,
    ancestorChainToOldest: lineage.ancestorChainToOldest.map((p) => ({
      id: p.id,
      name_roman: p.name_roman,
      name_dev: p.name_dev,
      village_roman: p.village_roman,
      source_ref: p.source_ref,
    })),
    connectedNodes: lineage.nodes.slice(0, 40).map((n) => ({
      id: n.person.id,
      label: n.person.label,
      name_dev: n.person.name_dev,
      role: n.role,
      generationOffset: n.generationOffset,
      relationshipBasis: n.relationshipBasis,
      village_roman: n.person.village_roman,
      source_ref: n.person.source_ref,
    })),
    edges: lineage.edges.slice(0, 60),
    corpusNotes: lineage.notes,
  };

  try {
    const response = await ai.models.generateContent({
      model: DEFAULT_MODEL,
      contents: `Explain the following retrieved Mithila-Panji record and lineage strictly using ONLY the JSON data below:\n${JSON.stringify(compactContext)}`,
      config: {
        thinkingConfig: { thinkingLevel: ThinkingLevel.LOW },
        systemInstruction: [
          'You are a cautious genealogical research assistant explaining records from the open Mithila-Panji corpus.',
          'CRITICAL RULES:',
          '1. Use ONLY facts present in the provided JSON. NEVER invent people, parent-child links, villages, gotras, dates, or historical narratives not present in the JSON.',
          '2. Always cite record IDs and source_ref values when referring to a person or link.',
          '3. Clearly distinguish source-backed facts (name, recorded village, parent-child links, explicit sibling links) from inferred facts (inferredMool, inferredGotras, inferred-shared-parent siblings).',
          '4. Explicitly highlight missing data, unresolved generations, or multiple-gotra ambiguity.',
          '5. Keep tone respectful, plain-language, and concise.',
        ].join(' '),
        responseMimeType: 'application/json',
        responseSchema: {
          type: Type.OBJECT,
          properties: {
            summary: {
              type: Type.STRING,
              description: '2-3 sentence grounded explanation referencing record IDs/source_refs.',
            },
            sourceBackedFacts: {
              type: Type.ARRAY,
              items: { type: Type.STRING },
              description: 'Bullet points strictly backed by source records.',
            },
            inferredOrUncertain: {
              type: Type.ARRAY,
              items: { type: Type.STRING },
              description: 'Bullet points for inferred mool/gotra or inferred shared-parent siblings.',
            },
            gapsAndLimitations: {
              type: Type.ARRAY,
              items: { type: Type.STRING },
              description: 'Explicit missing fields, incomplete chains, and corpus limits.',
            },
          },
          required: ['summary', 'sourceBackedFacts', 'inferredOrUncertain', 'gapsAndLimitations'],
        },
      },
    });

    const text = (response.text ?? '').trim();
    if (!text) return deterministic;
    const parsed = JSON.parse(text) as {
      summary?: string;
      sourceBackedFacts?: string[];
      inferredOrUncertain?: string[];
      gapsAndLimitations?: string[];
    };

    if (!parsed.summary) return deterministic;

    return {
      mode: 'gemini',
      personId: lineage.focusPerson.id,
      summary: parsed.summary,
      sourceBackedFacts: (parsed.sourceBackedFacts ?? deterministic.sourceBackedFacts).slice(0, 8),
      inferredOrUncertain: (parsed.inferredOrUncertain ?? deterministic.inferredOrUncertain).slice(0, 6),
      gapsAndLimitations: (parsed.gapsAndLimitations ?? deterministic.gapsAndLimitations).slice(0, 6),
      citedRecords: deterministic.citedRecords,
    };
  } catch (err) {
    console.warn('[ai] Lineage explanation fallback to deterministic:', (err as Error).message);
    return deterministic;
  }
}
