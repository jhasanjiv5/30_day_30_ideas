import React from 'react';
import { Search, SlidersHorizontal, Sparkles, X } from 'lucide-react';
import type { FilterOptionsPayload, SearchFilters } from '../types/panji.ts';
import { MadhubaniBorderStrip, MadhubaniCorner } from './MadhubaniMotifs.tsx';

export interface ExampleSearchItem {
  label: string;
  query: string;
  filters?: SearchFilters;
  description: string;
}

export const REAL_EXAMPLE_SEARCHES: ExampleSearchItem[] = [
  {
    label: 'Bhagiratha from Darihara',
    query: 'I am looking for Bhagiratha from Darihara',
    description: '4-generation lineage (Kashyapa gotra)',
  },
  {
    label: 'Arjuna of Pali, Vatsa gotra',
    query: 'Arjuna of Pali, Vatsa gotra',
    description: 'Traces 3 generations to Lākhū',
  },
  {
    label: 'Shubhankara kaviraja',
    query: 'Shubhankara kaviraja',
    description: 'Title match in Garha Mandar',
  },
  {
    label: 'Khadgadhara',
    query: 'Khadgadhara',
    description: 'Documented sibling link',
  },
  {
    label: 'भगीरथ',
    query: 'भगीरथ',
    description: 'Devanagari name search',
  },
];

interface SearchPanelProps {
  query: string;
  onQueryChange: (val: string) => void;
  filters: SearchFilters;
  onFiltersChange: (next: SearchFilters) => void;
  filterOptions: FilterOptionsPayload | null;
  useAiAssist: boolean;
  onToggleAiAssist: (next: boolean) => void;
  aiAvailable: boolean;
  semanticSearchAvailable: boolean;
  semanticSearchError?: string;
  semanticSearchWarning?: string;
  isSearching: boolean;
  onSubmit: (overrideQuery?: string, overrideFilters?: SearchFilters) => void;
  onReset: () => void;
}

