import React, { useState } from 'react';
import { 
  Server, 
  Layers, 
  Database, 
  BrainCircuit, 
  ShieldCheck, 
  Code2, 
  ArrowRight, 
  Activity, 
  CheckCircle2, 
  Copy, 
  Check, 
  Sparkles,
  ExternalLink
} from 'lucide-react';
import { ArchitectureLayer } from '../types/rag';

interface ArchitectureViewProps {
  onTestInquiry: (query: string) => void;
  onNavigateToConnectors?: () => void;
}

const LAYERS: ArchitectureLayer[] = [
  {
    id: 'layer-ambient-ui',
    name: '1. Ambient Interface Layer',
    subtitle: 'Decoupled, non-intrusive peripheral UX',
    role: 'Observes user context and accepts inquiries via floating omnibar, dockable glass drawer, or headless DOM listener without blocking user tasks.',
    decouplingMechanism: 'Communicates strictly over async SSE / WebSocket event streams or REST postback; contains zero database or embedding logic.',
    precisionImpact: 'Filters out spurious triggers; enforces high confidence thresholds (>90%) before interrupting user workflow.',
    techStack: ['React 19', 'Tailwind CSS', 'EventSource / SSE', 'Web Workers'],
    protocol: 'SSE / JSON RPC',
    diagramColor: 'border-blue-500'
  },
  {
    id: 'layer-event-mesh',
    name: '2. Asynchronous Event Mesh & Gateway',
    subtitle: 'Decoupling buffer & orchestrator',
    role: 'Receives ambient inquiries, deduplicates queries, enforces rate limiting, and dispatches parallel tasks to vector stores and reasoning engines.',
    decouplingMechanism: 'Pub/Sub queue architecture. Vector store changes or agent updates do not alter client contract (AsyncAPI specification).',
    precisionImpact: 'Enables asynchronous multi-query generation and parallel HyDE retrieval before passing context to the model.',
    techStack: ['Redis Streams', 'NATS Core', 'FastAPI Gateway', 'RabbitMQ'],
    protocol: 'Async Pub/Sub',
    diagramColor: 'border-cyan-500'
  },
  {
    id: 'layer-vector-store',
    name: '3. Pluggable ChromaDB Vector Store',
    subtitle: 'Embeddings & HNSW semantic cluster index',
    role: 'Stores document chunks, generates dense semantic embeddings, and executes high-speed k-NN / Cosine distance searches over domain corpus.',
    decouplingMechanism: 'Standardized AbstractVectorStore interface. ChromaDB can run in-memory, embedded via SQLite, or as a standalone cluster.',
    precisionImpact: 'Hierarchical chunking (parent 2048 / child 512 tokens) with metadata filtering eliminates irrelevant token noise.',
    techStack: ['ChromaDB 0.6+', 'HNSW Index', 'Gemini / Text Embeddings', 'DuckDB'],
    protocol: 'gRPC / HTTP REST',
    diagramColor: 'border-emerald-500'
  },
  {
    id: 'layer-reasoning-core',
    name: '4. Cognitive Reasoning Engine (Gemini 3.8 Flash)',
    subtitle: 'Autonomous Chain of Thought & Self-RAG',
    role: 'Performs multi-step query decomposition, evaluates retrieved context sufficiency, and generates rigorous factual synthesis.',
    decouplingMechanism: 'Stateless LLM inference receiving normalized JSON schema. Model vendor can be swapped without touching DB.',
    precisionImpact: 'Self-RAG reflection loop: explicitly checks if facts are grounded in retrieved chunks before formulating the answer.',
    techStack: ['@google/genai', 'Gemini 3.8 Flash', 'Structured JSON Schema', 'Chain of Thought'],
    protocol: 'HTTPS / Structured JSON',
    diagramColor: 'border-purple-500'
  },
  {
    id: 'layer-precision-guard',
    name: '5. Grounding & Autonomous Actuation Guard',
    subtitle: 'Citation verification & fallback protection',
    role: 'Verifies every claim against ChromaDB chunk IDs, rejects hallucinated extrapolations, and formats verified resolutions.',
    decouplingMechanism: 'Independent post-processing evaluator running deterministic lexical verification and source attribution.',
    precisionImpact: 'Guarantees zero-hallucination compliance by suppressing ungrounded statements and providing exact source references.',
    techStack: ['Deterministic Citation Matcher', 'Strict JSON Validator', 'Feedback Loop'],
    protocol: 'In-Memory Pipeline',
    diagramColor: 'border-amber-500'
  }
];

