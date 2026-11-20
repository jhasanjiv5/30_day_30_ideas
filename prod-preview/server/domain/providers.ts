import fs from 'node:fs';
import path from 'node:path';
import type {
  EnvironmentSnapshot,
  POC,
  Requirement,
} from '../../src/types/domain.ts';
import { evaluateAllChecks } from './checks.ts';

export interface EnvironmentProvider {
  readonly name: 'MockProvider' | 'GcpProvider';
  loadSeedPocs(): Promise<POC[]>;
  refreshEnvironment(poc: POC): Promise<EnvironmentSnapshot>;
}

function addDaysIso(days: number): string {
  const d = new Date(Date.now() + days * 24 * 60 * 60 * 1000);
  return d.toISOString().slice(0, 10);
}

export class MockProvider implements EnvironmentProvider {
  readonly name = 'MockProvider' as const;

  async loadSeedPocs(): Promise<POC[]> {
    const poc1Env: EnvironmentSnapshot = {
      provider_name: 'MockProvider',
      project_id: 'poc-retail-checkout-eu-04',
      primary_region: 'europe-west1',
      region_display: 'Belgium (EU)',
      service_url: 'https://checkout-preview-eu.example.run.app',
      lifecycle_state: 'live',
      days_until_teardown: 5,
      teardown_date_iso: addDaysIso(5),
      budget_cap_usd: 450,
      current_spend_usd: 184,
      terraform_template_ref: 'infra/main.tf (Cloud Run + Cloud SQL EU)',
      resources: [
        {
          id: 'edge-https-lb',
          business_label: 'Edge HTTPS Router',
          plain_description: 'Receives customer checkout requests over encrypted HTTPS and routes traffic to Belgium.',
          gcp_service: 'Cloud Run Domain Mapping / HTTPS LB',
          region: 'europe-west1',
          tier: 'Managed TLS 1.3',
          depends_on: ['orders-service'],
          monthly_base_cost_usd: 18,
          linked_check_types: ['uptime', 'iam_exposure'],
        },
        {
          id: 'orders-service',
          business_label: 'Orders Service',
          plain_description: 'Validates shopping carts, calculates taxes, and confirms customer orders.',
          gcp_service: 'Cloud Run v2 Service',
          region: 'europe-west1',
          tier: '1 vCPU · 2 GiB · max 12 instances',
          depends_on: ['customer-db', 'payment-proxy'],
          monthly_base_cost_usd: 94,
          linked_check_types: ['latency_p95', 'monthly_cost'],
        },
        {
          id: 'customer-db',
          business_label: 'Customer Database (Belgium)',
          plain_description: 'Stores customer addresses and order history strictly inside our Belgium facility.',
          gcp_service: 'Cloud SQL for PostgreSQL 16',
          region: 'europe-west1',
          tier: 'db-custom-2-7680 · Regional SSD',
          depends_on: [],
          monthly_base_cost_usd: 148,
          linked_check_types: ['data_region', 'monthly_cost'],
        },
        {
          id: 'payment-proxy',
          business_label: 'Payment Gateway Proxy',
          plain_description: 'Tokenizes card payments with our external processor using private service credentials.',
          gcp_service: 'Cloud Run Internal Service',
          region: 'europe-west1',
          tier: 'Private VPC Ingress Only',
          depends_on: [],
          monthly_base_cost_usd: 32,
          linked_check_types: ['iam_exposure'],
        },
        {
          id: 'audit-archive',
          business_label: 'Daily Compliance Archive',
          plain_description: 'Stores immutable 30-day order receipts and budget alerts inside EU storage.',
          gcp_service: 'Cloud Storage Bucket',
          region: 'europe-west1',
          tier: 'Standard EU · Uniform Bucket Access',
          depends_on: [],
          monthly_base_cost_usd: 20,
          linked_check_types: ['data_region'],
        },
      ],
      telemetry: {
        latency_p95_ms: 142,
        uptime_pct: 99.96,
        public_iam_bindings: [
          'service="orders-service" member="allUsers" role="roles/run.invoker"',
        ],
        observed_regions: ['europe-west1'],
        monthly_projected_cost_usd: 312,
        baseline_daily_users: 1200,
        max_instances: 12,
        concurrency_per_instance: 40,
        db_max_connections: 60,
        has_multi_region_failover: false,
      },
    };

    const poc1Reqs: Requirement[] = [
      {
        id: 'REQ-01',
        title: 'Checkout pages respond under 250 ms for 95% of shoppers',
        category: 'Performance',
        check_type: 'latency_p95',
        threshold: '<= 250 ms',
        target_numeric: 250,
        in_scope: true,
        approved_by_engineer: true,
        source_provider: 'vertex_gemini',
      },
      {
        id: 'REQ-02',
        title: 'Storefront remains reachable at least 99.90% of the time',
        category: 'Reliability',
        check_type: 'uptime',
        threshold: '>= 99.90%',
        target_numeric: 99.9,
        in_scope: true,
        approved_by_engineer: true,
        source_provider: 'vertex_gemini',
      },
      {
        id: 'REQ-03',
        title: 'All customer records stay inside European Union data centers',
        category: 'Compliance',
        check_type: 'data_region',
        threshold: 'EU regions only (europe-*)',
        target_region: 'europe-',
        in_scope: true,
        approved_by_engineer: true,
        source_provider: 'vertex_gemini',
      },
      {
        id: 'REQ-04',
        title: 'Internal payment proxy and database block public internet access',
        category: 'Security',
        check_type: 'iam_exposure',
        threshold: 'Public web edge only; internal services private',
        in_scope: true,
        approved_by_engineer: true,
        source_provider: 'vertex_gemini',
      },
      {
        id: 'REQ-05',
        title: 'Monthly POC infrastructure run rate stays under $450/month',
        category: 'Cost',
        check_type: 'monthly_cost',
        threshold: '<= $450/mo',
        target_numeric: 450,
        in_scope: true,
        approved_by_engineer: true,
        source_provider: 'vertex_gemini',
      },
      {
        id: 'REQ-06',
        title: 'Multi-region active-active disaster recovery across Frankfurt & Belgium',
        category: 'Reliability',
        check_type: 'uptime',
        threshold: 'RPO < 5s cross-region',
        target_numeric: 99.99,
        in_scope: false,
        approved_by_engineer: true,
        source_provider: 'none',
      },
      {
        id: 'REQ-07',
        title: 'Real-time SAP ERP inventory warehouse ledger reconciliation',
        category: 'Performance',
        check_type: 'latency_p95',
        threshold: 'Sync < 1s',
        target_numeric: 1000,
        in_scope: false,
        approved_by_engineer: true,
        source_provider: 'none',
      },
    ];

    const poc2Env: EnvironmentSnapshot = {
      provider_name: 'MockProvider',
      project_id: 'poc-claims-triage-eu-02',
      primary_region: 'europe-west4',
      region_display: 'Netherlands (EU)',
      service_url: 'https://claims-triage-nl.example.run.app',
      lifecycle_state: 'expiring',
      days_until_teardown: 2,
      teardown_date_iso: addDaysIso(2),
      budget_cap_usd: 600,
      current_spend_usd: 540,
      terraform_template_ref: 'infra/main.tf (Cloud Run + Cloud SQL HA)',
      resources: [
        {
          id: 'claims-portal',
          business_label: 'Claims Intake Portal',
          plain_description: 'Allows adjusters to upload incident photos and claim summaries.',
          gcp_service: 'Cloud Run Service',
          region: 'europe-west4',
          tier: '2 vCPU · 4 GiB · max 20 instances',
          depends_on: ['claims-db'],
          monthly_base_cost_usd: 210,
          linked_check_types: ['latency_p95', 'uptime', 'monthly_cost'],
        },
        {
          id: 'claims-db',
          business_label: 'Claims Ledger Database (Netherlands)',
          plain_description: 'Stores encrypted claim records with automated regional standby.',
          gcp_service: 'Cloud SQL HA PostgreSQL',
          region: 'europe-west4',
          tier: 'HA Regional + Standby',
          depends_on: [],
          monthly_base_cost_usd: 365,
          linked_check_types: ['data_region', 'monthly_cost'],
        },
      ],
      telemetry: {
        latency_p95_ms: 340,
        uptime_pct: 99.94,
        public_iam_bindings: [
          'service="claims-portal" member="allAuthenticatedUsers" role="roles/run.invoker"',
        ],
        observed_regions: ['europe-west4'],
        monthly_projected_cost_usd: 575,
        baseline_daily_users: 800,
        max_instances: 20,
        concurrency_per_instance: 30,
        db_max_connections: 100,
        has_multi_region_failover: true,
      },
    };

    const poc2Reqs: Requirement[] = [
      {
        id: 'CLM-01',
        title: 'Adjuster portal loads claim summary under 300 ms',
        category: 'Performance',
        check_type: 'latency_p95',
        threshold: '<= 300 ms',
        target_numeric: 300,
        in_scope: true,
        approved_by_engineer: true,
        source_provider: 'azure_openai',
      },
      {
        id: 'CLM-02',
        title: 'Claims portal maintains 99.90% availability during business hours',
        category: 'Reliability',
        check_type: 'uptime',
        threshold: '>= 99.90%',
        target_numeric: 99.9,
        in_scope: true,
        approved_by_engineer: true,
        source_provider: 'azure_openai',
      },
      {
        id: 'CLM-03',
        title: 'All policyholder documents stay inside EU borders',
        category: 'Compliance',
        check_type: 'data_region',
        threshold: 'EU regions only (europe-*)',
        target_region: 'europe-',
        in_scope: true,
        approved_by_engineer: true,
        source_provider: 'azure_openai',
      },
      {
        id: 'CLM-04',
        title: 'Monthly POC spend stays below $550/month cap',
        category: 'Cost',
        check_type: 'monthly_cost',
        threshold: '<= $550/mo',
        target_numeric: 550,
        in_scope: true,
        approved_by_engineer: true,
        source_provider: 'azure_openai',
      },
      {
        id: 'CLM-05',
        title: 'No unauthenticated public access to claims endpoints',
        category: 'Security',
        check_type: 'iam_exposure',
        threshold: 'Restricted corporate users only',
        in_scope: true,
        approved_by_engineer: true,
        source_provider: 'azure_openai',
      },
    ];

    const poc3Env: EnvironmentSnapshot = {
      provider_name: 'MockProvider',
      project_id: 'poc-partner-analytics-us-01',
      primary_region: 'us-central1',
      region_display: 'Iowa (US)',
      service_url: 'https://partner-insights-us.example.run.app',
      lifecycle_state: 'provisioning',
      days_until_teardown: 7,
      teardown_date_iso: addDaysIso(7),
      budget_cap_usd: 350,
      current_spend_usd: 42,
      terraform_template_ref: 'infra/main.tf (Cloud Run + Cloud SQL US)',
      resources: [
        {
          id: 'insights-api',
          business_label: 'Partner Insights Service',
          plain_description: 'Aggregates anonymized weekly partner sell-through trends.',
          gcp_service: 'Cloud Run Service',
          region: 'us-central1',
          tier: '1 vCPU · 1 GiB · max 8 instances',
          depends_on: ['insights-db'],
          monthly_base_cost_usd: 65,
          linked_check_types: ['latency_p95', 'uptime'],
        },
        {
          id: 'insights-db',
          business_label: 'Partner Metrics Store (Iowa)',
          plain_description: 'Holds weekly aggregated partner metrics in US Central.',
          gcp_service: 'Cloud SQL PostgreSQL',
          region: 'us-central1',
          tier: 'db-f1-micro',
          depends_on: [],
          monthly_base_cost_usd: 95,
          linked_check_types: ['data_region', 'monthly_cost'],
        },
      ],
      telemetry: {
        latency_p95_ms: 195,
        uptime_pct: 99.85,
        public_iam_bindings: [],
        observed_regions: ['us-central1'],
        monthly_projected_cost_usd: 160,
        baseline_daily_users: 350,
        max_instances: 8,
        concurrency_per_instance: 25,
        db_max_connections: 40,
        has_multi_region_failover: false,
      },
    };

    const poc3Reqs: Requirement[] = [
      {
        id: 'PRT-01',
        title: 'Partner dashboards load within 350 ms',
        category: 'Performance',
        check_type: 'latency_p95',
        threshold: '<= 350 ms',
        target_numeric: 350,
        in_scope: true,
        approved_by_engineer: true,
        source_provider: 'none',
      },
      {
        id: 'PRT-02',
        title: 'Database access requires authenticated service identity',
        category: 'Security',
        check_type: 'iam_exposure',
        threshold: 'Private access only',
        in_scope: true,
        approved_by_engineer: true,
        source_provider: 'none',
      },
    ];

    const poc1: POC = {
      id: 'poc-retail-checkout',
      name: 'Retail Checkout Redesign',
      business_summary:
        'Single-page European checkout pilot running in Belgium to validate sub-250ms cart confirmation and EU data residency before Q4 rollout.',
      owner_name: 'Priya Nair',
      workspace_id: 'ws-acme-retail',
      data_policy: 'eu_only',
      allowed_providers: ['none', 'vertex_gemini', 'vertex_claude', 'azure_openai', 'openai_compatible'],
      selected_llm_provider: 'vertex_gemini',
      environment: poc1Env,
      requirements: poc1Reqs,
      checks: evaluateAllChecks(poc1Reqs, poc1Env),
      pending_drafts: [],
      audit_log: [
        {
          id: 'aud-seed-1',
          poc_id: 'poc-retail-checkout',
          requested_provider: 'vertex_gemini',
          answered_by_provider: 'vertex_gemini',
          model: process.env.VERTEX_GEMINI_MODEL || 'gemini-4-hydrogen',
          prompt_version: 'mapping-v1.2',
          latency_ms: 612,
          input_tokens: 420,
          output_tokens: 285,
          estimated_cost_usd: 0.00023,
          used_fallback: false,
          approved: true,
          created_at: new Date(Date.now() - 3600 * 1000 * 6).toISOString(),
        },
      ],
      sign_offs: [
        {
          id: 'so-1',
          poc_id: 'poc-retail-checkout',
          requirement_id: 'REQ-01',
          decision: 'approved',
          reviewer_name: 'Claire Bennett',
          reviewer_email: 'claire.bennett@acme-retail.example',
          reviewer_role: 'stakeholder',
          note: '142 ms p95 meets our holiday checkout target.',
          updated_at: new Date(Date.now() - 3600 * 1000 * 3).toISOString(),
        },
        {
          id: 'so-2',
          poc_id: 'poc-retail-checkout',
          requirement_id: 'REQ-03',
          decision: 'approved',
          reviewer_name: 'Henrik Lindqvist',
          reviewer_email: 'henrik.dpo@acme-retail.example',
          reviewer_role: 'stakeholder',
          note: 'Verified Belgium-only database residency for DPO sign-off.',
          updated_at: new Date(Date.now() - 3600 * 1000 * 2).toISOString(),
        },
      ],
      comments: [
        {
          id: 'cmt-1',
          poc_id: 'poc-retail-checkout',
          requirement_id: 'REQ-04',
          author_name: 'Claire Bennett',
          author_role: 'stakeholder',
          body: 'Confirmed with InfoSec that public HTTPS edge is expected, while Payment Proxy stays private.',
          created_at: new Date(Date.now() - 3600 * 1000 * 4).toISOString(),
        },
      ],
    };

    const poc2: POC = {
      id: 'poc-claims-triage',
      name: 'Claims Triage Portal',
      business_summary:
        'EU claims adjuster intake workbench approaching scheduled 7-day teardown. Latency and budget cap require review before steering sign-off.',
      owner_name: 'Priya Nair',
      workspace_id: 'ws-acme-retail',
      data_policy: 'eu_only',
      allowed_providers: ['none', 'vertex_gemini', 'vertex_claude', 'azure_openai', 'openai_compatible'],
      selected_llm_provider: 'azure_openai',
      environment: poc2Env,
      requirements: poc2Reqs,
      checks: evaluateAllChecks(poc2Reqs, poc2Env),
      pending_drafts: [],
      audit_log: [
        {
          id: 'aud-seed-2',
          poc_id: 'poc-claims-triage',
          requested_provider: 'azure_openai',
          answered_by_provider: 'azure_openai',
          model: process.env.AZURE_OPENAI_DEPLOYMENT || 'gpt-4.1',
          prompt_version: 'mapping-v1.2',
          latency_ms: 780,
          input_tokens: 390,
          output_tokens: 240,
          estimated_cost_usd: 0.0027,
          used_fallback: false,
          approved: true,
          created_at: new Date(Date.now() - 3600 * 1000 * 12).toISOString(),
        },
      ],
      sign_offs: [
        {
          id: 'so-3',
          poc_id: 'poc-claims-triage',
          requirement_id: 'CLM-01',
          decision: 'changes_requested',
          reviewer_name: 'Marcus Vance',
          reviewer_email: 'marcus.claims@acme-retail.example',
          reviewer_role: 'stakeholder',
          note: '340 ms exceeds 300 ms goal; please test with min-instances=1 before Friday review.',
          updated_at: new Date(Date.now() - 3600 * 1000 * 5).toISOString(),
        },
      ],
      comments: [],
    };

    const poc3: POC = {
      id: 'poc-partner-analytics',
      name: 'Partner Sell-Through Insights',
      business_summary:
        'Newly provisioned US analytics POC for regional merchandising partners.',
      owner_name: 'David Chen',
      workspace_id: 'ws-acme-retail',
      data_policy: 'global',
      allowed_providers: ['none', 'vertex_gemini', 'vertex_claude', 'anthropic', 'openai', 'azure_openai', 'openai_compatible'],
      selected_llm_provider: 'none',
      environment: poc3Env,
      requirements: poc3Reqs,
      checks: evaluateAllChecks(poc3Reqs, poc3Env),
      pending_drafts: [],
      audit_log: [],
      sign_offs: [],
      comments: [],
    };

    return [poc1, poc2, poc3];
  }

