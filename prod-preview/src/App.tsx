import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { BookOpen, LogOut, Menu, Shield, X } from 'lucide-react';
import type {
  AuthSession,
  POC,
  ProjectHistoryEntry,
  UserRecentPocSummary,
  UserRole,
} from './types/domain.ts';
import {
  clearUserHistoryApi,
  fetchPocs,
  fetchSession,
  fetchUserHistoryApi,
  logoutApi,
  recordUserHistoryApi,
  type AuthResponse,
  type ClientAuthHeaders,
} from './utils/api.ts';
import { ArchitectureMapView } from './components/ArchitectureMapView.tsx';
import { AuthView } from './components/AuthView.tsx';
import { EngineerConsoleView } from './components/EngineerConsoleView.tsx';
import { HistoryView } from './components/HistoryView.tsx';
import { OnboardingView } from './components/OnboardingView.tsx';
import { PocListView } from './components/PocListView.tsx';
import { ScorecardView } from './components/ScorecardView.tsx';
import { SignOffView } from './components/SignOffView.tsx';
import { WhatIfView } from './components/WhatIfView.tsx';

type TabId =
  | 'onboarding'
  | 'pocs'
  | 'architecture'
  | 'scorecard'
  | 'whatif'
  | 'signoff'
  | 'console'
  | 'history';

const SESSION_TOKEN_KEY = 'pp_session_token';

const TAB_LABELS: Record<TabId, string> = {
  onboarding: 'How It Works',
  pocs: 'POCs',
  architecture: 'Architecture Map',
  scorecard: 'Requirements Scorecard',
  whatif: 'What-If Simulator',
  signoff: 'Sign-Off',
  console: 'Engineer Console',
  history: 'Project History',
};

function readStoredSessionToken(): string | null {
  try {
    return window.localStorage.getItem(SESSION_TOKEN_KEY);
  } catch {
    return null;
  }
}

function saveStoredSessionToken(token: string | null): void {
  try {
    if (token) {
      window.localStorage.setItem(SESSION_TOKEN_KEY, token);
    } else {
      window.localStorage.removeItem(SESSION_TOKEN_KEY);
    }
  } catch {
    // Ignore storage quota or sandbox restrictions
  }
}

function getInitialQueryParams(): {
  inviteToken: string | null;
  initialTab: TabId;
} {
  if (typeof window === 'undefined') {
    return { inviteToken: null, initialTab: 'onboarding' };
  }
  const params = new URLSearchParams(window.location.search);
  const inviteToken = params.get('invite');
  const rawTab = params.get('tab') as TabId | null;
  const validTabs: TabId[] = [
    'onboarding',
    'pocs',
    'architecture',
    'scorecard',
    'whatif',
    'signoff',
    'console',
    'history',
  ];
  const initialTab =
    rawTab && validTabs.includes(rawTab)
      ? rawTab
      : inviteToken
        ? 'scorecard'
        : 'onboarding';
  return { inviteToken, initialTab };
}

