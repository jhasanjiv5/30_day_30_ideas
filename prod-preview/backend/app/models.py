from __future__ import annotations

from typing import Literal, Optional
from pydantic import BaseModel, Field

LifecycleState = Literal["provisioning", "live", "expiring", "torn_down"]
CheckType = Literal["latency_p95", "uptime", "data_region", "iam_exposure", "monthly_cost"]
CheckStatus = Literal["pass", "warn", "fail"]
MeasurementKind = Literal["measured", "projected"]
UserRole = Literal["engineer", "stakeholder"]
SignOffDecision = Literal["approved", "changes_requested", "pending"]


class ResourceNode(BaseModel):
    id: str
    business_label: str
    plain_description: str
    gcp_service: str
    region: str
    tier: str
    depends_on: list[str] = Field(default_factory=list)
    monthly_base_cost_usd: float
    linked_check_types: list[CheckType] = Field(default_factory=list)


class Requirement(BaseModel):
    id: str
    title: str
    category: Literal["Performance", "Reliability", "Compliance", "Security", "Cost"]
    check_type: CheckType
    threshold: str
    target_numeric: Optional[float] = None
    target_region: Optional[str] = None
    in_scope: bool = True
    approved_by_engineer: bool = True
    source_provider: Optional[str] = None


class CheckEvidence(BaseModel):
    source_api: str
    metric_name: str
    resource_id: str
    resource_label: str
    policy_line: Optional[str] = None
    observed_summary: str
    raw_excerpt: str
    observed_at: str


class CheckResult(BaseModel):
    id: str
    requirement_id: str
    check_type: CheckType
    status: CheckStatus
    measured_or_projected: MeasurementKind
    actual_display: str
    threshold_display: str
    plain_explanation: str
    evidence: CheckEvidence


class WhatIfParams(BaseModel):
    users_multiplier: int = Field(default=1, ge=1, le=100)
    traffic_spike: float = Field(default=1.0, ge=1.0, le=10.0)
    region_outage: bool = False


class CostBreakdownRow(BaseModel):
    item: str
    sku_reference: str
    monthly_usd: float


class WhatIfProjection(BaseModel):
    params: WhatIfParams
    baseline: dict[str, float | int]
    projected: dict[str, float | int]
    what_breaks: str
    cost_breakdown: list[CostBreakdownRow]
    measured_or_projected: Literal["projected"] = "projected"


class MappingDraftItem(BaseModel):
    id: str = Field(min_length=2)
    title: str = Field(min_length=4)
    category: Literal["Performance", "Reliability", "Compliance", "Security", "Cost"]
    check_type: CheckType
    threshold: str = Field(min_length=1)
    in_scope: bool
    rationale: str = Field(min_length=3)


class LLMAuditRecord(BaseModel):
    id: str
    poc_id: str
    requested_provider: str
    answered_by_provider: str
    model: str
    prompt_version: str
    latency_ms: int
    input_tokens: int
    output_tokens: int
    estimated_cost_usd: float
    used_fallback: bool
    approved: bool
    created_at: str


class MappingDraftBatch(BaseModel):
    id: str
    poc_id: str
    source_text: str
    items: list[MappingDraftItem]
    audit: LLMAuditRecord
    status: Literal["pending_approval", "approved", "rejected"] = "pending_approval"


class SignOffRecord(BaseModel):
    id: str
    poc_id: str
    requirement_id: str
    decision: SignOffDecision
    reviewer_name: str
    reviewer_email: str
    reviewer_role: UserRole
    note: str = ""
    updated_at: str


class CommentRecord(BaseModel):
    id: str
    poc_id: str
    requirement_id: str
    author_name: str
    author_role: UserRole
    body: str
    created_at: str


class TelemetrySnapshot(BaseModel):
    latency_p95_ms: float
    uptime_pct: float
    public_iam_bindings: list[str]
    observed_regions: list[str]
    monthly_projected_cost_usd: float
    baseline_daily_users: int
    max_instances: int
    concurrency_per_instance: int
    db_max_connections: int
    has_multi_region_failover: bool


class EnvironmentSnapshot(BaseModel):
    provider_name: Literal["MockProvider", "GcpProvider"]
    project_id: str
    primary_region: str
    region_display: str
    service_url: str
    lifecycle_state: LifecycleState
    days_until_teardown: int
    teardown_date_iso: str
    budget_cap_usd: float
    current_spend_usd: float
    terraform_template_ref: str
    resources: list[ResourceNode]
    telemetry: TelemetrySnapshot


class POC(BaseModel):
    id: str
    name: str
    business_summary: str
    owner_name: str
    workspace_id: str
    data_policy: Literal["eu_only", "global"]
    allowed_providers: list[str]
    selected_llm_provider: str
    environment: EnvironmentSnapshot
    requirements: list[Requirement]
    checks: list[CheckResult]
    pending_drafts: list[MappingDraftBatch] = Field(default_factory=list)
    audit_log: list[LLMAuditRecord] = Field(default_factory=list)
    sign_offs: list[SignOffRecord] = Field(default_factory=list)
    comments: list[CommentRecord] = Field(default_factory=list)
