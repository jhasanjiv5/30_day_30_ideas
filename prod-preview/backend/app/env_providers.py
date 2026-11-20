from __future__ import annotations

import json
import os
from abc import ABC, abstractmethod
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import httpx

from .checks import evaluate_all_checks
from .models import EnvironmentSnapshot, POC, Requirement, ResourceNode, TelemetrySnapshot


class EnvironmentProvider(ABC):
    name: str

    @abstractmethod
    async def load_seed_pocs(self) -> list[POC]:
        ...

    @abstractmethod
    async def refresh_environment(self, poc: POC) -> EnvironmentSnapshot:
        ...


class MockProvider(EnvironmentProvider):
    name = "MockProvider"

    async def load_seed_pocs(self) -> list[POC]:
        teardown_5d = (datetime.now(timezone.utc) + timedelta(days=5)).date().isoformat()
        env1 = EnvironmentSnapshot(
            provider_name="MockProvider",
            project_id="poc-retail-checkout-eu-04",
            primary_region="europe-west1",
            region_display="Belgium (EU)",
            service_url="https://checkout-preview-eu.example.run.app",
            lifecycle_state="live",
            days_until_teardown=5,
            teardown_date_iso=teardown_5d,
            budget_cap_usd=450,
            current_spend_usd=184,
            terraform_template_ref="infra/main.tf (Cloud Run + Cloud SQL EU)",
            resources=[
                ResourceNode(
                    id="edge-https-lb",
                    business_label="Edge HTTPS Router",
                    plain_description="Receives encrypted customer checkout requests.",
                    gcp_service="Cloud Run Domain Mapping / HTTPS LB",
                    region="europe-west1",
                    tier="Managed TLS 1.3",
                    depends_on=["orders-service"],
                    monthly_base_cost_usd=18,
                    linked_check_types=["uptime", "iam_exposure"],
                ),
                ResourceNode(
                    id="orders-service",
                    business_label="Orders Service",
                    plain_description="Validates carts and confirms customer orders.",
                    gcp_service="Cloud Run v2 Service",
                    region="europe-west1",
                    tier="1 vCPU · 2 GiB · max 12 instances",
                    depends_on=["customer-db"],
                    monthly_base_cost_usd=94,
                    linked_check_types=["latency_p95", "monthly_cost"],
                ),
                ResourceNode(
                    id="customer-db",
                    business_label="Customer Database (Belgium)",
                    plain_description="Stores customer addresses and orders inside Belgium.",
                    gcp_service="Cloud SQL PostgreSQL 16",
                    region="europe-west1",
                    tier="db-custom-2-7680",
                    depends_on=[],
                    monthly_base_cost_usd=148,
                    linked_check_types=["data_region", "monthly_cost"],
                ),
            ],
            telemetry=TelemetrySnapshot(
                latency_p95_ms=142,
                uptime_pct=99.96,
                public_iam_bindings=['service="orders-service" member="allUsers" role="roles/run.invoker"'],
                observed_regions=["europe-west1"],
                monthly_projected_cost_usd=312,
                baseline_daily_users=1200,
                max_instances=12,
                concurrency_per_instance=40,
                db_max_connections=60,
                has_multi_region_failover=False,
            ),
        )
        reqs1 = [
            Requirement(
                id="REQ-01",
                title="Checkout pages respond under 250 ms for 95% of shoppers",
                category="Performance",
                check_type="latency_p95",
                threshold="<= 250 ms",
                target_numeric=250,
                in_scope=True,
                approved_by_engineer=True,
                source_provider="vertex_gemini",
            ),
            Requirement(
                id="REQ-02",
                title="Storefront remains reachable at least 99.90% of the time",
                category="Reliability",
                check_type="uptime",
                threshold=">= 99.90%",
                target_numeric=99.9,
                in_scope=True,
                approved_by_engineer=True,
                source_provider="vertex_gemini",
            ),
            Requirement(
                id="REQ-03",
                title="All customer records stay inside European Union data centers",
                category="Compliance",
                check_type="data_region",
                threshold="EU regions only (europe-*)",
                target_region="europe-",
                in_scope=True,
                approved_by_engineer=True,
                source_provider="vertex_gemini",
            ),
            Requirement(
                id="REQ-04",
                title="Internal database blocks public internet access",
                category="Security",
                check_type="iam_exposure",
                threshold="Public web edge only",
                in_scope=True,
                approved_by_engineer=True,
                source_provider="vertex_gemini",
            ),
            Requirement(
                id="REQ-05",
                title="Monthly POC infrastructure run rate stays under $450/month",
                category="Cost",
                check_type="monthly_cost",
                threshold="<= $450/mo",
                target_numeric=450,
                in_scope=True,
                approved_by_engineer=True,
                source_provider="vertex_gemini",
            ),
            Requirement(
                id="REQ-06",
                title="Multi-region active-active disaster recovery",
                category="Reliability",
                check_type="uptime",
                threshold="RPO < 5s",
                in_scope=False,
                approved_by_engineer=True,
                source_provider="none",
            ),
        ]
        return [
            POC(
                id="poc-retail-checkout",
                name="Retail Checkout Redesign",
                business_summary="Single-page European checkout pilot running in Belgium.",
                owner_name="Priya Nair",
                workspace_id="ws-acme-retail",
                data_policy="eu_only",
                allowed_providers=["none", "vertex_gemini", "vertex_claude", "azure_openai", "openai_compatible"],
                selected_llm_provider="vertex_gemini",
                environment=env1,
                requirements=reqs1,
                checks=evaluate_all_checks(reqs1, env1),
            )
        ]

    async def refresh_environment(self, poc: POC) -> EnvironmentSnapshot:
        return poc.environment


