import {
  containsDevanagari,
  foldIastToAscii,
  normalizeDevanagari,
  phoneticRomanKey,
} from './normalize.ts';
import {
  buildVocabularyIndex,
  parseQueryDeterministically,
  type VocabularyIndex,
} from './queryParser.ts';
import type {
  AiExplanationPayload,
  FilterOption,
  FilterOptionsPayload,
  LineageEdge,
  LineageGraph,
  LineageNode,
  MatchEvidence,
  PanjiDataset,
  PersonRecord,
  QueryInterpretation,
  SearchCandidate,
  SearchFilters,
  SearchResponse,
} from '../types/panji.ts';

const MAX_ANCESTOR_GENERATIONS = 20;
const MAX_DESCENDANT_GENERATIONS = 8;
const MAX_LINEAGE_NODES = 240;

interface IndexedPerson {
  person: PersonRecord;
  nameRomanFolded: string;
  nameRomanPhonetic: string;
  nameDevNorm: string;
  nameTokensFolded: string[];
  nameTokensPhonetic: string[];
  villageRomanFolded: string;
  villageRomanPhonetic: string;
  villageDevNorm: string;
  moolFolded: string;
  moolPhonetic: string;
  moolDevNorm: string;
  gotraFoldedList: string[];
  gotraPhoneticList: string[];
  gotraDevList: string[];
  titlesFolded: string;
  titlesDevNorm: string;
  sourceRefNorm: string;
}

export class PanjiEngine {
  readonly dataset: PanjiDataset;
  readonly vocab: VocabularyIndex;
  private readonly personById = new Map<string, PersonRecord>();
  private readonly indexedPersons: IndexedPerson[] = [];
  private readonly parentsOf = new Map<string, string[]>();
  private readonly childrenOf = new Map<string, string[]>();
  private readonly explicitSiblingsOf = new Map<string, Set<string>>();

  constructor(dataset: PanjiDataset) {
    this.dataset = dataset;
    this.vocab = buildVocabularyIndex(dataset);

    for (const p of dataset.persons) {
      this.personById.set(p.id, p);

      const nameRomanFolded = foldIastToAscii(p.name_roman);
      const nameRomanPhonetic = phoneticRomanKey(p.name_roman);
      const nameDevNorm = normalizeDevanagari(p.name_dev);

      this.indexedPersons.push({
        person: p,
        nameRomanFolded,
        nameRomanPhonetic,
        nameDevNorm,
        nameTokensFolded: nameRomanFolded.split(' ').filter(Boolean),
        nameTokensPhonetic: nameRomanPhonetic.split(' ').filter(Boolean),
        villageRomanFolded: foldIastToAscii(p.village_roman),
        villageRomanPhonetic: phoneticRomanKey(p.village_roman),
        villageDevNorm: normalizeDevanagari(p.village_dev),
        moolFolded: p.inferredMool ? foldIastToAscii(p.inferredMool.name_roman) : '',
        moolPhonetic: p.inferredMool ? phoneticRomanKey(p.inferredMool.name_roman) : '',
        moolDevNorm: p.inferredMool ? normalizeDevanagari(p.inferredMool.name_dev) : '',
        gotraFoldedList: p.inferredGotras.map((g) => foldIastToAscii(g.name_roman)),
        gotraPhoneticList: p.inferredGotras.map((g) => phoneticRomanKey(g.name_roman)),
        gotraDevList: p.inferredGotras.map((g) => normalizeDevanagari(g.name_dev)),
        titlesFolded: foldIastToAscii(p.titles),
        titlesDevNorm: normalizeDevanagari(p.titles),
        sourceRefNorm: (p.source_ref || '').toLowerCase(),
      });
    }

    for (const [childId, parentId] of dataset.childOfEdges) {
      const pList = this.parentsOf.get(childId) ?? [];
      pList.push(parentId);
      this.parentsOf.set(childId, pList);

      const cList = this.childrenOf.get(parentId) ?? [];
      cList.push(childId);
      this.childrenOf.set(parentId, cList);
    }

    for (const [a, b] of dataset.siblingOfEdges) {
      const sa = this.explicitSiblingsOf.get(a) ?? new Set<string>();
      sa.add(b);
      this.explicitSiblingsOf.set(a, sa);

      const sb = this.explicitSiblingsOf.get(b) ?? new Set<string>();
      sb.add(a);
      this.explicitSiblingsOf.set(b, sb);
    }
  }

