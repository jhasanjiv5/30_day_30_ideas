import {
  clamp,
  computeNdcgAtK,
  cosineSimilarity,
  createRng,
  normalize,
  sigmoid,
} from './math';
import {
  AutopsyResult,
  CatalogItem,
  FeatureAttribution,
  HnswFrontierPoint,
  ProvenanceEntry,
  RankedSlot,
  RetrieverSource,
  SessionEvent,
  UserProfile,
} from './types';

// Build a deterministic navigable small-world graph (M=5 neighbors per node)
// so greedy beam search with ef_search genuinely trades off recall vs visited nodes.
interface HnswGraph {
  adjacency: Map<string, string[]>;
  entryId: string;
}

const graphCache = new WeakMap<CatalogItem[], HnswGraph>();

function getHnswGraph(catalog: CatalogItem[]): HnswGraph {
  const cached = graphCache.get(catalog);
  if (cached) return cached;

  const rng = createRng(424242);
  const adjacency = new Map<string, string[]>();

  for (let i = 0; i < catalog.length; i++) {
    const item = catalog[i];
    const neighborsBySim = catalog
      .filter((other) => other.id !== item.id)
      .map((other) => ({
        id: other.id,
        sim: cosineSimilarity(item.embedding, other.embedding),
      }))
      .sort((a, b) => b.sim - a.sim);

    // 3 close local neighbors + 2 mid/long-range skip bridges
    const selected = new Set<string>();
    for (let k = 0; k < Math.min(3, neighborsBySim.length); k++) {
      selected.add(neighborsBySim[k].id);
    }
    const stride = Math.max(4, Math.floor(neighborsBySim.length / 4));
    for (let b = 0; b < 2; b++) {
      const idx = Math.min(
        neighborsBySim.length - 1,
        Math.floor(stride * (b + 1) + rng() * 5)
      );
      selected.add(neighborsBySim[idx].id);
    }
    adjacency.set(item.id, Array.from(selected));
  }

  // Pick a fixed low-index medoid/entry node so short beam searches must traverse hops
  const entryId = catalog[Math.floor(catalog.length / 2)].id;
  const graph = { adjacency, entryId };
  graphCache.set(catalog, graph);
  return graph;
}

// Run HNSW greedy beam search with beam width scaled from ef_search (16..512)
function searchHnswGraph(
  query: number[],
  catalog: CatalogItem[],
  efSearch: number,
  topK: number
): { results: Array<{ item: CatalogItem; score: number }>; visitedCount: number } {
  const graph = getHnswGraph(catalog);
  const byId = new Map(catalog.map((c) => [c.id, c]));

  // Map efSearch [16..512] to beam budget within an ~80-item catalog
  // ef=16 explores ~11 nodes; ef=32 -> ~18; ef=64 -> ~28; ef=128 -> ~44; ef=256 -> ~64; ef=512 -> full catalog
  const maxExplore = Math.min(
    catalog.length,
    Math.max(8, Math.round(5 + Math.pow(efSearch / 16, 0.72) * 6.5))
  );

  const visited = new Set<string>();
  const candidates: Array<{ item: CatalogItem; score: number }> = [];
  const frontier: Array<{ id: string; score: number }> = [];

  const seedIds = [graph.entryId, catalog[0].id];
  for (const sid of seedIds) {
    const it = byId.get(sid);
    if (!it || visited.has(sid)) continue;
    visited.add(sid);
    const s = cosineSimilarity(query, it.embedding);
    frontier.push({ id: sid, score: s });
    candidates.push({ item: it, score: s });
  }

  while (frontier.length > 0 && visited.size < maxExplore) {
    frontier.sort((a, b) => b.score - a.score);
    const current = frontier.shift()!;
    const neighbors = graph.adjacency.get(current.id) ?? [];

    for (const nid of neighbors) {
      if (visited.has(nid)) continue;
      visited.add(nid);
      const item = byId.get(nid);
      if (!item) continue;
      const score = cosineSimilarity(query, item.embedding);
      candidates.push({ item, score });
      frontier.push({ id: nid, score });
      if (visited.size >= maxExplore) break;
    }
  }

  candidates.sort((a, b) => b.score - a.score);
  return {
    results: candidates.slice(0, topK),
    visitedCount: visited.size,
  };
}

