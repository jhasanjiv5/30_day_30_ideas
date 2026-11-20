import fs from 'node:fs';
import path from 'node:path';
import type {
  AuthSession,
  POC,
  ProjectHistoryAction,
  ProjectHistoryEntry,
  UserAccountPublic,
  UserRecentPocSummary,
} from '../../src/types/domain.ts';
import { hashPassword } from './auth.ts';
import { createEnvironmentProvider } from './providers.ts';

export interface StoredUserAccount extends UserAccountPublic {
  password_hash?: string;
}

export interface WorkspaceState {
  pocs: POC[];
  disabled_providers: string[];
  encrypted_byok_keys: Record<string, string>; // Never returned in any API response!
  users: StoredUserAccount[];
  history: ProjectHistoryEntry[];
}

const STORE_PATH = path.resolve(process.cwd(), 'data/store.json');

function buildSeedUsers(): StoredUserAccount[] {
  const now = new Date().toISOString();
  const demoPasswordHash = hashPassword('ProdPreview2026!');
  return [
    {
      id: 'usr-claire',
      name: 'Claire Bennett (VP Operations)',
      email: 'claire.bennett@acme-retail.example',
      role: 'stakeholder',
      auth_provider: 'password',
      password_hash: demoPasswordHash,
      created_at: now,
      last_login_at: now,
    },
    {
      id: 'usr-priya',
      name: 'Priya Nair (Lead Cloud Engineer)',
      email: 'priya.nair@acme-retail.example',
      role: 'engineer',
      auth_provider: 'password',
      password_hash: demoPasswordHash,
      created_at: now,
      last_login_at: now,
    },
  ];
}

function buildSeedHistory(pocs: POC[]): ProjectHistoryEntry[] {
  const nowMs = Date.now();
  const first = pocs[0];
  const second = pocs[1];
  const entries: ProjectHistoryEntry[] = [];
  if (first) {
    entries.push(
      {
        id: 'hist-seed-1',
        user_email: 'priya.nair@acme-retail.example',
        user_name: 'Priya Nair (Lead Cloud Engineer)',
        user_role: 'engineer',
        poc_id: first.id,
        poc_name: first.name,
        action: 'approved_mapping',
        summary: 'Approved initial requirement mappings and published live scorecard',
        tab: 'console',
        timestamp: new Date(nowMs - 4 * 3600_000).toISOString(),
      },
      {
        id: 'hist-seed-2',
        user_email: 'claire.bennett@acme-retail.example',
        user_name: 'Claire Bennett (VP Operations)',
        user_role: 'stakeholder',
        poc_id: first.id,
        poc_name: first.name,
        action: 'signed_off',
        summary: 'Reviewed EU data residency evidence and approved REQ-3',
        tab: 'signoff',
        timestamp: new Date(nowMs - 2 * 3600_000).toISOString(),
      }
    );
  }
  if (second) {
    entries.push({
      id: 'hist-seed-3',
      user_email: 'priya.nair@acme-retail.example',
      user_name: 'Priya Nair (Lead Cloud Engineer)',
      user_role: 'engineer',
      poc_id: second.id,
      poc_name: second.name,
      action: 'rechecked',
      summary: 'Refreshed Cloud Run latency and uptime metrics',
      tab: 'scorecard',
      timestamp: new Date(nowMs - 90 * 60_000).toISOString(),
    });
  }
  return entries;
}

export function toPublicUser(user: StoredUserAccount): UserAccountPublic {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    role: user.role,
    auth_provider: user.auth_provider,
    created_at: user.created_at,
    last_login_at: user.last_login_at,
  };
}

export class AppStore {
  private state: WorkspaceState | null = null;

  async init(): Promise<WorkspaceState> {
    if (this.state) return this.state;

    if (fs.existsSync(STORE_PATH)) {
      try {
        const raw = fs.readFileSync(STORE_PATH, 'utf8');
        const parsed = JSON.parse(raw) as Partial<WorkspaceState>;
        if (Array.isArray(parsed.pocs) && parsed.pocs.length > 0) {
          this.state = {
            pocs: parsed.pocs,
            disabled_providers: Array.isArray(parsed.disabled_providers)
              ? parsed.disabled_providers
              : [],
            encrypted_byok_keys: parsed.encrypted_byok_keys ?? {},
            users:
              Array.isArray(parsed.users) && parsed.users.length > 0
                ? parsed.users
                : buildSeedUsers(),
            history: Array.isArray(parsed.history)
              ? parsed.history
              : buildSeedHistory(parsed.pocs),
          };
          return this.state;
        }
      } catch {
        // Re-seed if corrupted
      }
    }

    const provider = createEnvironmentProvider();
    const pocs = await provider.loadSeedPocs();
    this.state = {
      pocs,
      disabled_providers: [],
      encrypted_byok_keys: {},
      users: buildSeedUsers(),
      history: buildSeedHistory(pocs),
    };
    this.persist();
    return this.state;
  }

