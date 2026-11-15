import React from 'react';
import {
  AlertCircle,
  ExternalLink,
  GitBranch,
  GitCompareArrows,
  GitFork,
  RefreshCw,
  Search,
  Sparkles,
} from 'lucide-react';
import type {
  FilterOptionsPayload,
  HealthPayload,
  LineageGraph,
  SearchAnswerPayload,
  SearchFilters,
  SearchResponse,
} from './types/panji.ts';
import { CandidateCard } from './components/CandidateCard.tsx';
import { LineageExplorer } from './components/LineageExplorer.tsx';
import { MithilaSuryaLogo } from './components/MadhubaniMotifs.tsx';
import { MoolGotraBrowser } from './components/MoolGotraBrowser.tsx';
import { RelationshipFinder } from './components/RelationshipFinder.tsx';
import { SearchPanel } from './components/SearchPanel.tsx';
import { TreeCoveragePanel } from './components/TreeCoveragePanel.tsx';
import { UsageGuide } from './components/UsageGuide.tsx';

type WorkspaceMode = 'search' | 'relationship' | 'mools' | 'coverage';

const WORKSPACE_MODES: Array<{
  id: WorkspaceMode;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
}> = [
  { id: 'search', label: 'Ancestor Search', icon: Search },
  { id: 'relationship', label: 'Relationship Finder', icon: GitCompareArrows },
  { id: 'mools', label: 'Mools & Gotras', icon: GitFork },
  { id: 'coverage', label: 'Tree Coverage', icon: GitBranch },
];

