import neo4j, { type Driver } from 'neo4j-driver';
import {
  containsDevanagari,
  foldIastToAscii,
  normalizeDevanagari,
  phoneticRomanKey,
} from '../src/lib/normalize.ts';
import { parseQueryDeterministically, type VocabularyIndex } from '../src/lib/queryParser.ts';
import { isGeminiConfigured } from './ai.ts';
import { VECTOR_INDEX_NAME } from './embeddings.ts';
import type {
  DatasetMetadata,
  FilterOption,
  FilterOptionsPayload,
  GotraRecord,
  HealthPayload,
  InferredMoolInfo,
  LineageEdge,
  LineageGraph,
  LineageNode,
  MatchEvidence,
  MoolGotraItem,
  MoolsGotrasPayload,
  PersonRecord,
  QueryInterpretation,
  RelationshipPathPayload,
  RelationshipPathStep,
  SearchCandidate,
  SearchFilters,
  SearchResponse,
  SemanticMatch,
  TreeCoverageItem,
  TreeCoveragePayload,
} from '../src/types/panji.ts';

export class Neo4jUnavailableError extends Error {
  readonly code: 'NEO4J_NOT_CONFIGURED' | 'NEO4J_UNAVAILABLE';

  constructor(code: 'NEO4J_NOT_CONFIGURED' | 'NEO4J_UNAVAILABLE', message: string) {
    super(message);
    this.name = 'Neo4jUnavailableError';
    this.code = code;
  }
}

export interface CypherRunner {
  runRead(cypher: string, params?: Record<string, unknown>): Promise<Record<string, unknown>[]>;
  verifyConnectivity(): Promise<void>;
  close(): Promise<void>;
}

export interface PanjiRepository {
  checkHealth(): Promise<Omit<HealthPayload, 'ok' | 'aiAvailable'>>;
  getGotraNames(): Promise<string[]>;
  getFilterOptions(): Promise<FilterOptionsPayload>;
  searchPersons(
    rawQuery: string,
    filters?: SearchFilters,
    customInterpretation?: QueryInterpretation,
    limit?: number,
    semanticMatches?: SemanticMatch[]
  ): Promise<SearchResponse>;
  findSemanticMatches(embedding: number[], limit?: number): Promise<SemanticMatch[]>;
  getSimilarPersons(personId: string, limit?: number): Promise<SearchCandidate[] | null>;
  getLineage(personId: string): Promise<LineageGraph | null>;
  findShortestRelationship(fromId: string, toId: string): Promise<RelationshipPathPayload | null>;
  getMoolsAndGotras(): Promise<MoolsGotrasPayload>;
  getTreeCoverage(limit?: number): Promise<TreeCoveragePayload>;
  getAnswerContextByIds(ids: string[]): Promise<SearchCandidate[]>;
}

export function isPlaceholderValue(value: string): boolean {
  const v = value.trim();
  if (!v) return true;
  return (
    /YOUR_[A-Z0-9_]+/i.test(v) ||
    /<[^>]+>/.test(v) ||
    /your-instance|your-password|placeholder|change_me|example\.com/i.test(v)
  );
}

export function isNeo4jConfigured(): boolean {
  const uri = (process.env.NEO4J_URI || '').trim();
  const user = (process.env.NEO4J_USERNAME || '').trim();
  const pass = (process.env.NEO4J_PASSWORD || '').trim();
  if (!uri || !user || !pass) return false;
  if (isPlaceholderValue(uri) || isPlaceholderValue(pass)) return false;
  return true;
}

function normalizeValue(val: unknown): unknown {
  if (val === null || val === undefined) return val;
  if (neo4j.isInt(val)) {
    return val.toNumber();
  }
  if (Array.isArray(val)) {
    return val.map(normalizeValue);
  }
  if (typeof val === 'object') {
    const obj = val as Record<string, unknown>;
    if ('properties' in obj && typeof obj.properties === 'object' && obj.properties !== null) {
      return normalizeValue(obj.properties);
    }
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(obj)) {
      out[k] = normalizeValue(v);
    }
    return out;
  }
  return val;
}

export function createNeo4jRunnerFromEnv(): CypherRunner | null {
  if (!isNeo4jConfigured()) return null;
  const uri = process.env.NEO4J_URI!.trim();
  const username = process.env.NEO4J_USERNAME!.trim();
  const password = process.env.NEO4J_PASSWORD!.trim();
  const database = (process.env.NEO4J_DATABASE || 'neo4j').trim();

  const driver: Driver = neo4j.driver(uri, neo4j.auth.basic(username, password), {
    disableLosslessIntegers: true,
    connectionTimeout: 8000,
  });

  return {
    async verifyConnectivity() {
      await driver.verifyConnectivity({ database });
    },
    async runRead(cypher: string, params: Record<string, unknown> = {}) {
      const session = driver.session({
        database,
        defaultAccessMode: neo4j.session.READ,
      });
      try {
        const result = await session.executeRead((tx) => tx.run(cypher, params));
        return result.records.map((rec) => {
          const row: Record<string, unknown> = {};
          for (const key of rec.keys) {
            row[String(key)] = normalizeValue(rec.get(key));
          }
          return row;
        });
      } finally {
        await session.close();
      }
    },
    async close() {
      await driver.close();
    },
  };
}

function toNum(v: unknown): number {
  if (typeof v === 'number') return v;
  if (neo4j.isInt(v)) return v.toNumber();
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
}

function mapGotras(raw: unknown): GotraRecord[] {
  if (!Array.isArray(raw)) return [];
  const items: GotraRecord[] = [];
  for (const g of raw) {
    if (!g || typeof g !== 'object') continue;
    const obj = g as Record<string, unknown>;
    if (!obj.id) continue;
    items.push({
      id: String(obj.id),
      name_dev: String(obj.name_dev || ''),
      name_roman: String(obj.name_roman || ''),
      seq: toNum(obj.seq),
    });
  }
  return items.sort((a, b) => a.seq - b.seq);
}

function mapInferredMool(
  rawMool: unknown,
  rawEdge: unknown
): InferredMoolInfo | null {
  if (!rawMool || typeof rawMool !== 'object') return null;
  const m = rawMool as Record<string, unknown>;
  if (!m.id) return null;
  const edge = rawEdge && typeof rawEdge === 'object' ? (rawEdge as Record<string, unknown>) : {};
  const matchedFromRaw = String(edge.matchedFrom || 'village_roman');
  const matchedFrom: InferredMoolInfo['matchedFrom'] =
    matchedFromRaw === 'aka' || matchedFromRaw === 'village_dev'
      ? matchedFromRaw
      : 'village_roman';
  return {
    id: String(m.id),
    name_dev: String(m.name_dev || ''),
    name_roman: String(m.name_roman || ''),
    matchedFrom,
    matchedTerm: String(edge.matchedTerm || m.name_roman || ''),
  };
}

