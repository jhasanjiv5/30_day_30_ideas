from __future__ import annotations

import math
from .models import CostBreakdownRow, EnvironmentSnapshot, WhatIfParams, WhatIfProjection

SKU_PRICES = {
    "cloud_run_vcpu_hour": 0.0864,
    "cloud_run_mem_gib_hour": 0.009,
    "cloud_sql_base_monthly": 148,
    "cloud_sql_replica_monthly": 148,
    "egress_per_gb": 0.085,
    "ops_monthly": 18,
}


def simulate_what_if(env: EnvironmentSnapshot, params: WhatIfParams) -> WhatIfProjection:
    t = env.telemetry
    effective_load = params.users_multiplier * params.traffic_spike

    base_concurrency = max(1, round(t.baseline_daily_users / 250))
    baseline_instances = max(1, math.ceil(base_concurrency / t.concurrency_per_instance))

    needed_concurrency = base_concurrency * effective_load
    raw_needed_instances = math.ceil(needed_concurrency / t.concurrency_per_instance)
    active_instances = min(t.max_instances, max(1, raw_needed_instances))
    total_capacity = active_instances * t.concurrency_per_instance
    utilization_pct = round((needed_concurrency / total_capacity) * 100)

    scale_delta = max(0, active_instances - baseline_instances)
    cold_start_ms = (
        min(480, round(scale_delta * 14 + (params.traffic_spike - 1) * 28))
        if scale_delta > 0
        else 0
    )

    db_connections_needed = active_instances * 6
    db_saturated = db_connections_needed > t.db_max_connections
    instance_saturated = utilization_pct > 100

    queue_delay_ms = 0
    if utilization_pct > 75:
        queue_delay_ms += round((utilization_pct - 75) * 4.5)
    if db_saturated:
        queue_delay_ms += round((db_connections_needed - t.db_max_connections) * 9)

    projected_latency_ms = round(t.latency_p95_ms + cold_start_ms * 0.45 + queue_delay_ms)
    projected_availability = t.uptime_pct

    if params.region_outage:
        if t.has_multi_region_failover:
            projected_latency_ms += 110
            projected_availability = max(99.5, t.uptime_pct - 0.15)
        else:
            projected_latency_ms = 0
            projected_availability = 0.0
    elif instance_saturated:
        projected_availability = max(92.0, round(t.uptime_pct - (utilization_pct - 100) * 0.08, 2))

    hours_per_month = 730
    avg_active_fraction = 0.35 * min(2.5, math.sqrt(params.traffic_spike))
    compute_scale_usd = round(
        active_instances
        * avg_active_fraction
        * hours_per_month
        * (SKU_PRICES["cloud_run_vcpu_hour"] + SKU_PRICES["cloud_run_mem_gib_hour"] * 2)
        + (effective_load - 1) * 18
    )
    base_service_baseline = max(0, int(t.monthly_projected_cost_usd) - SKU_PRICES["cloud_sql_base_monthly"] - 45)
    compute_usd = max(base_service_baseline, compute_scale_usd + base_service_baseline - 26)
    db_usd = (
        SKU_PRICES["cloud_sql_base_monthly"] + SKU_PRICES["cloud_sql_replica_monthly"]
        if t.has_multi_region_failover
        else SKU_PRICES["cloud_sql_base_monthly"]
    ) + round((effective_load - 1) * 3.5)
    egress_gb = round(25 * effective_load)
    egress_usd = max(12, round(egress_gb * SKU_PRICES["egress_per_gb"]))
    ops_usd = SKU_PRICES["ops_monthly"] + 15 + round((effective_load - 1) * 2.5)
    total_cost = int(t.monthly_projected_cost_usd) if effective_load == 1 else (compute_usd + db_usd + egress_usd + ops_usd)

    if params.region_outage and not t.has_multi_region_failover:
        what_breaks = f"Everything stops responding during a {env.region_display} outage because no backup region is configured."
    elif params.region_outage and t.has_multi_region_failover:
        what_breaks = "Traffic automatically reroutes to the backup European region with ~110 ms added delay; no data is lost."
    elif instance_saturated and db_saturated:
        what_breaks = f"Both app capacity (max {t.max_instances} instances) and database connections ({t.db_max_connections} limit) saturate."
    elif instance_saturated:
        what_breaks = f"The service hits its {t.max_instances}-instance autoscaling ceiling ({utilization_pct}% load)."
    elif db_saturated:
        what_breaks = f"The customer database hits its {t.db_max_connections}-connection limit under {active_instances} instances."
    elif total_cost > env.budget_cap_usd:
        what_breaks = f"Performance stays healthy, but monthly spend (${total_cost:,}) breaches the ${int(env.budget_cap_usd):,} budget cap."
    elif cold_start_ms > 120:
        what_breaks = f"Nothing fails, though sudden traffic bursts add up to {cold_start_ms} ms of cold-start wait."
    else:
        what_breaks = "Nothing breaks at this load; capacity, database connections, and monthly spend remain within safe limits."

    return WhatIfProjection(
        params=params,
        baseline={
            "latency_p95_ms": int(t.latency_p95_ms),
            "monthly_cost_usd": int(t.monthly_projected_cost_usd),
            "availability_pct": t.uptime_pct,
            "active_instances": baseline_instances,
        },
        projected={
            "latency_p95_ms": projected_latency_ms,
            "monthly_cost_usd": total_cost,
            "availability_pct": round(projected_availability, 2),
            "active_instances": active_instances,
            "cold_start_penalty_ms": cold_start_ms,
            "concurrency_utilization_pct": utilization_pct,
        },
        what_breaks=what_breaks,
        cost_breakdown=[
            CostBreakdownRow(
                item=f"App hosting ({active_instances} peak instances)",
                sku_reference="Cloud Run vCPU & Memory SKU",
                monthly_usd=compute_usd,
            ),
            CostBreakdownRow(
                item="Customer database",
                sku_reference="Cloud SQL PostgreSQL SKU",
                monthly_usd=db_usd,
            ),
            CostBreakdownRow(
                item=f"Outbound network traffic ({egress_gb:,} GB)",
                sku_reference="GCP Premium Tier Egress SKU",
                monthly_usd=egress_usd,
            ),
            CostBreakdownRow(
                item="Uptime checks & audit logs",
                sku_reference="Cloud Monitoring & Logging SKU",
                monthly_usd=ops_usd,
            ),
        ],
    )
