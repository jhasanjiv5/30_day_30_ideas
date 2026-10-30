# AmbientRAG Architect & Autonomous Interface

An architecture blueprint and interactive workbench for **ambient, loosely-coupled RAG systems**. It demonstrates how to decouple an independent user interface from embedded or remote vector databases (such as **ChromaDB**) and cognitive reasoning models (such as **Gemini 3.8 Flash Thinking**) to autonomously resolve inquiries with high precision and zero hallucinations.

---

## 1. System Architecture

The core tenet of this architecture is **strict decoupling**: the ambient user interface (floating omnibar, dockable glass drawer, or headless daemon) never imports database drivers, vector indexes, or model SDKs directly. Instead, communication flows through an asynchronous event mesh and standardized adapter sockets.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      1. Ambient Interface Layer                         │
│  • Headless listener / Floating Omnibar / Dockable Peripheral Drawer    │
│  • Dispatches lightweight JSON event envelopes; zero DB/LLM bindings    │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │ Async Pub/Sub (SSE / REST)
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                 2. Asynchronous Event Mesh & Ingress Gateway            │
│  • Decouples client lifecycle from vector index and inference latency   │
│  • Routes queries, deduplicates requests, and buffers streaming results │
└──────────────────┬───────────────────────────────────┬──────────────────┘
                   │                                   │
                   ▼                                   ▼
┌─────────────────────────────────────┐┌──────────────────────────────────┐
│ 3. Pluggable Vector Adapter         ││ 4. Cognitive Reasoning Core      │
│ (ChromaDB / SQLite-VSS)             ││ (Gemini 3.8 Flash Thinking)      │
│ • AbstractVectorStore contract      ││ • Query Intent Decomposition     │
│ • HNSW Cosine Index                 ││ • Self-RAG Context Sufficiency   │
│ • Recursive Parent/Child Chunking   ││ • Multi-Step Thinking Traces     │
└──────────────────┬──────────────────┘└──────────────────┬───────────────┘
                   │                                   │
                   └─────────────────┬─────────────────┘
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                 5. Grounding & Autonomous Actuation Guard               │
│  • Enforces confidence thresholds (>= 90%) before user notification     │
│  • Mandatory bracketed citation attribution: [Source 1], [Source 2]     │
│  • Strict zero-hallucination guardrail suppresses ungrounded claims    │
└─────────────────────────────────────────────────────────────────────────┘
```

### Core Architecture Principles

1. **Pluggable Vector Store (`AbstractVectorStore` Contract):**
   ChromaDB is wrapped behind a uniform `queryByText(query, options)` interface. Swapping between an embedded SQLite-backed ChromaDB, a remote Docker cluster, or a cloud provider (Pinecone, Qdrant) requires zero changes to the ambient client.
2. **Autonomous Cognitive Reasoning (Self-RAG Reflection Loop):**
   The system does not blindly concatenate retrieved text into prompt templates. The reasoning engine executes:
   - **Hypothetical Document Embeddings (HyDE):** Expands ambiguous user inquiries into candidate semantic representations.
   - **Context Sufficiency Check:** Assesses if retrieved passages contain factual proof. If facts are absent, the engine reports the boundary of known information rather than guessing.
   - **Step-by-Step Chain-of-Thought (CoT):** Exposes reasoning traces before formulating the final answer.
   - **Deterministic Citations:** Ties every statement to exact document IDs (`[Source X]`).
3. **Ambient UI Lifecycle:**
   Operates in the periphery of the user workflow. It evaluates context quietly and only surfaces proactive resolutions when grounding confidence exceeds 90%.

---

## 2. Where & How to Connect Vector Stores & Reasoning Models

### Physical Sockets Map

| Socket | Component | File Location | How It Connects |
|---|---|---|---|
| **Socket 1** | **Vector Store** (ChromaDB) | `src/connectors/vectorStore.ts` | Instantiate `chromadb.HttpClient` (remote) or `PersistentClient` (embedded) and expose `queryByText()`. |
| **Socket 2** | **Reasoning Core** (Gemini) | `src/connectors/reasoningEngine.ts` | Instantiate `GoogleGenAI` with `gemini-3.8-flash` and `thinkingLevel: ThinkingLevel.MEDIUM`. |
| **Socket 3** | **Decoupled Router** | `server.ts` (`/api/rag/query`) | Queries Socket 1, passes candidates to Socket 2, and dispatches JSON back to client. |
| **Socket 0** | **Environment Variables** | `.env` | Holds `GEMINI_API_KEY`, `CHROMA_HOST`, and `PORT`. |

### Implementation Snippets

#### Socket 1: Connecting ChromaDB (`src/connectors/vectorStore.ts`)
```typescript
import chromadb from 'chromadb';

const chroma = new chromadb.ChromaClient({
  path: process.env.CHROMA_HOST || 'http://localhost:8000'
});

