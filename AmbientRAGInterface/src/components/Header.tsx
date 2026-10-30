import React from 'react';
import { Sun, Moon, Cpu } from 'lucide-react';

interface HeaderProps {
  activeTab: 'architecture' | 'connectors' | 'workbench' | 'vectorStore' | 'whitepaper';
  setActiveTab: (tab: 'architecture' | 'connectors' | 'workbench' | 'vectorStore' | 'whitepaper') => void;
  isDark: boolean;
  toggleDark: () => void;
  openAmbientWidget: () => void;
  isAmbientOpen: boolean;
}

export const Header: React.FC<HeaderProps> = ({
  activeTab,
  setActiveTab,
  isDark,
  toggleDark,
  openAmbientWidget,
  isAmbientOpen
}) => {
  return (
    <header className="sticky top-0 z-40 w-full border-b border-slate-200 dark:border-slate-800 bg-white/90 dark:bg-slate-950/90 backdrop-blur-md">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between gap-8">
        {/* Zone 1: Brand Wordmark (Single text element) */}
        <div className="flex items-center gap-3 shrink-0">
          <div className="w-8 h-8 rounded-lg bg-slate-900 dark:bg-slate-100 flex items-center justify-center text-white dark:text-slate-900 shadow-sm">
            <Cpu className="w-4 h-4" />
          </div>
          <span className="text-base font-bold tracking-tight text-slate-900 dark:text-slate-100 whitespace-nowrap shrink-0">
            AmbientRAG Architect
          </span>
        </div>

        {/* Zone 2: Navigation Links (Clean single-line prose, hover states, no pills) */}
        <nav className="hidden md:flex items-center gap-6 text-sm font-medium text-slate-600 dark:text-slate-400">
          <button
            onClick={() => setActiveTab('architecture')}
            className={`transition-colors whitespace-nowrap shrink-0 pb-1 border-b-2 ${
              activeTab === 'architecture'
                ? 'border-blue-600 text-slate-900 dark:text-slate-100 font-semibold'
                : 'border-transparent hover:text-slate-900 dark:hover:text-slate-200'
            }`}
          >
            System Blueprint
          </button>
          <button
            onClick={() => setActiveTab('connectors')}
            className={`transition-colors whitespace-nowrap shrink-0 pb-1 border-b-2 ${
              activeTab === 'connectors'
                ? 'border-blue-600 text-slate-900 dark:text-slate-100 font-semibold'
                : 'border-transparent hover:text-slate-900 dark:hover:text-slate-200'
            }`}
          >
            Integration Guide
          </button>
          <button
            onClick={() => setActiveTab('workbench')}
            className={`transition-colors whitespace-nowrap shrink-0 pb-1 border-b-2 ${
              activeTab === 'workbench'
                ? 'border-blue-600 text-slate-900 dark:text-slate-100 font-semibold'
                : 'border-transparent hover:text-slate-900 dark:hover:text-slate-200'
            }`}
          >
            Interactive Workbench
          </button>
          <button
            onClick={() => setActiveTab('vectorStore')}
            className={`transition-colors whitespace-nowrap shrink-0 pb-1 border-b-2 ${
              activeTab === 'vectorStore'
                ? 'border-blue-600 text-slate-900 dark:text-slate-100 font-semibold'
                : 'border-transparent hover:text-slate-900 dark:hover:text-slate-200'
            }`}
          >
            ChromaDB Store
          </button>
          <button
            onClick={() => setActiveTab('whitepaper')}
            className={`transition-colors whitespace-nowrap shrink-0 pb-1 border-b-2 ${
              activeTab === 'whitepaper'
                ? 'border-blue-600 text-slate-900 dark:text-slate-100 font-semibold'
                : 'border-transparent hover:text-slate-900 dark:hover:text-slate-200'
            }`}
          >
            Whitepaper
          </button>
        </nav>

        {/* Zone 3: Primary Action & Controls */}
        <div className="flex items-center gap-3 shrink-0">
          <button
            onClick={toggleDark}
            aria-label="Toggle theme"
            className="p-2 text-slate-500 hover:text-slate-900 dark:text-slate-400 dark:hover:text-slate-100 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
          >
            {isDark ? <Sun className="w-4 h-4" /> : <Moon className="w-4 h-4" />}
          </button>

          <button
            onClick={openAmbientWidget}
            className={`px-3.5 py-1.5 text-xs font-semibold rounded-lg transition-all whitespace-nowrap shrink-0 flex items-center gap-2 shadow-sm ${
              isAmbientOpen
                ? 'bg-blue-600 text-white hover:bg-blue-700'
                : 'bg-slate-900 dark:bg-slate-100 text-white dark:text-slate-900 hover:bg-slate-800 dark:hover:bg-slate-200'
            }`}
          >
            <span>{isAmbientOpen ? 'Ambient Mode Active' : 'Launch Ambient Omnibar'}</span>
          </button>
        </div>
      </div>
    </header>
  );
};