function mapPersonRecord(
  rawNode: unknown,
  rawMool: unknown = null,
  rawEdge: unknown = null,
  rawGotras: unknown = []
): PersonRecord {
  const n = (rawNode || {}) as Record<string, unknown>;
  const id = String(n.id || '');
  const name_dev = String(n.name_dev || '');
  const name_roman = String(n.name_roman || '');
  return {
    id,
    name_dev,
    name_roman,
    label: String(n.label || name_roman || name_dev || id),
    village_dev: String(n.village_dev || ''),
    village_roman: String(n.village_roman || ''),
    titles: String(n.titles || ''),
    source_ref: String(n.source_ref || ''),
    source_file: String(n.source_file || ''),
    inferredMool: mapInferredMool(rawMool, rawEdge),
    inferredGotras: mapGotras(rawGotras),
  };
}

function scoreFieldMatch(
  term: string,
  targetRoman: string,
  targetDev: string
): { score: number; matchType: 'exact' | 'prefix' | 'substring' | 'phonetic' } | null {
  const cleanTerm = term.trim();
  if (!cleanTerm) return null;

  if (containsDevanagari(cleanTerm)) {
    const qDev = normalizeDevanagari(cleanTerm);
    const tDev = normalizeDevanagari(targetDev);
    if (!qDev || !tDev) return null;
    if (tDev === qDev) return { score: 100, matchType: 'exact' };
    if (tDev.startsWith(qDev)) return { score: 85, matchType: 'prefix' };
    if (tDev.includes(qDev)) return { score: 65, matchType: 'substring' };
    return null;
  }

  const qFold = foldIastToAscii(cleanTerm);
  const tFold = foldIastToAscii(targetRoman);
  if (!qFold || !tFold) return null;

  if (tFold === qFold) return { score: 100, matchType: 'exact' };
  const words = tFold.split(' ');
  if (words.some((w) => w === qFold)) return { score: 92, matchType: 'exact' };
  if (tFold.startsWith(qFold) || words.some((w) => w.startsWith(qFold))) {
    return { score: 80, matchType: 'prefix' };
  }
  if (tFold.includes(qFold)) return { score: 62, matchType: 'substring' };

  const qPhon = phoneticRomanKey(cleanTerm);
  const tPhon = phoneticRomanKey(targetRoman);
  if (qPhon && tPhon) {
    if (tPhon === qPhon) return { score: 78, matchType: 'phonetic' };
    const pWords = tPhon.split(' ');
    if (pWords.some((w) => w === qPhon)) return { score: 74, matchType: 'phonetic' };
    if (tPhon.includes(qPhon)) return { score: 56, matchType: 'phonetic' };
  }

  return null;
}

const DEFAULT_LICENSE = 'Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)';
const DEFAULT_CITATION =
  'Thakur, Gajendra; Jha, Nagendra Kumar; Jha, Panjikar Vidyanand. Genome Mapping (450 A.D. to 2009 A.D.) — Mithilak Panji Prabandh, Vol. I–III. Shruti Publication, New Delhi, 2009. ISBN 978-81-907729-6-9.';

export class Neo4jRepository implements PanjiRepository {
  private readonly runner: CypherRunner | null;

  constructor(runner: CypherRunner | null) {
    this.runner = runner;
  }

  private requireRunner(): CypherRunner {
    if (!this.runner) {
      throw new Neo4jUnavailableError(
        'NEO4J_NOT_CONFIGURED',
        'Neo4j is not configured. Set NEO4J_URI, NEO4J_USERNAME, and NEO4J_PASSWORD on the server and load the upstream dataset with npm run neo4j:load.'
      );
    }
    return this.runner;
  }

  private async runReadSafe(
    cypher: string,
    params: Record<string, unknown> = {}
  ): Promise<Record<string, unknown>[]> {
    const runner = this.requireRunner();
    try {
      return await runner.runRead(cypher, params);
    } catch (err) {
      if (err instanceof Neo4jUnavailableError) throw err;
      throw new Neo4jUnavailableError(
        'NEO4J_UNAVAILABLE',
        `Neo4j query failed: ${(err as Error).message}`
      );
    }
  }

  async checkHealth(): Promise<Omit<HealthPayload, 'ok' | 'aiAvailable'>> {
    if (!this.runner) {
      return {
        neo4jConfigured: false,
        neo4jConnected: false,
        neo4jError:
          'NEO4J_URI, NEO4J_USERNAME, and NEO4J_PASSWORD are not set on the server.',
        semanticSearchAvailable: false,
        semanticSearchError: 'Configure Neo4j and Gemini embeddings to enable semantic search.',
        semanticProfilesEmbedded: 0,
        semanticProfilesTotal: 0,
        counts: null,
      };
    }

    try {
      await this.runner.verifyConnectivity();
      const rows = await this.runner.runRead(`
        RETURN
          COUNT { (p:Person) } AS persons,
          COUNT { (v:Village) } AS villages,
          COUNT { (m:Mool) } AS mools,
          COUNT { (g:Gotra) } AS gotras,
          COUNT { (:Person)-[:CHILD_OF]->(:Person) } AS childOfEdges,
          COUNT { (:Person)-[:SIBLING_OF]->(:Person) } AS siblingOfEdges,
          COUNT { (p:Person) WHERE p.village_roman <> '' OR p.village_dev <> '' } AS personsWithVillage,
          COUNT { (p:Person)-[:OF_MOOL_GUESS]->(:Mool) } AS personsWithInferredMool,
          COUNT { (p:Person) WHERE EXISTS { (p)-[:CHILD_OF|SIBLING_OF]-() } } AS personsWithLineageLinks
      `);
      const r = rows[0] || {};
      let semanticSearchAvailable = false;
      let semanticSearchError: string | undefined;
      let semanticSearchWarning: string | undefined;
      let semanticProfilesEmbedded = 0;
      let semanticProfilesTotal = 0;
      if (!isGeminiConfigured()) {
        semanticSearchError = 'Set GEMINI_API_KEY to enable semantic search.';
      } else {
        try {
          const [indexRows, embeddingRows] = await Promise.all([
            this.runner.runRead(
              'SHOW VECTOR INDEXES YIELD name, state WHERE name = $name RETURN state',
              { name: VECTOR_INDEX_NAME }
            ),
            this.runner.runRead(
              'MATCH (p:Person) RETURN count(p) AS total, count(p.embedding) AS embedded'
            ),
          ]);
          semanticProfilesTotal = toNum(embeddingRows[0]?.total);
          semanticProfilesEmbedded = toNum(embeddingRows[0]?.embedded);
          semanticSearchAvailable =
            String(indexRows[0]?.state || '') === 'ONLINE' &&
            semanticProfilesTotal > 0 &&
            semanticProfilesEmbedded > 0;
          if (!semanticSearchAvailable) {
            semanticSearchError =
              'Vector index or profile embeddings are not ready. Run npm run neo4j:embed to build the index.';
          } else if (semanticProfilesEmbedded < semanticProfilesTotal) {
            semanticSearchWarning = `Semantic search currently covers ${semanticProfilesEmbedded} of ${semanticProfilesTotal} profiles. Exact matches still search the full corpus; run npm run neo4j:embed again when Gemini quota is available.`;
          }
        } catch {
          semanticSearchError =
            'Neo4j vector search is unavailable. Use Neo4j 5.15 or newer and run npm run neo4j:embed.';
        }
      }

      return {
        neo4jConfigured: true,
        neo4jConnected: true,
        semanticSearchAvailable,
        semanticSearchError,
        semanticSearchWarning,
        semanticProfilesEmbedded,
        semanticProfilesTotal,
        counts: {
          persons: toNum(r.persons),
          villages: toNum(r.villages),
          mools: toNum(r.mools),
          gotras: toNum(r.gotras),
          childOfEdges: toNum(r.childOfEdges),
          siblingOfEdges: toNum(r.siblingOfEdges),
          personsWithVillage: toNum(r.personsWithVillage),
          personsWithInferredMool: toNum(r.personsWithInferredMool),
          personsWithLineageLinks: toNum(r.personsWithLineageLinks),
        },
      };
    } catch (err) {
      return {
        neo4jConfigured: true,
        neo4jConnected: false,
        neo4jError: (err as Error).message,
        semanticSearchAvailable: false,
        semanticSearchError: 'Neo4j is unavailable.',
        semanticProfilesEmbedded: 0,
        semanticProfilesTotal: 0,
        counts: null,
      };
    }
  }

