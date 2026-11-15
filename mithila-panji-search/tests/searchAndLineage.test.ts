import path from 'node:path';
import http from 'node:http';
import { describe, expect, it } from 'vitest';
import { loadUpstreamBundleFromDir } from '../src/lib/upstreamLoader.ts';
import {
  foldIastToAscii,
  normalizeDevanagari,
  phoneticRomanKey,
} from '../src/lib/normalize.ts';
import { parseQueryDeterministically, type VocabularyIndex } from '../src/lib/queryParser.ts';
import {
  Neo4jRepository,
  type CypherRunner,
} from '../server/neo4jRepo.ts';
import {
  buildPersonEmbeddingProfile,
  isEmbeddingRateLimitError,
} from '../server/embeddings.ts';
import { createApiApp } from '../server.ts';

const UPSTREAM_DIR = path.resolve(import.meta.dirname, '..', 'data', 'upstream');
const bundle = loadUpstreamBundleFromDir(UPSTREAM_DIR);
const { dataset, inGotraEdges } = bundle;

function buildVocabFromDataset(): VocabularyIndex {
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
    for (const t of [m.name_roman, m.name_dev, ...m.aka]) {
      if (!t) continue;
      const k1 = foldIastToAscii(t);
      const k2 = phoneticRomanKey(t);
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

/**
 * Simulates Neo4j Cypher responses against the real upstream dataset so
 * Neo4jRepository Cypher parsing, scoring, and response mapping can be
 * thoroughly tested even without a running Neo4j container in CI.
 */
function createInMemoryCypherRunner(): CypherRunner {
  const personById = new Map(dataset.persons.map((p) => [p.id, p]));
  const moolById = new Map(dataset.mools.map((m) => [m.id, m]));
  const gotraById = new Map(dataset.gotras.map((g) => [g.id, g]));

  const parentsOf = new Map<string, string[]>();
  const childrenOf = new Map<string, string[]>();
  for (const [child, parent] of dataset.childOfEdges) {
    const pList = parentsOf.get(child) ?? [];
    pList.push(parent);
    parentsOf.set(child, pList);

    const cList = childrenOf.get(parent) ?? [];
    cList.push(child);
    childrenOf.set(parent, cList);
  }

  const siblingsOf = new Map<string, string[]>();
  for (const [a, b] of dataset.siblingOfEdges) {
    const la = siblingsOf.get(a) ?? [];
    la.push(b);
    siblingsOf.set(a, la);
    const lb = siblingsOf.get(b) ?? [];
    lb.push(a);
    siblingsOf.set(b, lb);
  }

  const toPersonNode = (p: (typeof dataset.persons)[number]) => ({
    id: p.id,
    name_dev: p.name_dev,
    name_roman: p.name_roman,
    label: p.label,
    village_dev: p.village_dev,
    village_roman: p.village_roman,
    titles: p.titles,
    source_ref: p.source_ref,
    source_file: p.source_file,
    name_folded: foldIastToAscii(p.name_roman),
    name_phonetic: phoneticRomanKey(p.name_roman),
    name_dev_norm: normalizeDevanagari(p.name_dev),
    village_folded: foldIastToAscii(p.village_roman),
    village_phonetic: phoneticRomanKey(p.village_roman),
    village_dev_norm: normalizeDevanagari(p.village_dev),
    titles_folded: foldIastToAscii(p.titles),
  });

  const sharedParentCount = (id: string) => {
    const set = new Set<string>();
    for (const par of parentsOf.get(id) ?? []) {
      for (const sib of childrenOf.get(par) ?? []) {
        if (sib !== id) set.add(sib);
      }
    }
    return set.size;
  };

  return {
    async verifyConnectivity() {
      return;
    },
    async close() {
      return;
    },
    async runRead(cypher: string, params: Record<string, unknown> = {}) {
      const q = cypher.trim();

      if (q.includes('AS personsWithLineageLinks')) {
        return [{ ...dataset.metadata.counts }];
      }

      if (q.includes('SHOW VECTOR INDEXES')) {
        return [{ state: 'ONLINE' }];
      }

      if (q.includes('count(p.embedding) AS embedded')) {
        return [{ total: 20, embedded: 10 }];
      }

      if (q.includes('RETURN g.name_roman AS name')) {
        return dataset.gotras.map((g) => ({ name: g.name_roman }));
      }

      if (q.includes('RETURN g.name_roman AS name_roman')) {
        return dataset.gotras.map((g) => ({ name_roman: g.name_roman, name_dev: g.name_dev }));
      }

      if (q.includes('RETURN m.name_roman AS name_roman')) {
        return dataset.mools.map((m) => ({
          name_roman: m.name_roman,
          name_dev: m.name_dev,
          aka: m.aka,
        }));
      }

      if (q.includes('RETURN v.name_roman AS name_roman')) {
        return dataset.villages.map((v) => ({
          name_roman: v.name_roman,
          name_dev: v.name_dev,
        }));
      }

      if (q.includes('RETURN p.embedding AS embedding')) {
        return personById.has(String(params.personId || ''))
          ? [{ embedding: Array(768).fill(0) }]
          : [];
      }

      if (q.includes('db.index.vector.queryNodes')) {
        return [
          { id: '86852a7f1617', score: 1 },
          { id: '5905349aee67', score: 0.82 },
        ];
      }

      if (q.includes('WHERE p.id IN $ids')) {
        const ids = (params.ids as string[]) || [];
        return ids
          .map((id) => personById.get(id))
          .filter((p): p is NonNullable<typeof p> => Boolean(p))
          .map((p) => ({
            person: toPersonNode(p),
            moolEdge: p.inferredMool
              ? {
                  matchedFrom: p.inferredMool.matchedFrom,
                  matchedTerm: p.inferredMool.matchedTerm,
                }
              : null,
            mool: p.inferredMool
              ? {
                  id: p.inferredMool.id,
                  name_dev: p.inferredMool.name_dev,
                  name_roman: p.inferredMool.name_roman,
                }
              : null,
            gotras: p.inferredGotras,
            parentCount: (parentsOf.get(p.id) ?? []).length,
            childCount: (childrenOf.get(p.id) ?? []).length,
            explicitSiblingCount: (siblingsOf.get(p.id) ?? []).length,
            parentLabels: (parentsOf.get(p.id) ?? [])
              .map((pid) => personById.get(pid)?.label)
              .filter(Boolean),
            childLabels: (childrenOf.get(p.id) ?? [])
              .map((cid) => personById.get(cid)?.label)
              .filter(Boolean),
          }));
      }

      if (q.includes('WHERE ($villageFold =')) {
        const villageFold = String(params.villageFold || '');
        const villagePhon = String(params.villagePhon || '');
        const moolFold = String(params.moolFold || '');
        const moolPhon = String(params.moolPhon || '');
        const gotraFold = String(params.gotraFold || '');
        const gotraPhon = String(params.gotraPhon || '');
        const terms = (params.terms as Array<Record<string, unknown>>) || [];
        const semanticIds = (params.semanticIds as string[]) || [];

        return dataset.persons
          .filter((p) => {
            const pn = toPersonNode(p);
            if (
              villageFold &&
              !pn.village_folded.includes(villageFold) &&
              !pn.village_phonetic.includes(villagePhon)
            ) {
              return false;
            }
            if (moolFold) {
              if (!p.inferredMool) return false;
              const mf = foldIastToAscii(p.inferredMool.name_roman);
              const mp = phoneticRomanKey(p.inferredMool.name_roman);
              if (!mf.includes(moolFold) && !mp.includes(moolPhon)) return false;
            }
            if (gotraFold) {
              const ok = p.inferredGotras.some((g) => {
                const gf = foldIastToAscii(g.name_roman);
                const gp = phoneticRomanKey(g.name_roman);
                return gf.includes(gotraFold) || gp.includes(gotraPhon);
              });
              if (!ok) return false;
            }
            if (terms.length > 0) {
              const matchedAny = terms.some((t) => {
                if (t.isDev) {
                  const dev = String(t.dev || '');
                  return pn.name_dev_norm.includes(dev) || pn.village_dev_norm.includes(dev);
                }
                const f = String(t.folded || '');
                const ph = String(t.phonetic || '');
                return (
                  pn.name_folded.includes(f) ||
                  pn.name_phonetic.includes(ph) ||
                  pn.titles_folded.includes(f) ||
                  pn.village_folded.includes(f) ||
                  pn.village_phonetic.includes(ph) ||
                  p.source_ref.toLowerCase().includes(f) ||
                  p.id === String(t.raw || '')
                );
              });
              if (!matchedAny && !semanticIds.includes(p.id)) return false;
            } else if (semanticIds.length > 0 && !semanticIds.includes(p.id)) {
              return false;
            }
            return true;
          })
          .slice(0, 250)
          .map((p) => ({
            person: toPersonNode(p),
            moolEdge: p.inferredMool
              ? {
                  matchedFrom: p.inferredMool.matchedFrom,
                  matchedTerm: p.inferredMool.matchedTerm,
                }
              : null,
            mool: p.inferredMool,
            gotras: p.inferredGotras,
            parentCount: (parentsOf.get(p.id) ?? []).length,
            childCount: (childrenOf.get(p.id) ?? []).length,
            explicitSiblingCount: (siblingsOf.get(p.id) ?? []).length,
            sharedParentSiblingCount: sharedParentCount(p.id),
            parentLabels: (parentsOf.get(p.id) ?? [])
              .map((pid) => personById.get(pid)?.label)
              .filter(Boolean),
            childLabels: (childrenOf.get(p.id) ?? [])
              .map((cid) => personById.get(cid)?.label)
              .filter(Boolean),
          }));
      }

      if (q.includes('-[:CHILD_OF*1..20]->(anc:Person)')) {
        const pid = String(params.personId || '');
        const rows: Record<string, unknown>[] = [];
        const dfs = (cur: string, pathIds: string[]) => {
          for (const par of parentsOf.get(cur) ?? []) {
            if (pathIds.includes(par)) continue;
            const next = [...pathIds, par];
            rows.push({ nodeIds: next, depth: next.length - 1 });
            dfs(par, next);
          }
        };
        dfs(pid, [pid]);
        return rows;
      }

      if (q.includes('(desc:Person)-[:CHILD_OF*1..8]->(p:Person')) {
        const pid = String(params.personId || '');
        const rows: Record<string, unknown>[] = [];
        const dfs = (cur: string, pathIds: string[]) => {
          for (const child of childrenOf.get(cur) ?? []) {
            if (pathIds.includes(child)) continue;
            const next = [child, ...pathIds];
            rows.push({ nodeIds: next, depth: next.length - 1 });
            dfs(child, next);
          }
        };
        dfs(pid, [pid]);
        return rows;
      }

      if (q.includes('-[:SIBLING_OF]-(sib:Person)')) {
        const pid = String(params.personId || '');
        return (siblingsOf.get(pid) ?? []).map((siblingId) => ({ siblingId }));
      }

      if (q.includes('<-[:CHILD_OF]-(sib:Person)')) {
        const pid = String(params.personId || '');
        const ids = new Set<string>();
        for (const par of parentsOf.get(pid) ?? []) {
          for (const sib of childrenOf.get(par) ?? []) {
            if (sib !== pid) ids.add(sib);
          }
        }
        return Array.from(ids).map((siblingId) => ({ siblingId }));
      }

      if (q.includes('shortestPath(')) {
        const fromId = String(params.fromId || '');
        const toId = String(params.toId || '');
        // BFS across CHILD_OF (directed child->parent) & SIBLING_OF
        const queue: Array<{
          id: string;
          nodeIds: string[];
          rels: Array<{ type: string; startId: string; endId: string }>;
        }> = [{ id: fromId, nodeIds: [fromId], rels: [] }];
        const visited = new Set<string>([fromId]);

        while (queue.length > 0) {
          const cur = queue.shift()!;
          if (cur.id === toId) {
            return [{ nodeIds: cur.nodeIds, rels: cur.rels }];
          }
          if (cur.rels.length >= 15) continue;

          const neighbors: Array<{
            next: string;
            rel: { type: string; startId: string; endId: string };
          }> = [];
          for (const par of parentsOf.get(cur.id) ?? []) {
            neighbors.push({
              next: par,
              rel: { type: 'CHILD_OF', startId: cur.id, endId: par },
            });
          }
          for (const child of childrenOf.get(cur.id) ?? []) {
            neighbors.push({
              next: child,
              rel: { type: 'CHILD_OF', startId: child, endId: cur.id },
            });
          }
          for (const sib of siblingsOf.get(cur.id) ?? []) {
            neighbors.push({
              next: sib,
              rel: { type: 'SIBLING_OF', startId: cur.id, endId: sib },
            });
          }

          for (const nb of neighbors) {
            if (visited.has(nb.next)) continue;
            visited.add(nb.next);
            queue.push({
              id: nb.next,
              nodeIds: [...cur.nodeIds, nb.next],
              rels: [...cur.rels, nb.rel],
            });
          }
        }
        return [];
      }

      if (q.includes('AS id') && q.includes('ca.id <> $fromId')) {
        const fromId = String(params.fromId || '');
        const toId = String(params.toId || '');
        const collectAncestors = (start: string) => {
          const set = new Set<string>([start]);
          const stack = [start];
          while (stack.length > 0) {
            const cur = stack.pop()!;
            for (const par of parentsOf.get(cur) ?? []) {
              if (!set.has(par)) {
                set.add(par);
                stack.push(par);
              }
            }
          }
          return set;
        };
        const aAnc = collectAncestors(fromId);
        const bAnc = collectAncestors(toId);
        const common = Array.from(aAnc).filter(
          (id) => bAnc.has(id) && id !== fromId && id !== toId
        );
        return common.slice(0, 6).map((id) => ({ id }));
      }

      if (q.includes('RETURN') && q.includes('moolCount') && q.includes('personCount')) {
        return dataset.gotras.map((g) => {
          const mIds = new Set(inGotraEdges.filter(([, gid]) => gid === g.id).map(([mid]) => mid));
          const pCount = dataset.persons.filter((p) =>
            p.inferredGotras.some((ig) => ig.id === g.id)
          ).length;
          return {
            gotra: g,
            moolCount: mIds.size,
            personCount: pCount,
          };
        });
      }

      if (q.includes('AS mool,') && q.includes('AS gotras,')) {
        return dataset.mools.map((m) => ({
          mool: { id: m.id, name_dev: m.name_dev, name_roman: m.name_roman, aka: m.aka },
          gotras: m.gotraIds.map((gid) => gotraById.get(gid)).filter(Boolean),
          personCount: dataset.persons.filter((p) => p.inferredMool?.id === m.id).length,
        }));
      }

      if (q.includes('AS descendantCount')) {
        const limit = Number(params.limit || 24);
        const roots = dataset.persons.filter(
          (p) => (parentsOf.get(p.id) ?? []).length === 0 && (childrenOf.get(p.id) ?? []).length > 0
        );
        const computed = roots.map((root) => {
          const desc = new Set<string>();
          let maxDepth = 0;
          const dfs = (cur: string, depth: number) => {
            for (const c of childrenOf.get(cur) ?? []) {
              if (!desc.has(c)) {
                desc.add(c);
                maxDepth = Math.max(maxDepth, depth + 1);
                dfs(c, depth + 1);
              }
            }
          };
          dfs(root.id, 0);
          return {
            root: toPersonNode(root),
            moolEdge: root.inferredMool
              ? {
                  matchedFrom: root.inferredMool.matchedFrom,
                  matchedTerm: root.inferredMool.matchedTerm,
                }
              : null,
            mool: root.inferredMool,
            gotras: root.inferredGotras,
            descendantCount: desc.size,
            maxDepth,
          };
        });
        computed.sort((a, b) => b.descendantCount - a.descendantCount);
        return computed.slice(0, limit);
      }

      if (q.includes('AS totalRootsWithDescendants')) {
        const roots = dataset.persons.filter(
          (p) => (parentsOf.get(p.id) ?? []).length === 0 && (childrenOf.get(p.id) ?? []).length > 0
        );
        return [
          {
            totalRootsWithDescendants: roots.length,
            totalConnectedPersons: dataset.metadata.counts.personsWithLineageLinks,
          },
        ];
      }

      return [];
    },
  };
}

const repo = new Neo4jRepository(createInMemoryCypherRunner());

describe('Normalization and upstream CSV loader', () => {
  it('folds IAST diacritics and common Roman variants', () => {
    expect(foldIastToAscii('śāṇḍilya')).toBe('sandilya');
    expect(foldIastToAscii('bhagīratha')).toBe('bhagiratha');
    expect(phoneticRomanKey('Shandilya')).toBe(phoneticRomanKey('śāṇḍilya'));
    expect(phoneticRomanKey('Kashyapa')).toBe(phoneticRomanKey('kāśyapa'));
  });

  it('loads authentic upstream Mithila-Panji CSV counts', () => {
    expect(dataset.metadata.counts.persons).toBe(1888);
    expect(dataset.metadata.counts.villages).toBe(505);
    expect(dataset.metadata.counts.mools).toBe(135);
    expect(dataset.metadata.counts.gotras).toBe(20);
    expect(dataset.metadata.counts.childOfEdges).toBe(474);
    expect(dataset.metadata.counts.siblingOfEdges).toBe(10);
  });
});

describe('Deterministic query parser', () => {
  const vocab = buildVocabFromDataset();

  it('extracts person and village from natural-language query', () => {
    const parsed = parseQueryDeterministically("I'm looking for Bhagiratha from Darihara", vocab);
    expect(parsed.personTerms).toEqual(['Bhagiratha']);
    expect(parsed.villageHint).toBe('dariharā');
  });

  it('extracts gotra and village from combined phrasing', () => {
    const parsed = parseQueryDeterministically('Arjuna of Pali, Vatsa gotra', vocab);
    expect(parsed.personTerms).toEqual(['Arjuna']);
    expect(parsed.villageHint).toBe('pālī');
    expect(parsed.gotraHint).toBe('vatsa');
  });
});

describe('Semantic profile search', () => {
  it('identifies provider rate limits so searches can report exact-only fallback', () => {
    expect(isEmbeddingRateLimitError({ status: 429 })).toBe(true);
    expect(isEmbeddingRateLimitError({ status: 500 })).toBe(false);
  });

  it('builds a full profile with source-backed and inferred family context', () => {
    const profile = buildPersonEmbeddingProfile({
      nameRoman: 'Bhagiratha',
      nameDevanagari: 'भगीरथ',
      villageRoman: 'Darihara',
      villageDevanagari: 'दरिहर',
      titles: 'kavirāja',
      mools: ['dariharā'],
      gotras: ['kāśyapa'],
      parents: ['Rāma'],
      children: ['Lakṣmaṇa'],
      recordedSiblings: ['Bharata'],
      inferredSiblings: ['Śatrughna'],
    });

    expect(profile).toContain('Recorded village: Darihara · दरिहर');
    expect(profile).toContain('Recorded titles: kavirāja');
    expect(profile).toContain('Inferred gotra: kāśyapa');
    expect(profile).toContain('Documented parents: Rāma');
    expect(profile).toContain('Possible siblings sharing a documented parent: Śatrughna');
  });

  it('ranks an exact name match above a semantically similar profile', async () => {
    const res = await repo.searchPersons('Arjuna', {}, undefined, 40, [
      { id: '86852a7f1617', score: 0.99 },
    ]);

    expect(res.candidates[0].evidence.some((item) => item.field === 'name')).toBe(true);
    const semanticCandidate = res.candidates.find((candidate) => candidate.person.id === '86852a7f1617');
    expect(semanticCandidate?.similarity).toBe(0.99);
    expect(semanticCandidate?.evidence.some((item) => item.field === 'semantic')).toBe(true);
    expect(res.candidates[0].score).toBeGreaterThan(semanticCandidate?.score ?? 0);
  });

  it('suggests similar records while excluding the selected person', async () => {
    const suggestions = await repo.getSimilarPersons('86852a7f1617');

    expect(suggestions?.map((candidate) => candidate.person.id)).toEqual(['5905349aee67']);
    expect(suggestions?.[0].similarity).toBe(0.82);
    expect(suggestions?.[0].evidence[0].field).toBe('semantic');
  });

  it('keeps semantic search available and reports partial vector coverage', async () => {
    const previousKey = process.env.GEMINI_API_KEY;
    process.env.GEMINI_API_KEY = 'test-key';
    try {
      const health = await repo.checkHealth();
      expect(health.semanticSearchAvailable).toBe(true);
      expect(health.semanticSearchWarning).toContain('10 of 20 profiles');
    } finally {
      if (previousKey === undefined) delete process.env.GEMINI_API_KEY;
      else process.env.GEMINI_API_KEY = previousKey;
    }
  });
});

describe('Neo4jRepository search, lineage, and graph enhancements', () => {
  it('finds Bhagiratha from Darihara with source-backed and inferred evidence', async () => {
    const res = await repo.searchPersons('I am looking for Bhagiratha from Darihara');
    expect(res.totalMatches).toBeGreaterThan(0);
    const top = res.candidates[0];
    expect(top.person.id).toBe('86852a7f1617');
    expect(top.person.inferredMool?.name_roman).toBe('dariharā');
    expect(top.person.inferredGotras.map((g) => g.name_roman)).toContain('kāśyapa');
    expect(top.evidence.some((e) => e.basis === 'source-backed' && e.field === 'name')).toBe(true);
    expect(top.evidence.some((e) => e.basis === 'source-backed' && e.field === 'village')).toBe(
      true
    );
  });

  it('matches Devanagari queries directly and applies filters', async () => {
    const devRes = await repo.searchPersons('भगीरथ');
    expect(devRes.candidates.some((c) => c.person.id === '86852a7f1617')).toBe(true);

    const filterRes = await repo.searchPersons('Arjuna', { gotra: 'vatsa', mool: 'pallī' });
    expect(filterRes.candidates[0].person.id).toBe('5905349aee67');
  });

  it('returns zero matches cleanly when query is absent from corpus (never fabricates)', async () => {
    const res = await repo.searchPersons("I'm looking for Ramnath Jha from Bisfi");
    expect(res.totalMatches).toBe(0);
    expect(res.candidates).toEqual([]);
  });

  it('traces 4-generation lineage and distinguishes explicit vs inferred siblings', async () => {
    const lineage = await repo.getLineage('5905349aee67');
    expect(lineage).not.toBeNull();
    const chainIds = lineage!.ancestorChainToOldest.map((p) => p.id);
    expect(chainIds[0]).toBe('b14a6e6ca547');
    expect(chainIds[chainIds.length - 1]).toBe('5905349aee67');
    expect(chainIds.length).toBe(4);

    const explicit = await repo.getLineage('cba4915a4bc0');
    expect(explicit?.nodes.find((n) => n.role === 'sibling')?.relationshipBasis).toBe(
      'source-backed'
    );
    expect(lineage!.nodes.find((n) => n.role === 'sibling')?.relationshipBasis).toBe(
      'inferred-shared-parent'
    );
  });

  it('finds shortest relationship path between Arjuna and Lākhū', async () => {
    const rel = await repo.findShortestRelationship('5905349aee67', 'b14a6e6ca547');
    expect(rel).not.toBeNull();
    expect(rel!.connected).toBe(true);
    expect(rel!.hops).toBe(3);
    expect(rel!.steps[0].from.id).toBe('5905349aee67');
    expect(rel!.steps[rel!.steps.length - 1].to.id).toBe('b14a6e6ca547');
  });

  it('returns canonical gotras, cross-gotra mools, and tree coverage stats', async () => {
    const mg = await repo.getMoolsAndGotras();
    expect(mg.gotras.length).toBe(20);
    expect(mg.mools.length).toBe(135);
    expect(mg.crossGotraCount).toBeGreaterThan(0);

    const cov = await repo.getTreeCoverage(10);
    expect(cov.totalRootsWithDescendants).toBeGreaterThan(0);
    expect(cov.trees[0].descendantCount).toBeGreaterThanOrEqual(cov.trees[1].descendantCount);
  });
});

describe('Strict Neo4j Express API behavior', () => {
  async function withAppServer<T>(
    repoOverride: Neo4jRepository | undefined,
    fn: (baseUrl: string) => Promise<T>
  ): Promise<T> {
    const prevKey = process.env.GEMINI_API_KEY;
    const prevUri = process.env.NEO4J_URI;
    const prevUser = process.env.NEO4J_USERNAME;
    const prevPass = process.env.NEO4J_PASSWORD;

    delete process.env.GEMINI_API_KEY;
    if (!repoOverride) {
      delete process.env.NEO4J_URI;
      delete process.env.NEO4J_USERNAME;
      delete process.env.NEO4J_PASSWORD;
    }

    const app = createApiApp(repoOverride);
    const server = await new Promise<http.Server>((resolve) => {
      const s = app.listen(0, '127.0.0.1', () => resolve(s));
    });
    const addr = server.address();
    const port = typeof addr === 'object' && addr ? addr.port : 0;
    try {
      return await fn(`http://127.0.0.1:${port}`);
    } finally {
      if (prevKey !== undefined) process.env.GEMINI_API_KEY = prevKey;
      if (prevUri !== undefined) process.env.NEO4J_URI = prevUri;
      if (prevUser !== undefined) process.env.NEO4J_USERNAME = prevUser;
      if (prevPass !== undefined) process.env.NEO4J_PASSWORD = prevPass;
      await new Promise<void>((resolve) => server.close(() => resolve()));
    }
  }

  it('strictly rejects data endpoints with 503 when Neo4j is not configured (no local fallback)', async () => {
    await withAppServer(undefined, async (base) => {
      const health = await fetch(`${base}/api/health`).then((r) => r.json());
      expect(health.ok).toBe(true);
      expect(health.neo4jConfigured).toBe(false);
      expect(health.neo4jConnected).toBe(false);

      for (const endpoint of [
        '/api/filters',
        '/api/search?q=Bhagiratha',
        '/api/person/86852a7f1617/lineage',
        '/api/person/86852a7f1617/similar',
        '/api/neo4j/relationship?from=5905349aee67&to=b14a6e6ca547',
        '/api/neo4j/mools-gotras',
        '/api/neo4j/coverage',
      ]) {
        const res = await fetch(`${base}${endpoint}`);
        expect(res.status).toBe(503);
        const body = await res.json();
        expect(body.code).toBe('NEO4J_NOT_CONFIGURED');
      }
    });
  });

  it('serves all search, lineage, Neo4j graph, and deterministic AI routes when repository is connected', async () => {
    await withAppServer(repo, async (base) => {
      const health = await fetch(`${base}/api/health`).then((r) => r.json());
      expect(health.neo4jConfigured).toBe(true);
      expect(health.neo4jConnected).toBe(true);
      expect(health.aiAvailable).toBe(false);

      const search = await fetch(
        `${base}/api/search?q=${encodeURIComponent('Bhagiratha from Darihara')}&useAi=true`
      ).then((r) => r.json());
      expect(search.totalMatches).toBeGreaterThan(0);
      expect(search.answer).toBeDefined();
      expect(search.answer.mode).toBe('deterministic');
      expect(search.answer.text).toContain('bhagīratha');
      expect(search.answer.citedRecords.length).toBeGreaterThan(0);
      expect(search.semanticSearchAvailable).toBe(false);
      expect(search.semanticSearchUsed).toBe(false);

      const similarRes = await fetch(`${base}/api/person/86852a7f1617/similar`);
      expect(similarRes.status).toBe(200);
      expect((await similarRes.json()).available).toBe(false);

      const answerRes = await fetch(`${base}/api/ai/answer`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          query: 'Bhagiratha from Darihara',
          candidateIds: ['86852a7f1617'],
          totalMatches: 1,
        }),
      });
      expect(answerRes.status).toBe(200);
      const answerBody = await answerRes.json();
      expect(answerBody.mode).toBe('deterministic');
      expect(answerBody.text).toContain('dariharā');

      const relRes = await fetch(
        `${base}/api/neo4j/relationship?from=5905349aee67&to=b14a6e6ca547`
      );
      expect(relRes.status).toBe(200);
      const rel = await relRes.json();
      expect(rel.connected).toBe(true);
      expect(rel.hops).toBe(3);

      const mgRes = await fetch(`${base}/api/neo4j/mools-gotras`);
      expect(mgRes.status).toBe(200);
      const mg = await mgRes.json();
      expect(mg.crossGotraCount).toBeGreaterThan(0);

      const covRes = await fetch(`${base}/api/neo4j/coverage`);
      expect(covRes.status).toBe(200);
      const cov = await covRes.json();
      expect(cov.trees.length).toBeGreaterThan(0);

      const explainRes = await fetch(`${base}/api/ai/explain`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ personId: '86852a7f1617' }),
      });
      expect(explainRes.status).toBe(200);
      const explain = await explainRes.json();
      expect(explain.mode).toBe('deterministic');
    });
  });

  it('treats placeholder Neo4j credentials safely as unconfigured without DNS lookup hang', async () => {
    const prevUri = process.env.NEO4J_URI;
    const prevUser = process.env.NEO4J_USERNAME;
    const prevPass = process.env.NEO4J_PASSWORD;

    process.env.NEO4J_URI = 'neo4j+s://YOUR_NEO4J_AURA_ID.databases.neo4j.io';
    process.env.NEO4J_USERNAME = 'neo4j';
    process.env.NEO4J_PASSWORD = 'YOUR_NEO4J_PASSWORD';

    try {
      const app = createApiApp();
      const server = await new Promise<http.Server>((resolve) => {
        const s = app.listen(0, '127.0.0.1', () => resolve(s));
      });
      const addr = server.address();
      const port = typeof addr === 'object' && addr ? addr.port : 0;
      try {
        const base = `http://127.0.0.1:${port}`;
        const health = await fetch(`${base}/api/health`).then((r) => r.json());
        expect(health.neo4jConfigured).toBe(false);
        expect(health.neo4jConnected).toBe(false);

        const searchRes = await fetch(`${base}/api/search?q=Bhagiratha`);
        expect(searchRes.status).toBe(503);
        const searchBody = await searchRes.json();
        expect(searchBody.code).toBe('NEO4J_NOT_CONFIGURED');
      } finally {
        await new Promise<void>((resolve) => server.close(() => resolve()));
      }
    } finally {
      if (prevUri !== undefined) process.env.NEO4J_URI = prevUri;
      else delete process.env.NEO4J_URI;
      if (prevUser !== undefined) process.env.NEO4J_USERNAME = prevUser;
      else delete process.env.NEO4J_USERNAME;
      if (prevPass !== undefined) process.env.NEO4J_PASSWORD = prevPass;
      else delete process.env.NEO4J_PASSWORD;
    }
  });
});