  getPerson(id: string): PersonRecord | undefined {
    return this.personById.get(id);
  }

  private getSharedParentSiblings(personId: string): string[] {
    const parents = this.parentsOf.get(personId) ?? [];
    const explicit = this.explicitSiblingsOf.get(personId) ?? new Set<string>();
    const found = new Set<string>();
    for (const parentId of parents) {
      for (const childId of this.childrenOf.get(parentId) ?? []) {
        if (childId !== personId && !explicit.has(childId)) {
          found.add(childId);
        }
      }
    }
    return Array.from(found);
  }

  private getConnectionCounts(personId: string) {
    return {
      parentCount: (this.parentsOf.get(personId) ?? []).length,
      childCount: (this.childrenOf.get(personId) ?? []).length,
      explicitSiblingCount: (this.explicitSiblingsOf.get(personId) ?? new Set()).size,
      sharedParentSiblingCount: this.getSharedParentSiblings(personId).length,
    };
  }

  getFilterOptions(): FilterOptionsPayload {
    const villageCounts = new Map<string, { label: string; dev: string; count: number }>();
    const moolCounts = new Map<string, number>();
    const gotraCounts = new Map<string, number>();

    for (const p of this.dataset.persons) {
      const vKey = p.village_roman || p.village_dev;
      if (vKey) {
        const existing = villageCounts.get(vKey);
        if (existing) {
          existing.count++;
        } else {
          villageCounts.set(vKey, {
            label: p.village_roman || p.village_dev,
            dev: p.village_dev,
            count: 1,
          });
        }
      }
      if (p.inferredMool) {
        moolCounts.set(p.inferredMool.name_roman, (moolCounts.get(p.inferredMool.name_roman) ?? 0) + 1);
      }
      for (const g of p.inferredGotras) {
        gotraCounts.set(g.name_roman, (gotraCounts.get(g.name_roman) ?? 0) + 1);
      }
    }

    const villages: FilterOption[] = Array.from(villageCounts.entries())
      .map(([value, info]) => ({
        value,
        label: info.label,
        secondaryLabel: info.dev && info.dev !== info.label ? info.dev : undefined,
        count: info.count,
      }))
      .sort((a, b) => b.count - a.count || a.label.localeCompare(b.label));

    const mools: FilterOption[] = this.dataset.mools
      .map((m) => ({
        value: m.name_roman,
        label: m.name_roman,
        secondaryLabel: m.name_dev,
        count: moolCounts.get(m.name_roman) ?? 0,
      }))
      .sort((a, b) => b.count - a.count || a.label.localeCompare(b.label));

    const gotras: FilterOption[] = this.dataset.gotras
      .slice()
      .sort((a, b) => a.seq - b.seq)
      .map((g) => ({
        value: g.name_roman,
        label: g.name_roman,
        secondaryLabel: g.name_dev,
        count: gotraCounts.get(g.name_roman) ?? 0,
      }));

    return {
      villages,
      mools,
      gotras,
      metadata: this.dataset.metadata,
    };
  }