  async getGotraNames(): Promise<string[]> {
    const rows = await this.runReadSafe(`
      MATCH (g:Gotra)
      RETURN g.name_roman AS name
      ORDER BY g.seq ASC
    `);
    return rows.map((r) => String(r.name || '')).filter(Boolean);
  }

  private async getVocabularyIndex(): Promise<VocabularyIndex> {
    const [gotraRows, moolRows, villageRows] = await Promise.all([
      this.runReadSafe(`MATCH (g:Gotra) RETURN g.name_roman AS name_roman, g.name_dev AS name_dev`),
      this.runReadSafe(
        `MATCH (m:Mool) RETURN m.name_roman AS name_roman, m.name_dev AS name_dev, m.aka AS aka`
      ),
      this.runReadSafe(`MATCH (v:Village) RETURN v.name_roman AS name_roman, v.name_dev AS name_dev`),
    ]);

    const gotraKeys = new Map<string, string>();
    for (const r of gotraRows) {
      const roman = String(r.name_roman || '');
      const dev = String(r.name_dev || '');
      for (const k of [foldIastToAscii(roman), phoneticRomanKey(roman), normalizeDevanagari(dev)]) {
        if (k && roman) gotraKeys.set(k, roman);
      }
    }

    const moolKeys = new Map<string, string>();
    for (const r of moolRows) {
      const roman = String(r.name_roman || '');
      const dev = String(r.name_dev || '');
      const aka = Array.isArray(r.aka) ? r.aka.map(String) : [];
      for (const term of [roman, dev, ...aka]) {
        if (!term) continue;
        const k1 = containsDevanagari(term) ? normalizeDevanagari(term) : foldIastToAscii(term);
        const k2 = containsDevanagari(term) ? '' : phoneticRomanKey(term);
        if (k1 && roman) moolKeys.set(k1, roman);
        if (k2 && roman) moolKeys.set(k2, roman);
      }
    }

    const villageKeys = new Map<string, string>();
    for (const r of villageRows) {
      const roman = String(r.name_roman || '');
      const dev = String(r.name_dev || '');
      for (const k of [foldIastToAscii(roman), phoneticRomanKey(roman), normalizeDevanagari(dev)]) {
        if (k && roman) villageKeys.set(k, roman);
      }
    }

    return { gotraKeys, moolKeys, villageKeys };
  }

  async getFilterOptions(): Promise<FilterOptionsPayload> {
    const [health, villageRows, moolRows, gotraRows, metaRows] = await Promise.all([
      this.checkHealth(),
      this.runReadSafe(`
        MATCH (v:Village)<-[:FROM_VILLAGE]-(p:Person)
        RETURN v.name_roman AS value, v.name_roman AS label, v.name_dev AS secondaryLabel, count(DISTINCT p) AS count
        ORDER BY count DESC, label ASC
      `),
      this.runReadSafe(`
        MATCH (m:Mool)<-[:OF_MOOL_GUESS]-(p:Person)
        RETURN m.name_roman AS value, m.name_roman AS label, m.name_dev AS secondaryLabel, count(DISTINCT p) AS count
        ORDER BY count DESC, label ASC
      `),
      this.runReadSafe(`
        MATCH (g:Gotra)
        OPTIONAL MATCH (g)<-[:IN_GOTRA]-(:Mool)<-[:OF_MOOL_GUESS]-(p:Person)
        RETURN g.name_roman AS value, g.name_roman AS label, g.name_dev AS secondaryLabel, g.seq AS seq, count(DISTINCT p) AS count
        ORDER BY seq ASC
      `),
      this.runReadSafe(`
        OPTIONAL MATCH (c:CorpusMetadata {id: 'mithila-panji'})
        RETURN c {.upstreamRepo, .upstreamCommit, .license, .sourceCitation, .loadedAt} AS meta
      `),
    ]);

    const mapOption = (r: Record<string, unknown>): FilterOption => ({
      value: String(r.value || ''),
      label: String(r.label || r.value || ''),
      secondaryLabel: r.secondaryLabel ? String(r.secondaryLabel) : undefined,
      count: toNum(r.count),
    });

    const metaObj = (metaRows[0]?.meta as Record<string, unknown> | null) ?? {};
    const metadata: DatasetMetadata = {
      upstreamRepo: String(metaObj.upstreamRepo || 'https://github.com/jharajiv/mithila-panji'),
      upstreamCommit: String(metaObj.upstreamCommit || 'a1734ba70c749eff209f496bac94aefceff8f040'),
      license: String(metaObj.license || DEFAULT_LICENSE),
      sourceCitation: String(metaObj.sourceCitation || DEFAULT_CITATION),
      generatedAt: String(metaObj.loadedAt || new Date().toISOString()),
      counts: health.counts ?? {
        persons: 0,
        villages: 0,
        mools: 0,
        gotras: 0,
        childOfEdges: 0,
        siblingOfEdges: 0,
        personsWithVillage: 0,
        personsWithInferredMool: 0,
        personsWithLineageLinks: 0,
      },
    };

    return {
      villages: villageRows.map(mapOption).filter((v) => v.value && v.count > 0),
      mools: moolRows.map(mapOption).filter((m) => m.value && m.count > 0),
      gotras: gotraRows.map(mapOption).filter((g) => g.value),
      metadata,
    };
  }

