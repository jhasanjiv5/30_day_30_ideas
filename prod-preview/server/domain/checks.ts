import type {
  CheckResult,
  EnvironmentSnapshot,
  Requirement,
} from '../../src/types/domain.ts';

function parseThresholdNumber(threshold: string, fallback: number): number {
  const match = threshold.replace(/,/g, '').match(/(\d+(?:\.\d+)?)/);
  return match ? Number(match[1]) : fallback;
}

export function evaluateRequirementCheck(
  req: Requirement,
  env: EnvironmentSnapshot,
  nowIso = new Date().toISOString()
): CheckResult {
  const t = env.telemetry;

  switch (req.check_type) {
    case 'latency_p95': {
      const limitMs = req.target_numeric ?? parseThresholdNumber(req.threshold, 300);
      const actualMs = t.latency_p95_ms;
      const status =
        actualMs <= limitMs ? 'pass' : actualMs <= limitMs * 1.25 ? 'warn' : 'fail';
      const appNode = env.resources.find((r) => r.linked_check_types.includes('latency_p95')) ?? env.resources[0];

      return {
        id: `chk-${req.id}`,
        requirement_id: req.id,
        check_type: req.check_type,
        status,
        measured_or_projected: 'measured',
        actual_display: `${actualMs} ms`,
        threshold_display: `<= ${limitMs} ms`,
        plain_explanation:
          status === 'pass'
            ? `95% of customer requests complete in ${actualMs} ms, well inside the ${limitMs} ms target.`
            : status === 'warn'
              ? `Response time (${actualMs} ms) is approaching the ${limitMs} ms ceiling under peak load.`
              : `Response time (${actualMs} ms) exceeds the ${limitMs} ms target and needs tuning before rollout.`,
        evidence: {
          source_api: 'Cloud Monitoring (run.googleapis.com/request_latencies)',
          metric_name: 'request_latencies_p95_ms',
          resource_id: appNode?.id ?? env.project_id,
          resource_label: appNode?.business_label ?? 'Primary Web Service',
          observed_summary: `p95=${actualMs}ms over 24h rolling window`,
          raw_excerpt: `metric="run.googleapis.com/request_latencies" percentile=95 value=${actualMs}ms region="${env.primary_region}"`,
          observed_at: nowIso,
        },
      };
    }

    case 'uptime': {
      const targetPct = req.target_numeric ?? parseThresholdNumber(req.threshold, 99.9);
      const actualPct = t.uptime_pct;
      const status =
        actualPct >= targetPct ? 'pass' : actualPct >= targetPct - 0.3 ? 'warn' : 'fail';
      const edgeNode = env.resources.find((r) => r.linked_check_types.includes('uptime')) ?? env.resources[0];

      return {
        id: `chk-${req.id}`,
        requirement_id: req.id,
        check_type: req.check_type,
        status,
        measured_or_projected: 'measured',
        actual_display: `${actualPct.toFixed(2)}%`,
        threshold_display: `>= ${targetPct.toFixed(2)}%`,
        plain_explanation:
          status === 'pass'
            ? `Service availability measured ${actualPct.toFixed(2)}% across continuous synthetic probes.`
            : `Service availability (${actualPct.toFixed(2)}%) dipped below the ${targetPct.toFixed(2)}% goal due to cold-start timeouts.`,
        evidence: {
          source_api: 'Cloud Monitoring (monitoring.googleapis.com/uptime_check)',
          metric_name: 'uptime_check/check_passed_ratio',
          resource_id: edgeNode?.id ?? env.service_url,
          resource_label: edgeNode?.business_label ?? 'Public HTTPS Endpoint',
          observed_summary: `${actualPct.toFixed(2)}% checks succeeded (1m interval)`,
          raw_excerpt: `uptime_probe url="${env.service_url}/healthz" pass_ratio=${(actualPct / 100).toFixed(4)} window="7d"`,
          observed_at: nowIso,
        },
      };
    }

    case 'data_region': {
      const requiredPrefix = (req.target_region ?? 'europe-').toLowerCase();
      const observed = t.observed_regions;
      const nonCompliant = observed.filter((r) => !r.toLowerCase().startsWith(requiredPrefix));
      const status = nonCompliant.length === 0 ? 'pass' : 'fail';
      const dbNode = env.resources.find((r) => r.linked_check_types.includes('data_region')) ?? env.resources[0];

      return {
        id: `chk-${req.id}`,
        requirement_id: req.id,
        check_type: req.check_type,
        status,
        measured_or_projected: 'measured',
        actual_display: observed.join(', '),
        threshold_display: req.threshold,
        plain_explanation:
          status === 'pass'
            ? `All data-storing services reside inside approved EU boundaries (${env.region_display}).`
            : `Detected storage resource outside approved region: ${nonCompliant.join(', ')}.`,
        evidence: {
          source_api: 'Cloud Asset Inventory (cloudasset.googleapis.com/v1/assets)',
          metric_name: 'asset_location_compliance',
          resource_id: dbNode?.id ?? env.project_id,
          resource_label: dbNode?.business_label ?? 'Customer Database',
          policy_line: `locations=${observed.join(',')} policy=${requiredPrefix}*`,
          observed_summary: `${observed.length} asset locations audited`,
          raw_excerpt: `asset_type="sqladmin.googleapis.com/Instance" location="${observed[0] ?? env.primary_region}" kms_region="${env.primary_region}"`,
          observed_at: nowIso,
        },
      };
    }

    case 'iam_exposure': {
      const publicBindings = t.public_iam_bindings;
      const hasUnexpectedExposure = publicBindings.some(
        (b) => !b.includes('roles/run.invoker') && (b.includes('allUsers') || b.includes('allAuthenticatedUsers'))
      );
      const hasPublicInvokerOnly =
        publicBindings.length > 0 &&
        publicBindings.every((b) => b.includes('roles/run.invoker'));
      const status = hasUnexpectedExposure ? 'fail' : hasPublicInvokerOnly ? 'warn' : 'pass';
      const iamNode = env.resources.find((r) => r.linked_check_types.includes('iam_exposure')) ?? env.resources[0];

      return {
        id: `chk-${req.id}`,
        requirement_id: req.id,
        check_type: req.check_type,
        status,
        measured_or_projected: 'measured',
        actual_display:
          publicBindings.length === 0
            ? 'Private access only'
            : `${publicBindings.length} public binding(s)`,
        threshold_display: req.threshold,
        plain_explanation:
          status === 'pass'
            ? 'No public or broad access bindings exist; all entry points require authentication.'
            : status === 'warn'
              ? 'Public web entry point is reachable on HTTPS, while internal services and databases stay private.'
              : `Broad public permission detected: ${publicBindings.join('; ')}. Restrict access immediately.`,
        evidence: {
          source_api: 'Cloud Resource Manager IAM Policy (getIamPolicy)',
          metric_name: 'iam_public_bindings_audit',
          resource_id: iamNode?.id ?? env.project_id,
          resource_label: iamNode?.business_label ?? 'Access Boundary',
          policy_line: publicBindings[0] ?? 'bindings: [] (no allUsers / allAuthenticatedUsers)',
          observed_summary:
            publicBindings.length === 0
              ? '0 public bindings found'
              : `Found: ${publicBindings.join(' | ')}`,
          raw_excerpt:
            publicBindings[0] ??
            `resource="//cloudresourcemanager.googleapis.com/projects/${env.project_id}" public_members=none`,
          observed_at: nowIso,
        },
      };
    }

    case 'monthly_cost': {
      const capUsd = req.target_numeric ?? parseThresholdNumber(req.threshold, env.budget_cap_usd);
      const projectedUsd = t.monthly_projected_cost_usd;
      const status =
        projectedUsd <= capUsd * 0.9 ? 'pass' : projectedUsd <= capUsd ? 'warn' : 'fail';
      const costNode = env.resources.find((r) => r.linked_check_types.includes('monthly_cost')) ?? env.resources[0];

      return {
        id: `chk-${req.id}`,
        requirement_id: req.id,
        check_type: req.check_type,
        status,
        measured_or_projected: 'projected',
        actual_display: `$${projectedUsd.toLocaleString('en-US')}/mo`,
        threshold_display: `<= $${capUsd.toLocaleString('en-US')}/mo`,
        plain_explanation:
          status === 'pass'
            ? `Estimated monthly run rate ($${projectedUsd}/mo) sits comfortably below the $${capUsd}/mo budget cap.`
            : status === 'warn'
              ? `Estimated monthly run rate ($${projectedUsd}/mo) is within 10% of the $${capUsd}/mo budget cap.`
              : `Estimated monthly run rate ($${projectedUsd}/mo) exceeds the $${capUsd}/mo budget cap.`,
        evidence: {
          source_api: 'Cloud Billing Catalog API (cloudbilling.googleapis.com/v1/services)',
          metric_name: 'projected_monthly_run_rate_usd',
          resource_id: costNode?.id ?? env.project_id,
          resource_label: costNode?.business_label ?? 'POC Monthly Footprint',
          observed_summary: `SKU estimate: $${projectedUsd}/mo vs $${capUsd}/mo cap`,
          raw_excerpt: `billing_skus="Cloud Run vCPU/GiB + Cloud SQL db-custom-2-7680 + Egress" projected_usd=${projectedUsd} cap_usd=${capUsd}`,
          observed_at: nowIso,
        },
      };
    }
  }
}

export function evaluateAllChecks(
  requirements: Requirement[],
  env: EnvironmentSnapshot
): CheckResult[] {
  const nowIso = new Date().toISOString();
  return requirements
    .filter((r) => r.in_scope && r.approved_by_engineer)
    .map((req) => evaluateRequirementCheck(req, env, nowIso));
}
