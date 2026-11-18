import React, { useState } from 'react';
import { ChevronDown, ChevronRight, ArrowDownRight } from 'lucide-react';
import { AutopsyResult, DatasetMode, RankedSlot, RetrieverSource } from '../engine/types';

interface RecommendationsPanelProps {
  autopsy: AutopsyResult;
  dataset: DatasetMode;
  efSearch: number;
  selectedSlotItemId: string | null;
  onSelectItem: (itemId: string) => void;
  onSetRanker: (ranker: 'ipw' | 'naive') => void;
}

const SOURCE_META: Record<
  RetrieverSource,
  { label: string; colorClass: string; dotColor: string }
> = {
  dense: {
    label: 'Dense',
    colorClass: 'bg-blue-50 text-blue-800 border-blue-200',
    dotColor: '#2563EB',
  },
  bm25: {
    label: 'BM25',
    colorClass: 'bg-amber-50 text-amber-800 border-amber-200',
    dotColor: '#D97706',
  },
  covisit: {
    label: 'Co-visit',
    colorClass: 'bg-emerald-50 text-emerald-800 border-emerald-200',
    dotColor: '#059669',
  },
  trending: {
    label: 'Trending',
    colorClass: 'bg-slate-100 text-slate-700 border-slate-200',
    dotColor: '#475569',
  },
};

