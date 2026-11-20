import { useMemo, useState } from 'react';
import { ChevronDown, ChevronUp, FileSearch, Search } from 'lucide-react';
import type { CheckResult, CheckStatus, POC } from '../types/domain.ts';
import { CheckStatusLabel, MeasurementKindLabel } from './StatusIndicator.tsx';

interface ScorecardViewProps {
  poc: POC;
}

export function ScorecardView({ poc }: ScorecardViewProps) {
  const [filter, setFilter] = useState<'all' | CheckStatus>('all');
  const [query, setQuery] = useState('');
  const [expandedEvidenceId, setExpandedEvidenceId] = useState<string | null>(null);

  const inScopeReqs = poc.requirements.filter((r) => r.in_scope && r.approved_by_engineer);
  const outOfScopeReqs = poc.requirements.filter((r) => !r.in_scope && r.approved_by_engineer);

  const rows = useMemo(() => {
    return inScopeReqs
      .map((req) => ({
        req,
        check: poc.checks.find((c) => c.requirement_id === req.id),
      }))
      .filter(({ req, check }) => {
        if (filter !== 'all' && check?.status !== filter) return false;
        if (query.trim()) {
          const q = query.toLowerCase();
          return (
            req.title.toLowerCase().includes(q) ||
            req.category.toLowerCase().includes(q) ||
            req.id.toLowerCase().includes(q)
          );
        }
        return true;
      });
  }, [inScopeReqs, poc.checks, filter, query]);

  const counts = useMemo(() => {
    let pass = 0;
    let warn = 0;
    let fail = 0;
    for (const c of poc.checks) {
      if (c.status === 'pass') pass++;
      else if (c.status === 'warn') warn++;
      else fail++;
    }
    return { pass, warn, fail };
  }, [poc.checks]);

  return (
    <section aria-labelledby="scorecard-heading" className="space-y-5">
      <div>
        <h1
          id="scorecard-heading"
          className="text-2xl font-bold tracking-tight text-[#242424] sm:text-3xl"
        >
          Requirements Scorecard
        </h1>
        <p className="mt-1 max-w-2xl text-sm text-[#605E5C]">
          Deliverable tracking sheet mapping approved business requirements to live environment
          checks with direct evidence and explicit measured or projected labels.
        </p>
      </div>

      {/* Fluent Summary Strip */}
      <div className="ms-card grid grid-cols-2 divide-y divide-[#EDEBE9] sm:grid-cols-4 sm:divide-x sm:divide-y-0">
        <div className="p-4">
          <div className="text-xs font-medium text-[#605E5C]">Passing</div>
          <div className="mt-1 font-mono text-2xl font-semibold text-[#107C10] tabular-nums">
            {counts.pass}
          </div>
        </div>
        <div className="p-4">
          <div className="text-xs font-medium text-[#605E5C]">Needs Attention</div>
          <div className="mt-1 font-mono text-2xl font-semibold text-[#A45B00] tabular-nums">
            {counts.warn}
          </div>
        </div>
        <div className="p-4">
          <div className="text-xs font-medium text-[#605E5C]">Failing</div>
          <div className="mt-1 font-mono text-2xl font-semibold text-[#C50F1F] tabular-nums">
            {counts.fail}
          </div>
        </div>
        <div className="p-4">
          <div className="text-xs font-medium text-[#605E5C]">Out of Scope</div>
          <div className="mt-1 font-mono text-2xl font-semibold text-[#323130] tabular-nums">
            {outOfScopeReqs.length}
          </div>
        </div>
      </div>

      {/* Fluent Pivot Filter & Search Bar */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div
          role="group"
          aria-label="Filter requirements by status"
          className="flex flex-wrap items-center gap-0.5 rounded border border-[#E1DFDD] bg-[#F3F2F1] p-0.5"
        >
          {(
            [
              { id: 'all', label: 'All' },
              { id: 'pass', label: 'Passing' },
              { id: 'warn', label: 'Attention' },
              { id: 'fail', label: 'Failing' },
            ] as const
          ).map((tab) => (
            <button
              key={tab.id}
              type="button"
              onClick={() => setFilter(tab.id)}
              className={`min-h-[34px] rounded-xs px-3 py-1 text-xs font-medium transition-colors whitespace-nowrap shrink-0 ${
                filter === tab.id
                  ? 'bg-white font-semibold text-[#0E6B38] shadow-xs'
                  : 'text-[#605E5C] hover:text-[#242424]'
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>

        <div className="relative w-full sm:w-72">
          <Search
            className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[#605E5C]"
            aria-hidden="true"
          />
          <label htmlFor="scorecard-search" className="sr-only">
            Search requirements
          </label>
          <input
            id="scorecard-search"
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Filter by requirement or category"
            className="min-h-[38px] w-full rounded border border-[#8A8886] bg-white pl-9 pr-3 text-sm text-[#242424] placeholder:text-[#605E5C]"
          />
        </div>
      </div>

      {/* Microsoft Project Task Grid */}
      <div className="ms-card overflow-hidden">
        <div className="hidden md:grid md:grid-cols-12 md:gap-4 border-b border-[#E1DFDD] bg-[#F3F2F1] px-5 py-2.5 text-xs font-semibold text-[#605E5C]">
          <div className="col-span-7">Deliverable &amp; Status</div>
          <div className="col-span-3 text-right">Observed vs Target</div>
          <div className="col-span-2 text-right">Evidence</div>
        </div>

        <div className="divide-y divide-[#EDEBE9]">
          {rows.length === 0 ? (
            <div className="p-8 text-center text-sm text-[#605E5C]">
              No requirements match the current filter.
            </div>
          ) : (
            rows.map(({ req, check }) => {
              const isExpanded = expandedEvidenceId === req.id;
              return (
                <div key={req.id} className="p-4 transition-colors hover:bg-[#FAF9F8] sm:px-5">
                  <div className="grid grid-cols-1 gap-3 md:grid-cols-12 md:items-center">
                    <div className="md:col-span-7 min-w-0 space-y-1">
                      <div className="flex flex-wrap items-center gap-x-3 gap-y-1">
                        {check ? <CheckStatusLabel status={check.status} /> : null}
                        <span className="font-mono text-xs text-[#605E5C]">{req.id}</span>
                        <span className="text-xs text-[#605E5C]">{req.category}</span>
                        {check ? <MeasurementKindLabel kind={check.measured_or_projected} /> : null}
                      </div>

                      <h2 className="text-sm font-semibold text-[#242424] sm:text-base">
                        {req.title}
                      </h2>
                      {check ? (
                        <p className="text-xs text-[#605E5C] sm:text-sm">
                          {check.plain_explanation}
                        </p>
                      ) : null}
                    </div>

                    <div className="flex items-center justify-between gap-4 border-t border-[#EDEBE9] pt-3 md:col-span-5 md:grid md:grid-cols-5 md:border-t-0 md:pt-0">
                      <div className="md:col-span-3 md:text-right">
                        <div className="text-xs text-[#605E5C] md:hidden">Observed vs Target</div>
                        <div className="font-mono text-sm font-semibold text-[#242424] tabular-nums">
                          {check ? check.actual_display : 'Pending'}{' '}
                          <span className="font-normal text-[#605E5C]">
                            ({check ? check.threshold_display : req.threshold})
                          </span>
                        </div>
                      </div>

                      <div className="md:col-span-2 md:flex md:justify-end">
                        {check ? (
                          <button
                            type="button"
                            onClick={() =>
                              setExpandedEvidenceId(isExpanded ? null : req.id)
                            }
                            aria-expanded={isExpanded}
                            className="inline-flex min-h-[36px] items-center gap-1.5 rounded border border-[#8A8886] bg-white px-3 py-1.5 text-xs font-medium text-[#242424] hover:bg-[#F3F2F1] whitespace-nowrap shrink-0"
                          >
                            <FileSearch className="h-3.5 w-3.5 text-[#107C41]" aria-hidden="true" />
                            <span>Evidence</span>
                            {isExpanded ? (
                              <ChevronUp className="h-3.5 w-3.5" aria-hidden="true" />
                            ) : (
                              <ChevronDown className="h-3.5 w-3.5" aria-hidden="true" />
                            )}
                          </button>
                        ) : null}
                      </div>
                    </div>
                  </div>

                  {isExpanded && check ? (
                    <EvidenceDrawer check={check} />
                  ) : null}
                </div>
              );
            })
          )}
        </div>
      </div>

      {/* Explicit Out of Scope Section */}
      <div className="ms-card overflow-hidden">
        <div className="border-b border-[#EDEBE9] bg-[#F3F2F1] px-5 py-3">
          <h2 className="text-sm font-semibold text-[#242424]">
            Explicitly Out of Scope for This POC
          </h2>
          <p className="mt-0.5 text-xs text-[#605E5C]">
            Documented for scope clarity and excluded from automated pass/fail scoring during this
            preview phase.
          </p>
        </div>
        <div className="p-5">
          {outOfScopeReqs.length === 0 ? (
            <p className="text-sm text-[#605E5C]">No out-of-scope items listed.</p>
          ) : (
            <ul className="divide-y divide-[#EDEBE9]">
              {outOfScopeReqs.map((req) => (
                <li
                  key={req.id}
                  className="flex flex-col gap-1 py-2.5 sm:flex-row sm:items-center sm:justify-between"
                >
                  <div className="text-sm text-[#242424]">
                    <span className="mr-2 font-mono text-xs text-[#605E5C]">{req.id}</span>
                    <span>{req.title}</span>
                  </div>
                  <div className="text-xs text-[#605E5C]">
                    {req.category} · Target deferred ({req.threshold})
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </section>
  );
}

function EvidenceDrawer({ check }: { check: CheckResult }) {
  const ev = check.evidence;
  return (
    <div className="mt-4 rounded border border-[#E1DFDD] bg-[#FAF9F8] p-4 text-xs text-[#323130] space-y-2">
      <div className="grid grid-cols-1 gap-2 sm:grid-cols-3">
        <div>
          <span className="font-semibold text-[#242424]">Source API:</span> {ev.source_api}
        </div>
        <div>
          <span className="font-semibold text-[#242424]">Component:</span> {ev.resource_label} (
          <span className="font-mono">{ev.resource_id}</span>)
        </div>
        <div>
          <span className="font-semibold text-[#242424]">Observed:</span>{' '}
          <span className="font-mono tabular-nums">
            {ev.observed_at.slice(0, 19).replace('T', ' ')} UTC
          </span>
        </div>
      </div>
      {ev.policy_line ? (
        <div>
          <span className="font-semibold text-[#242424]">Policy line:</span>{' '}
          <code className="rounded border border-[#EDEBE9] bg-white px-1.5 py-0.5 font-mono text-[#242424]">
            {ev.policy_line}
          </code>
        </div>
      ) : null}
      <div>
        <span className="font-semibold text-[#242424]">Evidence payload:</span>
        <pre className="mt-1 overflow-x-auto rounded border border-[#E1DFDD] bg-white p-2.5 font-mono text-[11px] leading-relaxed text-[#242424]">
          {ev.raw_excerpt}
        </pre>
      </div>
    </div>
  );
}
