export interface GotraRecord {
  id: string;
  name_dev: string;
  name_roman: string;
  seq: number;
}

export interface MoolRecord {
  id: string;
  name_dev: string;
  name_roman: string;
  aka: string[];
  gotraIds: string[];
}

export interface VillageRecord {
  id: string;
  name_dev: string;
  name_roman: string;
}

export interface InferredMoolInfo {
  id: string;
  name_dev: string;
  name_roman: string;
  matchedFrom: 'village_roman' | 'village_dev' | 'aka';
  matchedTerm: string;
}

export interface PersonRecord {
  id: string;
  name_dev: string;
  name_roman: string;
  label: string;
  village_dev: string;
  village_roman: string;
  titles: string;
  source_ref: string;
  source_file: string;
  inferredMool: InferredMoolInfo | null;
  inferredGotras: GotraRecord[];
}

export interface DatasetMetadata {
  upstreamRepo: string;
  upstreamCommit: string;
  license: string;
  sourceCitation: string;
  generatedAt: string;
  counts: {
    persons: number;
    villages: number;
    mools: number;
    gotras: number;
    childOfEdges: number;
    siblingOfEdges: number;
    personsWithVillage: number;
    personsWithInferredMool: number;
    personsWithLineageLinks: number;
  };
}

export interface PanjiDataset {
  metadata: DatasetMetadata;
  gotras: GotraRecord[];
  mools: MoolRecord[];
  villages: VillageRecord[];
  persons: PersonRecord[];
  childOfEdges: [string, string][];
  siblingOfEdges: [string, string][];
}

export interface SearchFilters {
  village?: string;
  mool?: string;
  gotra?: string;
}

export interface QueryInterpretation {
  originalQuery: string;
  personTerms: string[];
  villageHint?: string;
  moolHint?: string;
  gotraHint?: string;
  strategy: 'deterministic' | 'gemini';
  note?: string;
}

export interface MatchEvidence {
  field: 'name' | 'village' | 'mool' | 'gotra' | 'title' | 'source_ref' | 'semantic';
  basis: 'source-backed' | 'inferred';
  reason: string;
}

export interface SearchCandidate {
  person: PersonRecord;
  score: number;
  similarity?: number;
  evidence: MatchEvidence[];
  connections: {
    parentCount: number;
    childCount: number;
    explicitSiblingCount: number;
    sharedParentSiblingCount: number;
    parentLabels?: string[];
    childLabels?: string[];
  };
}

export interface SearchAnswerPayload {
  mode: 'gemini' | 'deterministic';
  text: string;
  citedRecords: Array<{ id: string; label: string; source_ref: string }>;
}

export interface SearchResponse {
  query: string;
  interpretation: QueryInterpretation;
  appliedFilters: SearchFilters;
  totalMatches: number;
  candidates: SearchCandidate[];
  semanticSearchAvailable?: boolean;
  semanticSearchUsed?: boolean;
  semanticSearchError?: string;
  semanticSearchWarning?: string;
  answer?: SearchAnswerPayload;
}

export interface SemanticMatch {
  id: string;
  score: number;
}

export interface SimilarPeopleResponse {
  available: boolean;
  error?: string;
  warning?: string;
  candidates: SearchCandidate[];
}

export interface LineageNode {
  person: PersonRecord;
  role: 'focus' | 'ancestor' | 'descendant' | 'sibling';
  generationOffset: number;
  relationshipBasis: 'focus' | 'source-backed' | 'inferred-shared-parent';
}

export interface LineageEdge {
  from: string;
  to: string;
  type: 'child_of' | 'sibling_of' | 'inferred_sibling';
  basis: 'source-backed' | 'inferred';
}

export interface LineageGraph {
  focusPerson: PersonRecord;
  nodes: LineageNode[];
  edges: LineageEdge[];
  ancestorChainToOldest: PersonRecord[];
  truncated: boolean;
  notes: string[];
}

export interface FilterOption {
  value: string;
  label: string;
  secondaryLabel?: string;
  count: number;
}

export interface FilterOptionsPayload {
  villages: FilterOption[];
  mools: FilterOption[];
  gotras: FilterOption[];
  metadata: DatasetMetadata;
}

export interface AiExplanationPayload {
  mode: 'gemini' | 'deterministic';
  personId: string;
  summary: string;
  sourceBackedFacts: string[];
  inferredOrUncertain: string[];
  gapsAndLimitations: string[];
  citedRecords: Array<{ id: string; label: string; source_ref: string }>;
}

export interface HealthPayload {
  ok: boolean;
  neo4jConfigured: boolean;
  neo4jConnected: boolean;
  neo4jError?: string;
  aiAvailable: boolean;
  semanticSearchAvailable: boolean;
  semanticSearchError?: string;
  semanticSearchWarning?: string;
  semanticProfilesEmbedded: number;
  semanticProfilesTotal: number;
  counts: DatasetMetadata['counts'] | null;
}

export interface RelationshipPathStep {
  from: PersonRecord;
  to: PersonRecord;
  edgeType: 'CHILD_OF' | 'SIBLING_OF';
  direction: 'parent' | 'child' | 'sibling';
}

export interface RelationshipPathPayload {
  personA: PersonRecord;
  personB: PersonRecord;
  connected: boolean;
  hops: number;
  steps: RelationshipPathStep[];
  commonAncestors: PersonRecord[];
  summaryNote: string;
}

export interface MoolGotraItem {
  id: string;
  name_roman: string;
  name_dev: string;
  aka: string[];
  gotras: GotraRecord[];
  isCrossGotra: boolean;
  personCount: number;
}

export interface MoolsGotrasPayload {
  gotras: Array<GotraRecord & { moolCount: number; personCount: number }>;
  mools: MoolGotraItem[];
  crossGotraCount: number;
}

export interface TreeCoverageItem {
  root: PersonRecord;
  descendantCount: number;
  maxDepth: number;
}

export interface TreeCoveragePayload {
  trees: TreeCoverageItem[];
  totalRootsWithDescendants: number;
  totalConnectedPersons: number;
}
