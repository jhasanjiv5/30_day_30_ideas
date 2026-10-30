import { DocumentChunk } from '../types/rag';

export const DEFAULT_CORPUS: DocumentChunk[] = [
  {
    id: 'doc-arch-01',
    title: 'Loose Coupling via Asynchronous Event Mesh',
    category: 'Architecture',
    source: 'Distributed Systems Pattern Book v4.2',
    tags: ['Event Mesh', 'Decoupling', 'Kafka/SSE', 'Ambient Interface'],
    text: 'An ambient interface must not form synchronous blocking bindings with the vector retrieval tier or the cognitive reasoning model. Instead, communication is brokered through an asynchronous pub/sub event mesh (such as Redis Streams, NATS, or Server-Sent Events). The ambient client dispatches an InquiryDispatched event containing lightweight session context. Background workers pull candidate events, orchestrate vector proximity queries, and push streaming thought deltas back to the client interface.'
  },
  {
    id: 'doc-arch-02',
    title: 'ChromaDB Pluggable Adapter Pattern',
    category: 'Vector Store',
    source: 'ChromaDB Technical Specifications & Design',
    tags: ['ChromaDB', 'HNSW', 'Embeddings', 'Vector Search'],
    text: 'ChromaDB operates as an embedded or client-server vector store indexing document collections via Hierarchical Navigable Small World (HNSW) graphs. In a loosely-connected RAG topology, ChromaDB is wrapped within an AbstractVectorStore interface. This guarantees that whether ChromaDB runs in-process as an embedded SQLite-backed instance or as a clustered Kubernetes service, the reasoning model queries it using uniform k-nearest-neighbors (k-NN) cosine vector projection.'
  },
  {
    id: 'doc-arch-03',
    title: 'Cognitive Reasoning with Self-RAG & Hallucination Guardrails',
    category: 'Reasoning Engine',
    source: 'NeurIPS Autonomous Inference Proceedings',
    tags: ['Self-RAG', 'Reasoning', 'Verification', 'High Precision'],
    text: 'High precision is achieved not through blind top-k retrieval, but via an active Self-RAG reflection loop. When an inquiry is received, the reasoning engine first executes Query Intent Decomposition and Hypothetical Document Embeddings (HyDE). Once candidate chunks are retrieved, the model performs Context Sufficiency Critique: if retrieved facts lack empirical support, it triggers a sub-query instead of hallucinating. The final response mandates bracketed citation grounding.'
  },
  {
    id: 'doc-arch-04',
    title: 'Ambient UI Lifecycle & Zero-Interruption Heuristics',
    category: 'Interface',
    source: 'Human-Agent Ambient Interaction Guidelines',
    tags: ['Ambient UI', 'Zero-Interruption', 'Omnibar', 'Background Sync'],
    text: 'An ambient assistant lives on the periphery of the user workflow (as a floating omnibar, dockable glass drawer, or headless daemon). It samples user context non-intrusively. When an explicit question or ambiguous issue arises, the ambient agent calculates an autonomous resolution confidence score. Only if precision exceeds 90% does it present a verified solution snippet with direct evidence, preserving user cognitive flow.'
  },
  {
    id: 'doc-arch-05',
    title: 'Hierarchical Chunking & Semantic Re-ranking',
    category: 'Vector Store',
    source: 'Information Retrieval Review 2026',
    tags: ['Chunking', 'Re-ranking', 'Cross-Encoder', 'Dense Retrieval'],
    text: 'Raw text ingestion must preserve semantic coherence through parent-child recursive chunking (512-token child chunks for dense vector embedding search, mapping to 2048-token parent context blocks). After initial ANN retrieval from ChromaDB, a cross-encoder re-ranking stage assesses query-document relevance scores, discarding low-similarity outliers before context window injection.'
  },
  {
    id: 'doc-arch-06',
    title: 'Failure Modes & Degraded Connectivity Handling',
    category: 'Architecture',
    source: 'Resilient Microservice Design Standards',
    tags: ['Fault Tolerance', 'Circuit Breaker', 'Offline Cache', 'Degraded Mode'],
    text: 'Because ambient interfaces may experience intermittent network conditions or API rate limits, a circuit breaker and client-side vector cache are required. If the cloud reasoning model is unreachable, the client degrades gracefully to local TF-IDF semantic matching and structured rule-based responses, queuing full cognitive synthesis until connectivity is restored.'
  }
];

export const PRESET_QUERIES = [
  'How do we ensure the chatbot is loosely coupled from ChromaDB?',
  'What guarantees autonomous high-precision without hallucination?',
  'How does the ambient interface avoid interrupting the user workflow?',
  'Explain the role of the HNSW index in ChromaDB for fast retrieval'
];