export default function App() {
  const [mode, setMode] = React.useState<WorkspaceMode>('search');
  const [autoLoadRelationshipSample, setAutoLoadRelationshipSample] = React.useState(false);
  const [query, setQuery] = React.useState('');
  const [filters, setFilters] = React.useState<SearchFilters>({});
  const [useAiAssist, setUseAiAssist] = React.useState(true);
  const [health, setHealth] = React.useState<HealthPayload | null>(null);
  const [serviceUnavailable, setServiceUnavailable] = React.useState(false);

  const [filterOptions, setFilterOptions] = React.useState<FilterOptionsPayload | null>(null);
  const [searchResult, setSearchResult] = React.useState<SearchResponse | null>(null);
  const [isSearching, setIsSearching] = React.useState(false);
  const [isRefiningAiAnswer, setIsRefiningAiAnswer] = React.useState(false);
  const [searchError, setSearchError] = React.useState<string | null>(null);

  const [activeLineage, setActiveLineage] = React.useState<LineageGraph | null>(null);
  const [isLoadingLineage, setIsLoadingLineage] = React.useState(false);
  const [lineageError, setLineageError] = React.useState<string | null>(null);

  const handleService503 = React.useCallback(() => {
    setServiceUnavailable(true);
  }, []);

  const refreshHomeData = React.useCallback(async () => {
    try {
      const healthRes = await fetch('/api/health', { cache: 'no-store' });
      if (!healthRes.ok) return;
      const healthData = (await healthRes.json()) as HealthPayload;
      setHealth(healthData);

      if (!healthData.neo4jConfigured || !healthData.neo4jConnected) {
        setServiceUnavailable(true);
        setFilterOptions(null);
        return;
      }

      setServiceUnavailable(false);
      const filtersRes = await fetch('/api/filters', { cache: 'no-store' });
      if (filtersRes.ok) {
        const opts = (await filtersRes.json()) as FilterOptionsPayload;
        setFilterOptions(opts);
      } else if (filtersRes.status === 503) {
        handleService503();
      }
    } catch {
      // Transient bootstrap errors handled gracefully
    }
  }, [handleService503]);

  const openLineage = React.useCallback(
    async (personId: string) => {
      setIsLoadingLineage(true);
      setLineageError(null);
      try {
        const res = await fetch(`/api/person/${encodeURIComponent(personId)}/lineage`, {
          cache: 'no-store',
        });
        if (res.status === 503) {
          handleService503();
          return;
        }
        if (!res.ok) {
          throw new Error('Could not load lineage for this record.');
        }
        const data = (await res.json()) as LineageGraph;
        setActiveLineage(data);
        const url = new URL(window.location.href);
        url.searchParams.set('person', personId);
        window.history.replaceState({}, '', url.toString());
        window.scrollTo({ top: 0, behavior: 'smooth' });
      } catch (err) {
        setLineageError((err as Error).message);
      } finally {
        setIsLoadingLineage(false);
      }
    },
    [handleService503]
  );

  React.useEffect(() => {
    refreshHomeData();

    const params = new URLSearchParams(window.location.search);
    const personParam = params.get('person');
    if (personParam) {
      openLineage(personParam);
    }

    const handlePageRefresh = () => {
      if (!window.location.search.includes('person=')) {
        refreshHomeData();
      }
    };
    window.addEventListener('pageshow', handlePageRefresh);
    window.addEventListener('focus', handlePageRefresh);
    return () => {
      window.removeEventListener('pageshow', handlePageRefresh);
      window.removeEventListener('focus', handlePageRefresh);
    };
  }, [openLineage, refreshHomeData]);

  const executeSearch = React.useCallback(
    async (
      overrideQuery?: string,
      overrideFilters?: SearchFilters,
      options?: { allowAi?: boolean; allowSemantic?: boolean }
    ) => {
      const q = (overrideQuery ?? query).trim();
      const f = overrideFilters ?? filters;
      const hasInput = Boolean(q || f.village || f.mool || f.gotra);

      if (!hasInput) {
        setSearchResult(null);
        setSearchError(null);
        return;
      }

      setActiveLineage(null);
      const url = new URL(window.location.href);
      url.searchParams.delete('person');
      window.history.replaceState({}, '', url.toString());

      setIsSearching(true);
      setSearchError(null);

      try {
        const params = new URLSearchParams();
        if (q) params.set('q', q);
        if (f.village) params.set('village', f.village);
        if (f.mool) params.set('mool', f.mool);
        if (f.gotra) params.set('gotra', f.gotra);
        const allowAi = options?.allowAi ?? true;
        params.set('useAi', 'false');
        params.set('useSemantic', String(options?.allowSemantic ?? true));

        const res = await fetch(`/api/search?${params.toString()}`, { cache: 'no-store' });
        if (res.status === 503) {
          handleService503();
          setSearchResult(null);
          return;
        }
        if (!res.ok) {
          throw new Error('Search request failed. Please try again.');
        }
        let data = (await res.json()) as SearchResponse;

        // If deterministic search found 0 matches for a multi-word natural-language query
        // and AI assist is enabled on submit, retry once with AI query interpretation.
        if (
          allowAi &&
          useAiAssist &&
          health?.aiAvailable &&
          data.totalMatches === 0 &&
          q.split(/\s+/).length >= 3
        ) {
          params.set('useAi', 'true');
          const aiRes = await fetch(`/api/search?${params.toString()}`, { cache: 'no-store' });
          if (aiRes.ok) {
            data = (await aiRes.json()) as SearchResponse;
          }
        }

        setSearchResult(data);
      } catch (err) {
        setSearchError((err as Error).message);
      } finally {
        setIsSearching(false);
      }
    },
    [query, filters, useAiAssist, health?.aiAvailable, handleService503]
  );

  // Auto-refresh results while typing (deterministic) and auto-restore home state when cleared
  React.useEffect(() => {
    if (activeLineage || mode !== 'search') return;
    if (health && (!health.neo4jConfigured || !health.neo4jConnected)) return;

    const trimmed = query.trim();
    const hasFilters = Boolean(filters.village || filters.mool || filters.gotra);

    if (!trimmed && !hasFilters) {
      if (searchResult !== null) {
        setSearchResult(null);
        setSearchError(null);
        refreshHomeData();
      }
      return;
    }

    const timer = window.setTimeout(() => {
      executeSearch(query, filters, { allowAi: false, allowSemantic: false });
    }, 220);

    return () => window.clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [query, filters.village, filters.mool, filters.gotra, mode]);

  // Generate 2-3 sentence AI answer from the retrieved matching records
  React.useEffect(() => {
    if (
      activeLineage ||
      mode !== 'search' ||
      isSearching ||
      !searchResult ||
      !useAiAssist ||
      !health?.aiAvailable ||
      searchResult.answer?.mode === 'gemini'
    ) {
      setIsRefiningAiAnswer(false);
      return;
    }

    let cancelled = false;
    const targetQuery = searchResult.query;
    const candidateIds = searchResult.candidates.slice(0, 6).map((c) => c.person.id);

    const timer = window.setTimeout(async () => {
      setIsRefiningAiAnswer(true);
      try {
        const res = await fetch('/api/ai/answer', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            query: targetQuery,
            candidateIds,
            totalMatches: searchResult.totalMatches,
            appliedFilters: searchResult.appliedFilters,
          }),
        });
        if (!res.ok || cancelled) return;
        const aiAnswer = (await res.json()) as SearchAnswerPayload;
        if (cancelled) return;
        setSearchResult((prev) =>
          prev && prev.query === targetQuery ? { ...prev, answer: aiAnswer } : prev
        );
      } catch {
        // Keep deterministic answer fallback silently on error
      } finally {
        if (!cancelled) setIsRefiningAiAnswer(false);
      }
    }, 250);

    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [
    activeLineage,
    mode,
    isSearching,
    searchResult,
    useAiAssist,
    health?.aiAvailable,
  ]);

  const handleReset = React.useCallback(() => {
    setMode('search');
    setAutoLoadRelationshipSample(false);
    setQuery('');
    setFilters({});
    setSearchResult(null);
    setSearchError(null);
    setIsRefiningAiAnswer(false);
    setActiveLineage(null);
    setLineageError(null);
    const url = new URL(window.location.href);
    url.searchParams.delete('person');
    window.history.replaceState({}, '', url.toString());
    refreshHomeData();
  }, [refreshHomeData]);

  const aiAvailable = Boolean(health?.aiAvailable);
  const counts = health?.counts ?? filterOptions?.metadata.counts ?? null;
  const isServiceReady =
    health === null || (health.neo4jConfigured && health.neo4jConnected && !serviceUnavailable);

  return (
    <div className="min-h-screen flex flex-col bg-[#FBF9F6] text-[#171514]">
      <header className="border-b border-[#E7DCD8] bg-[#FBF9F6]">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 h-15 flex items-center justify-between gap-6">
          <button
            type="button"
            onClick={handleReset}
            className="inline-flex items-center gap-2.5 font-serif text-xl sm:text-2xl font-semibold tracking-tight text-[#171514] whitespace-nowrap shrink-0"
          >
            <MithilaSuryaLogo className="w-8 h-8 shrink-0" />
            <span>PAAG Foundation</span>
          </button>

          <a
            href="https://www.paag.org.in"
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-[#171514] hover:bg-[#C42426] text-white text-xs sm:text-sm font-medium transition-colors whitespace-nowrap shrink-0"
          >
            <span>Build Family Tree</span>
            <ExternalLink className="w-3.5 h-3.5" aria-hidden="true" />
          </a>
        </div>
      </header>

      <main className="flex-1 max-w-5xl w-full mx-auto px-4 sm:px-6 py-8 sm:py-12 space-y-8">
        {!activeLineage && (
          <div className="space-y-6">
            <div className="max-w-3xl mx-auto text-center space-y-3.5">
              <div className="flex justify-center">
                <MithilaSuryaLogo className="w-14 h-14" />
              </div>
              <p className="text-xs font-medium tracking-wider uppercase text-[#C42426]">
                Panji Ancestry &amp; Graph · Search &amp; AI Guide
              </p>
              <h1 className="font-serif text-4xl sm:text-5xl font-semibold tracking-tight text-[#171514] leading-[1.12]">
                Search Panji Documented ancestors &amp; lineages
              </h1>
              <p className="text-[15px] sm:text-base text-[#5E5753] leading-relaxed max-w-2xl mx-auto">
                Ask in natural language, trace family connections across generations, explore{' '}
                <em>mools</em> and <em>gotras</em>, and inspect documented family trees with
                transparent source-backed evidence.
              </p>
            </div>

            {/* Segmented Mode Switcher (no in-page anchor navigation) */}
            <div
              role="tablist"
              aria-label="Panji Search Tools"
              className="flex flex-wrap items-center justify-center gap-2"
            >
              {WORKSPACE_MODES.map((item) => {
                const Icon = item.icon;
                const active = mode === item.id;
                return (
                  <button
                    key={item.id}
                    type="button"
                    role="tab"
                    aria-selected={active}
                    onClick={() => {
                      setAutoLoadRelationshipSample(false);
                      setMode(item.id);
                    }}
                    className={`inline-flex items-center gap-2 px-4 py-2 rounded-xl text-xs sm:text-sm font-medium border transition-colors whitespace-nowrap shrink-0 ${
                      active
                        ? 'bg-[#171514] border-[#171514] text-white'
                        : 'bg-white border-[#E7DCD8] text-[#5E5753] hover:border-[#CBB8B2] hover:text-[#171514]'
                    }`}
                  >
                    <Icon className="w-3.5 h-3.5" aria-hidden="true" />
                    <span>{item.label}</span>
                  </button>
                );
              })}
            </div>
          </div>
        )}

        {/* Calm Service Unavailable Notice (only if backend archive cannot be reached) */}
        {!isServiceReady && (
          <div
            role="status"
            className="rounded-2xl bg-[#FDF3F2] border border-[#DFB7B5] p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-4"
          >
            <div className="flex items-start gap-3">
              <AlertCircle className="w-5 h-5 text-[#C42426] shrink-0 mt-0.5" aria-hidden="true" />
              <div className="space-y-0.5 text-sm">
                <div className="font-semibold text-[#171514]">
                  Genealogy search archive is temporarily unavailable
                </div>
                <p className="text-xs text-[#5E5753]">
                  Live records could not be reached right now. Please retry in a moment.
                </p>
              </div>
            </div>
            <button
              type="button"
              onClick={refreshHomeData}
              className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-[#C42426] hover:bg-[#A31B1D] text-white text-xs font-medium transition-colors whitespace-nowrap shrink-0 self-start sm:self-center"
            >
              <RefreshCw className="w-3.5 h-3.5" aria-hidden="true" />
              <span>Retry</span>
            </button>
          </div>
        )}

        {/* Active Search Mode */}
        {!activeLineage && mode === 'search' && (
          <SearchPanel
            query={query}
            onQueryChange={setQuery}
            filters={filters}
            onFiltersChange={setFilters}
            filterOptions={filterOptions}
            useAiAssist={useAiAssist}
            onToggleAiAssist={setUseAiAssist}
            aiAvailable={aiAvailable}
            semanticSearchAvailable={Boolean(health?.semanticSearchAvailable)}
            semanticSearchError={health?.semanticSearchError}
            semanticSearchWarning={health?.semanticSearchWarning}
            isSearching={isSearching}
            onSubmit={executeSearch}
            onReset={handleReset}
          />
        )}

        {/* Additional Archive Views */}
        {isServiceReady && !activeLineage && mode === 'relationship' && (
          <RelationshipFinder
            autoLoadSample={autoLoadRelationshipSample}
            onOpenLineage={openLineage}
            onNeo4jError={handleService503}
          />
        )}

        {isServiceReady && !activeLineage && mode === 'mools' && (
          <MoolGotraBrowser
            onNeo4jError={handleService503}
            onFilterSearch={(nextFilters) => {
              setMode('search');
              setQuery('');
              setFilters(nextFilters);
              executeSearch('', nextFilters, { allowAi: false });
            }}
          />
        )}

        {isServiceReady && !activeLineage && mode === 'coverage' && (
          <TreeCoveragePanel onOpenLineage={openLineage} onNeo4jError={handleService503} />
        )}

        {/* Lineage Loading / Error */}
        {isLoadingLineage && (
          <div
            aria-live="polite"
            className="rounded-3xl bg-white border border-[#E7DCD8] p-8 text-center space-y-3"
          >
            <div className="w-8 h-8 rounded-full border-2 border-[#C42426] border-t-transparent animate-spin mx-auto" />
            <p className="text-sm text-[#5E5753]">Loading documented lineage…</p>
          </div>
        )}

        {lineageError && (
          <div
            role="alert"
            className="rounded-2xl bg-[#C42426]/8 border border-[#C42426]/25 p-5 text-sm text-[#8E181A]"
          >
            {lineageError}
          </div>
        )}

        {/* Active Lineage Explorer */}
        {activeLineage && !isLoadingLineage && (
          <LineageExplorer
            lineage={activeLineage}
            activeQuery={query}
            aiAvailable={aiAvailable}
            semanticSearchAvailable={Boolean(health?.semanticSearchAvailable)}
            semanticSearchError={health?.semanticSearchError}
            semanticSearchWarning={health?.semanticSearchWarning}
            onSelectPerson={openLineage}
            onBackToResults={() => {
              setActiveLineage(null);
              const url = new URL(window.location.href);
              url.searchParams.delete('person');
              window.history.replaceState({}, '', url.toString());
              if (!searchResult) {
                refreshHomeData();
              }
            }}
          />
        )}

        {/* Search Loading State */}
        {isServiceReady && !activeLineage && mode === 'search' && isSearching && (
          <div aria-live="polite" className="space-y-4">
            {[1, 2, 3].map((n) => (
              <div
                key={n}
                className="rounded-2xl bg-white border border-[#E7DCD8] p-6 animate-pulse space-y-3"
              >
                <div className="h-6 w-48 bg-[#F4E6E4] rounded" />
                <div className="h-4 w-72 bg-[#FAF2F0] rounded" />
                <div className="h-3 w-56 bg-[#FAF2F0] rounded" />
              </div>
            ))}
          </div>
        )}

        {/* Search Error State */}
        {isServiceReady && !activeLineage && mode === 'search' && searchError && (
          <div
            role="alert"
            className="rounded-2xl bg-[#C42426]/8 border border-[#C42426]/25 p-5 text-sm text-[#8E181A]"
          >
            {searchError}
          </div>
        )}

        {/* Search Results / Concise AI Answer + Supporting Records */}
        {isServiceReady &&
          !activeLineage &&
          mode === 'search' &&
          !isSearching &&
          searchResult && (
            <section aria-live="polite" aria-label="Search Results" className="space-y-5">
              {/* Concise 2-3 Line Grounded Answer Directly Below Search */}
              {searchResult.answer && (
                <div
                  aria-label="Concise Answer"
                  className="rounded-2xl bg-[#FDF3F2] border border-[#ECCACA] p-5 sm:p-6 space-y-3"
                >
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <div className="inline-flex items-center gap-2 text-xs font-semibold uppercase tracking-wider text-[#8E181A]">
                      <Sparkles className="w-3.5 h-3.5" aria-hidden="true" />
                      <span>
                        {searchResult.answer.mode === 'gemini'
                          ? 'AI Summary'
                          : 'Grounded Summary'}
                      </span>
                    </div>
                    <span className="text-[11px] text-[#6E5656]">
                      {isRefiningAiAnswer
                        ? 'Generating AI summary…'
                        : searchResult.answer.mode === 'gemini'
                          ? 'Generated strictly from matching records'
                          : 'Deterministic summary from matching records'}
                    </span>
                  </div>

                  <p className="text-[15px] sm:text-base leading-relaxed text-[#171514]">
                    {searchResult.answer.text}
                  </p>

                  {searchResult.answer.citedRecords.length > 0 && (
                    <div className="flex flex-wrap items-center gap-2 pt-1 text-xs">
                      <span className="text-[#5E5753]">Referenced records:</span>
                      {searchResult.answer.citedRecords.map((rec) => (
                        <button
                          key={rec.id}
                          type="button"
                          onClick={() => openLineage(rec.id)}
                          className="px-2.5 py-1 rounded-lg bg-white border border-[#E7C6C4] hover:border-[#C42426] text-[#171514] font-medium transition-colors"
                        >
                          {rec.label}
                          {rec.source_ref ? ` (${rec.source_ref})` : ''}
                        </button>
                      ))}
                    </div>
                  )}
                </div>
              )}

              {/* Evidence & Supporting Matching Records Bar */}
              <div className="rounded-2xl bg-white border border-[#E7DCD8] px-5 py-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                <div className="space-y-1 text-sm">
                  <div className="font-medium text-[#171514]">
                    Evidence &amp; Supporting Records:{' '}
                    <span className="tabular-nums font-mono">{searchResult.totalMatches}</span>{' '}
                    match{searchResult.totalMatches === 1 ? '' : 'es'}
                    {searchResult.totalMatches > searchResult.candidates.length
                      ? ` (showing top ${searchResult.candidates.length})`
                      : ''}
                  </div>
                  <div className="text-xs text-[#5E5753] flex flex-wrap items-center gap-x-2 gap-y-1">
                    <span>
                      Query interpretation:{' '}
                      {searchResult.interpretation.strategy === 'gemini'
                        ? 'AI-assisted'
                        : 'Deterministic'}
                    </span>
                    {searchResult.interpretation.personTerms.length > 0 && (
                      <>
                        <span aria-hidden="true">·</span>
                        <span>
                          Terms: &ldquo;{searchResult.interpretation.personTerms.join(' ')}&rdquo;
                        </span>
                      </>
                    )}
                    <span aria-hidden="true">·</span>
                    <span>
                      {searchResult.semanticSearchUsed
                        ? 'Hybrid exact + semantic ranking'
                        : 'Exact name, village, and filter ranking'}
                    </span>
                    {searchResult.appliedFilters.village && (
                      <>
                        <span aria-hidden="true">·</span>
                        <span>Village filter: {searchResult.appliedFilters.village}</span>
                      </>
                    )}
                    {searchResult.appliedFilters.mool && (
                      <>
                        <span aria-hidden="true">·</span>
                        <span>Mool filter: {searchResult.appliedFilters.mool}</span>
                      </>
                    )}
                    {searchResult.appliedFilters.gotra && (
                      <>
                        <span aria-hidden="true">·</span>
                        <span>Gotra filter: {searchResult.appliedFilters.gotra}</span>
                      </>
                    )}
                  </div>
                </div>

                <button
                  type="button"
                  onClick={handleReset}
                  className="text-xs font-medium text-[#C42426] hover:underline self-start sm:self-center whitespace-nowrap shrink-0"
                >
                  Clear search
                </button>
              </div>

              {searchResult.semanticSearchWarning && (
                <p role="status" className="rounded-xl bg-[#FFF7E6] px-4 py-3 text-xs text-[#8A5A10]">
                  {searchResult.semanticSearchWarning}
                </p>
              )}

              {searchResult.candidates.length === 0 ? (
                <div className="rounded-3xl bg-white border border-[#E7DCD8] p-8 sm:p-10 text-center space-y-3">
                  <h2 className="font-serif text-2xl font-semibold text-[#171514]">
                    No documented records matched this search
                  </h2>
                  <p className="text-sm text-[#5E5753] max-w-xl mx-auto leading-relaxed">
                    This public extract contains{' '}
                    <span className="tabular-nums font-medium text-[#171514]">
                      {counts?.persons.toLocaleString() ?? '1,888'}
                    </span>{' '}
                    digitized records and is not a complete atlas of every Maithil family. Try a
                    shorter given name, adjust filters, or search by Devanagari spelling.
                  </p>
                </div>
              ) : (
                <div className="space-y-3.5">
                  {searchResult.candidates.map((candidate) => (
                    <CandidateCard
                      key={candidate.person.id}
                      candidate={candidate}
                      onOpenLineage={openLineage}
                    />
                  ))}
                </div>
              )}
            </section>
          )}

        {/* Idle State: Illustrative Interactive Guide + Corpus Coverage Summary */}
        {!activeLineage && mode === 'search' && !isSearching && !searchResult && (
          <div className="space-y-6">
            <UsageGuide
              onTrySearch={(sampleQuery) => {
                setQuery(sampleQuery);
                setFilters({});
                executeSearch(sampleQuery, {});
              }}
              onTryRelationshipSample={() => {
                setAutoLoadRelationshipSample(true);
                setMode('relationship');
              }}
              onOpenMoolBrowser={() => setMode('mools')}
              onOpenTreeCoverage={() => setMode('coverage')}
            />

            {counts && (
              <section
                aria-label="Indexed archive summary"
                className="grid grid-cols-2 sm:grid-cols-4 gap-3 sm:gap-4"
              >
                <div className="rounded-2xl bg-white border border-[#E7DCD8] p-4 sm:p-5">
                  <div className="font-mono text-2xl font-medium text-[#C42426] tabular-nums">
                    {counts.persons.toLocaleString()}
                  </div>
                  <div className="text-xs text-[#5E5753] mt-1">Person records indexed</div>
                </div>
                <div className="rounded-2xl bg-white border border-[#E7DCD8] p-4 sm:p-5">
                  <div className="font-mono text-2xl font-medium text-[#171514] tabular-nums">
                    {counts.villages.toLocaleString()}
                  </div>
                  <div className="text-xs text-[#5E5753] mt-1">Recorded villages</div>
                </div>
                <div className="rounded-2xl bg-white border border-[#E7DCD8] p-4 sm:p-5">
                  <div className="font-mono text-2xl font-medium text-[#171514] tabular-nums">
                    {counts.mools} / {counts.gotras}
                  </div>
                  <div className="text-xs text-[#5E5753] mt-1">Mools &amp; canonical gotras</div>
                </div>
                <div className="rounded-2xl bg-white border border-[#E7DCD8] p-4 sm:p-5">
                  <div className="font-mono text-2xl font-medium text-[#171514] tabular-nums">
                    {counts.childOfEdges + counts.siblingOfEdges}
                  </div>
                  <div className="text-xs text-[#5E5753] mt-1">Documented family links</div>
                </div>
              </section>
            )}
          </div>
        )}
      </main>

      <footer className="border-t border-[#E7DCD8] bg-white/75">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 py-4 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-2 text-xs text-[#5E5753]">
          <span>
            PAAG Foundation ·{' '}
            <a
              href="https://www.paag.org.in"
              target="_blank"
              rel="noreferrer"
              className="hover:text-[#C42426] underline decoration-[#D2C3BE]"
            >
              paag.org.in
            </a>
          </span>
          <span>
            Partial 2009 corpus (Thakur, Jha &amp; Jha / Mithila-Panji, CC BY-SA 4.0) · Not
            official matrimonial or legal proof
          </span>
        </div>
      </footer>
    </div>
  );
}
