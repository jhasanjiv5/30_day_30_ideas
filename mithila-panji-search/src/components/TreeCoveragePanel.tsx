import React from 'react';
import { GitBranch, Layers } from 'lucide-react';
import type { TreeCoveragePayload } from '../types/panji.ts';
import { MadhubaniBorderStrip } from './MadhubaniMotifs.tsx';

interface TreeCoveragePanelProps {
  onOpenLineage: (personId: string) => void;
  onNeo4jError?: (msg: string) => void;
}

export function TreeCoveragePanel({
  onOpenLineage,
  onNeo4jError,
}: TreeCoveragePanelProps) {
  const [data, setData] = React.useState<TreeCoveragePayload | null>(null);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  React.useEffect(() => {
    let active = true;
    (async () => {
      setLoading(true);
      setError(null);
      try {
        const res = await fetch('/api/neo4j/coverage?limit=24', { cache: 'no-store' });
        if (res.status === 503) {
          onNeo4jError?.('Genealogy archive is temporarily unavailable. Please try again in a moment.');
          return;
        }
        if (!res.ok) {
          throw new Error('Could not load family tree overview.');
        }
        const payload = (await res.json()) as TreeCoveragePayload;
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

  return (
    <section
      aria-label="Documented Family Tree Coverage"
      className="relative overflow-hidden rounded-3xl bg-white border border-[#E7DCD8] shadow-[0_14px_40px_rgba(23,21,20,0.06)]"
    >
      <MadhubaniBorderStrip />

      <div className="p-5 sm:p-8 space-y-6">
        <div>
          <h2 className="font-serif text-2xl sm:text-3xl font-semibold text-[#171514]">
            Documented Family Tree Coverage
          </h2>
          <p className="text-sm text-[#5E5753] mt-1">
            Earliest recorded ancestors in the archive ranked by total documented descendants and
            generation depth.
          </p>
        </div>

        {loading && (
          <div className="py-10 text-center text-sm text-[#5E5753]">
            Loading documented family trees…
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
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
              <div className="rounded-2xl bg-[#FBF9F6] border border-[#E7DCD8] p-4">
                <div className="font-mono text-2xl font-medium text-[#C42426] tabular-nums">
                  {data.totalRootsWithDescendants}
                </div>
                <div className="text-xs text-[#5E5753] mt-1">
                  Documented root ancestors with descendants
                </div>
              </div>
              <div className="rounded-2xl bg-[#FBF9F6] border border-[#E7DCD8] p-4">
                <div className="font-mono text-2xl font-medium text-[#171514] tabular-nums">
                  {data.totalConnectedPersons}
                </div>
                <div className="text-xs text-[#5E5753] mt-1">
                  Persons participating in lineage edges
                </div>
              </div>
              <div className="rounded-2xl bg-[#FBF9F6] border border-[#E7DCD8] p-4">
                <div className="font-mono text-2xl font-medium text-[#171514] tabular-nums">
                  {data.trees[0]?.maxDepth ?? 0} gens
                </div>
                <div className="text-xs text-[#5E5753] mt-1">
                  Deepest documented downward tree
                </div>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              {data.trees.map((item) => (
                <button
                  key={item.root.id}
                  type="button"
                  onClick={() => onOpenLineage(item.root.id)}
                  className="text-left rounded-2xl bg-[#FBF9F6] hover:bg-[#FDF3F2] border border-[#E7DCD8] hover:border-[#C42426]/60 p-4 transition-colors space-y-2"
                >
                  <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0">
                      <div className="font-serif text-lg font-semibold text-[#171514] truncate">
                        {item.root.label}
                        {item.root.name_dev && (
                          <span className="ml-2 font-devanagari text-sm font-normal text-[#5E5753]">
                            {item.root.name_dev}
                          </span>
                        )}
                      </div>
                      <div className="text-xs text-[#5E5753] truncate">
                        {item.root.village_roman || item.root.village_dev || 'Village unrecorded'}
                        {item.root.inferredGotras.length > 0
                          ? ` · Inferred gotra: ${item.root.inferredGotras
                              .map((g) => g.name_roman)
                              .join(', ')}`
                          : ''}
                      </div>
                    </div>
                    <span className="text-xs font-medium text-[#C42426] shrink-0">
                      Open tree →
                    </span>
                  </div>

                  <div className="flex flex-wrap items-center gap-3 text-xs font-mono text-[#5E5753] pt-1">
                    <span className="inline-flex items-center gap-1 tabular-nums">
                      <GitBranch className="w-3.5 h-3.5 text-[#C42426]" aria-hidden="true" />
                      {item.descendantCount} descendant{item.descendantCount === 1 ? '' : 's'}
                    </span>
                    <span className="inline-flex items-center gap-1 tabular-nums">
                      <Layers className="w-3.5 h-3.5 text-[#5E5753]" aria-hidden="true" />
                      {item.maxDepth} generation{item.maxDepth === 1 ? '' : 's'} deep
                    </span>
                    <span className="text-[11px] opacity-75">{item.root.id}</span>
                  </div>
                </button>
              ))}
            </div>
          </>
        )}
      </div>
    </section>
  );
}