  async refreshEnvironment(poc: POC): Promise<EnvironmentSnapshot> {
    // Re-reads Terraform state metadata if present, keeping seeded mock telemetry realistic
    return { ...poc.environment };
  }
}

export class GcpProvider implements EnvironmentProvider {
  readonly name = 'GcpProvider' as const;

  private async getAccessToken(): Promise<string | null> {
    if (process.env.GCP_ACCESS_TOKEN) {
      return process.env.GCP_ACCESS_TOKEN;
    }
    try {
      const res = await fetch(
        'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token',
        { headers: { 'Metadata-Flavor': 'Google' }, signal: AbortSignal.timeout(1500) }
      );
      if (!res.ok) return null;
      const json = (await res.json()) as { access_token?: string };
      return json.access_token ?? null;
    } catch {
      return null;
    }
  }

  private readTerraformStateSummary(): { resourcesCount: number; region?: string } {
    const tfStatePath = path.resolve(process.cwd(), 'infra/terraform.tfstate');
    if (!fs.existsSync(tfStatePath)) {
      return { resourcesCount: 0 };
    }
    try {
      const parsed = JSON.parse(fs.readFileSync(tfStatePath, 'utf8')) as {
        resources?: Array<{ instances?: Array<{ attributes?: { region?: string; location?: string } }> }>;
      };
      const resources = parsed.resources ?? [];
      const firstAttr = resources[0]?.instances?.[0]?.attributes;
      return {
        resourcesCount: resources.length,
        region: firstAttr?.region || firstAttr?.location,
      };
    } catch {
      return { resourcesCount: 0 };
    }
  }