export default function App() {
  const initial = useMemo(() => getInitialQueryParams(), []);
  const [inviteToken] = useState<string | null>(initial.inviteToken);
  const [sessionToken, setSessionToken] = useState<string | null>(() =>
    initial.inviteToken ? null : readStoredSessionToken()
  );
  const [previewAsStakeholder, setPreviewAsStakeholder] = useState(false);
  const [activeTab, setActiveTab] = useState<TabId>(initial.initialTab);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  const [session, setSession] = useState<AuthSession | null>(null);
  const [pocs, setPocs] = useState<POC[]>([]);
  const [history, setHistory] = useState<ProjectHistoryEntry[]>([]);
  const [recentPocs, setRecentPocs] = useState<UserRecentPocSummary[]>([]);
  const [activePocId, setActivePocId] = useState<string>('');
  const [loading, setLoading] = useState(true);
  const [authError, setAuthError] = useState<string | null>(null);
  const lastViewedKeyRef = useRef<string>('');

  const authHeaders: ClientAuthHeaders = useMemo(() => {
    if (inviteToken) return { inviteToken };
    if (sessionToken) return { sessionToken };
    return {};
  }, [inviteToken, sessionToken]);

  const refreshHistory = useCallback(async () => {
    try {
      const data = await fetchUserHistoryApi(authHeaders);
      setHistory(data.history);
      setRecentPocs(data.recent_pocs);
    } catch {
      // Non-fatal if session just ended
    }
  }, [authHeaders]);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setAuthError(null);

    (async () => {
      try {
        const sess = await fetchSession(authHeaders);
        if (cancelled) return;
        setSession(sess);

        if (!sess.authenticated) {
          if (sessionToken) {
            saveStoredSessionToken(null);
            setSessionToken(null);
          }
          setPocs([]);
          setHistory([]);
          setRecentPocs([]);
          return;
        }

        const [pocList, historyData] = await Promise.all([
          fetchPocs(authHeaders),
          fetchUserHistoryApi(authHeaders),
        ]);
        if (cancelled) return;
        setPocs(pocList);
        setHistory(historyData.history);
        setRecentPocs(historyData.recent_pocs);
        setActivePocId((prev) => {
          if (prev && pocList.some((p) => p.id === prev)) return prev;
          return pocList[0]?.id ?? '';
        });
        if (sess.role !== 'engineer' && activeTab === 'console') {
          setActiveTab('scorecard');
        }
      } catch (err) {
        if (!cancelled) {
          setAuthError(err instanceof Error ? err.message : 'Unable to load POC session');
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [authHeaders]);

  const activePoc = pocs.find((p) => p.id === activePocId) ?? pocs[0] ?? null;
  const isAuthenticated = Boolean(session?.authenticated);
  const effectiveRole: UserRole =
    session?.role === 'engineer' && !previewAsStakeholder ? 'engineer' : 'stakeholder';

  // Record per-user project view history when switching tabs or POCs
  useEffect(() => {
    if (!isAuthenticated || !session || !activePoc) return;
    if (
      activeTab !== 'architecture' &&
      activeTab !== 'scorecard' &&
      activeTab !== 'whatif' &&
      activeTab !== 'signoff' &&
      activeTab !== 'console'
    ) {
      return;
    }
    const key = `${session.user_email}:${activePoc.id}:${activeTab}`;
    if (lastViewedKeyRef.current === key) return;
    lastViewedKeyRef.current = key;

    void recordUserHistoryApi(
      {
        poc_id: activePoc.id,
        action: 'viewed',
        summary: `Opened ${TAB_LABELS[activeTab]} view`,
        tab: activeTab,
      },
      authHeaders
    )
      .then(() => refreshHistory())
      .catch(() => undefined);
  }, [isAuthenticated, session, activePoc, activeTab, authHeaders, refreshHistory]);

  useEffect(() => {
    if (isAuthenticated && (activeTab === 'history' || activeTab === 'pocs')) {
      void refreshHistory();
    }
  }, [isAuthenticated, activeTab, refreshHistory]);

  const navItems: Array<{ id: TabId; label: string }> = isAuthenticated
    ? [
        ...(!inviteToken ? [{ id: 'pocs' as const, label: 'POCs' }] : []),
        { id: 'architecture', label: 'Architecture' },
        { id: 'scorecard', label: 'Scorecard' },
        { id: 'whatif', label: 'What-If' },
        { id: 'signoff', label: 'Sign-Off' },
        ...(effectiveRole === 'engineer'
          ? [{ id: 'console' as const, label: 'Console' }]
          : []),
        ...(!inviteToken ? [{ id: 'history' as const, label: 'History' }] : []),
      ]
    : [];

  const handlePocUpdated = (updated: POC) => {
    setPocs((prev) => prev.map((p) => (p.id === updated.id ? updated : p)));
    void refreshHistory();
  };

  const handleAuthenticated = (authRes: AuthResponse) => {
    saveStoredSessionToken(authRes.token);
    lastViewedKeyRef.current = '';
    setAuthError(null);
    setPreviewAsStakeholder(false);
    setSession(authRes.session);
    setSessionToken(authRes.token);
    if (authRes.session.role !== 'engineer' && activeTab === 'console') {
      setActiveTab('onboarding');
    }
  };

  const handleSignOut = async () => {
    try {
      await logoutApi(authHeaders);
    } catch {
      // Ignore network errors on sign-out
    }
    saveStoredSessionToken(null);
    lastViewedKeyRef.current = '';
    setSessionToken(null);
    setSession({
      authenticated: false,
      user_name: 'Guest',
      user_email: '',
      role: 'stakeholder',
      auth_method: 'none',
      scoped_poc_id: null,
      invite_expires_at: null,
    });
    setPocs([]);
    setHistory([]);
    setRecentPocs([]);
    setActivePocId('');
    setPreviewAsStakeholder(false);
    setMobileMenuOpen(false);
    setActiveTab('onboarding');
  };

  const handleClearHistory = async () => {
    await clearUserHistoryApi(authHeaders);
    setHistory([]);
    setRecentPocs([]);
  };

  return (
    <div className="min-h-screen bg-[#FAF9F8] text-[#242424]">
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 focus:rounded focus:bg-[#107C41] focus:px-3 focus:py-2 focus:text-sm focus:font-medium focus:text-white"
      >
        Skip to main content
      </a>

      {/* Microsoft Project Suite Header — Strict 3-zone Top Bar Contract */}
      <header className="sticky top-0 z-30 border-b border-[#0B5A2F] bg-[#107C41] text-white">
        <div className="mx-auto flex h-12 max-w-7xl items-center justify-between gap-6 px-4 sm:px-6">
          {/* Zone 1: Single-line Brand Wordmark */}
          <a
            href="#main-content"
            onClick={(e) => {
              e.preventDefault();
              setActiveTab('onboarding');
            }}
            className="font-display text-base font-bold tracking-tight text-white whitespace-nowrap shrink-0"
          >
            Prod Preview
          </a>

          {/* Zone 2: Concise single-line Microsoft Project view pivots */}
          <nav
            aria-label="Primary navigation"
            className="hidden md:flex h-full items-center gap-5 lg:gap-6 text-sm font-medium text-white/90"
          >
            {navItems.map((item) => {
              const active = activeTab === item.id;
              return (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => setActiveTab(item.id)}
                  aria-current={active ? 'page' : undefined}
                  className={`flex h-full items-center px-1 transition-colors whitespace-nowrap shrink-0 ${
                    active
                      ? 'border-b-2 border-white font-semibold text-white'
                      : 'text-white/90 hover:text-white'
                  }`}
                >
                  {item.label}
                </button>
              );
            })}
          </nav>

          {/* Zone 3: Single primary action + mobile menu trigger */}
          <div className="flex items-center gap-2 shrink-0">
            {isAuthenticated ? (
              <>
                <button
                  type="button"
                  onClick={() =>
                    setActiveTab(
                      activeTab === 'onboarding'
                        ? inviteToken
                          ? 'scorecard'
                          : 'pocs'
                        : 'onboarding'
                    )
                  }
                  className={`hidden sm:inline-flex min-h-[34px] items-center gap-1.5 rounded px-3 py-1.5 text-xs font-semibold transition-colors whitespace-nowrap shrink-0 ${
                    activeTab === 'onboarding'
                      ? 'bg-white text-[#0E6B38] hover:bg-[#EFF6F1]'
                      : 'border border-white/40 bg-white/10 text-white hover:bg-white/20'
                  }`}
                >
                  <BookOpen className="h-3.5 w-3.5" aria-hidden="true" />
                  <span>
                    {activeTab === 'onboarding'
                      ? inviteToken
                        ? 'View Scorecard'
                        : 'Browse POCs'
                      : 'How It Works'}
                  </span>
                </button>

                <button
                  type="button"
                  onClick={() => setMobileMenuOpen((v) => !v)}
                  aria-expanded={mobileMenuOpen}
                  aria-label="Toggle navigation menu"
                  className="inline-flex min-h-[40px] min-w-[40px] items-center justify-center rounded border border-white/30 text-white hover:bg-white/10 md:hidden"
                >
                  {mobileMenuOpen ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
                </button>
              </>
            ) : (
              <span className="text-xs font-medium text-white/90 whitespace-nowrap">
                Workspace Sign-In
              </span>
            )}
          </div>
        </div>

        {/* Collapsible Mobile Navigation Drawer */}
        {isAuthenticated && mobileMenuOpen ? (
          <nav
            aria-label="Mobile navigation"
            className="border-t border-[#E1DFDD] bg-white px-4 py-3 text-[#242424] md:hidden"
          >
            <div className="flex flex-col gap-1">
              <button
                type="button"
                onClick={() => {
                  setActiveTab('onboarding');
                  setMobileMenuOpen(false);
                }}
                className={`min-h-[44px] rounded px-3 text-left text-sm font-medium ${
                  activeTab === 'onboarding'
                    ? 'bg-[#EFF6F1] font-semibold text-[#0E6B38]'
                    : 'text-[#323130] hover:bg-[#F3F2F1]'
                }`}
              >
                How It Works
              </button>
              {navItems.map((item) => {
                const active = activeTab === item.id;
                return (
                  <button
                    key={item.id}
                    type="button"
                    onClick={() => {
                      setActiveTab(item.id);
                      setMobileMenuOpen(false);
                    }}
                    className={`min-h-[44px] rounded px-3 text-left text-sm font-medium ${
                      active
                        ? 'bg-[#EFF6F1] font-semibold text-[#0E6B38]'
                        : 'text-[#323130] hover:bg-[#F3F2F1]'
                    }`}
                  >
                    {item.label}
                  </button>
                );
              })}
              {!inviteToken && (
                <button
                  type="button"
                  onClick={() => void handleSignOut()}
                  className="mt-1 flex min-h-[44px] items-center gap-2 rounded border-t border-[#EDEBE9] px-3 text-left text-sm font-medium text-[#C50F1F] hover:bg-[#FDF3F4]"
                >
                  <LogOut className="h-4 w-4" aria-hidden="true" />
                  <span>Sign Out</span>
                </button>
              )}
            </div>
          </nav>
        ) : null}
      </header>

      {/* Microsoft Project Breadcrumb & Account Command Strip */}
      {isAuthenticated && session && !authError ? (
        <div className="border-b border-[#E1DFDD] bg-white">
          <div className="mx-auto flex max-w-7xl flex-col gap-2.5 px-4 py-2.5 sm:flex-row sm:items-center sm:justify-between sm:px-6">
            {activePoc ? (
              <div className="flex flex-wrap items-center gap-x-2 gap-y-1.5 text-xs text-[#605E5C]">
                <button
                  type="button"
                  onClick={() => setActiveTab(inviteToken ? 'scorecard' : 'pocs')}
                  className="font-medium text-[#605E5C] hover:text-[#107C41] hover:underline"
                >
                  Projects
                </button>
                <span aria-hidden="true">/</span>
                {!inviteToken && pocs.length > 1 ? (
                  <div className="flex items-center gap-1.5">
                    <label htmlFor="active-poc-select" className="sr-only">
                      Active Proof-of-Concept
                    </label>
                    <select
                      id="active-poc-select"
                      value={activePoc.id}
                      onChange={(e) => setActivePocId(e.target.value)}
                      className="min-h-[32px] rounded border border-[#E1DFDD] bg-[#FAF9F8] px-2 text-xs font-semibold text-[#242424] hover:border-[#8A8886]"
                    >
                      {pocs.map((p) => (
                        <option key={p.id} value={p.id}>
                          {p.name}
                        </option>
                      ))}
                    </select>
                  </div>
                ) : (
                  <span className="font-semibold text-[#242424]">{activePoc.name}</span>
                )}
                <span aria-hidden="true">/</span>
                <span>{activePoc.environment.region_display}</span>
                <span aria-hidden="true">·</span>
                <span className="tabular-nums font-medium text-[#323130]">
                  {activePoc.environment.days_until_teardown} days until teardown
                </span>
              </div>
            ) : (
              <div className="text-xs font-medium text-[#605E5C]">Personal Workspace</div>
            )}

            <div className="flex flex-wrap items-center gap-3 text-xs">
              <div className="flex items-center gap-1.5 text-[#605E5C]">
                <Shield className="h-3.5 w-3.5 text-[#107C41]" aria-hidden="true" />
                <span className="font-medium text-[#242424]">{session.user_name}</span>
                <span>({session.role})</span>
              </div>

              {inviteToken ? (
                <span className="font-medium text-[#A45B00]">
                  Invite link · Read &amp; sign-off only (expires{' '}
                  {session.invite_expires_at?.slice(0, 10)})
                </span>
              ) : (
                <>
                  {session.role === 'engineer' && (
                    <div
                      role="group"
                      aria-label="Preview perspective"
                      className="flex items-center gap-0.5 rounded border border-[#E1DFDD] bg-[#F3F2F1] p-0.5"
                    >
                      <button
                        type="button"
                        onClick={() => {
                          setPreviewAsStakeholder(true);
                          if (activeTab === 'console') setActiveTab('scorecard');
                        }}
                        className={`min-h-[28px] rounded-xs px-2.5 text-xs font-medium transition-colors whitespace-nowrap ${
                          previewAsStakeholder
                            ? 'bg-white font-semibold text-[#0E6B38] shadow-xs'
                            : 'text-[#605E5C] hover:text-[#242424]'
                        }`}
                      >
                        Stakeholder Preview
                      </button>
                      <button
                        type="button"
                        onClick={() => setPreviewAsStakeholder(false)}
                        className={`min-h-[28px] rounded-xs px-2.5 text-xs font-medium transition-colors whitespace-nowrap ${
                          !previewAsStakeholder
                            ? 'bg-white font-semibold text-[#0E6B38] shadow-xs'
                            : 'text-[#605E5C] hover:text-[#242424]'
                        }`}
                      >
                        Engineer View
                      </button>
                    </div>
                  )}

                  <button
                    type="button"
                    onClick={() => void handleSignOut()}
                    className="inline-flex min-h-[30px] items-center gap-1.5 rounded border border-[#E1DFDD] bg-white px-2.5 text-xs font-medium text-[#242424] hover:bg-[#F3F2F1] whitespace-nowrap"
                  >
                    <LogOut className="h-3.5 w-3.5 text-[#605E5C]" aria-hidden="true" />
                    <span>Sign Out</span>
                  </button>
                </>
              )}
            </div>
          </div>
        </div>
      ) : null}

      {/* Main Workspace Canvas */}
      <main id="main-content" className="mx-auto max-w-7xl px-4 py-6 sm:px-6 sm:py-7">
        {loading ? (
          <div className="space-y-4">
            <div className="h-10 w-72 animate-pulse rounded bg-[#EDEBE9]" />
            <div className="h-64 animate-pulse rounded border border-[#E1DFDD] bg-white" />
          </div>
        ) : authError ? (
          <div
            role="alert"
            className="ms-card mx-auto max-w-lg p-6 text-center space-y-2"
          >
            <h1 className="text-lg font-semibold text-[#242424]">Access Denied</h1>
            <p className="text-sm text-[#C50F1F]">{authError}</p>
            <p className="text-xs text-[#605E5C]">
              Ask the POC engineer to generate a fresh stakeholder invite link or sign in with
              your workspace account.
            </p>
          </div>
        ) : !isAuthenticated || !session ? (
          <AuthView onAuthenticated={handleAuthenticated} />
        ) : activeTab === 'history' ? (
          <HistoryView
            session={session}
            history={history}
            recentPocs={recentPocs}
            onReopenPoc={(pocId, nextTab = 'scorecard') => {
              setActivePocId(pocId);
              setActiveTab(
                nextTab === 'console' && effectiveRole !== 'engineer' ? 'scorecard' : nextTab
              );
            }}
            onClearHistory={handleClearHistory}
          />
        ) : !activePoc ? (
          <div className="ms-card p-8 text-center text-sm text-[#605E5C]">
            No proof-of-concept environments found.
          </div>
        ) : (
          <>
            {activeTab === 'onboarding' && (
              <OnboardingView
                role={effectiveRole}
                isInviteSession={Boolean(inviteToken)}
                pocCount={pocs.length}
                onNavigate={(tab) => setActiveTab(tab)}
                onStartAsEngineer={() => {
                  setPreviewAsStakeholder(false);
                  setActiveTab('pocs');
                }}
                onOpenEngineerConsole={() => {
                  setPreviewAsStakeholder(false);
                  setActiveTab('console');
                }}
                onStartAsStakeholder={() => setActiveTab('scorecard')}
              />
            )}
            {activeTab === 'pocs' && (
              <PocListView
                pocs={pocs}
                activePocId={activePoc.id}
                role={effectiveRole}
                userName={session.user_name}
                recentPocs={recentPocs}
                auth={authHeaders}
                onSelectPoc={(id, nextTab = 'scorecard') => {
                  setActivePocId(id);
                  setActiveTab(nextTab);
                }}
                onPocCreated={(created) => {
                  setPocs((prev) => [created, ...prev]);
                  setActivePocId(created.id);
                  setActiveTab(created.pending_drafts.length > 0 ? 'console' : 'scorecard');
                  void refreshHistory();
                }}
                onSwitchToEngineer={
                  session.role === 'engineer' && previewAsStakeholder
                    ? () => setPreviewAsStakeholder(false)
                    : undefined
                }
                onOpenHistory={() => setActiveTab('history')}
              />
            )}
            {activeTab === 'architecture' && <ArchitectureMapView poc={activePoc} />}
            {activeTab === 'scorecard' && <ScorecardView poc={activePoc} />}
            {activeTab === 'whatif' && (
              <WhatIfView poc={activePoc} auth={authHeaders} />
            )}
            {activeTab === 'signoff' && (
              <SignOffView
                poc={activePoc}
                session={session}
                auth={authHeaders}
                onPocUpdated={handlePocUpdated}
                onExportPdf={() => {
                  void recordUserHistoryApi(
                    {
                      poc_id: activePoc.id,
                      action: 'exported_pdf',
                      summary: 'Exported Steering Committee PDF',
                      tab: 'signoff',
                    },
                    authHeaders
                  )
                    .then(() => refreshHistory())
                    .catch(() => undefined);
                }}
              />
            )}
            {activeTab === 'console' && effectiveRole === 'engineer' && (
              <EngineerConsoleView
                poc={activePoc}
                auth={authHeaders}
                onPocUpdated={handlePocUpdated}
              />
            )}
          </>
        )}
      </main>
    </div>
  );
}