  async searchPersons(
    rawQuery: string,
    filters: SearchFilters = {},
    customInterpretation?: QueryInterpretation,
    limit = 40,
    semanticMatches: SemanticMatch[] = []
  ): Promise<SearchResponse> {
    const vocab = customInterpretation ? null : await this.getVocabularyIndex();
    const interpretation =
      customInterpretation ?? parseQueryDeterministically(rawQuery, vocab!);

    const appliedFilters: SearchFilters = {
      village: filters.village?.trim() || interpretation.villageHint || undefined,
      mool: filters.mool?.trim() || interpretation.moolHint || undefined,
      gotra: filters.gotra?.trim() || interpretation.gotraHint || undefined,
    };

    const hasFilters = Boolean(
      appliedFilters.village || appliedFilters.mool || appliedFilters.gotra
    );
    const hasTerms = interpretation.personTerms.length > 0;

    if (!hasTerms && !hasFilters && semanticMatches.length === 0) {
      return {
        query: rawQuery,
        interpretation,
        appliedFilters,
        totalMatches: 0,
        candidates: [],
      };
    }

    const villageFold = appliedFilters.village ? foldIastToAscii(appliedFilters.village) : '';
    const villagePhon = appliedFilters.village ? phoneticRomanKey(appliedFilters.village) : '';
    const villageDev =
      appliedFilters.village && containsDevanagari(appliedFilters.village)
        ? normalizeDevanagari(appliedFilters.village)
        : '';

    const moolFold = appliedFilters.mool ? foldIastToAscii(appliedFilters.mool) : '';
    const moolPhon = appliedFilters.mool ? phoneticRomanKey(appliedFilters.mool) : '';
    const moolDev =
      appliedFilters.mool && containsDevanagari(appliedFilters.mool)
        ? normalizeDevanagari(appliedFilters.mool)
        : '';

    const gotraFold = appliedFilters.gotra ? foldIastToAscii(appliedFilters.gotra) : '';
    const gotraPhon = appliedFilters.gotra ? phoneticRomanKey(appliedFilters.gotra) : '';
    const gotraDev =
      appliedFilters.gotra && containsDevanagari(appliedFilters.gotra)
        ? normalizeDevanagari(appliedFilters.gotra)
        : '';

    const termPayloads = interpretation.personTerms.map((t) => ({
      raw: t,
      isDev: containsDevanagari(t),
      folded: foldIastToAscii(t),
      phonetic: phoneticRomanKey(t),
      dev: normalizeDevanagari(t),
    }));

    const rows = await this.runReadSafe(
      `
      MATCH (p:Person)
      OPTIONAL MATCH (p)-[om:OF_MOOL_GUESS]->(m:Mool)
      OPTIONAL MATCH (m)-[:IN_GOTRA]->(g:Gotra)
      WITH p, om, m, collect(DISTINCT g) AS gotras
      WHERE ($villageFold = '' OR (
              coalesce(p.village_folded, '') CONTAINS $villageFold OR
              coalesce(p.village_phonetic, '') CONTAINS $villagePhon OR
              ($villageDev <> '' AND coalesce(p.village_dev_norm, '') CONTAINS $villageDev)
            ))
        AND ($moolFold = '' OR (
              m IS NOT NULL AND (
                coalesce(m.name_folded, '') CONTAINS $moolFold OR
                coalesce(m.name_phonetic, '') CONTAINS $moolPhon OR
                ($moolDev <> '' AND coalesce(m.name_dev, '') CONTAINS $moolDev)
              )
            ))
        AND ($gotraFold = '' OR ANY(gr IN gotras WHERE
              coalesce(gr.name_folded, '') CONTAINS $gotraFold OR
              coalesce(gr.name_phonetic, '') CONTAINS $gotraPhon OR
              ($gotraDev <> '' AND coalesce(gr.name_dev, '') CONTAINS $gotraDev)
            ))
        AND (size($terms) = 0 OR ANY(t IN $terms WHERE
              (t.isDev AND (
                coalesce(p.name_dev_norm, '') CONTAINS t.dev OR
                coalesce(p.village_dev_norm, '') CONTAINS t.dev
              )) OR
              (NOT t.isDev AND (
                coalesce(p.name_folded, '') CONTAINS t.folded OR
                coalesce(p.name_phonetic, '') CONTAINS t.phonetic OR
                coalesce(p.titles_folded, '') CONTAINS t.folded OR
                coalesce(p.village_folded, '') CONTAINS t.folded OR
                coalesce(p.village_phonetic, '') CONTAINS t.phonetic OR
                toLower(coalesce(p.source_ref, '')) CONTAINS t.folded OR
                p.id = t.raw
              ))
            ) OR p.id IN $semanticIds)
      RETURN
        p {.id, .name_dev, .name_roman, .label, .village_dev, .village_roman, .titles, .source_ref, .source_file} AS person,
        om {.matchedFrom, .matchedTerm} AS moolEdge,
        m {.id, .name_dev, .name_roman} AS mool,
        [gr IN gotras | gr {.id, .name_dev, .name_roman, .seq}] AS gotras,
        COUNT { (p)-[:CHILD_OF]->(:Person) } AS parentCount,
        COUNT { (:Person)-[:CHILD_OF]->(p) } AS childCount,
        COUNT { (p)-[:SIBLING_OF]-(:Person) } AS explicitSiblingCount,
        COUNT {
          MATCH (p)-[:CHILD_OF]->(par:Person)<-[:CHILD_OF]-(sib:Person)
          WHERE sib.id <> p.id
          RETURN DISTINCT sib
        } AS sharedParentSiblingCount,
        [(p)-[:CHILD_OF]->(par:Person) | par.label][0..4] AS parentLabels,
        [(ch:Person)-[:CHILD_OF]->(p) | ch.label][0..6] AS childLabels,
        CASE WHEN p.id IN $semanticIds THEN 1 ELSE 0 END AS semanticRank
      ORDER BY semanticRank DESC
      LIMIT $candidateLimit
      `,
      {
        villageFold,
        villagePhon,
        villageDev,
        moolFold,
        moolPhon,
        moolDev,
        gotraFold,
        gotraPhon,
        gotraDev,
        terms: termPayloads,
        semanticIds: semanticMatches.map((match) => match.id),
        candidateLimit: neo4j.int(250 + Math.min(semanticMatches.length, 200)),
      }
    );

    const candidates: SearchCandidate[] = [];
    const similarityById = new Map(semanticMatches.map((match) => [match.id, match.score]));

    for (const row of rows) {
      const person = mapPersonRecord(row.person, row.mool, row.moolEdge, row.gotras);
      let score = 0;
      const evidence: MatchEvidence[] = [];
      const similarity = similarityById.get(person.id);

      if (similarity !== undefined) {
        score += similarity * 60;
        evidence.push({
          field: 'semantic',
          basis: 'inferred',
          reason: `Profile similarity ${Math.round(similarity * 100)}%; this is a discovery cue, not evidence of kinship.`,
        });
      }

      if (appliedFilters.village) {
        const vm = scoreFieldMatch(
          appliedFilters.village,
          person.village_roman,
          person.village_dev
        );
        if (vm) {
          score += vm.score * 0.85;
          evidence.push({
            field: 'village',
            basis: 'source-backed',
            reason: `Recorded village "${person.village_roman || person.village_dev}" matches "${appliedFilters.village}" (${vm.matchType}).`,
          });
        }
      }

      if (appliedFilters.mool && person.inferredMool) {
        score += 65;
        evidence.push({
          field: 'mool',
          basis: 'inferred',
          reason: `Inferred mool "${person.inferredMool.name_roman}" (${person.inferredMool.name_dev}) derived from village "${person.village_roman || person.village_dev}".`,
        });
      }

      if (appliedFilters.gotra && person.inferredGotras.length > 0) {
        score += 55;
        evidence.push({
          field: 'gotra',
          basis: 'inferred',
          reason: `Inferred gotra "${person.inferredGotras.map((g) => g.name_roman).join(', ')}" associated with mool "${person.inferredMool?.name_roman}".`,
        });
      }

      let matchedAllTerms = true;
      for (const term of interpretation.personTerms) {
        const nameMatch = scoreFieldMatch(term, person.name_roman, person.name_dev);
        const titleMatch = person.titles ? scoreFieldMatch(term, person.titles, '') : null;
        const villageMatch = scoreFieldMatch(term, person.village_roman, person.village_dev);
        const refMatch =
          person.source_ref &&
          foldIastToAscii(person.source_ref).includes(foldIastToAscii(term))
            ? { score: 45, matchType: 'substring' as const }
            : person.id === term
              ? { score: 110, matchType: 'exact' as const }
              : null;

        const best = [
          nameMatch ? { kind: 'name' as const, ...nameMatch, weight: 1.25 } : null,
          titleMatch ? { kind: 'title' as const, ...titleMatch, weight: 0.7 } : null,
          villageMatch ? { kind: 'village' as const, ...villageMatch, weight: 0.6 } : null,
          refMatch ? { kind: 'source_ref' as const, ...refMatch, weight: 0.5 } : null,
        ]
          .filter((x): x is NonNullable<typeof x> => x !== null)
          .sort((a, b) => b.score * b.weight - a.score * a.weight)[0];

        if (!best) {
          matchedAllTerms = false;
          continue;
        }

        score += best.score * best.weight;
        if (best.kind === 'name') {
          evidence.push({
            field: 'name',
            basis: 'source-backed',
            reason: `Name "${person.name_roman || person.name_dev}" ${best.matchType === 'exact' ? 'matches' : `partially matches (${best.matchType})`} "${term}".`,
          });
        } else if (best.kind === 'title') {
          evidence.push({
            field: 'title',
            basis: 'source-backed',
            reason: `Recorded title "${person.titles}" matches "${term}".`,
          });
        } else if (best.kind === 'village') {
          evidence.push({
            field: 'village',
            basis: 'source-backed',
            reason: `Recorded village "${person.village_roman || person.village_dev}" matches "${term}".`,
          });
        } else {
          evidence.push({
            field: 'source_ref',
            basis: 'source-backed',
            reason: `Record reference "${person.source_ref || person.id}" matches "${term}".`,
          });
        }
      }

      if (hasTerms && matchedAllTerms && interpretation.personTerms.length > 1) {
        score += 35;
      }

      const parentCount = toNum(row.parentCount);
      const childCount = toNum(row.childCount);
      const explicitSiblingCount = toNum(row.explicitSiblingCount);
      const sharedParentSiblingCount = toNum(row.sharedParentSiblingCount);

      if (parentCount + childCount + explicitSiblingCount > 0) {
        score += 8;
      }

      const dedupEvidence: MatchEvidence[] = [];
      const seenKeys = new Set<string>();
      for (const ev of evidence) {
        const key = `${ev.field}:${ev.reason}`;
        if (!seenKeys.has(key)) {
          seenKeys.add(key);
          dedupEvidence.push(ev);
        }
      }

      candidates.push({
        person,
        score: Math.round(score),
        similarity,
        evidence: dedupEvidence,
        connections: {
          parentCount,
          childCount,
          explicitSiblingCount,
          sharedParentSiblingCount,
          parentLabels: Array.isArray(row.parentLabels)
            ? row.parentLabels.map(String).filter(Boolean)
            : undefined,
          childLabels: Array.isArray(row.childLabels)
            ? row.childLabels.map(String).filter(Boolean)
            : undefined,
        },
      });
    }

    candidates.sort((a, b) => {
      if (b.score !== a.score) return b.score - a.score;
      const aLinks =
        a.connections.parentCount +
        a.connections.childCount +
        a.connections.explicitSiblingCount;
      const bLinks =
        b.connections.parentCount +
        b.connections.childCount +
        b.connections.explicitSiblingCount;
      if (bLinks !== aLinks) return bLinks - aLinks;
      return a.person.label.localeCompare(b.person.label, 'en');
    });

    return {
      query: rawQuery,
      interpretation,
      appliedFilters,
      totalMatches: candidates.length,
      candidates: candidates.slice(0, limit),
    };
  }