export async function queryVectorStore(queryText: string, topK = 3) {
  const collection = await chroma.getOrCreateCollection({
    name: 'enterprise_knowledge',
    metadata: { 'hnsw:space': 'cosine' }
  });

  const results = await collection.query({
    queryTexts: [queryText],
    nResults: topK
  });

  return (results.documents[0] || []).map((text, i) => ({
    id: results.ids[0][i],
    title: results.metadatas[0][i]?.title || 'Document',
    text,
    similarityScore: 1.0 - (results.distances?.[0]?.[i] ?? 0.5)
  }));
}
```

#### Socket 2: Connecting Gemini Reasoning Core (`src/connectors/reasoningEngine.ts`)
```typescript
import { GoogleGenAI, Type, ThinkingLevel } from '@google/genai';

const ai = new GoogleGenAI({
  apiKey: process.env.GEMINI_API_KEY,
  httpOptions: { headers: { 'User-Agent': 'aistudio-build' } }
});

export async function executeReasoning(query: string, retrievedChunks: any[]) {
  const contextBlock = retrievedChunks
    .map((c, i) => `[Source ${i + 1} | ID: ${c.id}]\n${c.text}`)
    .join('\n\n');

  const response = await ai.models.generateContent({
    model: 'gemini-3.8-flash',
    contents: `User Query: "${query}"\n\nRetrieved Chunks:\n${contextBlock}`,
    config: {
      systemInstruction: 'Decompose query, verify retrieved facts, cite [Source X], and reject hallucinations.',
      thinkingConfig: { thinkingLevel: ThinkingLevel.MEDIUM },
      responseMimeType: 'application/json',
      responseSchema: {
        type: Type.OBJECT,
        properties: {
          reasoningSteps: { type: Type.ARRAY, items: { type: Type.STRING } },
          answer: { type: Type.STRING },
          precisionScore: { type: Type.NUMBER }
        },
        required: ['reasoningSteps', 'answer', 'precisionScore']
      }
    }
  });

  return JSON.parse(response.text ?? '{}');
}
```

---

## 3. Local Installation & Setup

### Prerequisites
- **Node.js**: `v20.0.0` or higher
- **npm** or **bun**
- **Docker** (recommended for running standalone ChromaDB) or **Python 3.10+** (if running embedded ChromaDB)
- **Gemini API Key** (obtainable from [Google AI Studio](https://aistudio.google.com/))

### Step 1: Clone & Install Dependencies
```bash
git clone <repository-url>
cd <repository-directory>
npm install
```

### Step 2: Configure Environment Variables
Create a local `.env` file based on `.env.example`:
```bash
cp .env.example .env
```
Populate `.env` with your credentials:
```env
# Gemini API Key (Server-side only)
GEMINI_API_KEY="AIzaSy..."

# ChromaDB Host endpoint (default for local Docker instance)
CHROMA_HOST="http://localhost:8000"

# Server Port
PORT=3000
```

### Step 3: Run ChromaDB (Vector Store)

#### Option A: Run via Docker (Recommended)
```bash
docker run -d \
  --name ambient-chromadb \
  -p 8000:8000 \
  -v chroma_data:/chroma/chroma \
  chromadb/chroma:0.6.3
```
Verify ChromaDB is running:
```bash
curl http://localhost:8000/api/v1/heartbeat
# Returns: {"nanosecond heartbeat": ...}
```

#### Option B: Run via Python CLI
```bash
pip install chromadb
chroma run --path ./chroma_data --port 8000
```

### Step 4: Run the Development Server
```bash
npm run dev
```
Open your browser to:
```
http://localhost:3000
```

### Step 5: Production Build & Deployment
Build the client application and start the full-stack server:
```bash
npm run build
npm start
```

### Optional: Docker Compose Multi-Container Deployment
To run both the application gateway and ChromaDB together:
```yaml
# docker-compose.yml
version: '3.9'
services:
  chromadb:
    image: chromadb/chroma:0.6.3
    container_name: ambient-chromadb
    ports:
      - "8000:8000"
    volumes:
      - chroma_data:/chroma/chroma

  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - GEMINI_API_KEY=${GEMINI_API_KEY}
      - CHROMA_HOST=http://chromadb:8000
      - PORT=3000
    depends_on:
      - chromadb

volumes:
  chroma_data:
```
Run with:
```bash
docker compose up -d
```

---

## 4. User Know-How & Application Guide

The application contains 5 coordinated views accessible via the top navigation bar:

### 1. System Blueprint (`/` tab: `System Blueprint`)
- **Interactive Isometric Architecture:** Visual schematic of the 5 decoupled layers.
- **Packet Flow Simulator:** Click **"Simulate Live Packet Flow"** to step through Ingress $\to$ Query Expansion $\to$ ChromaDB HNSW Search $\to$ Self-RAG CoT $\to$ Grounded Delivery.
- **Layer Deep Dive:** Inspect how each layer enforces loose coupling and high precision.

### 2. Integration Guide (`/` tab: `Integration Guide`)
- **Physical Sockets Map:** Visual cards for Socket 1 (Vector Store), Socket 2 (Reasoning Core), and Socket 3 (Gateway Router).
- **Live Connection Handshake Console:** Select your vector store mode (`Remote HTTP` or `Embedded SQLite`), specify the endpoint (`http://localhost:8000`), choose your reasoning model (`Gemini 3.8 Flash`), and click **"Run Socket Handshake"** to test live connectivity.
- **Code Insertion Blueprints:** Ready-to-copy source templates for each integration file.

