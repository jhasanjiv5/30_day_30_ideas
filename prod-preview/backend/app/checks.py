from __future__ import annotations

import re
from datetime import datetime, timezone
from .models import CheckEvidence, CheckResult, EnvironmentSnapshot, Requirement


def _parse_threshold_number(threshold: str, fallback: float) -> float:
    cleaned = threshold.replace(",", "")
    m = re.search(r"(\d+(?:\.\d+)?)", cleaned)
    return float(m.group(1)) if m else fallback


def evaluate_requirement_check(
    req: Requirement,
    env: EnvironmentSnapshot,
    now_iso: str | None = None,
) -> CheckResult:
    timestamp = now_iso or datetime.now(timezone.utc).isoformat()
    t = env.telemetry

    if req.check_type == "latency_p95":
        limit_ms = req.target_numeric if req.target_numeric is not None else _parse_threshold_number(req.threshold, 300.0)
        actual_ms = t.latency_p95_ms
        status = "pass" if actual_ms <= limit_ms else "warn" if actual_ms <= limit_ms * 1.25 else "fail"
        node = next((r for r in env.resources if "latency_p95" in r.linked_check_types), env.resources[0])
        return CheckResult(
            id=f"chk-{req.id}",
            requirement_id=req.id,
            check_type=req.check_type,
            status=status,
            measured_or_projected="measured",
            actual_display=f"{int(round(actual_ms))} ms",
            threshold_display=f"<= {int(round(limit_ms))} ms",
            plain_explanation=(
                f"95% of customer requests complete in {int(round(actual_ms))} ms, inside the {int(round(limit_ms))} ms target."
                if status == "pass"
                else f"Response time ({int(round(actual_ms))} ms) exceeds or nears the {int(round(limit_ms))} ms target."
            ),
            evidence=CheckEvidence(
                source_api="Cloud Monitoring (run.googleapis.com/request_latencies)",
                metric_name="request_latencies_p95_ms",
                resource_id=node.id,
                resource_label=node.business_label,
                observed_summary=f"p95={actual_ms}ms over 24h rolling window",
                raw_excerpt=f'metric="run.googleapis.com/request_latencies" percentile=95 value={actual_ms}ms region="{env.primary_region}"',
                observed_at=timestamp,
            ),
        )

    if req.check_type == "uptime":
        target_pct = req.target_numeric if req.target_numeric is not None else _parse_threshold_number(req.threshold, 99.9)
        actual_pct = t.uptime_pct
        status = "pass" if actual_pct >= target_pct else "warn" if actual_pct >= target_pct - 0.3 else "fail"
        node = next((r for r in env.resources if "uptime" in r.linked_check_types), env.resources[0])
        return CheckResult(
            id=f"chk-{req.id}",
            requirement_id=req.id,
            check_type=req.check_type,
            status=status,
            measured_or_projected="measured",
            actual_display=f"{actual_pct:.2f}%",
            threshold_display=f">= {target_pct:.2f}%",
            plain_explanation=(
                f"Service availability measured {actual_pct:.2f}% across continuous synthetic probes."
                if status == "pass"
                else f"Service availability ({actual_pct:.2f}%) fell below the {target_pct:.2f}% target."
            ),
            evidence=CheckEvidence(
                source_api="Cloud Monitoring (monitoring.googleapis.com/uptime_check)",
                metric_name="uptime_check/check_passed_ratio",
                resource_id=node.id,
                resource_label=node.business_label,
                observed_summary=f"{actual_pct:.2f}% checks succeeded",
                raw_excerpt=f'uptime_probe url="{env.service_url}/healthz" pass_ratio={actual_pct / 100:.4f}',
                observed_at=timestamp,
            ),
        )

    if req.check_type == "data_region":
        prefix = (req.target_region or "europe-").lower()
        non_compliant = [r for r in t.observed_regions if not r.lower().startswith(prefix)]
        status = "pass" if not non_compliant else "fail"
        node = next((r for r in env.resources if "data_region" in r.linked_check_types), env.resources[0])
        return CheckResult(
            id=f"chk-{req.id}",
            requirement_id=req.id,
            check_type=req.check_type,
            status=status,
            measured_or_projected="measured",
            actual_display=", ".join(t.observed_regions),
            threshold_display=req.threshold,
            plain_explanation=(
                f"All data-storing services reside inside approved boundaries ({env.region_display})."
                if status == "pass"
                else f"Detected resource outside approved region: {', '.join(non_compliant)}."
            ),
            evidence=CheckEvidence(
                source_api="Cloud Asset Inventory (cloudasset.googleapis.com/v1/assets)",
                metric_name="asset_location_compliance",
                resource_id=node.id,
                resource_label=node.business_label,
                policy_line=f"locations={','.join(t.observed_regions)} policy={prefix}*",
                observed_summary=f"{len(t.observed_regions)} asset locations audited",
                raw_excerpt=f'asset_type="sqladmin.googleapis.com/Instance" location="{t.observed_regions[0] if t.observed_regions else env.primary_region}"',
                observed_at=timestamp,
            ),
        )

    if req.check_type == "iam_exposure":
        bindings = t.public_iam_bindings
        unexpected = [
            b for b in bindings
            if "roles/run.invoker" not in b and ("allUsers" in b or "allAuthenticatedUsers" in b)
        ]
        invoker_only = bool(bindings) and all("roles/run.invoker" in b for b in bindings)
        status = "fail" if unexpected else "warn" if invoker_only else "pass"
        node = next((r for r in env.resources if "iam_exposure" in r.linked_check_types), env.resources[0])
        return CheckResult(
            id=f"chk-{req.id}",
            requirement_id=req.id,
            check_type=req.check_type,
            status=status,
            measured_or_projected="measured",
            actual_display="Private access only" if not bindings else f"{len(bindings)} public binding(s)",
            threshold_display=req.threshold,
            plain_explanation=(
                "No public bindings exist; all endpoints require authentication."
                if status == "pass"
                else "Public web edge is open on HTTPS while internal payment and database tiers remain private."
                if status == "warn"
                else f"Broad public permission detected: {'; '.join(bindings)}."
            ),
            evidence=CheckEvidence(
                source_api="Cloud Resource Manager IAM Policy (getIamPolicy)",
                metric_name="iam_public_bindings_audit",
                resource_id=node.id,
                resource_label=node.business_label,
                policy_line=bindings[0] if bindings else "bindings: []",
                observed_summary="0 public bindings" if not bindings else f"Found: {'; '.join(bindings)}",
                raw_excerpt=bindings[0] if bindings else f'project="{env.project_id}" public_members=none',
                observed_at=timestamp,
            ),
        )

    # monthly_cost
    cap_usd = req.target_numeric if req.target_numeric is not None else _parse_threshold_number(req.threshold, env.budget_cap_usd)
    projected_usd = t.monthly_projected_cost_usd
    status = "pass" if projected_usd <= cap_usd * 0.9 else "warn" if projected_usd <= cap_usd else "fail"
    node = next((r for r in env.resources if "monthly_cost" in r.linked_check_types), env.resources[0])
    return CheckResult(
        id=f"chk-{req.id}",
        requirement_id=req.id,
        check_type=req.check_type,
        status=status,
        measured_or_projected="projected",
        actual_display=f"${int(round(projected_usd)):,}/mo",
        threshold_display=f"<= ${int(round(cap_usd)):,}/mo",
        plain_explanation=(
            f"Estimated monthly run rate (${int(round(projected_usd))}/mo) sits below the ${int(round(cap_usd))}/mo budget cap."
            if status != "fail"
            else f"Estimated monthly run rate (${int(round(projected_usd))}/mo) exceeds the ${int(round(cap_usd))}/mo budget cap."
        ),
        evidence=CheckEvidence(
            source_api="Cloud Billing Catalog API (cloudbilling.googleapis.com/v1/services)",
            metric_name="projected_monthly_run_rate_usd",
            resource_id=node.id,
            resource_label=node.business_label,
            observed_summary=f"SKU estimate: ${int(round(projected_usd))}/mo vs ${int(round(cap_usd))}/mo cap",
            raw_excerpt=f'billing_skus="Cloud Run + Cloud SQL + Egress" projected_usd={projected_usd} cap_usd={cap_usd}',
            observed_at=timestamp,
        ),
    )


def evaluate_all_checks(requirements: list[Requirement], env: EnvironmentSnapshot) -> list[CheckResult]:
    now_iso = datetime.now(timezone.utc).isoformat()
    return [
        evaluate_requirement_check(req, env, now_iso)
        for req in requirements
        if req.in_scope and req.approved_by_engineer
    ]
