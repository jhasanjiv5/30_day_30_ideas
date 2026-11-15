import 'dotenv/config';
import neo4j, { type Driver, type Record as Neo4jRecord } from 'neo4j-driver';
import {
  buildPersonEmbeddingProfile,
  EMBEDDING_MODEL,
  embedTexts,
  EMBEDDING_DIMENSIONS,
  VECTOR_INDEX_NAME,
} from '../server/embeddings.ts';
import { isGeminiConfigured } from '../server/ai.ts';

const BATCH_SIZE = 80;
const INDEX_STATEMENT = `CREATE VECTOR INDEX ${VECTOR_INDEX_NAME} IF NOT EXISTS
  FOR (p:Person) ON (p.embedding)
  OPTIONS {indexConfig: {
    \`vector.dimensions\`: ${EMBEDDING_DIMENSIONS},
    \`vector.similarity_function\`: 'cosine'
  }}`;

interface ProfileRow {
  id: string;
  nameRoman: string;
  nameDevanagari: string;
  villageRoman: string;
  villageDevanagari: string;
  titles: string;
  mools: string[];
  gotras: string[];
  parents: string[];
  children: string[];
  recordedSiblings: string[];
  inferredSiblings: string[];
  embeddingText: string;
  embeddingModel: string;
  hasEmbedding: boolean;
}

function stringList(value: unknown): string[] {
  return Array.isArray(value)
    ? value.map(String).filter(Boolean).sort((a, b) => a.localeCompare(b, 'en'))
    : [];
}

function toProfileRow(record: Neo4jRecord): ProfileRow {
  return {
    id: String(record.get('id') || ''),
    nameRoman: String(record.get('nameRoman') || ''),
    nameDevanagari: String(record.get('nameDevanagari') || ''),
    villageRoman: String(record.get('villageRoman') || ''),
    villageDevanagari: String(record.get('villageDevanagari') || ''),
    titles: String(record.get('titles') || ''),
    mools: stringList(record.get('mools')),
    gotras: stringList(record.get('gotras')),
    parents: stringList(record.get('parents')),
    children: stringList(record.get('children')),
    recordedSiblings: stringList(record.get('recordedSiblings')),
    inferredSiblings: stringList(record.get('inferredSiblings')),
    embeddingText: String(record.get('embeddingText') || ''),
    embeddingModel: String(record.get('embeddingModel') || ''),
    hasEmbedding: Boolean(record.get('hasEmbedding')),
  };
}

