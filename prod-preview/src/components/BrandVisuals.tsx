import type { ReactNode } from 'react';

export function GoogleCloudLogo({ className = 'h-5 w-5' }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" className={className} aria-hidden="true" fill="none">
      <path
        d="M15.9 9.5a5 5 0 0 0-9.3-1.4A4.2 4.2 0 0 0 3 12.2 4.3 4.3 0 0 0 7.3 16.5h8.2a3.6 3.6 0 0 0 .4-7Z"
        fill="#E8F0FE"
        stroke="#1A73E8"
        strokeWidth="1.6"
        strokeLinejoin="round"
      />
      <path d="M8.5 8.1a5 5 0 0 1 7.4 1.4" stroke="#EA4335" strokeWidth="1.8" strokeLinecap="round" />
      <path d="M15.9 9.5a3.6 3.6 0 0 1 2.9 4.5" stroke="#FBBC04" strokeWidth="1.8" strokeLinecap="round" />
      <path d="M7.3 16.5h8.2" stroke="#34A853" strokeWidth="1.8" strokeLinecap="round" />
    </svg>
  );
}

export function TerraformLogo({ className = 'h-5 w-5' }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" className={className} aria-hidden="true" fill="none">
      <path d="M3 4.5 9 8v6.5L3 11V4.5Z" fill="#5C4EE5" />
      <path d="M10 8.5 16 12v6.5L10 15V8.5Z" fill="#5C4EE5" />
      <path d="M10 1.5 16 5v6L10 7.5v-6Z" fill="#7B42BC" />
      <path d="M17 12l4-2.3v6.5L17 18.5V12Z" fill="#4040B2" />
    </svg>
  );
}

export function AzureLogo({ className = 'h-5 w-5' }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" className={className} aria-hidden="true" fill="none">
      <path d="M10.8 4 5 18.5h4.2l4.1-9.6L10.8 4Z" fill="#0078D4" />
      <path d="M11.7 9.8 14.5 16H9.8l-1.5 2.5H19L13.3 6.2l-1.6 3.6Z" fill="#50E6FF" />
    </svg>
  );
}

export function VertexAiLogo({ className = 'h-5 w-5' }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" className={className} aria-hidden="true" fill="none">
      <polygon
        points="12,2.5 20.5,7.3 20.5,16.7 12,21.5 3.5,16.7 3.5,7.3"
        fill="#E8F0FE"
        stroke="#1A73E8"
        strokeWidth="1.6"
      />
      <path
        d="M12 6.5 13.6 10.4 17.5 12 13.6 13.6 12 17.5 10.4 13.6 6.5 12 10.4 10.4 12 6.5Z"
        fill="#1A73E8"
      />
    </svg>
  );
}

export function OpenAiLogo({ className = 'h-5 w-5' }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" className={className} aria-hidden="true" fill="none">
      <circle cx="12" cy="12" r="9" fill="#F3F2F1" stroke="#242424" strokeWidth="1.5" />
      <path
        d="M12 6.2v11.6M7 9.1l10 5.8M17 9.1l-10 5.8"
        stroke="#242424"
        strokeWidth="1.5"
        strokeLinecap="round"
      />
      <circle cx="12" cy="12" r="2.2" fill="#FFFFFF" stroke="#242424" strokeWidth="1.4" />
    </svg>
  );
}

export function AnthropicLogo({ className = 'h-5 w-5' }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" className={className} aria-hidden="true" fill="none">
      <rect x="3" y="3" width="18" height="18" rx="4" fill="#F4EDE4" stroke="#B45309" strokeWidth="1.4" />
      <path d="M8.2 17 11.4 7h1.8L16.4 17h-2l-.8-2.6h-3.4L9.4 17H8.2Zm2.5-4.3h2.4l-1.2-3.7-1.2 3.7Z" fill="#92400E" />
    </svg>
  );
}

