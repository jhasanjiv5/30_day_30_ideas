import { useMemo, useState } from 'react';
import { ArrowRight, Clock, History, Trash2 } from 'lucide-react';
import type {
  AuthSession,
  ProjectHistoryAction,
  ProjectHistoryEntry,
  UserRecentPocSummary,
} from '../types/domain.ts';
import { GoogleCloudLogo, MicrosoftProjectMark } from './BrandVisuals.tsx';

interface HistoryViewProps {
  session: AuthSession;
  history: ProjectHistoryEntry[];
  recentPocs: UserRecentPocSummary[];
  onReopenPoc: (
    pocId: string,
    tab?: 'architecture' | 'scorecard' | 'whatif' | 'signoff' | 'console'
  ) => void;
  onClearHistory: () => Promise<void>;
}

const ACTION_LABELS: Record<ProjectHistoryAction, string> = {
  viewed: 'Viewed',
  created_poc: 'Created POC',
  ran_whatif: 'What-If Run',
  signed_off: 'Signed Off',
  commented: 'Commented',
  drafted_mapping: 'Drafted Mapping',
  approved_mapping: 'Approved Mapping',
  rechecked: 'Live Re-Check',
  exported_pdf: 'Exported PDF',
  created_invite: 'Minted Invite',
};

function normalizeTab(
  tab?: string
): 'architecture' | 'scorecard' | 'whatif' | 'signoff' | 'console' {
  if (
    tab === 'architecture' ||
    tab === 'scorecard' ||
    tab === 'whatif' ||
    tab === 'signoff' ||
    tab === 'console'
  ) {
    return tab;
  }
  return 'scorecard';
}

