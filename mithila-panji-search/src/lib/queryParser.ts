import {
  containsDevanagari,
  foldIastToAscii,
  normalizeDevanagari,
  phoneticRomanKey,
} from './normalize.ts';
import type { PanjiDataset, QueryInterpretation } from '../types/panji.ts';

const BOILERPLATE_PREFIXES = [
  /^(?:hi|hello|please|can you|could you|help me)\s+/i,
  /^(?:i am|i'm|im)\s+(?:looking|searching|trying to find)\s+(?:for\s+)?/i,
  /^(?:looking|searching)\s+for\s+/i,
  /^(?:find|search|show|trace|locate)\s+(?:me\s+)?(?:records?\s+(?:for|of)\s+)?/i,
  /^(?:who\s+is|tell\s+me\s+about|ancestors?\s+of|lineage\s+of)\s+/i,
];

const HONORIFIC_STOPWORDS = new Set(['jha', 'thakur', 'mishra', 'misra', 'pandit', 'ji']);

export interface VocabularyIndex {
  gotraKeys: Map<string, string>; // folded/phonetic -> canonical name_roman
  moolKeys: Map<string, string>; // folded/phonetic -> canonical name_roman
  villageKeys: Map<string, string>; // folded/phonetic -> canonical name_roman
}

export function buildVocabularyIndex(dataset: PanjiDataset): VocabularyIndex {
  const gotraKeys = new Map<string, string>();
  for (const g of dataset.gotras) {
    for (const k of [
      foldIastToAscii(g.name_roman),
      phoneticRomanKey(g.name_roman),
      normalizeDevanagari(g.name_dev),
    ]) {
      if (k) gotraKeys.set(k, g.name_roman);
    }
  }

  const moolKeys = new Map<string, string>();
  for (const m of dataset.mools) {
    const terms = [m.name_roman, m.name_dev, ...m.aka];
    for (const t of terms) {
      const k1 = containsDevanagari(t) ? normalizeDevanagari(t) : foldIastToAscii(t);
      const k2 = containsDevanagari(t) ? '' : phoneticRomanKey(t);
      if (k1) moolKeys.set(k1, m.name_roman);
      if (k2) moolKeys.set(k2, m.name_roman);
    }
  }

  const villageKeys = new Map<string, string>();
  for (const v of dataset.villages) {
    for (const k of [
      foldIastToAscii(v.name_roman),
      phoneticRomanKey(v.name_roman),
      normalizeDevanagari(v.name_dev),
    ]) {
      if (k) villageKeys.set(k, v.name_roman);
    }
  }

  return { gotraKeys, moolKeys, villageKeys };
}

function lookupTerm(map: Map<string, string>, raw: string): string | undefined {
  const cleaned = raw.trim();
  if (!cleaned) return undefined;
  if (containsDevanagari(cleaned)) {
    return map.get(normalizeDevanagari(cleaned));
  }
  return map.get(foldIastToAscii(cleaned)) ?? map.get(phoneticRomanKey(cleaned));
}

export function parseQueryDeterministically(
  rawQuery: string,
  vocab: VocabularyIndex
): QueryInterpretation {
  const originalQuery = (rawQuery || '').trim();
  if (!originalQuery) {
    return {
      originalQuery: '',
      personTerms: [],
      strategy: 'deterministic',
    };
  }

  let working = originalQuery.replace(/[?!.]+$/g, '').trim();
  for (const rx of BOILERPLATE_PREFIXES) {
    working = working.replace(rx, '').trim();
  }

  let gotraHint: string | undefined;
  let moolHint: string | undefined;
  let villageHint: string | undefined;

  // 1. Extract explicit "<X> gotra" or "gotra <X>"
  working = working.replace(
    /\b([a-zA-Z\u00C0-\u024F\u1E00-\u1EFF\u0900-\u097F]+)\s+gotra\b/gi,
    (_m, term: string) => {
      gotraHint = lookupTerm(vocab.gotraKeys, term) ?? term.trim();
      return ' ';
    }
  );
  working = working.replace(
    /\bgotra\s+([a-zA-Z\u00C0-\u024F\u1E00-\u1EFF\u0900-\u097F]+)\b/gi,
    (_m, term: string) => {
      gotraHint = lookupTerm(vocab.gotraKeys, term) ?? term.trim();
      return ' ';
    }
  );

  // 2. Extract explicit "<X> mool" or "mool <X>"
  working = working.replace(
    /\b([a-zA-Z\u00C0-\u024F\u1E00-\u1EFF\u0900-\u097F]+)\s+mool\b/gi,
    (_m, term: string) => {
      moolHint = lookupTerm(vocab.moolKeys, term) ?? term.trim();
      return ' ';
    }
  );
  working = working.replace(
    /\bmool\s+([a-zA-Z\u00C0-\u024F\u1E00-\u1EFF\u0900-\u097F]+)\b/gi,
    (_m, term: string) => {
      moolHint = lookupTerm(vocab.moolKeys, term) ?? term.trim();
      return ' ';
    }
  );

  // 3. Extract "from <place>" / "of <place>" / "in <place>" / "village <place>"
  working = working.replace(
    /\b(?:from|of|in|village)\s+([a-zA-Z\u00C0-\u024F\u1E00-\u1EFF\u0900-\u097F]+(?:\s+[a-zA-Z\u00C0-\u024F\u1E00-\u1EFF\u0900-\u097F]+)?)(?=\s*(?:,|$))/gi,
    (_m, place: string) => {
      const cleanedPlace = place.trim();
      const matchedVillage = lookupTerm(vocab.villageKeys, cleanedPlace);
      const matchedMool = lookupTerm(vocab.moolKeys, cleanedPlace);
      if (matchedVillage) {
        villageHint = matchedVillage;
      } else if (matchedMool) {
        moolHint = matchedMool;
      } else {
        villageHint = cleanedPlace;
      }
      return ' ';
    }
  );

  // 4. Clean remaining separators and tokens
  const remainingTokens = working
    .replace(/[,;|]+/g, ' ')
    .split(/\s+/)
    .map((t) => t.trim())
    .filter(Boolean);

  // If user typed a single known gotra/mool/village without prepositions (e.g., "Vatsa" or "Darihara")
  // keep it in personTerms too unless we have multiple tokens where one is clearly a gotra.
  const personTerms: string[] = [];
  for (const token of remainingTokens) {
    const folded = foldIastToAscii(token);
    if (!folded && !containsDevanagari(token)) continue;
    if (remainingTokens.length > 1 && HONORIFIC_STOPWORDS.has(folded)) {
      // Keep as optional soft term only if nothing else remains; wait -
      // Some upstream records DO contain "jha" or similar? Let's keep all non-connector words,
      // except pure English connectors like "and", "with", "the".
      if (['and', 'with', 'the', 'for', 'a', 'an'].includes(folded)) continue;
    }
    if (['and', 'with', 'the', 'for', 'a', 'an'].includes(folded)) continue;
    personTerms.push(token);
  }

  return {
    originalQuery,
    personTerms,
    villageHint,
    moolHint,
    gotraHint,
    strategy: 'deterministic',
  };
}
