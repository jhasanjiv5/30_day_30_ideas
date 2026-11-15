import React from 'react';
import { ArrowRight, GitCompareArrows, Search, Sparkles, Users } from 'lucide-react';
import type {
  PersonRecord,
  RelationshipPathPayload,
  SearchCandidate,
  SearchResponse,
} from '../types/panji.ts';
import { MadhubaniBorderStrip } from './MadhubaniMotifs.tsx';

interface PersonPickerProps {
  id: string;
  label: string;
  selected: PersonRecord | null;
  onSelect: (person: PersonRecord | null) => void;
  placeholder: string;
  onNeo4jError?: (msg: string) => void;
}

function PersonPicker({
  id,
  label,
  selected,
  onSelect,
  placeholder,
  onNeo4jError,
}: PersonPickerProps) {
  const [term, setTerm] = React.useState('');
  const [matches, setMatches] = React.useState<SearchCandidate[]>([]);
  const [loading, setLoading] = React.useState(false);

  React.useEffect(() => {
    const q = term.trim();
    if (!q) {
      setMatches([]);
      return;
    }
    const timer = window.setTimeout(async () => {
      setLoading(true);
      try {
        const res = await fetch(
          `/api/search?q=${encodeURIComponent(q)}&useAi=false&limit=8`,
          { cache: 'no-store' }
        );
        if (res.status === 503) {
          onNeo4jError?.('Genealogy archive is temporarily unavailable. Please try again in a moment.');
          setMatches([]);
          return;
        }
        if (res.ok) {
          const data = (await res.json()) as SearchResponse;
          setMatches(data.candidates);
        }
      } catch {
        setMatches([]);
      } finally {
        setLoading(false);
      }
    }, 200);
    return () => window.clearTimeout(timer);
  }, [term, onNeo4jError]);

  return (
    <div className="space-y-2">
      <label htmlFor={id} className="block text-xs font-semibold uppercase tracking-wider text-[#5E5753]">
        {label}
      </label>

      {selected ? (
        <div className="rounded-2xl bg-[#FDF3F2] border border-[#DFB7B5] p-3.5 flex items-start justify-between gap-3">
          <div className="min-w-0">
            <div className="font-serif text-lg font-semibold text-[#171514] leading-snug">
              {selected.name_roman || selected.label}
              {selected.name_dev && (
                <span className="ml-2 font-devanagari text-sm font-normal text-[#5E5753]">
                  {selected.name_dev}
                </span>
              )}
            </div>
            <div className="text-xs text-[#5E5753] mt-0.5 flex flex-wrap gap-x-2">
              {selected.village_roman && <span>{selected.village_roman}</span>}
              <span className="font-mono text-[11px]">{selected.id}</span>
            </div>
          </div>
          <button
            type="button"
            onClick={() => {
              onSelect(null);
              setTerm('');
              setMatches([]);
            }}
            className="text-xs font-medium text-[#C42426] hover:underline shrink-0"
          >
            Change
          </button>
        </div>
      ) : (
        <div className="space-y-2">
          <div className="relative">
            <Search
              className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-[#6E6560]"
              aria-hidden="true"
            />
            <input
              id={id}
              type="text"
              value={term}
              onChange={(e) => setTerm(e.target.value)}
              placeholder={placeholder}
              autoComplete="off"
              className="w-full h-11 pl-10 pr-3 rounded-xl bg-[#FBF9F6] border border-[#E0D2CE] text-sm text-[#171514] placeholder:text-[#8A7F7A] focus:bg-white focus:border-[#C42426] focus:outline-none"
            />
          </div>
          {loading && <p className="text-xs text-[#6E6560]">Searching archive records…</p>}
          {!loading && matches.length > 0 && (
            <ul
              role="listbox"
              aria-label={`${label} suggestions`}
              className="max-h-52 overflow-y-auto rounded-xl border border-[#E7DCD8] bg-white divide-y divide-[#F2E9E6]"
            >
              {matches.map((c) => (
                <li key={c.person.id}>
                  <button
                    type="button"
                    onClick={() => {
                      onSelect(c.person);
                      setMatches([]);
                    }}
                    className="w-full text-left px-3.5 py-2.5 hover:bg-[#FDF3F2] transition-colors flex items-center justify-between gap-2"
                  >
                    <div className="min-w-0">
                      <div className="text-sm font-medium text-[#171514] truncate">
                        {c.person.label}
                        {c.person.name_dev ? ` · ${c.person.name_dev}` : ''}
                      </div>
                      <div className="text-xs text-[#5E5753] truncate">
                        {c.person.village_roman || 'Village unrecorded'}
                        {c.person.inferredMool ? ` · Mool: ${c.person.inferredMool.name_roman}` : ''}
                      </div>
                    </div>
                    <span className="text-[11px] font-mono text-[#6E6560] shrink-0">
                      {c.connections.parentCount +
                        c.connections.childCount +
                        c.connections.explicitSiblingCount}{' '}
                      links
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </div>
  );
}

interface RelationshipFinderProps {
  autoLoadSample?: boolean;
  onOpenLineage: (personId: string) => void;
  onNeo4jError?: (msg: string) => void;
}

export function RelationshipFinder({
  autoLoadSample = false,
  onOpenLineage,
  onNeo4jError,
}: RelationshipFinderProps) {
  const [personA, setPersonA] = React.useState<PersonRecord | null>(null);
  const [personB, setPersonB] = React.useState<PersonRecord | null>(null);
  const [result, setResult] = React.useState<RelationshipPathPayload | null>(null);
  const [loading, setLoading] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);

  const runLookup = React.useCallback(
    async (idA: string, idB: string) => {
      setLoading(true);
      setError(null);
      try {
        const res = await fetch(
          `/api/neo4j/relationship?from=${encodeURIComponent(idA)}&to=${encodeURIComponent(idB)}`,
          { cache: 'no-store' }
        );
        if (res.status === 503) {
          onNeo4jError?.('Genealogy archive is temporarily unavailable. Please try again in a moment.');
          return;
        }
        if (!res.ok) {
          throw new Error('Could not trace relationship path between these records.');
        }
        const data = (await res.json()) as RelationshipPathPayload;
        setResult(data);
      } catch (err) {
        setError((err as Error).message);
      } finally {
        setLoading(false);
      }
    },
    [onNeo4jError]
  );

  const loadSamplePair = React.useCallback(() => {
    const sampleA: PersonRecord = {
      id: '5905349aee67',
      name_dev: 'अर्जुन',
      name_roman: 'arjuna',
      label: 'arjuna',
      village_dev: 'पाली',
      village_roman: 'pālī',
      titles: '',
      source_ref: '',
      source_file: 'panji.csv',
      inferredMool: null,
      inferredGotras: [],
    };
    const sampleB: PersonRecord = {
      id: 'b14a6e6ca547',
      name_dev: 'लाखू',
      name_roman: 'lākhū',
      label: 'lākhū',
      village_dev: 'पाली',
      village_roman: 'pālī',
      titles: '',
      source_ref: '',
      source_file: 'panji.csv',
      inferredMool: null,
      inferredGotras: [],
    };
    setPersonA(sampleA);
    setPersonB(sampleB);
    runLookup(sampleA.id, sampleB.id);
  }, [runLookup]);

  React.useEffect(() => {
    if (autoLoadSample) {
      loadSamplePair();
    }
  }, [autoLoadSample, loadSamplePair]);

  return (
    <section
      aria-label="Relationship Path Finder"
      className="relative overflow-hidden rounded-3xl bg-white border border-[#E7DCD8] shadow-[0_14px_40px_rgba(23,21,20,0.06)]"
    >
      <MadhubaniBorderStrip />

      <div className="p-5 sm:p-8 space-y-6">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div>
            <h2 className="font-serif text-2xl sm:text-3xl font-semibold text-[#171514]">
              Relationship Path Finder
            </h2>
            <p className="text-sm text-[#5E5753] mt-1">
              Discover the shortest documented family connection between any two people across
              recorded parent, child, and sibling links, and check for shared ancestors.
            </p>
          </div>
          <button
            type="button"
            onClick={loadSamplePair}
            className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-[#FDF3F2] border border-[#DFB7B5] hover:border-[#C42426] text-xs font-medium text-[#8E181A] transition-colors whitespace-nowrap shrink-0 self-start"
          >
            <Sparkles className="w-3.5 h-3.5" aria-hidden="true" />
            <span>Try Arjuna ↔ Lākhū</span>
          </button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <PersonPicker
            id="rel-person-a"
            label="Person A"
            selected={personA}
            onSelect={(p) => {
              setPersonA(p);
              setResult(null);
            }}
            placeholder="Search first person (e.g., Arjuna, Bhagiratha)"
            onNeo4jError={onNeo4jError}
          />
          <PersonPicker
            id="rel-person-b"
            label="Person B"
            selected={personB}
            onSelect={(p) => {
              setPersonB(p);
              setResult(null);
            }}
            placeholder="Search second person (e.g., Lakhu, Narayana)"
            onNeo4jError={onNeo4jError}
          />
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <button
            type="button"
            disabled={!personA || !personB || loading}
            onClick={() => personA && personB && runLookup(personA.id, personB.id)}
            className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-[#C42426] hover:bg-[#A31B1D] text-white text-sm font-medium transition-colors disabled:opacity-45"
          >
            <GitCompareArrows className="w-4 h-4" aria-hidden="true" />
            <span>{loading ? 'Tracing Connection…' : 'Find Relationship Path'}</span>
          </button>

          {(personA || personB || result) && (
            <button
              type="button"
              onClick={() => {
                setPersonA(null);
                setPersonB(null);
                setResult(null);
                setError(null);
              }}
              className="text-xs font-medium text-[#5E5753] hover:text-[#C42426]"
            >
              Reset selection
            </button>
          )}
        </div>

        {error && (
          <div
            role="alert"
            className="rounded-2xl bg-[#C42426]/8 border border-[#C42426]/25 p-4 text-sm text-[#8E181A]"
          >
            {error}
          </div>
        )}

        {result && (
          <div className="rounded-2xl bg-[#FBF9F6] border border-[#E7DCD8] p-5 space-y-4">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div className="text-sm font-semibold text-[#171514]">
                {result.connected
                  ? `Connected in ${result.hops} documented hop${result.hops === 1 ? '' : 's'}`
                  : 'No documented connection found'}
              </div>
              <span className="text-xs font-mono px-2.5 py-1 rounded-md bg-white border border-[#E7DCD8] text-[#5E5753]">
                Documented path (up to 15 steps)
              </span>
            </div>

            <p className="text-sm text-[#433E3B] leading-relaxed">{result.summaryNote}</p>

            {result.steps.length > 0 && (
              <ol className="space-y-2.5">
                {result.steps.map((step, idx) => (
                  <li
                    key={`${step.from.id}-${step.to.id}-${idx}`}
                    className="rounded-xl bg-white border border-[#E7DCD8] p-3.5 flex flex-col sm:flex-row sm:items-center justify-between gap-2"
                  >
                    <div className="flex flex-wrap items-center gap-2 text-sm">
                      <span className="font-mono text-xs text-[#6E6560] w-5 tabular-nums">
                        {idx + 1}.
                      </span>
                      <button
                        type="button"
                        onClick={() => onOpenLineage(step.from.id)}
                        className="font-semibold text-[#171514] hover:text-[#C42426] underline decoration-[#DFC5C2]"
                      >
                        {step.from.label}
                      </button>
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md bg-[#FDF3F2] border border-[#DFB7B5] text-[11px] font-mono text-[#8E181A]">
                        {step.direction === 'parent'
                          ? 'child of'
                          : step.direction === 'child'
                            ? 'parent of'
                            : 'sibling of'}
                        <ArrowRight className="w-3 h-3" aria-hidden="true" />
                      </span>
                      <button
                        type="button"
                        onClick={() => onOpenLineage(step.to.id)}
                        className="font-semibold text-[#171514] hover:text-[#C42426] underline decoration-[#DFC5C2]"
                      >
                        {step.to.label}
                      </button>
                    </div>
                    <div className="text-xs text-[#5E5753]">
                      {step.edgeType === 'CHILD_OF' ? 'Parent–child record' : 'Sibling record'}
                    </div>
                  </li>
                ))}
              </ol>
            )}

            {result.commonAncestors.length > 0 && (
              <div className="pt-2 border-t border-[#E7DCD8]">
                <div className="inline-flex items-center gap-1.5 text-xs font-semibold uppercase tracking-wider text-[#5E5753] mb-2">
                  <Users className="w-3.5 h-3.5" aria-hidden="true" />
                  <span>Common Documented Ancestor(s)</span>
                </div>
                <div className="flex flex-wrap gap-2">
                  {result.commonAncestors.map((anc) => (
                    <button
                      key={anc.id}
                      type="button"
                      onClick={() => onOpenLineage(anc.id)}
                      className="px-3 py-1.5 rounded-lg bg-white border border-[#E7DCD8] hover:border-[#C42426] text-xs font-medium text-[#171514]"
                    >
                      {anc.label}
                      {anc.name_dev ? ` (${anc.name_dev})` : ''}
                    </button>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}
      </div>
    </section>
  );
}