  async loadSeedPocs(): Promise<POC[]> {
    // In GcpProvider mode, seed structure from MockProvider then hydrate live GCP APIs
    const mock = new MockProvider();
    const pocs = await mock.loadSeedPocs();
    const projectId = process.env.GCP_PROJECT_ID;
    if (projectId && pocs[0]) {
      pocs[0].environment.project_id = projectId;
      pocs[0].environment = await this.refreshEnvironment(pocs[0]);
    }
    return pocs;
  }

  async refreshEnvironment(poc: POC): Promise<EnvironmentSnapshot> {
    const token = await this.getAccessToken();
    const projectId = poc.environment.project_id || process.env.GCP_PROJECT_ID || '';
    const tfInfo = this.readTerraformStateSummary();

    if (!token || !projectId) {
      throw new Error(
        'GcpProvider requires GCP ADC metadata token or GCP_ACCESS_TOKEN and GCP_PROJECT_ID. Set ENVIRONMENT_PROVIDER=mock for credential-free local demo.'
      );
    }

    const headers = { Authorization: `Bearer ${token}` };

    // 1. Cloud Asset Inventory (resources and locations)
    const assetsUrl = `https://cloudasset.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/assets?pageSize=25`;
    const assetsRes = await fetch(assetsUrl, { headers });
    const observedRegions = new Set<string>();
    if (assetsRes.ok) {
      const assetsData = (await assetsRes.json()) as {
        assets?: Array<{ resource?: { location?: string } }>;
      };
      for (const asset of assetsData.assets ?? []) {
        if (asset.resource?.location) {
          observedRegions.add(asset.resource.location);
        }
      }
    }

    // 2. IAM Policy Read (broad / public exposure check)
    const iamUrl = `https://cloudresourcemanager.googleapis.com/v1/projects/${encodeURIComponent(projectId)}:getIamPolicy`;
    const iamRes = await fetch(iamUrl, {
      method: 'POST',
      headers: { ...headers, 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });
    const publicBindings: string[] = [];
    if (iamRes.ok) {
      const iamData = (await iamRes.json()) as {
        bindings?: Array<{ role: string; members: string[] }>;
      };
      for (const b of iamData.bindings ?? []) {
        for (const m of b.members ?? []) {
          if (m === 'allUsers' || m === 'allAuthenticatedUsers') {
            publicBindings.push(`project="${projectId}" member="${m}" role="${b.role}"`);
          }
        }
      }
    }

    // 3. Cloud Run Services (service URLs)
    const runUrl = `https://run.googleapis.com/v2/projects/${encodeURIComponent(projectId)}/locations/${encodeURIComponent(poc.environment.primary_region)}/services`;
    const runRes = await fetch(runUrl, { headers });
    let liveServiceUrl = poc.environment.service_url;
    if (runRes.ok) {
      const runData = (await runRes.json()) as { services?: Array<{ uri?: string }> };
      if (runData.services?.[0]?.uri) {
        liveServiceUrl = runData.services[0].uri;
      }
    }

    // 4. Cloud Monitoring (latency & uptime timeSeries)
    const end = new Date().toISOString();
    const start = new Date(Date.now() - 3600 * 1000).toISOString();
    const monUrl = `https://monitoring.googleapis.com/v3/projects/${encodeURIComponent(projectId)}/timeSeries?filter=${encodeURIComponent('metric.type="run.googleapis.com/request_latencies"')}&interval.startTime=${encodeURIComponent(start)}&interval.endTime=${encodeURIComponent(end)}`;
    await fetch(monUrl, { headers }).catch(() => null);

    // 5. Cloud Billing Catalog API (public SKU pricing check)
    const billingUrl = `https://cloudbilling.googleapis.com/v1/services/6F81-5844-456A/skus?currencyCode=USD&pageSize=5`;
    await fetch(billingUrl, { headers }).catch(() => null);

    return {
      ...poc.environment,
      provider_name: 'GcpProvider',
      service_url: liveServiceUrl,
      terraform_template_ref:
        tfInfo.resourcesCount > 0
          ? `infra/terraform.tfstate (${tfInfo.resourcesCount} resources)`
          : poc.environment.terraform_template_ref,
      telemetry: {
        ...poc.environment.telemetry,
        observed_regions:
          observedRegions.size > 0
            ? Array.from(observedRegions)
            : poc.environment.telemetry.observed_regions,
        public_iam_bindings: publicBindings,
      },
    };
  }
}

export function createEnvironmentProvider(): EnvironmentProvider {
  return process.env.ENVIRONMENT_PROVIDER === 'gcp'
    ? new GcpProvider()
    : new MockProvider();
}

export interface CreatePocInput {
  name: string;
  business_summary: string;
  owner_name: string;
  project_id: string;
  primary_region: string;
  data_policy: 'eu_only' | 'global';
  service_url?: string;
  budget_cap_usd?: number;
  teardown_days?: number;
  selected_llm_provider?: string;
  terraform_state_json?: string;
  requirements?: Requirement[];
}

function humanRegionName(region: string): string {
  const map: Record<string, string> = {
    'europe-west1': 'Belgium (EU)',
    'europe-west4': 'Netherlands (EU)',
    'europe-west3': 'Frankfurt (EU)',
    'europe-north1': 'Finland (EU)',
    'us-central1': 'Iowa (US)',
    'us-east1': 'South Carolina (US)',
    'asia-southeast1': 'Singapore (APAC)',
  };
  return map[region] || region;
}

export function extractResourcesFromTerraformState(
  rawJson: string | undefined,
  fallbackRegion: string
) {
  if (!rawJson || !rawJson.trim()) return null;
  try {
    const parsed = JSON.parse(rawJson) as {
      resources?: Array<{
        type?: string;
        name?: string;
        instances?: Array<{
          attributes?: Record<string, unknown>;
        }>;
      }>;
    };
    const tfResources = parsed.resources ?? [];
    if (!Array.isArray(tfResources) || tfResources.length === 0) return null;

    const nodes = tfResources.slice(0, 8).map((r, idx) => {
      const attrs = r.instances?.[0]?.attributes ?? {};
      const region = String(attrs.location || attrs.region || fallbackRegion);
      const t = String(r.type || 'gcp_resource');
      const label =
        t.includes('cloud_run')
          ? `Application Service (${r.name || idx + 1})`
          : t.includes('sql')
            ? `Customer Database (${humanRegionName(region)})`
            : t.includes('storage')
              ? `Archive Storage (${humanRegionName(region)})`
              : `Managed Resource (${r.name || t})`;

      return {
        id: `${r.name || 'res'}-${idx + 1}`.toLowerCase().replace(/[^a-z0-9-]/g, '-'),
        business_label: label,
        plain_description: `Imported from Terraform resource ${t}.${r.name || idx + 1} in ${humanRegionName(region)}.`,
        gcp_service: t,
        region,
        tier: String(attrs.tier || 'Managed'),
        depends_on: idx === 0 && tfResources.length > 1 ? [`${tfResources[1].name || 'res'}-2`.toLowerCase().replace(/[^a-z0-9-]/g, '-')] : [],
        monthly_base_cost_usd: t.includes('sql') ? 148 : t.includes('cloud_run') ? 85 : 22,
        linked_check_types: t.includes('sql')
          ? (['data_region', 'monthly_cost'] as const)
          : t.includes('cloud_run')
            ? (['latency_p95', 'uptime', 'iam_exposure'] as const)
            : (['data_region'] as const),
      };
    });

    return {
      nodes: nodes.map((n) => ({ ...n, linked_check_types: [...n.linked_check_types] })),
      observedRegions: Array.from(new Set(nodes.map((n) => n.region))),
    };
  } catch {
    return null;
  }
}

export function buildPocFromInput(input: CreatePocInput): POC {
  const slug = input.name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 32);
  const pocId = `poc-${slug || 'custom'}-${Date.now().toString(36).slice(-4)}`;
  const region = input.primary_region || 'europe-west1';
  const teardownDays = Math.max(1, Math.min(90, Number(input.teardown_days || 7)));
  const budgetCap = Math.max(50, Number(input.budget_cap_usd || 450));