export function SearchPanel({
  query,
  onQueryChange,
  filters,
  onFiltersChange,
  filterOptions,
  useAiAssist,
  onToggleAiAssist,
  aiAvailable,
  semanticSearchAvailable,
  semanticSearchError,
  semanticSearchWarning,
  isSearching,
  onSubmit,
  onReset,
}: SearchPanelProps) {
  const [showFilters, setShowFilters] = React.useState(false);

  const hasActiveFilters = Boolean(filters.village || filters.mool || filters.gotra);
  const activeFilterCount = [filters.village, filters.mool, filters.gotra].filter(Boolean).length;

  const handleFormSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit();
  };

  return (
    <section
      aria-label="Ancestor Search"
      className="relative overflow-hidden rounded-3xl bg-white border border-[#E7DCD8] shadow-[0_14px_40px_rgba(23,21,20,0.06)]"
    >
      <MadhubaniBorderStrip />

      <div className="relative p-5 sm:p-8">
        <MadhubaniCorner position="bottom-left" />
        <MadhubaniCorner position="bottom-right" />

        <form onSubmit={handleFormSubmit} className="relative z-10 space-y-4">
          <label htmlFor="panji-search-input" className="sr-only">
            Search Mithila Panji ancestor records by name, village, mool, gotra, or natural language
          </label>

          <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-2.5">
            <div className="relative flex-1">
              <Search
                className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-[#6E6560]"
                aria-hidden="true"
              />
              <input
                id="panji-search-input"
                type="text"
                value={query}
                onChange={(e) => onQueryChange(e.target.value)}
                placeholder="Try “Bhagiratha from Darihara” or “Arjuna of Pali, Vatsa gotra”"
                className="w-full h-12 sm:h-13 pl-12 pr-10 rounded-2xl bg-[#FBF9F6] border border-[#E0D2CE] text-[#171514] placeholder:text-[#8A7F7A] text-[15px] sm:text-base transition-colors focus:bg-white focus:border-[#C42426] focus:outline-none"
                autoComplete="off"
              />
              {query && (
                <button
                  type="button"
                  onClick={() => {
                    onQueryChange('');
                    if (!hasActiveFilters) onReset();
                  }}
                  aria-label="Clear search query"
                  className="absolute right-3 top-1/2 -translate-y-1/2 p-1.5 rounded-full text-[#6E6560] hover:text-[#171514] hover:bg-[#F8E2E0] transition-colors"
                >
                  <X className="w-4 h-4" />
                </button>
              )}
            </div>

            <button
              type="submit"
              disabled={isSearching}
              className="h-12 sm:h-13 px-6 rounded-2xl bg-[#C42426] hover:bg-[#A31B1D] active:scale-[0.99] text-white font-medium text-[15px] transition-all whitespace-nowrap shrink-0 disabled:opacity-60"
            >
              {isSearching ? 'Searching…' : 'Search Records'}
            </button>
          </div>

          {/* Control strip: Filters toggle + AI Assist toggle */}
          <div className="flex flex-wrap items-center justify-between gap-3 pt-1">
            <div className="flex flex-wrap items-center gap-2">
              <button
                type="button"
                onClick={() => setShowFilters((v) => !v)}
                aria-expanded={showFilters}
                className={`inline-flex items-center gap-2 px-3.5 py-2 rounded-xl text-sm font-medium border transition-colors whitespace-nowrap shrink-0 ${
                  showFilters || hasActiveFilters
                    ? 'bg-[#FDF3F2] border-[#DFB7B5] text-[#171514]'
                    : 'bg-white border-[#E7DCD8] text-[#5E5753] hover:border-[#CBB8B2] hover:text-[#171514]'
                }`}
              >
                <SlidersHorizontal className="w-4 h-4" aria-hidden="true" />
                <span>Filters{activeFilterCount > 0 ? ` (${activeFilterCount})` : ''}</span>
              </button>

              {hasActiveFilters && (
                <button
                  type="button"
                  onClick={() => {
                    const empty: SearchFilters = {};
                    onFiltersChange(empty);
                    if (query.trim()) onSubmit(query, empty);
                    else onReset();
                  }}
                  className="px-3 py-2 rounded-xl text-xs font-medium text-[#C42426] hover:bg-[#FDF3F2] transition-colors whitespace-nowrap shrink-0"
                >
                  Clear filters
                </button>
              )}
            </div>

            <div className="flex items-center gap-2">
              <button
                type="button"
                role="switch"
                aria-checked={useAiAssist}
                onClick={() => onToggleAiAssist(!useAiAssist)}
                className={`inline-flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-medium border transition-colors whitespace-nowrap shrink-0 ${
                  useAiAssist
                    ? 'bg-[#FDF3F2] border-[#C42426]/35 text-[#8E181A]'
                    : 'bg-white border-[#E7DCD8] text-[#5E5753] hover:text-[#171514]'
                }`}
              >
                <Sparkles className="w-3.5 h-3.5" aria-hidden="true" />
                <span>
                  {useAiAssist
                    ? aiAvailable
                      ? 'AI Query Assist: On'
                      : 'AI Assist: Deterministic Fallback'
                    : 'AI Query Assist: Off'}
                </span>
              </button>
            </div>
          </div>

          <p
            role="status"
            className={`text-xs ${
              semanticSearchAvailable
                ? semanticSearchWarning
                  ? 'text-[#8A5A10]'
                  : 'text-[#2B6249]'
                : 'text-[#786E69]'
            }`}
          >
            {semanticSearchAvailable
              ? `Hybrid search is ready: exact matches are ranked with semantic profile similarity.${semanticSearchWarning ? ` ${semanticSearchWarning}` : ''}`
              : `Exact name and village search is active. ${semanticSearchError || 'Semantic search is not configured.'}`}
          </p>

          {/* Optional Filters Drawer */}
          {showFilters && (
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-3 border-t border-[#F2E9E6]">
              <div>
                <label
                  htmlFor="filter-village"
                  className="block text-xs font-medium text-[#5E5753] mb-1.5"
                >
                  Village (source-backed)
                </label>
                <select
                  id="filter-village"
                  value={filters.village ?? ''}
                  onChange={(e) => {
                    const next = { ...filters, village: e.target.value || undefined };
                    onFiltersChange(next);
                    onSubmit(query, next);
                  }}
                  className="w-full h-10 px-3 rounded-xl bg-[#FBF9F6] border border-[#E0D2CE] text-sm text-[#171514] focus:border-[#C42426] focus:outline-none"
                >
                  <option value="">
                    All recorded villages ({filterOptions?.villages.length ?? 0})
                  </option>
                  {(filterOptions?.villages ?? []).map((v) => (
                    <option key={v.value} value={v.value}>
                      {v.label}
                      {v.secondaryLabel ? ` (${v.secondaryLabel})` : ''} · {v.count}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label
                  htmlFor="filter-mool"
                  className="block text-xs font-medium text-[#5E5753] mb-1.5"
                >
                  Mool (inferred from village)
                </label>
                <select
                  id="filter-mool"
                  value={filters.mool ?? ''}
                  onChange={(e) => {
                    const next = { ...filters, mool: e.target.value || undefined };
                    onFiltersChange(next);
                    onSubmit(query, next);
                  }}
                  className="w-full h-10 px-3 rounded-xl bg-[#FBF9F6] border border-[#E0D2CE] text-sm text-[#171514] focus:border-[#C42426] focus:outline-none"
                >
                  <option value="">All mools ({filterOptions?.mools.length ?? 0})</option>
                  {(filterOptions?.mools ?? []).map((m) => (
                    <option key={m.value} value={m.value}>
                      {m.label}
                      {m.secondaryLabel ? ` (${m.secondaryLabel})` : ''} · {m.count}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label
                  htmlFor="filter-gotra"
                  className="block text-xs font-medium text-[#5E5753] mb-1.5"
                >
                  Gotra (inferred via mool)
                </label>
                <select
                  id="filter-gotra"
                  value={filters.gotra ?? ''}
                  onChange={(e) => {
                    const next = { ...filters, gotra: e.target.value || undefined };
                    onFiltersChange(next);
                    onSubmit(query, next);
                  }}
                  className="w-full h-10 px-3 rounded-xl bg-[#FBF9F6] border border-[#E0D2CE] text-sm text-[#171514] focus:border-[#C42426] focus:outline-none"
                >
                  <option value="">
                    All canonical gotras ({filterOptions?.gotras.length ?? 0})
                  </option>
                  {(filterOptions?.gotras ?? []).map((g) => (
                    <option key={g.value} value={g.value}>
                      {g.label}
                      {g.secondaryLabel ? ` (${g.secondaryLabel})` : ''} · {g.count}
                    </option>
                  ))}
                </select>
              </div>
            </div>
          )}

          {/* Real corpus example searches */}
          <div className="pt-2 flex flex-wrap items-center gap-2 text-xs text-[#5E5753]">
            <span className="font-medium text-[#2E2A27] mr-1">Example searches:</span>
            {REAL_EXAMPLE_SEARCHES.map((ex) => (
              <button
                key={ex.label}
                type="button"
                onClick={() => {
                  const nextFilters = ex.filters ?? {};
                  onQueryChange(ex.query);
                  onFiltersChange(nextFilters);
                  onSubmit(ex.query, nextFilters);
                }}
                title={ex.description}
                className="px-2.5 py-1.5 rounded-lg bg-[#FBF9F6] border border-[#E7DCD8] hover:border-[#C42426]/60 hover:bg-[#FDF3F2] text-[#171514] transition-colors whitespace-nowrap shrink-0"
              >
                {ex.label}
              </button>
            ))}
          </div>
        </form>
      </div>
    </section>
  );
}
