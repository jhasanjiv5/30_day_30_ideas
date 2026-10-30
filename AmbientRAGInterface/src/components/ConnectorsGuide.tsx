import React, { useState } from 'react';
import { 
  Plug, 
  Cpu, 
  Database, 
  ArrowRight, 
  Check, 
  Copy, 
  Terminal, 
  Play, 
  CheckCircle2, 
  AlertCircle, 
  Layers, 
  Code2, 
  Server,
  FileCode,
  ShieldAlert,
  Sparkles
} from 'lucide-react';

interface ConnectorsGuideProps {
  onNavigateToWorkbench: () => void;
}

export const ConnectorsGuide: React.FC<ConnectorsGuideProps> = ({ onNavigateToWorkbench }) => {
  const [selectedVectorStore, setSelectedVectorStore] = useState<'chroma_embedded' | 'chroma_remote' | 'qdrant_pinecone'>('chroma_remote');
  const [selectedModel, setSelectedModel] = useState<'gemini_38_flash' | 'gemini_4_argon' | 'local_ollama'>('gemini_38_flash');
  const [activeSocketTab, setActiveSocketTab] = useState<'socket_vector' | 'socket_reasoning' | 'socket_gateway' | 'env_file'>('socket_vector');
  const [copied, setCopied] = useState<boolean>(false);

  // Live test state
  const [testingConnection, setTestingConnection] = useState<boolean>(false);
  const [testResponse, setTestResponse] = useState<any>(null);
  const [endpointInput, setEndpointInput] = useState<string>('http://localhost:8000');

  const handleCopy = (text: string) => {
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const runConnectionTest = async () => {
    setTestingConnection(true);
    setTestResponse(null);
    try {
      const res = await fetch('/api/connectors/test', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          vectorStoreType: selectedVectorStore === 'chroma_remote' ? 'chromadb_remote' : 'chromadb_embedded',
          vectorEndpoint: endpointInput,
          modelType: selectedModel === 'gemini_38_flash' ? 'gemini-3.8-flash' : selectedModel === 'gemini_4_argon' ? 'gemini-4-argon' : 'local-reasoning-model',
          thinkingLevel: 'MEDIUM'
        })
      });
      const data = await res.json();
      setTestResponse(data);
    } catch (err: any) {
      setTestResponse({
        success: false,
        logs: [
          {
            timestamp: new Date().toISOString().split('T')[1].slice(0, 8),
            step: 'NETWORK_ERROR',
            status: 'error',
            message: `Connection test failed: ${err?.message}`
          }
        ]
      });
    } finally {
      setTestingConnection(false);
    }
  };

  const codeSnippets = {
    socket_vector: {
      title: 'Socket 1: Vector Store Adapter (ChromaDB)',
      filePath: 'src/connectors/vectorStore.ts (or python backend vector_store.py)',
      description: 'Where ChromaDB plugs into the system. Exposes a clean query interface without exposing raw DB calls to the client UI.',
      code: `// ==============================================================================
// WHERE TO CONNECT: src/connectors/vectorStore.ts (Server-Side)
// HOW TO CONNECT: Instantiate ChromaDB client & wrap in VectorStoreAdapter
// ==============================================================================

import chromadb from 'chromadb'; // or Python: import chromadb

// 1. Choose Connection Mode:
// Option A: Remote Standalone ChromaDB Server (Docker or Cloud)
const chroma = new chromadb.ChromaClient({
  path: process.env.CHROMA_HOST || "${endpointInput}"
});

// Option B: In-Process Persistent SQLite Store
// const chroma = new chromadb.PersistentClient({ path: "./chroma_data" });

export async function queryVectorStore(queryText: string, topK = 3) {
  // Connect to the specific knowledge collection
  const collection = await chroma.getOrCreateCollection({
    name: "enterprise_knowledge",
    metadata: { "hnsw:space": "cosine" } // Use Cosine distance
  });

  // Query nearest semantic neighbors
  const results = await collection.query({
    queryTexts: [queryText],
    nResults: topK
  });

  // Return normalized chunk objects
  return (results.documents[0] || []).map((text, i) => ({
    id: results.ids[0][i],
    title: results.metadatas[0][i]?.title || 'Document',
    text,
    similarityScore: 1.0 - (results.distances?.[0]?.[i] ?? 0.5)
  }));
}`
    },
    socket_reasoning: {
      title: 'Socket 2: Cognitive Reasoning Model (Gemini 3.8 Flash)',
      filePath: 'src/connectors/reasoningEngine.ts (or server.ts)',
      description: 'Where the reasoning model is initialized. Performs multi-step thinking, evaluates context sufficiency, and grounds citations.',
      code: `// ==============================================================================
// WHERE TO CONNECT: src/connectors/reasoningEngine.ts (Server-Side)
// HOW TO CONNECT: @google/genai SDK with ThinkingLevel & Structured JSON
// ==============================================================================

import { GoogleGenAI, Type, ThinkingLevel } from "@google/genai";

// 1. Initialize client using server-only process.env.GEMINI_API_KEY
const ai = new GoogleGenAI({
  apiKey: process.env.GEMINI_API_KEY,
  httpOptions: {
    headers: { 'User-Agent': 'aistudio-build' }
  }
});

// 2. Execute reasoning with Self-RAG reflection & citation grounding
export async function executeReasoning(query: string, retrievedChunks: any[]) {
  const contextSnippet = retrievedChunks
    .map((c, i) => \`[Source \${i + 1} | ID: \${c.id}]\n\${c.text}\`)
    .join("\\n\\n");

  const systemInstruction = 
    "You are an autonomous cognitive reasoning core. " +
    "Deconstruct the user inquiry, evaluate if the retrieved vector context is sufficient, " +
    "and synthesize an authoritative answer. Strictly cite sources as [Source X]. " +
    "Never invent facts not present in the retrieved passages.";

  const response = await ai.models.generateContent({
    model: "gemini-3.8-flash", // Target model
    contents: \`User Query: "\${query}"\\n\\nRetrieved Knowledge:\\n\${contextSnippet}\`,
    config: {
      systemInstruction,
      thinkingConfig: {
        thinkingLevel: ThinkingLevel.MEDIUM // Balances reasoning depth & latency
      },
      responseMimeType: "application/json",
      responseSchema: {
        type: Type.OBJECT,
        properties: {
          reasoningSteps: {
            type: Type.ARRAY,
            items: { type: Type.STRING },
            description: "Step-by-step thinking trace decomposing query and validating context"
          },
          answer: {
            type: Type.STRING,
            description: "Authoritative grounded answer with [Source X] citations"
          },
          precisionScore: {
            type: Type.NUMBER,
            description: "Factual confidence score (0-100)"
          }
        },
        required: ["reasoningSteps", "answer", "precisionScore"]
      }
    }
  });

  return JSON.parse(response.text ?? "{}");
}`
    },
    socket_gateway: {
      title: 'Socket 3: Decoupled Pipeline Router',
      filePath: 'server.ts (or FastAPI main.py)',
      description: 'Where the Vector Store and Reasoning Model are connected together inside the server controller.',
      code: `// ==============================================================================
// WHERE TO CONNECT: server.ts (The Bridge Router)
// HOW TO CONNECT: Accepts ambient inquiry -> calls Vector Store -> calls LLM
// ==============================================================================

import express from 'express';
import { queryVectorStore } from './src/connectors/vectorStore';
import { executeReasoning } from './src/connectors/reasoningEngine';

const app = express();
app.use(express.json());

// Main Ambient Ingress Route
app.post('/api/rag/query', async (req, res) => {
  const { query, ambientContext } = req.body;

  // Step 1: Query the Vector Store (ChromaDB)
  const chunks = await queryVectorStore(query, 3);

  // Step 2: Feed retrieved chunks into the Cognitive Reasoning Core (Gemini)
  const resolution = await executeReasoning(query, chunks, ambientContext);

  // Step 3: Dispatch decoupled response back to ambient UI
  res.json({
    query,
    answer: resolution.answer,
    reasoningSteps: resolution.reasoningSteps,
    retrievedChunks: chunks,
    precisionScore: resolution.precisionScore
  });
});`
    },
    env_file: {
      title: 'Socket 0: Environment Variables & Endpoints',
      filePath: '.env (or Secrets panel)',
      description: 'The connection credentials and service host URLs required to bind the vector store and reasoning model.',
      code: `# ==============================================================================
# WHERE TO CONFIGURE: /.env
# HOW TO CONFIGURE: Set your ChromaDB URL and Gemini API Key
# ==============================================================================

# 1. Reasoning Model API Key (Injected automatically in AI Studio)
GEMINI_API_KEY="YOUR_GEMINI_API_KEY"

# 2. Vector Store Configuration (ChromaDB)
CHROMA_HOST="http://localhost:8000"
CHROMA_COLLECTION_NAME="enterprise_knowledge"
CHROMA_DISTANCE_METRIC="cosine"

# 3. Ambient Gateway Port & Environment
PORT=3000
NODE_ENV="development"`
    }
  };

  const activeSnippet = codeSnippets[activeSocketTab];

  return (
    <div className="space-y-10">
      {/* Hero Overview */}
      <section className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-6 sm:p-8 lg:p-10 shadow-sm">
        <div className="max-w-3xl space-y-3">
          <div className="flex items-center gap-2 text-xs font-medium text-slate-500 dark:text-slate-400">
            <span>Implementation Guide</span>
            <span aria-hidden="true">·</span>
            <span>Pluggable Sockets</span>
            <span aria-hidden="true">·</span>
            <span>Zero-Coupling Contract</span>
          </div>

          <h1 className="text-2xl sm:text-3xl font-extrabold text-slate-900 dark:text-slate-100 tracking-tight">
            Where & How to Connect Vector Stores & Reasoning Models
          </h1>

          <p className="text-slate-600 dark:text-slate-300 text-sm sm:text-base leading-relaxed">
            In an ambient loosely-connected architecture, the ambient interface never touches database drivers or model weights directly. This guide explicitly maps the <strong>exact insertion points</strong> in your code, shows the <strong>exact connection strings</strong>, and provides an interactive test bench to verify live handshakes.
          </p>
        </div>
      </section>

      {/* Visual Architectural Sockets Map ("WHERE") */}
      <section className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-6 sm:p-8 shadow-sm space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-lg font-bold text-slate-900 dark:text-slate-100 flex items-center gap-2">
              <Plug className="w-5 h-5 text-blue-500" />
              <span>Physical Connection Points in Your Project</span>
            </h2>
            <p className="text-xs text-slate-500 dark:text-slate-400">
              Click any socket below to jump directly to its code implementation and connection rules.
            </p>
          </div>
        </div>

        {/* 3 Physical Sockets Grid */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
          {/* Socket 1 */}
          <div
            onClick={() => setActiveSocketTab('socket_vector')}
            className={`cursor-pointer p-5 rounded-xl border transition-all ${
              activeSocketTab === 'socket_vector'
                ? 'border-emerald-500 bg-emerald-50/30 dark:bg-emerald-950/20 shadow-sm ring-1 ring-emerald-500'
                : 'border-slate-200 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-950/40 hover:border-slate-300 dark:hover:border-slate-700'
            }`}
          >
            <div className="flex items-center justify-between text-xs mb-2">
              <span className="font-mono text-[10px] text-emerald-600 dark:text-emerald-400 font-bold uppercase tracking-wider">
                Socket 1 · Data Tier
              </span>
              <Database className="w-4 h-4 text-emerald-500" />
            </div>
            <h3 className="text-sm font-bold text-slate-900 dark:text-slate-100 mb-1">
              ChromaDB Vector Adapter
            </h3>
            <div className="text-[11px] font-mono text-slate-500 dark:text-slate-400 mb-2 truncate">
              src/connectors/vectorStore.ts
            </div>
            <p className="text-xs text-slate-600 dark:text-slate-400 leading-relaxed">
              <strong>Where:</strong> Server-side adapter.<br />
              <strong>How:</strong> Wrap ChromaDB client in <code className="font-mono text-[11px]">queryVectorStore()</code> using cosine distance.
            </p>
          </div>

          {/* Socket 2 */}
          <div
            onClick={() => setActiveSocketTab('socket_reasoning')}
            className={`cursor-pointer p-5 rounded-xl border transition-all ${
              activeSocketTab === 'socket_reasoning'
                ? 'border-purple-500 bg-purple-50/30 dark:bg-purple-950/20 shadow-sm ring-1 ring-purple-500'
                : 'border-slate-200 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-950/40 hover:border-slate-300 dark:hover:border-slate-700'
            }`}
          >
            <div className="flex items-center justify-between text-xs mb-2">
              <span className="font-mono text-[10px] text-purple-600 dark:text-purple-400 font-bold uppercase tracking-wider">
                Socket 2 · Cognitive Core
              </span>
              <Cpu className="w-4 h-4 text-purple-500" />
            </div>
            <h3 className="text-sm font-bold text-slate-900 dark:text-slate-100 mb-1">
              Gemini 3.8 Flash Reasoning
            </h3>
            <div className="text-[11px] font-mono text-slate-500 dark:text-slate-400 mb-2 truncate">
              src/connectors/reasoningEngine.ts
            </div>
            <p className="text-xs text-slate-600 dark:text-slate-400 leading-relaxed">
              <strong>Where:</strong> Server-side LLM hook.<br />
              <strong>How:</strong> Call <code className="font-mono text-[11px]">ai.models.generateContent</code> with <code className="font-mono text-[11px]">thinkingLevel</code> & schema.
            </p>
          </div>

          {/* Socket 3 */}
          <div
            onClick={() => setActiveSocketTab('socket_gateway')}
            className={`cursor-pointer p-5 rounded-xl border transition-all ${
              activeSocketTab === 'socket_gateway'
                ? 'border-blue-500 bg-blue-50/30 dark:bg-blue-950/20 shadow-sm ring-1 ring-blue-500'
                : 'border-slate-200 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-950/40 hover:border-slate-300 dark:hover:border-slate-700'
            }`}
          >
            <div className="flex items-center justify-between text-xs mb-2">
              <span className="font-mono text-[10px] text-blue-600 dark:text-blue-400 font-bold uppercase tracking-wider">
                Socket 3 · Bridge Router
              </span>
              <Server className="w-4 h-4 text-blue-500" />
            </div>
            <h3 className="text-sm font-bold text-slate-900 dark:text-slate-100 mb-1">
              Decoupled Ingress Router
            </h3>
            <div className="text-[11px] font-mono text-slate-500 dark:text-slate-400 mb-2 truncate">
              server.ts (/api/rag/query)
            </div>
            <p className="text-xs text-slate-600 dark:text-slate-400 leading-relaxed">
              <strong>Where:</strong> Express or FastAPI route.<br />
              <strong>How:</strong> Receives ambient payload, queries Socket 1, passes context to Socket 2, returns JSON.
            </p>
          </div>
        </div>
      </section>

      {/* Live Handshake & Connection Test Console ("VERIFY") */}
      <section className="bg-slate-900 text-white rounded-2xl p-6 sm:p-8 border border-slate-800 space-y-6">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h2 className="text-base font-bold text-white flex items-center gap-2">
              <Terminal className="w-4 h-4 text-emerald-400" />
              <span>Interactive Connection Verification & Handshake Test</span>
            </h2>
            <p className="text-xs text-slate-400">
              Simulate or test the live socket handshakes between ChromaDB, Gemini, and the server gateway.
            </p>
          </div>

          <button
            onClick={runConnectionTest}
            disabled={testingConnection}
            className="px-4 py-2 text-xs font-semibold rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white transition-colors flex items-center gap-2 shadow-sm disabled:opacity-50 self-start sm:self-auto"
          >
            <Play className="w-3.5 h-3.5" />
            <span>{testingConnection ? 'Running Handshake...' : 'Run Socket Handshake'}</span>
          </button>
        </div>

        {/* Connection Options */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 pt-2 text-xs">
          <div>
            <label className="text-slate-300 font-medium block mb-1">
              Target Vector Store
            </label>
            <select
              value={selectedVectorStore}
              onChange={e => setSelectedVectorStore(e.target.value as any)}
              className="w-full bg-slate-950 border border-slate-700 rounded-lg px-3 py-2 text-slate-200 text-xs focus:outline-none focus:ring-1 focus:ring-emerald-500"
            >
              <option value="chroma_remote">ChromaDB Standalone (HTTP / Port 8000)</option>
              <option value="chroma_embedded">ChromaDB Embedded (In-process SQLite)</option>
              <option value="qdrant_pinecone">Abstract Adapter (Pinecone / Qdrant)</option>
            </select>
          </div>

          <div>
            <label className="text-slate-300 font-medium block mb-1">
              ChromaDB Endpoint URL
            </label>
            <input
              type="text"
              value={endpointInput}
              onChange={e => setEndpointInput(e.target.value)}
              placeholder="http://localhost:8000"
              className="w-full bg-slate-950 border border-slate-700 rounded-lg px-3 py-2 text-slate-200 font-mono text-xs focus:outline-none focus:ring-1 focus:ring-emerald-500"
            />
          </div>

          <div>
            <label className="text-slate-300 font-medium block mb-1">
              Target Reasoning Core
            </label>
            <select
              value={selectedModel}
              onChange={e => setSelectedModel(e.target.value as any)}
              className="w-full bg-slate-950 border border-slate-700 rounded-lg px-3 py-2 text-slate-200 text-xs focus:outline-none focus:ring-1 focus:ring-emerald-500"
            >
              <option value="gemini_38_flash">Gemini 3.8 Flash (Thinking Level: MEDIUM)</option>
              <option value="gemini_4_argon">Gemini 4 Argon (Deep Reasoning / STEM)</option>
              <option value="local_ollama">Local Self-Hosted Reasoning Model</option>
            </select>
          </div>
        </div>

        {/* Live Test Console Output */}
        <div className="rounded-xl bg-slate-950 border border-slate-800 p-4 font-mono text-xs space-y-2">
          <div className="flex items-center justify-between text-[11px] text-slate-400 border-b border-slate-800 pb-2">
            <span>SOCKET HANDSHAKE TELEMETRY</span>
            <span>PORT: 3000 ⟷ TARGET: CHROMA & GEMINI</span>
          </div>

          {!testResponse && !testingConnection && (
            <div className="text-slate-500 py-3 text-center">
              Click "Run Socket Handshake" to verify environment bindings, vector health, and model thinking readiness.
            </div>
          )}

          {testingConnection && (
            <div className="text-emerald-400 py-3 flex items-center justify-center gap-2">
              <span className="animate-spin font-mono">⟳</span>
              <span>Probing vector socket and model API keys...</span>
            </div>
          )}

          {testResponse && (
            <div className="space-y-1.5 pt-1">
              {testResponse.logs?.map((log: any, idx: number) => (
                <div key={idx} className="flex items-start gap-2 text-[11px]">
                  <span className="text-slate-500">[{log.timestamp}]</span>
                  <span
                    className={`font-semibold shrink-0 ${
                      log.status === 'ok'
                        ? 'text-emerald-400'
                        : log.status === 'warn'
                        ? 'text-amber-400'
                        : log.status === 'error'
                        ? 'text-red-400'
                        : 'text-blue-400'
                    }`}
                  >
                    {log.step}:
                  </span>
                  <span className="text-slate-300">{log.message}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      </section>

      {/* Code Inspector with Direct Copy ("HOW TO CODE IT") */}
      <section className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-6 sm:p-8 space-y-5 shadow-sm">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h2 className="text-lg font-bold text-slate-900 dark:text-slate-100 flex items-center gap-2">
              <Code2 className="w-5 h-5 text-purple-500" />
              <span>Exact Code Insertion Blueprints</span>
            </h2>
            <p className="text-xs text-slate-500 dark:text-slate-400">
              Inspect the exact code to drop into each file to complete your integration.
            </p>
          </div>

          <button
            onClick={() => handleCopy(activeSnippet.code)}
            className="px-3.5 py-1.5 text-xs font-medium rounded-lg border border-slate-200 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800 text-slate-700 dark:text-slate-200 transition-colors flex items-center gap-1.5 self-start sm:self-auto"
          >
            {copied ? <Check className="w-3.5 h-3.5 text-emerald-500" /> : <Copy className="w-3.5 h-3.5" />}
            <span>{copied ? 'Copied' : 'Copy Code Snippet'}</span>
          </button>
        </div>

        {/* Tab Selector */}
        <div className="flex flex-wrap gap-1 p-1 bg-slate-100 dark:bg-slate-800 rounded-lg">
          <button
            onClick={() => setActiveSocketTab('socket_vector')}
            className={`px-3 py-1.5 text-xs font-medium rounded-md transition-colors ${
              activeSocketTab === 'socket_vector'
                ? 'bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 shadow-sm'
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200'
            }`}
          >
            1. Vector Store (vectorStore.ts)
          </button>
          <button
            onClick={() => setActiveSocketTab('socket_reasoning')}
            className={`px-3 py-1.5 text-xs font-medium rounded-md transition-colors ${
              activeSocketTab === 'socket_reasoning'
                ? 'bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 shadow-sm'
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200'
            }`}
          >
            2. Reasoning Core (reasoningEngine.ts)
          </button>
          <button
            onClick={() => setActiveSocketTab('socket_gateway')}
            className={`px-3 py-1.5 text-xs font-medium rounded-md transition-colors ${
              activeSocketTab === 'socket_gateway'
                ? 'bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 shadow-sm'
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200'
            }`}
          >
            3. Router Glue (server.ts)
          </button>
          <button
            onClick={() => setActiveSocketTab('env_file')}
            className={`px-3 py-1.5 text-xs font-medium rounded-md transition-colors ${
              activeSocketTab === 'env_file'
                ? 'bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 shadow-sm'
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200'
            }`}
          >
            0. Environment (.env)
          </button>
        </div>

        {/* Active Tab Info Box */}
        <div className="p-4 rounded-xl bg-slate-50 dark:bg-slate-800/40 border border-slate-200 dark:border-slate-800 space-y-1">
          <div className="flex items-center justify-between text-xs">
            <span className="font-bold text-slate-900 dark:text-slate-100">{activeSnippet.title}</span>
            <span className="font-mono text-slate-500 dark:text-slate-400">{activeSnippet.filePath}</span>
          </div>
          <p className="text-xs text-slate-600 dark:text-slate-300">
            {activeSnippet.description}
          </p>
        </div>

        {/* Code Block */}
        <div className="relative rounded-xl overflow-hidden border border-slate-800 bg-slate-950">
          <pre className="p-4 text-xs font-mono text-slate-200 overflow-x-auto leading-relaxed max-h-[460px]">
            {activeSnippet.code}
          </pre>
        </div>
      </section>

      {/* Step-by-Step 4-Stage Setup Checklist */}
      <section className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-6 sm:p-8 space-y-6 shadow-sm">
        <div>
          <h2 className="text-lg font-bold text-slate-900 dark:text-slate-100">
            4-Step Production Setup Walkthrough
          </h2>
          <p className="text-xs text-slate-500 dark:text-slate-400">
            Follow this chronological order to connect and deploy your ambient RAG stack.
          </p>
        </div>

        <div className="space-y-4">
          {[
            {
              step: 'Step 1: Launch ChromaDB Vector Service',
              detail: 'Run ChromaDB in Docker or install in Python.',
              command: 'docker run -d -p 8000:8000 -v chroma_data:/chroma/chroma chromadb/chroma:0.6.3',
              notes: 'ChromaDB starts an embedded SQLite/HNSW index on port 8000.'
            },
            {
              step: 'Step 2: Install @google/genai & Server Dependencies',
              detail: 'Install the official Gemini SDK (>= 2.25.0) and Express/FastAPI.',
              command: 'npm install @google/genai dotenv express',
              notes: 'Required for Gemini 3.8 Flash, thinkingLevel, and structured JSON schemas.'
            },
            {
              step: 'Step 3: Wire Vector & Reasoning Sockets in server.ts',
              detail: 'Mount the queryVectorStore() and executeReasoning() adapters into your API route.',
              command: 'cat src/connectors/vectorStore.ts src/connectors/reasoningEngine.ts',
              notes: 'The server acts as the decoupling mediator so the ambient UI never imports database drivers.'
            },
            {
              step: 'Step 4: Connect the Ambient Client UI',
              detail: 'Dispatch user inquiries over non-blocking fetch or SSE from the Omnibar.',
              command: 'fetch("/api/rag/query", { method: "POST", body: JSON.stringify({ query }) })',
              notes: 'The ambient UI renders verified citations [Source 1] and step-by-step thinking traces.'
            }
          ].map((item, idx) => (
            <div
              key={idx}
              className="p-4 rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50/60 dark:bg-slate-950/40 space-y-2"
            >
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-slate-900 dark:text-slate-100">
                  {item.step}
                </span>
                <span className="text-[10px] font-mono text-slate-500 dark:text-slate-400">
                  Phase {idx + 1}
                </span>
              </div>
              <p className="text-xs text-slate-600 dark:text-slate-400">
                {item.detail}
              </p>
              <div className="p-2.5 rounded-lg bg-slate-900 text-slate-200 font-mono text-[11px] flex items-center justify-between overflow-x-auto">
                <span>$ {item.command}</span>
                <button
                  onClick={() => handleCopy(item.command)}
                  className="text-slate-400 hover:text-white transition-colors text-xs ml-2"
                >
                  <Copy className="w-3 h-3" />
                </button>
              </div>
              <p className="text-[11px] text-slate-500 dark:text-slate-400 italic">
                {item.notes}
              </p>
            </div>
          ))}
        </div>

        <div className="pt-2 flex items-center justify-between border-t border-slate-200 dark:border-slate-800">
          <span className="text-xs text-slate-500 dark:text-slate-400">
            Ready to test live queries against this pipeline?
          </span>
          <button
            onClick={onNavigateToWorkbench}
            className="px-4 py-2 text-xs font-semibold rounded-lg bg-blue-600 hover:bg-blue-700 text-white transition-colors flex items-center gap-1.5"
          >
            <span>Launch Interactive Workbench</span>
            <ArrowRight className="w-3.5 h-3.5" />
          </button>
        </div>
      </section>
    </div>
  );
};