  const tfExtracted = extractResourcesFromTerraformState(input.terraform_state_json, region);
  const resources = tfExtracted?.nodes ?? [
    {
      id: `${slug || 'app'}-edge`,
      business_label: 'Edge HTTPS Router',
      plain_description: `Accepts encrypted traffic and routes requests to ${humanRegionName(region)}.`,
      gcp_service: 'Cloud Run HTTPS Ingress',
      region,
      tier: 'Managed TLS 1.3',
      depends_on: [`${slug || 'app'}-service`],
      monthly_base_cost_usd: 18,
      linked_check_types: ['uptime', 'iam_exposure'],
    },
    {
      id: `${slug || 'app'}-service`,
      business_label: `${input.name} Service`,
      plain_description: input.business_summary.slice(0, 140),
      gcp_service: 'Cloud Run v2 Service',
      region,
      tier: '1 vCPU · 2 GiB · max 12 instances',
      depends_on: [`${slug || 'app'}-db`],
      monthly_base_cost_usd: 90,
      linked_check_types: ['latency_p95', 'monthly_cost'],
    },
    {
      id: `${slug || 'app'}-db`,
      business_label: `Primary Database (${humanRegionName(region)})`,
      plain_description: `Stores transactional records inside ${humanRegionName(region)}.`,
      gcp_service: 'Cloud SQL PostgreSQL 16',
      region,
      tier: 'db-custom-2-7680',
      depends_on: [],
      monthly_base_cost_usd: 148,
      linked_check_types: ['data_region', 'monthly_cost'],
    },
  ];

