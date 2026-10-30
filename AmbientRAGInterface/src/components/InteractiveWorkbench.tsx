import React, { useState } from 'react';
import { 
  Search, 
  Send, 
  Sparkles, 
  Database, 
  BrainCircuit, 
  ShieldCheck, 
  Clock, 
  ChevronDown, 
  ChevronUp, 
  Layers, 
  FileText,
  Sliders,
  CheckCircle2,
  AlertTriangle
} from 'lucide-react';
import { DocumentChunk, QueryResult } from '../types/rag';
import { PRESET_QUERIES } from '../data/defaultCorpus';

interface InteractiveWorkbenchProps {
  documents: DocumentChunk[];
  initialQuery?: string;
}

export const InteractiveWorkbench: React.FC<InteractiveWorkbenchProps> = ({ 
  documents,
  initialQuery = ''
}) => {
  const [query, setQuery] = useState<string>(initialQuery || PRESET_QUERIES[0]);
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [result, setResult] = useState<QueryResult | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Vector store config parameters
  const [similarityThreshold, setSimilarityThreshold] = useState<number>(0.45);
  const [topK, setTopK] = useState<number>(3);
  const [vectorStoreType, setVectorStoreType] = useState<string>('chromadb_embedded');
  const [expandedChunkId, setExpandedChunkId] = useState<string | null>(null);
  const [showConfig, setShowConfig] = useState<boolean>(false);

  const executeInquiry = async (queryText: string) => {
    if (!queryText.trim() || isLoading) return;
    setIsLoading(true);
    setError(null);

    try {
      const response = await fetch('/api/rag/query', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          query: queryText,
          documents,
          vectorStoreType,
          similarityThreshold,
          topK,
          ambientContext: {
            activeView: 'workbench',
            userIntent: 'inquiry_resolution',
            sessionMode: 'autonomous_ambient'
          }
        })
      });

      if (!response.ok) {
        throw new Error(`Inquiry failed with status ${response.status}`);
      }

      const data: QueryResult = await response.json();
      setResult(data);
    } catch (err: any) {
      console.error('Inquiry error:', err);
      setError(err?.message || 'Failed to complete autonomous inquiry');
    } finally {
      setIsLoading(false);
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    executeInquiry(query);
  };

  return (
    <div className="space-y-8">
      {/* Workbench Header & Query Bar */}
      <section className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-6 sm:p-8 shadow-sm space-y-6">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <div className="flex items-center gap-2 text-xs font-medium text-slate-500 dark:text-slate-400 mb-1">
              <span>RAG Execution Pipeline</span>
              <span aria-hidden="true">·</span>
              <span>Vector Ingestion: ChromaDB</span>
              <span aria-hidden="true">·</span>
              <span>Reasoning: Gemini 3.8 Flash</span>
            </div>
            <h1 className="text-xl sm:text-2xl font-bold text-slate-900 dark:text-slate-100">
              Interactive Autonomous Inquiry Sandbox
            </h1>
          </div>

          <button
            onClick={() => setShowConfig(!showConfig)}
            className="px-3.5 py-1.5 text-xs font-medium rounded-lg border border-slate-200 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-800 text-slate-700 dark:text-slate-300 transition-colors flex items-center gap-2 self-start sm:self-auto"
          >
            <Sliders className="w-3.5 h-3.5" />
            <span>Parameters {showConfig ? '▲' : '▼'}</span>
          </button>
        </div>

        {/* Collapsible Config Parameters */}
        {showConfig && (
          <div className="p-4 bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700 rounded-xl grid grid-cols-1 sm:grid-cols-3 gap-5 text-xs">
            <div>
              <label className="font-medium text-slate-700 dark:text-slate-300 block mb-1">
                Vector Store Adapter
              </label>
              <select
                value={vectorStoreType}
                onChange={e => setVectorStoreType(e.target.value)}
                className="w-full bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-lg px-2.5 py-1.5 text-xs text-slate-900 dark:text-slate-100"
              >
                <option value="chromadb_embedded">ChromaDB (Embedded SQLite / In-Memory)</option>
                <option value="chromadb_remote">ChromaDB (Remote Cluster / Port 8000)</option>
                <option value="milvus_adapter">Milvus / Qdrant Adapter (Abstract)</option>
              </select>
            </div>

            <div>
              <label className="font-medium text-slate-700 dark:text-slate-300 block mb-1">
                Cosine Similarity Cutoff: <span className="font-mono tabular-nums">{similarityThreshold.toFixed(2)}</span>
              </label>
              <input
                type="range"
                min="0.2"
                max="0.8"
                step="0.05"
                value={similarityThreshold}
                onChange={e => setSimilarityThreshold(parseFloat(e.target.value))}
                className="w-full accent-blue-600"
              />
            </div>

            <div>
              <label className="font-medium text-slate-700 dark:text-slate-300 block mb-1">
                Top-K Vector Candidates: <span className="font-mono tabular-nums">{topK}</span>
              </label>
              <input
                type="range"
                min="1"
                max="6"
                step="1"
                value={topK}
                onChange={e => setTopK(parseInt(e.target.value, 10))}
                className="w-full accent-blue-600"
              />
            </div>
          </div>
        )}

        {/* Query Input Box */}
        <form onSubmit={handleSubmit} className="space-y-3">
          <div className="relative">
            <input
              type="text"
              value={query}
              onChange={e => setQuery(e.target.value)}
              placeholder="Ask an architectural inquiry (e.g. How is loose coupling maintained with ChromaDB?)..."
              className="w-full bg-slate-50 dark:bg-slate-950 border border-slate-300 dark:border-slate-700 rounded-xl px-4 py-3.5 text-sm text-slate-900 dark:text-slate-100 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500 pr-24 shadow-inner"
            />
            <button
              type="submit"
              disabled={isLoading || !query.trim()}
              className="absolute right-2 top-2 bottom-2 px-4 bg-blue-600 hover:bg-blue-700 text-white text-xs font-semibold rounded-lg transition-colors flex items-center gap-1.5 disabled:opacity-50 shadow-sm"
            >
              {isLoading ? (
                <span>Thinking...</span>
              ) : (
                <>
                  <span>Resolve</span>
                  <Send className="w-3.5 h-3.5" />
                </>
              )}
            </button>
          </div>

          {/* Quick Preset Queries */}
          <div className="flex items-center gap-2 overflow-x-auto pb-1 text-xs text-slate-500 dark:text-slate-400">
            <span className="shrink-0 font-medium">Try asking:</span>
            {PRESET_QUERIES.map((preset, idx) => (
              <button
                key={idx}
                type="button"
                onClick={() => {
                  setQuery(preset);
                  executeInquiry(preset);
                }}
                className="hover:text-blue-600 dark:hover:text-blue-400 transition-colors whitespace-nowrap shrink-0 underline decoration-slate-300 dark:decoration-slate-700"
              >
                {preset}
              </button>
            ))}
          </div>
        </form>
      </section>

      {/* Error state */}
      {error && (
        <div className="p-4 rounded-xl border border-red-200 dark:border-red-900 bg-red-50 dark:bg-red-950/40 text-red-700 dark:text-red-300 text-xs flex items-center gap-2">
          <AlertTriangle className="w-4 h-4 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* Results View */}
      {result && (
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
          {/* Main Resolution Column */}
          <div className="lg:col-span-7 space-y-6">
            {/* Answer Card */}
            <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-6 sm:p-7 shadow-sm space-y-4">
              <div className="flex items-center justify-between gap-4 border-b border-slate-100 dark:border-slate-800 pb-3">
                <div className="flex items-center gap-2">
                  <ShieldCheck className="w-4 h-4 text-emerald-600 dark:text-emerald-400" />
                  <h2 className="text-sm font-bold text-slate-900 dark:text-slate-100">
                    Autonomous Grounded Resolution
                  </h2>
                </div>
                <div className="flex items-center gap-3 text-xs text-slate-500 dark:text-slate-400">
                  <span>Precision: <strong className="font-mono tabular-nums text-emerald-600 dark:text-emerald-400">{result.factualPrecisionScore}%</strong></span>
                  <span aria-hidden="true">·</span>
                  <span>Latency: <strong className="font-mono tabular-nums">{result.totalLatencyMs}ms</strong></span>
                </div>
              </div>

              {/* Formatted Answer */}
              <div className="text-sm text-slate-800 dark:text-slate-200 leading-relaxed whitespace-pre-line space-y-2">
                {result.answer}
              </div>

              {/* Citations Footer */}
              {result.citations.length > 0 && (
                <div className="pt-3 border-t border-slate-100 dark:border-slate-800 flex flex-wrap items-center gap-2 text-xs text-slate-500 dark:text-slate-400">
                  <span className="font-semibold text-slate-700 dark:text-slate-300">Grounded Citations:</span>
                  {result.citations.map((cite, i) => (
                    <span
                      key={cite.id}
                      className="font-mono text-[11px] bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 px-2 py-0.5 rounded text-slate-700 dark:text-slate-300"
                    >
                      [Source {i + 1}: {cite.title} · sim {(cite.score * 100).toFixed(0)}%]
                    </span>
                  ))}
                </div>
              )}
            </div>

            {/* Step-by-Step Chain-of-Thought Thinking Trace */}
            <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-6 shadow-sm space-y-3">
              <div className="flex items-center gap-2 text-xs font-bold text-slate-900 dark:text-slate-100 uppercase tracking-wider">
                <BrainCircuit className="w-4 h-4 text-purple-600 dark:text-purple-400" />
                <span>Cognitive Reasoning Engine · Chain of Thought</span>
              </div>
              <p className="text-xs text-slate-500 dark:text-slate-400">
                Transparent verification trace showing intent decomposition, context evaluation, and hallucination rejection:
              </p>

              <div className="space-y-2 pt-1">
                {result.reasoningSteps.map((step, idx) => (
                  <div
                    key={idx}
                    className="p-3 rounded-xl bg-slate-50 dark:bg-slate-950/60 border border-slate-200 dark:border-slate-800/80 text-xs text-slate-700 dark:text-slate-300 leading-relaxed flex items-start gap-2.5"
                  >
                    <span className="font-mono text-[11px] text-purple-600 dark:text-purple-400 font-semibold shrink-0">
                      #{idx + 1}
                    </span>
                    <span>{step}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Right Column: ChromaDB Vector Matches & Event Mesh Trace */}
          <div className="lg:col-span-5 space-y-6">
            {/* Retrieved Chunks from ChromaDB */}
            <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-6 shadow-sm space-y-4">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Database className="w-4 h-4 text-blue-600 dark:text-blue-400" />
                  <h3 className="text-sm font-bold text-slate-900 dark:text-slate-100">
                    ChromaDB Vector Retrieval
                  </h3>
                </div>
                <span className="text-xs font-mono tabular-nums text-slate-500 dark:text-slate-400">
                  {result.retrievedChunks.length} matches
                </span>
              </div>

              {result.retrievedChunks.length === 0 ? (
                <div className="p-4 rounded-xl bg-amber-50 dark:bg-amber-950/30 border border-amber-200 dark:border-amber-900 text-xs text-amber-700 dark:text-amber-300">
                  No document met the cosine similarity cutoff ({similarityThreshold}). System prevented ungrounded hallucination.
                </div>
              ) : (
                <div className="space-y-3">
                  {result.retrievedChunks.map((chunk, idx) => {
                    const isExpanded = expandedChunkId === chunk.id;
                    return (
                      <div
                        key={chunk.id}
                        className="p-3.5 rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50/70 dark:bg-slate-950/40 space-y-2"
                      >
                        <div className="flex items-start justify-between gap-2">
                          <div>
                            <div className="text-xs font-bold text-slate-900 dark:text-slate-100">
                              [Source {idx + 1}] {chunk.title}
                            </div>
                            <div className="text-[11px] text-slate-500 dark:text-slate-400">
                              {chunk.category} · {chunk.source}
                            </div>
                          </div>
                          <span className="text-[11px] font-mono tabular-nums px-2 py-0.5 rounded bg-blue-100 dark:bg-blue-950/80 text-blue-700 dark:text-blue-300 font-semibold shrink-0">
                            cos: {(chunk.score * 100).toFixed(1)}%
                          </span>
                        </div>

                        <p className="text-xs text-slate-600 dark:text-slate-400 leading-relaxed">
                          {isExpanded ? chunk.fullText : chunk.snippet}
                        </p>

                        <button
                          type="button"
                          onClick={() => setExpandedChunkId(isExpanded ? null : chunk.id)}
                          className="text-[11px] text-blue-600 dark:text-blue-400 font-medium hover:underline flex items-center gap-1"
                        >
                          {isExpanded ? 'Collapse' : 'Expand full chunk context'}
                          {isExpanded ? <ChevronUp className="w-3 h-3" /> : <ChevronDown className="w-3 h-3" />}
                        </button>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>

            {/* Asynchronous Event Mesh Packet Log */}
            <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-6 shadow-sm space-y-3">
              <div className="flex items-center gap-2">
                <Clock className="w-4 h-4 text-cyan-600 dark:text-cyan-400" />
                <h3 className="text-sm font-bold text-slate-900 dark:text-slate-100">
                  Event Mesh Packet Log (Decoupled Trace)
                </h3>
              </div>

              <div className="space-y-2 pt-1 font-mono text-[11px]">
                {result.packetEvents.map((evt, idx) => (
                  <div
                    key={idx}
                    className="p-2.5 rounded-lg bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 flex items-start justify-between gap-3"
                  >
                    <div className="space-y-0.5">
                      <span className="font-semibold text-slate-800 dark:text-slate-200 block">
                        {evt.step}
                      </span>
                      <span className="text-slate-500 dark:text-slate-400 block text-[10px]">
                        {evt.details}
                      </span>
                    </div>
                    <span className="tabular-nums text-slate-500 dark:text-slate-400 shrink-0">
                      +{evt.latencyMs}ms
                    </span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
