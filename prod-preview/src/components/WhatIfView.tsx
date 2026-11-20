import { useEffect, useState } from 'react';
import { AlertCircle, RotateCcw, TrendingUp } from 'lucide-react';
import type { POC, WhatIfParams, WhatIfProjection } from '../types/domain.ts';
import { simulateWhatIfApi, type ClientAuthHeaders } from '../utils/api.ts';
import { GoogleCloudLogo } from './BrandVisuals.tsx';

interface WhatIfViewProps {
  poc: POC;
  auth: ClientAuthHeaders;
}

export function WhatIfView({ poc, auth }: WhatIfViewProps) {
  const [params, setParams] = useState<WhatIfParams>({
    users_multiplier: 1,
    traffic_spike: 1,
    region_outage: false,
  });
  const [projection, setProjection] = useState<WhatIfProjection | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    simulateWhatIfApi(poc.id, params, auth)
      .then((res) => {
        if (!cancelled) {
          setProjection(res);
          setError(null);
        }
      })
      .catch((err) => {
        if (!cancelled) {
          setError(err instanceof Error ? err.message : 'Simulation failed');
        }
      });
    return () => {
      cancelled = true;
    };
  }, [poc.id, params, auth]);

  const reset = () =>
    setParams({ users_multiplier: 1, traffic_spike: 1, region_outage: false });

  return (
    <section aria-labelledby="whatif-heading" className="space-y-5">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1
            id="whatif-heading"
            className="text-2xl font-bold tracking-tight text-[#242424] sm:text-3xl"
          >
            What-If Capacity &amp; Cost Simulator
          </h1>
          <p className="mt-1 max-w-2xl text-sm text-[#605E5C]">
            Model how customer growth, traffic bursts, or a regional outage affect latency,
            availability, and monthly spend. Outputs are{' '}
            <strong className="font-semibold text-[#242424]">projected</strong> estimates, not live
            load tests.
          </p>
        </div>

        <button
          type="button"
          onClick={reset}
          className="inline-flex min-h-[38px] items-center gap-1.5 self-start rounded border border-[#8A8886] bg-white px-3.5 py-2 text-xs font-medium text-[#242424] hover:bg-[#F3F2F1] whitespace-nowrap shrink-0"
        >
          <RotateCcw className="h-3.5 w-3.5 text-[#107C41]" aria-hidden="true" />
          <span>Reset to 1× Baseline</span>
        </button>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
        {/* Controls Column */}
        <div className="ms-card overflow-hidden lg:col-span-5">
          <div className="border-b border-[#E1DFDD] bg-[#F3F2F1] px-5 py-2.5 text-xs font-semibold text-[#605E5C]">
            Scenario Parameters
          </div>
          <div className="p-5 space-y-6">
            <div>
              <div className="flex items-center justify-between">
                <label
                  htmlFor="users-multiplier-slider"
                  className="text-sm font-semibold text-[#242424]"
                >
                  Active Users Scale
                </label>
                <span
                  data-testid="users-multiplier-value"
                  className="font-mono text-sm font-semibold text-[#0E6B38] tabular-nums"
                >
                  ×{params.users_multiplier}
                </span>
              </div>
              <input
                id="users-multiplier-slider"
                type="range"
                min={1}
                max={100}
                step={1}
                value={params.users_multiplier}
                onChange={(e) =>
                  setParams((p) => ({ ...p, users_multiplier: Number(e.target.value) }))
                }
                className="mt-3 h-2 w-full cursor-pointer accent-[#107C41]"
              />
              <div className="mt-1.5 flex justify-between text-xs text-[#605E5C] tabular-nums">
                <span>
                  ×1 ({poc.environment.telemetry.baseline_daily_users.toLocaleString()} users/day)
                </span>
                <span>×10</span>
                <span>×50</span>
                <span>×100</span>
              </div>
            </div>

            <div>
              <div className="flex items-center justify-between">
                <label
                  htmlFor="traffic-spike-slider"
                  className="text-sm font-semibold text-[#242424]"
                >
                  Sudden Traffic Burst
                </label>
                <span className="font-mono text-sm font-semibold text-[#0E6B38] tabular-nums">
                  ×{params.traffic_spike}
                </span>
              </div>
              <input
                id="traffic-spike-slider"
                type="range"
                min={1}
                max={10}
                step={1}
                value={params.traffic_spike}
                onChange={(e) =>
                  setParams((p) => ({ ...p, traffic_spike: Number(e.target.value) }))
                }
                className="mt-3 h-2 w-full cursor-pointer accent-[#107C41]"
              />
              <div className="mt-1.5 flex justify-between text-xs text-[#605E5C] tabular-nums">
                <span>Steady (×1)</span>
                <span>Campaign (×5)</span>
                <span>Flash Sale (×10)</span>
              </div>
            </div>

            <div className="border-t border-[#EDEBE9] pt-4">
              <label
                htmlFor="region-outage-toggle"
                className="flex min-h-[44px] cursor-pointer items-start gap-3"
              >
                <input
                  id="region-outage-toggle"
                  type="checkbox"
                  checked={params.region_outage}
                  onChange={(e) =>
                    setParams((p) => ({ ...p, region_outage: e.target.checked }))
                  }
                  className="mt-1 h-4 w-4 rounded border-[#8A8886] accent-[#107C41]"
                />
                <div>
                  <span className="block text-sm font-semibold text-[#242424]">
                    Simulate {poc.environment.region_display} Outage
                  </span>
                  <span className="mt-0.5 block text-xs text-[#605E5C]">
                    Tests whether failover keeps customer checkout online if the primary facility
                    becomes unavailable.
                  </span>
                </div>
              </label>
            </div>
          </div>
        </div>

        {/* Side-by-side Projections Column */}
        <div className="space-y-4 lg:col-span-7" aria-live="polite">
          {error ? (
            <div className="rounded border border-[#C50F1F]/30 bg-[#FDF3F4] p-4 text-sm text-[#C50F1F]">
              {error}
            </div>
          ) : null}

          {projection ? (
            <>
              <div className="ms-card overflow-hidden">
                <div className="flex items-center justify-between border-b border-[#E1DFDD] bg-[#F3F2F1] px-5 py-2.5">
                  <div className="flex items-center gap-2 text-xs font-semibold text-[#242424]">
                    <TrendingUp className="h-4 w-4 text-[#A45B00]" aria-hidden="true" />
                    <span>Current Measured vs Projected Scenario</span>
                  </div>
                  <span className="text-xs font-semibold text-[#A45B00]">Projected</span>
                </div>

                <div className="p-5">
                  <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
                    <ComparisonMetric
                      label="Response Time (p95)"
                      current={`${projection.baseline.latency_p95_ms} ms`}
                      projected={
                        projection.projected.latency_p95_ms === 0
                          ? 'Unreachable'
                          : `${projection.projected.latency_p95_ms} ms`
                      }
                      testId="projected-latency"
                      alert={
                        projection.projected.latency_p95_ms === 0 ||
                        projection.projected.latency_p95_ms > 300
                      }
                    />
                    <ComparisonMetric
                      label="Monthly Cost"
                      current={`$${projection.baseline.monthly_cost_usd.toLocaleString('en-US')}/mo`}
                      projected={`$${projection.projected.monthly_cost_usd.toLocaleString('en-US')}/mo`}
                      testId="projected-cost"
                      alert={
                        projection.projected.monthly_cost_usd > poc.environment.budget_cap_usd
                      }
                    />
                    <ComparisonMetric
                      label="Service Availability"
                      current={`${projection.baseline.availability_pct}%`}
                      projected={`${projection.projected.availability_pct}%`}
                      testId="projected-availability"
                      alert={projection.projected.availability_pct < 99.5}
                    />
                  </div>

                  <div className="mt-4 grid grid-cols-3 gap-4 border-t border-[#EDEBE9] pt-3 text-xs text-[#605E5C] tabular-nums">
                    <div>
                      Peak instances:{' '}
                      <strong className="font-mono text-[#242424]">
                        {projection.projected.active_instances}
                      </strong>{' '}
                      (was {projection.baseline.active_instances})
                    </div>
                    <div>
                      Cold-start add:{' '}
                      <strong className="font-mono text-[#242424]">
                        +{projection.projected.cold_start_penalty_ms} ms
                      </strong>
                    </div>
                    <div>
                      Capacity load:{' '}
                      <strong className="font-mono text-[#242424]">
                        {projection.projected.concurrency_utilization_pct}%
                      </strong>
                    </div>
                  </div>
                </div>
              </div>

              {/* Plain-language What Breaks notice */}
              <div
                data-testid="what-breaks-summary"
                className="ms-card flex items-start gap-3 p-5"
              >
                <AlertCircle
                  className="mt-0.5 h-5 w-5 shrink-0 text-[#0F6CBD]"
                  aria-hidden="true"
                />
                <div>
                  <h2 className="text-sm font-semibold text-[#242424]">
                    What breaks at this scale
                  </h2>
                  <p className="mt-1 text-sm leading-relaxed text-[#323130]">
                    {projection.what_breaks}
                  </p>
                </div>
              </div>

              {/* Billing Catalog Breakdown */}
              <div className="ms-card overflow-hidden">
                <div className="flex items-center gap-2 border-b border-[#E1DFDD] bg-[#F3F2F1] px-5 py-2.5 text-xs font-semibold text-[#242424]">
                  <GoogleCloudLogo className="h-4 w-4 shrink-0" />
                  <span>Projected Monthly Cost Breakdown (Billing Catalog SKUs)</span>
                </div>
                <div className="divide-y divide-[#EDEBE9] px-5">
                  {projection.cost_breakdown.map((row) => (
                    <div
                      key={row.item}
                      className="flex items-center justify-between gap-4 py-3 text-sm"
                    >
                      <div>
                        <div className="font-medium text-[#242424]">{row.item}</div>
                        <div className="text-xs text-[#605E5C]">{row.sku_reference}</div>
                      </div>
                      <div className="font-mono font-semibold text-[#242424] tabular-nums">
                        ${row.monthly_usd.toLocaleString('en-US')}/mo
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </>
          ) : (
            <div className="h-64 animate-pulse rounded border border-[#E1DFDD] bg-[#F3F2F1]" />
          )}
        </div>
      </div>
    </section>
  );
}

function ComparisonMetric({
  label,
  current,
  projected,
  alert,
  testId,
}: {
  label: string;
  current: string;
  projected: string;
  alert: boolean;
  testId: string;
}) {
  return (
    <div className="rounded border border-[#E1DFDD] bg-[#FAF9F8] p-3.5">
      <div className="text-xs font-medium text-[#605E5C]">{label}</div>
      <div
        data-testid={testId}
        className={`mt-1 font-mono text-xl font-bold tabular-nums ${
          alert ? 'text-[#C50F1F]' : 'text-[#242424]'
        }`}
      >
        {projected}
      </div>
      <div className="mt-1 text-xs text-[#605E5C] tabular-nums">Current: {current}</div>
    </div>
  );
}