### 3. Interactive Workbench (`/` tab: `Interactive Workbench`)
- **Query Sandbox:** Submit queries or choose from curated presets.
- **Configurable Parameters:** Toggle the **Parameters** panel to adjust Cosine Similarity Cutoff ($0.2$ to $0.8$) and Top-K candidates ($1$ to $6$).
- **Chain of Thought Inspector:** View step-by-step thinking traces showing how the reasoning model decomposed the query and verified context sufficiency.
- **Retrieved Chunks Inspector:** View the exact passages returned by ChromaDB with cosine similarity scores.

### 4. ChromaDB Store Manager (`/` tab: `ChromaDB Store`)
- **Corpus Ingestion:** Click **"Ingest New Document Chunk"** to add custom knowledge items to the vector store.
- **Latent Vector Space Visualization:** Inspect dense semantic clustering and dimensionality metrics.
- **Search & Filter:** Filter ingested documents by category or search term, and click **"Test Query Grounding"** to immediately test retrieval.

### 5. Ambient Floating Omnibar (Click top right: `Launch Ambient Omnibar`)
- Opens an **independent floating assistant** that lives on the periphery of your desktop.
- Dispatches inquiries over non-blocking envelopes without interrupting your background activities.
- Expands to reveal chain-of-thought traces and citation badges.

---

## 5. Backend REST API Endpoints

### `POST /api/rag/query`
Executes an ambient inquiry through the decoupled RAG pipeline.
- **Request Body:**
  ```json
  {
    "query": "How is loose coupling maintained with ChromaDB?",
    "similarityThreshold": 0.45,
    "topK": 3,
    "vectorStoreType": "chromadb_embedded"
  }
  ```
- **Response:**
  ```json
  {
    "query": "...",
    "answer": "According to ChromaDB Pluggable Adapter Pattern [Source 1]...",
    "reasoningSteps": ["Step 1: ...", "Step 2: ..."],
    "retrievedChunks": [...],
    "citations": [...],
    "factualPrecisionScore": 96,
    "packetEvents": [...],
    "totalLatencyMs": 482
  }
  ```

### `POST /api/connectors/test`
Validates connectivity to ChromaDB and Gemini reasoning models.
- **Request Body:**
  ```json
  {
    "vectorStoreType": "chromadb_remote",
    "vectorEndpoint": "http://localhost:8000",
    "modelType": "gemini-3.8-flash",
    "thinkingLevel": "MEDIUM"
  }
  ```
- **Response:**
  ```json
  {
    "success": true,
    "vectorStore": { "type": "chromadb_remote", "status": "connected" },
    "reasoningEngine": { "model": "gemini-3.8-flash", "status": "active" },
    "logs": [...]
  }
  ```

### `GET /api/health`
Checks server status, API key presence, and active model.

---

## 6. Project Structure

```
├── .env.example                     # Environment template (GEMINI_API_KEY, CHROMA_HOST)
├── package.json                     # Dependencies (@google/genai, express, tailwindcss, react 19)
├── server.ts                        # Full-stack Express server with Vite middleware & RAG APIs
├── tsconfig.json                    # TypeScript compiler configuration
├── vite.config.ts                   # Vite bundler configuration
├── src/
│   ├── App.tsx                      # Root application layout with tabs & theme state
│   ├── main.tsx                     # React 19 entry point
│   ├── index.css                    # Tailwind CSS v4 custom variants & typography
│   ├── connectors/
│   │   ├── vectorStore.ts           # Vector Store Adapter interface & ChromaDB client
│   │   └── reasoningEngine.ts       # Cognitive Reasoning Core & Gemini 3.8 Flash hook
│   ├── components/
│   │   ├── Header.tsx               # 3-Zone navigation header
│   │   ├── ArchitectureView.tsx     # 5-layer interactive blueprint & simulator
│   │   ├── ConnectorsGuide.tsx      # Where & How to Connect guide + live handshake test
│   │   ├── InteractiveWorkbench.tsx # Query sandbox with CoT traces & chunk inspector
│   │   ├── VectorStoreManager.tsx   # ChromaDB collection & chunk manager
│   │   ├── ArchitectureWhitepaper.tsx# Technical whitepaper & export
│   │   └── AmbientWidget.tsx        # Floating decoupled peripheral omnibar
│   ├── data/
│   │   └── defaultCorpus.ts         # Pre-seeded architectural knowledge chunks & preset queries
│   └── types/
│       └── rag.ts                   # TypeScript interfaces for chunks, events, and results
└── README.md                        # Complete architecture, know-how, and installation guide
```

---

## 7. License
Apache-2.0
