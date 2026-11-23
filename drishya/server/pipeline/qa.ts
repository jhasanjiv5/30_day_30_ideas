import {
  ClarificationSource,
  DocumentModel,
  QAResponse,
  QASentence,
  StoryboardScene,
} from '../types.ts';
import { buildValidCitationSet, extractAllowedNumbers, findUngroundedNumbers } from './grounding.ts';

export const EXACT_QA_REFUSAL = 'The document and trusted sources don\'t answer this.';

interface RetrievalUnit {
  id: string;
  sourceType: 'document' | 'clarification';
  citationKey: string;
  title: string;
  text: string;
  tier?: 1 | 2 | 3;
  confidenceLabel?: 'high' | 'lower confidence';
  viewLabel?: 'Differing view';
  url?: string;
}

const STOPWORDS = new Set([
  'the', 'is', 'at', 'which', 'on', 'a', 'an', 'and', 'or', 'to', 'of', 'in',
  'for', 'with', 'what', 'how', 'why', 'does', 'do', 'are', 'was', 'were', 'it',
  'this', 'that', 'from', 'by', 'as', 'be', 'vs', 'compared',
]);

function tokenize(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9.\s/-]/g, ' ')
    .split(/\s+/)
    .filter((t) => t.length > 1 && !STOPWORDS.has(t));
}

/**
 * Deterministic 64-dim character-ngram + token hash embedding for hybrid retrieval.
 */
function hashEmbedding(text: string): number[] {
  const vec = new Array<number>(64).fill(0);
  const tokens = tokenize(text);
  for (const tok of tokens) {
    let h = 2166136261;
    for (let i = 0; i < tok.length; i += 1) {
      h ^= tok.charCodeAt(i);
      h = Math.imul(h, 16777619);
    }
    const idx = Math.abs(h) % 64;
    vec[idx] += 1;
    // Also add 3-char subword hashes for morphological similarity
    for (let j = 0; j <= tok.length - 3; j += 1) {
      const sub = tok.slice(j, j + 3);
      let sh = 2166136261;
      for (let k = 0; k < sub.length; k += 1) {
        sh ^= sub.charCodeAt(k);
        sh = Math.imul(sh, 16777619);
      }
      vec[Math.abs(sh) % 64] += 0.5;
    }
  }
  const norm = Math.sqrt(vec.reduce((sum, v) => sum + v * v, 0)) || 1;
  return vec.map((v) => v / norm);
}

function cosineSim(a: number[], b: number[]): number {
  let dot = 0;
  for (let i = 0; i < a.length; i += 1) dot += a[i] * b[i];
  return dot;
}

function buildCorpus(doc: DocumentModel, clarifications: ClarificationSource[]): RetrievalUnit[] {
  const units: RetrievalUnit[] = [];

  for (const p of doc.paragraphs) {
    units.push({
      id: p.id,
      sourceType: 'document',
      citationKey: p.citationKey,
      title: `${p.sectionTitle} (p.${p.page})`,
      text: p.text,
    });
  }

  for (const t of doc.tables) {
    const rowSummary = t.rows
      .map((r) => Object.entries(r).map(([k, v]) => `${k}: ${v} ${t.units[k] ?? ''}`).join(', '))
      .join(' | ');
    units.push({
      id: t.id,
      sourceType: 'document',
      citationKey: t.citationKey,
      title: `${t.label} (p.${t.page})`,
      text: `${t.caption} ${rowSummary}`,
    });
  }

  for (const f of doc.figures) {
    units.push({
      id: f.id,
      sourceType: 'document',
      citationKey: f.citationKey,
      title: `${f.label} (p.${f.page})`,
      text: f.caption,
    });
  }

  for (const e of doc.equations) {
    units.push({
      id: e.id,
      sourceType: 'document',
      citationKey: e.citationKey,
      title: `${e.label} (p.${e.page})`,
      text: `${e.description} ${e.latex}`,
    });
  }

  for (const c of clarifications) {
    units.push({
      id: c.id,
      sourceType: 'clarification',
      citationKey: c.url,
      title: `${c.title} (${c.providerName})`,
      text: `${c.term}: ${c.quote}`,
      tier: c.tier,
      confidenceLabel: c.confidenceLabel,
      viewLabel: c.viewLabel,
      url: c.url,
    });
  }

  return units;
}

/**
 * Hybrid BM25 + Embedding retrieval fused with Reciprocal Rank Fusion (RRF, k=60).
 */