  persist(): void {
    if (!this.state) return;
    const dir = path.dirname(STORE_PATH);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(STORE_PATH, JSON.stringify(this.state, null, 2), 'utf8');
  }

  getState(): WorkspaceState {
    if (!this.state) {
      throw new Error('Store not initialized');
    }
    return this.state;
  }

  getPoc(pocId: string): POC | undefined {
    return this.getState().pocs.find((p) => p.id === pocId);
  }

  findUserByEmail(email: string): StoredUserAccount | undefined {
    const normalized = email.trim().toLowerCase();
    return this.getState().users.find((u) => u.email.toLowerCase() === normalized);
  }

  recordUserHistory(input: {
    session: AuthSession;
    poc_id: string;
    poc_name: string;
    action: ProjectHistoryAction;
    summary: string;
    tab?: string;
  }): ProjectHistoryEntry | null {
    if (!input.session.authenticated || !input.session.user_email) {
      return null;
    }
    const state = this.getState();
    const entry: ProjectHistoryEntry = {
      id: `hist-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
      user_email: input.session.user_email.toLowerCase(),
      user_name: input.session.user_name,
      user_role: input.session.role,
      poc_id: input.poc_id,
      poc_name: input.poc_name,
      action: input.action,
      summary: input.summary.slice(0, 240),
      tab: input.tab,
      timestamp: new Date().toISOString(),
    };
    state.history.unshift(entry);
    // Keep bounded history size per store
    if (state.history.length > 500) {
      state.history = state.history.slice(0, 500);
    }
    this.persist();
    return entry;
  }

  getUserHistory(
    userEmail: string,
    scopedPocId?: string | null
  ): { history: ProjectHistoryEntry[]; recent_pocs: UserRecentPocSummary[] } {
    const normalized = userEmail.trim().toLowerCase();
    const entries = this.getState().history.filter((h) => {
      if (h.user_email.toLowerCase() !== normalized) return false;
      if (scopedPocId && h.poc_id !== scopedPocId) return false;
      return true;
    });

    const byPoc = new Map<string, UserRecentPocSummary>();
    for (const h of entries) {
      const existing = byPoc.get(h.poc_id);
      if (!existing) {
        byPoc.set(h.poc_id, {
          poc_id: h.poc_id,
          poc_name: h.poc_name,
          last_accessed_at: h.timestamp,
          last_action: h.action,
          last_tab: h.tab,
          interaction_count: 1,
        });
      } else {
        existing.interaction_count += 1;
      }
    }

    return {
      history: entries,
      recent_pocs: Array.from(byPoc.values()),
    };
  }
}

export function isPlaceholderSecret(val?: string | null): boolean {
  if (!val) return true;
  const trimmed = val.trim();
  if (trimmed.length < 8) return true;
  return (
    trimmed.startsWith('YOUR_') ||
    trimmed.startsWith('MY_') ||
    trimmed.startsWith('REPLACE_') ||
    trimmed.includes('PLACEHOLDER')
  );
}

export function containsSecretLeak(payloadText: string): boolean {
  const secretKeys = [
    process.env.GEMINI_API_KEY,
    process.env.ANTHROPIC_API_KEY,
    process.env.OPENAI_API_KEY,
    process.env.AZURE_OPENAI_API_KEY,
    process.env.OPENAI_COMPAT_API_KEY,
    process.env.INVITE_TOKEN_SECRET,
    process.env.SESSION_TOKEN_SECRET,
    process.env.BYOK_ENCRYPTION_KEY,
  ].filter((v): v is string => Boolean(v && !isPlaceholderSecret(v)));

  for (const secret of secretKeys) {
    if (payloadText.includes(secret)) {
      return true;
    }
  }
  return false;
}
