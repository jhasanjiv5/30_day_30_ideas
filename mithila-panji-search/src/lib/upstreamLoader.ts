import fs from 'node:fs';
import path from 'node:path';
import { parseCsv } from './csv.ts';
import { foldIastToAscii, normalizeDevanagari } from './normalize.ts';
import type {
  GotraRecord,
  InferredMoolInfo,
  MoolRecord,
  PanjiDataset,
  PersonRecord,
  VillageRecord,
} from '../types/panji.ts';

export const UPSTREAM_RAW_BASE =
  'https://raw.githubusercontent.com/jharajiv/mithila-panji/main/data';

export const UPSTREAM_FILES = [
  'persons.csv',
  'villages.csv',
  'mools.csv',
  'gotras.csv',
  'in_gotra_edges.csv',
  'from_village_edges.csv',
  'child_of_edges.csv',
  'sibling_of_edges.csv',
  'LICENSE-DATA.md',
  'README.md',
] as const;

export interface ParsedUpstreamBundle {
  dataset: PanjiDataset;
  inGotraEdges: [string, string][];
  fromVillageEdges: [string, string][];
}

function readCsvFile(dir: string, filename: string): Record<string, string>[] {
  const filePath = path.join(dir, filename);
  if (!fs.existsSync(filePath)) {
    throw new Error(`Missing required upstream CSV file: ${filePath}`);
  }
  const content = fs.readFileSync(filePath, 'utf8');
  return parseCsv(content);
}

export async function fetchUpstreamCsvsToDir(targetDir: string): Promise<void> {
  fs.mkdirSync(targetDir, { recursive: true });
  for (const filename of UPSTREAM_FILES) {
    const url = `${UPSTREAM_RAW_BASE}/${filename}`;
    const res = await fetch(url);
    if (!res.ok) {
      throw new Error(`Failed to fetch ${url}: HTTP ${res.status}`);
    }
    const text = await res.text();
    fs.writeFileSync(path.join(targetDir, filename), text, 'utf8');
  }
}

