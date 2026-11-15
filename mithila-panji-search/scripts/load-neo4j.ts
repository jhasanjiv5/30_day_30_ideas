import 'dotenv/config';
import path from 'node:path';
import neo4j, { type Driver } from 'neo4j-driver';
import {
  fetchUpstreamCsvsToDir,
  loadUpstreamBundleFromDir,
} from '../src/lib/upstreamLoader.ts';
import {
  foldIastToAscii,
  normalizeDevanagari,
  phoneticRomanKey,
} from '../src/lib/normalize.ts';

const ROOT_DIR = path.resolve(import.meta.dirname, '..');
const UPSTREAM_DIR = path.join(ROOT_DIR, 'data', 'upstream');
const BATCH_SIZE = 250;

function chunkArray<T>(items: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < items.length; i += size) {
    chunks.push(items.slice(i, i + size));
  }
  return chunks;
}

async function runBatched(
  driver: Driver,
  database: string,
  cypher: string,
  rows: Record<string, unknown>[],
  label: string
) {
  const batches = chunkArray(rows, BATCH_SIZE);
  const session = driver.session({ database });
  try {
    for (let i = 0; i < batches.length; i++) {
      await session.executeWrite((tx) => tx.run(cypher, { rows: batches[i] }));
    }
    console.log(`[neo4j:load] Upserted ${rows.length} ${label}`);
  } finally {
    await session.close();
  }
}

