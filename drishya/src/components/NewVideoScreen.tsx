import { Upload } from 'lucide-react';
import { useState } from 'react';
import {
  Depth,
  LanguageCode,
  LanguageInfo,
  LengthTarget,
  LLMProviderName,
  TTSProviderName,
  WorkspaceSettings,
} from '../types.ts';

interface NewVideoScreenProps {
  languages: LanguageInfo[];
  settings: WorkspaceSettings;
  onJobCreated: (jobId: string, videoId?: string) => void;
}

export function NewVideoScreen({
  languages,
  settings,
  onJobCreated,
}: NewVideoScreenProps) {
  const [sourceMode, setSourceMode] = useState<'fixture' | 'url' | 'upload'>('url');
  const [urlInput, setUrlInput] = useState('');
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [depth, setDepth] = useState<Depth>('student');
  const [lengthTarget, setLengthTarget] = useState<LengthTarget>('2min');
  const [language, setLanguage] = useState<LanguageCode>('en');
  const [llmProvider, setLlmProvider] = useState<LLMProviderName>(settings.llmProvider);
  const [ttsProvider, setTtsProvider] = useState<TTSProviderName>(settings.ttsProvider);
  const [simulateFail, setSimulateFail] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const selectedLangInfo = languages.find((l) => l.code === language);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSubmitting(true);
    setError(null);
    try {
      let docRes: Response;
      if (sourceMode === 'upload') {
        if (!selectedFile) throw new Error('Please choose a PDF, DOCX, or HTML file to upload.');
        const form = new FormData();
        form.append('file', selectedFile);
        docRes = await fetch('/api/documents', { method: 'POST', body: form });
      } else if (sourceMode === 'url') {
        if (!urlInput.trim()) {
          throw new Error('Enter an open-access paper URL (e.g. https://arxiv.org/abs/1706.03762) or select an example link.');
        }
        docRes = await fetch('/api/documents', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ url: urlInput.trim() }),
        });
      } else {
        docRes = await fetch('/api/documents', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ useBundledFixture: true }),
        });
      }

      const docData = await docRes.json();
      if (!docRes.ok) throw new Error(docData.error || 'Document ingestion failed.');

      const jobRes = await fetch('/api/jobs', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          documentId: docData.document.id,
          depth,
          lengthTarget,
          language,
          llmProvider,
          ttsProvider,
          simulateFailStage: simulateFail ? 'plan' : undefined,
        }),
      });
      const jobData = await jobRes.json();
      if (!jobRes.ok) throw new Error(jobData.error || 'Failed to launch video job.');

      onJobCreated(jobData.job.id, jobData.video?.id);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unable to create video job');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main className="mx-auto max-w-5xl px-6 py-8 space-y-6">
      <div className="border-b border-slate-200 pb-5 space-y-1">
        <h1 className="font-display text-3xl font-bold tracking-tight text-slate-900">
          Create Narrated Video Podcast
        </h1>
        <p className="text-sm text-slate-600">
          Provide an open-access paper link (arXiv, DOI, PubMed Central, HTML/PDF) or upload a local file. Drishya extracts sections, tables, figures, and equations from that document, fetches Tier 1–3 background sources, and builds a narrated MP4 + split reader.
        </p>
      </div>

      <form onSubmit={handleSubmit} className="grid grid-cols-1 lg:grid-cols-12 gap-8">
        {/* Left Column: Document & Audience */}
        <div className="lg:col-span-7 space-y-6">
          <section className="rounded-xl border border-slate-200 bg-white p-6 space-y-4">
            <h2 className="text-base font-semibold text-slate-900">1. Research Document Source</h2>

            <div className="flex items-center gap-1 rounded-lg bg-slate-100 p-1">
              {(
                [
                  { id: 'url', label: 'arXiv / DOI / URL' },
                  { id: 'upload', label: 'Upload PDF / DOCX / HTML' },
                  { id: 'fixture', label: 'Offline Sample Paper' },
                ] as const
              ).map((mode) => (
                <button
                  key={mode.id}
                  type="button"
                  onClick={() => setSourceMode(mode.id)}
                  className={`flex-1 rounded-md px-3 py-2 text-xs font-medium transition-colors whitespace-nowrap ${
                    sourceMode === mode.id
                      ? 'bg-white text-slate-900 shadow-xs'
                      : 'text-slate-600 hover:text-slate-900'
                  }`}
                >
                  {mode.label}
                </button>
              ))}
            </div>

            {sourceMode === 'fixture' && (
              <div className="rounded-lg border border-slate-200 bg-slate-50 p-4 text-xs text-slate-700 space-y-1">
                <div className="font-semibold text-slate-900">
                  Offline Sample: Sparse-Attention Transformers for Multi-Horizon Monsoon Rainfall Forecasting
                </div>
                <div>
                  CC-BY 4.0 bundled demo paper with 2 quantitative tables, 2 figures, 2 LaTeX equations, and offline recorded LLM/TTS fixtures.
                </div>
              </div>
            )}

            {sourceMode === 'url' && (
              <div className="space-y-2.5">
                <label htmlFor="doc-url" className="block text-xs font-medium text-slate-700">
                  Open-access document URL, DOI, or arXiv ID (respects robots.txt; sends no cookies)
                </label>
                <input
                  id="doc-url"
                  type="text"
                  required
                  value={urlInput}
                  onChange={(e) => setUrlInput(e.target.value)}
                  placeholder="https://arxiv.org/abs/1706.03762  or  https://arxiv.org/abs/2408.09869"
                  className="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm text-slate-900 focus:border-blue-700 focus:outline-none"
                />
                <div className="flex flex-wrap items-center gap-2 text-xs">
                  <span className="text-slate-500">Real examples:</span>
                  {[
                    { label: 'arXiv:1706.03762 (Transformers)', url: 'https://arxiv.org/abs/1706.03762' },
                    { label: 'arXiv:2408.09869 (Docling)', url: 'https://arxiv.org/abs/2408.09869' },
                    { label: 'arXiv:2305.10601 (Tree of Thoughts)', url: 'https://arxiv.org/abs/2305.10601' },
                  ].map((ex) => (
                    <button
                      key={ex.url}
                      type="button"
                      onClick={() => setUrlInput(ex.url)}
                      className="rounded border border-slate-300 bg-slate-50 px-2 py-1 text-[11px] font-medium text-blue-800 hover:bg-blue-50"
                    >
                      {ex.label}
                    </button>
                  ))}
                </div>
              </div>
            )}

            {sourceMode === 'upload' && (
              <div>
                <label
                  htmlFor="doc-file"
                  className="flex flex-col items-center justify-center gap-2 rounded-lg border border-dashed border-slate-300 bg-slate-50 p-6 text-center cursor-pointer hover:border-blue-500"
                >
                  <Upload className="h-5 w-5 text-slate-500" />
                  <span className="text-xs font-medium text-slate-800">
                    {selectedFile ? selectedFile.name : 'Choose PDF, DOCX, or HTML file'}
                  </span>
                  <span className="text-xs text-slate-500">
                    Layout-aware parsing with OCR fallback · Auto-deleted after {settings.retentionDays} days
                  </span>
                  <input
                    id="doc-file"
                    type="file"
                    accept=".pdf,.docx,.html,.htm,.txt"
                    onChange={(e) => setSelectedFile(e.target.files?.[0] ?? null)}
                    className="sr-only"
                  />
                </label>
              </div>
            )}
          </section>

          <section className="rounded-xl border border-slate-200 bg-white p-6 space-y-5">
            <h2 className="text-base font-semibold text-slate-900">2. Depth & Length</h2>

            <div className="space-y-2">
              <div className="text-xs font-medium text-slate-700">Explanation Depth</div>
              <div className="grid grid-cols-3 gap-2">
                {(
                  [
                    { id: 'beginner', label: 'Beginner', desc: 'Adds marked analogies' },
                    { id: 'student', label: 'Student', desc: 'Balanced theory & terms' },
                    { id: 'expert', label: 'Expert', desc: 'Skips basic primers' },
                  ] as const
                ).map((d) => (
                  <button
                    key={d.id}
                    type="button"
                    onClick={() => setDepth(d.id)}
                    className={`rounded-lg border p-3 text-left transition-colors ${
                      depth === d.id
                        ? 'border-blue-700 bg-blue-50 text-slate-900'
                        : 'border-slate-200 bg-white text-slate-700 hover:bg-slate-50'
                    }`}
                  >
                    <div className="text-xs font-semibold">{d.label}</div>
                    <div className="mt-0.5 text-[11px] text-slate-500">{d.desc}</div>
                  </button>
                ))}
              </div>
            </div>

            <div className="space-y-2">
              <div className="text-xs font-medium text-slate-700">Target Video Length</div>
              <div className="grid grid-cols-3 gap-2">
                {(
                  [
                    { id: '2min', label: '2 min', desc: 'Chaptered brief' },
                    { id: '5min', label: '5 min', desc: 'Full walkthrough' },
                    { id: '10min', label: '10+ min', desc: 'Deep seminar' },
                  ] as const
                ).map((l) => (
                  <button
                    key={l.id}
                    type="button"
                    onClick={() => setLengthTarget(l.id)}
                    className={`rounded-lg border p-3 text-left transition-colors ${
                      lengthTarget === l.id
                        ? 'border-blue-700 bg-blue-50 text-slate-900'
                        : 'border-slate-200 bg-white text-slate-700 hover:bg-slate-50'
                    }`}
                  >
                    <div className="text-xs font-semibold tabular-nums">{l.label}</div>
                    <div className="mt-0.5 text-[11px] text-slate-500">{l.desc}</div>
                  </button>
                ))}
              </div>
            </div>
          </section>
        </div>

        {/* Right Column: Language & Providers */}
        <div className="lg:col-span-5 space-y-6">
          <section className="rounded-xl border border-slate-200 bg-white p-6 space-y-4">
            <h2 className="text-base font-semibold text-slate-900">3. Narration Language & Voice</h2>

            <div>
              <label htmlFor="lang-select" className="block text-xs font-medium text-slate-700">
                Narration & On-Screen Language
              </label>
              <select
                id="lang-select"
                value={language}
                onChange={(e) => setLanguage(e.target.value as LanguageCode)}
                className="mt-1.5 w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 focus:border-blue-700 focus:outline-none"
              >
                {languages.map((lang) => (
                  <option key={lang.code} value={lang.code}>
                    {lang.name} ({lang.nativeName}) —{' '}
                    {lang.capability === 'voice_and_captions' ? 'Voice + Captions' : 'Captions only'}
                  </option>
                ))}
              </select>
            </div>

            {selectedLangInfo && (
              <div className="rounded-lg border border-slate-200 bg-slate-50 p-3.5 text-xs text-slate-700 space-y-1">
                <div>
                  Capability:{' '}
                  <strong>
                    {selectedLangInfo.capability === 'voice_and_captions'
                      ? 'Voice narration + WebVTT captions'
                      : 'Captions only (no voice synthesis for this language)'}
                  </strong>
                </div>
                <div>
                  Chosen voice:{' '}
                  <strong>
                    {ttsProvider === 'piper'
                      ? selectedLangInfo.piperVoice
                      : selectedLangInfo.defaultVoice}
                  </strong>
                </div>
                <div>
                  Layout direction:{' '}
                  <strong>{selectedLangInfo.dir === 'rtl' ? 'Right-to-Left (Urdu RTL)' : 'Left-to-Right'}</strong>
                </div>
              </div>
            )}

            <div className="grid grid-cols-2 gap-3 pt-1">
              <div>
                <label htmlFor="llm-prov" className="block text-xs font-medium text-slate-700">
                  LLM Provider
                </label>
                <select
                  id="llm-prov"
                  value={llmProvider}
                  onChange={(e) => setLlmProvider(e.target.value as LLMProviderName)}
                  className="mt-1 w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-xs text-slate-900"
                >
                  <option value="mock">Mock (Offline Fixtures)</option>
                  <option value="gemini">Gemini ({settings.llmModels.gemini})</option>
                  <option value="anthropic">Anthropic ({settings.llmModels.anthropic})</option>
                  <option value="openai">OpenAI ({settings.llmModels.openai})</option>
                  <option value="ollama">Ollama ({settings.llmModels.ollama})</option>
                </select>
              </div>
              <div>
                <label htmlFor="tts-prov" className="block text-xs font-medium text-slate-700">
                  TTS Provider
                </label>
                <select
                  id="tts-prov"
                  value={ttsProvider}
                  onChange={(e) => setTtsProvider(e.target.value as TTSProviderName)}
                  className="mt-1 w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-xs text-slate-900"
                >
                  <option value="mock">Mock (Offline Fixtures)</option>
                  <option value="cloud">Cloud Neural TTS</option>
                  <option value="piper">Piper (Local TTS)</option>
                </select>
              </div>
            </div>

            <label className="flex items-center gap-2 pt-2 text-xs text-slate-600 cursor-pointer">
              <input
                type="checkbox"
                checked={simulateFail}
                onChange={(e) => setSimulateFail(e.target.checked)}
                className="rounded border-slate-300 accent-blue-700"
              />
              Simulate failure at Storyboard Planning stage (to inspect stage retry)
            </label>

            {error && (
              <p role="alert" className="text-xs font-medium text-red-700">
                {error}
              </p>
            )}

            <button
              type="submit"
              disabled={submitting}
              className="w-full rounded-lg bg-blue-700 px-5 py-3 text-sm font-semibold text-white transition-colors hover:bg-blue-800 disabled:opacity-50"
            >
              {submitting ? 'Running Pipeline & Assembling MP4...' : 'Generate Grounded Video'}
            </button>
          </section>
        </div>
      </form>
    </main>
  );
}
