import type {
  EnvironmentSnapshot,
  WhatIfParams,
  WhatIfProjection,
} from '../../src/types/domain.ts';

// Cloud Billing Catalog reference SKU prices (europe-west1 / standard)
const SKU_PRICES = {
  cloudRunVcpuPerHourUsd: 0.0864,
  cloudRunMemGiBPerHourUsd: 0.009,
  cloudSqlBaseMonthlyUsd: 148,
  cloudSqlReplicaMonthlyUsd: 148,
  egressPerGbUsd: 0.085,
  monitoringLoggingMonthlyUsd: 18,
};

export function simulateWhatIf(
  env: EnvironmentSnapshot,
  rawParams: WhatIfParams
): WhatIfProjection {
  const usersMultiplier = Math.max(1, Math.min(100, Math.round(rawParams.users_multiplier || 1)));
  const trafficSpike = Math.max(1, Math.min(10, Number((rawParams.traffic_spike || 1).toFixed(1))));
  const regionOutage = Boolean(rawParams.region_outage);

  const t = env.telemetry;
  const effectiveLoad = usersMultiplier * trafficSpike;

  // Baseline calculations (1x load)
  const baseConcurrency = Math.max(1, Math.round(t.baseline_daily_users / 250));
  const baselineInstances = Math.max(1, Math.ceil(baseConcurrency / t.concurrency_per_instance));

  // Projected instances and saturation
  const neededConcurrency = baseConcurrency * effectiveLoad;
  const rawNeededInstances = Math.ceil(neededConcurrency / t.concurrency_per_instance);
  const activeInstances = Math.min(t.max_instances, Math.max(1, rawNeededInstances));
  const totalCapacity = activeInstances * t.concurrency_per_instance;
  const utilizationPct = Math.round((neededConcurrency / totalCapacity) * 100);

  // Cold start penalty increases when scaling up rapidly
  const scaleDelta = Math.max(0, activeInstances - baselineInstances);
  const coldStartPenaltyMs = scaleDelta > 0 ? Math.min(480, Math.round(scaleDelta * 14 + (trafficSpike - 1) * 28)) : 0;

  // Queueing delay if utilization > 80% or DB connections saturated
  const dbConnectionsNeeded = activeInstances * 6;
  const dbSaturated = dbConnectionsNeeded > t.db_max_connections;
  const instanceSaturated = utilizationPct > 100;

  let queueDelayMs = 0;
  if (utilizationPct > 75) {
    queueDelayMs += Math.round((utilizationPct - 75) * 4.5);
  }
  if (dbSaturated) {
    queueDelayMs += Math.round((dbConnectionsNeeded - t.db_max_connections) * 9);
  }

  let projectedLatencyMs = Math.round(
    t.latency_p95_ms + coldStartPenaltyMs * 0.45 + queueDelayMs
  );
  let projectedAvailabilityPct = t.uptime_pct;

  if (regionOutage) {
    if (t.has_multi_region_failover) {
      projectedLatencyMs += 110; // Cross-region hop
      projectedAvailabilityPct = Math.max(99.5, t.uptime_pct - 0.15);
    } else {
      projectedLatencyMs = 0; // Service unreachable
      projectedAvailabilityPct = 0.0;
    }
  } else if (instanceSaturated) {
    projectedAvailabilityPct = Math.max(92.0, Number((t.uptime_pct - (utilizationPct - 100) * 0.08).toFixed(2)));
  }

  // Monthly cost projection from Billing Catalog SKUs anchored to POC resource baseline
  const hoursPerMonth = 730;
  const avgActiveFraction = 0.35 * Math.min(2.5, Math.sqrt(trafficSpike));
  const computeScaleUsd = Math.round(
    activeInstances *
      avgActiveFraction *
      hoursPerMonth *
      (SKU_PRICES.cloudRunVcpuPerHourUsd + SKU_PRICES.cloudRunMemGiBPerHourUsd * 2) +
      (effectiveLoad - 1) * 18
  );
  const baseServiceBaseline = Math.max(0, t.monthly_projected_cost_usd - SKU_PRICES.cloudSqlBaseMonthlyUsd - 45);
  const computeUsd = Math.max(baseServiceBaseline, computeScaleUsd + baseServiceBaseline - 26);
  const dbUsd =
    (t.has_multi_region_failover
      ? SKU_PRICES.cloudSqlBaseMonthlyUsd + SKU_PRICES.cloudSqlReplicaMonthlyUsd
      : SKU_PRICES.cloudSqlBaseMonthlyUsd) + Math.round((effectiveLoad - 1) * 3.5);
  const egressGb = Math.round(25 * effectiveLoad);
  const egressUsd = Math.max(12, Math.round(egressGb * SKU_PRICES.egressPerGbUsd));
  const opsUsd = SKU_PRICES.monitoringLoggingMonthlyUsd + 15 + Math.round((effectiveLoad - 1) * 2.5);

  const projectedMonthlyCostUsd =
    effectiveLoad === 1 ? t.monthly_projected_cost_usd : computeUsd + dbUsd + egressUsd + opsUsd;

  // Plain-language "what breaks" sentence
  let whatBreaks: string;
  if (regionOutage && !t.has_multi_region_failover) {
    whatBreaks = `Everything stops responding during a ${env.region_display} outage because this POC has no backup region configured.`;
  } else if (regionOutage && t.has_multi_region_failover) {
    whatBreaks = `Traffic automatically reroutes to the backup European region with ~110 ms added delay; no data is lost.`;
  } else if (instanceSaturated && dbSaturated) {
    whatBreaks = `Both app capacity (max ${t.max_instances} instances) and database connections (${t.db_max_connections} limit) saturate, causing queued requests and timeouts.`;
  } else if (instanceSaturated) {
    whatBreaks = `The service hits its ${t.max_instances}-instance autoscaling ceiling (${utilizationPct}% load), forcing users to wait in queue.`;
  } else if (dbSaturated) {
    whatBreaks = `The customer database hits its ${t.db_max_connections}-connection limit under ${activeInstances} running app instances, slowing checkout writes.`;
  } else if (projectedMonthlyCostUsd > env.budget_cap_usd) {
    whatBreaks = `Performance stays healthy, but monthly spend ($${projectedMonthlyCostUsd.toLocaleString('en-US')}) breaches the $${env.budget_cap_usd.toLocaleString('en-US')} budget cap.`;
  } else if (coldStartPenaltyMs > 120) {
    whatBreaks = `Nothing fails, though sudden traffic bursts add up to ${coldStartPenaltyMs} ms of cold-start wait while new instances warm up.`;
  } else {
    whatBreaks = 'Nothing breaks at this load; capacity, database connections, and monthly spend remain within safe limits.';
  }

  return {
    params: {
      users_multiplier: usersMultiplier,
      traffic_spike: trafficSpike,
      region_outage: regionOutage,
    },
    baseline: {
      latency_p95_ms: t.latency_p95_ms,
      monthly_cost_usd: t.monthly_projected_cost_usd,
      availability_pct: t.uptime_pct,
      active_instances: baselineInstances,
    },
    projected: {
      latency_p95_ms: projectedLatencyMs,
      monthly_cost_usd: projectedMonthlyCostUsd,
      availability_pct: Number(projectedAvailabilityPct.toFixed(2)),
      active_instances: activeInstances,
      cold_start_penalty_ms: coldStartPenaltyMs,
      concurrency_utilization_pct: utilizationPct,
    },
    what_breaks: whatBreaks,
    cost_breakdown: [
      {
        item: `App hosting (${activeInstances} peak instances)`,
        sku_reference: 'Cloud Run vCPU & Memory SKU (europe-west1)',
        monthly_usd: computeUsd,
      },
      {
        item: t.has_multi_region_failover ? 'Customer database (Primary + Standby)' : 'Customer database (Single region)',
        sku_reference: 'Cloud SQL PostgreSQL HA SKU',
        monthly_usd: dbUsd,
      },
      {
        item: `Outbound network traffic (${egressGb.toLocaleString('en-US')} GB)`,
        sku_reference: 'GCP Premium Tier Egress SKU',
        monthly_usd: egressUsd,
      },
      {
        item: 'Uptime checks & audit logs',
        sku_reference: 'Cloud Monitoring & Logging SKU',
        monthly_usd: opsUsd,
      },
    ],
    measured_or_projected: 'projected',
  };
}