async function main() {
  const args = new Set(process.argv.slice(2));
  const shouldFetch = args.has('--fetch');
  const shouldReset = args.has('--reset');

  const uri = (process.env.NEO4J_URI || '').trim();
  const username = (process.env.NEO4J_USERNAME || '').trim();
  const password = (process.env.NEO4J_PASSWORD || '').trim();
  const database = (process.env.NEO4J_DATABASE || 'neo4j').trim();

  const looksLikePlaceholder =
    /YOUR_[A-Z0-9_]+|<[^>]+>|your-instance|your-password|placeholder|change_me/i.test(uri) ||
    /YOUR_[A-Z0-9_]+|<[^>]+>|your-password|placeholder|change_me/i.test(password);

  if (!uri || !username || !password || looksLikePlaceholder) {
    console.error(
      'Neo4j credentials are missing or still set to placeholders. Replace NEO4J_URI and NEO4J_PASSWORD with your live instance details before running npm run neo4j:load.'
    );
    process.exit(1);
  }

  if (shouldFetch) {
    console.log(`[neo4j:load] Fetching latest CSV snapshot from GitHub into ${UPSTREAM_DIR}...`);
    await fetchUpstreamCsvsToDir(UPSTREAM_DIR);
  }

  console.log(`[neo4j:load] Parsing upstream CSV files from ${UPSTREAM_DIR}...`);
  const bundle = loadUpstreamBundleFromDir(UPSTREAM_DIR);
  const { dataset, inGotraEdges, fromVillageEdges } = bundle;

  console.log(`[neo4j:load] Connecting to Neo4j (${uri}, database="${database}")...`);
  const driver = neo4j.driver(uri, neo4j.auth.basic(username, password), {
    disableLosslessIntegers: true,
  });

  try {
    await driver.verifyConnectivity({ database });

    if (shouldReset) {
      console.log('[neo4j:load] --reset specified: wiping existing Panji graph nodes...');
      const resetSession = driver.session({ database });
      try {
        await resetSession.executeWrite((tx) =>
          tx.run(
            'MATCH (n) WHERE n:Person OR n:Village OR n:Mool OR n:Gotra OR n:CorpusMetadata DETACH DELETE n'
          )
        );
      } finally {
        await resetSession.close();
      }
    }

    const schemaStatements = [
      'CREATE CONSTRAINT person_id IF NOT EXISTS FOR (p:Person) REQUIRE p.id IS UNIQUE',
      'CREATE CONSTRAINT village_id IF NOT EXISTS FOR (v:Village) REQUIRE v.id IS UNIQUE',
      'CREATE CONSTRAINT mool_id IF NOT EXISTS FOR (m:Mool) REQUIRE m.id IS UNIQUE',
      'CREATE CONSTRAINT gotra_id IF NOT EXISTS FOR (g:Gotra) REQUIRE g.id IS UNIQUE',
      'CREATE CONSTRAINT corpus_meta_id IF NOT EXISTS FOR (c:CorpusMetadata) REQUIRE c.id IS UNIQUE',
      'CREATE INDEX person_name_roman IF NOT EXISTS FOR (p:Person) ON (p.name_roman)',
      'CREATE INDEX person_name_dev IF NOT EXISTS FOR (p:Person) ON (p.name_dev)',
      'CREATE INDEX person_name_folded IF NOT EXISTS FOR (p:Person) ON (p.name_folded)',
      'CREATE INDEX person_name_phonetic IF NOT EXISTS FOR (p:Person) ON (p.name_phonetic)',
      'CREATE INDEX person_village_folded IF NOT EXISTS FOR (p:Person) ON (p.village_folded)',
      'CREATE INDEX village_name_roman IF NOT EXISTS FOR (v:Village) ON (v.name_roman)',
      'CREATE INDEX village_name_folded IF NOT EXISTS FOR (v:Village) ON (v.name_folded)',
      'CREATE INDEX mool_name_roman IF NOT EXISTS FOR (m:Mool) ON (m.name_roman)',
      'CREATE INDEX mool_name_folded IF NOT EXISTS FOR (m:Mool) ON (m.name_folded)',
      'CREATE INDEX gotra_name_roman IF NOT EXISTS FOR (g:Gotra) ON (g.name_roman)',
    ];

    const schemaSession = driver.session({ database });
    try {
      for (const stmt of schemaStatements) {
        await schemaSession.executeWrite((tx) => tx.run(stmt));
      }
      console.log(`[neo4j:load] Applied ${schemaStatements.length} constraints & indexes.`);
    } finally {
      await schemaSession.close();
    }

    await runBatched(
      driver,
      database,
      `UNWIND $rows AS row
       MERGE (g:Gotra {id: row.id})
       SET g.name_dev = row.name_dev,
           g.name_roman = row.name_roman,
           g.name_folded = row.name_folded,
           g.name_phonetic = row.name_phonetic,
           g.seq = row.seq`,
      dataset.gotras.map((g) => ({
        id: g.id,
        name_dev: g.name_dev,
        name_roman: g.name_roman,
        name_folded: foldIastToAscii(g.name_roman),
        name_phonetic: phoneticRomanKey(g.name_roman),
        seq: g.seq,
      })),
      'Gotra nodes'
    );

    await runBatched(
      driver,
      database,
      `UNWIND $rows AS row
       MERGE (m:Mool {id: row.id})
       SET m.name_dev = row.name_dev,
           m.name_roman = row.name_roman,
           m.name_folded = row.name_folded,
           m.name_phonetic = row.name_phonetic,
           m.aka = row.aka,
           m.aka_folded = row.aka_folded`,
      dataset.mools.map((m) => ({
        id: m.id,
        name_dev: m.name_dev,
        name_roman: m.name_roman,
        name_folded: foldIastToAscii(m.name_roman),
        name_phonetic: phoneticRomanKey(m.name_roman),
        aka: m.aka,
        aka_folded: m.aka.map((a) => foldIastToAscii(a)).filter(Boolean),
      })),
      'Mool nodes'
    );

    await runBatched(
      driver,
      database,
      `UNWIND $rows AS row
       MATCH (m:Mool {id: row.moolId})
       MATCH (g:Gotra {id: row.gotraId})
       MERGE (m)-[:IN_GOTRA]->(g)`,
      inGotraEdges.map(([moolId, gotraId]) => ({ moolId, gotraId })),
      'IN_GOTRA edges'
    );

    await runBatched(
      driver,
      database,
      `UNWIND $rows AS row
       MERGE (v:Village {id: row.id})
       SET v.name_dev = row.name_dev,
           v.name_roman = row.name_roman,
           v.name_folded = row.name_folded,
           v.name_phonetic = row.name_phonetic`,
      dataset.villages.map((v) => ({
        id: v.id,
        name_dev: v.name_dev,
        name_roman: v.name_roman,
        name_folded: foldIastToAscii(v.name_roman),
        name_phonetic: phoneticRomanKey(v.name_roman),
      })),
      'Village nodes'
    );

    await runBatched(
      driver,
      database,
      `UNWIND $rows AS row
       MERGE (p:Person {id: row.id})
       SET p.name_dev = row.name_dev,
           p.name_roman = row.name_roman,
           p.label = row.label,
           p.village_dev = row.village_dev,
           p.village_roman = row.village_roman,
           p.titles = row.titles,
           p.source_ref = row.source_ref,
           p.source_file = row.source_file,
           p.name_folded = row.name_folded,
           p.name_phonetic = row.name_phonetic,
           p.name_dev_norm = row.name_dev_norm,
           p.village_folded = row.village_folded,
           p.village_phonetic = row.village_phonetic,
           p.village_dev_norm = row.village_dev_norm,
           p.titles_folded = row.titles_folded`,
      dataset.persons.map((p) => ({
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
      })),
      'Person nodes'
    );

    await runBatched(
      driver,
      database,
      `UNWIND $rows AS row
       MATCH (p:Person {id: row.personId})
       MATCH (v:Village {id: row.villageId})
       MERGE (p)-[:FROM_VILLAGE]->(v)`,
      fromVillageEdges.map(([personId, villageId]) => ({ personId, villageId })),
      'FROM_VILLAGE edges'
    );

    const moolGuessRows = dataset.persons
      .filter((p) => p.inferredMool !== null)
      .map((p) => ({
        personId: p.id,
        moolId: p.inferredMool!.id,
        matchedFrom: p.inferredMool!.matchedFrom,
        matchedTerm: p.inferredMool!.matchedTerm,
      }));

    await runBatched(
      driver,
      database,
      `UNWIND $rows AS row
       MATCH (p:Person {id: row.personId})
       MATCH (m:Mool {id: row.moolId})
       MERGE (p)-[r:OF_MOOL_GUESS]->(m)
       SET r.matchedFrom = row.matchedFrom,
           r.matchedTerm = row.matchedTerm`,
      moolGuessRows,
      'OF_MOOL_GUESS edges'
    );

    await runBatched(
      driver,
      database,
      `UNWIND $rows AS row
       MATCH (c:Person {id: row.childId})
       MATCH (p:Person {id: row.parentId})
       MERGE (c)-[:CHILD_OF]->(p)`,
      dataset.childOfEdges.map(([childId, parentId]) => ({ childId, parentId })),
      'CHILD_OF edges'
    );

    await runBatched(
      driver,
      database,
      `UNWIND $rows AS row
       MATCH (a:Person {id: row.aId})
       MATCH (b:Person {id: row.bId})
       MERGE (a)-[:SIBLING_OF]->(b)`,
      dataset.siblingOfEdges.map(([a, b]) => (a < b ? { aId: a, bId: b } : { aId: b, bId: a })),
      'SIBLING_OF edges'
    );

    const metaSession = driver.session({ database });
    try {
      await metaSession.executeWrite((tx) =>
        tx.run(
          `MERGE (c:CorpusMetadata {id: 'mithila-panji'})
           SET c.upstreamRepo = $upstreamRepo,
               c.upstreamCommit = $upstreamCommit,
               c.license = $license,
               c.sourceCitation = $sourceCitation,
               c.loadedAt = $loadedAt`,
          {
            upstreamRepo: dataset.metadata.upstreamRepo,
            upstreamCommit: dataset.metadata.upstreamCommit,
            license: dataset.metadata.license,
            sourceCitation: dataset.metadata.sourceCitation,
            loadedAt: new Date().toISOString(),
          }
        )
      );

      const summaryRes = await metaSession.executeRead((tx) =>
        tx.run(`
          RETURN
            COUNT { (p:Person) } AS persons,
            COUNT { (v:Village) } AS villages,
            COUNT { (m:Mool) } AS mools,
            COUNT { (g:Gotra) } AS gotras,
            COUNT { (:Person)-[r:CHILD_OF]->(:Person) } AS childOfEdges,
            COUNT { (:Person)-[r:SIBLING_OF]->(:Person) } AS siblingOfEdges
        `)
      );
      const rec = summaryRes.records[0];
      console.log('[neo4j:load] Verified Neo4j counts:', {
        persons: rec.get('persons'),
        villages: rec.get('villages'),
        mools: rec.get('mools'),
        gotras: rec.get('gotras'),
        childOfEdges: rec.get('childOfEdges'),
        siblingOfEdges: rec.get('siblingOfEdges'),
      });
    } finally {
      await metaSession.close();
    }
  } finally {
    await driver.close();
  }
}

main().catch((err) => {
  console.error('[neo4j:load] Failed:', err);
  process.exit(1);
});