  async findSemanticMatches(embedding: number[], limit = 120): Promise<SemanticMatch[]> {
    const rows = await this.runReadSafe(
      `
      CALL db.index.vector.queryNodes($indexName, $limit, $embedding)
      YIELD node, score
      RETURN node.id AS id, score
      ORDER BY score DESC
      `,
      {
        indexName: VECTOR_INDEX_NAME,
        limit: neo4j.int(Math.min(Math.max(Math.trunc(limit), 1), 200)),
        embedding,
      }
    );
    return rows
      .map((row) => ({ id: String(row.id || ''), score: toNum(row.score) }))
      .filter((match) => match.id && Number.isFinite(match.score));
  }

  async getSimilarPersons(personId: string, limit = 5): Promise<SearchCandidate[] | null> {
    const rows = await this.runReadSafe(
      'MATCH (p:Person {id: $personId}) RETURN p.embedding AS embedding',
      { personId }
    );
    const embedding = rows[0]?.embedding;
    if (!Array.isArray(embedding) || embedding.length === 0) return null;

    const matches = (await this.findSemanticMatches(embedding.map(Number), limit + 1))
      .filter((match) => match.id !== personId)
      .slice(0, Math.min(Math.max(Math.trunc(limit), 1), 20));
    const people = await this.getAnswerContextByIds(matches.map((match) => match.id));
    const peopleById = new Map(people.map((candidate) => [candidate.person.id, candidate]));

    const similarPeople: SearchCandidate[] = [];
    for (const match of matches) {
      const candidate = peopleById.get(match.id);
      if (candidate) {
        similarPeople.push({
          ...candidate,
          score: Math.round(match.score * 100),
          similarity: match.score,
          evidence: [
            {
              field: 'semantic' as const,
              basis: 'inferred' as const,
              reason: `Profile similarity ${Math.round(match.score * 100)}%; this is a discovery cue, not evidence of kinship.`,
            },
          ],
        });
      }
    }
    return similarPeople;
  }