export function HistoryView({
  session,
  history,
  recentPocs,
  onReopenPoc,
  onClearHistory,
}: HistoryViewProps) {
  const [pocFilter, setPocFilter] = useState<string>('all');
  const [clearing, setClearing] = useState(false);

  const filteredHistory = useMemo(() => {
    if (pocFilter === 'all') return history;
    return history.filter((item) => item.poc_id === pocFilter);
  }, [history, pocFilter]);

  const handleClear = async () => {
    setClearing(true);
    try {
      await onClearHistory();
    } finally {
      setClearing(false);
    }
  };

  return (
    <section aria-labelledby="history-heading" className="space-y-5">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1
            id="history-heading"
            className="text-2xl font-bold tracking-tight text-[#242424] sm:text-3xl"
          >
            My Project History
          </h1>
          <p className="mt-1 max-w-2xl text-sm text-[#605E5C]">
            Personal activity log for{' '}
            <strong className="font-semibold text-[#242424]">{session.user_name}</strong> (
            <span className="font-mono text-xs">{session.user_email}</span>). Only your own
            reviewed projects, simulations, and approvals appear here.
          </p>
        </div>

        {history.length > 0 && (
          <button
            type="button"
            disabled={clearing}
            onClick={handleClear}
            className="inline-flex min-h-[38px] items-center gap-1.5 self-start rounded border border-[#8A8886] bg-white px-3.5 py-1.5 text-xs font-medium text-[#242424] hover:bg-[#F3F2F1] disabled:opacity-50 whitespace-nowrap shrink-0"
          >
            <Trash2 className="h-3.5 w-3.5 text-[#605E5C]" aria-hidden="true" />
            <span>{clearing ? 'Clearing...' : 'Clear My History'}</span>
          </button>
        )}
      </div>

      {/* Recently Accessed Projects Cards */}
      <div className="ms-card overflow-hidden">
        <div className="flex items-center justify-between border-b border-[#E1DFDD] bg-[#F3F2F1] px-5 py-2.5 text-xs font-semibold text-[#242424]">
          <span className="flex items-center gap-2">
            <MicrosoftProjectMark className="h-4 w-4" />
            <span>Recently Reviewed Projects ({recentPocs.length})</span>
          </span>
        </div>

        {recentPocs.length === 0 ? (
          <div className="p-6 text-sm text-[#605E5C]">
            No projects recorded under your account yet. Open a POC scorecard, run a What-If
            simulation, or record a sign-off to start your timeline.
          </div>
        ) : (
          <div className="grid grid-cols-1 divide-y divide-[#EDEBE9] md:grid-cols-3 md:divide-x md:divide-y-0">
            {recentPocs.slice(0, 6).map((item) => (
              <div key={item.poc_id} className="flex flex-col justify-between p-4 space-y-3">
                <div className="space-y-1">
                  <div className="flex items-center gap-2">
                    <GoogleCloudLogo className="h-4 w-4 shrink-0" />
                    <h2 className="truncate text-sm font-semibold text-[#242424]">
                      {item.poc_name}
                    </h2>
                  </div>
                  <div className="flex flex-wrap items-center gap-x-2 text-xs text-[#605E5C] tabular-nums">
                    <span>{ACTION_LABELS[item.last_action] || item.last_action}</span>
                    <span aria-hidden="true">·</span>
                    <span>{item.interaction_count} action(s)</span>
                  </div>
                  <div className="flex items-center gap-1 text-[11px] text-[#605E5C] tabular-nums">
                    <Clock className="h-3 w-3" aria-hidden="true" />
                    <span>{item.last_accessed_at.slice(0, 16).replace('T', ' ')} UTC</span>
                  </div>
                </div>

                <button
                  type="button"
                  onClick={() => onReopenPoc(item.poc_id, normalizeTab(item.last_tab))}
                  className="inline-flex min-h-[34px] items-center justify-center gap-1.5 rounded border border-[#8A8886] bg-white px-3 py-1 text-xs font-semibold text-[#242424] hover:bg-[#EFF6F1] hover:border-[#107C41] hover:text-[#0E6B38]"
                >
                  <span>Reopen Project</span>
                  <ArrowRight className="h-3.5 w-3.5" aria-hidden="true" />
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Filter + Full Activity Timeline */}
      <div className="ms-card overflow-hidden">
        <div className="flex flex-col gap-2 border-b border-[#E1DFDD] bg-[#F3F2F1] px-5 py-2.5 sm:flex-row sm:items-center sm:justify-between">
          <span className="flex items-center gap-2 text-xs font-semibold text-[#242424]">
            <History className="h-4 w-4 text-[#107C41]" aria-hidden="true" />
            <span>Personal Activity Log ({filteredHistory.length})</span>
          </span>

          {recentPocs.length > 1 && (
            <select
              value={pocFilter}
              onChange={(e) => setPocFilter(e.target.value)}
              aria-label="Filter history by project"
              className="min-h-[32px] rounded border border-[#8A8886] bg-white px-2.5 text-xs text-[#242424]"
            >
              <option value="all">All Projects</option>
              {recentPocs.map((rp) => (
                <option key={rp.poc_id} value={rp.poc_id}>
                  {rp.poc_name}
                </option>
              ))}
            </select>
          )}
        </div>

        {filteredHistory.length === 0 ? (
          <div className="p-8 text-center text-sm text-[#605E5C]">
            No activity recorded yet for this filter.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-[#E1DFDD] bg-[#FAF9F8] text-[#605E5C]">
                <tr>
                  <th className="py-2.5 pl-5 pr-4 font-semibold">Timestamp (UTC)</th>
                  <th className="py-2.5 pr-4 font-semibold">Project</th>
                  <th className="py-2.5 pr-4 font-semibold">Action</th>
                  <th className="py-2.5 pr-4 font-semibold">Summary</th>
                  <th className="py-2.5 pr-5 font-semibold text-right">Open</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[#EDEBE9] tabular-nums">
                {filteredHistory.map((entry) => (
                  <tr key={entry.id} className="hover:bg-[#FAF9F8]">
                    <td className="py-3 pl-5 pr-4 font-mono text-[#605E5C] whitespace-nowrap">
                      {entry.timestamp.slice(0, 19).replace('T', ' ')}
                    </td>
                    <td className="py-3 pr-4 font-semibold text-[#242424] whitespace-nowrap">
                      {entry.poc_name}
                    </td>
                    <td className="py-3 pr-4 font-medium text-[#0E6B38] whitespace-nowrap">
                      {ACTION_LABELS[entry.action] || entry.action}
                    </td>
                    <td className="py-3 pr-4 text-[#323130]">{entry.summary}</td>
                    <td className="py-3 pr-5 text-right whitespace-nowrap">
                      <button
                        type="button"
                        onClick={() => onReopenPoc(entry.poc_id, normalizeTab(entry.tab))}
                        className="text-xs font-semibold text-[#0F6CBD] hover:underline"
                      >
                        Resume
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </section>
  );
}
