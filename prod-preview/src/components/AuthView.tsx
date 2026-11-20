import { useState, type FormEvent } from 'react';
import { ArrowRight, KeyRound, Lock, Mail, ShieldCheck, UserPlus, Users } from 'lucide-react';
import type { UserRole } from '../types/domain.ts';
import {
  googleSignInApi,
  loginApi,
  registerApi,
  type AuthResponse,
} from '../utils/api.ts';
import {
  GoogleCloudLogo,
  HeroWorkflowIllustration,
  MicrosoftProjectMark,
  TerraformLogo,
} from './BrandVisuals.tsx';

interface AuthViewProps {
  onAuthenticated: (auth: AuthResponse) => void;
}

export function AuthView({ onAuthenticated }: AuthViewProps) {
  const [mode, setMode] = useState<'login' | 'register'>('login');
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState<UserRole>('stakeholder');
  const [googleEmail, setGoogleEmail] = useState('reviewer@acme-retail.example');
  const [googleOpen, setGoogleOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const res =
        mode === 'login'
          ? await loginApi(email, password)
          : await registerApi(name, email, password, role);
      onAuthenticated(res);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Authentication failed');
    } finally {
      setBusy(false);
    }
  };

  const handleQuickDemoSignIn = async (demoEmail: string) => {
    setError(null);
    setBusy(true);
    try {
      const res = await loginApi(demoEmail, 'ProdPreview2026!');
      onAuthenticated(res);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Demo sign-in failed');
    } finally {
      setBusy(false);
    }
  };

  const handleGoogleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const inferredName = googleEmail
        .split('@')[0]
        .replace(/[._-]/g, ' ')
        .replace(/\b\w/g, (c) => c.toUpperCase());
      const res = await googleSignInApi(googleEmail, inferredName, role);
      onAuthenticated(res);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Google sign-in failed');
    } finally {
      setBusy(false);
    }
  };

  return (
    <section aria-labelledby="auth-heading" className="mx-auto max-w-6xl py-4 sm:py-8">
      <div className="ms-card overflow-hidden">
        <div className="grid grid-cols-1 lg:grid-cols-12">
          {/* Left Column: Sign-In / Registration Form */}
          <div className="p-6 sm:p-8 lg:col-span-6 space-y-6">
            <div className="space-y-2">
              <div className="flex items-center gap-2 text-xs font-semibold text-[#0E6B38]">
                <MicrosoftProjectMark className="h-5 w-5" />
                <span>Prod Preview · Workspace Access</span>
              </div>
              <h1 id="auth-heading" className="text-2xl font-bold tracking-tight text-[#242424]">
                {mode === 'login'
                  ? 'Sign in to review POC scorecards'
                  : 'Create your Prod Preview account'}
              </h1>
              <p className="text-xs text-[#605E5C]">
                Authenticated sessions keep your personal project history, sign-off audit trail,
                and role permissions isolated per user.
              </p>
            </div>

            {/* Mode Segmented Toggle */}
            <div
              role="tablist"
              aria-label="Authentication mode"
              className="grid grid-cols-2 gap-1 rounded border border-[#E1DFDD] bg-[#F3F2F1] p-1"
            >
              <button
                type="button"
                role="tab"
                aria-selected={mode === 'login'}
                onClick={() => {
                  setMode('login');
                  setError(null);
                }}
                className={`min-h-[36px] rounded-xs text-xs font-semibold transition-colors ${
                  mode === 'login'
                    ? 'bg-white text-[#0E6B38] shadow-xs'
                    : 'text-[#605E5C] hover:text-[#242424]'
                }`}
              >
                Sign In
              </button>
              <button
                type="button"
                role="tab"
                aria-selected={mode === 'register'}
                onClick={() => {
                  setMode('register');
                  setError(null);
                }}
                className={`min-h-[36px] rounded-xs text-xs font-semibold transition-colors ${
                  mode === 'register'
                    ? 'bg-white text-[#0E6B38] shadow-xs'
                    : 'text-[#605E5C] hover:text-[#242424]'
                }`}
              >
                Create Account
              </button>
            </div>

            {error ? (
              <div
                role="alert"
                className="rounded border border-[#C50F1F]/30 bg-[#FDF3F4] px-3.5 py-2.5 text-xs text-[#C50F1F]"
              >
                {error}
              </div>
            ) : null}

            <form onSubmit={handleSubmit} className="space-y-4">
              {mode === 'register' && (
                <div>
                  <label htmlFor="auth-name" className="block text-xs font-semibold text-[#242424]">
                    Full Name
                  </label>
                  <input
                    id="auth-name"
                    type="text"
                    required
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    placeholder="e.g., Alex Morgan"
                    className="mt-1 min-h-[38px] w-full rounded border border-[#8A8886] px-3 text-sm text-[#242424]"
                  />
                </div>
              )}

              <div>
                <label htmlFor="auth-email" className="block text-xs font-semibold text-[#242424]">
                  Work Email
                </label>
                <div className="relative mt-1">
                  <Mail
                    className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[#605E5C]"
                    aria-hidden="true"
                  />
                  <input
                    id="auth-email"
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="name@company.com"
                    className="min-h-[38px] w-full rounded border border-[#8A8886] pl-9 pr-3 text-sm text-[#242424]"
                  />
                </div>
              </div>

              <div>
                <label
                  htmlFor="auth-password"
                  className="block text-xs font-semibold text-[#242424]"
                >
                  Password
                </label>
                <div className="relative mt-1">
                  <KeyRound
                    className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[#605E5C]"
                    aria-hidden="true"
                  />
                  <input
                    id="auth-password"
                    type="password"
                    required
                    minLength={8}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder={mode === 'register' ? 'Minimum 8 characters' : 'Enter password'}
                    className="min-h-[38px] w-full rounded border border-[#8A8886] pl-9 pr-3 text-sm text-[#242424]"
                  />
                </div>
              </div>

              {mode === 'register' && (
                <div>
                  <label htmlFor="auth-role" className="block text-xs font-semibold text-[#242424]">
                    Workspace Role
                  </label>
                  <select
                    id="auth-role"
                    value={role}
                    onChange={(e) => setRole(e.target.value as UserRole)}
                    className="mt-1 min-h-[38px] w-full rounded border border-[#8A8886] bg-white px-3 text-sm text-[#242424]"
                  >
                    <option value="stakeholder">Stakeholder (View, What-If, Comment, Sign Off)</option>
                    <option value="engineer">Engineer (Upload POCs, Edit Mappings, Approve)</option>
                  </select>
                </div>
              )}

              <button
                type="submit"
                disabled={busy}
                className="inline-flex min-h-[40px] w-full items-center justify-center gap-2 rounded bg-[#107C41] px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-[#0C6233] disabled:opacity-50"
              >
                {mode === 'login' ? (
                  <>
                    <Lock className="h-4 w-4" aria-hidden="true" />
                    <span>{busy ? 'Signing in...' : 'Sign In'}</span>
                  </>
                ) : (
                  <>
                    <UserPlus className="h-4 w-4" aria-hidden="true" />
                    <span>{busy ? 'Creating account...' : 'Create Account & Enter'}</span>
                  </>
                )}
              </button>
            </form>

            {/* Google Identity Platform Sign-In */}
            <div className="space-y-3 border-t border-[#EDEBE9] pt-4">
              {!googleOpen ? (
                <button
                  type="button"
                  disabled={busy}
                  onClick={() => setGoogleOpen(true)}
                  className="inline-flex min-h-[40px] w-full items-center justify-center gap-2 rounded border border-[#8A8886] bg-white px-4 py-2 text-xs font-semibold text-[#242424] hover:bg-[#F3F2F1]"
                >
                  <GoogleCloudLogo className="h-4 w-4" />
                  <span>Continue with Google Workspace</span>
                </button>
              ) : (
                <form
                  onSubmit={handleGoogleSubmit}
                  className="rounded border border-[#E1DFDD] bg-[#FAF9F8] p-3.5 space-y-2.5"
                >
                  <div className="flex items-center justify-between text-xs font-semibold text-[#242424]">
                    <span className="flex items-center gap-1.5">
                      <GoogleCloudLogo className="h-4 w-4" />
                      <span>Google Identity Workspace</span>
                    </span>
                    <button
                      type="button"
                      onClick={() => setGoogleOpen(false)}
                      className="text-[11px] font-medium text-[#605E5C] hover:underline"
                    >
                      Cancel
                    </button>
                  </div>
                  <input
                    type="email"
                    required
                    value={googleEmail}
                    onChange={(e) => setGoogleEmail(e.target.value)}
                    aria-label="Google Workspace email"
                    placeholder="you@company.com"
                    className="min-h-[36px] w-full rounded border border-[#8A8886] bg-white px-3 text-xs text-[#242424]"
                  />
                  <div className="flex items-center gap-2">
                    <select
                      value={role}
                      onChange={(e) => setRole(e.target.value as UserRole)}
                      aria-label="Google sign-in role"
                      className="min-h-[36px] flex-1 rounded border border-[#8A8886] bg-white px-2 text-xs text-[#242424]"
                    >
                      <option value="stakeholder">Stakeholder Role</option>
                      <option value="engineer">Engineer Role</option>
                    </select>
                    <button
                      type="submit"
                      disabled={busy}
                      className="min-h-[36px] rounded bg-[#0F6CBD] px-3.5 text-xs font-semibold text-white hover:bg-[#115EA3]"
                    >
                      Verify &amp; Enter
                    </button>
                  </div>
                </form>
              )}

              {/* 1-Click Seeded Demo Logins */}
              <div className="space-y-2 pt-1">
                <div className="text-[11px] font-semibold text-[#605E5C]">
                  Quick Workspace Demo Sign-In (each keeps separate project history)
                </div>
                <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
                  <button
                    type="button"
                    disabled={busy}
                    onClick={() => handleQuickDemoSignIn('claire.bennett@acme-retail.example')}
                    className="flex items-center justify-between gap-2 rounded border border-[#E1DFDD] bg-[#FAF9F8] px-3 py-2 text-left hover:bg-[#EFF6F1]"
                  >
                    <div className="min-w-0">
                      <div className="flex items-center gap-1.5 text-xs font-semibold text-[#242424]">
                        <Users className="h-3.5 w-3.5 text-[#0F6CBD]" aria-hidden="true" />
                        <span className="truncate">Claire Bennett</span>
                      </div>
                      <div className="text-[11px] text-[#605E5C]">Stakeholder</div>
                    </div>
                    <ArrowRight className="h-3.5 w-3.5 text-[#107C41] shrink-0" aria-hidden="true" />
                  </button>

                  <button
                    type="button"
                    disabled={busy}
                    onClick={() => handleQuickDemoSignIn('priya.nair@acme-retail.example')}
                    className="flex items-center justify-between gap-2 rounded border border-[#E1DFDD] bg-[#FAF9F8] px-3 py-2 text-left hover:bg-[#EFF6F1]"
                  >
                    <div className="min-w-0">
                      <div className="flex items-center gap-1.5 text-xs font-semibold text-[#242424]">
                        <TerraformLogo className="h-3.5 w-3.5" />
                        <span className="truncate">Priya Nair</span>
                      </div>
                      <div className="text-[11px] text-[#605E5C]">Lead Engineer</div>
                    </div>
                    <ArrowRight className="h-3.5 w-3.5 text-[#107C41] shrink-0" aria-hidden="true" />
                  </button>
                </div>
              </div>
            </div>
          </div>

          {/* Right Column: Visual Platform Overview */}
          <div className="flex flex-col justify-between border-t border-[#E1DFDD] bg-[#FAF9F8] p-6 sm:p-8 lg:col-span-6 lg:border-l lg:border-t-0">
            <HeroWorkflowIllustration />

            <div className="mt-5 grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div className="rounded border border-[#E1DFDD] bg-white p-3.5">
                <div className="flex items-center gap-1.5 text-xs font-semibold text-[#0E6B38]">
                  <ShieldCheck className="h-4 w-4" aria-hidden="true" />
                  <span>Signed Sessions &amp; RBAC</span>
                </div>
                <p className="mt-1 text-xs text-[#605E5C]">
                  HMAC-signed session tokens and invite links protect every POC route.
                </p>
              </div>
              <div className="rounded border border-[#E1DFDD] bg-white p-3.5">
                <div className="flex items-center gap-1.5 text-xs font-semibold text-[#0F6CBD]">
                  <MicrosoftProjectMark className="h-4 w-4" />
                  <span>Per-User Project History</span>
                </div>
                <p className="mt-1 text-xs text-[#605E5C]">
                  Every review, simulation, and sign-off is saved to your personal timeline.
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
