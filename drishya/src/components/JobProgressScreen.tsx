import { CheckCircle2, Play, RotateCcw, XCircle } from 'lucide-react';
import { useState } from 'react';
import { JobRecord, JobStageName } from '../types.ts';

interface JobProgressScreenProps {
  jobs: JobRecord[];
  selectedJobId: string | null;
  onSelectJob: (jobId: string) => void;
  onRetryStage: (jobId: string, stage: JobStageName) => Promise<void>;
  onOpenPlayer: (videoId: string) => void;
}

export function JobProgressScreen({
  jobs,
  selectedJobId,
  onSelectJob,
  onRetryStage,
  onOpenPlayer,
}: JobProgressScreenProps) {
  const [retrying, setRetrying] = useState(false);

  const activeJob = jobs.find((j) => j.id === selectedJobId) ?? jobs[0];

  if (!activeJob) {
    return (
      <main className="mx-auto max-w-5xl px-6 py-12 text-center">
        <h1 className="font-display text-2xl font-bold text-slate-900">No Pipeline Jobs Yet</h1>
        <p className="mt-2 text-sm text-slate-600">
          Create a video from the Library or New Video tab to inspect stage-by-stage progress.
        </p>
      </main>
    );
  }

  return (
    <main className="mx-auto max-w-6xl px-6 py-8 space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-4 border-b border-slate-200 pb-5">
        <div className="space-y-1">
          <h1 className="font-display text-3xl font-bold tracking-tight text-slate-900">
            Pipeline Job Progress
          </h1>
          <div className="text-xs text-slate-600 tabular-nums">
            Job {activeJob.id} · {activeJob.depth} · {activeJob.lengthTarget} ·{' '}
            {activeJob.language.toUpperCase()} · Provider {activeJob.llmProvider} (
            {activeJob.llmModel}) · {activeJob.totalTokens} tokens · $
            {activeJob.totalCostUsd.toFixed(5)}
          </div>
        </div>

        <div className="flex items-center gap-3">
          {jobs.length > 1 && (
            <select
              aria-label="Select job"
              value={activeJob.id}
              onChange={(e) => onSelectJob(e.target.value)}
              className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-xs font-medium text-slate-800"
            >
              {jobs.map((j) => (
                <option key={j.id} value={j.id}>
                  {j.id} ({j.language.toUpperCase()} · {j.status})
                </option>
              ))}
            </select>
          )}
          {activeJob.videoId && (
            <button
              type="button"
              onClick={() => onOpenPlayer(activeJob.videoId!)}
              className="inline-flex items-center gap-1.5 rounded-lg bg-blue-700 px-4 py-2 text-xs font-semibold text-white hover:bg-blue-800 whitespace-nowrap"
            >
              <Play className="h-3.5 w-3.5" />
              Watch Rendered Video
            </button>
          )}
        </div>
      </div>

      {/* Stage-by-Stage Resumable Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {activeJob.stages.map((st, idx) => {
          const isFailed = st.status === 'failed';
          const isDone = st.status === 'completed';
          return (
            <div
              key={st.stage}
              className={`rounded-xl border bg-white p-5 space-y-3 ${
                isFailed ? 'border-red-300' : 'border-slate-200'
              }`}
            >
              <div className="flex items-center justify-between gap-2">
                <div className="text-sm font-semibold text-slate-900">
                  0{idx + 1}. {st.stage.charAt(0).toUpperCase() + st.stage.slice(1)}
                </div>
                <span
                  className={`inline-flex items-center gap-1 text-xs font-semibold ${
                    isDone
                      ? 'text-emerald-700'
                      : isFailed
                        ? 'text-red-700'
                        : 'text-slate-500'
                  }`}
                >
                  {isDone && <CheckCircle2 className="h-3.5 w-3.5" />}
                  {isFailed && <XCircle className="h-3.5 w-3.5" />}
                  {st.status}
                </span>
              </div>

              <p className="text-xs text-slate-600 leading-relaxed min-h-[36px]">
                {st.message}
              </p>

              <div className="border-t border-slate-100 pt-2.5 text-[11px] font-mono text-slate-500 tabular-nums space-y-0.5">
                <div>
                  Provider: {st.provider} · {st.model}
                </div>
                <div>
                  Prompt: {st.promptVersion} · {st.durationMs} ms
                </div>
                <div>
                  Tokens: {st.inputTokens + st.outputTokens} · Cost: ${st.costUsd.toFixed(5)}
                </div>
              </div>

              {isFailed && (
                <button
                  type="button"
                  disabled={retrying}
                  onClick={async () => {
                    setRetrying(true);
                    await onRetryStage(activeJob.id, st.stage);
                    setRetrying(false);
                  }}
                  className="inline-flex w-full items-center justify-center gap-1.5 rounded-lg bg-red-700 px-3 py-2 text-xs font-semibold text-white hover:bg-red-800 disabled:opacity-50"
                >
                  <RotateCcw className="h-3.5 w-3.5" />
                  {retrying ? 'Retrying Stage...' : `Retry ${st.stage} Stage`}
                </button>
              )}
            </div>
          );
        })}
      </div>

      {/* Extracted Understanding & Clarifications Preview */}
      {activeJob.understand && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 pt-2">
          <section className="rounded-xl border border-slate-200 bg-white p-5 space-y-3">
            <h2 className="text-sm font-semibold text-slate-900">
              Extracted Claims & Hard Parts ({activeJob.understand.hardParts.length})
            </h2>
            <ul className="space-y-2 text-xs text-slate-700">
              {activeJob.understand.claims.map((c) => (
                <li key={c.id} className="border-b border-slate-100 pb-2">
                  <span>{c.statement} </span>
                  <span className="font-mono text-blue-700">[{c.citationKey}]</span>
                </li>
              ))}
            </ul>
          </section>

          <section className="rounded-xl border border-slate-200 bg-white p-5 space-y-3">
            <h2 className="text-sm font-semibold text-slate-900">
              Clarification Sources ({activeJob.clarifications?.length ?? 0})
            </h2>
            <ul className="space-y-2 text-xs text-slate-700">
              {(activeJob.clarifications ?? []).map((src) => (
                <li key={src.id} className="border-b border-slate-100 pb-2 space-y-0.5">
                  <div className="font-semibold text-slate-900">
                    Tier {src.tier} · {src.providerName}{' '}
                    {src.confidenceLabel === 'lower confidence' && '· Lower confidence'}
                    {src.viewLabel && ` · ${src.viewLabel}`}
                  </div>
                  <div>“{src.quote}”</div>
                </li>
              ))}
            </ul>
          </section>
        </div>
      )}
    </main>
  );
}
