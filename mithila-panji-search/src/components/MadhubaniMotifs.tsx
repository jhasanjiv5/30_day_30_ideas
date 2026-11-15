import React from 'react';

/**
 * Surya Sun Emblem Logo inspired directly by the concentric Surya sun-disc
 * and fine kachni linework in the Madhubani reference painting.
 */
export function MithilaSuryaLogo({ className = 'w-10 h-10' }: { className?: string }) {
  const rays = Array.from({ length: 16 }, (_, i) => i * 22.5);

  return (
    <svg viewBox="0 0 64 64" fill="none" aria-hidden="true" className={className}>
      {/* Fine radiating kachni sunbeams */}
      {rays.map((angle) => {
        const rad = (angle * Math.PI) / 180;
        const r1 = 23.5;
        const r2 = angle % 45 === 0 ? 30 : 27.5;
        const x1 = 32 + Math.cos(rad) * r1;
        const y1 = 32 + Math.sin(rad) * r1;
        const x2 = 32 + Math.cos(rad) * r2;
        const y2 = 32 + Math.sin(rad) * r2;
        return (
          <line
            key={angle}
            x1={x1}
            y1={y1}
            x2={x2}
            y2={y2}
            stroke={angle % 45 === 0 ? '#C42426' : '#171514'}
            strokeWidth={angle % 45 === 0 ? '1.25' : '0.9'}
            strokeOpacity={angle % 45 === 0 ? '0.85' : '0.55'}
            strokeLinecap="round"
          />
        );
      })}

      {/* Outer crimson kachni ring */}
      <circle cx="32" cy="32" r="22" stroke="#C42426" strokeWidth="1.6" fill="#FFFFFF" />
      {/* Inner charcoal double-line ring */}
      <circle cx="32" cy="32" r="19" stroke="#171514" strokeWidth="1.1" fill="#FDF3F2" />

      {/* 8-petal scalloped lotus ring inside sun disc */}
      {[0, 45, 90, 135, 180, 225, 270, 315].map((angle) => (
        <path
          key={angle}
          d="M32 15C34.5 21 34.5 26 32 32C29.5 26 29.5 21 32 15Z"
          transform={`rotate(${angle} 32 32)`}
          fill="#F6D5D3"
          fillOpacity="0.65"
          stroke="#171514"
          strokeWidth="0.85"
        />
      ))}

      {/* Central inner circle with sindoor tilak bindu */}
      <circle cx="32" cy="32" r="7" fill="#FFFFFF" stroke="#C42426" strokeWidth="1.35" />
      <path
        d="M32 27.2C33.4 29.4 33.4 31.6 32 33.4C30.6 31.6 30.6 29.4 32 27.2Z"
        fill="#C42426"
      />
      <circle cx="32" cy="35.3" r="1.3" fill="#171514" />
    </svg>
  );
}

/**
 * Repeating Madhubani crimson hourglass & vertical kachni hatch border strip
 * echoing the outer frame of the reference painting.
 */
export function MadhubaniBorderStrip({ className = '' }: { className?: string }) {
  const patternId = React.useId();
  return (
    <svg
      viewBox="0 0 600 12"
      preserveAspectRatio="none"
      aria-hidden="true"
      className={`w-full h-3 block ${className}`}
    >
      <defs>
        <pattern id={patternId} width="24" height="12" patternUnits="userSpaceOnUse">
          <rect width="24" height="12" fill="#FDF3F2" />
          {/* Top and bottom crimson border hairlines */}
          <line x1="0" y1="0.75" x2="24" y2="0.75" stroke="#C42426" strokeWidth="1.4" />
          <line x1="0" y1="11.25" x2="24" y2="11.25" stroke="#171514" strokeWidth="1" strokeOpacity="0.65" />
          {/* Vertical kachni hatch divider */}
          <line x1="3" y1="1.5" x2="3" y2="10.5" stroke="#171514" strokeWidth="0.75" strokeOpacity="0.55" />
          <line x1="6" y1="1.5" x2="6" y2="10.5" stroke="#171514" strokeWidth="0.75" strokeOpacity="0.55" />
          {/* Crimson hourglass/damaru motif */}
          <polygon
            points="9,2.2 21,2.2 15,6 21,9.8 9,9.8 15,6"
            fill="#C42426"
            fillOpacity="0.88"
            stroke="#171514"
            strokeWidth="0.65"
          />
        </pattern>
      </defs>
      <rect width="600" height="12" fill={`url(#${patternId})`} />
    </svg>
  );
}

export function MadhubaniCorner({
  position,
}: {
  position: 'top-left' | 'top-right' | 'bottom-left' | 'bottom-right';
}) {
  const rotation =
    position === 'top-left'
      ? ''
      : position === 'top-right'
        ? 'scale-x-[-1]'
        : position === 'bottom-left'
          ? 'scale-y-[-1]'
          : 'scale-x-[-1] scale-y-[-1]';

  const placement =
    position === 'top-left'
      ? 'top-3.5 left-3.5'
      : position === 'top-right'
        ? 'top-3.5 right-3.5'
        : position === 'bottom-left'
          ? 'bottom-3.5 left-3.5'
          : 'bottom-3.5 right-3.5';

  return (
    <svg
      viewBox="0 0 36 36"
      fill="none"
      aria-hidden="true"
      className={`pointer-events-none absolute w-7 h-7 ${placement} ${rotation}`}
    >
      {/* Double-line crimson & kajal charcoal corner bracket */}
      <path d="M2 22V2H22" stroke="#C42426" strokeWidth="1.35" strokeOpacity="0.7" />
      <path d="M6 18V6H18" stroke="#171514" strokeWidth="1" strokeOpacity="0.55" />
      <circle cx="9.5" cy="9.5" r="1.8" fill="#F6D5D3" stroke="#C42426" strokeWidth="0.9" />
    </svg>
  );
}

/**
 * Scalloped earth-ridge divider inspired by the lower scalloped mounds
 * in the reference painting.
 */
export function MadhubaniDivider({ className = '' }: { className?: string }) {
  return (
    <div className={`flex items-center gap-3 my-6 ${className}`} aria-hidden="true">
      <div className="h-px flex-1 bg-gradient-to-r from-transparent via-[#DFCECA] to-[#C42426]/40" />
      <svg viewBox="0 0 84 18" fill="none" className="w-20 h-4.5 shrink-0">
        {/* Three overlapping scalloped arches */}
        <path
          d="M12 15C12 8 22 8 22 15"
          fill="#F8E2E0"
          stroke="#171514"
          strokeWidth="1"
          strokeOpacity="0.7"
        />
        <path
          d="M62 15C62 8 72 8 72 15"
          fill="#F8E2E0"
          stroke="#171514"
          strokeWidth="1"
          strokeOpacity="0.7"
        />
        <path
          d="M32 15C32 4 52 4 52 15"
          fill="#F6D5D3"
          stroke="#C42426"
          strokeWidth="1.2"
        />
        <path
          d="M36 15C36 8 48 8 48 15"
          fill="none"
          stroke="#171514"
          strokeWidth="0.9"
          strokeOpacity="0.7"
        />
        <circle cx="42" cy="12" r="1.6" fill="#C42426" />
      </svg>
      <div className="h-px flex-1 bg-gradient-to-l from-transparent via-[#DFCECA] to-[#C42426]/40" />
    </div>
  );
}
