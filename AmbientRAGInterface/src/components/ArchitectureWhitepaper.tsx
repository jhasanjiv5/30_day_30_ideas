import React, { useState } from 'react';
import { 
  FileText, 
  Download, 
  Check, 
  ExternalLink, 
  Share2, 
  ShieldCheck, 
  Cpu, 
  Database, 
  Network,
  BookOpen
} from 'lucide-react';

export const ArchitectureWhitepaper: React.FC = () => {
  const [downloaded, setDownloaded] = useState<boolean>(false);

  const whitepaperMarkdown = `# Technical Whitepaper: Ambient Loosely-Coupled Autonomous RAG Architecture

## 1. Executive Summary
This architecture provides a blueprint for an **ambient, loosely-connected autonomous chatbot interface**. It decouples the presentation layer (ambient UI/omnibar/headless daemon) from the vector storage tier (e.g., ChromaDB, Milvus, Qdrant) and the cognitive reasoning model (e.g., Gemini 3.8 Flash Thinking).

Through asynchronous event-driven messaging, standardized vector abstraction interfaces, and a Self-RAG verification loop, the system resolves user inquiries with verifiable precision, deterministic citation grounding, and strict zero-hallucination guardrails.

---

## 2. Decoupled System Architecture

\`\`\`
+-------------------------------------------------------------+
|                  1. Ambient Interface Layer                 |
|  - Headless DOM listener / Floating Omnibar / Glass Drawer  |
|  - Passive context observation & zero-interruption filter   |
+------------------------------+------------------------------+
                               | (SSE / JSON-RPC / WebSocket)
                               v
+-------------------------------------------------------------+
|           2. Asynchronous Event Mesh & Ingress Gateway       |
|  - Redis Streams / RabbitMQ / NATS event broker             |
|  - Decouples client lifecycle from storage & LLM latency    |
+------------------------------+------------------------------+
                               |
         +---------------------+---------------------+
         |                                           |
         v                                           v
+-----------------------------+     +-------------------------------+
| 3. Pluggable Vector Adapter |     | 4. Cognitive Reasoning Core   |
| (ChromaDB / SQLite-VSS)     |     | (Gemini 3.8 Flash Thinking)   |
| - HNSW Cosine Index         |     | - Query Intent Decomposition  |
| - Parent-Child Chunking     |     | - Context Sufficiency Critique|
| - Dense Vector Embeddings   |     | - Multi-step Chain of Thought |
+-----------------------------+     +-------------------------------+
         |                                           |
         +---------------------+---------------------+
                               |
                               v
+-------------------------------------------------------------+
|            5. Grounding & Autonomous Actuation Guard        |
|  - Self-RAG verification & Hallucination rejection          |
|  - Deterministic citation attribution [Source X]            |
|  - Precision threshold check (Confidence >= 90%)           |
+-------------------------------------------------------------+
\`\`\`

---

## 3. Guarantees & Mechanisms

### 3.1 Loose Coupling
- **Contract-First Communication**: The ambient interface communicates via normalized event payloads. It never imports database SDKs or vector libraries directly.
- **Pluggable Vector Store Adapter**: Wraps ChromaDB in an \`AbstractVectorStore\` interface (\`query_embeddings(query_vector, top_k, filters)\`). Swapping ChromaDB for Milvus or DuckDB requires zero client modifications.
- **Stateless Reasoning Core**: The reasoning engine executes stateless prompt-and-context completions with schema validation.

### 3.2 Ambient Operation
- **Zero-Interruption Policy**: Operates in the periphery. Rather than constantly popping up, it evaluates context quietly.
- **Autonomous Resolution Threshold**: Resolutions are surfaced proactively only when grounding confidence meets or exceeds 90%.

### 3.3 High Precision & Zero Hallucination
- **Hypothetical Document Embeddings (HyDE)**: Expands nuanced or terse inquiries into candidate semantic representations for better retrieval recall.
- **Context Sufficiency Check**: If retrieved ChromaDB documents do not directly corroborate the premises of the question, the engine explicitly reports the boundary of known information instead of hallucinating.
- **Chain of Thought Verification**: Step-by-step thinking traces expose the exact rationale behind every synthesized claim.
- **Mandatory Source Citations**: Every sentence attributing facts includes exact bracketed source identifiers tied to retrieved chunk IDs.
`;

  const handleDownload = () => {
    const blob = new Blob([whitepaperMarkdown], { type: 'text/markdown' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'ambient_rag_architecture_specification.md';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    setDownloaded(true);
    setTimeout(() => setDownloaded(false), 2000);
  };

  return (
    <div className="space-y-8 max-w-5xl mx-auto">
      {/* Top Banner */}
      <section className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-6 sm:p-8 shadow-sm flex flex-col sm:flex-row sm:items-center justify-between gap-6">
        <div className="space-y-1.5">
          <div className="flex items-center gap-2 text-xs font-medium text-slate-500 dark:text-slate-400">
            <span>Engineering Architecture Document</span>
            <span aria-hidden="true">·</span>
            <span>Revision 2026.4</span>
            <span aria-hidden="true">·</span>
            <span>Full Decoupled Specification</span>
          </div>
          <h1 className="text-2xl font-bold text-slate-900 dark:text-slate-100">
            Ambient Loosely-Connected RAG Architecture Whitepaper
          </h1>
          <p className="text-xs sm:text-sm text-slate-600 dark:text-slate-300">
            Complete technical blueprint resolving query ingress, pluggable ChromaDB clustering, and Gemini cognitive reasoning.
          </p>
        </div>

        <button
          onClick={handleDownload}
          className="px-4 py-2.5 text-xs font-semibold rounded-lg bg-blue-600 hover:bg-blue-700 text-white shadow-sm transition-colors flex items-center gap-2 shrink-0 self-start sm:self-auto"
        >
          {downloaded ? <Check className="w-4 h-4 text-emerald-200" /> : <Download className="w-4 h-4" />}
          <span>{downloaded ? 'Downloaded Specification' : 'Export Whitepaper (MD)'}</span>
        </button>
      </section>

      {/* Visual Infographic Card */}
      <section className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-6 shadow-sm space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Cpu className="w-4 h-4 text-purple-600 dark:text-purple-400" />
            <h2 className="text-sm font-bold text-slate-900 dark:text-slate-100">
              Cognitive Self-RAG & Multi-Step Verification Topology
            </h2>
          </div>
          <span className="text-xs font-mono text-slate-500">Autonomous Reasoning Cycle</span>
        </div>

        <div className="rounded-xl overflow-hidden border border-slate-200 dark:border-slate-800 bg-slate-950 max-h-[420px]">
          <img
            src="/src/assets/images/autonomous_agent_core_1793306563521.jpg"
            alt="Cognitive Reasoning Engine Architecture with Self-Correction Loops"
            referrerPolicy="no-referrer"
            className="w-full h-full object-cover"
          />
        </div>
      </section>

      {/* Whitepaper Content Display */}
      <section className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-6 sm:p-10 shadow-sm space-y-8 text-slate-800 dark:text-slate-200 leading-relaxed text-sm">
        {/* Section 1 */}
        <div className="space-y-3">
          <h2 className="text-lg font-bold text-slate-900 dark:text-slate-100 border-b border-slate-200 dark:border-slate-800 pb-2">
            1. Core Problem Statement & Answer
          </h2>
          <p className="text-slate-700 dark:text-slate-300">
            <strong>Question:</strong> Can an ambient chatbot be loosely coupled from an embedded vector data source like ChromaDB and a reasoning model to act like an independent interface that autonomously resolves user inquiries with high precision?
          </p>
          <p className="text-slate-700 dark:text-slate-300">
            <strong>Definitive Architecture Verdict:</strong> <em>Yes, absolutely.</em> The key is to never couple the client interface directly to ChromaDB or the model API. By introducing an <strong>Asynchronous Event Mesh</strong> and an <strong>Abstract Vector Storage Adapter</strong>, the ambient interface acts as a lightweight observer, while background orchestrators manage semantic search, context critique, and cognitive reasoning.
          </p>
        </div>

        {/* Section 2 */}
        <div className="space-y-4">
          <h2 className="text-lg font-bold text-slate-900 dark:text-slate-100 border-b border-slate-200 dark:border-slate-800 pb-2">
            2. The Decoupled Triad: Three Isolated Core Pillars
          </h2>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="p-4 rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50/60 dark:bg-slate-950/40 space-y-2">
              <span className="text-xs font-bold text-blue-600 dark:text-blue-400 block">Pillar 1: Ambient Interface</span>
              <p className="text-xs text-slate-600 dark:text-slate-400">
                Independent client widget, floating omnibar, or headless observer. Emits standardized JSON event envelopes over Server-Sent Events (SSE). Knows nothing of HNSW indexing or prompt templates.
              </p>
            </div>

            <div className="p-4 rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50/60 dark:bg-slate-950/40 space-y-2">
              <span className="text-xs font-bold text-emerald-600 dark:text-emerald-400 block">Pillar 2: ChromaDB Adapter</span>
              <p className="text-xs text-slate-600 dark:text-slate-400">
                Pluggable vector collection manager. Handles recursive chunking (512 child / 2048 parent), Cosine distance metric calculation, and collection partitioning.
              </p>
            </div>

            <div className="p-4 rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50/60 dark:bg-slate-950/40 space-y-2">
              <span className="text-xs font-bold text-purple-600 dark:text-purple-400 block">Pillar 3: Reasoning Engine</span>
              <p className="text-xs text-slate-600 dark:text-slate-400">
                Gemini 3.8 Flash Thinking model executing Self-RAG reflection. Performs query decomposition, context sufficiency verification, step-by-step thinking traces, and grounded synthesis.
              </p>
            </div>
          </div>
        </div>

        {/* Section 3 */}
        <div className="space-y-3">
          <h2 className="text-lg font-bold text-slate-900 dark:text-slate-100 border-b border-slate-200 dark:border-slate-800 pb-2">
            3. How Autonomous High Precision is Guaranteed
          </h2>
          <p className="text-slate-700 dark:text-slate-300">
            Standard RAG systems suffer from hallucinations when the retrieved context is irrelevant or noisy. This architecture achieves high precision through four algorithmic safeguards:
          </p>

          <ol className="list-decimal list-inside space-y-2 text-xs sm:text-sm text-slate-700 dark:text-slate-300 pl-2">
            <li>
              <strong>Hypothetical Document Embeddings (HyDE):</strong> Before querying ChromaDB, the reasoning model generates a hypothetical factual passage matching the query intent, maximizing cosine vector alignment with the stored knowledge base.
            </li>
            <li>
              <strong>Cosine Distance Thresholding:</strong> Any candidate chunk with a similarity score below the calibrated threshold (e.g., 0.45) is discarded, preventing noise injection.
            </li>
            <li>
              <strong>Context Sufficiency Critique (Self-RAG):</strong> The model assesses whether the retrieved passages contain sufficient factual basis to answer the query. If insufficient, it halts generation and flags the gap rather than guessing.
            </li>
            <li>
              <strong>Deterministic Bracketed Citation Attribution:</strong> Every synthesized sentence is indexed to specific chunk IDs <code className="font-mono text-xs bg-slate-100 dark:bg-slate-800 px-1 py-0.5 rounded">[Source X]</code>, allowing end-users to immediately verify statements.
            </li>
          </ol>
        </div>

        {/* Section 4 */}
        <div className="space-y-3">
          <h2 className="text-lg font-bold text-slate-900 dark:text-slate-100 border-b border-slate-200 dark:border-slate-800 pb-2">
            4. Real-World Deployment Topology
          </h2>
          <p className="text-slate-700 dark:text-slate-300 text-xs sm:text-sm">
            In production, this architecture is deployed as two independent Docker microservices:
          </p>

          <div className="p-4 rounded-xl bg-slate-50 dark:bg-slate-950 font-mono text-xs text-slate-700 dark:text-slate-300 space-y-2 border border-slate-200 dark:border-slate-800">
            <div>• <strong className="text-blue-600 dark:text-blue-400">chromadb-service:</strong> Runs <code className="text-slate-900 dark:text-slate-100">chromadb/chroma:0.6.3</code> with persistent volume mount for HNSW graph storage.</div>
            <div>• <strong className="text-purple-600 dark:text-purple-400">rag-gateway:</strong> Express/Node.js or FastAPI orchestration gateway hosting the Gemini 3.8 Flash SDK, serving the ambient client bundle and managing async SSE queries.</div>
          </div>
        </div>
      </section>
    </div>
  );
};