export function OllamaLogo({ className = 'h-5 w-5' }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" className={className} aria-hidden="true" fill="none">
      <rect x="3.5" y="4.5" width="17" height="6" rx="1.5" fill="#EFF6F1" stroke="#107C41" strokeWidth="1.5" />
      <rect x="3.5" y="13.5" width="17" height="6" rx="1.5" fill="#EFF6F1" stroke="#107C41" strokeWidth="1.5" />
      <circle cx="7" cy="7.5" r="1" fill="#107C41" />
      <circle cx="7" cy="16.5" r="1" fill="#107C41" />
      <path d="M10.5 7.5h6.5M10.5 16.5h6.5" stroke="#107C41" strokeWidth="1.5" strokeLinecap="round" />
    </svg>
  );
}

export function ManualMappingLogo({ className = 'h-5 w-5' }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" className={className} aria-hidden="true" fill="none">
      <rect x="4" y="3.5" width="16" height="17" rx="2" fill="#F3F2F1" stroke="#605E5C" strokeWidth="1.5" />
      <path d="M8 8.5h8M8 12h8M8 15.5h5" stroke="#107C41" strokeWidth="1.7" strokeLinecap="round" />
    </svg>
  );
}

export function YamlLogo({ className = 'h-5 w-5' }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" className={className} aria-hidden="true" fill="none">
      <path
        d="M6 3.5h8.5L19 8v12.5H6V3.5Z"
        fill="#FFFFFF"
        stroke="#0F6CBD"
        strokeWidth="1.6"
        strokeLinejoin="round"
      />
      <path d="M14.5 3.5V8H19" stroke="#0F6CBD" strokeWidth="1.6" strokeLinejoin="round" />
      <path d="M8.5 11.5h7M10 14.5h5.5M10 17.5h4" stroke="#107C41" strokeWidth="1.6" strokeLinecap="round" />
    </svg>
  );
}

export function MicrosoftProjectMark({ className = 'h-6 w-6' }: { className?: string }) {
  return (
    <svg viewBox="0 0 28 28" className={className} aria-hidden="true" fill="none">
      <rect x="2" y="3" width="24" height="22" rx="3" fill="#107C41" />
      <rect x="6" y="8" width="10" height="3" rx="1" fill="#FFFFFF" />
      <rect x="9" y="13" width="13" height="3" rx="1" fill="#A7F3D0" />
      <rect x="6" y="18" width="8" height="3" rx="1" fill="#FFFFFF" />
    </svg>
  );
}

export function ProviderLogoBadge({ providerId, className = 'h-5 w-5' }: { providerId: string; className?: string }) {
  if (providerId.startsWith('vertex')) return <VertexAiLogo className={className} />;
  if (providerId === 'azure_openai') return <AzureLogo className={className} />;
  if (providerId === 'openai') return <OpenAiLogo className={className} />;
  if (providerId === 'anthropic') return <AnthropicLogo className={className} />;
  if (providerId === 'openai_compatible') return <OllamaLogo className={className} />;
  return <ManualMappingLogo className={className} />;
}