  getFeaturedRoots(limit = 4): SearchCandidate[] {
    const scoredRoots: Array<{ person: PersonRecord; depthScore: number }> = [];

    const measureSubtree = (id: string, visited: Set<string>): number => {
      if (visited.has(id)) return 0;
      visited.add(id);
      const children = this.childrenOf.get(id) ?? [];
      let total = 1;
      for (const c of children) {
        total += measureSubtree(c, visited);
      }
      return total;
    };

    for (const p of this.dataset.persons) {
      const parents = this.parentsOf.get(p.id) ?? [];
      const children = this.childrenOf.get(p.id) ?? [];
      if (parents.length === 0 && children.length > 0 && p.village_roman && p.inferredMool) {
        const subtreeSize = measureSubtree(p.id, new Set<string>());
        if (subtreeSize >= 4) {
          scoredRoots.push({ person: p, depthScore: subtreeSize });
        }
      }
    }

    scoredRoots.sort((a, b) => b.depthScore - a.depthScore);
    return scoredRoots.slice(0, limit).map(({ person, depthScore }) => ({
      person,
      score: depthScore,
      evidence: [
        {
          field: 'name',
          basis: 'source-backed',
          reason: `Documented root ancestor in corpus with ${depthScore - 1} recorded descendants`,
        },
      ],
      connections: this.getConnectionCounts(person.id),
    }));
  }

