import React from 'react';
import { ArrowLeft, Check, ChevronRight, Copy, Info, Sparkles } from 'lucide-react';
import type {
  AiExplanationPayload,
  LineageGraph,
  LineageNode,
  SearchCandidate,
  SimilarPeopleResponse,
} from '../types/panji.ts';
import { LineageGraphCanvas } from './LineageGraphCanvas.tsx';
import { MadhubaniBorderStrip, MadhubaniCorner } from './MadhubaniMotifs.tsx';

interface LineageExplorerProps {
  lineage: LineageGraph;
  activeQuery?: string;
  aiAvailable: boolean;
  semanticSearchAvailable: boolean;
  semanticSearchError?: string;
  semanticSearchWarning?: string;
  onSelectPerson: (personId: string) => void;
  onBackToResults: () => void;
}

export function LineageExplorer({
  lineage,
  activeQuery,
  aiAvailable,
  semanticSearchAvailable,
  semanticSearchError,
  semanticSearchWarning,
  onSelectPerson,
  onBackToResults,
}: LineageExplorerProps) {
  const [viewMode, setViewMode] = React.useState<'split' | 'graph' | 'list'>('split');
  const [copied, setCopied] = React.useState(false);
  const [explanation, setExplanation] = React.useState<AiExplanationPayload | null>(null);
  const [isExplaining, setIsExplaining] = React.useState(false);
  const [explainError, setExplainError] = React.useState<string | null>(null);
  const [similarProfiles, setSimilarProfiles] = React.useState<SearchCandidate[]>([]);
  const [isLoadingSimilar, setIsLoadingSimilar] = React.useState(false);
  const [similarError, setSimilarError] = React.useState<string | null>(null);
  const [similarWarning, setSimilarWarning] = React.useState<string | null>(null);

  const p = lineage.focusPerson;

  React.useEffect(() => {
    setExplanation(null);
    setExplainError(null);
  }, [p.id]);

  React.useEffect(() => {
    let cancelled = false;
    setSimilarProfiles([]);
    setSimilarError(null);
    setSimilarWarning(null);
    if (!semanticSearchAvailable) {
      setIsLoadingSimilar(false);
      return;
    }

    setIsLoadingSimilar(true);
    fetch(`/api/person/${encodeURIComponent(p.id)}/similar?limit=5`, {
      cache: 'no-store',
    })
      .then(async (res) => {
        if (!res.ok) throw new Error('Could not load similar ancestor suggestions.');
        return (await res.json()) as SimilarPeopleResponse;
      })
      .then((data) => {
        if (cancelled) return;
        setSimilarWarning(data.warning || null);
        if (!data.available) {
          setSimilarError(data.error || 'Semantic suggestions are not ready yet.');
          return;
        }
        setSimilarProfiles(data.candidates);
      })
      .catch((err: unknown) => {
        if (!cancelled) setSimilarError((err as Error).message);
      })
      .finally(() => {
        if (!cancelled) setIsLoadingSimilar(false);
      });

    return () => {
      cancelled = true;
    };
  }, [p.id, semanticSearchAvailable]);

  const handleCopyShareLink = async () => {
    try {
      const url = new URL(window.location.href);
      url.searchParams.set('person', p.id);
      await navigator.clipboard.writeText(url.toString());
      setCopied(true);
      window.setTimeout(() => setCopied(false), 2000);
    } catch {
      setCopied(false);
    }
  };

  const handleExplain = async () => {
    setIsExplaining(true);
    setExplainError(null);
    try {
      const res = await fetch('/api/ai/explain', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ personId: p.id, query: activeQuery || undefined }),
      });
      if (!res.ok) {
        throw new Error('Could not generate explanation for this record.');
      }
      const data = (await res.json()) as AiExplanationPayload;
      setExplanation(data);
    } catch (err) {
      setExplainError((err as Error).message);
    } finally {
      setIsExplaining(false);
    }
  };

  const groupedGenerations = React.useMemo(() => {
    const map = new Map<number, LineageNode[]>();
    for (const node of lineage.nodes) {
      const list = map.get(node.generationOffset) ?? [];
      list.push(node);
      map.set(node.generationOffset, list);
    }
    return Array.from(map.entries()).sort((a, b) => a[0] - b[0]);
  }, [lineage.nodes]);

  const generationLabel = (offset: number) => {
    if (offset === 0) return 'Selected Person & Documented Siblings';
    if (offset === -1) return 'Parents (1 generation earlier)';
    if (offset < -1) return `Ancestors (${Math.abs(offset)} generations earlier)`;
    if (offset === 1) return 'Children (1 generation later)';
    return `Descendants (${offset} generations later)`;
  };

  return (
    <section aria-label={`Lineage explorer for ${p.label}`} className="space-y-6">
      {/* Top Action Bar */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <button
          type="button"
          onClick={onBackToResults}
          className="inline-flex items-center gap-2 px-3.5 py-2 rounded-xl bg-white border border-[#E7DCD8] hover:border-[#C9B3AE] text-sm font-medium text-[#171514] transition-colors whitespace-nowrap shrink-0"
        >
          <ArrowLeft className="w-4 h-4" aria-hidden="true" />
          <span>Back to Results</span>
        </button>

        <div className="flex flex-wrap items-center gap-2">
          <div
            role="group"
            aria-label="Lineage display mode"
            className="inline-flex items-center p-1 rounded-xl bg-[#F3EAE7] border border-[#E5D4D0]"
          >
            {(['split', 'graph', 'list'] as const).map((mode) => (
              <button
                key={mode}
                type="button"
                onClick={() => setViewMode(mode)}
                className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors whitespace-nowrap shrink-0 ${
                  viewMode === mode
                    ? 'bg-white text-[#171514] shadow-xs'
                    : 'text-[#5E5753] hover:text-[#171514]'
                }`}
              >
                {mode === 'split' ? 'Graph + List' : mode === 'graph' ? 'Graph Only' : 'List Only'}
              </button>
            ))}
          </div>

          <button
            type="button"
            onClick={handleCopyShareLink}
            className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-white border border-[#E7DCD8] hover:border-[#C9B3AE] text-xs font-medium text-[#171514] transition-colors whitespace-nowrap shrink-0"
          >
            {copied ? (
              <>
                <Check className="w-3.5 h-3.5 text-[#2B6249]" aria-hidden="true" />
                <span>Link Copied</span>
              </>
            ) : (
              <>
                <Copy className="w-3.5 h-3.5" aria-hidden="true" />
                <span>Copy Lineage Link</span>
              </>
            )}
          </button>
        </div>
      </div>

      {/* Person Dossier Card framed by Madhubani border strip */}
      <div className="relative overflow-hidden rounded-3xl bg-white border border-[#E7DCD8] shadow-[0_10px_32px_rgba(23,21,20,0.06)]">
        <MadhubaniBorderStrip />

        <div className="relative p-6 sm:p-8">
          <MadhubaniCorner position="bottom-left" />
          <MadhubaniCorner position="bottom-right" />

          <div className="relative z-10 space-y-5">
            <div className="flex flex-col lg:flex-row lg:items-start justify-between gap-4">
              <div>
                <p className="text-xs font-medium text-[#786E69] mb-1">
                  Documented Person Record · <span className="font-mono">{p.id}</span>
                </p>
                <div className="flex flex-wrap items-baseline gap-x-4 gap-y-1">
                  <h2 className="font-serif text-3xl sm:text-4xl font-semibold text-[#171514]">
                    {p.name_roman || p.name_dev || p.id}
                  </h2>
                  {p.name_dev && p.name_roman && (
                    <span className="text-xl sm:text-2xl text-[#5E5753]">{p.name_dev}</span>
                  )}
                </div>
              </div>

              <button
                type="button"
                onClick={handleExplain}
                disabled={isExplaining}
                className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-[#171514] hover:bg-[#C42426] text-white text-sm font-medium transition-colors whitespace-nowrap shrink-0 disabled:opacity-60"
              >
                <Sparkles className="w-4 h-4" aria-hidden="true" />
                <span>
                  {isExplaining
                    ? 'Summarizing Record…'
                    : aiAvailable
                      ? 'Explain Record & Gaps (AI)'
                      : 'Summarize Record & Gaps'}
                </span>
              </button>
            </div>

            {/* Structured Definition Grid: Source-Backed vs Inferred */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6 pt-4 border-t border-[#F2E9E6]">
              <div>
                <h3 className="text-xs font-semibold uppercase tracking-wider text-[#2B6249] mb-3">
                  Source-Backed Facts
                </h3>
                <dl className="space-y-2 text-sm">
                  <div className="flex justify-between gap-4 py-1 border-b border-[#F7F1EF]">
                    <dt className="text-[#786E69]">Recorded Village</dt>
                    <dd className="font-medium text-[#171514] text-right">
                      {p.village_roman || p.village_dev ? (
                        <>
                          {p.village_roman || p.village_dev}
                          {p.village_dev && p.village_roman ? ` (${p.village_dev})` : ''}
                        </>
                      ) : (
                        <span className="italic text-[#8A7F7A] font-normal">Not recorded</span>
                      )}
                    </dd>
                  </div>
                  <div className="flex justify-between gap-4 py-1 border-b border-[#F7F1EF]">
                    <dt className="text-[#786E69]">Titles / Honorifics</dt>
                    <dd className="font-medium text-[#171514] text-right">
                      {p.titles || (
                        <span className="italic text-[#8A7F7A] font-normal">None recorded</span>
                      )}
                    </dd>
                  </div>
                  <div className="flex justify-between gap-4 py-1 border-b border-[#F7F1EF]">
                    <dt className="text-[#786E69]">Source Citation</dt>
                    <dd className="font-mono text-xs text-[#2E2A27] text-right">
                      {p.source_ref || 'Unnumbered'} · {p.source_file || '2009 extract'}
                    </dd>
                  </div>
                </dl>
              </div>

              <div>
                <h3 className="text-xs font-semibold uppercase tracking-wider text-[#A31B1D] mb-3">
                  Inferred &amp; Contextual Attributes
                </h3>
                <dl className="space-y-2 text-sm">
                  <div className="flex justify-between gap-4 py-1 border-b border-[#F7F1EF]">
                    <dt className="text-[#786E69]">Mool (via village match)</dt>
                    <dd className="font-medium text-[#171514] text-right">
                      {p.inferredMool ? (
                        `${p.inferredMool.name_roman} (${p.inferredMool.name_dev})`
                      ) : (
                        <span className="italic text-[#8A7F7A] font-normal">
                          Not matched to mool index
                        </span>
                      )}
                    </dd>
                  </div>
                  <div className="flex justify-between gap-4 py-1 border-b border-[#F7F1EF]">
                    <dt className="text-[#786E69]">Gotra (via mool directory)</dt>
                    <dd className="font-medium text-[#171514] text-right">
                      {p.inferredGotras.length > 0 ? (
                        p.inferredGotras.map((g) => `${g.name_roman} (${g.name_dev})`).join(', ')
                      ) : (
                        <span className="italic text-[#8A7F7A] font-normal">Not inferred</span>
                      )}
                    </dd>
                  </div>
                  <div className="flex justify-between gap-4 py-1 border-b border-[#F7F1EF]">
                    <dt className="text-[#786E69]">People in This Lineage</dt>
                    <dd className="font-mono text-xs text-[#2E2A27] tabular-nums text-right">
                      {lineage.nodes.length} person{lineage.nodes.length === 1 ? '' : 's'} ·{' '}
                      {lineage.edges.length} link{lineage.edges.length === 1 ? '' : 's'}
                    </dd>
                  </div>
                </dl>
              </div>
            </div>

            {/* Ancestor Chain */}
            <div className="rounded-2xl bg-[#FBF9F6] border border-[#EDE2DF] p-4 space-y-2">
              <div className="text-xs font-medium text-[#5E5753]">
                Documented Ancestor Path (oldest recorded in this extract → selected person)
              </div>
              <div className="flex flex-wrap items-center gap-1.5 text-sm">
                {lineage.ancestorChainToOldest.map((anc, idx) => {
                  const isLast = idx === lineage.ancestorChainToOldest.length - 1;
                  return (
                    <React.Fragment key={anc.id}>
                      <button
                        type="button"
                        onClick={() => onSelectPerson(anc.id)}
                        className={`px-2.5 py-1 rounded-lg transition-colors text-left ${
                          isLast
                            ? 'bg-[#C42426] text-white font-medium'
                            : 'bg-white border border-[#E7DCD8] hover:border-[#C42426] text-[#171514]'
                        }`}
                      >
                        {anc.label}
                      </button>
                      {!isLast && (
                        <ChevronRight
                          className="w-4 h-4 text-[#9E8B87] shrink-0"
                          aria-hidden="true"
                        />
                      )}
                    </React.Fragment>
                  );
                })}
              </div>
            </div>

            {/* Grounded Explanation Panel */}
            {explainError && (
              <div
                role="alert"
                className="rounded-2xl bg-[#C42426]/8 border border-[#C42426]/25 p-4 text-sm text-[#8E181A]"
              >
                {explainError}
              </div>
            )}

            {explanation && (
              <div className="rounded-2xl bg-[#FDF3F2] border border-[#ECCACA] p-5 space-y-4">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <h3 className="text-sm font-semibold text-[#8E181A]">
                    {explanation.mode === 'gemini'
                      ? 'AI-Assisted Record Explanation (Grounded in Retrieved Corpus)'
                      : 'Deterministic Record Summary (No External AI Used)'}
                  </h3>
                  <span className="font-mono text-xs text-[#6E5656]">
                    Cited: {explanation.citedRecords.map((r) => r.id).join(', ')}
                  </span>
                </div>

                <p className="text-sm leading-relaxed text-[#171514]">{explanation.summary}</p>

                <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-xs leading-relaxed">
                  <div className="space-y-1.5">
                    <div className="font-semibold text-[#2B6249]">Source-Backed Facts</div>
                    <ul className="list-disc pl-4 space-y-1 text-[#3E3835]">
                      {explanation.sourceBackedFacts.map((fact, i) => (
                        <li key={i}>{fact}</li>
                      ))}
                    </ul>
                  </div>

                  <div className="space-y-1.5">
                    <div className="font-semibold text-[#A31B1D]">Inferred or Multiple-Match</div>
                    {explanation.inferredOrUncertain.length > 0 ? (
                      <ul className="list-disc pl-4 space-y-1 text-[#3E3835]">
                        {explanation.inferredOrUncertain.map((item, i) => (
                          <li key={i}>{item}</li>
                        ))}
                      </ul>
                    ) : (
                      <p className="text-[#5E5753] italic">
                        No inferred attributes on this record.
                      </p>
                    )}
                  </div>

                  <div className="space-y-1.5">
                    <div className="font-semibold text-[#262321]">Gaps &amp; Corpus Limits</div>
                    <ul className="list-disc pl-4 space-y-1 text-[#3E3835]">
                      {explanation.gapsAndLimitations.map((gap, i) => (
                        <li key={i}>{gap}</li>
                      ))}
                    </ul>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      <section
        aria-label="Similar ancestor suggestions"
        className="rounded-2xl bg-white border border-[#E7DCD8] p-5 space-y-3"
      >
        <div className="flex items-center gap-2">
          <Sparkles className="w-4 h-4 text-[#64519A]" aria-hidden="true" />
          <h3 className="font-serif text-xl font-semibold text-[#171514]">
            Similar ancestor profiles
          </h3>
        </div>
        <p className="text-xs leading-relaxed text-[#5E5753]">
          Suggestions compare recorded names, villages, titles, inferred gotra context, and
          relatives. Similarity is a discovery aid, not evidence of kinship.
        </p>
        {!semanticSearchAvailable && (
          <p role="status" className="text-xs text-[#786E69]">
            {semanticSearchError || 'Semantic suggestions are not configured.'}
          </p>
        )}
        {semanticSearchAvailable && semanticSearchWarning && (
          <p role="status" className="text-xs text-[#8A5A10]">
            {semanticSearchWarning}
          </p>
        )}
        {isLoadingSimilar && (
          <p aria-live="polite" className="text-xs text-[#786E69]">
            Finding similar profiles…
          </p>
        )}
        {similarError && (
          <p role="alert" className="text-xs text-[#8E181A]">
            {similarError}
          </p>
        )}
        {similarWarning && !semanticSearchWarning && (
          <p role="status" className="text-xs text-[#8A5A10]">
            {similarWarning}
          </p>
        )}
        {semanticSearchAvailable && !isLoadingSimilar && !similarError && similarProfiles.length === 0 && (
          <p className="text-xs text-[#786E69]">No similar profiles were found in this extract.</p>
        )}
        {similarProfiles.length > 0 && (
          <ul className="grid gap-2 sm:grid-cols-2">
            {similarProfiles.map((candidate) => (
              <li key={candidate.person.id}>
                <button
                  type="button"
                  onClick={() => onSelectPerson(candidate.person.id)}
                  className="w-full rounded-xl border border-[#E7DCD8] bg-[#FBF9F6] px-3.5 py-3 text-left hover:border-[#C9B3AE] transition-colors"
                >
                  <span className="flex items-start justify-between gap-3">
                    <span className="min-w-0">
                      <span className="block truncate text-sm font-medium text-[#171514]">
                        {candidate.person.name_roman || candidate.person.name_dev}
                      </span>
                      <span className="block truncate text-xs text-[#5E5753]">
                        {candidate.person.village_roman || 'Village not recorded'}
                        {candidate.person.titles ? ` · ${candidate.person.titles}` : ''}
                      </span>
                    </span>
                    <span className="shrink-0 text-[11px] font-medium text-[#64519A]">
                      {Math.round((candidate.similarity ?? 0) * 100)}% similar
                    </span>
                  </span>
                </button>
              </li>
            ))}
          </ul>
        )}
      </section>

      {/* Main Graph + Generation List Workspace */}
      <div
        className={`grid gap-6 ${
          viewMode === 'split' ? 'grid-cols-1 lg:grid-cols-12 items-start' : 'grid-cols-1'
        }`}
      >
        {(viewMode === 'split' || viewMode === 'graph') && (
          <div className={viewMode === 'split' ? 'lg:col-span-7' : ''}>
            <LineageGraphCanvas lineage={lineage} onSelectPerson={onSelectPerson} />
          </div>
        )}

        {(viewMode === 'split' || viewMode === 'list') && (
          <div
            className={`rounded-2xl bg-white border border-[#E7DCD8] p-5 space-y-4 ${
              viewMode === 'split' ? 'lg:col-span-5' : ''
            }`}
          >
            <div>
              <h3 className="font-serif text-xl font-semibold text-[#171514]">
                Generation Directory
              </h3>
              <p className="text-xs text-[#5E5753]">
                Click any relative to center the lineage view on their record.
              </p>
            </div>

            <div className="space-y-4">
              {groupedGenerations.map(([offset, nodes]) => (
                <div key={offset} className="space-y-2">
                  <div className="text-xs font-semibold text-[#786E69] border-b border-[#F2E9E6] pb-1">
                    {generationLabel(offset)}
                  </div>
                  <ul className="space-y-1.5">
                    {nodes.map((n) => {
                      const isCurrent = n.person.id === p.id;
                      return (
                        <li key={n.person.id}>
                          <button
                            type="button"
                            onClick={() => onSelectPerson(n.person.id)}
                            className={`w-full text-left px-3 py-2.5 rounded-xl border transition-colors flex items-center justify-between gap-3 ${
                              isCurrent
                                ? 'bg-[#FDF3F2] border-[#C42426]/55 text-[#171514]'
                                : 'bg-[#FBF9F6] border-[#EDE2DF] hover:border-[#C9B3AE] text-[#171514]'
                            }`}
                          >
                            <div className="min-w-0">
                              <div className="text-sm font-medium truncate">
                                {n.person.name_roman || n.person.name_dev}
                                {n.person.name_dev && n.person.name_roman
                                  ? ` · ${n.person.name_dev}`
                                  : ''}
                              </div>
                              <div className="text-xs text-[#5E5753] truncate">
                                {n.person.village_roman || 'Village not recorded'}
                                {n.relationshipBasis === 'inferred-shared-parent'
                                  ? ' · Shared parent (inferred)'
                                  : n.role === 'sibling'
                                    ? ' · Recorded sibling'
                                    : ''}
                              </div>
                            </div>
                            <span className="font-mono text-[11px] text-[#786E69] shrink-0">
                              {n.person.source_ref || n.person.id}
                            </span>
                          </button>
                        </li>
                      );
                    })}
                  </ul>
                </div>
              ))}
            </div>

            <div className="pt-3 border-t border-[#F2E9E6] space-y-2">
              <div className="flex items-center gap-1.5 text-xs font-medium text-[#2E2A27]">
                <Info className="w-3.5 h-3.5 text-[#C42426]" aria-hidden="true" />
                <span>Corpus Notes for This Entry</span>
              </div>
              <ul className="space-y-1 text-xs text-[#5E5753] list-disc pl-4">
                {lineage.notes.map((note, idx) => (
                  <li key={idx}>{note}</li>
                ))}
              </ul>
            </div>
          </div>
        )}
      </div>
    </section>
  );
}