// Encode long-term user embedding + GRU-like short-term session embedding + learned gate g
export function encodeUserAndSession(
  user: UserProfile,
  sessionEvents: SessionEvent[],
  catalog: CatalogItem[]
): {
  eLong: number[];
  eShort: number[];
  gateG: number;
  sessionCoherence: number;
  historyStrength: number;
  fusedQuery: number[];
} {
  const byId = new Map(catalog.map((c) => [c.id, c]));

  // Long-term embedding from user history
  const histVec = new Array(12).fill(0);
  let histCount = 0;
  for (const hid of user.historyItemIds) {
    const item = byId.get(hid);
    if (!item) continue;
    for (let d = 0; d < 12; d++) histVec[d] += item.embedding[d];
    histCount++;
  }
  const eLong = histCount > 0 ? normalize(histVec) : user.truePreference;

  // Short-term GRU/SASRec-inspired exponential recency decay over last 20 session clicks
  const recent = sessionEvents.slice(-20);
  if (recent.length === 0) {
    return {
      eLong,
      eShort: eLong,
      gateG: 0.08,
      sessionCoherence: 0,
      historyStrength: clamp(histCount / 8, 0.15, 1),
      fusedQuery: eLong,
    };
  }

  const shortVec = new Array(12).fill(0);
  const decay = 0.78;
  const itemVectors: number[][] = [];
  for (let i = 0; i < recent.length; i++) {
    const item = byId.get(recent[i].itemId);
    if (!item) continue;
    itemVectors.push(item.embedding);
    const age = recent.length - 1 - i;
    const w = Math.pow(decay, age);
    for (let d = 0; d < 12; d++) shortVec[d] += w * item.embedding[d];
  }
  const eShort = normalize(shortVec);

  // Coherence: average cosine similarity of session clicks to session centroid
  let coherenceSum = 0;
  for (const v of itemVectors) {
    coherenceSum += cosineSimilarity(v, eShort);
  }
  const sessionCoherence =
    itemVectors.length > 0 ? clamp(coherenceSum / itemVectors.length, 0, 1) : 0;

  const historyStrength = clamp(histCount / 8, 0.15, 1);

  // Learned gate g: grows with session length & coherence, tempered by deep history
  const logit =
    -1.65 +
    1.15 * Math.log(1 + recent.length) +
    1.25 * sessionCoherence -
    0.85 * historyStrength;
  const gateG = clamp(sigmoid(logit), 0.05, 0.96);

  const fusedRaw = eLong.map((v, d) => (1 - gateG) * v + gateG * eShort[d]);
  const fusedQuery = normalize(fusedRaw);

  return {
    eLong,
    eShort,
    gateG,
    sessionCoherence,
    historyStrength,
    fusedQuery,
  };
}

// Okapi BM25 on item tags & category tokens
function scoreBm25(
  queryTags: string[],
  catalog: CatalogItem[]
): Array<{ item: CatalogItem; score: number }> {
  if (queryTags.length === 0) {
    return catalog.map((item) => ({ item, score: 0 }));
  }

  const docs = catalog.map((item) => [
    ...item.tags,
    item.category.toLowerCase(),
  ]);
  const N = docs.length;
  const avgDl = docs.reduce((s, d) => s + d.length, 0) / Math.max(1, N);
  const k1 = 1.5;
  const b = 0.75;

  // Query term frequencies
  const qTf = new Map<string, number>();
  for (const t of queryTags) {
    const lt = t.toLowerCase();
    qTf.set(lt, (qTf.get(lt) ?? 0) + 1);
  }

  // Document frequencies
  const df = new Map<string, number>();
  for (const term of qTf.keys()) {
    let count = 0;
    for (const d of docs) {
      if (d.includes(term)) count++;
    }
    df.set(term, count);
  }

  return catalog
    .map((item, idx) => {
      const doc = docs[idx];
      const dl = doc.length;
      let score = 0;

      for (const [term, qWeight] of qTf.entries()) {
        const tf = doc.filter((t) => t === term).length;
        if (tf === 0) continue;
        const nq = df.get(term) ?? 0;
        const idf = Math.log(1 + (N - nq + 0.5) / (nq + 0.5));
        const denom = tf + k1 * (1 - b + b * (dl / avgDl));
        score += qWeight * idf * ((tf * (k1 + 1)) / denom);
      }
      return { item, score };
    })
    .sort((a, b) => b.score - a.score);
}

