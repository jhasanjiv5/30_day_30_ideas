# Drishya

Drishya turns open-access research documents (arXiv, DOI, PubMed Central, URLs, or uploaded PDF/DOCX/HTML files) into narrated, chaptered MP4 video podcasts with animated 2D diagrams, table-verified charts, highlighted figures, and term-by-term equations. Every narrated sentence and every Q&A answer is strictly bound to verified document spans or tiered external clarification sources, removing any uncited claim or ungrounded number before rendering. Videos support Beginner, Student, and Expert depths across English and 11 Indian languages (including right-to-left Urdu), with interactive scene jumping from the grounded Q&A panel.

### What Drishya Does / Never Does

| Capability | What Drishya Does | What Drishya Never Does |
| :--- | :--- | :--- |
| **Grounding & Citations** | Attaches `doc:page/section/figure/table` or verified external URLs to every spoken sentence and Q&A sentence; drops uncited sentences before rendering. | Never emits uncited claims, hallucinated statistics, or numbers absent from parsed tables, document text, or cited sources. |
| **Charts & Tables** | Rebuilds chart series directly from parsed `DocumentTable` cells at render time and blocks scenes on any value mismatch. | Never trusts LLM-generated numbers to draw chart bars or data points. |
| **External Sources** | Ranks clarifications by Tier 1 (scholarly), Tier 2 (Wikipedia/Wikidata), Tier 3 (web search labeled `"lower confidence"`), and flags contradictions as `"Differing view"`. | Never merges contradicting papers silently or presents Tier 3 web blogs as scholarly consensus. |
| **Privacy & Retention** | Isolates documents per user, auto-deletes artifacts after `N` days (default 30), provides a `Delete Now` purge button, and expires shared Viewer links. | Never logs document text or prompts in plain text, never sends cookies on remote fetches, and never uses workspace content for model training. |
| **Scope & Access** | Fetches open-access URLs respecting `robots.txt` and SSRF boundaries. | Never bypasses paywalls, never fetches private network addresses, and never exposes provider API keys to the browser. |

---

## 2. Installation

### Prerequisites

- **Docker & Docker Compose** (FFmpeg, Manim Community, LaTeX, Postgres 16, Redis 7, MinIO, and Python 3.12 are packaged inside the container images)
- For local Node/Python verification without Docker: Node.js `>= 22`, FFmpeg `>= 4.4`, Python `>= 3.11`

### One-Command Local Startup (Offline Mock Mode)

```bash
docker compose up
```

In the AI Studio / Node-only environment, start the full-stack Express + Vite server on port 3000:

```bash
npm install
npm run dev
```

Mock Mode (`DRISHYA_MOCK_MODE=true`) is enabled by default so the bundled CC-BY open-access paper, recorded LLM/TTS/search fixtures, MP4 assembly, tests, and key-frame generation run completely offline with zero API keys.

### Environment Variables

| Variable | Default | Description |
| :--- | :--- | :--- |
| `DRISHYA_MOCK_MODE` | `true` | Runs the entire pipeline on bundled CC-BY paper and recorded fixtures with no network calls. |
| `DRISHYA_RETENTION_DAYS` | `30` | Automatic deletion window for ingested documents, videos, and storage objects. |
| `DRISHYA_STORAGE_DIR` | `./data/storage` | Local object store path when running without MinIO. |
| `GEMINI_API_KEY` | — | Server-side key for Gemini (`@google/genai`). Never exposed to client code. |
| `ANTHROPIC_API_KEY` | — | Server-side key for Anthropic Claude models. |
| `OPENAI_API_KEY` | — | Server-side key for OpenAI models. |
| `OLLAMA_BASE_URL` | `http://localhost:11434` | Local OpenAI-compatible Ollama endpoint. |
| `CLOUD_TTS_PROVIDER` | `mock` | Cloud neural TTS adapter (`mock`, `cloud`, or `piper` local). |
| `PIPER_BIN_PATH` | `piper` | Path to local Piper binary for offline Indian/English voice synthesis. |
| `SEARCH_API_KEY` | — | Optional Tier 3 web search API key (Tier 1 uses OpenAlex/Crossref/arXiv/PubMed). |
| `DATABASE_URL` | `postgresql+psycopg://drishya:drishya@postgres:5432/drishya` | Postgres connection string in Docker Compose. |
| `REDIS_URL` | `redis://redis:6379/0` | Redis URL for RQ ingest and rendering job queues. |
| `S3_ENDPOINT` / `S3_BUCKET` | `http://minio:9000` / `drishya-artifacts` | MinIO S3-compatible object storage configuration. |

