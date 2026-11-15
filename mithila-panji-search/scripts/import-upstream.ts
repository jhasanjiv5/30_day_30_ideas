import fs from 'node:fs';
import path from 'node:path';
import { parseCsv } from '../src/lib/csv.ts';
import { foldIastToAscii, normalizeDevanagari } from '../src/lib/normalize.ts';
import type {
  GotraRecord,
  InferredMoolInfo,
  MoolRecord,
  PanjiDataset,
  PersonRecord,
  VillageRecord,
} from '../src/types/panji.ts';

const ROOT_DIR = path.resolve(import.meta.dirname, '..');
const UPSTREAM_DIR = path.join(ROOT_DIR, 'data', 'upstream');
const OUTPUT_PATH = path.join(ROOT_DIR, 'src', 'data', 'panji-dataset.json');

function readCsvFile(filename: string): Record<string, string>[] {
  const filePath = path.join(UPSTREAM_DIR, filename);
  if (!fs.existsSync(filePath)) {
    throw new Error(`Missing required upstream CSV file: ${filePath}`);
  }
  const content = fs.readFileSync(filePath, 'utf8');
  return parseCsv(content);
}

function main() {
  const personRows = readCsvFile('persons.csv');
  const villageRows = readCsvFile('villages.csv');
  const moolRows = readCsvFile('mools.csv');
  const gotraRows = readCsvFile('gotras.csv');
  const inGotraRows = readCsvFile('in_gotra_edges.csv');
  const fromVillageRows = readCsvFile('from_village_edges.csv');
  const childOfRows = readCsvFile('child_of_edges.csv');
  const siblingOfRows = readCsvFile('sibling_of_edges.csv');

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

  const gotraIdsByMoolId = new Map<string, string[]>();
  for (const row of inGotraRows) {
    const moolId = row.mool_id;
    const gotraId = row.gotra_id;
    if (!moolId || !gotraId || !gotraById.has(gotraId)) continue;
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

  // Build exact-normalized mool lookup matching upstream OF_MOOL_GUESS behavior
  // (using normalized name_roman, name_dev, and slash-separated aka alternates).
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
  for (const row of fromVillageRows) {
    if (row.person_id && row.village_id && !villageIdByPersonId.has(row.person_id)) {
      villageIdByPersonId.set(row.person_id, row.village_id);
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

  const dataset: PanjiDataset = {
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
  };

  fs.mkdirSync(path.dirname(OUTPUT_PATH), { recursive: true });
  fs.writeFileSync(OUTPUT_PATH, JSON.stringify(dataset, null, 2), 'utf8');

  console.log(`Generated ${OUTPUT_PATH}`);
  console.log(JSON.stringify(dataset.metadata.counts, null, 2));
}

main();