  search(
    rawQuery: string,
    filters: SearchFilters = {},
    customInterpretation?: QueryInterpretation,
    limit = 40
  ): SearchResponse {
    const interpretation =
      customInterpretation ?? parseQueryDeterministically(rawQuery, this.vocab);

    const activeVillage = (filters.village || interpretation.villageHint || '').trim();
    const activeMool = (filters.mool || interpretation.moolHint || '').trim();
    const activeGotra = (filters.gotra || interpretation.gotraHint || '').trim();

    const appliedFilters: SearchFilters = {
      ...(activeVillage ? { village: activeVillage } : {}),
      ...(activeMool ? { mool: activeMool } : {}),
      ...(activeGotra ? { gotra: activeGotra } : {}),
    };

    const hasAnyInput =
      interpretation.personTerms.length > 0 ||
      Boolean(activeVillage) ||
      Boolean(activeMool) ||
      Boolean(activeGotra);

    if (!hasAnyInput) {
      return {
        query: rawQuery,
        interpretation,
        appliedFilters,
        totalMatches: 0,
        candidates: [],
      };
    }

    const vFolded = foldIastToAscii(activeVillage);
    const vPhonetic = phoneticRomanKey(activeVillage);
    const vDev = normalizeDevanagari(activeVillage);

    const mFolded = foldIastToAscii(activeMool);
    const mPhonetic = phoneticRomanKey(activeMool);
    const mDev = normalizeDevanagari(activeMool);

    const gFolded = foldIastToAscii(activeGotra);
    const gPhonetic = phoneticRomanKey(activeGotra);
    const gDev = normalizeDevanagari(activeGotra);

    const candidates: SearchCandidate[] = [];

    for (const item of this.indexedPersons) {
      const evidence: MatchEvidence[] = [];
      let score = 0;

      // 1. Apply hard / high-signal filters (village, mool, gotra)
      if (activeVillage) {
        let matched = false;
        if (containsDevanagari(activeVillage)) {
          matched = item.villageDevNorm.includes(vDev);
        } else {
          matched =
            (vFolded.length > 0 && item.villageRomanFolded.includes(vFolded)) ||
            (vPhonetic.length > 0 && item.villageRomanPhonetic.includes(vPhonetic));
        }
        if (!matched) continue;
        score += item.villageRomanFolded === vFolded ? 35 : 24;
        evidence.push({
          field: 'village',
          basis: 'source-backed',
          reason: `Recorded village "${item.person.village_roman || item.person.village_dev}" matches "${activeVillage}"`,
        });
      }

      if (activeMool) {
        if (!item.person.inferredMool) continue;
        let matched = false;
        if (containsDevanagari(activeMool)) {
          matched = item.moolDevNorm.includes(mDev);
        } else {
          matched =
            (mFolded.length > 0 && item.moolFolded.includes(mFolded)) ||
            (mPhonetic.length > 0 && item.moolPhonetic.includes(mPhonetic));
        }
        if (!matched) continue;
        score += item.moolFolded === mFolded ? 30 : 20;
        evidence.push({
          field: 'mool',
          basis: 'inferred',
          reason: `Inferred mool "${item.person.inferredMool.name_roman}" (via village "${item.person.village_roman || item.person.village_dev}") matches "${activeMool}"`,
        });
      }

      if (activeGotra) {
        if (item.person.inferredGotras.length === 0) continue;
        let matchedGotraName = '';
        if (containsDevanagari(activeGotra)) {
          const idx = item.gotraDevList.findIndex((g) => g.includes(gDev));
          if (idx >= 0) matchedGotraName = item.person.inferredGotras[idx].name_roman;
        } else {
          const idx = item.gotraFoldedList.findIndex(
            (g, i) =>
              (gFolded.length > 0 && g.includes(gFolded)) ||
              (gPhonetic.length > 0 && item.gotraPhoneticList[i].includes(gPhonetic))
          );
          if (idx >= 0) matchedGotraName = item.person.inferredGotras[idx].name_roman;
        }
        if (!matchedGotraName) continue;
        score += 24;
        evidence.push({
          field: 'gotra',
          basis: 'inferred',
          reason: `Inferred gotra "${matchedGotraName}" (via mool "${item.person.inferredMool?.name_roman}") matches "${activeGotra}"`,
        });
      }

      // 2. Match personTerms against name, title, source_ref, or unparsed village/mool/gotra fallback
      if (interpretation.personTerms.length > 0) {
        const joinedTerms = interpretation.personTerms.join(' ');
        const joinedFolded = foldIastToAscii(joinedTerms);
        const joinedPhonetic = phoneticRomanKey(joinedTerms);
        const joinedDev = normalizeDevanagari(joinedTerms);

        let termMatchedCount = 0;

        // Full-phrase bonus
        if (containsDevanagari(joinedTerms)) {
          if (item.nameDevNorm === joinedDev) {
            score += 90;
            evidence.push({
              field: 'name',
              basis: 'source-backed',
              reason: `Exact Devanagari name match "${item.person.name_dev}"`,
            });
          } else if (item.nameDevNorm.includes(joinedDev)) {
            score += 60;
            evidence.push({
              field: 'name',
              basis: 'source-backed',
              reason: `Devanagari name contains "${joinedTerms}"`,
            });
          }
        } else {
          if (joinedFolded && item.nameRomanFolded === joinedFolded) {
            score += 95;
            evidence.push({
              field: 'name',
              basis: 'source-backed',
              reason: `Exact name match on "${item.person.name_roman}"`,
            });
          } else if (joinedPhonetic && item.nameRomanPhonetic === joinedPhonetic) {
            score += 82;
            evidence.push({
              field: 'name',
              basis: 'source-backed',
              reason: `Romanized spelling match on "${item.person.name_roman}"`,
            });
          } else if (joinedFolded && item.nameRomanFolded.startsWith(joinedFolded)) {
            score += 65;
            evidence.push({
              field: 'name',
              basis: 'source-backed',
              reason: `Name starts with "${joinedTerms}"`,
            });
          }
        }

        // Token-by-token matching (handles multi-word names, titles, source_ref, or direct place words)
        for (const term of interpretation.personTerms) {
          const isDev = containsDevanagari(term);
          const tDev = normalizeDevanagari(term);
          const tFold = foldIastToAscii(term);
          const tPhon = phoneticRomanKey(term);

          let matchedThisTerm = false;

          if (isDev) {
            if (item.nameDevNorm.includes(tDev)) {
              score += 36;
              matchedThisTerm = true;
              if (!evidence.some((e) => e.field === 'name')) {
                evidence.push({
                  field: 'name',
                  basis: 'source-backed',
                  reason: `Devanagari name matches "${term}"`,
                });
              }
            } else if (item.titlesDevNorm.includes(tDev)) {
              score += 26;
              matchedThisTerm = true;
              evidence.push({
                field: 'title',
                basis: 'source-backed',
                reason: `Recorded title "${item.person.titles}" matches "${term}"`,
              });
            } else if (!activeVillage && item.villageDevNorm.includes(tDev)) {
              score += 22;
              matchedThisTerm = true;
              evidence.push({
                field: 'village',
                basis: 'source-backed',
                reason: `Recorded village "${item.person.village_dev}" matches "${term}"`,
              });
            }
          } else {
            const exactWord =
              item.nameTokensFolded.includes(tFold) || item.nameTokensPhonetic.includes(tPhon);
            const prefixWord =
              item.nameTokensFolded.some((w) => w.startsWith(tFold)) ||
              item.nameTokensPhonetic.some((w) => w.startsWith(tPhon));
            const substrName =
              (tFold.length >= 2 && item.nameRomanFolded.includes(tFold)) ||
              (tPhon.length >= 2 && item.nameRomanPhonetic.includes(tPhon));

            if (exactWord || prefixWord || substrName) {
              score += exactWord ? 44 : prefixWord ? 32 : 20;
              matchedThisTerm = true;
              if (!evidence.some((e) => e.field === 'name')) {
                evidence.push({
                  field: 'name',
                  basis: 'source-backed',
                  reason: exactWord
                    ? `Name token matches "${term}" on "${item.person.name_roman}"`
                    : `Name similarity to "${term}" on "${item.person.name_roman}"`,
                });
              }
            } else if (
              item.titlesFolded &&
              ((tFold && item.titlesFolded.includes(tFold)) ||
                (tPhon && phoneticRomanKey(item.person.titles).includes(tPhon)))
            ) {
              score += 28;
              matchedThisTerm = true;
              evidence.push({
                field: 'title',
                basis: 'source-backed',
                reason: `Recorded title "${item.person.titles}" matches "${term}"`,
              });
            } else if (item.sourceRefNorm && item.sourceRefNorm === term.toLowerCase()) {
              score += 34;
              matchedThisTerm = true;
              evidence.push({
                field: 'source_ref',
                basis: 'source-backed',
                reason: `Source citation "${item.person.source_ref}" matches "${term}"`,
              });
            } else if (
              !activeVillage &&
              ((tFold.length >= 3 && item.villageRomanFolded.includes(tFold)) ||
                (tPhon.length >= 3 && item.villageRomanPhonetic.includes(tPhon)))
            ) {
              score += 22;
              matchedThisTerm = true;
              evidence.push({
                field: 'village',
                basis: 'source-backed',
                reason: `Recorded village "${item.person.village_roman}" matches "${term}"`,
              });
            } else if (
              !activeMool &&
              item.person.inferredMool &&
              ((tFold.length >= 3 && item.moolFolded.includes(tFold)) ||
                (tPhon.length >= 3 && item.moolPhonetic.includes(tPhon)))
            ) {
              score += 18;
              matchedThisTerm = true;
              evidence.push({
                field: 'mool',
                basis: 'inferred',
                reason: `Inferred mool "${item.person.inferredMool.name_roman}" matches "${term}"`,
              });
            } else if (
              !activeGotra &&
              item.gotraFoldedList.some(
                (g, idx) =>
                  (tFold.length >= 3 && g.includes(tFold)) ||
                  (tPhon.length >= 3 && item.gotraPhoneticList[idx].includes(tPhon))
              )
            ) {
              score += 16;
              matchedThisTerm = true;
              evidence.push({
                field: 'gotra',
                basis: 'inferred',
                reason: `Inferred gotra matches "${term}"`,
              });
            }
          }

          if (matchedThisTerm) termMatchedCount++;
        }

        // If the user provided person terms, require at least one term match
        // (while strongly boosting records where all terms match).
        if (termMatchedCount === 0) continue;
        if (termMatchedCount === interpretation.personTerms.length && interpretation.personTerms.length > 1) {
          score += 25;
        }
      }

      const connections = this.getConnectionCounts(item.person.id);
      const totalConnections =
        connections.parentCount +
        connections.childCount +
        connections.explicitSiblingCount +
        connections.sharedParentSiblingCount;

      // Small tie-breaker favoring documented lineage links & citation completeness
      score += Math.min(totalConnections, 6) * 1.5;
      if (item.person.source_ref) score += 1;

      candidates.push({
        person: item.person,
        score: Math.round(score * 10) / 10,
        evidence,
        connections,
      });
    }

    candidates.sort((a, b) => b.score - a.score || a.person.label.localeCompare(b.person.label));

    return {
      query: rawQuery,
      interpretation,
      appliedFilters,
      totalMatches: candidates.length,
      candidates: candidates.slice(0, limit),
    };
  }

