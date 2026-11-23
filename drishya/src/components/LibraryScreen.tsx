import {
  ArrowRight,
  Download,
  FileText,
  Globe,
  Play,
  RefreshCw,
  Search,
  Trash2,
  Upload,
} from 'lucide-react';
import { useMemo, useState } from 'react';
import {
  Depth,
  LanguageCode,
  LanguageInfo,
  LengthTarget,
  LibraryItem,
  WorkspaceSettings,
} from '../types.ts';

interface LibraryScreenProps {
  items: LibraryItem[];
  loading: boolean;
  languages: LanguageInfo[];
  settings: WorkspaceSettings | null;
  onNewVideo: () => void;
  onJobCreated: (jobId: string, videoId?: string) => Promise<void>;
  onOpenPlayer: (videoId: string) => void;
  onInspectJob: (jobId: string) => void;
  onDeleteDocument: (documentId: string) => Promise<void>;
}

const SAMPLE_URLS = [
  {
    label: 'Attention Is All You Need (arXiv:1706.03762)',
    url: 'https://arxiv.org/abs/1706.03762',
  },
  {
    label: 'Docling Technical Report (arXiv:2408.09869)',
    url: 'https://arxiv.org/abs/2408.09869',
  },
  {
    label: 'Tree of Thoughts (arXiv:2305.10601)',
    url: 'https://arxiv.org/abs/2305.10601',
  },
];