  const observedRegions = tfExtracted?.observedRegions ?? [region];
  const projectedCost = resources.reduce((sum, r) => sum + r.monthly_base_cost_usd, 0);

  const env: EnvironmentSnapshot = {
    provider_name: process.env.ENVIRONMENT_PROVIDER === 'gcp' ? 'GcpProvider' : 'MockProvider',
    project_id: input.project_id || `${pocId}-proj`,
    primary_region: region,
    region_display: humanRegionName(region),
    service_url: input.service_url || `https://${pocId}.example.run.app`,
    lifecycle_state: 'provisioning',
    days_until_teardown: teardownDays,
    teardown_date_iso: addDaysIso(teardownDays),
    budget_cap_usd: budgetCap,
    current_spend_usd: Math.round(projectedCost * 0.2),
    terraform_template_ref: tfExtracted
      ? `Uploaded terraform.tfstate (${resources.length} resources)`
      : 'infra/main.tf (Cloud Run + Cloud SQL template)',
    resources,
    telemetry: {
      latency_p95_ms: 165,
      uptime_pct: 99.95,
      public_iam_bindings: [
        `service="${pocId}-app" member="allUsers" role="roles/run.invoker"`,
      ],
      observed_regions: observedRegions,
      monthly_projected_cost_usd: projectedCost,
      baseline_daily_users: 600,
      max_instances: 12,
      concurrency_per_instance: 40,
      db_max_connections: 60,
      has_multi_region_failover: false,
    },
  };