export function answerGroundedQuestion(params: {
  question: string;
  doc: DocumentModel;
  clarifications: ClarificationSource[];
  scenes: StoryboardScene[];
}): QAResponse {
  const units = buildCorpus(params.doc, params.clarifications);
  const queryTokens = tokenize(params.question);

  if (queryTokens.length === 0) {
    return {
      question: params.question,
      answered: false,
      refusalText: EXACT_QA_REFUSAL,
      sentences: [],
      retrievedChunks: [],
    };
  }

  // BM25 scoring
  const N = units.length || 1;
  const docTokens = units.map((u) => tokenize(`${u.title} ${u.text}`));
  const avgdl = docTokens.reduce((sum, arr) => sum + arr.length, 0) / N || 1;
  const k1 = 1.5;
  const b = 0.75;

  const df = new Map<string, number>();
  for (const toks of docTokens) {
    const unique = new Set(toks);
    for (const t of unique) df.set(t, (df.get(t) ?? 0) + 1);
  }

  const bm25Scores = units.map((_, idx) => {
    const toks = docTokens[idx];
    const dl = toks.length || 1;
    const tfMap = new Map<string, number>();
    for (const t of toks) tfMap.set(t, (tfMap.get(t) ?? 0) + 1);

    let score = 0;
    for (const qt of queryTokens) {
      const f = tfMap.get(qt) ?? 0;
      if (f === 0) continue;
      const nq = df.get(qt) ?? 0;
      const idf = Math.log(1 + (N - nq + 0.5) / (nq + 0.5));
      score += idf * ((f * (k1 + 1)) / (f + k1 * (1 - b + (b * dl) / avgdl)));
    }
    return score;
  });

  // Dense embedding similarity
  const qVec = hashEmbedding(params.question);
  const embScores = units.map((u) => cosineSim(qVec, hashEmbedding(`${u.title} ${u.text}`)));

  // Require real lexical or high semantic overlap so off-topic questions cleanly refuse
  const maxBm25 = Math.max(...bm25Scores, 0);
  const maxEmb = Math.max(...embScores, 0);
  const overlapCount = units.reduce((best, _, idx) => {
    const set = new Set(docTokens[idx]);
    const hits = queryTokens.filter((qt) => set.has(qt)).length;
    return Math.max(best, hits);
  }, 0);

  if (maxBm25 < 0.35 && (overlapCount === 0 || maxEmb < 0.28)) {
    return {
      question: params.question,
      answered: false,
      refusalText: EXACT_QA_REFUSAL,
      sentences: [],
      retrievedChunks: [],
    };
  }

  const bm25Ranked = units
    .map((u, idx) => ({ idx, score: bm25Scores[idx] }))
    .sort((a, b2) => b2.score - a.score);
  const embRanked = units
    .map((u, idx) => ({ idx, score: embScores[idx] }))
    .sort((a, b2) => b2.score - a.score);

  const rrfK = 60;
  const rrfMap = new Map<number, number>();
  bm25Ranked.forEach((item, rank) => {
    rrfMap.set(item.idx, (rrfMap.get(item.idx) ?? 0) + 1 / (rrfK + rank + 1));
  });
  embRanked.forEach((item, rank) => {
    rrfMap.set(item.idx, (rrfMap.get(item.idx) ?? 0) + 1 / (rrfK + rank + 1));
  });

  // Document-first tie-breaking + Tier priority
  const topUnits = units
    .map((u, idx) => ({
      unit: u,
      bm25: bm25Scores[idx],
      emb: embScores[idx],
      rrf:
        (rrfMap.get(idx) ?? 0) +
        (u.sourceType === 'document' ? 0.002 : 0) +
        (u.tier === 1 ? 0.001 : 0),
    }))
    .filter((entry) => entry.bm25 > 0.1 || entry.emb > 0.2)
    .sort((a, b2) => b2.rrf - a.rrf)
    .slice(0, 4);

  if (topUnits.length === 0) {
    return {
      question: params.question,
      answered: false,
      refusalText: EXACT_QA_REFUSAL,
      sentences: [],
      retrievedChunks: [],
    };
  }

  const validCitations = buildValidCitationSet(params.doc, params.clarifications);
  const allowedNumbers = extractAllowedNumbers(params.doc, params.clarifications);

  const findSceneJump = (citationKey: string): { sceneId?: string; seconds?: number } => {
    const exact = params.scenes.find((s) => s.citations.includes(citationKey));
    if (exact) return { sceneId: exact.id, seconds: exact.startSeconds };
    const first = params.scenes[0];
    return first ? { sceneId: first.id, seconds: first.startSeconds } : {};
  };

  const sentences: QASentence[] = [];
  for (const item of topUnits.slice(0, 3)) {
    const u = item.unit;
    if (!validCitations.has(u.citationKey)) continue;
    const prefix =
      u.viewLabel === 'Differing view'
        ? `[Differing view] ${u.title}: `
        : u.confidenceLabel === 'lower confidence'
          ? `[Lower confidence · Tier 3] ${u.title}: `
          : '';
    const rawSentence = `${prefix}${u.text.split('|')[0].trim()}`;
    const trimmed = rawSentence.endsWith('.') ? rawSentence : `${rawSentence}.`;

    // Enforce number guard on every Q&A sentence
    if (findUngroundedNumbers(trimmed, allowedNumbers).length > 0) {
      continue;
    }

    const jump = findSceneJump(u.citationKey);
    sentences.push({
      text: trimmed,
      citations: [u.citationKey],
      jumpToSceneId: jump.sceneId,
      jumpToSeconds: jump.seconds,
    });
  }

  if (sentences.length === 0) {
    return {
      question: params.question,
      answered: false,
      refusalText: EXACT_QA_REFUSAL,
      sentences: [],
      retrievedChunks: [],
    };
  }

  return {
    question: params.question,
    answered: true,
    sentences,
    retrievedChunks: topUnits.map((item) => ({
      id: item.unit.id,
      sourceType: item.unit.sourceType,
      citationKey: item.unit.citationKey,
      title: item.unit.title,
      snippet: item.unit.text.slice(0, 180),
      rrfScore: Number(item.rrf.toFixed(4)),
      tier: item.unit.tier,
      confidenceLabel: item.unit.confidenceLabel,
      viewLabel: item.unit.viewLabel,
      url: item.unit.url,
    })),
  };
}