export function loadUpstreamBundleFromDir(upstreamDir: string): ParsedUpstreamBundle {
  const personRows = readCsvFile(upstreamDir, 'persons.csv');
  const villageRows = readCsvFile(upstreamDir, 'villages.csv');
  const moolRows = readCsvFile(upstreamDir, 'mools.csv');
  const gotraRows = readCsvFile(upstreamDir, 'gotras.csv');
  const inGotraRows = readCsvFile(upstreamDir, 'in_gotra_edges.csv');
  const fromVillageRows = readCsvFile(upstreamDir, 'from_village_edges.csv');
  const childOfRows = readCsvFile(upstreamDir, 'child_of_edges.csv');
  const siblingOfRows = readCsvFile(upstreamDir, 'sibling_of_edges.csv');

  const gotras: GotraRecord[] = gotraRows
    .filter((r) => r.id)
    .map((r) => ({
      id: r.id,
      name_dev: r.name_dev || '',
      name_roman: r.name_roman || '',
      seq: Number(r.seq || '0') || 0,
    }))
    .sort((a, b) => a.seq - b.seq);

  const gotraById = new Map<string, GotraRecord>(gotras.map((g) => [g.id, g]));

  const inGotraEdges: [string, string][] = [];
  const gotraIdsByMoolId = new Map<string, string[]>();
  for (const row of inGotraRows) {
    const moolId = row.mool_id;
    const gotraId = row.gotra_id;
    if (!moolId || !gotraId || !gotraById.has(gotraId)) continue;
    inGotraEdges.push([moolId, gotraId]);
    const list = gotraIdsByMoolId.get(moolId) ?? [];
    if (!list.includes(gotraId)) {
      list.push(gotraId);
    }
    gotraIdsByMoolId.set(moolId, list);
  }

  const mools: MoolRecord[] = moolRows
    .filter((r) => r.id)
    .map((r) => ({
      id: r.id,
      name_dev: r.name_dev || '',
      name_roman: r.name_roman || '',
      aka: (r.aka || '')
        .split('/')
        .map((s) => s.trim())
        .filter(Boolean),
      gotraIds: gotraIdsByMoolId.get(r.id) ?? [],
    }));

  interface MoolLookupEntry {
    mool: MoolRecord;
    source: 'roman' | 'dev' | 'aka';
    term: string;
  }
  const moolLookup = new Map<string, MoolLookupEntry>();
  for (const mool of mools) {
    const romanKey = foldIastToAscii(mool.name_roman);
    if (romanKey && !moolLookup.has(romanKey)) {
      moolLookup.set(romanKey, { mool, source: 'roman', term: mool.name_roman });
    }
    const devKey = normalizeDevanagari(mool.name_dev);
    if (devKey && !moolLookup.has(devKey)) {
      moolLookup.set(devKey, { mool, source: 'dev', term: mool.name_dev });
    }
    for (const alt of mool.aka) {
      const altKey = /[\u0900-\u097F]/.test(alt)
        ? normalizeDevanagari(alt)
        : foldIastToAscii(alt);
      if (altKey && !moolLookup.has(altKey)) {
        moolLookup.set(altKey, { mool, source: 'aka', term: alt });
      }
    }
  }

  const villages: VillageRecord[] = villageRows
    .filter((r) => r.id)
    .map((r) => ({
      id: r.id,
      name_dev: r.name_dev || '',
      name_roman: r.name_roman || '',
    }));

  const villageById = new Map<string, VillageRecord>(villages.map((v) => [v.id, v]));
  const villageIdByPersonId = new Map<string, string>();
  const fromVillageEdges: [string, string][] = [];
  for (const row of fromVillageRows) {
    if (row.person_id && row.village_id) {
      fromVillageEdges.push([row.person_id, row.village_id]);
      if (!villageIdByPersonId.has(row.person_id)) {
        villageIdByPersonId.set(row.person_id, row.village_id);
      }
    }
  }

  function resolveInferredMool(
    villageRoman: string,
    villageDev: string
  ): { inferredMool: InferredMoolInfo | null; inferredGotras: GotraRecord[] } {
    const romanMatch = villageRoman ? moolLookup.get(foldIastToAscii(villageRoman)) : undefined;
    const devMatch = !romanMatch && villageDev ? moolLookup.get(normalizeDevanagari(villageDev)) : undefined;
    const match = romanMatch ?? devMatch;
    if (!match) {
      return { inferredMool: null, inferredGotras: [] };
    }
    const matchedFrom: InferredMoolInfo['matchedFrom'] =
      match.source === 'aka' ? 'aka' : romanMatch ? 'village_roman' : 'village_dev';

    const inferredGotras = match.mool.gotraIds
      .map((gid) => gotraById.get(gid))
      .filter((g): g is GotraRecord => Boolean(g));

    return {
      inferredMool: {
        id: match.mool.id,
        name_dev: match.mool.name_dev,
        name_roman: match.mool.name_roman,
        matchedFrom,
        matchedTerm: match.term,
      },
      inferredGotras,
    };
  }

  const persons: PersonRecord[] = [];
  const personIds = new Set<string>();

  for (const row of personRows) {
    const id = row.id;
    if (!id || personIds.has(id)) continue;

    let village_dev = row.village_dev || '';
    let village_roman = row.village_roman || '';

    if (!village_roman && !village_dev) {
      const villageId = villageIdByPersonId.get(id);
      const v = villageId ? villageById.get(villageId) : undefined;
      if (v) {
        village_dev = v.name_dev;
        village_roman = v.name_roman;
      }
    }

    const name_dev = row.name_dev || '';
    const name_roman = row.name_roman || '';
    const { inferredMool, inferredGotras } = resolveInferredMool(village_roman, village_dev);

    persons.push({
      id,
      name_dev,
      name_roman,
      label: name_roman || name_dev || id,
      village_dev,
      village_roman,
      titles: row.titles || '',
      source_ref: row.source_ref || '',
      source_file: row.source_file || '',
      inferredMool,
      inferredGotras,
    });
    personIds.add(id);
  }

  persons.sort((a, b) => a.label.localeCompare(b.label, 'en'));

  const childOfEdges: [string, string][] = [];
  const seenChildOf = new Set<string>();
  for (const row of childOfRows) {
    const childId = row.child_id;
    const parentId = row.parent_id;
    if (!childId || !parentId) continue;
    if (!personIds.has(childId) || !personIds.has(parentId)) continue;
    const key = `${childId}->${parentId}`;
    if (seenChildOf.has(key)) continue;
    seenChildOf.add(key);
    childOfEdges.push([childId, parentId]);
  }

  const siblingOfEdges: [string, string][] = [];
  const seenSiblings = new Set<string>();
  for (const row of siblingOfRows) {
    const a = row.person_a_id;
    const b = row.person_b_id;
    if (!a || !b || a === b) continue;
    if (!personIds.has(a) || !personIds.has(b)) continue;
    const pairKey = a < b ? `${a}<->${b}` : `${b}<->${a}`;
    if (seenSiblings.has(pairKey)) continue;
    seenSiblings.add(pairKey);
    siblingOfEdges.push([a, b]);
  }

  const connectedPersons = new Set<string>();
  for (const [c, p] of childOfEdges) {
    connectedPersons.add(c);
    connectedPersons.add(p);
  }
  for (const [a, b] of siblingOfEdges) {
    connectedPersons.add(a);
    connectedPersons.add(b);
  }

  const validFromVillageEdges = fromVillageEdges.filter(
    ([pid, vid]) => personIds.has(pid) && villageById.has(vid)
  );
  const moolIds = new Set(mools.map((m) => m.id));
  const validInGotraEdges = inGotraEdges.filter(
    ([mid, gid]) => moolIds.has(mid) && gotraById.has(gid)
  );

  return {
    dataset: {
      metadata: {
        upstreamRepo: 'https://github.com/jharajiv/mithila-panji',
        upstreamCommit: 'a1734ba70c749eff209f496bac94aefceff8f040',
        license: 'Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)',
        sourceCitation:
          'Thakur, Gajendra; Jha, Nagendra Kumar; Jha, Panjikar Vidyanand. Genome Mapping (450 A.D. to 2009 A.D.) — Mithilak Panji Prabandh, Vol. I–III. Shruti Publication, New Delhi, 2009. ISBN 978-81-907729-6-9.',
        generatedAt: new Date().toISOString(),
        counts: {
          persons: persons.length,
          villages: villages.length,
          mools: mools.length,
          gotras: gotras.length,
          childOfEdges: childOfEdges.length,
          siblingOfEdges: siblingOfEdges.length,
          personsWithVillage: persons.filter((p) => p.village_roman || p.village_dev).length,
          personsWithInferredMool: persons.filter((p) => p.inferredMool !== null).length,
          personsWithLineageLinks: connectedPersons.size,
        },
      },
      gotras,
      mools,
      villages,
      persons,
      childOfEdges,
      siblingOfEdges,
    },
    inGotraEdges: validInGotraEdges,
    fromVillageEdges: validFromVillageEdges,
  };
}
