import { useState } from 'react';
import { motion } from 'motion/react';
import { Check, CheckCircle2, RotateCcw, Terminal } from 'lucide-react';
import { CopyCommandButton } from './CopyCommandButton';

type InstallMethod = 'homebrew' | 'checksum' | 'source';

interface OnboardingStep {
  number: string;
  title: string;
  shortTitle: string;
  summary: string;
  reassurance: string;
  command: string;
  expectedLabel: string;
  expectedOutput: string;
}

const INSTALL_METHODS: Record<InstallMethod, { label: string; command: string; note: string }> = {
  homebrew: {
    label: 'Homebrew (Mac & Linux)',
    command: 'brew install kavach-sec/tap/kavach',
    note: 'Recommended for most Apple Silicon Mac users. Installs a single standalone binary with zero background services.',
  },
  checksum: {
    label: 'Verified Release Binary',
    command: `shasum -a 256 -c kavach-darwin-arm64.sha256\nchmod +x kavach-darwin-arm64 && sudo mv kavach-darwin-arm64 /usr/local/bin/kavach`,
    note: 'Download the release binary and .sha256 file first—never pipe curl directly into sh.',
  },
  source: {
    label: 'Build from Source (Go 1.24+)',
    command: `make build\nsudo cp bin/kavach /usr/local/bin/kavach`,
    note: 'Compiles the static binary directly from the repository with embedded L0 rules and L1 heuristics.',
  },
};

const STEPS: OnboardingStep[] = [
  {
    number: '01',
    title: 'Install the local Kavach binary',
    shortTitle: 'Install Kavach',
    summary:
      'Kavach runs as a single local command on macOS (Apple Silicon) or Linux. You do not need an account, API key, or running server.',
    reassurance: 'Requirement: Claude Code CLI (`claude`) installed if you plan to guard live sessions.',
    command: 'brew install kavach-sec/tap/kavach',
    expectedLabel: 'Verify installation',
    expectedOutput: `$ kavach version
kavach 0.1.0 (darwin/arm64) · L0+L1 embedded · local-only`,
  },
  {
    number: '02',
    title: 'Connect Kavach to Claude Code',
    shortTitle: 'Connect Claude Code',
    summary:
      'This wires Kavach into Claude Code’s four lifecycle hooks so prompts, tool calls, and tool outputs are checked automatically before Claude sees them.',
    reassurance:
      'Safe to undo anytime: Kavach saves a byte-for-byte backup first, and if you install new modes, MCP servers, or other hooks later, `kavach uninstall` removes only Kavach hooks without touching them.',
    command: 'kavach install --claude-code --user',
    expectedLabel: 'What your terminal will print',
    expectedOutput: `Kavach hooks installed (user scope)
  Settings : ~/.claude/settings.json
  Backup   : ~/.kavach/backups/9c41f2.settings.json.bak
  Policy   : ~/.kavach/policy.yaml
  Manifest : ~/.kavach/install_manifest.json (sha256:…)
Next: run \`kavach doctor\` and \`kavach selftest\`.`,
  },
  {
    number: '03',
    title: 'Confirm everything is healthy & accurate',
    shortTitle: 'Verify Safety',
    summary:
      'Run `doctor` to confirm your hook files have not been tampered with, then run `selftest` to test 75 safe fake attacks locally without touching the cloud.',
    reassurance:
      'If every category shows PASS and 0.0% false positives, you are protected—just open Claude Code normally.',
    command: 'kavach doctor && kavach selftest',
    expectedLabel: 'Expected verification output',
    expectedOutput: `Kavach Doctor (0.1.0, darwin/arm64)
  [ok] Kavach home   : ~/.kavach
  [ok] Policy YAML   : ~/.kavach/policy.yaml
  [ok] L0 rules      : 22 rules loaded
  [ok] Hook integrity: installed & verified (SHA-256 match)

Kavach Self-Test (75 labelled hook fixtures, 0 network calls)
  secrets             12/12   100.0%   p95: 0.34 ms
  pii                  8/8    100.0%   p95: 0.18 ms
  direct_injection     8/8    100.0%   p95: 0.22 ms
  indirect_injection  10/10   100.0%   p95: 0.31 ms
  unicode              6/6    100.0%   p95: 0.10 ms
  risky_command       10/10   100.0%   p95: 0.14 ms
  benign              21/21   100.0%   0 false positives
RESULT: PASS`,
  },
];

