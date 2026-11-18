import React, { useState } from 'react';
import { AutopsyResult } from '../engine/types';

interface BiasAutopsyPanelProps {
  autopsy: AutopsyResult;
  eta: number;
  selectedSlotItemId: string | null;
}

export const BiasAutopsyPanel: React.FC<BiasAutopsyPanelProps> = ({
  autopsy,
  eta,
  selectedSlotItemId,
}) => {
  const [hoveredSlot, setHoveredSlot] = useState<number | null>(null);
  const activeSlots =
    autopsy.activeRanker === 'ipw' ? autopsy.ipwSlots : autopsy.naiveSlots;

  // Compare naive vs IPW slot predictions alongside ground-truth r*
  const rows = Array.from({ length: Math.min(10, activeSlots.length) }, (_, idx) => {
    const slotNum = idx + 1;
    const ipwItem = autopsy.ipwSlots[idx];
    const naiveItem = autopsy.naiveSlots[idx];
    const examProb = Math.pow(slotNum, -eta);

    return {
      slot: slotNum,
      ipwItem,
      naiveItem,
      trueRelIpwSlate: ipwItem ? ipwItem.trueRelevance : 0,
      trueRelNaiveSlate: naiveItem ? naiveItem.trueRelevance : 0,
      ipwPred: ipwItem ? ipwItem.ipwScore : 0,
      naivePred: naiveItem ? naiveItem.naiveScore : 0,
      naiveBiasLeak: naiveItem ? naiveItem.attribution.positionBiasLeak : 0,
      examProb,
    };
  });

  // SVG grouped slot comparison chart (True Relevance vs Naive Pred vs IPW Pred)
  const width = 560;
  const height = 235;
  const pad = { top: 20, right: 20, bottom: 34, left: 42 };
  const plotW = width - pad.left - pad.right;
  const plotH = height - pad.top - pad.bottom;

  const groupW = plotW / 10;
  const barW = Math.min(10, (groupW - 10) / 3);
  const yScale = (val: number) => pad.top + (1 - val) * plotH;

  const ndcgLiftPct =
    ((autopsy.ndcgAt10Ipw - autopsy.ndcgAt10Naive) /
      Math.max(0.01, autopsy.ndcgAt10Naive)) *
    100;

  // Examination curve polyline
  const examPath = rows
    .map((r, i) => {
      const cx = pad.left + groupW * i + groupW / 2;
      const cy = yScale(r.examProb);
      return `${i === 0 ? 'M' : 'L'} ${cx.toFixed(1)} ${cy.toFixed(1)}`;
    })
    .join(' ');

  return (
    <section
      id="autopsy"
      className="bg-white border border-slate-200 rounded-lg overflow-hidden flex flex-col"
    >
      <div className="px-5 py-4 border-b border-slate-200 flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 className="text-base font-semibold text-slate-900 tracking-tight">
            03. Position Bias Autopsy (Simulator Ground Truth)
          </h2>
          <p className="text-xs text-slate-500 mt-0.5 tabular-nums">
            Propensity P(E_k=1) = k^(-{eta.toFixed(2)}) · Naive ranker mistakes top-slot exposure for relevance
          </p>
        </div>

        <div className="text-right font-mono tabular-nums">
          <div className="text-[11px] text-slate-500">NDCG@10 Debiasing Gain</div>
          <div className="text-sm font-semibold text-emerald-700">
            {ndcgLiftPct >= 0 ? '+' : ''}
            {ndcgLiftPct.toFixed(1)}% ({autopsy.ndcgAt10Naive.toFixed(3)} →{' '}
            {autopsy.ndcgAt10Ipw.toFixed(3)})
          </div>
        </div>
      </div>

      {/* Legend Bar */}
      <div className="px-5 py-2.5 bg-slate-50/70 border-b border-slate-200 flex flex-wrap items-center justify-between gap-4 text-xs">
        <div className="flex flex-wrap items-center gap-4">
          <span className="inline-flex items-center gap-1.5 text-slate-700 font-medium">
            <span className="w-2.5 h-2.5 rounded-[2px] bg-emerald-600 inline-block" />
            True Relevance r*
          </span>
          <span className="inline-flex items-center gap-1.5 text-slate-700 font-medium">
            <span className="w-2.5 h-2.5 rounded-[2px] bg-blue-600 inline-block" />
            IPW Pred
          </span>
          <span className="inline-flex items-center gap-1.5 text-slate-700 font-medium">
            <span className="w-2.5 h-2.5 rounded-[2px] bg-amber-600 inline-block" />
            Naive Pred (biased)
          </span>
          <span className="inline-flex items-center gap-1.5 text-slate-600 font-medium">
            <span className="w-4 h-0.5 border-t-2 border-dashed border-slate-500 inline-block" />
            P(Exam_k)
          </span>
        </div>
      </div>

      {/* SVG Grouped Bar + Propensity Overlay */}
      <div className="px-4 pt-3 pb-2">
        <svg
          viewBox={`0 0 ${width} ${height}`}
          className="w-full h-auto overflow-visible"
          role="img"
          aria-label="Position Bias Autopsy comparing True Relevance, IPW prediction, and Naive biased prediction across slots 1 to 10"
        >
          {[0.25, 0.5, 0.75, 1.0].map((tick) => {
            const y = yScale(tick);
            return (
              <g key={tick}>
                <line
                  x1={pad.left}
                  y1={y}
                  x2={width - pad.right}
                  y2={y}
                  stroke="#E2E8F0"
                  strokeDasharray="3 3"
                />
                <text
                  x={pad.left - 8}
                  y={y + 4}
                  textAnchor="end"
                  className="fill-slate-500 text-[10px] font-mono tabular-nums"
                >
                  {tick.toFixed(2)}
                </text>
              </g>
            );
          })}

          <line
            x1={pad.left}
            y1={height - pad.bottom}
            x2={width - pad.right}
            y2={height - pad.bottom}
            stroke="#CBD5E1"
          />

          {rows.map((r, i) => {
            const gx = pad.left + i * groupW + (groupW - barW * 3 - 4) / 2;
            const isHovered = hoveredSlot === r.slot;
            const trueVal =
              autopsy.activeRanker === 'ipw'
                ? r.trueRelIpwSlate
                : r.trueRelNaiveSlate;

            const hTrue = (height - pad.bottom) - yScale(trueVal);
            const hIpw = (height - pad.bottom) - yScale(r.ipwPred);
            const hNaive = (height - pad.bottom) - yScale(r.naivePred);

            return (
              <g
                key={r.slot}
                onMouseEnter={() => setHoveredSlot(r.slot)}
                onMouseLeave={() => setHoveredSlot(null)}
              >
                {isHovered && (
                  <rect
                    x={pad.left + i * groupW + 2}
                    y={pad.top}
                    width={groupW - 4}
                    height={plotH}
                    fill="#F1F5F9"
                    rx={3}
                  />
                )}
                {/* True Relevance */}
                <rect
                  x={gx}
                  y={yScale(trueVal)}
                  width={barW}
                  height={Math.max(1, hTrue)}
                  fill="#059669"
                  rx={1.5}
                />
                {/* IPW Prediction */}
                <rect
                  x={gx + barW + 2}
                  y={yScale(r.ipwPred)}
                  width={barW}
                  height={Math.max(1, hIpw)}
                  fill="#2563EB"
                  rx={1.5}
                />
                {/* Naive Prediction */}
                <rect
                  x={gx + (barW + 2) * 2}
                  y={yScale(r.naivePred)}
                  width={barW}
                  height={Math.max(1, hNaive)}
                  fill="#D97706"
                  rx={1.5}
                />
                <text
                  x={pad.left + i * groupW + groupW / 2}
                  y={height - pad.bottom + 14}
                  textAnchor="middle"
                  className={`text-[10px] font-mono tabular-nums ${
                    isHovered ? 'fill-slate-900 font-semibold' : 'fill-slate-500'
                  }`}
                >
                  S{r.slot}
                </text>
              </g>
            );
          })}

          {/* Examination Propensity Dashed Curve */}
          <path
            d={examPath}
            fill="none"
            stroke="#475569"
            strokeWidth={1.75}
            strokeDasharray="4 3"
          />
          {rows.map((r, i) => (
            <circle
              key={`ex-${r.slot}`}
              cx={pad.left + groupW * i + groupW / 2}
              cy={yScale(r.examProb)}
              r={2.5}
              fill="#475569"
            />
          ))}

          <text
            x={pad.left + plotW / 2}
            y={height - 4}
            textAnchor="middle"
            className="fill-slate-600 text-[11px] font-medium"
          >
            Display Slot (S1 – S10)
          </text>
        </svg>
      </div>

      {/* Compact Slot Autopsy Table */}
      <div className="border-t border-slate-200 overflow-x-auto">
        <table className="w-full text-xs text-left border-collapse">
          <thead>
            <tr className="bg-slate-50 border-b border-slate-200 text-slate-500 font-medium">
              <th className="py-2 px-4">Slot</th>
              <th className="py-2 px-2">IPW Slate Item</th>
              <th className="py-2 px-2 text-right">True r*</th>
              <th className="py-2 px-2 text-right">IPW</th>
              <th className="py-2 px-2 text-right">Naive</th>
              <th className="py-2 px-4 text-right">Pos Leak</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100 tabular-nums">
            {rows.slice(0, 6).map((r) => {
              const isHighlighted =
                hoveredSlot === r.slot ||
                (r.ipwItem && r.ipwItem.item.id === selectedSlotItemId);
              const overestimation = r.naivePred - r.trueRelNaiveSlate;

              return (
                <tr
                  key={r.slot}
                  onMouseEnter={() => setHoveredSlot(r.slot)}
                  onMouseLeave={() => setHoveredSlot(null)}
                  className={isHighlighted ? 'bg-blue-50/50' : 'hover:bg-slate-50'}
                >
                  <td className="py-1.5 px-4 font-mono text-slate-500">
                    #{r.slot}
                  </td>
                  <td className="py-1.5 px-2 text-slate-900 font-medium truncate max-w-[170px]">
                    {r.ipwItem?.item.title ?? '—'}
                  </td>
                  <td className="py-1.5 px-2 text-right font-mono text-emerald-700 font-semibold">
                    {r.trueRelIpwSlate.toFixed(3)}
                  </td>
                  <td className="py-1.5 px-2 text-right font-mono text-blue-700">
                    {r.ipwPred.toFixed(3)}
                  </td>
                  <td className="py-1.5 px-2 text-right font-mono text-amber-700">
                    {r.naivePred.toFixed(3)}
                    <span className="text-[10px] text-slate-400 ml-1">
                      ({overestimation >= 0 ? '+' : ''}
                      {overestimation.toFixed(2)})
                    </span>
                  </td>
                  <td className="py-1.5 px-4 text-right font-mono text-amber-800">
                    +{r.naiveBiasLeak.toFixed(3)}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </section>
  );
};