### Switching From Mock Mode to Real Providers

1. Set `DRISHYA_MOCK_MODE=false` in your server environment (or toggle **Offline Mock Mode** off in **Settings**).
2. Configure at least one server-side credential (`GEMINI_API_KEY`, `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, or `OLLAMA_BASE_URL`).
3. In **Settings**, choose your active `LLMProvider`, customize model identifiers (never hardcoded), configure the fallback chain, and select `Cloud Neural TTS` or `Piper (Local Offline TTS)`.

---

## 3. How to Use

1. **Create a video**: Open **New Video**, paste an open-access URL (arXiv, DOI, PubMed Central), upload a PDF/DOCX/HTML file, or select the bundled CC-BY paper.
2. **Choose options**: Pick Explanation Depth (`Beginner`, `Student`, or `Expert`), Target Length (`2 min`, `5 min`, or `10+ min`), Language (English + 11 Indian languages, showing `Voice + Captions` or `Captions only` capability and selected voice), and LLM/TTS providers.
3. **Monitor & retry stages**: Open **Job Progress** to inspect per-stage timings, model names, prompt versions, token counts, and costs. If any stage fails, click **Retry Stage** to resume from that exact step.
4. **Watch & trace citations**: In **Player**, toggle between the synchronized **Interactive Stage** (animated diagrams, table-verified charts, highlighted figures, term-by-term KaTeX equations) and the **Rendered MP4 Stream** with WebVTT captions and chapter markers. Click any `[doc:...]` or URL citation in the **Transcript** to inspect the exact source span.
5. **Ask grounded Q&A**: Use the **Grounded Q&A** tab to ask questions answered first from the paper, then verified external clarifications. Click **Show me** to jump the video directly to the covering scene.
6. **Share or Delete**: Click **Share** to generate an expiring read-only Viewer link (`1h`, `24h`, `7d`), or **Delete Now** to immediately purge all database rows and rendered storage artifacts.

---

## 4. Verify It Is Grounded

Run the complete offline verification suites:

```bash
npm test
python3 -m unittest discover -s backend/tests -v
```

### Trace Citations in a Transcript

1. Open the bundled **MonsoonFormer** video in **Player**.
2. In the **Transcript** tab, inspect three citations:
   - `[doc:p1/sec-intro]` → resolves to Section 1, Page 1 (*25 km operational NWP smoothing*).
   - `[doc:p5/table-1]` → resolves to Table 1, Page 5 (*11.4 mm/day 5-day RMSE and 9.6 GB VRAM*).
   - `[https://doi.org/10.1029/2024GL109821]` → resolves to Tier 1 cited paper *Rao et al. (2024)*.

### Chart Accuracy Report & Source Flags

Open **Sources & Audit** in the Player panel to inspect:
- **Chart Accuracy Report**: Confirms `100% Exact Match` across every cell of `Table 1` (`8 table cells verified`, `0 mismatches`).
- **`Lower confidence`**: Applied automatically to Tier 3 general web search sources so readers distinguish blog/web benchmarks from peer-reviewed Tier 1 literature.
- **`Differing view`**: Flagged whenever an external Tier 1/2 source contradicts a claim in the paper (e.g., *Rao et al., 2024* on 10–14 day monsoon break predictions) rather than merging conflicting claims.

---

## 5. Maintenance

- **Updating models, providers, & voices**: Update model IDs in **Settings** (`llmModels` map) or `WorkspaceSettings` defaults; add new voice IDs in `SUPPORTED_LANGUAGES` (`server/types.ts`).
- **Source API quotas & keys**: Keep `SEARCH_API_KEY` and LLM credentials strictly in server environment variables; Tier 1 scholarly APIs (OpenAlex, Crossref, arXiv, PubMed) do not require user cookies.
- **Retention tuning & clean-up**: Adjust `DRISHYA_RETENTION_DAYS` (default `30`) in `.env` or **Settings**, or invoke `POST /api/retention/sweep` via cron to purge expired documents, share links, and `data/storage/videos/*` objects.
- **Re-rendering**: Use `POST /api/jobs/:id/retry` with `{ "stage": "render" }` to re-assemble MP4/VTT artifacts after voice or caption adjustments.
- **Adding a language or visual type**:
  1. Add the language entry (`code`, `dir`, `capability`, `defaultVoice`, `piperVoice`) in `server/types.ts` and phrase rules in `server/pipeline/translation.ts`.
  2. Add new visual spec schemas in `VisualSpecSchema` (`server/types.ts`), a renderer branch in `src/components/SceneStage.tsx`, and a corresponding Manim class in `backend/app/manim_scenes.py`.

---

## 6. Architecture Diagrams

### Dataflow & Trust Boundaries

```mermaid
flowchart LR
  subgraph Client["Browser Client (Untrusted Zone)"]
    UI["React + Vite UI"]
    Player["Scene Stage & MP4 Player"]
  end

  subgraph Server["Drishya API & Worker Trust Boundary"]
    Ingest["1. Ingest (SSRF + robots.txt + Parser)"]
    Understand["2. Understand (Schema Validated)"]
    Clarify["3. Clarify (Tier 1/2/3 Ranker)"]
    Plan["4. Storyboard + Grounding & Chart Guard"]
    Translate["5. Placeholder-Guarded Translator"]
    Render["6. Manim + FFmpeg + TTS Assembler"]
    QASvc["7. Hybrid BM25 + RRF Q&A"]
    Store[("Postgres / JSON Store + MinIO S3")]
  end

  subgraph External["External Services (Keys Server-Side Only)"]
    Scholar["Tier 1: OpenAlex / arXiv / Crossref / PubMed"]
    Wiki["Tier 2: Wikipedia / Wikidata"]
    WebSearch["Tier 3: Web Search API"]
    LLM["LLMProvider (Gemini / Anthropic / OpenAI / Ollama)"]
    TTS["TTSProvider (Cloud / Piper Local)"]
  end

  UI -->|Upload / Open-Access URL| Ingest
  Ingest --> Understand
  Understand -->|Redacted structured chunks| LLM
  Understand --> Clarify
  Clarify -->|Term queries only| Scholar
  Clarify -->|Term queries only| Wiki
  Clarify -->|Term queries only| WebSearch
  Clarify --> Plan
  Plan --> Translate
  Translate --> Render
  Render -->|Synthesize audio| TTS
  Render -->|MP4 + WebVTT + Citations| Store
  Store --> Player
  UI -->|Question| QASvc
  QASvc --> Store
  QASvc -->|Cited answer + Show Me timestamp| UI
```

### User Interaction Flow

```mermaid
sequenceDiagram
  actor User
  participant Web as Drishya Web UI
  participant API as Server Pipeline
  participant QA as Grounded Q&A

  User->>Web: Upload PDF or paste arXiv/DOI URL
  User->>Web: Select Depth, Length, Language, Provider
  Web->>API: POST /api/documents + POST /api/jobs
  API-->>Web: Stage-by-stage progress & ready MP4/WebVTT
  User->>Web: Watch video with chapters & captions
  User->>Web: Click citation in transcript
  Web-->>User: Highlight exact doc span or external quote
  User->>QA: Ask question in Q&A panel
  QA-->>Web: Cited answer + "Show me" scene timestamp
  User->>Web: Click "Show me" -> seek video to scene
  User->>Web: Create expiring share link or click Delete Now
  Web->>API: DELETE /api/documents/:id (purges rows & MP4)
```

### Resumable Job State Machine

```mermaid
stateDiagram-v2
  [*] --> queued
  queued --> ingesting
  ingesting --> understanding
  understanding --> clarifying
  clarifying --> planning
  planning --> translating
  translating --> rendering
  rendering --> ready
  ready --> [*]

  ingesting --> failed
  understanding --> failed
  clarifying --> failed
  planning --> failed
  translating --> failed
  rendering --> failed

  failed --> retried: Retry Failed Stage
  retried --> ingesting
  retried --> understanding
  retried --> clarifying
  retried --> planning
  retried --> translating
  retried --> rendering
```

---

## 7. Key Frames & Sample Clip (`docs/frames/`)

Generate live Playwright screenshots in mock mode with:

```bash
make frames
```

| Frame | File | Caption |
| :--- | :--- | :--- |
| Library | `docs/frames/01_library.png` | Document library showing license, section/table counts, retention expiry, and one-click Delete Now. |
| New Video | `docs/frames/02_new_video_options.png` | Ingestion form for URLs/uploads/fixture with depth, length, 12-language capability matrix, and provider pickers. |
| Job Progress | `docs/frames/03_job_progress.png` | Resumable 6-stage pipeline tracker displaying provider, model, prompt version, latency, tokens, cost, and stage retry. |
| Player & Chapters | `docs/frames/04_player_chapters.png` | Video player with chapter markers, timeline scrubber, Interactive Stage vs MP4 toggle, and WebVTT captions. |
| Transcript & Citations | `docs/frames/05_transcript_citations.png` | Synchronized transcript with clickable `doc:page/section` citations and inline span inspector. |
| Q&A & Sources | `docs/frames/06_qa_sources.png` | Grounded Q&A panel with per-sentence citations, `"Show me"` scene jump links, and Tier 1/2/3 source audit. |
| Diagram Scene | `docs/frames/07_diagram_scene.png` | Progressive 4-step animated 2D architecture diagram rendered for MonsoonFormer sparse routing. |
| Chart Scene | `docs/frames/08_chart_scene.png` | Grouped bar chart rebuilt verbatim from parsed `Table 1` cells (`11.4 mm/day` RMSE, `9.6 GB` VRAM). |
| Equation Scene | `docs/frames/09_equation_scene.png` | KaTeX-rendered sparse attention equation with term-by-term plain-language symbol reveal. |
| Hindi Frame | `docs/frames/10_hindi_frame.png` | Hindi (`hi`) narration and captions preserving `MonsoonFormer`, `11.4 mm/day`, and `$\alpha_{ij}$` via placeholder guard. |
| Urdu RTL UI | `docs/frames/11_urdu_rtl.png` | Urdu (`ur`) player stage, captions, and transcript rendered in full right-to-left (`dir="rtl"`) layout. |
| Settings & Providers | `docs/frames/12_settings_providers.png` | Workspace LLM/TTS provider switcher, retention window config, zero-training policy, and redacted audit log. |
| 20s Sample Clip | `docs/frames/sample_clip.mp4` (`sample_clip.gif`) | 20-second FFmpeg-assembled sample clip from the bundled CC-BY fixture video. |

---

## 8. Cost, Latency, Limitations & Roadmap

### Provider Cost & Latency Notes (2-Minute Student Video)

| Provider | Typical End-to-End Latency | Estimated LLM + TTS Cost / Video | Notes |
| :--- | :--- | :--- | :--- |
| `mock` (Offline Fixtures) | ~0.8–1.5 s (including FFmpeg MP4) | `$0.0000` | Deterministic fixtures; zero API keys required. |
| `gemini` (`gemini-4-hydrogen`) + Cloud TTS | ~8–16 s | `~$0.002–$0.006` | Fast structured JSON output + low-latency Indian neural voices. |
| `anthropic` / `openai` + Cloud TTS | ~12–24 s | `~$0.015–$0.045` | Higher per-token cost; automatic fallback chain supported. |
| `ollama` + `piper` (Local) | ~18–45 s (CPU/GPU dependent) | `$0.0000` (compute only) | Fully self-hosted; Punjabi (`pa`) & Odia (`or`) fall back to captions-only. |

### Known Limitations
- Local Piper TTS does not ship pre-trained voices for every Indian language (Punjabi and Odia automatically mark `Captions only`).
- Scanned image-only PDFs without embedded text require OCR fallback, which reduces table extraction fidelity on complex multi-column layouts.
- Paywalled journals, real-time collaborative editing, mobile native apps, and avatar talking-head videos are intentionally out of scope for the MVP.

### Roadmap
- **Slides Export (PPTX / Reveal.js)** generated from the verified storyboard visual specs.
- **Voice Q&A** using live speech-to-text paired with the grounded RRF retrieval engine.
- **Multi-Document Comparisons** synthesizing cross-paper tables and differing-view graphs across 2–5 uploaded papers.