export function CloudServiceLogo({ serviceName, className = 'h-6 w-6' }: { serviceName: string; className?: string }) {
  const s = serviceName.toLowerCase();
  if (s.includes('sql') || s.includes('database') || s.includes('postgres')) {
    return (
      <svg viewBox="0 0 24 24" className={className} aria-hidden="true" fill="none">
        <ellipse cx="12" cy="6.5" rx="7" ry="2.8" fill="#E8F0FE" stroke="#0F6CBD" strokeWidth="1.6" />
        <path d="M5 6.5v11c0 1.55 3.13 2.8 7 2.8s7-1.25 7-2.8v-11" stroke="#0F6CBD" strokeWidth="1.6" />
        <path d="M5 12c0 1.55 3.13 2.8 7 2.8s7-1.25 7-2.8" stroke="#0F6CBD" strokeWidth="1.4" />
      </svg>
    );
  }
  if (s.includes('redis') || s.includes('memory') || s.includes('cache')) {
    return (
      <svg viewBox="0 0 24 24" className={className} aria-hidden="true" fill="none">
        <rect x="4" y="5" width="16" height="14" rx="2.5" fill="#FFF4E5" stroke="#A45B00" strokeWidth="1.6" />
        <path d="M8 10h8M8 14h5" stroke="#A45B00" strokeWidth="1.7" strokeLinecap="round" />
      </svg>
    );
  }
  if (s.includes('lb') || s.includes('gateway') || s.includes('load') || s.includes('armor') || s.includes('network')) {
    return (
      <svg viewBox="0 0 24 24" className={className} aria-hidden="true" fill="none">
        <path d="M12 3 19 6v5.5c0 4.5-3 7.8-7 9.5-4-1.7-7-5-7-9.5V6l7-3Z" fill="#EFF6F1" stroke="#107C41" strokeWidth="1.6" />
        <path d="m9.5 12 1.8 1.8 3.5-3.6" stroke="#107C41" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    );
  }
  if (s.includes('secret') || s.includes('kms') || s.includes('iam')) {
    return (
      <svg viewBox="0 0 24 24" className={className} aria-hidden="true" fill="none">
        <rect x="5" y="10.5" width="14" height="9.5" rx="2" fill="#F3F2F1" stroke="#605E5C" strokeWidth="1.6" />
        <path d="M8 10.5V8a4 4 0 1 1 8 0v2.5" stroke="#605E5C" strokeWidth="1.6" />
        <circle cx="12" cy="15.2" r="1.3" fill="#107C41" />
      </svg>
    );
  }
  return (
    <svg viewBox="0 0 24 24" className={className} aria-hidden="true" fill="none">
      <rect x="4" y="4.5" width="16" height="15" rx="2.5" fill="#EFF6F1" stroke="#107C41" strokeWidth="1.6" />
      <path d="m10 9 5 3-5 3V9Z" fill="#107C41" />
    </svg>
  );
}

