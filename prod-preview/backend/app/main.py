from __future__ import annotations

import json
import os
from contextlib import asynccontextmanager
from typing import Any, Optional

from fastapi import FastAPI, Header, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from .auth import AuthSession, can_perform_action, sign_invite_token, verify_invite_token
from .checks import evaluate_all_checks
from .env_providers import create_environment_provider
from .llm_providers import LLMProviderRegistry, encrypt_byok_secret
from .models import POC, Requirement, SignOffRecord, WhatIfParams
from .whatif import simulate_what_if

STATE: dict[str, Any] = {
    "pocs": [],
    "disabled_providers": [],
    "encrypted_byok_keys": {},
}

env_provider = create_environment_provider()
llm_registry = LLMProviderRegistry()


def contains_secret_leak(text: str) -> bool:
    for env_name in (
        "GEMINI_API_KEY",
        "ANTHROPIC_API_KEY",
        "OPENAI_API_KEY",
        "AZURE_OPENAI_API_KEY",
        "INVITE_TOKEN_SECRET",
        "BYOK_ENCRYPTION_KEY",
    ):
        val = os.environ.get(env_name, "")
        if len(val) >= 8 and val in text:
            return True
    return False


def _resolve_session(request: Request, x_invite_token: Optional[str], x_demo_role: Optional[str]) -> AuthSession:
    invite = x_invite_token or request.query_params.get("invite")
    if invite:
        ok, payload = verify_invite_token(invite)
        if not ok:
            raise HTTPException(status_code=401, detail=str(payload))
        assert isinstance(payload, dict)
        return AuthSession(
            authenticated=True,
            user_name=str(payload.get("label", "External Reviewer")),
            user_email="invite-reviewer@external.guest",
            role="stakeholder",
            auth_method="invite_link",
            scoped_poc_id=str(payload["poc_id"]),
        )
    if x_demo_role == "anonymous":
        return AuthSession(authenticated=False, user_name="Anonymous", user_email="", role="stakeholder", auth_method="none")
    role = "stakeholder" if x_demo_role == "stakeholder" else "engineer"
    return AuthSession(
        authenticated=True,
        user_name="Priya Nair" if role == "engineer" else "Claire Bennett",
        user_email="priya@acme.example" if role == "engineer" else "claire@acme.example",
        role=role,  # type: ignore[arg-type]
        auth_method="google_identity",
    )


def _sanitize_poc(poc: POC, role: str) -> dict[str, Any]:
    data = poc.model_dump()
    if role != "engineer":
        data["requirements"] = [r for r in data["requirements"] if r["approved_by_engineer"]]
        data["pending_drafts"] = []
    return data


@asynccontextmanager
async def lifespan(_app: FastAPI):
    STATE["pocs"] = await env_provider.load_seed_pocs()
    yield


app = FastAPI(title="Prod Preview API", version="1.0.0", lifespan=lifespan)


@app.middleware("http")
async def redact_secrets_middleware(request: Request, call_next):
    response = await call_next(request)
    if response.headers.get("content-type", "").startswith("application/json"):
        body = b"".join([chunk async for chunk in response.body_iterator])
        if contains_secret_leak(body.decode("utf-8", errors="ignore")):
            return JSONResponse(status_code=500, content={"detail": "Blocked unsafe secret serialization"})
        return JSONResponse(status_code=response.status_code, content=json.loads(body))
    return response


@app.get("/api/health")
async def health():
    return {"status": "ok", "environment_provider": env_provider.name}


@app.get("/api/pocs")
async def list_pocs(
    request: Request,
    x_invite_token: Optional[str] = Header(default=None),
    x_demo_role: Optional[str] = Header(default=None),
):
    sess = _resolve_session(request, x_invite_token, x_demo_role)
    ok, reason = can_perform_action(sess, "view_poc")
    if not ok:
        raise HTTPException(status_code=401, detail=reason)
    visible = [
        _sanitize_poc(p, sess.role)
        for p in STATE["pocs"]
        if not sess.scoped_poc_id or p.id == sess.scoped_poc_id
    ]
    return {"pocs": visible}


