import React from 'react';
import { Plus, RotateCcw, X } from 'lucide-react';
import { EF_SEARCH_SWEEP } from '../engine/pipeline';
import {
  AutopsyResult,
  DatasetMode,
  SessionEvent,
  UserProfile,
} from '../engine/types';

interface ControlSidebarProps {
  dataset: DatasetMode;
  onChangeDataset: (mode: DatasetMode) => void;
  users: UserProfile[];
  selectedUserId: string;
  onSelectUser: (userId: string) => void;
  injectableLabel: string;
  injectedCount: number;
  onSetInjectedCount: (count: number) => void;
  sessionEvents: SessionEvent[];
  onRemoveSessionEvent: (stepIndex: number) => void;
  autopsy: AutopsyResult;
  efSearch: number;
  onSelectEf: (ef: number) => void;
  eta: number;
  onChangeEta: (eta: number) => void;
  mmrLambda: number;
  onChangeMmrLambda: (lambda: number) => void;
}

export const ControlSidebar: React.FC<ControlSidebarProps> = ({
  dataset,
  onChangeDataset,
  users,
  selectedUserId,
  onSelectUser,
  injectableLabel,
  injectedCount,
  onSetInjectedCount,
  sessionEvents,
  onRemoveSessionEvent,
  autopsy,
  efSearch,
  onSelectEf,
  eta,
  onChangeEta,
  mmrLambda,
  onChangeMmrLambda,
}) => {
  const activeUser = users.find((u) => u.id === selectedUserId) ?? users[0];

  return (
    <aside className="w-full lg:w-[310px] shrink-0 space-y-4">
      {/* 1. Corpus & User Card */}
      <div className="bg-white border border-slate-200 rounded-lg p-4 space-y-4">
        <div>
          <label className="block text-xs font-semibold text-slate-700 mb-1.5">
            Dataset &amp; Conversion Funnel
          </label>
          <div className="grid grid-cols-2 gap-1 bg-slate-100 p-0.5 rounded-md border border-slate-200">
            <button
              type="button"
              onClick={() => onChangeDataset('movielens')}
              className={`px-2.5 py-1.5 text-xs font-medium rounded whitespace-nowrap shrink-0 transition-colors ${
                dataset === 'movielens'
                  ? 'bg-white text-slate-900 shadow-xs'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              MovieLens 25M
            </button>
            <button
              type="button"
              onClick={() => onChangeDataset('otto')}
              className={`px-2.5 py-1.5 text-xs font-medium rounded whitespace-nowrap shrink-0 transition-colors ${
                dataset === 'otto'
                  ? 'bg-white text-slate-900 shadow-xs'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              OTTO Funnel
            </button>
          </div>
          <p className="text-[11px] text-slate-500 mt-1.5 leading-snug">
            {dataset === 'movielens'
              ? 'Timestamped watch sessions with tag-genome text for BM25 & dense HNSW.'
              : 'E-commerce sessions with click → cart → order funnel conversion rates.'}
          </p>
        </div>

        <div className="pt-3 border-t border-slate-100">
          <label
            htmlFor="user-select"
            className="block text-xs font-semibold text-slate-700 mb-1.5"
          >
            Simulated User Profile
          </label>
          <select
            id="user-select"
            value={activeUser.id}
            onChange={(e) => onSelectUser(e.target.value)}
            className="w-full text-xs font-medium text-slate-900 bg-white border border-slate-300 rounded-md px-2.5 py-2 focus-visible:outline-2 focus-visible:outline-blue-600"
          >
            {users.map((u) => (
              <option key={u.id} value={u.id}>
                {u.label}
              </option>
            ))}
          </select>
          <p className="text-xs text-slate-600 mt-2 leading-relaxed">
            {activeUser.persona}
          </p>
          <p className="text-[11px] text-slate-500 mt-1.5 leading-snug">
            {activeUser.historySummary}
          </p>
        </div>
      </div>

      {/* 2. Session Intent Slider & Learned Gate g */}
      <div className="bg-white border border-slate-200 rounded-lg p-4 space-y-3.5">
        <div className="flex items-center justify-between gap-2">
          <label
            htmlFor="session-intent-slider"
            className="text-xs font-semibold text-slate-900"
          >
            Session {injectableLabel} Clicks
          </label>
          <span className="text-xs font-mono font-semibold text-blue-700 tabular-nums">
            {injectedCount} / 10 clicks
          </span>
        </div>

        <input
          id="session-intent-slider"
          type="range"
          min={0}
          max={10}
          step={1}
          value={injectedCount}
          onChange={(e) => onSetInjectedCount(Number(e.target.value))}
          className="w-full precision-slider"
        />

        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => onSetInjectedCount(Math.min(10, injectedCount + 1))}
            disabled={injectedCount >= 10}
            className="flex-1 inline-flex items-center justify-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-md bg-blue-700 text-white hover:bg-blue-800 disabled:opacity-40 whitespace-nowrap shrink-0 transition-colors"
          >
            <Plus className="w-3.5 h-3.5" />
            <span>Add {injectableLabel} Click</span>
          </button>
          <button
            type="button"
            onClick={() => onSetInjectedCount(0)}
            disabled={injectedCount === 0}
            className="inline-flex items-center justify-center gap-1 px-2.5 py-1.5 text-xs font-medium rounded-md border border-slate-300 text-slate-700 hover:bg-slate-50 disabled:opacity-40 whitespace-nowrap shrink-0 transition-colors"
            title="Reset injected session clicks"
          >
            <RotateCcw className="w-3.5 h-3.5" />
            <span>Reset</span>
          </button>
        </div>

        {/* Learned Gate g Meter */}
        <div className="pt-3 border-t border-slate-100 space-y-2">
          <div className="flex items-center justify-between text-xs tabular-nums">
            <span className="font-medium text-slate-700">
              Learned GRU Gate <span className="font-mono">g</span>
            </span>
            <span className="font-mono font-semibold text-slate-900">
              {autopsy.gateG.toFixed(3)}
            </span>
          </div>
          <div className="h-2 w-full bg-slate-200 rounded-xs overflow-hidden flex">
            <div
              className="h-full bg-slate-600 transition-all duration-200"
              style={{ width: `${Math.round((1 - autopsy.gateG) * 100)}%` }}
              title="Long-term two-tower weight (1 - g)"
            />
            <div
              className="h-full bg-blue-600 transition-all duration-200"
              style={{ width: `${Math.round(autopsy.gateG * 100)}%` }}
              title="Short-term session encoder weight (g)"
            />
          </div>
          <div className="flex items-center justify-between text-[11px] text-slate-500 font-mono tabular-nums">
            <span>Long-term {Math.round((1 - autopsy.gateG) * 100)}%</span>
            <span>Coherence {autopsy.sessionCoherence.toFixed(2)}</span>
            <span className="text-blue-700 font-medium">
              Session {Math.round(autopsy.gateG * 100)}%
            </span>
          </div>
        </div>

        {/* Active Session Timeline */}
        <div className="pt-3 border-t border-slate-100">
          <div className="flex items-center justify-between text-xs mb-2">
            <span className="font-semibold text-slate-700">
              Active Session Window (last 20)
            </span>
            <span className="font-mono text-[11px] text-slate-500 tabular-nums">
              {sessionEvents.length} events
            </span>
          </div>
          {sessionEvents.length === 0 ? (
            <p className="text-xs text-slate-500 py-2">
              No active clicks in session. Recommendations reflect pure long-term
              two-tower taste.
            </p>
          ) : (
            <div className="max-h-40 overflow-y-auto divide-y divide-slate-100 border border-slate-200 rounded-md">
              {[...sessionEvents].reverse().map((ev) => (
                <div
                  key={ev.stepIndex}
                  className="px-2.5 py-1.5 flex items-center justify-between gap-2 text-xs hover:bg-slate-50"
                >
                  <div className="min-w-0">
                    <div className="font-medium text-slate-800 truncate">
                      {ev.title}
                    </div>
                    <div className="text-[11px] text-slate-500 truncate">
                      <span>t={ev.stepIndex + 1}</span>
                      <span aria-hidden="true"> · </span>
                      <span>{ev.category}</span>
                      <span aria-hidden="true"> · </span>
                      <span>
                        {ev.intentType === 'injected' ? 'Injected' : 'Seed'}
                      </span>
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={() => onRemoveSessionEvent(ev.stepIndex)}
                    className="p-1 text-slate-400 hover:text-slate-700 rounded shrink-0"
                    aria-label={`Remove ${ev.title} from session`}
                  >
                    <X className="w-3.5 h-3.5" />
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* 3. Retrieval & Ranker Parameters */}
      <div className="bg-white border border-slate-200 rounded-lg p-4 space-y-4">
        <div className="text-xs font-semibold text-slate-900">
          Pipeline Parameters
        </div>

        {/* ef_search quick selector */}
        <div>
          <div className="flex items-center justify-between text-xs mb-1.5 tabular-nums">
            <span className="text-slate-700 font-medium">HNSW ef_search</span>
            <span className="font-mono font-semibold text-slate-900">
              {efSearch}
            </span>
          </div>
          <div className="grid grid-cols-6 gap-1">
            {EF_SEARCH_SWEEP.map((ef) => (
              <button
                key={ef}
                type="button"
                onClick={() => onSelectEf(ef)}
                className={`py-1 text-[11px] font-mono font-medium rounded border transition-colors tabular-nums ${
                  efSearch === ef
                    ? 'bg-slate-900 text-white border-slate-900'
                    : 'bg-white text-slate-700 border-slate-200 hover:bg-slate-50'
                }`}
              >
                {ef}
              </button>
            ))}
          </div>
        </div>

        {/* Position Bias Severity eta */}
        <div>
          <div className="flex items-center justify-between text-xs mb-1 tabular-nums">
            <label htmlFor="eta-slider" className="text-slate-700 font-medium">
              Position Bias Severity (η)
            </label>
            <span className="font-mono font-semibold text-slate-900">
              {eta.toFixed(2)}
            </span>
          </div>
          <input
            id="eta-slider"
            type="range"
            min={0.3}
            max={1.3}
            step={0.05}
            value={eta}
            onChange={(e) => onChangeEta(Number(e.target.value))}
            className="w-full precision-slider"
          />
          <div className="flex justify-between text-[10px] text-slate-400 font-mono mt-0.5">
            <span>0.30 (mild)</span>
            <span>0.85 (typical)</span>
            <span>1.30 (steep)</span>
          </div>
        </div>

        {/* MMR Diversity lambda */}
        <div>
          <div className="flex items-center justify-between text-xs mb-1 tabular-nums">
            <label htmlFor="mmr-slider" className="text-slate-700 font-medium">
              MMR Relevance vs Diversity (λ)
            </label>
            <span className="font-mono font-semibold text-slate-900">
              {mmrLambda.toFixed(2)}
            </span>
          </div>
          <input
            id="mmr-slider"
            type="range"
            min={0.45}
            max={1.0}
            step={0.05}
            value={mmrLambda}
            onChange={(e) => onChangeMmrLambda(Number(e.target.value))}
            className="w-full precision-slider"
          />
          <div className="flex justify-between text-[10px] text-slate-400 font-mono mt-0.5">
            <span>0.45 (diverse)</span>
            <span>1.00 (pure score)</span>
          </div>
        </div>
      </div>
    </aside>
  );
};
