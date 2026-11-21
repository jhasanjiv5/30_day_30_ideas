import { CheckCircle2, RotateCcw, Shield, ShieldCheck } from 'lucide-react';
import { CopyCommandButton } from './CopyCommandButton';

const CORE_COMMANDS = [
  {
    cmd: 'kavach install --claude-code --user',
    purpose: 'First-time setup',
    desc: 'Backs up settings.json byte-for-byte and wires all four Claude Code hooks.',
  },
  {
    cmd: 'kavach doctor',
    purpose: 'Health check',
    desc: 'Verifies binary, 22 embedded L0 rules, SHA-256 hook integrity, and optional Ollama L2.',
  },
  {
    cmd: 'kavach selftest',
    purpose: 'Offline proof',
    desc: 'Runs 75 labelled attack + benign fixtures locally with zero cloud calls.',
  },
  {
    cmd: 'kavach audit',
    purpose: 'Machine hygiene',
    desc: 'Scores credential file permissions, shell env tokens, git history, and MCP servers.',
  },
  {
    cmd: 'kavach scan --redact <file>',
    purpose: 'Clean a file',
    desc: 'Replaces leaked keys and PII with safe redacted previews before sharing.',
  },
  {
    cmd: 'kavach uninstall',
    purpose: 'Safe undo',
    desc: 'Unhooks Kavach cleanly—preserves modes, MCP servers, and other apps added after install.',
  },
];

const UNINSTALL_STEPS = [
  {
    step: '01',
    title: 'Unhook Claude Code without touching your other apps',
    detail:
      'Auto-detects whether you installed for your user account or a project (add --all to clean every scope at once). Only Kavach hooks are removed; any MCP servers, modes, plugins, or hooks you installed later stay intact.',
    cmd: 'kavach uninstall',
  },
  {
    step: '02',
    title: 'Optional: remove Kavach’s own ~/.kavach state folder',
    detail:
      'Unhooks Claude Code and clears Kavach’s local policy YAML, hash salt, backups, and JSONL logs. Never touches Claude Code, Ollama, or other developer tools.',
    cmd: 'kavach uninstall --purge',
  },
  {
    step: '03',
    title: 'Optional: remove the kavach binary itself',
    detail:
      'Uninstall the standalone CLI executable via Homebrew, or delete it if you installed the release binary manually.',
    cmd: 'brew uninstall kavach',
  },
];

const HONEST_BOUNDARIES = [
  {
    title: 'Cannot stop an already-stolen token',
    detail:
      'If an attacker already holds a valid API key or session cookie off your machine, revoke and rotate it.',
  },
  {
    title: 'Injection detection is probabilistic',
    detail:
      'Heuristics and optional local Ollama models sharply reduce indirect prompt-injection risk, but no detector guarantees 100% recall against novel phrasing.',
  },
  {
    title: 'Phase 1 protects Claude Code inline',
    detail:
      'Tools without Claude Code hooks still benefit from `kavach audit` and `kavach scan`, while local HTTP proxy and browser coverage arrive in Phases 2–3.',
  },
];