@app.post("/api/pocs/{poc_id}/whatif")
async def what_if(
    poc_id: str,
    params: WhatIfParams,
    request: Request,
    x_invite_token: Optional[str] = Header(default=None),
    x_demo_role: Optional[str] = Header(default=None),
):
    sess = _resolve_session(request, x_invite_token, x_demo_role)
    ok, reason = can_perform_action(sess, "view_poc", poc_id)
    if not ok:
        raise HTTPException(status_code=403, detail=reason)
    poc = next((p for p in STATE["pocs"] if p.id == poc_id), None)
    if not poc:
        raise HTTPException(status_code=404, detail="POC not found")
    return simulate_what_if(poc.environment, params)


class ProviderSwitchBody(BaseModel):
    provider_id: str


@app.put("/api/pocs/{poc_id}/llm/provider")
async def switch_provider(
    poc_id: str,
    body: ProviderSwitchBody,
    request: Request,
    x_invite_token: Optional[str] = Header(default=None),
    x_demo_role: Optional[str] = Header(default=None),
):
    sess = _resolve_session(request, x_invite_token, x_demo_role)
    ok, reason = can_perform_action(sess, "switch_llm_provider", poc_id)
    if not ok:
        raise HTTPException(status_code=403, detail=reason)
    poc = next((p for p in STATE["pocs"] if p.id == poc_id), None)
    if not poc:
        raise HTTPException(status_code=404, detail="POC not found")
    allowed, policy_reason = llm_registry.check_policy(body.provider_id, poc, STATE["disabled_providers"])
    if not allowed:
        raise HTTPException(status_code=403, detail=policy_reason)
    poc.selected_llm_provider = body.provider_id
    return {"selected_provider": poc.selected_llm_provider}


class DraftBody(BaseModel):
    requirements_text: str
    provider_id: Optional[str] = None


@app.post("/api/pocs/{poc_id}/llm/draft")
async def draft_mappings(
    poc_id: str,
    body: DraftBody,
    request: Request,
    x_invite_token: Optional[str] = Header(default=None),
    x_demo_role: Optional[str] = Header(default=None),
):
    sess = _resolve_session(request, x_invite_token, x_demo_role)
    ok, reason = can_perform_action(sess, "edit_mappings", poc_id)
    if not ok:
        raise HTTPException(status_code=403, detail=reason)
    poc = next((p for p in STATE["pocs"] if p.id == poc_id), None)
    if not poc:
        raise HTTPException(status_code=404, detail="POC not found")
    pid = body.provider_id or poc.selected_llm_provider
    try:
        batch = await llm_registry.draft_with_reliability(
            poc=poc,
            requested_provider_id=pid,
            requirements_text=body.requirements_text,
            disabled_in_workspace=STATE["disabled_providers"],
            encrypted_byok_map=STATE["encrypted_byok_keys"],
        )
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    poc.pending_drafts.insert(0, batch)
    poc.audit_log.insert(0, batch.audit)
    return {"batch": batch}


class ByokBody(BaseModel):
    provider_id: str
    api_key: str


@app.post("/api/workspace/byok")
async def save_byok(
    body: ByokBody,
    request: Request,
    x_invite_token: Optional[str] = Header(default=None),
    x_demo_role: Optional[str] = Header(default=None),
):
    sess = _resolve_session(request, x_invite_token, x_demo_role)
    ok, reason = can_perform_action(sess, "manage_workspace")
    if not ok:
        raise HTTPException(status_code=403, detail=reason)
    STATE["encrypted_byok_keys"][body.provider_id] = encrypt_byok_secret(body.api_key)
    return {"provider_id": body.provider_id, "stored": True}