export const ArchitectureView: React.FC<ArchitectureViewProps> = ({ 
  onTestInquiry, 
  onNavigateToConnectors 
}) => {
  const [activeLayer, setActiveLayer] = useState<string>(LAYERS[0].id);
  const [activeCodeTab, setActiveCodeTab] = useState<'fastapi_chroma' | 'client_hook' | 'gemini_reasoning' | 'docker'>('fastapi_chroma');
  const [copied, setCopied] = useState<boolean>(false);
  const [simulationStep, setSimulationStep] = useState<number>(0);
  const [isSimulating, setIsSimulating] = useState<boolean>(false);

  const currentLayer = LAYERS.find(l => l.id === activeLayer) || LAYERS[0];

  const runSimulation = () => {
    setIsSimulating(true);
    setSimulationStep(1);
    const intervals = [700, 1500, 2300, 3100, 3800];
    intervals.forEach((delay, idx) => {
      setTimeout(() => {
        setSimulationStep(idx + 1);
        if (idx === intervals.length - 1) {
          setTimeout(() => setIsSimulating(false), 800);
        }
      }, delay);
    });
  };

  const handleCopyCode = (code: string) => {
    navigator.clipboard.writeText(code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const codeSnippets = {
    fastapi_chroma: `# ==============================================================================
# Microservice: ChromaDB Adapter & Query Dispatcher (Python / FastAPI)
# Loose Coupling: Exposes clean REST/WebSocket endpoints for ambient clients.
# ==============================================================================

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import chromadb
from chromadb.config import Settings
from typing import List, Optional

app = FastAPI(title="Ambient ChromaDB Decoupled Service")

# Initialize ChromaDB in embedded or client-server mode
chroma_client = chromadb.PersistentClient(path="./chroma_data")
collection = chroma_client.get_or_create_collection(
    name="enterprise_knowledge",
    metadata={"hnsw:space": "cosine"}
)

class QueryPayload(BaseModel):
    query: str
    top_k: Optional[int] = 3
    filter_metadata: Optional[dict] = None

@app.post("/api/v1/vector/retrieve")
async def retrieve_context(payload: QueryPayload):
    """
    Decoupled vector retrieval interface.
    Returns ranked chunks with cosine similarity distances.
    """
    results = collection.query(
        query_texts=[payload.query],
        n_results=payload.top_k,
        where=payload.filter_metadata
    )
    
    formatted_chunks = []
    if results and "documents" in results and results["documents"]:
        docs = results["documents"][0]
        distances = results.get("distances", [[]])[0]
        metadatas = results.get("metadatas", [[]])[0]
        ids = results.get("ids", [[]])[0]
        
        for i, text in enumerate(docs):
            # Cosine similarity calculation: 1 - cosine distance
            sim_score = round(1.0 - (distances[i] if i < len(distances) else 0.5), 4)
            formatted_chunks.append({
                "id": ids[i],
                "text": text,
                "metadata": metadatas[i] if i < len(metadatas) else {},
                "similarity_score": sim_score
            })
            
    return {"query": payload.query, "chunks": formatted_chunks}`,

    client_hook: `// ==============================================================================
// Ambient Client Hook: React 19 + TypeScript
// Loose Coupling: Decoupled from backend DB; connects via SSE event stream.
// ==============================================================================

import { useState, useCallback } from 'react';

export function useAmbientRAG() {
  const [isProcessing, setIsProcessing] = useState(false);
  const [traceLogs, setTraceLogs] = useState<string[]>([]);

  const dispatchInquiry = useCallback(async (query: string) => {
    setIsProcessing(true);
    setTraceLogs(prev => [...prev, \`[Ambient Interface] Query dispatched: "\${query}"\`]);

    try {
      const response = await fetch('/api/rag/query', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          query,
          vectorStoreType: 'chromadb_embedded',
          similarityThreshold: 0.45,
          topK: 3
        })
      });

      const result = await response.json();
      return result;
    } catch (err) {
      console.error('Ambient resolution error:', err);
      throw err;
    } finally {
      setIsProcessing(false);
    }
  }, []);

  return { dispatchInquiry, isProcessing, traceLogs };
}`,

    gemini_reasoning: `// ==============================================================================
// Server-Side Reasoning Core with @google/genai (Gemini 3.8 Flash)
// Precision: Chain of Thought + Context Sufficiency + Citation Grounding
// ==============================================================================

import { GoogleGenAI, Type } from "@google/genai";

const ai = new GoogleGenAI({
  apiKey: process.env.GEMINI_API_KEY,
  httpOptions: {
    headers: { 'User-Agent': 'aistudio-build' }
  }
});

export async function executeReasoningWithRAG(query: string, retrievedChunks: any[]) {
  const contextBlock = retrievedChunks
    .map((c, i) => \`[Source \${i + 1} | ID: \${c.id}]\n\${c.text}\`)
    .join("\\n\\n");

  const systemInstruction = 
    "You are an autonomous cognitive reasoning core. " +
    "Deconstruct the user inquiry, evaluate if the retrieved vector context is sufficient, " +
    "and synthesize an authoritative answer. Strictly cite sources as [Source X]. " +
    "Never invent facts not present in the retrieved passages.";

  const response = await ai.models.generateContent({
    model: "gemini-3.8-flash",
    contents: \`User Query: "\${query}"\\n\\nRetrieved Chunks:\\n\${contextBlock}\`,
    config: {
      systemInstruction,
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
            description: "High-precision response with [Source X] citations"
          },
          precisionScore: {
            type: Type.NUMBER,
            description: "Factual grounding confidence (0 to 100)"
          }
        },
        required: ["reasoningSteps", "answer", "precisionScore"]
      }
    }
  });

  return JSON.parse(response.text ?? "{}");
}`,

    docker: `# ==============================================================================
# Docker Compose: Loosely-Connected Ambient RAG Architecture
# Services: ChromaDB Vector DB + Node Gateway + Python Ingestion Worker
# ==============================================================================

version: '3.9'

services:
  chromadb:
    image: chromadb/chroma:0.6.3
    container_name: ambient-chromadb
    ports:
      - "8000:8000"
    volumes:
      - chroma_data:/chroma/chroma
    environment:
      - IS_PERSISTENT=TRUE
      - ANONYMIZED_TELEMETRY=FALSE
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/api/v1/heartbeat"]
      interval: 10s
      timeout: 5s
      retries: 3

  rag-gateway:
    build: .
    container_name: ambient-rag-gateway
    ports:
      - "3000:3000"
    environment:
      - GEMINI_API_KEY=\${GEMINI_API_KEY}
      - CHROMA_HOST=http://chromadb:8000
      - NODE_ENV=production
    depends_on:
      chromadb:
        condition: service_healthy

volumes:
  chroma_data:
    driver: local`
  };

  return (
    <div className="space-y-10">
      {/* Hero Section */}
      <section className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-6 sm:p-8 lg:p-10 shadow-sm">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
          <div className="lg:col-span-7 space-y-4">
            <div className="flex items-center gap-2 text-xs font-medium text-slate-500 dark:text-slate-400">
              <span>Autonomous Architecture</span>
              <span aria-hidden="true">·</span>
              <span>Decoupled Topology</span>
              <span aria-hidden="true">·</span>
              <span>ChromaDB & Gemini Reasoning</span>
            </div>

            <h1 className="text-2xl sm:text-3xl lg:text-4xl font-extrabold text-slate-900 dark:text-slate-100 tracking-tight leading-tight">
              Ambient Loosely-Connected RAG Architecture
            </h1>

            <p className="text-slate-600 dark:text-slate-300 text-sm sm:text-base leading-relaxed">
              Yes, an ambient chatbot can be completely decoupled from embedded vector sources like ChromaDB and cognitive reasoning models. By using an asynchronous event mesh, standardized vector store adapters, and a Self-RAG reflection engine, the interface autonomously resolves inquiries with verifiable precision and zero hallucination.
            </p>

            <div className="pt-2 flex flex-wrap items-center gap-3">
              <button
                onClick={runSimulation}
                disabled={isSimulating}
                className="px-4 py-2 text-xs font-semibold rounded-lg bg-blue-600 hover:bg-blue-700 text-white shadow-sm transition-colors flex items-center gap-2 disabled:opacity-50"
              >
                <Activity className="w-3.5 h-3.5" />
                <span>{isSimulating ? 'Simulating Pipeline...' : 'Simulate Live Packet Flow'}</span>
              </button>

              {onNavigateToConnectors && (
                <button
                  onClick={onNavigateToConnectors}
                  className="px-4 py-2 text-xs font-semibold rounded-lg border border-slate-300 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800 text-slate-900 dark:text-slate-100 transition-colors flex items-center gap-1.5"
                >
                  <span>Where & How to Connect</span>
                  <ArrowRight className="w-3.5 h-3.5" />
                </button>
              )}

              <button
                onClick={() => onTestInquiry('How do we ensure the chatbot is loosely coupled from ChromaDB?')}
                className="px-4 py-2 text-xs font-semibold rounded-lg bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-900 dark:text-slate-100 transition-colors flex items-center gap-2"
              >
                <span>Test Live Inquiry</span>
                <ArrowRight className="w-3.5 h-3.5" />
              </button>
            </div>
          </div>

          <div className="lg:col-span-5">
            <div className="relative rounded-xl overflow-hidden border border-slate-200 dark:border-slate-800 bg-slate-950 aspect-video shadow-md">
              <img
                src="/src/assets/images/architecture_hero_diagram_1793306562713.jpg"
                alt="Ambient Loosely-Connected RAG Architecture Schematic"
                referrerPolicy="no-referrer"
                className="w-full h-full object-cover"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-slate-950/80 via-transparent to-transparent flex items-end p-4">
                <span className="text-xs font-medium text-slate-300">
                  Decoupled Triad: Ambient Interface ⟷ Event Mesh ⟷ ChromaDB + Gemini
                </span>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Interactive Simulation Strip */}
      <section className="bg-slate-900 text-white rounded-2xl p-6 border border-slate-800">
        <div className="flex items-center justify-between gap-4 mb-4">
          <div>
            <h2 className="text-base font-semibold text-white">
              Autonomous Inquiry Lifecycle & Packet Flow
            </h2>
            <p className="text-xs text-slate-400">
              Watch how an inquiry traverses the loosely-coupled layers without blocking client execution.
            </p>
          </div>
          <button
            onClick={runSimulation}
            disabled={isSimulating}
            className="text-xs font-medium text-blue-400 hover:text-blue-300 transition-colors underline"
          >
            Replay Trace
          </button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-5 gap-3">
          {[
            { step: 1, title: '1. Ambient Ingress', desc: 'Non-blocking prompt emitted over SSE' },
            { step: 2, title: '2. Query Expansion', desc: 'HyDE and sub-query decomposition' },
            { step: 3, title: '3. ChromaDB ANN', desc: 'HNSW cosine vector search (top-k)' },
            { step: 4, title: '4. Self-RAG CoT', desc: 'Reasoning model verifies sufficiency' },
            { step: 5, title: '5. Grounded Delivery', desc: 'Bracketed citations & precision score' }
          ].map((item) => {
            const isActive = simulationStep === item.step;
            const isCompleted = simulationStep > item.step;
            return (
              <div
                key={item.step}
                className={`p-3 rounded-xl border transition-all ${
                  isActive
                    ? 'border-blue-400 bg-blue-950/60 shadow-md ring-1 ring-blue-500'
                    : isCompleted
                    ? 'border-emerald-600/40 bg-emerald-950/20 text-slate-300'
                    : 'border-slate-800 bg-slate-950/40 text-slate-400'
                }`}
              >
                <div className="flex items-center justify-between text-xs font-semibold mb-1">
                  <span>{item.title}</span>
                  {isCompleted ? (
                    <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400" />
                  ) : isActive ? (
                    <span className="w-2 h-2 rounded-full bg-blue-400" />
                  ) : null}
                </div>
                <p className="text-[11px] leading-snug">{item.desc}</p>
              </div>
            );
          })}
        </div>
      </section>

      {/* Layer Deep Dive & Decoupling Analysis */}
      <section className="space-y-6">
        <div>
          <h2 className="text-xl font-bold text-slate-900 dark:text-slate-100">
            The 5 Decoupled Layers for Autonomous Precision
          </h2>
          <p className="text-sm text-slate-500 dark:text-slate-400">
            How architectural separation between interface, vector storage, and reasoning engine preserves scalability.
          </p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
          {/* Layer Selector */}
          <div className="lg:col-span-4 space-y-2">
            {LAYERS.map(layer => (
              <button
                key={layer.id}
                onClick={() => setActiveLayer(layer.id)}
                className={`w-full text-left p-3.5 rounded-xl border transition-all ${
                  activeLayer === layer.id
                    ? 'bg-white dark:bg-slate-800 border-blue-500 shadow-sm text-slate-900 dark:text-slate-100'
                    : 'bg-white/60 dark:bg-slate-900/60 border-slate-200 dark:border-slate-800 hover:border-slate-300 dark:hover:border-slate-700 text-slate-600 dark:text-slate-400'
                }`}
              >
                <div className="text-xs font-bold">{layer.name}</div>
                <div className="text-[11px] text-slate-500 dark:text-slate-400 truncate">{layer.subtitle}</div>
              </button>
            ))}
          </div>

          {/* Active Layer Details */}
          <div className="lg:col-span-8 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-6 sm:p-7 space-y-5 shadow-sm">
            <div className="flex items-start justify-between gap-4">
              <div>
                <h3 className="text-lg font-bold text-slate-900 dark:text-slate-100">
                  {currentLayer.name}
                </h3>
                <span className="text-xs text-blue-600 dark:text-blue-400 font-medium">
                  {currentLayer.subtitle}
                </span>
              </div>
              <span className="text-xs font-mono tabular-nums px-2.5 py-1 rounded bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300">
                {currentLayer.protocol}
              </span>
            </div>

            <div className="space-y-4 text-sm">
              <div>
                <h4 className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-1">
                  System Role & Execution
                </h4>
                <p className="text-slate-700 dark:text-slate-300 leading-relaxed">
                  {currentLayer.role}
                </p>
              </div>

              <div>
                <h4 className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-1">
                  How Loose Coupling is Guaranteed
                </h4>
                <p className="text-slate-700 dark:text-slate-300 leading-relaxed">
                  {currentLayer.decouplingMechanism}
                </p>
              </div>

              <div>
                <h4 className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-1">
                  High Precision & Zero-Hallucination Impact
                </h4>
                <p className="text-slate-700 dark:text-slate-300 leading-relaxed">
                  {currentLayer.precisionImpact}
                </p>
              </div>

              <div>
                <h4 className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-1.5">
                  Component Technologies
                </h4>
                <div className="flex flex-wrap gap-2">
                  {currentLayer.techStack.map(tech => (
                    <span
                      key={tech}
                      className="text-xs font-mono bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-slate-800 dark:text-slate-200 px-2.5 py-1 rounded-md"
                    >
                      {tech}
                    </span>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Production Implementation Code Blueprint */}
      <section className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-6 sm:p-8 space-y-5 shadow-sm">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h2 className="text-xl font-bold text-slate-900 dark:text-slate-100 flex items-center gap-2">
              <Code2 className="w-5 h-5 text-blue-500" />
              <span>Production Code Blueprints & Contract Implementations</span>
            </h2>
            <p className="text-xs text-slate-500 dark:text-slate-400">
              Clean drop-in implementations showing real ChromaDB, client hooks, and Gemini reasoning configurations.
            </p>
          </div>

          <button
            onClick={() => handleCopyCode(codeSnippets[activeCodeTab])}
            className="px-3 py-1.5 text-xs font-medium rounded-lg border border-slate-200 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800 text-slate-700 dark:text-slate-200 transition-colors flex items-center gap-1.5 self-start sm:self-auto"
          >
            {copied ? <Check className="w-3.5 h-3.5 text-emerald-500" /> : <Copy className="w-3.5 h-3.5" />}
            <span>{copied ? 'Copied' : 'Copy Code'}</span>
          </button>
        </div>

        {/* Code Tabs */}
        <div className="flex flex-wrap gap-1 p-1 bg-slate-100 dark:bg-slate-800 rounded-lg">
          <button
            onClick={() => setActiveCodeTab('fastapi_chroma')}
            className={`px-3 py-1.5 text-xs font-medium rounded-md transition-colors ${
              activeCodeTab === 'fastapi_chroma'
                ? 'bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 shadow-sm'
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200'
            }`}
          >
            Python FastAPI + ChromaDB
          </button>
          <button
            onClick={() => setActiveCodeTab('client_hook')}
            className={`px-3 py-1.5 text-xs font-medium rounded-md transition-colors ${
              activeCodeTab === 'client_hook'
                ? 'bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 shadow-sm'
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200'
            }`}
          >
            Ambient Client Hook (TS)
          </button>
          <button
            onClick={() => setActiveCodeTab('gemini_reasoning')}
            className={`px-3 py-1.5 text-xs font-medium rounded-md transition-colors ${
              activeCodeTab === 'gemini_reasoning'
                ? 'bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 shadow-sm'
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200'
            }`}
          >
            Gemini 3.8 Flash Reasoning Core
          </button>
          <button
            onClick={() => setActiveCodeTab('docker')}
            className={`px-3 py-1.5 text-xs font-medium rounded-md transition-colors ${
              activeCodeTab === 'docker'
                ? 'bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 shadow-sm'
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200'
            }`}
          >
            Docker Compose Mesh
          </button>
        </div>

        {/* Code Content */}
        <div className="relative rounded-xl overflow-hidden border border-slate-800 bg-slate-950">
          <pre className="p-4 text-xs font-mono text-slate-200 overflow-x-auto leading-relaxed max-h-[460px]">
            {codeSnippets[activeCodeTab]}
          </pre>
        </div>
      </section>
    </div>
  );
};