  private async fetchPersonsByIds(ids: string[]): Promise<Map<string, PersonRecord>> {
    const unique = Array.from(new Set(ids)).filter(Boolean);
    const map = new Map<string, PersonRecord>();
    if (unique.length === 0) return map;

    const rows = await this.runReadSafe(
      `
      MATCH (p:Person)
      WHERE p.id IN $ids
      OPTIONAL MATCH (p)-[om:OF_MOOL_GUESS]->(m:Mool)
      OPTIONAL MATCH (m)-[:IN_GOTRA]->(g:Gotra)
      RETURN
        p {.id, .name_dev, .name_roman, .label, .village_dev, .village_roman, .titles, .source_ref, .source_file} AS person,
        om {.matchedFrom, .matchedTerm} AS moolEdge,
        m {.id, .name_dev, .name_roman} AS mool,
        collect(DISTINCT g {.id, .name_dev, .name_roman, .seq}) AS gotras
      `,
      { ids: unique }
    );

    for (const r of rows) {
      const person = mapPersonRecord(r.person, r.mool, r.moolEdge, r.gotras);
      map.set(person.id, person);
    }
    return map;
  }

  async getAnswerContextByIds(ids: string[]): Promise<SearchCandidate[]> {
    const unique = Array.from(new Set(ids)).filter(Boolean).slice(0, 8);
    if (unique.length === 0) return [];

    const rows = await this.runReadSafe(
      `
      MATCH (p:Person)
      WHERE p.id IN $ids
      OPTIONAL MATCH (p)-[om:OF_MOOL_GUESS]->(m:Mool)
      OPTIONAL MATCH (m)-[:IN_GOTRA]->(g:Gotra)
      WITH p, om, m, collect(DISTINCT g) AS gotras
      RETURN
        p {.id, .name_dev, .name_roman, .label, .village_dev, .village_roman, .titles, .source_ref, .source_file} AS person,
        om {.matchedFrom, .matchedTerm} AS moolEdge,
        m {.id, .name_dev, .name_roman} AS mool,
        [gr IN gotras | gr {.id, .name_dev, .name_roman, .seq}] AS gotras,
        COUNT { (p)-[:CHILD_OF]->(:Person) } AS parentCount,
        COUNT { (:Person)-[:CHILD_OF]->(p) } AS childCount,
        COUNT { (p)-[:SIBLING_OF]-(:Person) } AS explicitSiblingCount,
        [(p)-[:CHILD_OF]->(par:Person) | par.label][0..4] AS parentLabels,
        [(ch:Person)-[:CHILD_OF]->(p) | ch.label][0..6] AS childLabels
      `,
      { ids: unique }
    );

    const byId = new Map<string, SearchCandidate>();
    for (const row of rows) {
      const person = mapPersonRecord(row.person, row.mool, row.moolEdge, row.gotras);
      byId.set(person.id, {
        person,
        score: 0,
        evidence: [],
        connections: {
          parentCount: toNum(row.parentCount),
          childCount: toNum(row.childCount),
          explicitSiblingCount: toNum(row.explicitSiblingCount),
          sharedParentSiblingCount: 0,
          parentLabels: Array.isArray(row.parentLabels)
            ? row.parentLabels.map(String).filter(Boolean)
            : [],
          childLabels: Array.isArray(row.childLabels)
            ? row.childLabels.map(String).filter(Boolean)
            : [],
        },
      });
    }

    return unique
      .map((id) => byId.get(id))
      .filter((c): c is SearchCandidate => Boolean(c));
  }

