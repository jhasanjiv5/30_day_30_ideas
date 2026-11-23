"""FastAPI + RQ + Postgres + MinIO entrypoint for Docker Compose deployment."""

from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from .core import (
    InMemoryRetentionStore,
    answer_question_rrf,
    get_bundled_fixture_paper,
    process_clarification_sources,
)

app = FastAPI(title="Drishya API", version="0.1.0")
store = InMemoryRetentionStore()


class CreateJobRequest(BaseModel):
    document_id: str
    depth: str = "student"
    length_target: str = "2min"
    language: str = "en"
    llm_provider: str = "mock"
    tts_provider: str = "mock"


class QARequest(BaseModel):
    question: str


@app.on_event("startup")
def seed_fixture() -> None:
    fixture = get_bundled_fixture_paper()
    retention_days = int(os.getenv("DRISHYA_RETENTION_DAYS", "30"))
    store.add_document(fixture, datetime.now(timezone.utc) + timedelta(days=retention_days))


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "status": "ok",
        "mock_mode": os.getenv("DRISHYA_MOCK_MODE", "true") == "true",
        "database_configured": bool(os.getenv("DATABASE_URL")),
        "redis_configured": bool(os.getenv("REDIS_URL")),
    }


@app.get("/api/documents")
def list_documents() -> dict[str, Any]:
    return {
        "items": [
            {"id": doc.id, "title": doc.title, "expires_at": exp.isoformat()}
            for doc, exp in store.documents.values()
        ]
    }


@app.post("/api/jobs")
def enqueue_job(req: CreateJobRequest) -> dict[str, Any]:
    if req.document_id not in store.documents:
        raise HTTPException(status_code=404, detail="Document not found")
    return {
        "job_id": f"job_{req.document_id}_{req.language}",
        "status": "queued",
        "depth": req.depth,
        "language": req.language,
    }


@app.post("/api/documents/{document_id}/qa")
def ask_qa(document_id: str, req: QARequest) -> dict[str, Any]:
    entry = store.documents.get(document_id)
    if not entry:
        raise HTTPException(status_code=404, detail="Document not found")
    doc, _ = entry
    clarifications = process_clarification_sources([])
    return answer_question_rrf(req.question, doc, clarifications)
