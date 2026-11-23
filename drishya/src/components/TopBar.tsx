import { ActiveScreen } from '../types.ts';

interface TopBarProps {
  activeScreen: ActiveScreen;
  onNavigate: (screen: ActiveScreen) => void;
  userEmail: string;
  onOpenAuth: () => void;
  isShareViewer?: boolean;
}

export function TopBar({
  activeScreen,
  onNavigate,
  userEmail,
  onOpenAuth,
  isShareViewer,
}: TopBarProps) {
  const navItems: Array<{ id: ActiveScreen; label: string }> = [
    { id: 'library', label: 'Start & History' },
    { id: 'new', label: 'New Research' },
    { id: 'job', label: 'Job Progress' },
    { id: 'settings', label: 'Settings' },
  ];

  return (
    <header className="sticky top-0 z-30 border-b border-slate-200 bg-white/95 backdrop-blur-sm">
      <div className="mx-auto flex max-w-7xl items-center justify-between gap-8 px-6 py-3.5">
        <button
          type="button"
          onClick={() => onNavigate('library')}
          className="flex items-baseline gap-2.5 whitespace-nowrap shrink-0 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-blue-700"
        >
          <span className="font-display text-xl font-bold tracking-tight text-slate-900">
            Drishya
          </span>
          <span className="font-mono text-[11px] font-medium text-blue-700">
            Research Labs
          </span>
        </button>

        {!isShareViewer ? (
          <nav
            aria-label="Primary navigation"
            className="hidden md:flex items-center gap-6 text-sm font-medium text-slate-600"
          >
            {navItems.map((item) => {
              const isActive =
                activeScreen === item.id ||
                (item.id === 'library' && activeScreen === 'player');
              return (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => onNavigate(item.id)}
                  className={`py-1 transition-colors whitespace-nowrap shrink-0 border-b-2 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-blue-700 ${
                    isActive
                      ? 'border-blue-700 text-slate-900 font-semibold'
                      : 'border-transparent text-slate-600 hover:text-slate-900 hover:border-slate-300'
                  }`}
                >
                  {item.label}
                </button>
              );
            })}
          </nav>
        ) : (
          <div className="text-sm text-slate-600 whitespace-nowrap shrink-0">
            Shared Viewer Access
          </div>
        )}

        <div className="flex items-center shrink-0">
          <button
            type="button"
            onClick={onOpenAuth}
            className="rounded-lg bg-blue-700 px-4 py-2 text-xs font-semibold text-white transition-colors hover:bg-blue-800 whitespace-nowrap shrink-0 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-700"
          >
            {userEmail === 'researcher@drishya.local' ? 'Sign In' : userEmail}
          </button>
        </div>
      </div>
    </header>
  );
}