export function GettingStartedStepper() {
  const [activeStepIndex, setActiveStepIndex] = useState(0);
  const [installMethod, setInstallMethod] = useState<InstallMethod>('homebrew');

  const step = STEPS[activeStepIndex];
  const commandToDisplay =
    activeStepIndex === 0 ? INSTALL_METHODS[installMethod].command : step.command;

  return (
    <section id="start-here" className="py-20 sm:py-28 px-6 bg-[#F5F5F7]">
      <div className="max-w-[1080px] mx-auto space-y-12">
        <div className="max-w-2xl space-y-3">
          <p className="text-xs font-semibold uppercase tracking-widest text-[#0071E3]">
            Where to start
          </p>
          <h2 className="text-3xl sm:text-4xl font-semibold tracking-[-0.025em] text-[#1D1D1F]">
            Up and running in three terminal commands.
          </h2>
          <p className="text-base sm:text-lg text-[#6E6E73] leading-relaxed">
            No sign-ups, no cloud dashboard, and no config files to write by hand. Follow these three
            steps once, then use Claude Code as you normally do.
          </p>
        </div>

        {/* Step selector rail */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
          {STEPS.map((item, idx) => {
            const isSelected = idx === activeStepIndex;
            const isCompleted = idx < activeStepIndex;
            return (
              <button
                key={item.number}
                type="button"
                onClick={() => setActiveStepIndex(idx)}
                className={`text-left rounded-2xl p-5 transition-all cursor-pointer border ${
                  isSelected
                    ? 'bg-white border-black/[0.08] shadow-xs'
                    : 'bg-white/60 hover:bg-white border-transparent'
                }`}
              >
                <div className="flex items-center justify-between">
                  <span
                    className={`font-mono text-xs font-medium tabular-nums ${
                      isSelected ? 'text-[#0071E3]' : 'text-[#6E6E73]'
                    }`}
                  >
                    Step {item.number}
                  </span>
                  {isCompleted && (
                    <span className="inline-flex items-center gap-1 text-xs font-medium text-emerald-700">
                      <Check className="w-3.5 h-3.5" aria-hidden="true" />
                      Done
                    </span>
                  )}
                </div>
                <p className="mt-2 text-base font-semibold text-[#1D1D1F]">{item.shortTitle}</p>
                <p className="mt-1 text-xs text-[#6E6E73] line-clamp-2">{item.summary}</p>
              </button>
            );
          })}
        </div>

        {/* Active Step Detail Workspace */}
        <motion.div
          key={`${activeStepIndex}-${installMethod}`}
          initial={{ opacity: 0, y: 6 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.22, ease: [0.22, 1, 0.36, 1] }}
          className="rounded-3xl bg-white border border-black/[0.06] p-6 sm:p-10 grid grid-cols-1 lg:grid-cols-12 gap-8 items-start"
        >
          {/* Left column: plain-language instructions & command */}
          <div className="lg:col-span-6 space-y-6">
            <div className="space-y-2.5">
              <div className="text-xs font-mono font-medium text-[#0071E3]">
                STEP {step.number} OF 03
              </div>
              <h3 className="text-2xl font-semibold tracking-tight text-[#1D1D1F]">
                {step.title}
              </h3>
              <p className="text-sm sm:text-base text-[#6E6E73] leading-relaxed">{step.summary}</p>
            </div>

            {activeStepIndex === 0 && (
              <div className="space-y-2.5">
                <span className="block text-xs font-medium text-[#6E6E73]">
                  Choose installation method
                </span>
                <div className="inline-flex flex-wrap rounded-xl bg-[#F5F5F7] p-1 gap-1">
                  {(Object.keys(INSTALL_METHODS) as InstallMethod[]).map((methodKey) => {
                    const active = methodKey === installMethod;
                    return (
                      <button
                        key={methodKey}
                        type="button"
                        onClick={() => setInstallMethod(methodKey)}
                        className={`rounded-lg px-3 py-1.5 text-xs font-medium transition-all cursor-pointer whitespace-nowrap ${
                          active
                            ? 'bg-white text-[#1D1D1F] shadow-xs'
                            : 'text-[#6E6E73] hover:text-[#1D1D1F]'
                        }`}
                      >
                        {INSTALL_METHODS[methodKey].label}
                      </button>
                    );
                  })}
                </div>
                <p className="text-xs text-[#6E6E73] leading-relaxed">
                  {INSTALL_METHODS[installMethod].note}
                </p>
              </div>
            )}

            <div className="rounded-2xl bg-[#F5F5F7] p-4 border border-black/[0.06] space-y-3">
              <div className="flex items-center justify-between gap-2">
                <span className="inline-flex items-center gap-1.5 text-xs font-medium text-[#1D1D1F]">
                  <Terminal className="w-3.5 h-3.5 text-[#6E6E73]" aria-hidden="true" />
                  Run in your terminal
                </span>
                <CopyCommandButton text={commandToDisplay} />
              </div>
              <pre className="font-mono text-xs sm:text-[13px] text-[#1D1D1F] overflow-x-auto leading-relaxed whitespace-pre-wrap break-all">
                <code>{commandToDisplay}</code>
              </pre>
            </div>

            <div className="flex items-start gap-2.5 text-xs text-[#6E6E73] leading-relaxed pt-1">
              {activeStepIndex === 1 ? (
                <RotateCcw className="w-4 h-4 text-[#0071E3] shrink-0 mt-0.5" aria-hidden="true" />
              ) : (
                <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0 mt-0.5" aria-hidden="true" />
              )}
              <span>{step.reassurance}</span>
            </div>

            <div className="pt-2 flex items-center gap-3">
              {activeStepIndex > 0 && (
                <button
                  type="button"
                  onClick={() => setActiveStepIndex((prev) => prev - 1)}
                  className="rounded-full px-4 py-2 text-xs font-medium bg-[#F5F5F7] hover:bg-[#E8E8ED] text-[#1D1D1F] transition-colors cursor-pointer"
                >
                  Previous step
                </button>
              )}
              {activeStepIndex < STEPS.length - 1 && (
                <button
                  type="button"
                  onClick={() => setActiveStepIndex((prev) => prev + 1)}
                  className="rounded-full px-4 py-2 text-xs font-medium bg-[#1D1D1F] hover:bg-black text-white transition-colors cursor-pointer"
                >
                  Next: {STEPS[activeStepIndex + 1].shortTitle}
                </button>
              )}
            </div>
          </div>

          {/* Right column: realistic Mac terminal output window */}
          <div className="lg:col-span-6 rounded-2xl bg-[#1D1D1F] text-[#F5F5F7] overflow-hidden border border-black/10">
            <div className="flex items-center justify-between px-4 py-3 bg-white/[0.04] border-b border-white/[0.08]">
              <div className="flex items-center gap-2" aria-hidden="true">
                <span className="w-2.5 h-2.5 rounded-full bg-white/20" />
                <span className="w-2.5 h-2.5 rounded-full bg-white/20" />
                <span className="w-2.5 h-2.5 rounded-full bg-white/20" />
              </div>
              <span className="text-[11px] font-mono text-white/60">{step.expectedLabel}</span>
              <span className="w-10" aria-hidden="true" />
            </div>
            <pre className="p-5 font-mono text-xs leading-relaxed text-white/90 overflow-x-auto whitespace-pre">
              <code>{step.expectedOutput}</code>
            </pre>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
