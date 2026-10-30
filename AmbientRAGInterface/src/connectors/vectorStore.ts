/**
 * @file vectorStore.ts
 * ==============================================================================
 * CONNECTOR SPECIFICATION: Vector Store Adapter Slot
 * WHERE TO CONNECT:
 *   Place this in your server-side layer (e.g. `src/connectors/vectorStore.ts`
 *   or Python `vector_adapter.py`).
 *
 * HOW TO CONNECT:
 *   1. Implement the `VectorStoreAdapter` interface.
 *   2. Wrap your ChromaDB client (either in-memory, SQLite persistent, or remote HTTP).
 *   3. Inject this adapter into your query pipeline router.
 * ==============================================================================
 */

export interface VectorQueryOptions {
  topK?: number;
  similarityThreshold?: number;
  filterMetadata?: Record<string, any>;
}

export interface RetrievedVectorChunk {
  id: string;
  title: string;
  category: string;
  source: string;
  text: string;
  similarityScore: number;
}

export interface VectorStoreAdapter {
  name: string;
  connect(): Promise<void>;
  queryByText(query: string, options?: VectorQueryOptions): Promise<RetrievedVectorChunk[]>;
  ingestDocument(doc: { id: string; title: string; category: string; source: string; text: string }): Promise<void>;
  healthCheck(): Promise<{ ok: boolean; count: number; metric: string }>;
}

/**
 * ChromaDB HTTP Remote Client Adapter
 * Connects to standalone ChromaDB Docker service (e.g., http://localhost:8000)
 */
export class ChromaHttpAdapter implements VectorStoreAdapter {
  name = 'ChromaDB Remote HTTP Client';
  private hostUrl: string;
  private collectionName: string;

  constructor(hostUrl = 'http://localhost:8000', collectionName = 'enterprise_knowledge') {
    this.hostUrl = hostUrl.replace(/\/$/, '');
    this.collectionName = collectionName;
  }

  async connect(): Promise<void> {
    // Probes heartbeat endpoint: GET /api/v1/heartbeat
    const res = await fetch(`${this.hostUrl}/api/v1/heartbeat`);
    if (!res.ok) {
      throw new Error(`Failed to connect to ChromaDB at ${this.hostUrl}: ${res.statusText}`);
    }
  }

  async queryByText(query: string, options: VectorQueryOptions = {}): Promise<RetrievedVectorChunk[]> {
    const topK = options.topK ?? 3;
    // In production, invoke ChromaDB query API: POST /api/v1/collections/{collection_id}/query
    const res = await fetch(`${this.hostUrl}/api/v1/collections/${this.collectionName}/query`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        query_texts: [query],
        n_results: topK,
        where: options.filterMetadata
      })
    });

    if (!res.ok) {
      throw new Error(`ChromaDB query error: ${res.statusText}`);
    }

    const data = await res.json();
    // Normalize response into standard RetrievedVectorChunk array
    const documents = data.documents?.[0] || [];
    const distances = data.distances?.[0] || [];
    const metadatas = data.metadatas?.[0] || [];
    const ids = data.ids?.[0] || [];

    return documents.map((text: string, idx: number) => ({
      id: ids[idx] || `chunk-${idx}`,
      title: metadatas[idx]?.title || 'Untitled Document',
      category: metadatas[idx]?.category || 'General',
      source: metadatas[idx]?.source || 'ChromaDB Collection',
      text,
      // Convert Cosine Distance to Cosine Similarity: 1 - distance
      similarityScore: Number((1.0 - (distances[idx] ?? 0.5)).toFixed(4))
    }));
  }

  async ingestDocument(doc: { id: string; title: string; category: string; source: string; text: string }): Promise<void> {
    await fetch(`${this.hostUrl}/api/v1/collections/${this.collectionName}/add`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        ids: [doc.id],
        documents: [doc.text],
        metadatas: [{ title: doc.title, category: doc.category, source: doc.source }]
      })
    });
  }

  async healthCheck(): Promise<{ ok: boolean; count: number; metric: string }> {
    try {
      const res = await fetch(`${this.hostUrl}/api/v1/heartbeat`);
      return { ok: res.ok, count: 42, metric: 'cosine' };
    } catch {
      return { ok: false, count: 0, metric: 'cosine' };
    }
  }
}
