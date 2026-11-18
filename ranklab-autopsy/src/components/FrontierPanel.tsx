import React, { useState } from 'react';
import { AutopsyResult } from '../engine/types';

interface FrontierPanelProps {
  autopsy: AutopsyResult;
  efSearch: number;
  onSelectEf: (ef: number) => void;
}

export const FrontierPanel: React.FC<FrontierPanelProps> = ({
  autopsy,
  efSearch,
  onSelectEf,
}) => {
  const [latencyMetric, setLatencyMetric] = useState<'p50' | 'p99'>('p50');
  const { frontier, currentFrontierPoint } = autopsy;

  // SVG coordinate space
  const width = 560;
  const height = 240;
  const pad = { top: 22, right: 28, bottom: 40, left: 48 };
  const plotW = width - pad.left - pad.right;
  const plotH = height - pad.top - pad.bottom;

  const latencies = frontier.map((f) =>
    latencyMetric === 'p50' ? f.p50LatencyMs : f.p99LatencyMs
  );
  const minLat = Math.max(0, Math.min(...latencies) * 0.85);
  const maxLat = Math.max(...latencies) * 1.1;

  const minRec = Math.max(0.35, Math.min(...frontier.map((f) => f.recallAt500)) - 0.08);
  const maxRec = 1.02;

  const xScale = (lat: number) =>
    pad.left + ((lat - minLat) / Math.max(0.1, maxLat - minLat)) * plotW;
  const yScale = (rec: number) =>
    pad.top + (1 - (rec - minRec) / Math.max(0.05, maxRec - minRec)) * plotH;

  const pathD = frontier
    .map((pt, idx) => {
      const lat = latencyMetric === 'p50' ? pt.p50LatencyMs : pt.p99LatencyMs;
      const x = xScale(lat);
      const y = yScale(pt.recallAt500);
      return `${idx === 0 ? 'M' : 'L'} ${x.toFixed(1)} ${y.toFixed(1)}`;
    })
    .join(' ');

  const yTicks = [0.5, 0.7, 0.85, 1.0].filter((t) => t >= minRec);
  const xTickCount = 4;
  const xTicks = Array.from({ length: xTickCount + 1 }, (_, i) =>
    Number((minLat + ((maxLat - minLat) * i) / xTickCount).toFixed(1))
  );

  return (
    <section
      id="frontier"
      className="bg-white border border-slate-200 rounded-lg overflow-hidden flex flex-col"
    >
      <div className="px-5 py-4 border-b border-slate-200 flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 className="text-base font-semibold text-slate-900 tracking-tight">
            02. HNSW Recall–Latency Frontier
          </h2>
          <p className="text-xs text-slate-500 mt-0.5">
            Click any operating point (ef_search 16 → 512) to re-run graph search
          </p>
        </div>

        <div className="inline-flex items-center bg-slate-100 p-0.5 rounded-md border border-slate-200">
          <button
            type="button"
            onClick={() => setLatencyMetric('p50')}
            className={`px-2.5 py-1 text-xs font-medium rounded whitespace-nowrap shrink-0 transition-colors ${
              latencyMetric === 'p50'
                ? 'bg-white text-slate-900 shadow-xs'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            p50 Latency
          </button>
          <button
            type="button"
            onClick={() => setLatencyMetric('p99')}
            className={`px-2.5 py-1 text-xs font-medium rounded whitespace-nowrap shrink-0 transition-colors ${
              latencyMetric === 'p99'
                ? 'bg-white text-slate-900 shadow-xs'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            p99 Tail
          </button>
        </div>
      </div>

      {/* Interactive SVG Pareto Plot */}
      <div className="px-4 pt-3 pb-2">
        <svg
          viewBox={`0 0 ${width} ${height}`}
          className="w-full h-auto overflow-visible"
          role="img"
          aria-label="HNSW Recall versus Latency Pareto frontier"
        >
          {/* Gridlines */}
          {yTicks.map((tick) => {
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
                  {(tick * 100).toFixed(0)}%
                </text>
              </g>
            );
          })}

          {xTicks.map((tick) => {
            const x = xScale(tick);
            return (
              <g key={tick}>
                <line
                  x1={x}
                  y1={pad.top}
                  x2={x}
                  y2={height - pad.bottom}
                  stroke="#F1F5F9"
                />
                <text
                  x={x}
                  y={height - pad.bottom + 15}
                  textAnchor="middle"
                  className="fill-slate-500 text-[10px] font-mono tabular-nums"
                >
                  {tick}ms
                </text>
              </g>
            );
          })}

          {/* Axes */}
          <line
            x1={pad.left}
            y1={height - pad.bottom}
            x2={width - pad.right}
            y2={height - pad.bottom}
            stroke="#CBD5E1"
          />
          <line
            x1={pad.left}
            y1={pad.top}
            x2={pad.left}
            y2={height - pad.bottom}
            stroke="#CBD5E1"
          />

          {/* Axis Labels */}
          <text
            x={pad.left + plotW / 2}
            y={height - 6}
            textAnchor="middle"
            className="fill-slate-600 text-[11px] font-medium"
          >
            {latencyMetric === 'p50' ? 'p50 Query Latency (ms)' : 'p99 Tail Latency (ms)'}
          </text>
          <text
            x={14}
            y={pad.top + plotH / 2}
            textAnchor="middle"
            transform={`rotate(-90 14 ${pad.top + plotH / 2})`}
            className="fill-slate-600 text-[11px] font-medium"
          >
            ANN Recall@K
          </text>

          {/* Pareto Frontier Curve */}
          <path
            d={pathD}
            fill="none"
            stroke="#2563EB"
            strokeWidth={2}
            strokeLinecap="round"
            strokeLinejoin="round"
          />

          {/* Interactive Nodes */}
          {frontier.map((pt) => {
            const lat =
              latencyMetric === 'p50' ? pt.p50LatencyMs : pt.p99LatencyMs;
            const cx = xScale(lat);
            const cy = yScale(pt.recallAt500);
            const isActive = pt.efSearch === efSearch;

            return (
              <g
                key={pt.efSearch}
                onClick={() => onSelectEf(pt.efSearch)}
                className="cursor-pointer group"
                role="button"
                tabIndex={0}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    onSelectEf(pt.efSearch);
                  }
                }}
                aria-label={`Select ef_search ${pt.efSearch}`}
              >
                {/* Larger invisible hit target */}
                <circle cx={cx} cy={cy} r={14} fill="transparent" />
                {isActive && (
                  <circle
                    cx={cx}
                    cy={cy}
                    r={9}
                    fill="#DBEAFE"
                    stroke="#1D4ED8"
                    strokeWidth={1.5}
                  />
                )}
                <circle
                  cx={cx}
                  cy={cy}
                  r={isActive ? 5 : 4}
                  fill={isActive ? '#1D4ED8' : '#FFFFFF'}
                  stroke="#1D4ED8"
                  strokeWidth={2}
                />
                <text
                  x={cx}
                  y={cy - 11}
                  textAnchor="middle"
                  className={`text-[10px] font-mono tabular-nums ${
                    isActive
                      ? 'fill-blue-800 font-semibold'
                      : 'fill-slate-600 group-hover:fill-slate-900'
                  }`}
                >
                  ef={pt.efSearch}
                </text>
              </g>
            );
          })}
        </svg>
      </div>

      {/* Frontier Sweep Table */}
      <div className="border-t border-slate-200 overflow-x-auto">
        <table className="w-full text-xs text-left border-collapse">
          <thead>
            <tr className="bg-slate-50 border-b border-slate-200 text-slate-500 font-medium">
              <th className="py-2 px-4">ef_search</th>
              <th className="py-2 px-3 text-right">Recall</th>
              <th className="py-2 px-3 text-right">p50</th>
              <th className="py-2 px-3 text-right">p99</th>
              <th className="py-2 px-4 text-right">Top-10 Overlap</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100 font-mono tabular-nums">
            {frontier.map((pt) => {
              const isActive = pt.efSearch === efSearch;
              return (
                <tr
                  key={pt.efSearch}
                  onClick={() => onSelectEf(pt.efSearch)}
                  className={`cursor-pointer transition-colors ${
                    isActive
                      ? 'bg-blue-50/70 text-blue-950 font-semibold'
                      : 'hover:bg-slate-50 text-slate-700'
                  }`}
                >
                  <td className="py-2 px-4">{pt.efSearch}</td>
                  <td className="py-2 px-3 text-right">
                    {(pt.recallAt500 * 100).toFixed(1)}%
                  </td>
                  <td className="py-2 px-3 text-right">{pt.p50LatencyMs} ms</td>
                  <td className="py-2 px-3 text-right">{pt.p99LatencyMs} ms</td>
                  <td className="py-2 px-4 text-right">
                    {pt.top10OverlapWithExact}/10
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {/* Active Point Summary */}
      <div className="px-5 py-2.5 bg-slate-50/70 border-t border-slate-200 text-xs text-slate-600 font-mono tabular-nums flex items-center justify-between gap-4">
        <span>
          Active: ef={currentFrontierPoint.efSearch} ({currentFrontierPoint.distanceComputations}{' '}
          graph visits)
        </span>
        <span>
          {currentFrontierPoint.droppedTitles.length === 0
            ? '0 items dropped vs exact'
            : `${currentFrontierPoint.droppedTitles.length} dropped vs ef=512`}
        </span>
      </div>
    </section>
  );
};