  getLineage(personId: string): LineageGraph | null {
    const focusPerson = this.personById.get(personId);
    if (!focusPerson) return null;

    const nodesMap = new Map<string, LineageNode>();
    const edges: LineageEdge[] = [];
    const seenEdgeKeys = new Set<string>();
    let truncated = false;

    const addNode = (
      id: string,
      role: LineageNode['role'],
      generationOffset: number,
      relationshipBasis: LineageNode['relationshipBasis']
    ): boolean => {
      if (nodesMap.has(id)) return true;
      if (nodesMap.size >= MAX_LINEAGE_NODES) {
        truncated = true;
        return false;
      }
      const p = this.personById.get(id);
      if (!p) return false;
      nodesMap.set(id, {
        person: p,
        role,
        generationOffset,
        relationshipBasis,
      });
      return true;
    };

    const addEdge = (edge: LineageEdge) => {
      const key = `${edge.type}:${edge.from}->${edge.to}`;
      if (seenEdgeKeys.has(key)) return;
      seenEdgeKeys.add(key);
      edges.push(edge);
    };

    addNode(personId, 'focus', 0, 'focus');

    // Walk ancestors (upward) via BFS
    const ancestorQueue: Array<{ id: string; offset: number }> = [{ id: personId, offset: 0 }];
    const visitedAncestors = new Set<string>([personId]);

    while (ancestorQueue.length > 0) {
      const current = ancestorQueue.shift()!;
      if (Math.abs(current.offset) >= MAX_ANCESTOR_GENERATIONS) continue;

      const parents = this.parentsOf.get(current.id) ?? [];
      for (const parentId of parents) {
        if (!addNode(parentId, 'ancestor', current.offset - 1, 'source-backed')) continue;
        addEdge({
          from: current.id,
          to: parentId,
          type: 'child_of',
          basis: 'source-backed',
        });
        if (!visitedAncestors.has(parentId)) {
          visitedAncestors.add(parentId);
          ancestorQueue.push({ id: parentId, offset: current.offset - 1 });
        }
      }
    }

    // Walk descendants (downward) via BFS
    const descendantQueue: Array<{ id: string; offset: number }> = [{ id: personId, offset: 0 }];
    const visitedDescendants = new Set<string>([personId]);

    while (descendantQueue.length > 0) {
      const current = descendantQueue.shift()!;
      if (current.offset >= MAX_DESCENDANT_GENERATIONS) continue;

      const children = this.childrenOf.get(current.id) ?? [];
      for (const childId of children) {
        if (!addNode(childId, 'descendant', current.offset + 1, 'source-backed')) continue;
        addEdge({
          from: childId,
          to: current.id,
          type: 'child_of',
          basis: 'source-backed',
        });
        if (!visitedDescendants.has(childId)) {
          visitedDescendants.add(childId);
          descendantQueue.push({ id: childId, offset: current.offset + 1 });
        }
      }
    }

    // Add explicit SIBLING_OF edges for focus person
    for (const sibId of this.explicitSiblingsOf.get(personId) ?? []) {
      if (addNode(sibId, 'sibling', 0, 'source-backed')) {
        const [a, b] = personId < sibId ? [personId, sibId] : [sibId, personId];
        addEdge({
          from: a,
          to: b,
          type: 'sibling_of',
          basis: 'source-backed',
        });
      }
    }

    // Add shared-parent siblings (explicitly flagged as inferred from shared parent)
    for (const sibId of this.getSharedParentSiblings(personId)) {
      if (addNode(sibId, 'sibling', 0, 'inferred-shared-parent')) {
        const [a, b] = personId < sibId ? [personId, sibId] : [sibId, personId];
        addEdge({
          from: a,
          to: b,
          type: 'inferred_sibling',
          basis: 'inferred',
        });
      }
    }

    // Compute longest documented ancestor path up to oldest ancestor in corpus
    const findLongestPathUp = (id: string, seen: Set<string>): PersonRecord[] => {
      const p = this.personById.get(id);
      if (!p) return [];
      const parents = (this.parentsOf.get(id) ?? []).filter((pid) => !seen.has(pid));
      if (parents.length === 0) return [p];
      let best: PersonRecord[] = [];
      for (const pid of parents) {
        const nextSeen = new Set(seen);
        nextSeen.add(pid);
        const sub = findLongestPathUp(pid, nextSeen);
        if (sub.length > best.length) best = sub;
      }
      return [...best, p];
    };

    const ancestorChainToOldest = findLongestPathUp(personId, new Set([personId]));

    const notes: string[] = [];
    if (focusPerson.inferredMool) {
      notes.push(
        `Mool "${focusPerson.inferredMool.name_roman}" is inferred by matching recorded village "${focusPerson.village_roman || focusPerson.village_dev}" against the canonical mool index.`
      );
    } else if (focusPerson.village_roman || focusPerson.village_dev) {
      notes.push(
        `Recorded village "${focusPerson.village_roman || focusPerson.village_dev}" did not match a single canonical mool entry directly.`
      );
    } else {
      notes.push('No ancestral village is recorded on this person entry in the extracted corpus.');
    }

    if (focusPerson.inferredGotras.length > 1) {
      notes.push(
        `Multiple gotras (${focusPerson.inferredGotras.map((g) => g.name_roman).join(', ')}) are associated with mool "${focusPerson.inferredMool?.name_roman}" in the seed index; a single gotra cannot be determined without direct family attestation.`
      );
    }

    if (ancestorChainToOldest.length <= 1) {
      notes.push(
        'No parent link (CHILD_OF) is recorded for this individual in the extracted 2009 corpus. This reflects partial digitization rather than absence of ancestry.'
      );
    }

    return {
      focusPerson,
      nodes: Array.from(nodesMap.values()),
      edges,
      ancestorChainToOldest,
      truncated,
      notes,
    };
  }

