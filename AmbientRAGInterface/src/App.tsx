import React, { useState, useEffect } from 'react';
import { Header } from './components/Header';
import { ArchitectureView } from './components/ArchitectureView';
import { ConnectorsGuide } from './components/ConnectorsGuide';
import { InteractiveWorkbench } from './components/InteractiveWorkbench';
import { VectorStoreManager } from './components/VectorStoreManager';
import { ArchitectureWhitepaper } from './components/ArchitectureWhitepaper';
import { AmbientWidget } from './components/AmbientWidget';
import { DEFAULT_CORPUS } from './data/defaultCorpus';
import { DocumentChunk } from './types/rag';

export default function App() {
  const [activeTab, setActiveTab] = useState<'architecture' | 'connectors' | 'workbench' | 'vectorStore' | 'whitepaper'>('architecture');
  const [isDark, setIsDark] = useState<boolean>(true);
  const [documents, setDocuments] = useState<DocumentChunk[]>(DEFAULT_CORPUS);
  const [isAmbientOpen, setIsAmbientOpen] = useState<boolean>(false);
  const [currentTestQuery, setCurrentTestQuery] = useState<string>('');

  useEffect(() => {
    // Sync dark class on root html element
    if (isDark) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, [isDark]);

  const toggleDark = () => {
    setIsDark(prev => !prev);
  };

  const handleTestInquiryFromArchitecture = (queryText: string) => {
    setCurrentTestQuery(queryText);
    setActiveTab('workbench');
  };

  const handleQueryFromVectorStore = (chunkTitle: string) => {
    setCurrentTestQuery(`Explain the key technical principles of: ${chunkTitle}`);
    setActiveTab('workbench');
  };

  return (
    <div className="min-h-screen bg-slate-50 dark:bg-slate-950 text-slate-900 dark:text-slate-100 flex flex-col transition-colors selection:bg-blue-500/20 selection:text-blue-600 dark:selection:text-blue-300">
      {/* Top Bar (Strict 3-zone contract) */}
      <Header
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        isDark={isDark}
        toggleDark={toggleDark}
        openAmbientWidget={() => setIsAmbientOpen(prev => !prev)}
        isAmbientOpen={isAmbientOpen}
      />

      {/* Main Content Area */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-8 sm:py-10">
        {activeTab === 'architecture' && (
          <ArchitectureView
            onTestInquiry={handleTestInquiryFromArchitecture}
            onNavigateToConnectors={() => setActiveTab('connectors')}
          />
        )}

        {activeTab === 'connectors' && (
          <ConnectorsGuide onNavigateToWorkbench={() => setActiveTab('workbench')} />
        )}

        {activeTab === 'workbench' && (
          <InteractiveWorkbench
            documents={documents}
            initialQuery={currentTestQuery}
          />
        )}

        {activeTab === 'vectorStore' && (
          <VectorStoreManager
            documents={documents}
            setDocuments={setDocuments}
            onQueryClick={handleQueryFromVectorStore}
          />
        )}

        {activeTab === 'whitepaper' && (
          <ArchitectureWhitepaper />
        )}
      </main>

      {/* Ambient Floating Assistant Widget */}
      <AmbientWidget
        isOpen={isAmbientOpen}
        onClose={() => setIsAmbientOpen(false)}
        documents={documents}
      />

      {/* Footer (Clean, unboxed prose, no fake scorecards or telemetry tickers) */}
      <footer className="border-t border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-950 py-8 text-xs text-slate-500 dark:text-slate-400">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <span className="font-semibold text-slate-700 dark:text-slate-300">AmbientRAG Architecture Specification</span>
            <span aria-hidden="true">·</span>
            <span>ChromaDB Embedded Vector Store</span>
            <span aria-hidden="true">·</span>
            <span>Gemini 3.8 Flash Reasoning</span>
          </div>

          <div className="flex items-center gap-4">
            <button
              onClick={() => setActiveTab('architecture')}
              className="hover:text-slate-900 dark:hover:text-slate-200 transition-colors"
            >
              Blueprint
            </button>
            <button
              onClick={() => setActiveTab('connectors')}
              className="hover:text-slate-900 dark:hover:text-slate-200 transition-colors"
            >
              Integration Guide
            </button>
            <button
              onClick={() => setActiveTab('workbench')}
              className="hover:text-slate-900 dark:hover:text-slate-200 transition-colors"
            >
              Workbench
            </button>
            <button
              onClick={() => setActiveTab('vectorStore')}
              className="hover:text-slate-900 dark:hover:text-slate-200 transition-colors"
            >
              ChromaDB Store
            </button>
            <button
              onClick={() => setActiveTab('whitepaper')}
              className="hover:text-slate-900 dark:hover:text-slate-200 transition-colors"
            >
              Whitepaper
            </button>
          </div>
        </div>
      </footer>
    </div>
  );
}