export const RecommendationsPanel: React.FC<RecommendationsPanelProps> = ({
  autopsy,
  dataset,
  efSearch,
  selectedSlotItemId,
  onSelectItem,
  onSetRanker,
}) => {
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const slots: RankedSlot[] =
    autopsy.activeRanker === 'ipw' ? autopsy.ipwSlots : autopsy.naiveSlots;

  const toggleExpand = (id: string) => {
    setExpandedId((prev) => (prev === id ? null : id));
    onSelectItem(id);
  };

  return (
    <section
      id="recommendations"
      className="bg-white border border-slate-200 rounded-lg overflow-hidden"
    >
      {/* Header Row */}
      <div className="px-5 py-4 border-b border-slate-200 flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-base font-semibold text-slate-900 tracking-tight">
            01. Recommendations &amp; Retriever Provenance
          </h2>
          <p className="text-xs text-slate-500 mt-0.5 tabular-nums">
            {autopsy.totalCandidatesBeforeRrf} source candidates fused via RRF into{' '}
            {autopsy.uniqueRrfCandidates} unique items · Top 10 after MMR diversity re-rank
          </p>
        </div>

        {/* Ranker Switcher */}
        <div className="flex items-center gap-3">
          <div className="inline-flex items-center bg-slate-100 p-0.5 rounded-md border border-slate-200">
            <button
              type="button"
              onClick={() => onSetRanker('ipw')}
              className={`px-3 py-1.5 text-xs font-medium rounded whitespace-nowrap shrink-0 transition-colors ${
                autopsy.activeRanker === 'ipw'
                  ? 'bg-white text-slate-900 shadow-xs'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              IPW Debiased (NDCG {autopsy.ndcgAt10Ipw.toFixed(3)})
            </button>
            <button
              type="button"
              onClick={() => onSetRanker('naive')}
              className={`px-3 py-1.5 text-xs font-medium rounded whitespace-nowrap shrink-0 transition-colors ${
                autopsy.activeRanker === 'naive'
                  ? 'bg-white text-slate-900 shadow-xs'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              Naive Ranker (NDCG {autopsy.ndcgAt10Naive.toFixed(3)})
            </button>
          </div>
        </div>
      </div>

      {/* Sub-header Bar: Gate & Provenance Legend */}
      <div className="px-5 py-2.5 bg-slate-50/70 border-b border-slate-200 flex flex-wrap items-center justify-between gap-4 text-xs">
        <div className="flex flex-wrap items-center gap-4">
          <span className="text-slate-600 font-medium">Sources:</span>
          {(['dense', 'bm25', 'covisit', 'trending'] as RetrieverSource[]).map(
            (src) => (
              <span
                key={src}
                className="inline-flex items-center gap-1.5 text-slate-700 font-medium"
              >
                <span
                  className="w-2 h-2 rounded-[2px] inline-block shrink-0"
                  style={{ backgroundColor: SOURCE_META[src].dotColor }}
                />
                <span>{SOURCE_META[src].label}</span>
              </span>
            )
          )}
        </div>

        <div className="flex items-center gap-3 text-slate-600 font-mono tabular-nums">
          <span>
            Gate g = <strong className="text-slate-900">{autopsy.gateG.toFixed(2)}</strong>
          </span>
          <span aria-hidden="true" className="text-slate-300">
            /
          </span>
          <span>
            Long-term{' '}
            <strong className="text-slate-900">
              {Math.round((1 - autopsy.gateG) * 100)}%
            </strong>
          </span>
          <span aria-hidden="true" className="text-slate-300">
            ·
          </span>
          <span>
            Session{' '}
            <strong className="text-blue-700">
              {Math.round(autopsy.gateG * 100)}%
            </strong>
          </span>
        </div>
      </div>

      {/* Dropped Items Alert if ef_search < 512 displaced any exact top-10 items */}
      {autopsy.droppedVsMaxEf.length > 0 && (
        <div className="px-5 py-2.5 bg-amber-50/70 border-b border-amber-200 flex items-start gap-2 text-xs text-amber-900">
          <ArrowDownRight className="w-4 h-4 text-amber-700 shrink-0 mt-0.5" />
          <div>
            <span className="font-semibold tabular-nums">
              HNSW approximation diff at ef_search = {efSearch}:
            </span>{' '}
            <span>
              {autopsy.droppedVsMaxEf.length}{' '}
              {autopsy.droppedVsMaxEf.length === 1 ? 'item' : 'items'} fell out of the
              top 10 compared to ef_search = 512:{' '}
              <span className="font-medium">
                {autopsy.droppedVsMaxEf.map((i) => i.title).join(', ')}
              </span>
              .
            </span>
          </div>
        </div>
      )}

      {/* Ranked Table */}
      <div className="divide-y divide-slate-100">
        {slots.map((slot) => {
          const isExpanded = expandedId === slot.item.id;
          const isSelected = selectedSlotItemId === slot.item.id;
          const activeScore =
            autopsy.activeRanker === 'ipw' ? slot.ipwScore : slot.naiveScore;

          return (
            <div
              key={slot.item.id}
              className={`transition-colors ${
                isSelected ? 'bg-blue-50/40' : 'hover:bg-slate-50/70'
              }`}
            >
              <button
                type="button"
                onClick={() => toggleExpand(slot.item.id)}
                className="w-full text-left px-5 py-3 flex items-center gap-3.5 focus-visible:outline-2 focus-visible:outline-blue-600"
              >
                {/* Slot Index */}
                <span className="w-6 text-xs font-mono font-semibold text-slate-500 tabular-nums shrink-0">
                  #{slot.slot}
                </span>

                {/* Main Title & Unboxed Metadata */}
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2 min-w-0">
                    <span className="text-sm font-semibold text-slate-900 truncate">
                      {slot.item.title}
                    </span>
                    {slot.droppedAtCurrentEf && (
                      <span className="text-[11px] font-mono text-amber-700 shrink-0">
                        (swapped in at ef={efSearch})
                      </span>
                    )}
                  </div>
                  <div className="text-xs text-slate-500 mt-0.5 truncate">
                    <span>{slot.item.subtitle}</span>
                    <span aria-hidden="true"> · </span>
                    <span>{slot.item.tags.slice(0, 3).join(', ')}</span>
                    {dataset === 'otto' && (
                      <>
                        <span aria-hidden="true"> · </span>
                        <span className="font-mono tabular-nums text-slate-600">
                          Order CVR {(slot.item.baseConversionRate * 100).toFixed(1)}%
                        </span>
                      </>
                    )}
                  </div>
                </div>

                {/* Provenance Tokens (crisp rectangular monospace source tokens) */}
                <div className="hidden sm:flex items-center gap-1.5 shrink-0">
                  {slot.provenance.map((p) => {
                    const meta = SOURCE_META[p.source];
                    return (
                      <span
                        key={p.source}
                        className={`px-1.5 py-0.5 text-[11px] font-mono font-medium rounded-[3px] border whitespace-nowrap tabular-nums ${meta.colorClass}`}
                        title={`${meta.label} rank #${p.rank} (RRF +${p.rrfContribution.toFixed(4)})`}
                      >
                        {meta.label} #{p.rank}
                      </span>
                    );
                  })}
                </div>

                {/* Numeric Columns: Predicted vs True Relevance */}
                <div className="flex items-center gap-4 shrink-0 text-right font-mono tabular-nums">
                  <div className="w-14">
                    <div className="text-[10px] text-slate-400">Pred</div>
                    <div className="text-xs font-semibold text-slate-900">
                      {activeScore.toFixed(3)}
                    </div>
                  </div>
                  <div className="w-14">
                    <div className="text-[10px] text-slate-400">True r*</div>
                    <div className="text-xs font-semibold text-emerald-700">
                      {slot.trueRelevance.toFixed(3)}
                    </div>
                  </div>
                  {isExpanded ? (
                    <ChevronDown className="w-4 h-4 text-slate-400" />
                  ) : (
                    <ChevronRight className="w-4 h-4 text-slate-400" />
                  )}
                </div>
              </button>

              {/* Expandable Feature Attribution & Simulator Autopsy */}
              {isExpanded && (
                <div className="px-5 pb-3.5 pt-1 pl-14 bg-slate-50/50 border-t border-slate-100">
                  <div className="grid grid-cols-2 sm:grid-cols-6 gap-3 text-xs font-mono tabular-nums py-2">
                    <div>
                      <div className="text-[11px] font-sans text-slate-500">
                        Long-term affinity
                      </div>
                      <div className="font-semibold text-slate-900 mt-0.5">
                        +{slot.attribution.longTermAffinity.toFixed(3)}
                      </div>
                    </div>
                    <div>
                      <div className="text-[11px] font-sans text-slate-500">
                        Session similarity
                      </div>
                      <div className="font-semibold text-blue-700 mt-0.5">
                        +{slot.attribution.sessionSimilarity.toFixed(3)}
                      </div>
                    </div>
                    <div>
                      <div className="text-[11px] font-sans text-slate-500">
                        Popularity prior
                      </div>
                      <div className="font-semibold text-slate-800 mt-0.5">
                        +{slot.attribution.popularity.toFixed(3)}
                      </div>
                    </div>
                    <div>
                      <div className="text-[11px] font-sans text-slate-500">
                        Recency boost
                      </div>
                      <div className="font-semibold text-slate-800 mt-0.5">
                        +{slot.attribution.recency.toFixed(3)}
                      </div>
                    </div>
                    <div>
                      <div className="text-[11px] font-sans text-slate-500">
                        Position bias leak
                      </div>
                      <div
                        className={`font-semibold mt-0.5 ${
                          slot.attribution.positionBiasLeak > 0
                            ? 'text-amber-700'
                            : 'text-emerald-700'
                        }`}
                      >
                        {slot.attribution.positionBiasLeak > 0
                          ? `+${slot.attribution.positionBiasLeak.toFixed(3)}`
                          : '0.000 (IPW)'}
                      </div>
                    </div>
                    <div>
                      <div className="text-[11px] font-sans text-slate-500">
                        P(Exam) / P(Click)
                      </div>
                      <div className="font-semibold text-slate-900 mt-0.5">
                        {(slot.examinationProb * 100).toFixed(0)}% /{' '}
                        {(slot.simulatedClickProb * 100).toFixed(1)}%
                      </div>
                    </div>
                  </div>
                  {/* Mobile provenance fallback */}
                  <div className="flex sm:hidden flex-wrap items-center gap-1.5 mt-1">
                    {slot.provenance.map((p) => (
                      <span
                        key={p.source}
                        className={`px-1.5 py-0.5 text-[11px] font-mono font-medium rounded-[3px] border tabular-nums ${SOURCE_META[p.source].colorClass}`}
                      >
                        {SOURCE_META[p.source].label} #{p.rank}
                      </span>
                    ))}
                  </div>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </section>
  );
};