/** Rich Hero Illustration: Cloud Infrastructure -> Verification Gate -> Executive Scorecard */
export function HeroWorkflowIllustration() {
  return (
    <div className="flex h-full flex-col justify-center rounded border border-[#E1DFDD] bg-[#FAF9F8] p-5">
      <svg
        viewBox="0 0 520 310"
        className="w-full h-auto"
        role="img"
        aria-label="Visual pipeline showing Google Cloud and Terraform inputs transforming into a verified scorecard and executive sign-off"
      >
        <defs>
          <pattern id="ms-grid" width="20" height="20" patternUnits="userSpaceOnUse">
            <path d="M 20 0 L 0 0 0 20" fill="none" stroke="#EDEBE9" strokeWidth="1" />
          </pattern>
        </defs>
        <rect width="520" height="310" rx="6" fill="#FFFFFF" stroke="#E1DFDD" />
        <rect width="520" height="310" rx="6" fill="url(#ms-grid)" opacity="0.6" />

        {/* Stage 1: Cloud & Terraform Input */}
        <g transform="translate(24, 34)">
          <rect width="136" height="242" rx="4" fill="#FFFFFF" stroke="#E1DFDD" />
          <rect width="136" height="28" rx="4" fill="#F3F2F1" />
          <text x="14" y="18" fill="#242424" fontSize="11" fontWeight="700" fontFamily="Public Sans, sans-serif">
            1. Cloud Input
          </text>

          {/* GCP box */}
          <rect x="14" y="44" width="108" height="52" rx="4" fill="#FAF9F8" stroke="#E1DFDD" />
          <circle cx="34" cy="70" r="12" fill="#E8F0FE" />
          <path d="M29 72h10a3 3 0 0 0 .4-5.9 4 4 0 0 0-7.5-1 3.3 3.3 0 0 0-2.9 6.9Z" fill="#1A73E8" />
          <text x="54" y="66" fill="#242424" fontSize="11" fontWeight="600" fontFamily="Public Sans, sans-serif">
            Google Cloud
          </text>
          <text x="54" y="81" fill="#605E5C" fontSize="9.5" fontFamily="Public Sans, sans-serif">
            Metrics &amp; IAM
          </text>

          {/* Terraform box */}
          <rect x="14" y="108" width="108" height="52" rx="4" fill="#FAF9F8" stroke="#E1DFDD" />
          <rect x="22" y="121" width="24" height="24" rx="4" fill="#EDE9FE" />
          <path d="M27 126l5 3v6l-5-3v-6Zm6 3.5l5 3v6l-5-3v-6Z" fill="#5C4EE5" />
          <text x="54" y="130" fill="#242424" fontSize="11" fontWeight="600" fontFamily="Public Sans, sans-serif">
            Terraform
          </text>
          <text x="54" y="145" fill="#605E5C" fontSize="9.5" fontFamily="Public Sans, sans-serif">
            .tfstate graph
          </text>

          {/* YAML box */}
          <rect x="14" y="172" width="108" height="52" rx="4" fill="#FAF9F8" stroke="#E1DFDD" />
          <rect x="22" y="185" width="24" height="24" rx="4" fill="#EFF6F1" />
          <path d="M28 192h12M28 197h9M28 202h6" stroke="#107C41" strokeWidth="2" strokeLinecap="round" />
          <text x="54" y="194" fill="#242424" fontSize="11" fontWeight="600" fontFamily="Public Sans, sans-serif">
            YAML Scope
          </text>
          <text x="54" y="209" fill="#605E5C" fontSize="9.5" fontFamily="Public Sans, sans-serif">
            Targets &amp; SLA
          </text>
        </g>

        {/* Flow Arrow 1 -> 2 */}
        <path d="M164 155h22" stroke="#107C41" strokeWidth="2.2" strokeLinecap="round" />
        <polygon points="184,150 193,155 184,160" fill="#107C41" />

        {/* Stage 2: Mapping & Engineer Gate */}
        <g transform="translate(196, 56)">
          <rect width="128" height="198" rx="4" fill="#FFFFFF" stroke="#107C41" strokeWidth="1.5" />
          <rect width="128" height="28" rx="4" fill="#107C41" />
          <text x="12" y="18" fill="#FFFFFF" fontSize="11" fontWeight="700" fontFamily="Public Sans, sans-serif">
            2. Verify &amp; Gate
          </text>

          {/* Provider options */}
          <text x="14" y="49" fill="#605E5C" fontSize="9.5" fontWeight="600" fontFamily="Public Sans, sans-serif">
            Optional AI or Manual
          </text>
          <g transform="translate(14, 58)">
            <rect width="30" height="28" rx="4" fill="#E8F0FE" stroke="#BFDBFE" />
            <circle cx="15" cy="14" r="5" fill="#1A73E8" />
            <rect x="35" width="30" height="28" rx="4" fill="#EFF6FF" stroke="#BAE6FD" />
            <path d="M47 20l5-12 4 12h-9Z" fill="#0078D4" />
            <rect x="70" width="30" height="28" rx="4" fill="#F3F2F1" stroke="#E1DFDD" />
            <path d="M78 14h14M85 9v10" stroke="#605E5C" strokeWidth="1.8" strokeLinecap="round" />
          </g>

          {/* Approval lock */}
          <rect x="14" y="102" width="100" height="78" rx="4" fill="#EFF6F1" stroke="#BBF7D0" />
          <circle cx="64" cy="128" r="14" fill="#107C41" />
          <path d="m58 128 4 4 8-8" stroke="#FFFFFF" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" fill="none" />
          <text x="64" y="156" textAnchor="middle" fill="#0E6B38" fontSize="10.5" fontWeight="700" fontFamily="Public Sans, sans-serif">
            Engineer Approved
          </text>
          <text x="64" y="170" textAnchor="middle" fill="#605E5C" fontSize="9" fontFamily="Public Sans, sans-serif">
            Zero Key Exposure
          </text>
        </g>

        {/* Flow Arrow 2 -> 3 */}
        <path d="M328 155h22" stroke="#107C41" strokeWidth="2.2" strokeLinecap="round" />
        <polygon points="348,150 357,155 348,160" fill="#107C41" />

        {/* Stage 3: Stakeholder Executive Scorecard */}
        <g transform="translate(360, 34)">
          <rect width="136" height="242" rx="4" fill="#FFFFFF" stroke="#E1DFDD" />
          <rect width="136" height="28" rx="4" fill="#F3F2F1" />
          <text x="14" y="18" fill="#242424" fontSize="11" fontWeight="700" fontFamily="Public Sans, sans-serif">
            3. Executive Sign-Off
          </text>

          {/* Mini bars */}
          <g transform="translate(14, 44)">
            <rect width="108" height="36" rx="4" fill="#FAF9F8" stroke="#E1DFDD" />
            <circle cx="15" cy="18" r="6" fill="#107C10" />
            <path d="m12.5 18 1.8 1.8 3.2-3.3" stroke="#fff" strokeWidth="1.5" strokeLinecap="round" fill="none" />
            <text x="27" y="16" fill="#242424" fontSize="10" fontWeight="600" fontFamily="Public Sans, sans-serif">
              Latency &amp; Uptime
            </text>
            <text x="27" y="29" fill="#107C10" fontSize="9" fontWeight="700" fontFamily="JetBrains Mono, monospace">
              MEASURED · PASS
            </text>
          </g>

          <g transform="translate(14, 90)">
            <rect width="108" height="36" rx="4" fill="#FAF9F8" stroke="#E1DFDD" />
            <circle cx="15" cy="18" r="6" fill="#0F6CBD" />
            <path d="M12 18h6M15 15v6" stroke="#fff" strokeWidth="1.5" strokeLinecap="round" />
            <text x="27" y="16" fill="#242424" fontSize="10" fontWeight="600" fontFamily="Public Sans, sans-serif">
              EU Data Region
            </text>
            <text x="27" y="29" fill="#0F6CBD" fontSize="9" fontWeight="700" fontFamily="JetBrains Mono, monospace">
              BELGIUM · VERIFIED
            </text>
          </g>

          <g transform="translate(14, 136)">
            <rect width="108" height="36" rx="4" fill="#FAF9F8" stroke="#E1DFDD" />
            <circle cx="15" cy="18" r="6" fill="#A45B00" />
            <path d="M12 20l3-4 2 2 2-3" stroke="#fff" strokeWidth="1.5" strokeLinecap="round" fill="none" />
            <text x="27" y="16" fill="#242424" fontSize="10" fontWeight="600" fontFamily="Public Sans, sans-serif">
              What-If ×10 Load
            </text>
            <text x="27" y="29" fill="#A45B00" fontSize="9" fontWeight="700" fontFamily="JetBrains Mono, monospace">
              PROJECTED · $565
            </text>
          </g>

          {/* PDF Export Pill Button inside illustration */}
          <rect x="14" y="188" width="108" height="38" rx="4" fill="#107C41" />
          <text x="68" y="211" textAnchor="middle" fill="#FFFFFF" fontSize="10.5" fontWeight="700" fontFamily="Public Sans, sans-serif">
            Steering PDF Ready
          </text>
        </g>
      </svg>
    </div>
  );
}

