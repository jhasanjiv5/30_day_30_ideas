"""Core grounded pipeline logic for Drishya (Python 3.11/3.12 compatible)."""

from __future__ import annotations

import math
import re
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Protocol


EXACT_QA_REFUSAL = "The document and trusted sources don't answer this."


@dataclass
class ParagraphSpan:
    id: str
    section_id: str
    section_title: str
    page: int
    text: str
    citation_key: str


@dataclass
class DocumentTable:
    id: str
    label: str
    page: int
    caption: str
    columns: list[str]
    units: dict[str, str]
    rows: list[dict[str, str | float | int]]
    citation_key: str


@dataclass
class DocumentModel:
    id: str
    title: str
    authors: list[str]
    year: int
    license: str
    paragraphs: list[ParagraphSpan]
    tables: list[DocumentTable]


@dataclass
class ClarificationSource:
    id: str
    term: str
    tier: int
    provider_name: str
    title: str
    url: str
    year: int
    relevance_score: float
    quote: str
    contradicts_paper: bool = False
    confidence_label: str = "high"
    view_label: str | None = None


@dataclass
class NarratedSentence:
    id: str
    text: str
    citations: list[str]


@dataclass
class ChartSeriesRow:
    label: str
    values: dict[str, float | int | str]


def get_bundled_fixture_paper() -> DocumentModel:
    return DocumentModel(
        id="doc_monsoon_2025",
        title=(
            "Sparse-Attention Transformers for Multi-Horizon Monsoon Rainfall Forecasting "
            "Across the Western Ghats"
        ),
        authors=["Ananya Deshmukh", "Raghav Subramanian", "Kaustav Banerjee", "Meera Krishnan"],
        year=2025,
        license="CC-BY-4.0",
        paragraphs=[
            ParagraphSpan(
                id="p1",
                section_id="sec-intro",
                section_title="1. Introduction",
                page=1,
                citation_key="doc:p1/sec-intro",
                text=(
                    "Operational 25 km weather grids smooth out steep Western Ghats escarpments "
                    "where extreme monsoon bursts trigger flash floods."
                ),
            ),
            ParagraphSpan(
                id="p4",
                section_id="sec-arch",
                section_title="2. Architecture",
                page=3,
                citation_key="doc:p3/sec-arch",
                text=(
                    "Each query token restricts key-value interaction to a 7x7 coastal-orographic "
                    "neighborhood W(i) plus 128 strided synoptic anchor tokens, cutting complexity by 84%."
                ),
            ),
            ParagraphSpan(
                id="p6",
                section_id="sec-results",
                section_title="4. Results",
                page=5,
                citation_key="doc:p5/sec-results",
                text=(
                    "Evaluated on IMD 0.25-degree rainfall across 2018-2023 JJAS seasons, "
                    "MonsoonFormer lowers 5-day RMSE to 11.4 mm/day compared to 15.8 mm/day for ConvLSTM."
                ),
            ),
            ParagraphSpan(
                id="p8",
                section_id="sec-limits",
                section_title="5. Limitations",
                page=7,
                citation_key="doc:p7/sec-limits",
                text=(
                    "Sparse local windows under-represent planetary Rossby wave coupling beyond day 7, "
                    "and training relies on historical ERA5 reanalysis without Doppler radar."
                ),
            ),
        ],
        tables=[
            DocumentTable(
                id="table-1",
                label="Table 1",
                page=5,
                caption="Multi-horizon monsoon forecast accuracy and compute footprint.",
                columns=["Model", "RMSE_5d", "CSI_65mm", "Latency_ms", "VRAM_GB"],
                units={"RMSE_5d": "mm/day", "CSI_65mm": "score", "Latency_ms": "ms", "VRAM_GB": "GB"},
                rows=[
                    {"Model": "ConvLSTM", "RMSE_5d": 15.8, "CSI_65mm": 0.44, "Latency_ms": 88, "VRAM_GB": 14.2},
                    {"Model": "PatchTST", "RMSE_5d": 13.9, "CSI_65mm": 0.49, "Latency_ms": 61, "VRAM_GB": 19.5},
                    {"Model": "Full-Attention", "RMSE_5d": 12.1, "CSI_65mm": 0.54, "Latency_ms": 195, "VRAM_GB": 38.4},
                    {"Model": "MonsoonFormer", "RMSE_5d": 11.4, "CSI_65mm": 0.61, "Latency_ms": 42, "VRAM_GB": 9.6},
                ],
                citation_key="doc:p5/table-1",
            )
        ],
    )