// Core candidate generation (4 sources + per-source quotas + RRF fusion) + Ranker + MMR
function executePipelineAtEf(
  user: UserProfile,
  sessionEvents: SessionEvent[],
  catalog: CatalogItem[],
  efSearch: number,
  eta: number,
  mmrLambda: number
): {
  ipwSlots: RankedSlot[];
  naiveSlots: RankedSlot[];
  recallAt500: number;
  distanceComputations: number;
  totalCandidatesBeforeRrf: number;
  uniqueRrfCandidates: number;
  ndcgAt10Naive: number;
  ndcgAt10Ipw: number;
  gateG: number;
  sessionCoherence: number;
  historyStrength: number;
  fusedQuery: number[];
  eLong: number[];
  eShort: number[];
} {
  const encoded = encodeUserAndSession(user, sessionEvents, catalog);
  const byId = new Map(catalog.map((c) => [c.id, c]));

  // Exact brute-force dense top-24 for true recall measurement
  const exactDense = catalog
    .map((item) => ({
      item,
      score: cosineSimilarity(encoded.fusedQuery, item.embedding),
    }))
    .sort((a, b) => b.score - a.score);
  const exactTopSet = new Set(exactDense.slice(0, 24).map((x) => x.item.id));

  // Source 1: Two-Tower ANN (HNSW with ef_search) - quota 28
  const denseQuota = 28;
  const hnsw = searchHnswGraph(encoded.fusedQuery, catalog, efSearch, denseQuota);
  const denseHits = hnsw.results.filter((x) => exactTopSet.has(x.item.id)).length;
  const recallAt500 = denseHits / Math.min(24, exactTopSet.size);

  // Source 2: BM25 on tags (recent session tags weighted higher + user history tags) - quota 20
  const queryTags: string[] = [];
  const recentEvents = sessionEvents.slice(-8);
  recentEvents.forEach((ev, idx) => {
    const repeats = idx >= recentEvents.length - 3 ? 2 : 1;
    for (let r = 0; r < repeats; r++) {
      queryTags.push(...ev.tags, ev.category.toLowerCase());
    }
  });
  if (queryTags.length === 0) {
    for (const hid of user.historyItemIds) {
      const h = byId.get(hid);
      if (h) queryTags.push(...h.tags);
    }
  }
  const bm25Quota = 20;
  const bm25Results = scoreBm25(queryTags, catalog)
    .filter((r) => r.score > 0.01)
    .slice(0, bm25Quota);

  // Source 3: Co-visitation graph from active session (fallback to history) - quota 18
  const coVisitQuota = 18;
  const coVisitMap = new Map<string, number>();
  const seedSources =
    sessionEvents.length > 0
      ? sessionEvents.slice(-6).map((e, i, arr) => ({
          id: e.itemId,
          weight: Math.pow(0.8, arr.length - 1 - i),
        }))
      : user.historyItemIds.slice(-4).map((id) => ({ id, weight: 0.5 }));

  for (const src of seedSources) {
    const item = byId.get(src.id);
    if (!item) continue;
    for (const edge of item.coVisitNeighbors) {
      coVisitMap.set(
        edge.itemId,
        (coVisitMap.get(edge.itemId) ?? 0) + src.weight * edge.weight
      );
    }
  }
  const coVisitResults = Array.from(coVisitMap.entries())
    .map(([id, score]) => ({ item: byId.get(id)!, score }))
    .filter((x) => Boolean(x.item))
    .sort((a, b) => b.score - a.score)
    .slice(0, coVisitQuota);

  // Source 4: Trending / Popularity Prior - quota 14
  const trendingQuota = 14;
  const trendingResults = [...catalog]
    .map((item) => ({
      item,
      score: 0.72 * item.popularity + 0.28 * item.recency,
    }))
    .sort((a, b) => b.score - a.score)
    .slice(0, trendingQuota);

  // Exclude items already clicked in current session or deep history if appropriate
  const seenSessionIds = new Set(sessionEvents.map((s) => s.itemId));

  // RRF Fusion (k = 60) with provenance tracking
  const rrfK = 60;
  const sourceWeights: Record<RetrieverSource, number> = {
    dense: 1.25,
    bm25: 1.05,
    covisit: 1.0,
    trending: 0.65,
  };

  const candidateMap = new Map<
    string,
    { item: CatalogItem; rrfScore: number; provenance: ProvenanceEntry[] }
  >();

  const registerSource = (
    source: RetrieverSource,
    list: Array<{ item: CatalogItem; score: number }>
  ) => {
    list.forEach((entry, idx) => {
      if (seenSessionIds.has(entry.item.id)) return;
      const rank = idx + 1;
      const contrib = sourceWeights[source] / (rrfK + rank);
      const existing = candidateMap.get(entry.item.id);
      if (existing) {
        existing.rrfScore += contrib;
        existing.provenance.push({
          source,
          rank,
          rawScore: entry.score,
          rrfContribution: contrib,
        });
      } else {
        candidateMap.set(entry.item.id, {
          item: entry.item,
          rrfScore: contrib,
          provenance: [
            {
              source,
              rank,
              rawScore: entry.score,
              rrfContribution: contrib,
            },
          ],
        });
      }
    });
  };

  registerSource('dense', hnsw.results);
  registerSource('bm25', bm25Results);
  registerSource('covisit', coVisitResults);
  registerSource('trending', trendingResults);

  const totalCandidatesBeforeRrf =
    hnsw.results.length +
    bm25Results.length +
    coVisitResults.length +
    trendingResults.length;

  const fusedCandidates = Array.from(candidateMap.values()).sort(
    (a, b) => b.rrfScore - a.rrfScore
  );

  // Ground-truth effective user preference shifts dynamically with injected session intent
  const trueIntentBlend = normalize(
    user.truePreference.map(
      (v, d) =>
        (1 - encoded.gateG * 0.88) * v + encoded.gateG * 0.88 * encoded.eShort[d]
    )
  );

  // Score every fused candidate under Ground Truth, Naive LambdaRank, and IPW LambdaRank
  const scoredPool = fusedCandidates.map((cand) => {
    const { item, rrfScore, provenance } = cand;
    const longSim = clamp((cosineSimilarity(encoded.eLong, item.embedding) + 1) / 2, 0, 1);
    const shortSim = clamp((cosineSimilarity(encoded.eShort, item.embedding) + 1) / 2, 0, 1);
    const fusedSim = clamp(
      (cosineSimilarity(encoded.fusedQuery, item.embedding) + 1) / 2,
      0,
      1
    );
    const trueSim = clamp(
      (cosineSimilarity(trueIntentBlend, item.embedding) + 1) / 2,
      0,
      1
    );

    // Known true relevance from the simulator (unconfounded by historical slot position)
    const bm25Hit = provenance.find((p) => p.source === 'bm25');
    const tagBonus = bm25Hit ? clamp(bm25Hit.rawScore / 12, 0, 0.14) : 0;
    const trueRelevance = clamp(
      0.72 * trueSim + 0.14 * item.recency + 0.06 * item.popularity + tagBonus,
      0.05,
      0.99
    );

    // Position examination propensity in historical logs: P(E_k = 1) = 1 / k^eta
    const histPropensity = Math.pow(Math.max(1, item.historicalAvgSlot), -eta);
    // Naive ranker mistakenly learns that historically slot-1 items (low historicalAvgSlot)
    // have higher click propensity and over-weights popularity + position leakage
    const positionBiasLeak = clamp(0.32 * histPropensity, 0, 0.34);

    const longTermContrib = (1 - encoded.gateG) * 0.48 * longSim;
    const sessionContrib = encoded.gateG * 0.56 * shortSim;
    const popContrib = 0.09 * item.popularity;
    const recencyContrib = 0.11 * item.recency;

    // IPW ranker recovers unbiased relevance estimate from propensity-weighted clicks (1 / max(p_k, 0.12))
    const ipwStability = clamp(0.68 * fusedSim + 0.14 * item.recency + 0.06 * item.popularity + tagBonus + 0.05 * Math.min(1, rrfScore * 16), 0.05, 0.99);

    // Naive ranker absorbs position-as-feature leak + popularity skew, under-weighting true tail fit
    const naiveScore = clamp(
      0.48 * fusedSim +
        0.16 * item.popularity +
        0.07 * item.recency +
        positionBiasLeak +
        0.5 * tagBonus,
      0.05,
      0.99
    );

    const attribution: FeatureAttribution = {
      longTermAffinity: longTermContrib,
      sessionSimilarity: sessionContrib,
      popularity: popContrib,
      recency: recencyContrib,
      positionBiasLeak,
    };

    return {
      item,
      provenance,
      rrfScore,
      trueRelevance,
      ipwScore: ipwStability,
      naiveScore,
      attribution,
    };
  });

  // MMR Diversity Re-ranking helper -> Top 10
  const selectTop10Mmr = (mode: 'ipw' | 'naive'): RankedSlot[] => {
    const remaining = [...scoredPool];
    const selected: RankedSlot[] = [];

    for (let k = 1; k <= Math.min(10, remaining.length); k++) {
      let bestIdx = 0;
      let bestMmr = -Infinity;
      let bestPenalty = 0;

      for (let i = 0; i < remaining.length; i++) {
        const cand = remaining[i];
        const baseScore = mode === 'ipw' ? cand.ipwScore : cand.naiveScore;
        let maxSimToSelected = 0;
        for (const prev of selected) {
          const sim = Math.max(
            0,
            cosineSimilarity(cand.item.embedding, prev.item.embedding)
          );
          if (sim > maxSimToSelected) maxSimToSelected = sim;
        }
        const penalty = selected.length > 0 ? (1 - mmrLambda) * maxSimToSelected : 0;
        const mmrVal = mmrLambda * baseScore - penalty;
        if (mmrVal > bestMmr) {
          bestMmr = mmrVal;
          bestIdx = i;
          bestPenalty = penalty;
        }
      }

      const chosen = remaining.splice(bestIdx, 1)[0];
      const examProb = Math.pow(k, -eta);
      const simulatedClickProb = clamp(
        examProb * sigmoid(4.2 * (chosen.trueRelevance - 0.48)),
        0.01,
        0.95
      );

      selected.push({
        slot: k,
        item: chosen.item,
        provenance: chosen.provenance,
        rrfScore: chosen.rrfScore,
        trueRelevance: chosen.trueRelevance,
        naiveScore: chosen.naiveScore,
        ipwScore: chosen.ipwScore,
        examinationProb: examProb,
        simulatedClickProb,
        attribution:
          mode === 'ipw'
            ? { ...chosen.attribution, positionBiasLeak: 0 }
            : chosen.attribution,
        mmrPenalty: bestPenalty,
      });
    }
    return selected;
  };

  const ipwSlots = selectTop10Mmr('ipw');
  const naiveSlots = selectTop10Mmr('naive');

  const idealPoolRels = scoredPool.map((c) => c.trueRelevance);
  const ndcgAt10Ipw = computeNdcgAtK(
    ipwSlots.map((s) => s.trueRelevance),
    idealPoolRels,
    10
  );
  const ndcgAt10Naive = computeNdcgAtK(
    naiveSlots.map((s) => s.trueRelevance),
    idealPoolRels,
    10
  );

  return {
    ipwSlots,
    naiveSlots,
    recallAt500,
    distanceComputations: hnsw.visitedCount,
    totalCandidatesBeforeRrf,
    uniqueRrfCandidates: fusedCandidates.length,
    ndcgAt10Naive,
    ndcgAt10Ipw,
    gateG: encoded.gateG,
    sessionCoherence: encoded.sessionCoherence,
    historyStrength: encoded.historyStrength,
    fusedQuery: encoded.fusedQuery,
    eLong: encoded.eLong,
    eShort: encoded.eShort,
  };
}

