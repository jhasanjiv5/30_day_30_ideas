from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import time
from dataclasses import dataclass
from typing import Literal, Optional

UserRole = Literal["engineer", "stakeholder"]

DEFAULT_DEV_SECRET = "dev-replace-with-32-byte-secret-in-prod"


def _signing_secret() -> bytes:
    return os.environ.get("INVITE_TOKEN_SECRET", DEFAULT_DEV_SECRET).encode("utf-8")


def _b64url_encode(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def _b64url_decode(val: str) -> bytes:
    pad = "=" * ((4 - len(val) % 4) % 4)
    return base64.urlsafe_b64decode(val + pad)


@dataclass
class AuthSession:
    authenticated: bool
    user_name: str
    user_email: str
    role: UserRole
    auth_method: str
    scoped_poc_id: Optional[str] = None
    invite_expires_at: Optional[str] = None


def sign_invite_token(
    poc_id: str,
    ttl_seconds: int = 7 * 24 * 3600,
    label: str = "External Steering Committee Reviewer",
    now_epoch: Optional[int] = None,
) -> tuple[str, int]:
    iat = now_epoch if now_epoch is not None else int(time.time())
    exp = iat + ttl_seconds
    payload = {
        "poc_id": poc_id,
        "role": "stakeholder",
        "label": label,
        "iat": iat,
        "exp": exp,
    }
    encoded = _b64url_encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    sig = hmac.new(_signing_secret(), encoded.encode("ascii"), hashlib.sha256).digest()
    return f"{encoded}.{_b64url_encode(sig)}", exp


def verify_invite_token(
    token: str,
    now_epoch: Optional[int] = None,
) -> tuple[bool, dict | str]:
    if not token or "." not in token:
        return False, "Malformed invite token."
    parts = token.split(".")
    if len(parts) != 2:
        return False, "Invalid invite token structure."

    encoded, provided_sig = parts
    expected_sig = _b64url_encode(
        hmac.new(_signing_secret(), encoded.encode("ascii"), hashlib.sha256).digest()
    )
    if not hmac.compare_digest(provided_sig, expected_sig):
        return False, "Invite link signature is invalid."

    try:
        payload = json.loads(_b64url_decode(encoded).decode("utf-8"))
    except Exception:
        return False, "Invite payload could not be parsed."

    if not payload.get("poc_id") or payload.get("role") != "stakeholder":
        return False, "Invite payload missing required scope."

    now = now_epoch if now_epoch is not None else int(time.time())
    if now >= int(payload.get("exp", 0)):
        return False, "This invite link has expired."

    return True, payload


def can_perform_action(
    session: AuthSession,
    action: str,
    target_poc_id: Optional[str] = None,
) -> tuple[bool, str]:
    if not session.authenticated:
        return False, "Authentication required. No anonymous write or read access."

    if session.scoped_poc_id and target_poc_id and session.scoped_poc_id != target_poc_id:
        return False, "Invite link is scoped to a single POC."

    engineer_only = {
        "edit_mappings",
        "switch_llm_provider",
        "approve_drafts",
        "manage_workspace",
        "generate_invite",
    }
    if action in engineer_only and session.role != "engineer":
        return False, "Stakeholder role cannot edit mappings, switch LLM providers, or approve drafts."

    return True, ""