def filter_uncited_sentences(
    sentences: list[NarratedSentence], valid_citations: set[str]
) -> tuple[list[NarratedSentence], int]:
    kept: list[NarratedSentence] = []
    dropped = 0
    for s in sentences:
        valid = [c for c in s.citations if c in valid_citations]
        if not valid:
            dropped += 1
            continue
        kept.append(NarratedSentence(id=s.id, text=s.text, citations=valid))
    return kept, dropped


def verify_chart_against_table(
    table: DocumentTable,
    x_col: str,
    y_cols: list[str],
    rendered_series: list[ChartSeriesRow],
) -> tuple[bool, list[str]]:
    mismatches: list[str] = []
    if len(rendered_series) != len(table.rows):
        mismatches.append(f"Row count mismatch: {len(rendered_series)} != {len(table.rows)}")
        return False, mismatches
    for idx, row in enumerate(table.rows):
        expected_label = str(row.get(x_col, ""))
        actual = rendered_series[idx]
        if actual.label != expected_label:
            mismatches.append(f"Label mismatch at {idx}: {actual.label} != {expected_label}")
        for yc in y_cols:
            if actual.values.get(yc) != row.get(yc):
                mismatches.append(
                    f"Value mismatch for ({expected_label}, {yc}): {actual.values.get(yc)} != {row.get(yc)}"
                )
    return len(mismatches) == 0, mismatches


def extract_allowed_numbers(doc: DocumentModel, clarifications: list[ClarificationSource]) -> set[str]:
    allowed = {"1", "2", "3", "4", "5", "6", "7", "10", "14", "30", "2024"}
    parts = [p.text for p in doc.paragraphs] + [c.quote for c in clarifications]
    for tbl in doc.tables:
        for row in tbl.rows:
            parts.extend(str(v) for v in row.values())
    for part in parts:
        for match in re.findall(r"\b\d+(?:\.\d+)?\b", part):
            allowed.add(match)
    return allowed


def find_ungrounded_numbers(text: str, allowed_numbers: set[str]) -> list[str]:
    scrubbed = re.sub(r"\b(Figure|Table|Equation|Section|Tier|Panel)\s+\d+\b", " ", text, flags=re.I)
    return [num for num in re.findall(r"\b\d+(?:\.\d+)?\b", scrubbed) if num not in allowed_numbers]


def process_clarification_sources(sources: list[ClarificationSource]) -> list[ClarificationSource]:
    processed: list[ClarificationSource] = []
    for s in sources:
        words = s.quote.strip().split()
        trimmed_quote = " ".join(words[:25])
        processed.append(
            ClarificationSource(
                id=s.id,
                term=s.term,
                tier=s.tier,
                provider_name=s.provider_name,
                title=s.title,
                url=s.url,
                year=s.year,
                relevance_score=s.relevance_score,
                quote=trimmed_quote,
                contradicts_paper=s.contradicts_paper,
                confidence_label="lower confidence" if s.tier == 3 else "high",
                view_label="Differing view" if s.contradicts_paper else None,
            )
        )
    processed.sort(key=lambda item: (item.tier, -item.relevance_score, -item.year))
    return processed


PROTECTED_PATTERNS = [
    re.compile(r"\$[^$]+\$"),
    re.compile(r"\\[a-zA-Z]+(?:\{[^}]*\})?"),
    re.compile(
        r"\b(?:MonsoonFormer|ConvLSTM|PatchTST|Full-Attention|ERA5|IMD|SST|VRAM|RMSE|CSI|JJAS)\b"
    ),
    re.compile(r"\b\d+(?:\.\d+)?\s*(?:mm/day|mm|km|GB|ms|deg|%)\b", re.I),
    re.compile(r"\b\d+(?:\.\d+)?\b"),
]


