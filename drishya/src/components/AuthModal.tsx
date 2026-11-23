import { useState } from 'react';
import { X } from 'lucide-react';

interface AuthModalProps {
  isOpen: boolean;
  onClose: () => void;
  currentEmail: string;
  authMethod: string;
  onAuthenticated: (token: string, email: string, name: string, method: string) => void;
}

export function AuthModal({
  isOpen,
  onClose,
  currentEmail,
  authMethod,
  onAuthenticated,
}: AuthModalProps) {
  const [email, setEmail] = useState('scholar@institute.edu');
  const [issuedToken, setIssuedToken] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!isOpen) return null;

  async function handleSendMagicLink(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      const res = await fetch('/api/auth/magic-link', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Failed to send magic link');
      setIssuedToken(data.magicToken);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Magic link error');
    } finally {
      setLoading(false);
    }
  }

  async function handleVerifyMagicLink() {
    if (!issuedToken) return;
    setLoading(true);
    setError(null);
    try {
      const res = await fetch('/api/auth/verify-magic-link', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ magicToken: issuedToken }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Verification failed');
      onAuthenticated(data.token, data.user.email, data.user.name, 'magic-link');
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Verification failed');
    } finally {
      setLoading(false);
    }
  }

  async function handleGoogleSignIn() {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch('/api/auth/google', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, name: 'Dr. Ananya Scholar' }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Google sign-in failed');
      onAuthenticated(data.token, data.user.email, data.user.name, 'google');
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Google sign-in error');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="auth-modal-title"
      className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 p-4"
    >
      <div className="w-full max-w-md rounded-xl border border-slate-200 bg-white p-6 shadow-xl">
        <div className="flex items-start justify-between gap-4">
          <div>
            <h2 id="auth-modal-title" className="text-lg font-semibold text-slate-900">
              Workspace Account
            </h2>
            <p className="mt-1 text-xs text-slate-500">
              Active session: {currentEmail} · Role: Owner ({authMethod})
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label="Close sign in dialog"
            className="rounded-lg p-2 text-slate-500 hover:bg-slate-100 hover:text-slate-900"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        <form onSubmit={handleSendMagicLink} className="mt-5 space-y-4">
          <div>
            <label htmlFor="magic-email" className="block text-sm font-medium text-slate-700">
              Email address
            </label>
            <input
              id="magic-email"
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="mt-1.5 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm text-slate-900 focus:border-blue-700 focus:outline-none"
              placeholder="researcher@university.edu"
            />
          </div>

          {error && (
            <p role="alert" className="text-xs font-medium text-red-700">
              {error}
            </p>
          )}

          {issuedToken ? (
            <div className="rounded-lg border border-slate-200 bg-slate-50 p-3 space-y-2">
              <p className="text-xs text-slate-700">
                Magic link token issued for <strong>{email}</strong> (15-min expiry).
              </p>
              <button
                type="button"
                disabled={loading}
                onClick={handleVerifyMagicLink}
                className="w-full rounded-lg bg-emerald-700 px-4 py-2 text-xs font-semibold text-white hover:bg-emerald-800 disabled:opacity-50"
              >
                Verify Magic Link & Sign In
              </button>
            </div>
          ) : (
            <button
              type="submit"
              disabled={loading}
              className="w-full rounded-lg bg-blue-700 px-4 py-2 text-xs font-semibold text-white hover:bg-blue-800 disabled:opacity-50"
            >
              Send Email Magic Link
            </button>
          )}
        </form>

        <div className="my-4 flex items-center gap-3">
          <div className="h-px flex-1 bg-slate-200" />
          <span className="text-xs text-slate-400">or</span>
          <div className="h-px flex-1 bg-slate-200" />
        </div>

        <button
          type="button"
          disabled={loading}
          onClick={handleGoogleSignIn}
          className="w-full rounded-lg border border-slate-300 bg-white px-4 py-2 text-xs font-semibold text-slate-800 hover:bg-slate-50 disabled:opacity-50"
        >
          Continue with Google Sign-In
        </button>

        <p className="mt-4 text-xs text-slate-500 leading-relaxed">
          Documents and rendered videos are isolated per workspace owner. Shared links grant read-only Viewer access and expire automatically.
        </p>
      </div>
    </div>
  );
}