  async getLineage(personId: string): Promise<LineageGraph | null> {
    const focusMap = await this.fetchPersonsByIds([personId]);
    const focusPerson = focusMap.get(personId);
    if (!focusPerson) return null;

    const [ancestorRows, descendantRows, explicitSiblingRows, sharedParentRows] =
      await Promise.all([
        this.runReadSafe(
          `
          MATCH path = (p:Person {id: $personId})-[:CHILD_OF*1..20]->(anc:Person)
          RETURN
            [n IN nodes(path) | n.id] AS nodeIds,
            length(path) AS depth
          `,
          { personId }
        ),
        this.runReadSafe(
          `
          MATCH path = (desc:Person)-[:CHILD_OF*1..8]->(p:Person {id: $personId})
          RETURN
            [n IN nodes(path) | n.id] AS nodeIds,
            length(path) AS depth
          LIMIT 250
          `,
          { personId }
        ),
        this.runReadSafe(
          `
          MATCH (p:Person {id: $personId})-[:SIBLING_OF]-(sib:Person)
          RETURN DISTINCT sib.id AS siblingId
          `,
          { personId }
        ),
        this.runReadSafe(
          `
          MATCH (p:Person {id: $personId})-[:CHILD_OF]->(par:Person)<-[:CHILD_OF]-(sib:Person)
          WHERE sib.id <> $personId
          RETURN DISTINCT sib.id AS siblingId
          `,
          { personId }
        ),
      ]);

    const neededIds = new Set<string>([personId]);
    const ancestorDist = new Map<string, number>();
    const childToParentPairs: [string, string][] = [];
    const seenChildEdges = new Set<string>();

    for (const row of ancestorRows) {
      const nodeIds = Array.isArray(row.nodeIds) ? row.nodeIds.map(String) : [];
      for (let i = 0; i < nodeIds.length; i++) {
        const id = nodeIds[i];
        neededIds.add(id);
        if (i > 0) {
          const prevDist = ancestorDist.get(id);
          if (prevDist === undefined || i < prevDist) {
            ancestorDist.set(id, i);
          }
          const child = nodeIds[i - 1];
          const parent = id;
          const key = `${child}->${parent}`;
          if (!seenChildEdges.has(key)) {
            seenChildEdges.add(key);
            childToParentPairs.push([child, parent]);
          }
        }
      }
    }

    const descendantDist = new Map<string, number>();
    let truncated = false;
    for (const row of descendantRows) {
      const nodeIds = Array.isArray(row.nodeIds) ? row.nodeIds.map(String) : [];
      // Path runs desc -> ... -> focusPerson
      for (let i = 0; i < nodeIds.length - 1; i++) {
        const child = nodeIds[i];
        const parent = nodeIds[i + 1];
        const distFromFocus = nodeIds.length - 1 - i;
        if (descendantDist.size >= 80 && !descendantDist.has(child)) {
          truncated = true;
          continue;
        }
        neededIds.add(child);
        neededIds.add(parent);
        const prevDist = descendantDist.get(child);
        if (prevDist === undefined || distFromFocus < prevDist) {
          descendantDist.set(child, distFromFocus);
        }
        const key = `${child}->${parent}`;
        if (!seenChildEdges.has(key)) {
          seenChildEdges.add(key);
          childToParentPairs.push([child, parent]);
        }
      }
    }

    const explicitSiblingIds = new Set<string>();
    for (const row of explicitSiblingRows) {
      const sid = String(row.siblingId || '');
      if (sid && sid !== personId) {
        explicitSiblingIds.add(sid);
        neededIds.add(sid);
      }
    }

    const sharedParentSiblingIds = new Set<string>();
    for (const row of sharedParentRows) {
      const sid = String(row.siblingId || '');
      if (sid && sid !== personId && !explicitSiblingIds.has(sid)) {
        sharedParentSiblingIds.add(sid);
        neededIds.add(sid);
      }
    }

    const personMap = await this.fetchPersonsByIds(Array.from(neededIds));

    const nodes: LineageNode[] = [
      {
        person: focusPerson,
        role: 'focus',
        generationOffset: 0,
        relationshipBasis: 'focus',
      },
    ];

    for (const [id, dist] of ancestorDist.entries()) {
      const person = personMap.get(id);
      if (person) {
        nodes.push({
          person,
          role: 'ancestor',
          generationOffset: -dist,
          relationshipBasis: 'source-backed',
        });
      }
    }

    for (const [id, dist] of descendantDist.entries()) {
      const person = personMap.get(id);
      if (person) {
        nodes.push({
          person,
          role: 'descendant',
          generationOffset: dist,
          relationshipBasis: 'source-backed',
        });
      }
    }

    for (const sid of explicitSiblingIds) {
      const person = personMap.get(sid);
      if (person) {
        nodes.push({
          person,
          role: 'sibling',
          generationOffset: 0,
          relationshipBasis: 'source-backed',
        });
      }
    }

    for (const sid of sharedParentSiblingIds) {
      const person = personMap.get(sid);
      if (person) {
        nodes.push({
          person,
          role: 'sibling',
          generationOffset: 0,
          relationshipBasis: 'inferred-shared-parent',
        });
      }
    }

    const edges: LineageEdge[] = childToParentPairs.map(([from, to]) => ({
      from,
      to,
      type: 'child_of',
      basis: 'source-backed',
    }));

    for (const sid of explicitSiblingIds) {
      edges.push({
        from: personId,
        to: sid,
        type: 'sibling_of',
        basis: 'source-backed',
      });
    }

    for (const sid of sharedParentSiblingIds) {
      edges.push({
        from: personId,
        to: sid,
        type: 'inferred_sibling',
        basis: 'inferred',
      });
    }

    // Build primary ancestor chain upward (using first parent link at each step)
    const primaryParent = new Map<string, string>();
    for (const [child, parent] of childToParentPairs) {
      if (!primaryParent.has(child)) {
        primaryParent.set(child, parent);
      }
    }

    const chainUp: PersonRecord[] = [focusPerson];
    const visitedChain = new Set<string>([personId]);
    let cur = personId;
    while (primaryParent.has(cur)) {
      const nextId = primaryParent.get(cur)!;
      if (visitedChain.has(nextId)) break;
      visitedChain.add(nextId);
      const nextPerson = personMap.get(nextId);
      if (!nextPerson) break;
      chainUp.push(nextPerson);
      cur = nextId;
    }
    const ancestorChainToOldest = [...chainUp].reverse();

    const notes: string[] = [];
    if (ancestorDist.size === 0) {
      notes.push('No documented parent links appear above this person in the archive.');
    }
    if (descendantDist.size === 0) {
      notes.push('No documented child links appear below this person in the archive.');
    }
    if (sharedParentSiblingIds.size > 0) {
      notes.push(
        'One or more siblings are inferred from sharing a documented parent record rather than an explicit sibling entry.'
      );
    }
    if (truncated) {
      notes.push(
        'Descendant exploration was capped at 80 records to keep the lineage view legible.'
      );
    }

    return {
      focusPerson,
      nodes,
      edges,
      ancestorChainToOldest,
      truncated,
      notes,
    };
  }

  async findShortestRelationship(
    fromId: string,
    toId: string
  ): Promise<RelationshipPathPayload | null> {
    const people = await this.fetchPersonsByIds([fromId, toId]);
    const personA = people.get(fromId);
    const personB = people.get(toId);
    if (!personA || !personB) return null;

    if (fromId === toId) {
      return {
        personA,
        personB,
        connected: true,
        hops: 0,
        steps: [],
        commonAncestors: [personA],
        summaryNote: `${personA.label} and ${personB.label} refer to the same person record (${personA.id}).`,
      };
    }

    const [pathRows, commonRows] = await Promise.all([
      this.runReadSafe(
        `
        MATCH path = shortestPath((a:Person {id: $fromId})-[:CHILD_OF|SIBLING_OF*1..15]-(b:Person {id: $toId}))
        RETURN
          [n IN nodes(path) | n.id] AS nodeIds,
          [r IN relationships(path) | {type: type(r), startId: startNode(r).id, endId: endNode(r).id}] AS rels
        `,
        { fromId, toId }
      ),
      this.runReadSafe(
        `
        MATCH (a:Person {id: $fromId})-[:CHILD_OF*0..15]->(ca:Person)<-[:CHILD_OF*0..15]-(b:Person {id: $toId})
        WHERE ca.id <> $fromId AND ca.id <> $toId
        RETURN DISTINCT ca.id AS id
        LIMIT 6
        `,
        { fromId, toId }
      ),
    ]);

    const commonIds = commonRows.map((r) => String(r.id || '')).filter(Boolean);
    const pathRow = pathRows[0];
    const pathNodeIds = pathRow && Array.isArray(pathRow.nodeIds)
      ? pathRow.nodeIds.map(String)
      : [];
    const pathRels = pathRow && Array.isArray(pathRow.rels)
      ? (pathRow.rels as Array<Record<string, unknown>>)
      : [];

    const enrichedMap = await this.fetchPersonsByIds([...pathNodeIds, ...commonIds]);
    const commonAncestors = commonIds
      .map((id) => enrichedMap.get(id))
      .filter((p): p is PersonRecord => Boolean(p));

    if (pathNodeIds.length === 0 || pathRels.length === 0) {
      return {
        personA,
        personB,
        connected: false,
        hops: 0,
        steps: [],
        commonAncestors,
        summaryNote:
          'No documented family path (within 15 parent, child, or sibling steps) connects these two records in the current archive.',
      };
    }

    const steps: RelationshipPathStep[] = [];
    for (let i = 0; i < pathRels.length; i++) {
      const stepFromId = pathNodeIds[i];
      const stepToId = pathNodeIds[i + 1];
      const rel = pathRels[i];
      const relType = String(rel.type || 'CHILD_OF') === 'SIBLING_OF' ? 'SIBLING_OF' : 'CHILD_OF';
      const relStart = String(rel.startId || '');

      let direction: RelationshipPathStep['direction'] = 'sibling';
      if (relType === 'CHILD_OF') {
        direction = relStart === stepFromId ? 'parent' : 'child';
      }

      const fromPerson = enrichedMap.get(stepFromId);
      const toPerson = enrichedMap.get(stepToId);
      if (fromPerson && toPerson) {
        steps.push({
          from: fromPerson,
          to: toPerson,
          edgeType: relType,
          direction,
        });
      }
    }

    return {
      personA,
      personB,
      connected: true,
      hops: steps.length,
      steps,
      commonAncestors,
      summaryNote: `Shortest documented path connects ${personA.label} and ${personB.label} in ${steps.length} hop${steps.length === 1 ? '' : 's'}${
        commonAncestors.length > 0
          ? `, with common documented ancestor(s): ${commonAncestors.map((c) => c.label).join(', ')}`
          : ''
      }.`,
    };
  }