/** Visual 4-node storyboard banner for Stakeholders */
export function StakeholderJourneyBanner() {
  return (
    <svg
      viewBox="0 0 480 104"
      className="w-full h-auto rounded border border-[#EDEBE9] bg-[#FAF9F8]"
      role="img"
      aria-label="Stakeholder journey: Portfolio, Architecture Map, Scorecard Evidence, and Sign-Off PDF"
    >
      {/* Step 1 */}
      <g transform="translate(12, 14)">
        <rect width="98" height="76" rx="4" fill="#FFFFFF" stroke="#E1DFDD" />
        <rect x="10" y="12" width="78" height="8" rx="2" fill="#E1DFDD" />
        <rect x="10" y="26" width="54" height="6" rx="2" fill="#107C41" />
        <rect x="10" y="38" width="68" height="6" rx="2" fill="#0F6CBD" />
        <text x="49" y="64" textAnchor="middle" fill="#242424" fontSize="10" fontWeight="700" fontFamily="Public Sans, sans-serif">
          1. Pick POC
        </text>
      </g>
      <path d="M114 52h12" stroke="#107C41" strokeWidth="1.8" strokeLinecap="round" />
      <polygon points="124,48 130,52 124,56" fill="#107C41" />

      {/* Step 2 */}
      <g transform="translate(132, 14)">
        <rect width="98" height="76" rx="4" fill="#FFFFFF" stroke="#E1DFDD" />
        <rect x="12" y="18" width="26" height="18" rx="3" fill="#EFF6F1" stroke="#107C41" />
        <rect x="60" y="18" width="26" height="18" rx="3" fill="#E8F0FE" stroke="#0F6CBD" />
        <path d="M38 27h22" stroke="#605E5C" strokeWidth="1.5" />
        <text x="49" y="64" textAnchor="middle" fill="#242424" fontSize="10" fontWeight="700" fontFamily="Public Sans, sans-serif">
          2. System Map
        </text>
      </g>
      <path d="M234 52h12" stroke="#107C41" strokeWidth="1.8" strokeLinecap="round" />
      <polygon points="244,48 250,52 244,56" fill="#107C41" />

      {/* Step 3 */}
      <g transform="translate(252, 14)">
        <rect width="98" height="76" rx="4" fill="#FFFFFF" stroke="#E1DFDD" />
        <circle cx="28" cy="28" r="9" fill="#107C10" />
        <path d="m24.5 28 2.5 2.5 4.5-4.5" stroke="#fff" strokeWidth="1.8" strokeLinecap="round" fill="none" />
        <rect x="44" y="21" width="42" height="6" rx="2" fill="#242424" />
        <rect x="44" y="31" width="30" height="5" rx="2" fill="#A45B00" />
        <text x="49" y="64" textAnchor="middle" fill="#242424" fontSize="10" fontWeight="700" fontFamily="Public Sans, sans-serif">
          3. Evidence
        </text>
      </g>
      <path d="M354 52h12" stroke="#107C41" strokeWidth="1.8" strokeLinecap="round" />
      <polygon points="364,48 370,52 364,56" fill="#107C41" />

      {/* Step 4 */}
      <g transform="translate(372, 14)">
        <rect width="96" height="76" rx="4" fill="#EFF6F1" stroke="#107C41" />
        <rect x="26" y="13" width="44" height="32" rx="3" fill="#FFFFFF" stroke="#107C41" />
        <path d="M34 25h28M34 32h18" stroke="#107C41" strokeWidth="2" strokeLinecap="round" />
        <text x="48" y="64" textAnchor="middle" fill="#0E6B38" fontSize="10" fontWeight="700" fontFamily="Public Sans, sans-serif">
          4. Sign Off
        </text>
      </g>
    </svg>
  );
}

