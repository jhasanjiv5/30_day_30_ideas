export type EnvironmentLifecycleState = 'provisioning' | 'live' | 'expiring' | 'torn_down';

export type CheckType =
  | 'latency_p95'
  | 'uptime'
  | 'data_region'
  | 'iam_exposure'
  | 'monthly_cost';

export type CheckStatus = 'pass' | 'warn' | 'fail';
export type MeasurementKind = 'measured' | 'projected';
export type UserRole = 'engineer' | 'stakeholder';
export type SignOffDecision = 'approved' | 'changes_requested' | 'pending';

export interface ResourceNode {
  id: string;
  business_label: string;
  plain_description: string;
  gcp_service: string;
  region: string;
  tier: string;
  depends_on: string[];
  monthly_base_cost_usd: number;
  linked_check_types: CheckType[];
}

export interface Requirement {
  id: string;
  title: string;
  category: 'Performance' | 'Reliability' | 'Compliance' | 'Security' | 'Cost';
  check_type: CheckType;
  threshold: string;
  target_numeric?: number;
  target_region?: string;
  in_scope: boolean;
  approved_by_engineer: boolean;
  source_provider?: string;
}

export interface CheckEvidence {
  source_api: string;
  metric_name: string;
  resource_id: string;
  resource_label: string;
  policy_line?: string;
  observed_summary: string;
  raw_excerpt: string;
  observed_at: string;
}

export interface CheckResult {
  id: string;
  requirement_id: string;
  check_type: CheckType;
  status: CheckStatus;
  measured_or_projected: MeasurementKind;
  actual_display: string;
  threshold_display: string;
  plain_explanation: string;
  evidence: CheckEvidence;
}

export interface WhatIfParams {
  users_multiplier: number; // 1 to 100
  traffic_spike: number;    // 1 to 10
  region_outage: boolean;
}

export interface WhatIfProjection {
  params: WhatIfParams;
  baseline: {
    latency_p95_ms: number;
    monthly_cost_usd: number;
    availability_pct: number;
    active_instances: number;
  };
  projected: {
    latency_p95_ms: number;
    monthly_cost_usd: number;
    availability_pct: number;
    active_instances: number;
    cold_start_penalty_ms: number;
    concurrency_utilization_pct: number;
  };
  what_breaks: string;
  cost_breakdown: Array<{
    item: string;
    sku_reference: string;
    monthly_usd: number;
  }>;
  measured_or_projected: 'projected';
}

export interface SignOffRecord {
  id: string;
  poc_id: string;
  requirement_id: string;
  decision: SignOffDecision;
  reviewer_name: string;
  reviewer_email: string;
  reviewer_role: UserRole;
  note: string;
  updated_at: string;
}

export interface CommentRecord {
  id: string;
  poc_id: string;
  requirement_id: string;
  author_name: string;
  author_role: UserRole;
  body: string;
  created_at: string;
}

export interface MappingDraftItem {
  id: string;
  title: string;
  category: 'Performance' | 'Reliability' | 'Compliance' | 'Security' | 'Cost';
  check_type: CheckType;
  threshold: string;
  in_scope: boolean;
  rationale: string;
}

export interface LLMAuditRecord {
  id: string;
  poc_id: string;
  requested_provider: string;
  answered_by_provider: string;
  model: string;
  prompt_version: string;
  latency_ms: number;
  input_tokens: number;
  output_tokens: number;
  estimated_cost_usd: number;
  used_fallback: boolean;
  approved: boolean;
  created_at: string;
}

export interface MappingDraftBatch {
  id: string;
  poc_id: string;
  source_text: string;
  items: MappingDraftItem[];
  audit: LLMAuditRecord;
  status: 'pending_approval' | 'approved' | 'rejected';
}

export interface ProviderCatalogItem {
  id: string;
  display_name: string;
  adapter: string;
  model: string;
  region: string;
  eu_data_residency: boolean;
  structured_output: boolean;
  max_context_tokens: number;
  cost_per_1k_input_usd: number;
  cost_per_1k_output_usd: number;
  description: string;
  enabled_in_workspace: boolean;
  allowed_by_poc_policy: boolean;
  unavailable_reason: string | null;
  has_server_key: boolean;
  has_byok_key: boolean;
  requires_key_env: string;
}

export interface EnvironmentSnapshot {
  provider_name: 'MockProvider' | 'GcpProvider';
  project_id: string;
  primary_region: string;
  region_display: string;
  service_url: string;
  lifecycle_state: EnvironmentLifecycleState;
  days_until_teardown: number;
  teardown_date_iso: string;
  budget_cap_usd: number;
  current_spend_usd: number;
  terraform_template_ref: string;
  resources: ResourceNode[];
  telemetry: {
    latency_p95_ms: number;
    uptime_pct: number;
    public_iam_bindings: string[];
    observed_regions: string[];
    monthly_projected_cost_usd: number;
    baseline_daily_users: number;
    max_instances: number;
    concurrency_per_instance: number;
    db_max_connections: number;
    has_multi_region_failover: boolean;
  };
}

export interface POC {
  id: string;
  name: string;
  business_summary: string;
  owner_name: string;
  workspace_id: string;
  data_policy: 'eu_only' | 'global';
  allowed_providers: string[];
  selected_llm_provider: string;
  environment: EnvironmentSnapshot;
  requirements: Requirement[];
  checks: CheckResult[];
  pending_drafts: MappingDraftBatch[];
  audit_log: LLMAuditRecord[];
  sign_offs: SignOffRecord[];
  comments: CommentRecord[];
}

export interface UserAccountPublic {
  id: string;
  name: string;
  email: string;
  role: UserRole;
  auth_provider: 'password' | 'google_identity';
  created_at: string;
  last_login_at: string;
}

export interface AuthSession {
  authenticated: boolean;
  user_id?: string;
  user_name: string;
  user_email: string;
  role: UserRole;
  auth_method: 'password' | 'google_identity' | 'invite_link' | 'demo_session' | 'none';
  scoped_poc_id: string | null;
  invite_expires_at: string | null;
}

export type ProjectHistoryAction =
  | 'viewed'
  | 'created_poc'
  | 'ran_whatif'
  | 'signed_off'
  | 'commented'
  | 'drafted_mapping'
  | 'approved_mapping'
  | 'rechecked'
  | 'exported_pdf'
  | 'created_invite';

export interface ProjectHistoryEntry {
  id: string;
  user_email: string;
  user_name: string;
  user_role: UserRole;
  poc_id: string;
  poc_name: string;
  action: ProjectHistoryAction;
  summary: string;
  tab?: string;
  timestamp: string;
}

export interface UserRecentPocSummary {
  poc_id: string;
  poc_name: string;
  last_accessed_at: string;
  last_action: ProjectHistoryAction;
  last_tab?: string;
  interaction_count: number;
}

export interface CompareResult {
  left_provider: string;
  right_provider: string;
  left_batch: MappingDraftBatch;
  right_batch: MappingDraftBatch;
  differences: Array<{
    index: number;
    title_left: string;
    title_right: string;
    changed_fields: string[];
  }>;
}