export function LibraryScreen({
  items,
  loading,
  languages,
  settings,
  onNewVideo,
  onJobCreated,
  onOpenPlayer,
  onInspectJob,
  onDeleteDocument,
}: LibraryScreenProps) {
  const [entryMode, setEntryMode] = useState<'url' | 'upload' | 'fixture'>('url');
  const [urlInput, setUrlInput] = useState('');
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [depth, setDepth] = useState<Depth>('student');
  const [lengthTarget, setLengthTarget] = useState<LengthTarget>('2min');
  const [language, setLanguage] = useState<LanguageCode>('en');
  const [submitting, setSubmitting] = useState(false);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Research History search & filter
  const [historyQuery, setHistoryQuery] = useState('');
  const [historyFilter, setHistoryFilter] = useState<'all' | 'annotated'>('all');

  const filteredItems = useMemo(() => {
    const q = historyQuery.trim().toLowerCase();
    return items.filter((item) => {
      if (historyFilter === 'annotated') {
        const totalAnn = (item.notesCount ?? 0) + (item.sketchesCount ?? 0);
        if (totalAnn === 0) return false;
      }
      if (!q) return true;
      const haystack = [
        item.document.model.title,
        item.document.model.venue,
        item.document.model.sourceUrl ?? '',
        ...item.document.model.authors,
      ]
        .join(' ')
        .toLowerCase();
      return haystack.includes(q);
    });
  }, [items, historyQuery, historyFilter]);

  async function handleQuickStartSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSubmitting(true);

    try {
      let docRes: Response;
      if (entryMode === 'upload') {
        if (!selectedFile) {
          throw new Error('Select a PDF, DOCX, HTML, or TXT file first.');
        }
        setStatusMessage(`Uploading and parsing ${selectedFile.name}...`);
        const form = new FormData();
        form.append('file', selectedFile);
        docRes = await fetch('/api/documents', { method: 'POST', body: form });
      } else if (entryMode === 'url') {
        const cleanUrl = urlInput.trim();
        if (!cleanUrl) {
          throw new Error(
            'Paste a research paper URL (e.g. https://arxiv.org/abs/1706.03762) or choose a sample link below.'
          );
        }
        setStatusMessage(`Fetching open-access document from ${cleanUrl}...`);
        docRes = await fetch('/api/documents', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ url: cleanUrl }),
        });
      } else {
        setStatusMessage('Loading bundled MonsoonFormer offline sample paper...');
        docRes = await fetch('/api/documents', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ useBundledFixture: true }),
        });
      }

      const docData = await docRes.json();
      if (!docRes.ok) {
        throw new Error(docData.error || 'Could not fetch or parse document.');
      }

      setStatusMessage(
        `Extracting claims, retrieving Tier 1–3 sources, and synthesizing voice narration for "${docData.document.model.title}"...`
      );

      const jobRes = await fetch('/api/jobs', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          documentId: docData.document.id,
          depth,
          lengthTarget,
          language,
          llmProvider: settings?.llmProvider ?? 'mock',
          ttsProvider: settings?.ttsProvider ?? 'mock',
        }),
      });
      const jobData = await jobRes.json();
      if (!jobRes.ok) {
        throw new Error(jobData.error || 'Video generation failed.');
      }

      setUrlInput('');
      setSelectedFile(null);
      setStatusMessage(null);
      await onJobCreated(jobData.job.id, jobData.video?.id);
    } catch (err) {
      setStatusMessage(null);
      setError(err instanceof Error ? err.message : 'Unable to process document.');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="min-h-full">
      {/* Google-Labs-Style Tactile Dot-Grid Notebook Startpage Hero */}
      <section
        aria-labelledby="start-here-heading"
        className="notebook-dot-grid border-b border-slate-200 py-8 sm:py-10"
      >
        <div className="mx-auto max-w-7xl px-6 space-y-6">
          <div className="flex flex-col lg:flex-row lg:items-end lg:justify-between gap-4">
            <div className="space-y-1.5 max-w-3xl">
              <div className="text-xs font-semibold uppercase tracking-wide text-blue-700">
                Drishya Research Notebook
              </div>
              <h1
                id="start-here-heading"
                className="font-display text-2xl sm:text-3xl font-bold tracking-tight text-slate-900"
              >
                Start a New Paper Notebook, Sketch &amp; Narrated Podcast
              </h1>
              <p className="text-sm text-slate-600">
                Paste any open-access URL (arXiv, DOI, PubMed Central, HTML/PDF) or upload your own paper. Read side-by-side, anchor notes and freehand sketches directly to spans, listen to a grounded video podcast, and export everything in open portable formats.
              </p>
            </div>
            <button
              type="button"
              onClick={onNewVideo}
              className="inline-flex items-center gap-1.5 rounded-lg border border-slate-300 bg-white px-4 py-2 text-xs font-semibold text-slate-700 hover:bg-slate-50 whitespace-nowrap self-start lg:self-auto"
            >
              Advanced Studio Options
              <ArrowRight className="h-3.5 w-3.5" />
            </button>
          </div>

          {/* Primary Research Input Card */}
          <div className="rounded-xl border border-slate-300/90 bg-white p-6 shadow-sm space-y-6">
            <form onSubmit={handleQuickStartSubmit} className="space-y-4">
              <div className="flex flex-wrap items-center gap-1.5 rounded-lg bg-slate-100 p-1 w-fit">
                {(
                  [
                    { id: 'url', label: 'New Link (arXiv / DOI / URL)' },
                    { id: 'upload', label: 'Upload Document (PDF / DOCX / HTML)' },
                    { id: 'fixture', label: 'Offline Sample Paper' },
                  ] as const
                ).map((tab) => (
                  <button
                    key={tab.id}
                    type="button"
                    onClick={() => {
                      setEntryMode(tab.id);
                      setError(null);
                    }}
                    className={`rounded-md px-3.5 py-2 text-xs font-semibold transition-colors whitespace-nowrap ${
                      entryMode === tab.id
                        ? 'bg-white text-slate-900 shadow-xs'
                        : 'text-slate-600 hover:text-slate-900'
                    }`}
                  >
                    {tab.label}
                  </button>
                ))}
              </div>

              {entryMode === 'url' && (
                <div className="space-y-2.5">
                  <label htmlFor="quick-url-input" className="block text-xs font-semibold text-slate-800">
                    Open-Access Paper URL, DOI, or arXiv ID
                  </label>
                  <div className="flex flex-col md:flex-row gap-3">
                    <div className="relative flex-1">
                      <Globe className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
                      <input
                        id="quick-url-input"
                        type="text"
                        value={urlInput}
                        onChange={(e) => setUrlInput(e.target.value)}
                        placeholder="https://arxiv.org/abs/1706.03762  or  https://doi.org/10....  or  arXiv:2408.09869"
                        className="w-full rounded-lg border border-slate-300 bg-white pl-9 pr-3 py-2.5 text-sm text-slate-900 placeholder:text-slate-400 focus:border-blue-700 focus:outline-none"
                      />
                    </div>
                    <button
                      type="submit"
                      disabled={submitting}
                      className="inline-flex items-center justify-center gap-2 rounded-lg bg-blue-700 px-5 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-blue-800 disabled:opacity-50 whitespace-nowrap"
                    >
                      {submitting ? 'Processing...' : 'Start Research'}
                    </button>
                  </div>

                  <div className="flex flex-wrap items-center gap-2 text-xs text-slate-600">
                    <span className="font-medium text-slate-500">Quick-start papers:</span>
                    {SAMPLE_URLS.map((sample) => (
                      <button
                        key={sample.url}
                        type="button"
                        onClick={() => {
                          setUrlInput(sample.url);
                          setError(null);
                        }}
                        className="rounded-md border border-slate-300 bg-slate-50 px-2.5 py-1 text-xs font-medium text-blue-800 hover:bg-blue-50 hover:border-blue-300 transition-colors"
                      >
                        {sample.label}
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {entryMode === 'upload' && (
                <div className="flex flex-col md:flex-row items-stretch md:items-center gap-3">
                  <label
                    htmlFor="quick-file-input"
                    className="flex-1 flex items-center gap-3 rounded-lg border border-dashed border-slate-300 bg-slate-50 px-4 py-3 cursor-pointer hover:border-blue-600"
                  >
                    <Upload className="h-4 w-4 text-slate-500 shrink-0" />
                    <div className="min-w-0 flex-1">
                      <div className="text-xs font-semibold text-slate-900 truncate">
                        {selectedFile
                          ? selectedFile.name
                          : 'Choose a PDF, DOCX, HTML, or TXT research paper'}
                      </div>
                      <div className="text-[11px] text-slate-500">
                        Parsed locally with layout &amp; text stream extraction · Auto-deletes after{' '}
                        {settings?.retentionDays ?? 30} days
                      </div>
                    </div>
                    <input
                      id="quick-file-input"
                      type="file"
                      accept=".pdf,.docx,.html,.htm,.txt"
                      onChange={(e) => setSelectedFile(e.target.files?.[0] ?? null)}
                      className="sr-only"
                    />
                  </label>
                  <button
                    type="submit"
                    disabled={submitting}
                    className="inline-flex items-center justify-center gap-2 rounded-lg bg-blue-700 px-5 py-3 text-sm font-semibold text-white transition-colors hover:bg-blue-800 disabled:opacity-50 whitespace-nowrap"
                  >
                    {submitting ? 'Processing...' : 'Start Research'}
                  </button>
                </div>
              )}

              {entryMode === 'fixture' && (
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 rounded-lg border border-slate-200 bg-slate-50 p-4">
                  <div className="space-y-1 text-xs text-slate-700">
                    <div className="font-semibold text-slate-900">
                      Offline Demo Paper: Sparse-Attention Transformers for Multi-Horizon Monsoon Rainfall Forecasting
                    </div>
                    <div>
                      CC-BY 4.0 bundled paper with 2 tables, 2 cropped figures, 2 LaTeX equations, and offline recorded LLM/TTS fixtures.
                    </div>
                  </div>
                  <button
                    type="submit"
                    disabled={submitting}
                    className="inline-flex items-center justify-center rounded-lg bg-blue-700 px-5 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-blue-800 disabled:opacity-50 whitespace-nowrap shrink-0"
                  >
                    {submitting ? 'Generating...' : 'Run Offline Sample'}
                  </button>
                </div>
              )}

              {/* Generation Preferences */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-1">
                <div>
                  <label htmlFor="quick-depth" className="block text-[11px] font-medium text-slate-600">
                    Explanation Depth
                  </label>
                  <select
                    id="quick-depth"
                    value={depth}
                    onChange={(e) => setDepth(e.target.value as Depth)}
                    className="mt-1 w-full rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-xs text-slate-900"
                  >
                    <option value="beginner">Beginner (adds analogies)</option>
                    <option value="student">Student (balanced explanation)</option>
                    <option value="expert">Expert (skips basics)</option>
                  </select>
                </div>
                <div>
                  <label htmlFor="quick-length" className="block text-[11px] font-medium text-slate-600">
                    Video Length
                  </label>
                  <select
                    id="quick-length"
                    value={lengthTarget}
                    onChange={(e) => setLengthTarget(e.target.value as LengthTarget)}
                    className="mt-1 w-full rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-xs text-slate-900"
                  >
                    <option value="2min">2 min (Chaptered brief)</option>
                    <option value="5min">5 min (Full walkthrough)</option>
                    <option value="10min">10+ min (Deep seminar)</option>
                  </select>
                </div>
                <div>
                  <label htmlFor="quick-lang" className="block text-[11px] font-medium text-slate-600">
                    Narration Language
                  </label>
                  <select
                    id="quick-lang"
                    value={language}
                    onChange={(e) => setLanguage(e.target.value as LanguageCode)}
                    className="mt-1 w-full rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-xs text-slate-900"
                  >
                    {languages.map((lang) => (
                      <option key={lang.code} value={lang.code}>
                        {lang.name} ({lang.nativeName}) ·{' '}
                        {lang.capability === 'voice_and_captions' ? 'Voice + Captions' : 'Captions only'}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              {statusMessage && (
                <div className="rounded-lg border border-blue-200 bg-blue-50 px-4 py-2.5 text-xs font-medium text-blue-900">
                  {statusMessage}
                </div>
              )}

              {error && (
                <div
                  role="alert"
                  className="rounded-lg border border-red-200 bg-red-50 px-4 py-2.5 text-xs font-medium text-red-800"
                >
                  {error}
                </div>
              )}
            </form>

            {/* What You Get Orientation Strip */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 border-t border-slate-200 pt-5">
              <div className="space-y-1">
                <div className="text-xs font-semibold text-slate-900">
                  1. Notes &amp; Freehand Sketches
                </div>
                <p className="text-xs text-slate-600 leading-relaxed">
                  Anchor study notes and dot-grid canvas diagrams directly to any paragraph, table, or equation—linked with a live connecting arrow.
                </p>
              </div>
              <div className="space-y-1">
                <div className="text-xs font-semibold text-slate-900">
                  2. Apple Preview Split Reader
                </div>
                <p className="text-xs text-slate-600 leading-relaxed">
                  Inspect pages on the left while clicking linked claims, Tier 1–3 external clarifications, and citation-locked Q&amp;A on the right.
                </p>
              </div>
              <div className="space-y-1">
                <div className="text-xs font-semibold text-slate-900">
                  3. Narrated Video &amp; Portable Export
                </div>
                <p className="text-xs text-slate-600 leading-relaxed">
                  Listen to voice-narrated chaptered MP4s and share complete research archives as self-contained HTML, Markdown+SVG, or JSON.
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Research History */}
      <main className="mx-auto max-w-7xl px-6 py-8 space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-4">
          <div>
            <h2 className="font-display text-xl font-bold tracking-tight text-slate-900">
              Your Research History
            </h2>
            <p className="text-xs text-slate-500">
              Resume reading, annotate with notes and sketches, or export complete portable notebooks.
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <div className="relative">
              <Search className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-slate-400" />
              <input
                type="search"
                aria-label="Filter research history"
                value={historyQuery}
                onChange={(e) => setHistoryQuery(e.target.value)}
                placeholder="Filter by title, author, URL..."
                className="w-56 rounded-lg border border-slate-300 bg-white pl-8 pr-3 py-1.5 text-xs text-slate-900 placeholder:text-slate-400 focus:border-blue-700 focus:outline-none"
              />
            </div>

            <div className="flex items-center rounded-lg border border-slate-300 bg-white p-0.5 text-xs">
              <button
                type="button"
                onClick={() => setHistoryFilter('all')}
                className={`rounded-md px-2.5 py-1 font-medium transition-colors ${
                  historyFilter === 'all' ? 'bg-blue-700 text-white' : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                All ({items.length})
              </button>
              <button
                type="button"
                onClick={() => setHistoryFilter('annotated')}
                className={`rounded-md px-2.5 py-1 font-medium transition-colors ${
                  historyFilter === 'annotated'
                    ? 'bg-blue-700 text-white'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                With Notes &amp; Sketches
              </button>
            </div>
          </div>
        </div>

        {loading ? (
          <div className="space-y-3" aria-busy="true">
            {[1, 2].map((n) => (
              <div key={n} className="h-28 rounded-xl border border-slate-200 bg-white animate-pulse" />
            ))}
          </div>
        ) : filteredItems.length === 0 ? (
          <div className="rounded-xl border border-slate-200 bg-white p-10 text-center space-y-2">
            <FileText className="mx-auto h-8 w-8 text-slate-400" />
            <h3 className="text-base font-semibold text-slate-900">
              {items.length === 0 ? 'No research history yet' : 'No matching research items'}
            </h3>
            <p className="mx-auto max-w-md text-xs text-slate-600">
              {items.length === 0
                ? 'Paste an open-access paper URL or upload a document in the Start Here card above to create your first research notebook.'
                : 'Clear your search filter to view all research papers in your workspace.'}
            </p>
          </div>
        ) : (
          <div className="divide-y divide-slate-200 rounded-xl border border-slate-200 bg-white">
            {filteredItems.map(({ document, latestJob, latestVideo, notesCount = 0, sketchesCount = 0 }) => {
              const isSamplePaper = document.id === 'doc_monsoon_2025';
              const status = latestJob?.status ?? 'ready';
              const statusText =
                status === 'ready'
                  ? 'Ready'
                  : status === 'failed'
                    ? `Failed (${latestJob?.failedStage})`
                    : `Processing · ${status}`;
              const statusColor =
                status === 'ready'
                  ? 'text-emerald-700'
                  : status === 'failed'
                    ? 'text-red-700'
                    : 'text-amber-700';

              return (
                <div
                  key={document.id}
                  className="flex flex-col lg:flex-row lg:items-center justify-between gap-4 p-6 transition-colors hover:bg-slate-50/60"
                >
                  <div className="space-y-1.5 min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2 text-xs text-slate-500 tabular-nums">
                      <span className={`font-semibold ${statusColor}`}>{statusText}</span>
                      <span aria-hidden="true">·</span>
                      <span className="font-medium text-slate-700">
                        {isSamplePaper
                          ? 'Bundled Offline Sample'
                          : `Source: ${document.model.sourceFormat.toUpperCase()}`}
                      </span>
                      <span aria-hidden="true">·</span>
                      <span>
                        {notesCount} {notesCount === 1 ? 'note' : 'notes'}
                      </span>
                      <span aria-hidden="true">·</span>
                      <span>
                        {sketchesCount} {sketchesCount === 1 ? 'sketch' : 'sketches'}
                      </span>
                      <span aria-hidden="true">·</span>
                      <span>{document.model.sections.length} sections</span>
                      <span aria-hidden="true">·</span>
                      <span>{document.model.paragraphs.length} spans</span>
                      <span aria-hidden="true">·</span>
                      <span>Auto-deletes {new Date(document.expiresAt).toLocaleDateString()}</span>
                    </div>

                    <h3 className="font-display text-lg font-semibold text-slate-900 leading-snug">
                      {document.model.title}
                    </h3>

                    <div className="text-xs text-slate-600 truncate">
                      {document.model.authors.slice(0, 4).join(', ')} · {document.model.venue}
                      {document.model.sourceUrl && (
                        <>
                          {' '}
                          · <span className="font-mono text-slate-500">{document.model.sourceUrl}</span>
                        </>
                      )}
                      {latestVideo && (
                        <>
                          {' '}
                          · Video: {latestVideo.depth} / {latestVideo.lengthTarget} /{' '}
                          {latestVideo.language.toUpperCase()} ({latestVideo.ttsVoice})
                        </>
                      )}
                    </div>
                  </div>

                  <div className="flex flex-wrap items-center gap-2 shrink-0">
                    {latestVideo && (
                      <button
                        type="button"
                        onClick={() => onOpenPlayer(latestVideo.id)}
                        className="inline-flex items-center gap-1.5 rounded-lg bg-blue-700 px-4 py-2 text-xs font-semibold text-white hover:bg-blue-800 whitespace-nowrap"
                      >
                        <Play className="h-3.5 w-3.5" />
                        Open Notebook &amp; Video
                      </button>
                    )}
                    <a
                      href={`/api/documents/${document.id}/export?format=html`}
                      download
                      className="inline-flex items-center gap-1.5 rounded-lg border border-slate-300 bg-white px-3.5 py-2 text-xs font-medium text-slate-700 hover:bg-slate-50 whitespace-nowrap"
                    >
                      <Download className="h-3.5 w-3.5" />
                      Export HTML
                    </a>
                    {latestJob && (
                      <button
                        type="button"
                        onClick={() => onInspectJob(latestJob.id)}
                        className="inline-flex items-center gap-1.5 rounded-lg border border-slate-300 bg-white px-3.5 py-2 text-xs font-medium text-slate-700 hover:bg-slate-50 whitespace-nowrap"
                      >
                        <RefreshCw className="h-3.5 w-3.5" />
                        Job Stages
                      </button>
                    )}
                    <button
                      type="button"
                      onClick={() => onDeleteDocument(document.id)}
                      aria-label={`Delete ${document.model.title} now`}
                      className="inline-flex items-center gap-1.5 rounded-lg border border-red-200 bg-white px-3.5 py-2 text-xs font-medium text-red-700 hover:bg-red-50 whitespace-nowrap"
                    >
                      <Trash2 className="h-3.5 w-3.5" />
                      Delete Now
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </main>
    </div>
  );
}