export function CommandReference() {
  return (
    <section id="commands" className="py-20 sm:py-28 px-6 bg-[#F5F5F7]">
      <div className="max-w-[1080px] mx-auto space-y-20">
        {/* Everyday Commands */}
        <div className="space-y-6">
          <div className="max-w-2xl space-y-2">
            <p className="text-xs font-semibold uppercase tracking-widest text-[#0071E3]">
              Reference
            </p>
            <h2 className="text-2xl sm:text-3xl font-semibold tracking-[-0.025em] text-[#1D1D1F]">
              Six commands you will actually use.
            </h2>
          </div>

          <div className="rounded-3xl bg-white border border-black/[0.06] divide-y divide-black/[0.06] overflow-hidden">
            {CORE_COMMANDS.map((item) => (
              <div
                key={item.cmd}
                className="p-5 sm:px-6 flex flex-col md:flex-row md:items-center justify-between gap-4"
              >
                <div className="space-y-1 min-w-0">
                  <div className="flex flex-wrap items-center gap-3">
                    <code className="font-mono text-xs sm:text-sm font-medium text-[#1D1D1F]">
                      {item.cmd}
                    </code>
                    <span className="text-xs font-medium text-[#0071E3]">{item.purpose}</span>
                  </div>
                  <p className="text-sm text-[#6E6E73]">{item.desc}</p>
                </div>
                <CopyCommandButton text={item.cmd} className="self-start md:self-center" />
              </div>
            ))}
          </div>
        </div>

        {/* Clean Uninstall & Preservation Guarantee */}
        <div id="uninstall" className="scroll-mt-20 space-y-8">
          <div className="max-w-2xl space-y-3">
            <p className="text-xs font-semibold uppercase tracking-widest text-[#0071E3]">
              Clean uninstall
            </p>
            <h2 className="text-2xl sm:text-3xl font-semibold tracking-[-0.025em] text-[#1D1D1F]">
              Undo anytime without breaking your modes or apps.
            </h2>
            <p className="text-base text-[#6E6E73] leading-relaxed">
              Uninstalling never wipes out changes you made later. Kavach inspects your{' '}
              <code className="font-mono text-xs text-[#1D1D1F]">settings.json</code> first and picks
              the safest way to remove itself.
            </p>
          </div>

          {/* Two clear behaviors explained side-by-side */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="rounded-2xl bg-white p-6 border border-black/[0.06] space-y-2.5">
              <div className="inline-flex items-center gap-2 text-xs font-semibold text-[#1D1D1F]">
                <ShieldCheck className="w-4 h-4 text-[#0071E3]" aria-hidden="true" />
                <span>If you installed other modes or apps later</span>
              </div>
              <p className="text-sm text-[#6E6E73] leading-relaxed">
                Kavach automatically performs a <strong className="font-semibold text-[#1D1D1F]">surgical merge</strong>—removing
                only its own hook entries while keeping every MCP server, permission mode, theme, plugin, and custom hook you added afterward.
              </p>
            </div>

            <div className="rounded-2xl bg-white p-6 border border-black/[0.06] space-y-2.5">
              <div className="inline-flex items-center gap-2 text-xs font-semibold text-[#1D1D1F]">
                <RotateCcw className="w-4 h-4 text-emerald-600" aria-hidden="true" />
                <span>If settings stayed unchanged since install</span>
              </div>
              <p className="text-sm text-[#6E6E73] leading-relaxed">
                Kavach restores your original pre-install <code className="font-mono text-xs text-[#1D1D1F]">settings.json</code>{' '}
                snapshot byte-for-byte (or removes the file cleanly if none existed before). Add{' '}
                <code className="font-mono text-xs text-[#1D1D1F]">--restore-backup</code> anytime to force snapshot restore.
              </p>
            </div>
          </div>

          {/* 3-Step Undo Commands + Terminal Preview */}
          <div className="rounded-3xl bg-white border border-black/[0.06] p-6 sm:p-8 grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
            <div className="lg:col-span-7 divide-y divide-black/[0.06]">
              {UNINSTALL_STEPS.map((item) => (
                <div key={item.step} className="py-5 first:pt-0 last:pb-0 space-y-3">
                  <div className="flex items-start justify-between gap-4">
                    <div className="space-y-1">
                      <span className="font-mono text-xs font-medium text-[#0071E3]">
                        STEP {item.step}
                      </span>
                      <h3 className="text-sm sm:text-base font-semibold text-[#1D1D1F]">
                        {item.title}
                      </h3>
                      <p className="text-xs sm:text-sm text-[#6E6E73] leading-relaxed">
                        {item.detail}
                      </p>
                    </div>
                  </div>

                  <div className="rounded-xl bg-[#F5F5F7] px-3.5 py-2.5 flex items-center justify-between gap-3 border border-black/[0.04]">
                    <code className="font-mono text-xs text-[#1D1D1F] truncate">{item.cmd}</code>
                    <CopyCommandButton text={item.cmd} />
                  </div>
                </div>
              ))}
            </div>

            <div className="lg:col-span-5 rounded-2xl bg-[#1D1D1F] text-[#F5F5F7] overflow-hidden border border-black/10">
              <div className="px-4 py-3 bg-white/[0.04] border-b border-white/[0.08] flex items-center justify-between">
                <span className="text-[11px] font-mono text-white/75">Expected uninstall output</span>
                <CheckCircle2 className="w-3.5 h-3.5 text-[#30D158]" aria-hidden="true" />
              </div>
              <pre className="p-5 font-mono text-xs leading-relaxed text-white/90 overflow-x-auto whitespace-pre-wrap">
                <code>{`$ kavach uninstall
Removed 4 Kavach hook(s) cleanly while preserving your other apps, modes & settings: ~/.claude/settings.json
  Pre-Kavach snapshot kept at: ~/.kavach/backups/9c41f2.settings.json.bak
Local config & logs kept in ~/.kavach (pass --purge to also remove them, or remove binary with brew/rm).`}</code>
              </pre>
            </div>
          </div>
        </div>

        {/* Honest Security Boundaries */}
        <div className="space-y-6">
          <div className="max-w-2xl space-y-2">
            <h3 className="text-xl font-semibold tracking-tight text-[#1D1D1F]">
              What Kavach is honest about
            </h3>
            <p className="text-sm text-[#6E6E73]">
              Clear limits matter more than marketing claims when trusting a local security tool.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {HONEST_BOUNDARIES.map((item) => (
              <div
                key={item.title}
                className="rounded-2xl bg-white p-6 border border-black/[0.06] space-y-2"
              >
                <h4 className="text-sm font-semibold text-[#1D1D1F]">{item.title}</h4>
                <p className="text-sm text-[#6E6E73] leading-relaxed">{item.detail}</p>
              </div>
            ))}
          </div>
        </div>

        {/* Quiet Footer */}
        <footer className="pt-8 border-t border-black/[0.08] flex flex-col sm:flex-row sm:items-center justify-between gap-4 text-xs text-[#6E6E73]">
          <div className="flex items-center gap-2 text-[#1D1D1F] font-medium">
            <Shield className="w-4 h-4 text-[#0071E3]" aria-hidden="true" />
            <span>Kavach · Local Security Guard for AI Agent Sessions</span>
          </div>
          <p>L0 + L1 embedded locally · Optional L2 on 127.0.0.1 only · Zero telemetry</p>
        </footer>
      </div>
    </section>
  );
}
