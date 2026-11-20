import { useState } from 'react';
import { ArrowRight, Clock, FileCheck2, History, Plus } from 'lucide-react';
import type { POC, UserRecentPocSummary, UserRole } from '../types/domain.ts';
import type { ClientAuthHeaders } from '../utils/api.ts';
import { GoogleCloudLogo, TerraformLogo, VertexAiLogo } from './BrandVisuals.tsx';
import { CreatePocModal } from './CreatePocModal.tsx';
import { LifecycleStateLabel } from './StatusIndicator.tsx';

interface PocListViewProps {
  pocs: POC[];
  activePocId: string;
  role: UserRole;
  userName?: string;
  recentPocs?: UserRecentPocSummary[];
  auth: ClientAuthHeaders;
  onSelectPoc: (
    pocId: string,
    nextTab?: 'architecture' | 'scorecard' | 'whatif' | 'signoff' | 'console'
  ) => void;
  onPocCreated: (poc: POC) => void;
  onSwitchToEngineer?: () => void;
  onOpenHistory?: () => void;
}

export function PocListView({
  pocs,
  activePocId,
  role,
  userName,
  recentPocs = [],
  auth,
  onSelectPoc,
  onPocCreated,
  onSwitchToEngineer,
  onOpenHistory,
}: PocListViewProps) {
  const [modalOpen, setModalOpen] = useState(false);

  return (
    <section aria-labelledby="poc-list-heading" className="space-y-5">
      {/* Microsoft Project Command Header */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1
            id="poc-list-heading"
            className="text-2xl font-bold tracking-tight text-[#242424] sm:text-3xl"
          >
            Active Proof-of-Concept Reviews
          </h1>
          <p className="mt-1 max-w-2xl text-sm text-[#605E5C]">
            Select any project row to inspect its architecture map, deliverable pass rate, and
            steering sign-offs.
          </p>
        </div>

        {role === 'engineer' ? (
          <button
            type="button"
            onClick={() => setModalOpen(true)}
            className="inline-flex min-h-[40px] items-center gap-2 self-start rounded bg-[#107C41] px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-[#0C6233] whitespace-nowrap shrink-0"
          >
            <Plus className="h-4 w-4" aria-hidden="true" />
            <span>Add / Upload POC</span>
          </button>
        ) : onSwitchToEngineer ? (
          <button
            type="button"
            onClick={onSwitchToEngineer}
            className="inline-flex min-h-[40px] items-center gap-2 self-start rounded border border-[#8A8886] bg-white px-4 py-2 text-xs font-semibold text-[#242424] transition-colors hover:bg-[#F3F2F1] whitespace-nowrap shrink-0"
          >
            <Plus className="h-4 w-4 text-[#107C41]" aria-hidden="true" />
            <span>Return to Engineer View</span>
          </button>
        ) : null}
      </div>

      {/* Personal Recent Projects Strip (scoped to authenticated user) */}
      {recentPocs.length > 0 && (
        <div className="ms-card overflow-hidden">
          <div className="flex items-center justify-between border-b border-[#E1DFDD] bg-[#F3F2F1] px-4 py-2 text-xs font-semibold text-[#242424]">
            <span className="flex items-center gap-2">
              <History className="h-3.5 w-3.5 text-[#107C41]" aria-hidden="true" />
              <span>Recently Reviewed by {userName || 'You'}</span>
            </span>
            {onOpenHistory && (
              <button
                type="button"
                onClick={onOpenHistory}
                className="text-xs font-semibold text-[#0F6CBD] hover:underline"
              >
                Full History
              </button>
            )}
          </div>
          <div className="grid grid-cols-1 divide-y divide-[#EDEBE9] sm:grid-cols-3 sm:divide-x sm:divide-y-0">
            {recentPocs.slice(0, 3).map((item) => (
              <button
                key={item.poc_id}
                type="button"
                onClick={() =>
                  onSelectPoc(
                    item.poc_id,
                    item.last_tab === 'architecture' ||
                      item.last_tab === 'scorecard' ||
                      item.last_tab === 'whatif' ||
                      item.last_tab === 'signoff' ||
                      item.last_tab === 'console'
                      ? item.last_tab
                      : 'scorecard'
                  )
                }
                className="flex items-center justify-between gap-3 px-4 py-3 text-left transition-colors hover:bg-[#EFF6F1]/60"
              >
                <div className="min-w-0">
                  <div className="truncate text-xs font-semibold text-[#242424]">
                    {item.poc_name}
                  </div>
                  <div className="mt-0.5 flex items-center gap-1.5 text-[11px] text-[#605E5C] tabular-nums">
                    <Clock className="h-3 w-3 shrink-0" aria-hidden="true" />
                    <span className="truncate">
                      {item.interaction_count} action(s) · {item.last_accessed_at.slice(0, 10)}
                    </span>
                  </div>
                </div>
                <ArrowRight className="h-3.5 w-3.5 shrink-0 text-[#107C41]" aria-hidden="true" />
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Visual 3-Step Quick Guide Strip with Logos */}
      <div className="ms-card grid grid-cols-1 divide-y divide-[#EDEBE9] md:grid-cols-3 md:divide-x md:divide-y-0">
        <div className="flex items-center gap-3.5 p-4">
          <div className="flex h-10 w-12 shrink-0 items-center justify-center gap-1 rounded border border-[#E1DFDD] bg-[#FAF9F8]">
            <GoogleCloudLogo className="h-4 w-4" />
            <TerraformLogo className="h-4 w-4" />
          </div>
          <div>
            <div className="text-xs font-semibold text-[#0E6B38]">01. Upload POC (Engineer)</div>
            <p className="mt-0.5 text-xs text-[#605E5C]">
              Add <code className="font-mono">.tfstate</code> &amp; YAML scope.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-3.5 p-4">
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded border border-[#E1DFDD] bg-[#FAF9F8]">
            <VertexAiLogo className="h-5 w-5" />
          </div>
          <div>
            <div className="text-xs font-semibold text-[#0E6B38]">02. Map &amp; Approve (Console)</div>
            <p className="mt-0.5 text-xs text-[#605E5C]">
              Verify AI or manual checks before publishing.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-3.5 p-4">
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded border border-[#E1DFDD] bg-[#EFF6F1]">
            <FileCheck2 className="h-5 w-5 text-[#107C41]" aria-hidden="true" />
          </div>
          <div>
            <div className="text-xs font-semibold text-[#0E6B38]">03. Review &amp; PDF Sign-Off</div>
            <p className="mt-0.5 text-xs text-[#605E5C]">
              Inspect Scorecard, What-If &amp; export PDF.
            </p>
          </div>
        </div>
      </div>

      {/* Microsoft Project Portfolio Grid */}
      {pocs.length === 0 ? (
        <div className="ms-card p-8 text-center">
          <p className="text-sm font-medium text-[#242424]">No POC environments available</p>
          <p className="mt-1 text-sm text-[#605E5C]">
            Click &ldquo;Add / Upload POC&rdquo; above as an Engineer or verify your invite link.
          </p>
        </div>
      ) : (
        <div className="ms-card overflow-hidden">
          <div className="hidden lg:grid lg:grid-cols-12 lg:gap-4 border-b border-[#E1DFDD] bg-[#F3F2F1] px-6 py-2.5 text-xs font-semibold text-[#605E5C]">
            <div className="col-span-5">Project Name &amp; Scope Summary</div>
            <div className="col-span-2">Deliverables Passing</div>
            <div className="col-span-2">Sign-Off Progress</div>
            <div className="col-span-3 text-right">Views &amp; Actions</div>
          </div>

          <div className="divide-y divide-[#EDEBE9]">
            {pocs.map((poc) => {
              const inScopeReqs = poc.requirements.filter(
                (r) => r.in_scope && r.approved_by_engineer
              );
              const passingCount = poc.checks.filter((c) => c.status === 'pass').length;
              const passPct =
                inScopeReqs.length > 0
                  ? Math.round((passingCount / inScopeReqs.length) * 100)
                  : 0;
              const approvedSignOffs = new Set(
                poc.sign_offs
                  .filter((s) => s.decision === 'approved')
                  .map((s) => s.requirement_id)
              ).size;
              const signOffPct =
                inScopeReqs.length > 0
                  ? Math.round((approvedSignOffs / inScopeReqs.length) * 100)
                  : 0;
              const isSelected = poc.id === activePocId;

              return (
                <article
                  key={poc.id}
                  className={`p-5 transition-colors sm:px-6 ${
                    isSelected ? 'bg-[#EFF6F1]/60' : 'bg-white hover:bg-[#FAF9F8]'
                  }`}
                >
                  <div className="grid grid-cols-1 gap-4 lg:grid-cols-12 lg:items-center">
                    <div className="lg:col-span-5 min-w-0 space-y-1.5">
                      <div className="flex flex-wrap items-center gap-x-3 gap-y-1">
                        <h2 className="text-base font-semibold text-[#242424]">{poc.name}</h2>
                        <LifecycleStateLabel state={poc.environment.lifecycle_state} />
                      </div>
                      <p className="text-sm leading-relaxed text-[#605E5C]">
                        {poc.business_summary}
                      </p>
                      <div className="flex flex-wrap items-center gap-x-2 gap-y-1 pt-0.5 text-xs text-[#605E5C]">
                        <span>{poc.environment.region_display}</span>
                        <span aria-hidden="true">·</span>
                        <span className="tabular-nums">
                          Teardown in {poc.environment.days_until_teardown}d (
                          {poc.environment.teardown_date_iso})
                        </span>
                        <span aria-hidden="true">·</span>
                        <span className="tabular-nums">
                          ${poc.environment.current_spend_usd} / ${poc.environment.budget_cap_usd}{' '}
                          cap
                        </span>
                        <span aria-hidden="true">·</span>
                        <span>Owner: {poc.owner_name}</span>
                      </div>
                    </div>

                    <div className="grid grid-cols-2 gap-4 border-t border-[#EDEBE9] pt-3 lg:col-span-4 lg:border-t-0 lg:pt-0">
                      <div className="space-y-1.5">
                        <div className="text-xs text-[#605E5C] lg:hidden">Requirements passing</div>
                        <div className="font-mono text-sm font-semibold text-[#242424] tabular-nums">
                          {passPct}%{' '}
                          <span className="text-xs font-normal text-[#605E5C]">
                            ({passingCount}/{inScopeReqs.length})
                          </span>
                        </div>
                        <div
                          className="h-1.5 w-full overflow-hidden rounded-xs bg-[#EDEBE9]"
                          aria-hidden="true"
                        >
                          <div
                            className="h-full bg-[#107C41]"
                            style={{ width: `${Math.min(100, passPct)}%` }}
                          />
                        </div>
                      </div>

                      <div className="space-y-1.5">
                        <div className="text-xs text-[#605E5C] lg:hidden">Sign-off progress</div>
                        <div className="font-mono text-sm font-semibold text-[#242424] tabular-nums">
                          {approvedSignOffs}/{inScopeReqs.length}{' '}
                          <span className="text-xs font-normal text-[#605E5C]">approved</span>
                        </div>
                        <div
                          className="h-1.5 w-full overflow-hidden rounded-xs bg-[#EDEBE9]"
                          aria-hidden="true"
                        >
                          <div
                            className="h-full bg-[#0F6CBD]"
                            style={{ width: `${Math.min(100, signOffPct)}%` }}
                          />
                        </div>
                      </div>
                    </div>

                    <div className="flex flex-wrap items-center gap-2 lg:col-span-3 lg:justify-end">
                      <button
                        type="button"
                        onClick={() => onSelectPoc(poc.id, 'architecture')}
                        className="inline-flex min-h-[38px] items-center gap-1.5 rounded border border-[#8A8886] bg-white px-3 py-1.5 text-xs font-medium text-[#242424] transition-colors hover:bg-[#F3F2F1] whitespace-nowrap shrink-0"
                      >
                        <span>Architecture Map</span>
                      </button>
                      <button
                        type="button"
                        onClick={() => onSelectPoc(poc.id, 'scorecard')}
                        className="inline-flex min-h-[38px] items-center gap-1.5 rounded bg-[#107C41] px-3.5 py-1.5 text-xs font-semibold text-white transition-colors hover:bg-[#0C6233] whitespace-nowrap shrink-0"
                      >
                        <span>Review Scorecard</span>
                        <ArrowRight className="h-3.5 w-3.5" aria-hidden="true" />
                      </button>
                    </div>
                  </div>
                </article>
              );
            })}
          </div>
        </div>
      )}

      <CreatePocModal
        open={modalOpen}
        auth={auth}
        onClose={() => setModalOpen(false)}
        onCreated={(created) => {
          onPocCreated(created);
        }}
      />
    </section>
  );
}