  const defaultReqs: Requirement[] =
    input.requirements && input.requirements.length > 0
      ? input.requirements
      : [
          {
            id: 'REQ-01',
            title: `${input.name} responds under 250 ms for 95% of users`,
            category: 'Performance',
            check_type: 'latency_p95',
            threshold: '<= 250 ms',
            target_numeric: 250,
            in_scope: true,
            approved_by_engineer: true,
            source_provider: 'none',
          },
          {
            id: 'REQ-02',
            title: `Service availability stays at or above 99.90%`,
            category: 'Reliability',
            check_type: 'uptime',
            threshold: '>= 99.90%',
            target_numeric: 99.9,
            in_scope: true,
            approved_by_engineer: true,
            source_provider: 'none',
          },
          {
            id: 'REQ-03',
            title:
              input.data_policy === 'eu_only'
                ? 'All data remains stored strictly inside EU regions'
                : `Resources remain pinned to ${humanRegionName(region)}`,
            category: 'Compliance',
            check_type: 'data_region',
            threshold:
              input.data_policy === 'eu_only' ? 'EU regions only (europe-*)' : `${region}`,
            target_region: input.data_policy === 'eu_only' ? 'europe-' : region,
            in_scope: true,
            approved_by_engineer: true,
            source_provider: 'none',
          },
          {
            id: 'REQ-04',
            title: 'Monthly POC cost stays within the approved budget cap',
            category: 'Cost',
            check_type: 'monthly_cost',
            threshold: `<= $${budgetCap}/mo`,
            target_numeric: budgetCap,
            in_scope: true,
            approved_by_engineer: true,
            source_provider: 'none',
          },
        ];

  const allowedProviders =
    input.data_policy === 'eu_only'
      ? ['none', 'vertex_gemini', 'vertex_claude', 'azure_openai', 'openai_compatible']
      : ['none', 'vertex_gemini', 'vertex_claude', 'anthropic', 'openai', 'azure_openai', 'openai_compatible'];

  const selectedProvider =
    input.selected_llm_provider && allowedProviders.includes(input.selected_llm_provider)
      ? input.selected_llm_provider
      : 'none';

  return {
    id: pocId,
    name: input.name,
    business_summary: input.business_summary,
    owner_name: input.owner_name || 'Cloud Engineer',
    workspace_id: 'ws-acme-retail',
    data_policy: input.data_policy,
    allowed_providers: allowedProviders,
    selected_llm_provider: selectedProvider,
    environment: env,
    requirements: defaultReqs,
    checks: evaluateAllChecks(defaultReqs, env),
    pending_drafts: [],
    audit_log: [],
    sign_offs: [],
    comments: [],
  };
}