class GcpProvider(EnvironmentProvider):
    name = "GcpProvider"

    async def _get_access_token(self) -> str | None:
        if token := os.environ.get("GCP_ACCESS_TOKEN"):
            return token
        try:
            async with httpx.AsyncClient(timeout=1.5) as client:
                r = await client.get(
                    "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token",
                    headers={"Metadata-Flavor": "Google"},
                )
                if r.status_code == 200:
                    return r.json().get("access_token")
        except Exception:
            return None
        return None

    def _read_terraform_state(self) -> dict[str, Any]:
        tf_path = Path("infra/terraform.tfstate")
        if not tf_path.exists():
            return {"count": 0}
        try:
            data = json.loads(tf_path.read_text(encoding="utf-8"))
            return {"count": len(data.get("resources", []))}
        except Exception:
            return {"count": 0}

    async def load_seed_pocs(self) -> list[POC]:
        pocs = await MockProvider().load_seed_pocs()
        if project_id := os.environ.get("GCP_PROJECT_ID"):
            pocs[0].environment.project_id = project_id
            pocs[0].environment = await self.refresh_environment(pocs[0])
        return pocs

    async def refresh_environment(self, poc: POC) -> EnvironmentSnapshot:
        token = await self._get_access_token()
        project_id = poc.environment.project_id or os.environ.get("GCP_PROJECT_ID", "")
        if not token or not project_id:
            raise RuntimeError("GcpProvider requires GCP metadata token or GCP_ACCESS_TOKEN + GCP_PROJECT_ID.")

        headers = {"Authorization": f"Bearer {token}"}
        observed_regions: set[str] = set()
        public_bindings: list[str] = []

        async with httpx.AsyncClient(timeout=10.0) as client:
            assets_res = await client.get(
                f"https://cloudasset.googleapis.com/v1/projects/{project_id}/assets?pageSize=25",
                headers=headers,
            )
            if assets_res.status_code == 200:
                for asset in assets_res.json().get("assets", []):
                    if loc := asset.get("resource", {}).get("location"):
                        observed_regions.add(loc)

            iam_res = await client.post(
                f"https://cloudresourcemanager.googleapis.com/v1/projects/{project_id}:getIamPolicy",
                headers=headers,
                json={},
            )
            if iam_res.status_code == 200:
                for b in iam_res.json().get("bindings", []):
                    for m in b.get("members", []):
                        if m in ("allUsers", "allAuthenticatedUsers"):
                            public_bindings.append(f'project="{project_id}" member="{m}" role="{b.get("role")}"')

            await client.get(
                f"https://run.googleapis.com/v2/projects/{project_id}/locations/{poc.environment.primary_region}/services",
                headers=headers,
            )

        tf_summary = self._read_terraform_state()
        updated = poc.environment.model_copy(deep=True)
        updated.provider_name = "GcpProvider"
        if tf_summary["count"]:
            updated.terraform_template_ref = f"infra/terraform.tfstate ({tf_summary['count']} resources)"
        if observed_regions:
            updated.telemetry.observed_regions = sorted(observed_regions)
        updated.telemetry.public_iam_bindings = public_bindings
        return updated


def create_environment_provider() -> EnvironmentProvider:
    if os.environ.get("ENVIRONMENT_PROVIDER") == "gcp":
        return GcpProvider()
    return MockProvider()