  buildDeterministicExplanation(personId: string, query?: string): AiExplanationPayload | null {
    const lineage = this.getLineage(personId);
    if (!lineage) return null;

    const p = lineage.focusPerson;
    const parents = lineage.nodes.filter((n) => n.generationOffset === -1);
    const children = lineage.nodes.filter((n) => n.generationOffset === 1);
    const explicitSiblings = lineage.nodes.filter(
      (n) => n.role === 'sibling' && n.relationshipBasis === 'source-backed'
    );
    const inferredSiblings = lineage.nodes.filter(
      (n) => n.role === 'sibling' && n.relationshipBasis === 'inferred-shared-parent'
    );

    const sourceBackedFacts: string[] = [];
    sourceBackedFacts.push(
      `Recorded name: ${p.name_roman || 'not romanized'}${p.name_dev ? ` (${p.name_dev})` : ''} [record ${p.id}].`
    );
    if (p.village_roman || p.village_dev) {
      sourceBackedFacts.push(
        `Recorded village: ${p.village_roman || p.village_dev}${p.village_dev && p.village_roman ? ` (${p.village_dev})` : ''}.`
      );
    }
    if (p.titles) {
      sourceBackedFacts.push(`Recorded title/honorific: ${p.titles}.`);
    }
    if (p.source_ref || p.source_file) {
      sourceBackedFacts.push(
        `Source provenance: ${p.source_file || '2009 Panji extract'}${p.source_ref ? `, ref ${p.source_ref}` : ''}.`
      );
    }
    if (parents.length > 0) {
      sourceBackedFacts.push(
        `Documented parent link(s): ${parents.map((n) => `${n.person.label} (${n.person.id})`).join(', ')}.`
      );
    }
    if (children.length > 0) {
      sourceBackedFacts.push(
        `Documented child link(s): ${children.map((n) => `${n.person.label} (${n.person.id})`).join(', ')}.`
      );
    }
    if (explicitSiblings.length > 0) {
      sourceBackedFacts.push(
        `Explicitly documented sibling(s): ${explicitSiblings.map((n) => `${n.person.label} (${n.person.id})`).join(', ')}.`
      );
    }

    const inferredOrUncertain: string[] = [];
    if (p.inferredMool) {
      inferredOrUncertain.push(
        `Inferred mool "${p.inferredMool.name_roman}" (${p.inferredMool.name_dev}) is derived via village-name matching ("${p.inferredMool.matchedTerm}"), not a direct OF_MOOL attestation.`
      );
    }
    if (p.inferredGotras.length > 0) {
      inferredOrUncertain.push(
        `Inferred gotra(s): ${p.inferredGotras.map((g) => `${g.name_roman} (${g.name_dev})`).join(', ')} via IN_GOTRA edges on the inferred mool.${p.inferredGotras.length > 1 ? ' Multiple gotras share this mool, so family confirmation is needed.' : ''}`
      );
    }
    if (inferredSiblings.length > 0) {
      inferredOrUncertain.push(
        `Possible sibling(s) sharing a documented parent link: ${inferredSiblings.map((n) => `${n.person.label} (${n.person.id})`).join(', ')}.`
      );
    }

    const gapsAndLimitations: string[] = [...lineage.notes];
    if (!p.source_ref) {
      gapsAndLimitations.push('No granular page/index reference (source_ref) is attached to this entry.');
    }
    gapsAndLimitations.push(
      'This Phase 0 corpus contains 1,888 extracted records from Thakur, Jha & Jha (2009) and is not a complete generational atlas.'
    );

    const ancestorDepth = lineage.ancestorChainToOldest.length - 1;
    const descendantNodes = lineage.nodes.filter((n) => n.role === 'descendant').length;
    const summaryParts = [
      `Deterministic record summary for ${p.label}${query ? ` (for query "${query}")` : ''}:`,
      p.village_roman || p.village_dev
        ? `Recorded in village ${p.village_roman || p.village_dev}.`
        : 'No village is recorded on this entry.',
      ancestorDepth > 0
        ? `Traces ${ancestorDepth} generation${ancestorDepth === 1 ? '' : 's'} upward to ${lineage.ancestorChainToOldest[0].label}.`
        : 'No documented parent chain exists above this record in the current dataset.',
      descendantNodes > 0
        ? `${descendantNodes} documented descendant record${descendantNodes === 1 ? '' : 's'} appear below this person.`
        : 'No documented descendants appear below this person.',
    ];

    const citedRecords = [
      { id: p.id, label: p.label, source_ref: p.source_ref },
      ...parents.map((n) => ({
        id: n.person.id,
        label: n.person.label,
        source_ref: n.person.source_ref,
      })),
      ...children.map((n) => ({
        id: n.person.id,
        label: n.person.label,
        source_ref: n.person.source_ref,
      })),
    ].slice(0, 10);

    return {
      mode: 'deterministic',
      personId: p.id,
      summary: summaryParts.join(' '),
      sourceBackedFacts,
      inferredOrUncertain,
      gapsAndLimitations,
      citedRecords,
    };
  }
}