def translate_with_placeholder_guard(text: str, target_lang: str) -> tuple[str, bool]:
    if target_lang == "en":
        return text, True
    tokens: list[tuple[str, str]] = []
    masked = text
    idx = 0
    for pattern in PROTECTED_PATTERNS:
        def _repl(match: re.Match[str]) -> str:
            nonlocal idx
            val = match.group(0)
            if "⟦P" in val:
                return val
            ph = f"⟦P{idx}⟧"
            idx += 1
            tokens.append((ph, val))
            return ph
        masked = pattern.sub(_repl, masked)

    prefixes = {"hi": "हिन्दी: ", "ta": "தமிழ்: ", "ur": "اردو: "}
    translated_masked = f"{prefixes.get(target_lang, '')}{masked}"
    restored = translated_masked
    for ph, original in tokens:
        restored = restored.replace(ph, original)
    verified = all(original in restored for _, original in tokens)
    return restored, verified


class LLMProvider(Protocol):
    name: str

    def generate_json(self, model: str, prompt: str, fallback: dict[str, Any]) -> dict[str, Any]: ...


class MockLLMProvider:
    name = "mock"

    def generate_json(self, model: str, prompt: str, fallback: dict[str, Any]) -> dict[str, Any]:
        return {"provider": self.name, "model": model, "payload": fallback}


QA_STOPWORDS = {
    "the", "is", "at", "which", "on", "and", "or", "to", "of", "in",
    "for", "with", "what", "how", "why", "does", "do", "are", "was",
    "were", "it", "this", "that", "from", "by", "as", "be",
}


def answer_question_rrf(
    question: str, doc: DocumentModel, clarifications: list[ClarificationSource]
) -> dict[str, Any]:
    tokens = [
        t for t in re.findall(r"[a-z0-9.]+", question.lower())
        if len(t) > 2 and t not in QA_STOPWORDS
    ]
    if not tokens:
        return {"answered": False, "refusal": EXACT_QA_REFUSAL, "sentences": []}

    corpus: list[tuple[str, str, str]] = []
    for p in doc.paragraphs:
        corpus.append((p.citation_key, p.section_title, p.text))
    for tbl in doc.tables:
        summary = " ".join(str(v) for row in tbl.rows for v in row.values())
        corpus.append((tbl.citation_key, tbl.label, f"{tbl.caption} {summary}"))
    for c in clarifications:
        corpus.append((c.url, c.title, c.quote))

    scores: list[tuple[float, str, str]] = []
    for cite, title, text in corpus:
        haystack_tokens = set(re.findall(r"[a-z0-9.]+", f"{title} {text}".lower()))
        hits = sum(1 for tok in tokens if tok in haystack_tokens)
        if hits > 0:
            scores.append((hits / math.sqrt(len(haystack_tokens) + 1), cite, text))

    if not scores:
        return {"answered": False, "refusal": EXACT_QA_REFUSAL, "sentences": []}

    scores.sort(reverse=True, key=lambda x: x[0])
    top = scores[0]
    return {
        "answered": True,
        "sentences": [{"text": top[2], "citations": [top[1]]}],
    }


@dataclass
class PrivacyAuditRecord:
    timestamp: str
    action: str
    resource_id: str
    note: str


@dataclass
class InMemoryRetentionStore:
    documents: dict[str, tuple[DocumentModel, datetime]] = field(default_factory=dict)
    objects: dict[str, bytes] = field(default_factory=dict)
    logs: list[PrivacyAuditRecord] = field(default_factory=list)

    def add_document(self, doc: DocumentModel, expires_at: datetime) -> None:
        self.documents[doc.id] = (doc, expires_at)
        self.objects[f"videos/{doc.id}/podcast.mp4"] = b"MP4_BYTES"
        self.logs.append(
            PrivacyAuditRecord(
                timestamp=datetime.now(timezone.utc).isoformat(),
                action="document.ingest",
                resource_id=doc.id,
                note=f"Ingested {len(doc.paragraphs)} spans (text redacted)",
            )
        )

    def sweep_expired(self, now: datetime) -> list[str]:
        removed: list[str] = []
        for doc_id, (_, exp) in list(self.documents.items()):
            if exp <= now:
                del self.documents[doc_id]
                for key in [k for k in self.objects if doc_id in k]:
                    del self.objects[key]
                removed.append(doc_id)
        return removed