async function embedBatchWithRetry(texts: string[]): Promise<number[][]> {
  for (let attempt = 0; ; attempt++) {
    try {
      return await embedTexts(texts, 'RETRIEVAL_DOCUMENT');
    } catch (err) {
      const status = (err as { status?: unknown }).status;
      const message = (err as Error).message;
      if (status === 429 && /requests per day limit exceeded/i.test(message)) {
        throw new Error(
          'Gemini daily embedding quota reached. Completed batches are saved; rerun npm run neo4j:embed after the quota resets.'
        );
      }
      const retrySeconds = Number(message.match(/retry in ([\d.]+)s/i)?.[1]);
      if (status !== 429 || attempt >= 4) throw err;
      const delayMs = Number.isFinite(retrySeconds) ? retrySeconds * 1000 + 1000 : 61_000;
      console.warn(
        `[neo4j:embed] Gemini rate limit reached; retrying in ${Math.ceil(delayMs / 1000)} seconds`
      );
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }
}

async function waitForVectorIndex(session: ReturnType<Driver['session']>) {
  const deadline = Date.now() + 120_000;
  while (Date.now() < deadline) {
    const result = await session.run(
      'SHOW VECTOR INDEXES YIELD name, state, failureMessage WHERE name = $name RETURN state, failureMessage',
      { name: VECTOR_INDEX_NAME }
    );
    const state = String(result.records[0]?.get('state') || '');
    if (state === 'ONLINE') return;
    if (state === 'FAILED') {
      const failure = String(result.records[0]?.get('failureMessage') || 'No failure details.');
      throw new Error(`Neo4j vector index failed to build: ${failure}`);
    }
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }
  throw new Error('Timed out waiting for the Neo4j vector index to become online.');
}

async function main() {
  const uri = (process.env.NEO4J_URI || '').trim();
  const username = (process.env.NEO4J_USERNAME || '').trim();
  const password = (process.env.NEO4J_PASSWORD || '').trim();
  const database = (process.env.NEO4J_DATABASE || 'neo4j').trim();
  if (!uri || !username || !password) {
    throw new Error('Set NEO4J_URI, NEO4J_USERNAME, and NEO4J_PASSWORD before embedding.');
  }
  if (!isGeminiConfigured()) {
    throw new Error('Set GEMINI_API_KEY to create profile embeddings.');
  }

  const driver = neo4j.driver(uri, neo4j.auth.basic(username, password), {
    disableLosslessIntegers: true,
  });
  const session = driver.session({ database });
  try {
    await driver.verifyConnectivity({ database });
    await session.executeWrite((tx) => tx.run(INDEX_STATEMENT));
    await waitForVectorIndex(session);

    const result = await session.executeRead((tx) =>
      tx.run(`
        MATCH (p:Person)
        CALL {
          WITH p
          OPTIONAL MATCH (p)-[:CHILD_OF]->(parent:Person)
          RETURN collect(DISTINCT parent.label) AS parents
        }
        CALL {
          WITH p
          OPTIONAL MATCH (child:Person)-[:CHILD_OF]->(p)
          RETURN collect(DISTINCT child.label) AS children
        }
        CALL {
          WITH p
          OPTIONAL MATCH (p)-[:SIBLING_OF]-(sibling:Person)
          RETURN collect(DISTINCT sibling.label) AS recordedSiblings
        }
        CALL {
          WITH p
          OPTIONAL MATCH (p)-[:CHILD_OF]->(:Person)<-[:CHILD_OF]-(sibling:Person)
          WHERE sibling.id <> p.id
          RETURN collect(DISTINCT sibling.label) AS inferredSiblings
        }
        CALL {
          WITH p
          OPTIONAL MATCH (p)-[:OF_MOOL_GUESS]->(m:Mool)
          OPTIONAL MATCH (m)-[:IN_GOTRA]->(g:Gotra)
          RETURN collect(DISTINCT m.name_roman) AS mools,
                 collect(DISTINCT g.name_roman) AS gotras
        }
        RETURN
          p.id AS id,
          p.name_roman AS nameRoman,
          p.name_dev AS nameDevanagari,
          p.village_roman AS villageRoman,
          p.village_dev AS villageDevanagari,
          p.titles AS titles,
          mools,
          gotras,
          parents,
          children,
          recordedSiblings,
          inferredSiblings,
          p.embedding_text AS embeddingText,
          p.embedding_model AS embeddingModel,
          p.embedding IS NOT NULL AS hasEmbedding
      `)
    );

    const profiles = result.records.map(toProfileRow).map((row) => ({
      ...row,
      profile: buildPersonEmbeddingProfile(row),
    }));
    const pending = profiles.filter(
      (row) =>
        !row.hasEmbedding ||
        row.embeddingModel !== EMBEDDING_MODEL ||
        row.embeddingText !== row.profile
    );
    for (let offset = 0; offset < pending.length; offset += BATCH_SIZE) {
      if (offset > 0) {
        console.log('[neo4j:embed] Pausing to stay within Gemini embedding request limits');
        await new Promise((resolve) => setTimeout(resolve, 61_000));
      }
      const batch = pending.slice(offset, offset + BATCH_SIZE);
      const embeddings = await embedBatchWithRetry(batch.map((row) => row.profile));
      const updateResult = await session.executeWrite((tx) =>
        tx.run(
          `UNWIND $rows AS row
           MATCH (p:Person {id: row.id})
           SET p.embedding = row.embedding,
               p.embedding_text = row.text,
               p.embedding_model = $model
           RETURN count(p) AS updated`,
          {
            rows: batch.map((row, index) => ({
              id: row.id,
              text: row.profile,
              embedding: embeddings[index],
            })),
            model: EMBEDDING_MODEL,
          }
        )
      );
      const updated = Number(updateResult.records[0]?.get('updated') ?? 0);
      if (updated !== batch.length) {
        throw new Error(`Updated ${updated} of ${batch.length} profiles in the current batch.`);
      }
      console.log(
        `[neo4j:embed] Updated ${Math.min(offset + batch.length, pending.length)}/${pending.length} profiles`
      );
    }

    console.log(
      `[neo4j:embed] ${pending.length} profiles embedded; ${profiles.length - pending.length} unchanged; ${profiles.length} total`
    );
  } finally {
    await session.close();
    await driver.close();
  }
}

main().catch((err) => {
  console.error('[neo4j:embed] Failed:', err);
  process.exitCode = 1;
});
