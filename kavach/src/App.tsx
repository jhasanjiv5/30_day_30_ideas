import { Shield } from 'lucide-react';
import { HeroOnboardingFlow } from './components/HeroOnboardingFlow';
import { GettingStartedStepper } from './components/GettingStartedStepper';
import { OutcomeExplorer } from './components/OutcomeExplorer';
import { CommandReference } from './components/CommandReference';

const NAV_ITEMS = [
  { label: 'Purpose', href: '#purpose' },
  { label: 'Start Here', href: '#start-here' },
  { label: "What You'll See", href: '#what-to-expect' },
  { label: 'Commands', href: '#commands' },
  { label: 'Uninstall', href: '#uninstall' },
];

export default function App() {
  return (
    <div className="min-h-screen bg-white text-[#1D1D1F]">
      {/* Apple-like translucent single-row top navigation */}
      <header className="sticky top-0 z-40 h-14 backdrop-blur-xl bg-white/80 border-b border-black/[0.06]">
        <div className="max-w-[1080px] h-full mx-auto px-6 flex items-center justify-between gap-4">
          <a
            href="#purpose"
            className="inline-flex items-center gap-2 text-[#1D1D1F] font-semibold tracking-tight text-base whitespace-nowrap shrink-0"
          >
            <Shield className="w-4 h-4 text-[#0071E3]" aria-hidden="true" />
            <span>Kavach</span>
          </a>

          <nav aria-label="Onboarding sections" className="hidden md:flex items-center gap-7">
            {NAV_ITEMS.map((item) => (
              <a
                key={item.href}
                href={item.href}
                className="text-xs font-medium text-[#6E6E73] hover:text-[#1D1D1F] transition-colors whitespace-nowrap shrink-0"
              >
                {item.label}
              </a>
            ))}
          </nav>

          <a
            href="#start-here"
            className="inline-flex items-center justify-center rounded-full bg-[#0071E3] hover:bg-[#0077ED] text-white px-4 py-1.5 text-xs font-medium transition-colors whitespace-nowrap shrink-0"
          >
            Get Started
          </a>
        </div>
      </header>

      <main>
        <HeroOnboardingFlow />
        <GettingStartedStepper />
        <OutcomeExplorer />
        <CommandReference />
      </main>
    </div>
  );
}
