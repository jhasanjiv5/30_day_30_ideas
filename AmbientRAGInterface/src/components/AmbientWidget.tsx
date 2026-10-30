import React, { useState } from 'react';
import { 
  Cpu, 
  X, 
  Minimize2, 
  Maximize2, 
  Send, 
  Sparkles, 
  ShieldCheck, 
  BrainCircuit, 
  ChevronRight,
  Database
} from 'lucide-react';
import { DocumentChunk, QueryResult } from '../types/rag';

interface AmbientWidgetProps {
  isOpen: boolean;
  onClose: () => void;
  documents: DocumentChunk[];
}

export const AmbientWidget: React.FC<AmbientWidgetProps> = ({
  isOpen,
  onClose,
  documents
}) => {
  const [query, setQuery] = useState<string>('');
  const [isProcessing, setIsProcessing] = useState<boolean>(false);
  const [result, setResult] = useState<QueryResult | null>(null);
  const [isExpanded, setIsExpanded] = useState<boolean>(false);
  const [showThinking, setShowThinking] = useState<boolean>(true);

  if (!isOpen) return null;

  const handleSend = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    if (!query.trim() || isProcessing) return;

    setIsProcessing(true);
    try {
      const resp = await fetch('/api/rag/query', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          query,
          documents,
          vectorStoreType: 'chromadb_embedded',
          similarityThreshold: 0.40,
          topK: 2,
          ambientContext: {
            origin: 'ambient_floating_omnibar',
            peripheralMode: true
          }
        })
      });

      const data: QueryResult = await resp.json();
      setResult(data);
    } catch (err) {
      console.error('Ambient widget error:', err);
    } finally {
      setIsProcessing(false);
    }
  };

  return (
    <div
      className={`fixed z-50 transition-all duration-300 ease-out ${
        isExpanded
          ? 'bottom-6 right-6 left-6 sm:left-auto sm:w-[580px] top-20'
          : 'bottom-6 right-6 w-full max-w-sm sm:max-w-md max-h-[85vh]'
      }`}
    >
      <div className="bg-white/95 dark:bg-slate-900/95 backdrop-blur-md border border-slate-300 dark:border-slate-700 rounded-2xl shadow-2xl flex flex-col h-full overflow-hidden">
        {/* Header Bar */}
        <div className="px-4 py-3 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between gap-3 bg-slate-50/80 dark:bg-slate-950/80">
          <div className="flex items-center gap-2">
            <div className="w-6 h-6 rounded-md bg-blue-600 text-white flex items-center justify-center">
              <Cpu className="w-3.5 h-3.5" />
            </div>
            <div>
              <div className="text-xs font-bold text-slate-900 dark:text-slate-100 flex items-center gap-1.5">
                <span>Ambient Interface</span>
                <span className="font-mono text-[9px] px-1.5 py-0.2 bg-blue-100 dark:bg-blue-900 text-blue-700 dark:text-blue-300 rounded font-normal">
                  Loosely-Coupled
                </span>
              </div>
            </div>
          </div>

          <div className="flex items-center gap-1 text-slate-400">
            <button
              onClick={() => setIsExpanded(!isExpanded)}
              aria-label="Toggle size"
              className="p-1 hover:text-slate-600 dark:hover:text-slate-200"
            >
              {isExpanded ? <Minimize2 className="w-3.5 h-3.5" /> : <Maximize2 className="w-3.5 h-3.5" />}
            </button>
            <button
              onClick={onClose}
              aria-label="Close ambient interface"
              className="p-1 hover:text-slate-600 dark:hover:text-slate-200"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* Content Body */}
        <div className="flex-1 overflow-y-auto p-4 space-y-3.5 text-xs">
          {!result && !isProcessing && (
            <div className="p-4 rounded-xl bg-slate-50 dark:bg-slate-800/40 border border-slate-200 dark:border-slate-800 space-y-2 text-slate-600 dark:text-slate-300">
              <p className="font-medium text-slate-900 dark:text-slate-100 text-xs">
                Independent Ambient Observer Active
              </p>
              <p className="text-[11px] leading-relaxed">
                This lightweight interface does not run ChromaDB or model weights. Inquiries are dispatched over asynchronous event envelopes.
              </p>
              <div className="pt-1">
                <span className="text-[10px] text-slate-400 block mb-1">Quick prompts:</span>
                <div className="flex flex-col gap-1">
                  {[
                    'How does loose coupling prevent client lock-in?',
                    'Why does Self-RAG eliminate hallucinations?'
                  ].map((p, idx) => (
                    <button
                      key={idx}
                      onClick={() => {
                        setQuery(p);
                      }}
                      className="text-left text-[11px] text-blue-600 dark:text-blue-400 hover:underline"
                    >
                      • {p}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* Result Display */}
          {result && (
            <div className="space-y-3">
              <div className="p-3.5 rounded-xl bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 space-y-2">
                <div className="flex items-center justify-between text-[11px]">
                  <span className="font-bold text-slate-900 dark:text-slate-100 flex items-center gap-1.5">
                    <ShieldCheck className="w-3.5 h-3.5 text-emerald-500" />
                    <span>Grounded Resolution</span>
                  </span>
                  <span className="font-mono text-emerald-600 dark:text-emerald-400 font-semibold">
                    {result.factualPrecisionScore}% precision
                  </span>
                </div>

                <div className="text-slate-700 dark:text-slate-300 leading-relaxed text-[11px] whitespace-pre-line">
                  {result.answer}
                </div>
              </div>

              {/* Collapsible Thinking Trace */}
              {result.reasoningSteps.length > 0 && (
                <div className="border border-slate-200 dark:border-slate-800 rounded-xl overflow-hidden">
                  <button
                    onClick={() => setShowThinking(!showThinking)}
                    className="w-full px-3 py-2 bg-slate-50 dark:bg-slate-800/60 flex items-center justify-between text-[11px] font-semibold text-slate-700 dark:text-slate-300"
                  >
                    <span className="flex items-center gap-1.5">
                      <BrainCircuit className="w-3.5 h-3.5 text-purple-500" />
                      <span>Reasoning Trace ({result.reasoningSteps.length} steps)</span>
                    </span>
                    <span>{showThinking ? '▲' : '▼'}</span>
                  </button>

                  {showThinking && (
                    <div className="p-3 bg-white dark:bg-slate-900 space-y-1.5 font-mono text-[10px] text-slate-600 dark:text-slate-400">
                      {result.reasoningSteps.map((step, idx) => (
                        <div key={idx} className="flex items-start gap-1.5">
                          <span className="text-purple-500 shrink-0">#{idx + 1}</span>
                          <span>{step}</span>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>
          )}

          {isProcessing && (
            <div className="p-4 rounded-xl bg-slate-50 dark:bg-slate-800/40 border border-slate-200 dark:border-slate-800 text-center space-y-2">
              <div className="inline-block animate-spin text-blue-600 dark:text-blue-400 font-mono text-xs">
                ⟳
              </div>
              <p className="text-[11px] text-slate-600 dark:text-slate-300 font-medium">
                Dispatching event envelope to ChromaDB & Gemini 3.8 Flash...
              </p>
            </div>
          )}
        </div>

        {/* Input Bar */}
        <form onSubmit={handleSend} className="p-3 border-t border-slate-200 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-950/50">
          <div className="relative">
            <input
              type="text"
              value={query}
              onChange={e => setQuery(e.target.value)}
              placeholder="Ask an ambient question..."
              className="w-full bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl px-3 py-2 text-xs text-slate-900 dark:text-slate-100 placeholder-slate-400 focus:outline-none focus:ring-1 focus:ring-blue-500 pr-10"
            />
            <button
              type="submit"
              disabled={isProcessing || !query.trim()}
              aria-label="Send"
              className="absolute right-1.5 top-1.5 bottom-1.5 px-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg flex items-center justify-center disabled:opacity-40 transition-colors"
            >
              <Send className="w-3 h-3" />
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