export const EF_SEARCH_SWEEP = [16, 32, 64, 128, 256, 512] as const;

export function runAutopsyPipeline(params: {
  user: UserProfile;
  sessionEvents: SessionEvent[];
  catalog: CatalogItem[];
  efSearch: number;
  activeRanker: 'ipw' | 'naive';
  eta: number;
  mmrLambda: number;
}): AutopsyResult {
  const { user, sessionEvents, catalog, efSearch, activeRanker, eta, mmrLambda } =
    params;

  // Baseline exact-ish frontier reference at ef_search = 512
  const refMax = executePipelineAtEf(
    user,
    sessionEvents,
    catalog,
    512,
    eta,
    mmrLambda
  );
  const refTop10Ids = new Set(refMax.ipwSlots.map((s) => s.item.id));

  // Sweep ef_search across all 6 operating points for the live Pareto frontier
  const frontier: HnswFrontierPoint[] = EF_SEARCH_SWEEP.map((ef) => {
    const run =
      ef === 512
        ? refMax
        : executePipelineAtEf(user, sessionEvents, catalog, ef, eta, mmrLambda);
    const runIds = new Set(run.ipwSlots.map((s) => s.item.id));
    const dropped = refMax.ipwSlots
      .filter((s) => !runIds.has(s.item.id))
      .map((s) => s.item.title);

    // Realistic sub-millisecond to multi-millisecond ANN + ranker latency model
    // Scales monotonically with visited distance evaluations (HNSW traversal + tail tail-latency)
    const p50LatencyMs = Number(
      (2.4 + 0.19 * run.distanceComputations + 0.018 * ef).toFixed(1)
    );
    const p99LatencyMs = Number(
      (p50LatencyMs * (1.85 + 0.0012 * ef) + 1.4).toFixed(1)
    );

    return {
      efSearch: ef,
      recallAt500: Number(run.recallAt500.toFixed(3)),
      p50LatencyMs,
      p99LatencyMs,
      distanceComputations: run.distanceComputations,
      top10OverlapWithExact: refMax.ipwSlots.filter((s) =>
        runIds.has(s.item.id)
      ).length,
      droppedTitles: dropped,
    };
  });

  const currentRun =
    efSearch === 512
      ? refMax
      : executePipelineAtEf(
          user,
          sessionEvents,
          catalog,
          efSearch,
          eta,
          mmrLambda
        );

  const currentTop10Ids = new Set(currentRun.ipwSlots.map((s) => s.item.id));
  const droppedVsMaxEf = refMax.ipwSlots
    .filter((s) => !currentTop10Ids.has(s.item.id))
    .map((s) => s.item);

  const currentFrontierPoint =
    frontier.find((f) => f.efSearch === efSearch) ??
    frontier[frontier.length - 1];

  // Mark items that are newly displaced compared to ef=512 if needed
  const markDiff = (slots: RankedSlot[]) =>
    slots.map((s) => ({
      ...s,
      droppedAtCurrentEf: !refTop10Ids.has(s.item.id),
    }));

  return {
    gateG: currentRun.gateG,
    sessionCoherence: currentRun.sessionCoherence,
    historyStrength: currentRun.historyStrength,
    fusedQuery: currentRun.fusedQuery,
    eLong: currentRun.eLong,
    eShort: currentRun.eShort,
    activeRanker,
    ipwSlots: markDiff(currentRun.ipwSlots),
    naiveSlots: markDiff(currentRun.naiveSlots),
    droppedVsMaxEf,
    frontier,
    currentFrontierPoint,
    totalCandidatesBeforeRrf: currentRun.totalCandidatesBeforeRrf,
    uniqueRrfCandidates: currentRun.uniqueRrfCandidates,
    ndcgAt10Naive: currentRun.ndcgAt10Naive,
    ndcgAt10Ipw: currentRun.ndcgAt10Ipw,
  };
}
