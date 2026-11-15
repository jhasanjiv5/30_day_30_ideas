import React from 'react';
import { GitFork, Search } from 'lucide-react';
import type { MoolsGotrasPayload } from '../types/panji.ts';
import { MadhubaniBorderStrip } from './MadhubaniMotifs.tsx';

interface MoolGotraBrowserProps {
  onFilterSearch: (filters: { mool?: string; gotra?: string }) => void;
  onNeo4jError?: (msg: string) => void;
}

export function MoolGotraBrowser({
  onFilterSearch,
  onNeo4jError,
}: MoolGotraBrowserProps) {
  const [data, setData] = React.useState<MoolsGotrasPayload | null>(null);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);
  const [crossOnly, setCrossOnly] = React.useState(false);
  const [selectedGotra, setSelectedGotra] = React.useState<string>('');
  const [filterText, setFilterText] = React.useState('');

  React.useEffect(() => {
    let active = true;
    (async () => {
      setLoading(true);
      setError(null);
      try {
        const res = await fetch('/api/neo4j/mools-gotras', { cache: 'no-store' });
        if (res.status === 503) {
          onNeo4jError?.('Genealogy archive is temporarily unavailable. Please try again in a moment.');
          return;
        }
        if (!res.ok) {
          throw new Error('Could not load mool and gotra directory.');
        }
        const payload = (await res.json()) as MoolsGotrasPayload;
        if (active) setData(payload);
      } catch (err) {
        if (active) setError((err as Error).message);
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [onNeo4jError]);

  const filteredMools = React.useMemo(() => {
    if (!data) return [];
    const q = filterText.trim().toLowerCase();
    return data.mools.filter((m) => {
      if (crossOnly && !m.isCrossGotra) return false;
      if (selectedGotra && !m.gotras.some((g) => g.name_roman === selectedGotra)) return false;
      if (q) {
        const hay = `${m.name_roman} ${m.name_dev} ${m.aka.join(' ')} ${m.gotras
          .map((g) => `${g.name_roman} ${g.name_dev}`)
          .join(' ')}`.toLowerCase();
        if (!hay.includes(q)) return false;
      }
      return true;
    });
  }, [data, crossOnly, selectedGotra, filterText]);

  return (
    <section
      aria-label="Mool and Gotra Browser"
      className="relative overflow-hidden rounded-3xl bg-white border border-[#E7DCD8] shadow-[0_14px_40px_rgba(23,21,20,0.06)]"
    >
      <MadhubaniBorderStrip />

      <div className="p-5 sm:p-8 space-y-6">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div>
            <h2 className="font-serif text-2xl sm:text-3xl font-semibold text-[#171514]">
              Mool &amp; Canonical Gotra Browser
            </h2>
            <p className="text-sm text-[#5E5753] mt-1">
              Explore traditional Maithil <em>mools</em> and their canonical <em>gotras</em>,
              including cross-gotra mools where two or more gotras share the same mool name.
            </p>
          </div>

          {data && (
            <div className="flex items-center gap-3 text-xs font-mono text-[#5E5753] shrink-0">
              <span className="px-2.5 py-1 rounded-md bg-[#FBF9F6] border border-[#E7DCD8] tabular-nums">
                {data.mools.length} mools
              </span>
              <span className="px-2.5 py-1 rounded-md bg-[#FDF3F2] border border-[#DFB7B5] text-[#8E181A] tabular-nums">
                {data.crossGotraCount} cross-gotra
              </span>
            </div>
          )}
        </div>

        {loading && (
          <div className="py-10 text-center text-sm text-[#5E5753]">
            Loading mool and gotra directory…
          </div>
        )}

        {error && (
          <div
            role="alert"
            className="rounded-2xl bg-[#C42426]/8 border border-[#C42426]/25 p-4 text-sm text-[#8E181A]"
          >
            {error}
          </div>
        )}

        {data && !loading && (
          <>
            {/* Canonical Gotra Strip */}
            <div className="space-y-2">
              <div className="text-xs font-semibold uppercase tracking-wider text-[#5E5753]">
                Filter by Canonical Gotra ({data.gotras.length})
              </div>
              <div className="flex flex-wrap gap-2">
                <button
                  type="button"
                  onClick={() => setSelectedGotra('')}
                  className={`px-3 py-1.5 rounded-lg text-xs font-medium border transition-colors ${
                    selectedGotra === ''
                      ? 'bg-[#171514] border-[#171514] text-white'
                      : 'bg-[#FBF9F6] border-[#E7DCD8] text-[#5E5753] hover:text-[#171514]'
                  }`}
                >
                  All Gotras
                </button>
                {data.gotras.map((g) => (
                  <button
                    key={g.id}
                    type="button"
                    onClick={() =>
                      setSelectedGotra((cur) => (cur === g.name_roman ? '' : g.name_roman))
                    }
                    className={`px-2.5 py-1.5 rounded-lg text-xs border transition-colors ${
                      selectedGotra === g.name_roman
                        ? 'bg-[#C42426] border-[#C42426] text-white font-medium'
                        : 'bg-white border-[#E7DCD8] text-[#171514] hover:border-[#C42426]/60'
                    }`}
                  >
                    <span>{g.name_roman}</span>
                    <span className="ml-1.5 opacity-75 font-mono tabular-nums">
                      ({g.moolCount})
                    </span>
                  </button>
                ))}
              </div>
            </div>

            {/* Filter controls */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pt-2 border-t border-[#F2E9E6]">
              <div className="relative flex-1 max-w-sm">
                <Search
                  className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#6E6560]"
                  aria-hidden="true"
                />
                <input
                  type="text"
                  value={filterText}
                  onChange={(e) => setFilterText(e.target.value)}
                  placeholder="Filter mool, aka, or gotra…"
                  aria-label="Filter mools by name"
                  className="w-full h-10 pl-9 pr-3 rounded-xl bg-[#FBF9F6] border border-[#E0D2CE] text-sm text-[#171514] focus:bg-white focus:border-[#C42426] focus:outline-none"
                />
              </div>

              <button
                type="button"
                role="switch"
                aria-checked={crossOnly}
                onClick={() => setCrossOnly((v) => !v)}
                className={`inline-flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-medium border transition-colors self-start sm:self-auto ${
                  crossOnly
                    ? 'bg-[#FDF3F2] border-[#C42426]/40 text-[#8E181A]'
                    : 'bg-white border-[#E7DCD8] text-[#5E5753] hover:text-[#171514]'
                }`}
              >
                <GitFork className="w-3.5 h-3.5" aria-hidden="true" />
                <span>Cross-Gotra Mools Only ({data.crossGotraCount})</span>
              </button>
            </div>

            {/* Mool Cards Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              {filteredMools.map((m) => (
                <div
                  key={m.id}
                  className={`rounded-2xl border p-4 flex flex-col justify-between gap-3 ${
                    m.isCrossGotra
                      ? 'bg-[#FDF3F2]/60 border-[#DFB7B5]'
                      : 'bg-[#FBF9F6] border-[#E7DCD8]'
                  }`}
                >
                  <div className="space-y-1.5">
                    <div className="flex items-start justify-between gap-2">
                      <div>
                        <span className="font-serif text-lg font-semibold text-[#171514]">
                          {m.name_roman}
                        </span>
                        {m.name_dev && (
                          <span className="ml-2 font-devanagari text-sm text-[#5E5753]">
                            {m.name_dev}
                          </span>
                        )}
                      </div>
                      <span className="text-[11px] font-mono text-[#5E5753] tabular-nums shrink-0">
                        {m.personCount} linked
                      </span>
                    </div>

                    {m.aka.length > 0 && (
                      <div className="text-xs text-[#6E6560]">
                        Variants: {m.aka.join(', ')}
                      </div>
                    )}

                    <div className="flex flex-wrap items-center gap-1.5 pt-1">
                      {m.isCrossGotra && (
                        <span className="px-2 py-0.5 rounded-md bg-[#C42426] text-white text-[10px] font-semibold uppercase tracking-wider">
                          Cross-Gotra
                        </span>
                      )}
                      {m.gotras.map((g) => (
                        <button
                          key={g.id}
                          type="button"
                          onClick={() => onFilterSearch({ gotra: g.name_roman })}
                          className="px-2 py-0.5 rounded-md bg-white border border-[#E0D2CE] hover:border-[#C42426] text-xs text-[#171514]"
                        >
                          {g.name_roman}
                        </button>
                      ))}
                    </div>
                  </div>

                  <div className="flex items-center justify-between pt-2 border-t border-[#E7DCD8]/70">
                    <span className="text-[11px] font-mono text-[#6E6560]">{m.id}</span>
                    <button
                      type="button"
                      onClick={() => onFilterSearch({ mool: m.name_roman })}
                      className="text-xs font-medium text-[#C42426] hover:underline"
                    >
                      Search matching records →
                    </button>
                  </div>
                </div>
              ))}
            </div>

            {filteredMools.length === 0 && (
              <p className="text-sm text-[#5E5753] text-center py-6">
                No mools match the current filter combination.
              </p>
            )}
          </>
        )}
      </div>
    </section>
  );
}