  async getMoolsAndGotras(): Promise<MoolsGotrasPayload> {
    const [gotraRows, moolRows] = await Promise.all([
      this.runReadSafe(`
        MATCH (g:Gotra)
        OPTIONAL MATCH (m:Mool)-[:IN_GOTRA]->(g)
        OPTIONAL MATCH (p:Person)-[:OF_MOOL_GUESS]->(m)
        RETURN
          g {.id, .name_dev, .name_roman, .seq} AS gotra,
          count(DISTINCT m) AS moolCount,
          count(DISTINCT p) AS personCount
        ORDER BY gotra.seq ASC
      `),
      this.runReadSafe(`
        MATCH (m:Mool)
        OPTIONAL MATCH (m)-[:IN_GOTRA]->(g:Gotra)
        OPTIONAL MATCH (p:Person)-[:OF_MOOL_GUESS]->(m)
        RETURN
          m {.id, .name_dev, .name_roman, .aka} AS mool,
          collect(DISTINCT g {.id, .name_dev, .name_roman, .seq}) AS gotras,
          count(DISTINCT p) AS personCount
        ORDER BY mool.name_roman ASC
      `),
    ]);

    const gotras = gotraRows.map((r) => {
      const g = (r.gotra || {}) as Record<string, unknown>;
      return {
        id: String(g.id || ''),
        name_dev: String(g.name_dev || ''),
        name_roman: String(g.name_roman || ''),
        seq: toNum(g.seq),
        moolCount: toNum(r.moolCount),
        personCount: toNum(r.personCount),
      };
    });

    const mools: MoolGotraItem[] = moolRows
      .map((r) => {
        const m = (r.mool || {}) as Record<string, unknown>;
        const moolGotras = mapGotras(r.gotras);
        return {
          id: String(m.id || ''),
          name_roman: String(m.name_roman || ''),
          name_dev: String(m.name_dev || ''),
          aka: Array.isArray(m.aka) ? m.aka.map(String) : [],
          gotras: moolGotras,
          isCrossGotra: moolGotras.length > 1,
          personCount: toNum(r.personCount),
        };
      })
      .filter((m) => m.id)
      .sort((a, b) => {
        if (a.isCrossGotra !== b.isCrossGotra) return a.isCrossGotra ? -1 : 1;
        if (b.personCount !== a.personCount) return b.personCount - a.personCount;
        return a.name_roman.localeCompare(b.name_roman, 'en');
      });

    return {
      gotras,
      mools,
      crossGotraCount: mools.filter((m) => m.isCrossGotra).length,
    };
  }

  async getTreeCoverage(limit = 24): Promise<TreeCoveragePayload> {
    const safeLimit = Math.min(Math.max(Math.floor(limit), 1), 60);

    const [treeRows, statRows] = await Promise.all([
      this.runReadSafe(
        `
        MATCH (root:Person)
        WHERE NOT (root)-[:CHILD_OF]->(:Person)
          AND EXISTS { (:Person)-[:CHILD_OF]->(root) }
        MATCH path = (desc:Person)-[:CHILD_OF*1..15]->(root)
        WITH root, count(DISTINCT desc) AS descendantCount, max(length(path)) AS maxDepth
        ORDER BY descendantCount DESC, maxDepth DESC, root.label ASC
        LIMIT toInteger($limit)
        OPTIONAL MATCH (root)-[om:OF_MOOL_GUESS]->(m:Mool)
        OPTIONAL MATCH (m)-[:IN_GOTRA]->(g:Gotra)
        RETURN
          root {.id, .name_dev, .name_roman, .label, .village_dev, .village_roman, .titles, .source_ref, .source_file} AS root,
          om {.matchedFrom, .matchedTerm} AS moolEdge,
          m {.id, .name_dev, .name_roman} AS mool,
          collect(DISTINCT g {.id, .name_dev, .name_roman, .seq}) AS gotras,
          descendantCount,
          maxDepth
        `,
        { limit: safeLimit }
      ),
      this.runReadSafe(`
        RETURN
          COUNT {
            (root:Person)
            WHERE NOT (root)-[:CHILD_OF]->(:Person)
              AND EXISTS { (:Person)-[:CHILD_OF]->(root) }
          } AS totalRootsWithDescendants,
          COUNT {
            (p:Person) WHERE EXISTS { (p)-[:CHILD_OF|SIBLING_OF]-() }
          } AS totalConnectedPersons
      `),
    ]);

    const trees: TreeCoverageItem[] = treeRows.map((r) => ({
      root: mapPersonRecord(r.root, r.mool, r.moolEdge, r.gotras),
      descendantCount: toNum(r.descendantCount),
      maxDepth: toNum(r.maxDepth),
    }));

    const stats = statRows[0] || {};
    return {
      trees,
      totalRootsWithDescendants: toNum(stats.totalRootsWithDescendants),
      totalConnectedPersons: toNum(stats.totalConnectedPersons),
    };
  }
}
