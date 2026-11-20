import {
  ArrowRight,
  CheckCircle2,
  FileCheck2,
  GitBranch,
  Link2,
  Lock,
  Map,
  ShieldCheck,
  UploadCloud,
  Users,
} from 'lucide-react';
import type { UserRole } from '../types/domain.ts';
import {
  AnthropicLogo,
  AzureLogo,
  EngineerJourneyBanner,
  GoogleCloudLogo,
  HeroWorkflowIllustration,
  ManualMappingLogo,
  MicrosoftProjectMark,
  OllamaLogo,
  OpenAiLogo,
  StakeholderJourneyBanner,
  TerraformLogo,
  VertexAiLogo,
  VisualStepTile,
  YamlLogo,
} from './BrandVisuals.tsx';

interface OnboardingViewProps {
  role: UserRole;
  isInviteSession: boolean;
  pocCount: number;
  onNavigate: (tab: 'pocs' | 'architecture' | 'scorecard' | 'whatif' | 'signoff' | 'console') => void;
  onStartAsEngineer: () => void;
  onOpenEngineerConsole: () => void;
  onStartAsStakeholder: () => void;
}

export function OnboardingView({
  role,
  isInviteSession,
  pocCount,
  onNavigate,
  onStartAsEngineer,
  onOpenEngineerConsole,
  onStartAsStakeholder,
}: OnboardingViewProps) {
  return (
    <section aria-labelledby="onboarding-heading" className="space-y-6">
      {/* Hero Split: Concise Motive + Visual Pipeline Diagram + Ecosystem Logos */}
      <div className="ms-card p-6 sm:p-8">
        <div className="grid grid-cols-1 items-stretch gap-6 lg:grid-cols-12">
          <div className="flex flex-col justify-between space-y-5 lg:col-span-6">
            <div className="space-y-3">
              <div className="flex items-center gap-2.5 text-xs font-semibold text-[#0E6B38]">
                <MicrosoftProjectMark className="h-5 w-5" />
                <span>Prod Preview · Stakeholder GCP Review</span>
              </div>
              <h1
                id="onboarding-heading"
                className="text-2xl font-bold tracking-tight text-[#242424] sm:text-4xl"
                style={{ textWrap: 'balance' }}
              >
                Cloud prototypes, translated for executive sign-off.
              </h1>
              <p className="text-sm leading-relaxed text-[#605E5C] sm:text-base">
                Replace raw cloud consoles with plain-language architecture maps, live requirement
                scorecards, 10× what-if scaling, and steering PDFs.
              </p>
            </div>

            <div className="space-y-4">
              <div className="flex flex-wrap items-center gap-3">
                <button
                  type="button"
                  onClick={() => onNavigate(isInviteSession ? 'scorecard' : 'pocs')}
                  className="inline-flex min-h-[40px] items-center gap-2 rounded bg-[#107C41] px-5 py-2 text-sm font-semibold text-white transition-colors hover:bg-[#0C6233] whitespace-nowrap shrink-0"
                >
                  <span>
                    {isInviteSession
                      ? 'Open Invited Scorecard'
                      : `Browse Active POCs (${pocCount})`}
                  </span>
                  <ArrowRight className="h-4 w-4" aria-hidden="true" />
                </button>

                {role === 'engineer' && !isInviteSession && (
                  <button
                    type="button"
                    onClick={onStartAsEngineer}
                    className="inline-flex min-h-[40px] items-center gap-2 rounded border border-[#8A8886] bg-white px-4 py-2 text-sm font-medium text-[#242424] transition-colors hover:bg-[#F3F2F1] whitespace-nowrap shrink-0"
                  >
                    <TerraformLogo className="h-4 w-4" />
                    <span>Upload POC (Engineer)</span>
                  </button>
                )}
              </div>

              {/* Supported Stack & AI Ecosystem Logo Strip */}
              <div className="border-t border-[#EDEBE9] pt-3">
                <div className="mb-2 text-[11px] font-semibold text-[#605E5C]">
                  Works with your cloud &amp; optional AI stack
                </div>
                <div className="flex flex-wrap items-center gap-4 text-xs font-medium text-[#323130]">
                  <span className="inline-flex items-center gap-1.5">
                    <GoogleCloudLogo className="h-4 w-4" />
                    <span>Google Cloud</span>
                  </span>
                  <span className="inline-flex items-center gap-1.5">
                    <TerraformLogo className="h-4 w-4" />
                    <span>Terraform</span>
                  </span>
                  <span className="inline-flex items-center gap-1.5">
                    <VertexAiLogo className="h-4 w-4" />
                    <span>Vertex AI</span>
                  </span>
                  <span className="inline-flex items-center gap-1.5">
                    <AzureLogo className="h-4 w-4" />
                    <span>Azure OpenAI</span>
                  </span>
                  <span className="inline-flex items-center gap-1.5">
                    <AnthropicLogo className="h-4 w-4" />
                    <span>Anthropic</span>
                  </span>
                  <span className="inline-flex items-center gap-1.5">
                    <OpenAiLogo className="h-4 w-4" />
                    <span>OpenAI</span>
                  </span>
                  <span className="inline-flex items-center gap-1.5">
                    <OllamaLogo className="h-4 w-4" />
                    <span>Local / Manual</span>
                  </span>
                </div>
              </div>
            </div>
          </div>

          <div className="lg:col-span-6">
            <HeroWorkflowIllustration />
          </div>
        </div>
      </div>

      {/* Role Visual Playbooks: Stakeholder vs Engineer */}
      <div className="grid grid-cols-1 gap-5 lg:grid-cols-2">
        {/* Stakeholder Visual Guide */}
        <article className="ms-card flex flex-col justify-between overflow-hidden">
          <div>
            <div className="flex items-center justify-between border-b border-[#EDEBE9] bg-[#F3F2F1] px-5 py-3">
              <div>
                <h2 className="text-base font-semibold text-[#242424]">
                  Stakeholders &amp; Steering Reviewers
                </h2>
                <p className="text-xs text-[#605E5C]">Product, Operations, Compliance, InfoSec</p>
              </div>
              <Users className="h-5 w-5 text-[#107C41] shrink-0" aria-hidden="true" />
            </div>

            <div className="p-5 space-y-4">
              <StakeholderJourneyBanner />

              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                <VisualStepTile
                  icon={<MicrosoftProjectMark className="h-5 w-5" />}
                  title="01. Open POC or Invite"
                  caption="Check pass % and teardown date."
                />
                <VisualStepTile
                  icon={<Map className="h-5 w-5 text-[#107C41]" aria-hidden="true" />}
                  title="02. Architecture Map"
                  caption="Click boxes for region & role."
                />
                <VisualStepTile
                  icon={<CheckCircle2 className="h-5 w-5 text-[#107C10]" aria-hidden="true" />}
                  title="03. Live Scorecard"
                  caption="Measured proof vs Out-of-Scope."
                />
                <VisualStepTile
                  icon={<FileCheck2 className="h-5 w-5 text-[#0F6CBD]" aria-hidden="true" />}
                  title="04. What-If & PDF"
                  caption="Test 10× scale, sign off & export."
                />
              </div>
            </div>
          </div>

          {!isInviteSession && (
            <div className="border-t border-[#EDEBE9] bg-[#FAF9F8] px-5 py-3">
              <button
                type="button"
                onClick={onStartAsStakeholder}
                className="inline-flex min-h-[36px] items-center gap-2 rounded border border-[#8A8886] bg-white px-4 py-1.5 text-xs font-semibold text-[#242424] hover:bg-[#F3F2F1]"
              >
                <span>
                  {role === 'stakeholder'
                    ? 'Open Stakeholder Scorecard'
                    : 'Preview as Stakeholder'}
                </span>
                <ArrowRight className="h-3.5 w-3.5 text-[#107C41]" aria-hidden="true" />
              </button>
            </div>
          )}
        </article>

        {/* Engineer Visual Guide */}
        <article className="ms-card flex flex-col justify-between overflow-hidden">
          <div>
            <div className="flex items-center justify-between border-b border-[#EDEBE9] bg-[#F3F2F1] px-5 py-3">
              <div>
                <h2 className="text-base font-semibold text-[#242424]">
                  Cloud &amp; Platform Engineers
                </h2>
                <p className="text-xs text-[#605E5C]">Tech Leads, SREs, Platform Architects</p>
              </div>
              <GoogleCloudLogo className="h-5 w-5 shrink-0" />
            </div>

            <div className="p-5 space-y-4">
              <EngineerJourneyBanner />

              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                <VisualStepTile
                  icon={<UploadCloud className="h-5 w-5 text-[#5C4EE5]" aria-hidden="true" />}
                  title="01. Upload .tfstate"
                  caption="Auto-build map & YAML checks."
                />
                <VisualStepTile
                  icon={<GitBranch className="h-5 w-5 text-[#0F6CBD]" aria-hidden="true" />}
                  title="02. AI or Manual Map"
                  caption="Compare LLMs or choose None."
                />
                <VisualStepTile
                  icon={<Lock className="h-5 w-5 text-[#A45B00]" aria-hidden="true" />}
                  title="03. Approval Gate"
                  caption="Drafts stay hidden until verified."
                />
                <VisualStepTile
                  icon={<Link2 className="h-5 w-5 text-[#107C41]" aria-hidden="true" />}
                  title="04. Expiring Invite"
                  caption="Share 24h / 7d single-POC links."
                />
              </div>
            </div>
          </div>

          {role === 'engineer' && !isInviteSession && (
            <div className="border-t border-[#EDEBE9] bg-[#FAF9F8] px-5 py-3">
              <button
                type="button"
                onClick={onOpenEngineerConsole}
                className="inline-flex min-h-[36px] items-center gap-2 rounded border border-[#8A8886] bg-white px-4 py-1.5 text-xs font-semibold text-[#242424] hover:bg-[#F3F2F1]"
              >
                <span>Open Engineer Console</span>
                <ArrowRight className="h-3.5 w-3.5 text-[#107C41]" aria-hidden="true" />
              </button>
            </div>
          )}
        </article>
      </div>

      {/* Microsoft Project Gantt-Style 7-Day Review Timeline */}
      <div className="ms-card overflow-hidden">
        <div className="flex items-center justify-between border-b border-[#EDEBE9] bg-[#F3F2F1] px-5 py-3">
          <div>
            <h2 className="text-sm font-semibold text-[#242424]">
              7-Day POC Review Timeline (Best Practice)
            </h2>
          </div>
          <span className="text-xs font-mono text-[#605E5C] tabular-nums">Days 1 → 7</span>
        </div>

        <div className="divide-y divide-[#EDEBE9]">
          <div className="grid grid-cols-1 items-center gap-3 px-5 py-3.5 md:grid-cols-12">
            <div className="flex items-center gap-2.5 md:col-span-3">
              <TerraformLogo className="h-5 w-5 shrink-0" />
              <div>
                <div className="text-xs font-semibold text-[#0E6B38]">Day 1 · Kickoff</div>
                <div className="text-[11px] text-[#605E5C]">Scope &amp; Budget Cap</div>
              </div>
            </div>
            <div className="md:col-span-5">
              <div className="h-5 w-full rounded-xs bg-[#F3F2F1] p-0.5">
                <div className="flex h-full w-1/3 items-center rounded-xs bg-[#107C41] px-2 text-[10px] font-semibold text-white">
                  Provision &amp; Map
                </div>
              </div>
            </div>
            <div className="text-xs text-[#323130] md:col-span-4">
              Upload <code className="font-mono">.tfstate</code> + lock <em>In/Out of Scope</em>
            </div>
          </div>

          <div className="grid grid-cols-1 items-center gap-3 px-5 py-3.5 md:grid-cols-12">
            <div className="flex items-center gap-2.5 md:col-span-3">
              <GoogleCloudLogo className="h-5 w-5 shrink-0" />
              <div>
                <div className="text-xs font-semibold text-[#0F6CBD]">Days 2–5 · Live Check</div>
                <div className="text-[11px] text-[#605E5C]">Async Review</div>
              </div>
            </div>
            <div className="md:col-span-5">
              <div className="h-5 w-full rounded-xs bg-[#F3F2F1] p-0.5">
                <div className="ml-[28%] flex h-full w-1/2 items-center rounded-xs bg-[#0F6CBD] px-2 text-[10px] font-semibold text-white">
                  Telemetry &amp; What-If
                </div>
              </div>
            </div>
            <div className="text-xs text-[#323130] md:col-span-4">
              Fix IAM/latency alerts &amp; test 10× load via invite link
            </div>
          </div>

          <div className="grid grid-cols-1 items-center gap-3 px-5 py-3.5 md:grid-cols-12">
            <div className="flex items-center gap-2.5 md:col-span-3">
              <YamlLogo className="h-5 w-5 shrink-0" />
              <div>
                <div className="text-xs font-semibold text-[#0E6B38]">Day 7 · Decision</div>
                <div className="text-[11px] text-[#605E5C]">Steering Sign-Off</div>
              </div>
            </div>
            <div className="md:col-span-5">
              <div className="flex h-5 w-full items-center justify-end rounded-xs bg-[#F3F2F1] px-2">
                <div className="flex items-center gap-1.5">
                  <span className="text-[10px] font-semibold text-[#0E6B38]">
                    PDF Export &amp; Auto-Teardown
                  </span>
                  <span className="inline-block h-3 w-3 rotate-45 bg-[#107C41]" aria-hidden="true" />
                </div>
              </div>
            </div>
            <div className="text-xs text-[#323130] md:col-span-4">
              Approve deliverables &amp; export Steering Committee PDF
            </div>
          </div>
        </div>
      </div>

      {/* Visual Core Guarantees Strip */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div className="ms-card flex items-start gap-3.5 p-5">
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded border border-[#E1DFDD] bg-[#EFF6F1]">
            <CheckCircle2 className="h-5 w-5 text-[#107C10]" aria-hidden="true" />
          </div>
          <div>
            <div className="text-sm font-semibold text-[#242424]">Measured vs. Projected</div>
            <p className="mt-1 text-xs text-[#605E5C]">
              Real monitoring metrics vs. billing &amp; scale forecasts.
            </p>
          </div>
        </div>

        <div className="ms-card flex items-start gap-3.5 p-5">
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded border border-[#E1DFDD] bg-[#FAF9F8]">
            <div className="flex items-center -space-x-1">
              <VertexAiLogo className="h-4 w-4" />
              <ManualMappingLogo className="h-4 w-4" />
            </div>
          </div>
          <div>
            <div className="text-sm font-semibold text-[#242424]">Pluggable &amp; Optional AI</div>
            <p className="mt-1 text-xs text-[#605E5C]">
              Switch providers per POC, enforce EU-only, or disable AI.
            </p>
          </div>
        </div>

        <div className="ms-card flex items-start gap-3.5 p-5">
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded border border-[#E1DFDD] bg-[#EFF6FF]">
            <ShieldCheck className="h-5 w-5 text-[#0F6CBD]" aria-hidden="true" />
          </div>
          <div>
            <div className="text-sm font-semibold text-[#242424]">Zero Key Exposure</div>
            <p className="mt-1 text-xs text-[#605E5C]">
              Server-side secrets and single-POC expiring invite links.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}