/** Visual 4-node storyboard banner for Engineers */
export function EngineerJourneyBanner() {
  return (
    <svg
      viewBox="0 0 480 104"
      className="w-full h-auto rounded border border-[#EDEBE9] bg-[#FAF9F8]"
      role="img"
      aria-label="Engineer journey: Upload Terraform, Pick LLM or Manual, Approve Queue, and Share Invite Link"
    >
      {/* Step 1 */}
      <g transform="translate(12, 14)">
        <rect width="98" height="76" rx="4" fill="#FFFFFF" stroke="#E1DFDD" />
        <path d="M30 18l8 4.5v9l-8-4.5v-9Zm10 5l8 4.5v9l-8-4.5v-9Z" fill="#5C4EE5" />
        <rect x="54" y="20" width="22" height="20" rx="2" fill="#EFF6F1" stroke="#107C41" />
        <text x="49" y="64" textAnchor="middle" fill="#242424" fontSize="10" fontWeight="700" fontFamily="Public Sans, sans-serif">
          1. Upload State
        </text>
      </g>
      <path d="M114 52h12" stroke="#107C41" strokeWidth="1.8" strokeLinecap="round" />
      <polygon points="124,48 130,52 124,56" fill="#107C41" />

      {/* Step 2 */}
      <g transform="translate(132, 14)">
        <rect width="98" height="76" rx="4" fill="#FFFFFF" stroke="#E1DFDD" />
        <circle cx="32" cy="28" r="10" fill="#E8F0FE" stroke="#1A73E8" />
        <circle cx="64" cy="28" r="10" fill="#F3F2F1" stroke="#605E5C" />
        <path d="M44 28h8" stroke="#605E5C" strokeWidth="1.5" strokeDasharray="2 2" />
        <text x="49" y="64" textAnchor="middle" fill="#242424" fontSize="10" fontWeight="700" fontFamily="Public Sans, sans-serif">
          2. AI / Manual
        </text>
      </g>
      <path d="M234 52h12" stroke="#107C41" strokeWidth="1.8" strokeLinecap="round" />
      <polygon points="244,48 250,52 244,56" fill="#107C41" />

      {/* Step 3 */}
      <g transform="translate(252, 14)">
        <rect width="98" height="76" rx="4" fill="#FFFFFF" stroke="#E1DFDD" />
        <rect x="33" y="23" width="32" height="22" rx="3" fill="#FFF9E6" stroke="#A45B00" />
        <path d="M42 23v-4a7 7 0 0 1 14 0v4" stroke="#A45B00" strokeWidth="1.8" fill="none" />
        <circle cx="49" cy="34" r="2.5" fill="#A45B00" />
        <text x="49" y="64" textAnchor="middle" fill="#242424" fontSize="10" fontWeight="700" fontFamily="Public Sans, sans-serif">
          3. Approve Gate
        </text>
      </g>
      <path d="M354 52h12" stroke="#107C41" strokeWidth="1.8" strokeLinecap="round" />
      <polygon points="364,48 370,52 364,56" fill="#107C41" />

      {/* Step 4 */}
      <g transform="translate(372, 14)">
        <rect width="96" height="76" rx="4" fill="#EFF6F1" stroke="#107C41" />
        <path d="M34 31a7 7 0 0 1 7-7h4M62 31a7 7 0 0 1-7 7h-4M40 31h16" stroke="#107C41" strokeWidth="2.2" strokeLinecap="round" fill="none" />
        <text x="48" y="64" textAnchor="middle" fill="#0E6B38" fontSize="10" fontWeight="700" fontFamily="Public Sans, sans-serif">
          4. Invite Link
        </text>
      </g>
    </svg>
  );
}

/** Helper container for compact visual step tiles */
export function VisualStepTile({
  icon,
  title,
  caption,
}: {
  icon: ReactNode;
  title: string;
  caption: string;
}) {
  return (
    <div className="flex items-start gap-3 rounded border border-[#EDEBE9] bg-[#FAF9F8] p-3">
      <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded border border-[#E1DFDD] bg-white">
        {icon}
      </div>
      <div className="min-w-0">
        <div className="text-xs font-semibold text-[#242424]">{title}</div>
        <div className="mt-0.5 text-xs text-[#605E5C]">{caption}</div>
      </div>
    </div>
  );
}
