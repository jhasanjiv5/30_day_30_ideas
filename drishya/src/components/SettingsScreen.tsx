import { useState } from 'react';
import {
  AuditLogEntry,
  LLMProviderName,
  TTSProviderName,
  WorkspaceSettings,
} from '../types.ts';

interface SettingsScreenProps {
  settings: WorkspaceSettings;
  auditLogs: AuditLogEntry[];
  onSaveSettings: (patch: Partial<WorkspaceSettings>) => Promise<void>;
  onRunRetentionSweep: () => Promise<{ deletedDocuments: string[]; expiredShareLinks: number }>;
}

export function SettingsScreen({
  settings,
  auditLogs,
  onSaveSettings,
  onRunRetentionSweep,
}: SettingsScreenProps) {
  const [draft, setDraft] = useState<WorkspaceSettings>(settings);
  const [saving, setSaving] = useState(false);
  const [statusMsg, setStatusMsg] = useState<string | null>(null);

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setStatusMsg(null);
    await onSaveSettings(draft);
    setSaving(false);
    setStatusMsg('Workspace provider and privacy settings saved.');
  }

  return (
    <main className="mx-auto max-w-6xl px-6 py-8 space-y-8">
      <div className="border-b border-slate-200 pb-5 space-y-1">
        <h1 className="font-display text-3xl font-bold tracking-tight text-slate-900">
          Workspace Settings & Privacy Controls
        </h1>
        <p className="text-sm text-slate-600">
          Configure LLM/TTS providers, model identifiers, automatic retention windows, and inspect redacted audit logs. API keys stay strictly server-side.
        </p>
      </div>

      <form onSubmit={handleSave} className="grid grid-cols-1 lg:grid-cols-12 gap-8">
        <section className="lg:col-span-7 rounded-xl border border-slate-200 bg-white p-6 space-y-5">
          <h2 className="text-base font-semibold text-slate-900">
            LLM & TTS Provider Configuration
          </h2>

          <label className="flex items-center justify-between gap-4 rounded-lg border border-slate-200 bg-slate-50 p-3.5 cursor-pointer">
            <div>
              <div className="text-xs font-semibold text-slate-900">
                Offline Mock Mode (Default for CI & Local Verification)
              </div>
              <div className="text-xs text-slate-600">
                Uses bundled CC-BY paper and recorded fixtures with zero external network or API keys.
              </div>
            </div>
            <input
              type="checkbox"
              checked={draft.mockMode}
              onChange={(e) => setDraft({ ...draft, mockMode: e.target.checked })}
              className="h-4 w-4 accent-blue-700"
            />
          </label>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label htmlFor="set-llm" className="block text-xs font-medium text-slate-700">
                Active LLM Provider
              </label>
              <select
                id="set-llm"
                value={draft.llmProvider}
                onChange={(e) =>
                  setDraft({ ...draft, llmProvider: e.target.value as LLMProviderName })
                }
                className="mt-1 w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm"
              >
                <option value="mock">Mock (Recorded Fixtures)</option>
                <option value="gemini">Gemini / Vertex</option>
                <option value="anthropic">Anthropic</option>
                <option value="openai">OpenAI</option>
                <option value="ollama">Ollama (Local OpenAI-Compatible)</option>
              </select>
            </div>

            <div>
              <label htmlFor="set-tts" className="block text-xs font-medium text-slate-700">
                Active TTS Provider
              </label>
              <select
                id="set-tts"
                value={draft.ttsProvider}
                onChange={(e) =>
                  setDraft({ ...draft, ttsProvider: e.target.value as TTSProviderName })
                }
                className="mt-1 w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm"
              >
                <option value="mock">Mock (Recorded Voices)</option>
                <option value="cloud">Cloud Neural TTS</option>
                <option value="piper">Piper (Local Offline TTS)</option>
              </select>
            </div>
          </div>

          <div className="space-y-3">
            <div className="text-xs font-semibold text-slate-800">
              Configured Model Names (Never Hardcoded)
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              {(['gemini', 'anthropic', 'openai', 'ollama'] as const).map((prov) => (
                <div key={prov}>
                  <label htmlFor={`model-${prov}`} className="block text-[11px] font-medium text-slate-600">
                    {prov.toUpperCase()} Model ID
                  </label>
                  <input
                    id={`model-${prov}`}
                    type="text"
                    value={draft.llmModels[prov]}
                    onChange={(e) =>
                      setDraft({
                        ...draft,
                        llmModels: { ...draft.llmModels, [prov]: e.target.value },
                      })
                    }
                    className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-1.5 font-mono text-xs text-slate-900"
                  />
                </div>
              ))}
            </div>
          </div>

          <div>
            <label htmlFor="fallback-chain" className="block text-xs font-medium text-slate-700">
              Admin Fallback Chain (comma-separated)
            </label>
            <input
              id="fallback-chain"
              type="text"
              value={draft.fallbackChain.join(', ')}
              onChange={(e) =>
                setDraft({
                  ...draft,
                  fallbackChain: e.target.value
                    .split(',')
                    .map((s) => s.trim())
                    .filter((s): s is LLMProviderName =>
                      ['mock', 'gemini', 'anthropic', 'openai', 'ollama'].includes(s)
                    ),
                })
              }
              className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 font-mono text-xs text-slate-900"
            />
          </div>
        </section>

        {/* Privacy & Retention */}
        <section className="lg:col-span-5 rounded-xl border border-slate-200 bg-white p-6 space-y-5">
          <h2 className="text-base font-semibold text-slate-900">
            Privacy, Retention & Zero-Training Policy
          </h2>

          <div>
            <label htmlFor="retention-days" className="block text-xs font-medium text-slate-700">
              Auto-Delete Documents & Videos After (Days)
            </label>
            <input
              id="retention-days"
              type="number"
              min={1}
              max={365}
              value={draft.retentionDays}
              onChange={(e) =>
                setDraft({ ...draft, retentionDays: Number(e.target.value) || 30 })
              }
              className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 font-mono text-sm tabular-nums text-slate-900"
            />
            <p className="mt-1 text-xs text-slate-500">
              Default: 30 days. Removes database rows, MP4/VTT objects, and share links.
            </p>
          </div>

          <div className="rounded-lg border border-slate-200 bg-slate-50 p-3.5 text-xs text-slate-700 space-y-1.5">
            <div className="font-semibold text-slate-900">Zero-Training & Log Redaction</div>
            <p>
              API calls use zero-data-retention / non-training provider endpoints where configured, and server logs never store document text or prompt contents in plain text.
            </p>
          </div>

          <div className="flex flex-col gap-2 pt-2">
            <button
              type="submit"
              disabled={saving}
              className="w-full rounded-lg bg-blue-700 px-4 py-2.5 text-xs font-semibold text-white hover:bg-blue-800 disabled:opacity-50"
            >
              {saving ? 'Saving...' : 'Save Settings'}
            </button>

            <button
              type="button"
              onClick={async () => {
                const res = await onRunRetentionSweep();
                setStatusMsg(
                  `Retention sweep completed: ${res.deletedDocuments.length} expired documents, ${res.expiredShareLinks} expired share links purged.`
                );
              }}
              className="w-full rounded-lg border border-slate-300 bg-white px-4 py-2 text-xs font-medium text-slate-700 hover:bg-slate-50"
            >
              Run Retention Sweep Now
            </button>
          </div>

          {statusMsg && (
            <p role="status" className="text-xs font-medium text-emerald-700">
              {statusMsg}
            </p>
          )}
        </section>
      </form>

      {/* Redacted Audit Log */}
      <section className="rounded-xl border border-slate-200 bg-white p-6 space-y-3">
        <h2 className="text-base font-semibold text-slate-900">
          Redacted Privacy Audit Log (No Document Text or Prompts Logged)
        </h2>
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-slate-200 text-slate-500">
              <tr>
                <th className="py-2 pr-4 font-medium">Timestamp</th>
                <th className="py-2 pr-4 font-medium">Action</th>
                <th className="py-2 pr-4 font-medium">Resource</th>
                <th className="py-2 font-medium">Redacted Summary</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 text-slate-700">
              {auditLogs.slice(0, 12).map((log) => (
                <tr key={log.id} className="h-9">
                  <td className="py-2 pr-4 font-mono tabular-nums whitespace-nowrap">
                    {new Date(log.timestamp).toLocaleString()}
                  </td>
                  <td className="py-2 pr-4 font-mono">{log.action}</td>
                  <td className="py-2 pr-4 font-mono">{log.resourceId}</td>
                  <td className="py-2">{log.note}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  );
}
