import React from 'react';
import { CheckCircle2, AlertTriangle } from 'lucide-react';
import { AbTestSummary } from '../engine/types';

interface AbVerdictPanelProps {
  abSummary: AbTestSummary;
  srmBugActive: boolean;
  onToggleSrmBug: () => void;
  onReseedSimulation: () => void;
}

export const AbVerdictPanel: React.FC<AbVerdictPanelProps> = ({
  abSummary,
  srmBugActive,
  onToggleSrmBug,
  onReseedSimulation,
}) => {
  const {
    metricLabel,
    controlUsers,
    treatmentUsers,
    cupedLiftPct,
    ciLowPct,
    ciHighPct,
    varianceReductionPct,
    srmPValue,
    srmPassed,
    extraAnnualConversionsAt1M,
    dailySeries,
  } = abSummary;

  const isSignificantPositive = ciLowPct > 0 && srmPassed;

  // Novelty decay SVG geometry
  const width = 920;
  const height = 225;
  const pad = { top: 22, right: 26, bottom: 36, left: 50 };
  const plotW = width - pad.left - pad.right;
  const plotH = height - pad.top - pad.bottom;

  const allVals = dailySeries.flatMap((d) => [
    d.ciLowPct,
    d.ciHighPct,
    d.noveltyComponentPct,
    0,
  ]);
  const minVal = Math.min(-1, Math.floor(Math.min(...allVals) - 0.5));
  const maxVal = Math.max(4, Math.ceil(Math.max(...allVals) + 0.8));

  const xScale = (day: number) =>
    pad.left + ((day - 1) / Math.max(1, dailySeries.length - 1)) * plotW;
  const yScale = (val: number) =>
    pad.top + (1 - (val - minVal) / Math.max(1, maxVal - minVal)) * plotH;

  // 95% CI Ribbon Polygon
  const upperPoints = dailySeries.map(
    (d) => `${xScale(d.day).toFixed(1)},${yScale(d.ciHighPct).toFixed(1)}`
  );
  const lowerPoints = [...dailySeries]
    .reverse()
    .map((d) => `${xScale(d.day).toFixed(1)},${yScale(d.ciLowPct).toFixed(1)}`);
  const ribbonPoints = [...upperPoints, ...lowerPoints].join(' ');

  const obsLineD = dailySeries
    .map(
      (d, idx) =>
        `${idx === 0 ? 'M' : 'L'} ${xScale(d.day).toFixed(1)} ${yScale(
          d.relativeLiftPct
        ).toFixed(1)}`
    )
    .join(' ');

  const noveltyLineD = dailySeries
    .map(
      (d, idx) =>
        `${idx === 0 ? 'M' : 'L'} ${xScale(d.day).toFixed(1)} ${yScale(
          d.noveltyComponentPct
        ).toFixed(1)}`
    )
    .join(' ');

  const steadyVal = dailySeries[0]?.steadyStatePct ?? 0;

  const yTicks = Array.from({ length: 5 }, (_, i) =>
    Number((minVal + ((maxVal - minVal) * i) / 4).toFixed(1))
  );

  return (
    <section
      id="verdict"
      className="bg-white border border-slate-200 rounded-lg overflow-hidden"
    >
      {/* Header */}
      <div className="px-5 py-4 border-b border-slate-200 flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-base font-semibold text-slate-900 tracking-tight">
            04. Simulated A/B Verdict &amp; Novelty Decay
          </h2>
          <p className="text-xs text-slate-500 mt-0.5 tabular-nums">
            14-day Monte Carlo click simulator (N = {(controlUsers + treatmentUsers).toLocaleString()}{' '}
            sessions · 500-resample block bootstrap · CUPED covariate adjustment)
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={onToggleSrmBug}
            className={`px-3 py-1.5 text-xs font-medium rounded-md border whitespace-nowrap shrink-0 transition-colors ${
              srmBugActive
                ? 'bg-red-50 text-red-800 border-red-300 hover:bg-red-100'
                : 'bg-white text-slate-700 border-slate-300 hover:bg-slate-50'
            }`}
          >
            {srmBugActive ? 'Disable SRM Logging Bug' : 'Inject SRM Bug'}
          </button>
          <button
            type="button"
            onClick={onReseedSimulation}
            className="px-3 py-1.5 text-xs font-medium rounded-md bg-slate-900 text-white hover:bg-slate-800 whitespace-nowrap shrink-0 transition-colors"
          >
            Resample A/B
          </button>
        </div>
      </div>

      {/* Natural Language Verdict Statement */}
      <div
        className={`px-5 py-3.5 border-b border-slate-200 flex flex-wrap items-center justify-between gap-3 text-sm ${
          !srmPassed
            ? 'bg-red-50/60 text-red-950'
            : isSignificantPositive
            ? 'bg-emerald-50/50 text-slate-900'
            : 'bg-slate-50 text-slate-900'
        }`}
      >
        <div className="font-medium leading-relaxed tabular-nums">
          <span className="font-semibold">Verdict:</span> IPW ranker{' '}
          <strong className="font-mono">
            {cupedLiftPct >= 0 ? '+' : ''}
            {cupedLiftPct.toFixed(1)}%
          </strong>{' '}
          {metricLabel} (95% CI{' '}
          <span className="font-mono">
            {ciLowPct >= 0 ? '+' : ''}
            {ciLowPct.toFixed(1)}% to {ciHighPct >= 0 ? '+' : ''}
            {ciHighPct.toFixed(1)}%
          </span>
          ), CUPED reduced variance{' '}
          <span className="font-mono font-semibold">
            {varianceReductionPct.toFixed(1)}%
          </span>
          , SRM{' '}
          <span className="font-mono font-semibold">
            p = {srmPValue < 0.001 ? '<0.001' : srmPValue.toFixed(2)}
          </span>
          , est.{' '}
          <span className="font-mono font-semibold">
            {extraAnnualConversionsAt1M.toLocaleString()}
          </span>{' '}
          extra conversions/yr at 1M MAU.
        </div>

        <span
          className={`inline-flex items-center gap-1.5 text-xs font-semibold whitespace-nowrap shrink-0 ${
            srmPassed ? 'text-emerald-700' : 'text-red-700'
          }`}
        >
          {srmPassed ? (
            <>
              <CheckCircle2 className="w-4 h-4" />
              <span>SRM Validated</span>
            </>
          ) : (
            <>
              <AlertTriangle className="w-4 h-4" />
              <span>SRM Mismatch Detected</span>
            </>
          )}
        </span>
      </div>

      {/* 4-Column Flat KPI Grid (hairline dividers only, no nested cards) */}
      <div className="grid grid-cols-2 lg:grid-cols-4 divide-y lg:divide-y-0 lg:divide-x divide-slate-200 border-b border-slate-200 tabular-nums">
        <div className="p-4">
          <div className="text-xs text-slate-500 font-medium">
            CUPED Relative Lift
          </div>
          <div className="text-xl font-semibold font-mono text-slate-900 mt-1">
            {cupedLiftPct >= 0 ? '+' : ''}
            {cupedLiftPct.toFixed(2)}%
          </div>
          <div className="text-xs font-mono text-slate-500 mt-0.5">
            95% CI [{ciLowPct >= 0 ? '+' : ''}
            {ciLowPct.toFixed(1)}%, {ciHighPct >= 0 ? '+' : ''}
            {ciHighPct.toFixed(1)}%]
          </div>
        </div>

        <div className="p-4">
          <div className="text-xs text-slate-500 font-medium">
            CUPED Variance Reduction
          </div>
          <div className="text-xl font-semibold font-mono text-blue-700 mt-1">
            {varianceReductionPct.toFixed(1)}%
          </div>
          <div className="text-xs font-mono text-slate-500 mt-0.5">
            Raw lift: {abSummary.rawLiftPct >= 0 ? '+' : ''}
            {abSummary.rawLiftPct.toFixed(2)}%
          </div>
        </div>

        <div className="p-4">
          <div className="text-xs text-slate-500 font-medium">
            Sample Ratio Mismatch (χ²)
          </div>
          <div
            className={`text-xl font-semibold font-mono mt-1 ${
              srmPassed ? 'text-emerald-700' : 'text-red-700'
            }`}
          >
            p = {srmPValue < 0.001 ? '<0.001' : srmPValue.toFixed(3)}
          </div>
          <div className="text-xs font-mono text-slate-500 mt-0.5">
            Ctrl {controlUsers.toLocaleString()} / Trt {treatmentUsers.toLocaleString()}
          </div>
        </div>

        <div className="p-4">
          <div className="text-xs text-slate-500 font-medium">
            Annualized Impact (1M MAU)
          </div>
          <div className="text-xl font-semibold font-mono text-slate-900 mt-1">
            +{extraAnnualConversionsAt1M.toLocaleString()}
          </div>
          <div className="text-xs font-mono text-slate-500 mt-0.5">
            Steady-state: +{steadyVal.toFixed(2)}%
          </div>
        </div>
      </div>

      {/* Novelty Decay Chart */}
      <div className="px-5 pt-4 pb-3">
        <div className="flex flex-wrap items-center justify-between gap-3 mb-2">
          <div className="text-xs font-semibold text-slate-700">
            14-Day Novelty Decay Trajectory (% Relative Lift vs Naive Control)
          </div>
          <div className="flex flex-wrap items-center gap-4 text-xs text-slate-600">
            <span className="inline-flex items-center gap-1.5">
              <span className="w-3 h-0.5 bg-blue-600 inline-block" />
              Observed daily lift
            </span>
            <span className="inline-flex items-center gap-1.5">
              <span className="w-3 h-2.5 bg-blue-100 border border-blue-200 inline-block" />
              95% CI band
            </span>
            <span className="inline-flex items-center gap-1.5">
              <span className="w-3 h-0.5 border-t-2 border-dashed border-amber-600 inline-block" />
              Novelty decay curve
            </span>
            <span className="inline-flex items-center gap-1.5">
              <span className="w-3 h-0.5 border-t-2 border-dotted border-emerald-700 inline-block" />
              Steady-state ({steadyVal.toFixed(1)}%)
            </span>
          </div>
        </div>

        <svg
          viewBox={`0 0 ${width} ${height}`}
          className="w-full h-auto overflow-visible"
          role="img"
          aria-label="14-day novelty decay curve showing daily lift converging toward steady state"
        >
          {/* Y gridlines */}
          {yTicks.map((tick) => {
            const y = yScale(tick);
            return (
              <g key={tick}>
                <line
                  x1={pad.left}
                  y1={y}
                  x2={width - pad.right}
                  y2={y}
                  stroke={Math.abs(tick) < 0.05 ? '#94A3B8' : '#E2E8F0'}
                  strokeDasharray={Math.abs(tick) < 0.05 ? undefined : '3 3'}
                />
                <text
                  x={pad.left - 8}
                  y={y + 4}
                  textAnchor="end"
                  className="fill-slate-500 text-[10px] font-mono tabular-nums"
                >
                  {tick > 0 ? '+' : ''}
                  {tick.toFixed(1)}%
                </text>
              </g>
            );
          })}

          {/* Zero baseline */}
          <line
            x1={pad.left}
            y1={yScale(0)}
            x2={width - pad.right}
            y2={yScale(0)}
            stroke="#94A3B8"
            strokeWidth={1}
          />

          {/* 95% CI Confidence Ribbon */}
          <polygon points={ribbonPoints} fill="#DBEAFE" fillOpacity={0.65} />

          {/* Steady-state asymptote */}
          <line
            x1={pad.left}
            y1={yScale(steadyVal)}
            x2={width - pad.right}
            y2={yScale(steadyVal)}
            stroke="#047857"
            strokeWidth={1.5}
            strokeDasharray="2 4"
          />

          {/* Novelty decay theoretical envelope */}
          <path
            d={noveltyLineD}
            fill="none"
            stroke="#D97706"
            strokeWidth={1.75}
            strokeDasharray="5 4"
          />

          {/* Daily observed relative lift */}
          <path
            d={obsLineD}
            fill="none"
            stroke="#1D4ED8"
            strokeWidth={2.2}
            strokeLinejoin="round"
          />

          {/* Data points & X ticks */}
          {dailySeries.map((d) => {
            const cx = xScale(d.day);
            const cy = yScale(d.relativeLiftPct);
            return (
              <g key={d.day}>
                <circle
                  cx={cx}
                  cy={cy}
                  r={3.5}
                  fill="#FFFFFF"
                  stroke="#1D4ED8"
                  strokeWidth={2}
                />
                <text
                  x={cx}
                  y={height - pad.bottom + 16}
                  textAnchor="middle"
                  className="fill-slate-500 text-[10px] font-mono tabular-nums"
                >
                  D{d.day}
                </text>
              </g>
            );
          })}

          <text
            x={pad.left + plotW / 2}
            y={height - 3}
            textAnchor="middle"
            className="fill-slate-600 text-[11px] font-medium"
          >
            Simulated Experiment Day (Novelty Decay Window)
          </text>
        </svg>
      </div>
    </section>
  );
};
