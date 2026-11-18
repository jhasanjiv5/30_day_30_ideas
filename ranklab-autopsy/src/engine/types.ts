export type DatasetMode = 'movielens' | 'otto';

export type RetrieverSource = 'dense' | 'bm25' | 'covisit' | 'trending';

export interface CatalogItem {
  id: string;
  title: string;
  subtitle: string; // e.g. "1982 · Sci-Fi / Neo-Noir" or "Audio · Studio Monitors"
  year: number;
  category: string;
  tags: string[];
  embedding: number[]; // 12D normalized semantic/tag-genome vector
  popularity: number; // [0, 1]
  recency: number; // [0, 1]
  // Simulated historical serving position in past logs (1..10) & historical CTR inflation
  historicalAvgSlot: number;
  baseConversionRate: number; // used especially in OTTO funnel mode (click -> cart -> order)
  cartRate: number;
  orderGivenCartRate: number;
  coVisitNeighbors: Array<{ itemId: string; weight: number }>;
}

export interface UserProfile {
  id: string;
  label: string;
  persona: string;
  historySummary: string;
  truePreference: number[]; // 12D ground truth latent vector u*
  historyItemIds: string[]; // long-term interacted items
  preExperimentRate: number; // pre-period X_u covariate for CUPED
  sessionSeedCategory: string;
}

export interface SessionEvent {
  itemId: string;
  title: string;
  category: string;
  tags: string[];
  stepIndex: number;
  intentType: 'organic' | 'injected';
}

export interface ProvenanceEntry {
  source: RetrieverSource;
  rank: number;
  rawScore: number;
  rrfContribution: number;
}

export interface FeatureAttribution {
  longTermAffinity: number;
  sessionSimilarity: number;
  popularity: number;
  recency: number;
  positionBiasLeak: number; // positive in Naive, 0 in IPW
}

export interface RankedSlot {
  slot: number; // 1..10
  item: CatalogItem;
  provenance: ProvenanceEntry[];
  rrfScore: number;
  trueRelevance: number; // [0, 1] from known ground truth
  naiveScore: number; // [0, 1]
  ipwScore: number; // [0, 1]
  examinationProb: number; // P(E_k = 1) = 1 / k^eta
  simulatedClickProb: number;
  attribution: FeatureAttribution;
  mmrPenalty: number;
  droppedAtCurrentEf?: boolean;
}

export interface HnswFrontierPoint {
  efSearch: number;
  recallAt500: number; // [0, 1]
  p50LatencyMs: number;
  p99LatencyMs: number;
  distanceComputations: number;
  top10OverlapWithExact: number; // how many of exact top-10 survived
  droppedTitles: string[];
}

export interface DailyAbMetric {
  day: number;
  controlRate: number;
  treatmentRate: number;
  relativeLiftPct: number;
  ciLowPct: number;
  ciHighPct: number;
  noveltyComponentPct: number;
  steadyStatePct: number;
}

export interface AbTestSummary {
  dataset: DatasetMode;
  metricLabel: string; // "CTR / Session" or "Order Conversion / User"
  controlUsers: number;
  treatmentUsers: number;
  controlRate: number;
  treatmentRate: number;
  rawLiftPct: number;
  cupedLiftPct: number;
  ciLowPct: number;
  ciHighPct: number;
  varianceReductionPct: number;
  srmPValue: number;
  srmPassed: boolean;
  extraAnnualConversionsAt1M: number;
  dailySeries: DailyAbMetric[];
  propensityEta: number;
  srmBugActive: boolean;
}

export interface AutopsyResult {
  gateG: number;
  sessionCoherence: number;
  historyStrength: number;
  fusedQuery: number[];
  eLong: number[];
  eShort: number[];
  activeRanker: 'ipw' | 'naive';
  ipwSlots: RankedSlot[];
  naiveSlots: RankedSlot[];
  droppedVsMaxEf: CatalogItem[]; // items present in ef=512 top-10 that fell out at current ef
  frontier: HnswFrontierPoint[];
  currentFrontierPoint: HnswFrontierPoint;
  totalCandidatesBeforeRrf: number;
  uniqueRrfCandidates: number;
  ndcgAt10Naive: number;
  ndcgAt10Ipw: number;
}
