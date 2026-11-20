import crypto from 'node:crypto';
import type { AuthSession, UserRole } from '../../src/types/domain.ts';

const DEFAULT_DEV_SECRET = 'dev-replace-with-32-byte-secret-in-prod';

function getSigningSecret(): string {
  return process.env.SESSION_TOKEN_SECRET || process.env.INVITE_TOKEN_SECRET || DEFAULT_DEV_SECRET;
}

export interface InvitePayload {
  poc_id: string;
  role: 'stakeholder';
  label: string;
  iat: number;
  exp: number;
}

export interface SessionPayload {
  sub: string;
  email: string;
  name: string;
  role: UserRole;
  auth_method: 'password' | 'google_identity';
  iat: number;
  exp: number;
}

function base64UrlEncode(input: Buffer | string): string {
  return Buffer.from(input)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

function base64UrlDecode(input: string): string {
  const normalized = input.replace(/-/g, '+').replace(/_/g, '/');
  const pad = normalized.length % 4 === 0 ? '' : '='.repeat(4 - (normalized.length % 4));
  return Buffer.from(normalized + pad, 'base64').toString('utf8');
}

export function hashPassword(password: string, saltHex?: string): string {
  const salt = saltHex || crypto.randomBytes(16).toString('hex');
  const derived = crypto.scryptSync(password, salt, 64).toString('hex');
  return `scrypt$${salt}$${derived}`;
}

export function verifyPassword(password: string, storedHash: string): boolean {
  const parts = storedHash.split('$');
  if (parts.length !== 3 || parts[0] !== 'scrypt') {
    return false;
  }
  const [, salt, expectedHex] = parts;
  const derived = crypto.scryptSync(password, salt, 64);
  const expected = Buffer.from(expectedHex, 'hex');
  if (derived.length !== expected.length) {
    return false;
  }
  return crypto.timingSafeEqual(derived, expected);
}

export function signSessionToken(
  user: {
    id: string;
    email: string;
    name: string;
    role: UserRole;
    auth_method: 'password' | 'google_identity';
  },
  ttlSeconds = 24 * 3600,
  nowEpochSeconds = Math.floor(Date.now() / 1000)
): { token: string; expires_at_iso: string } {
  const payload: SessionPayload = {
    sub: user.id,
    email: user.email,
    name: user.name,
    role: user.role,
    auth_method: user.auth_method,
    iat: nowEpochSeconds,
    exp: nowEpochSeconds + ttlSeconds,
  };
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const sig = crypto
    .createHmac('sha256', getSigningSecret())
    .update(`session:${encodedPayload}`)
    .digest();
  return {
    token: `${encodedPayload}.${base64UrlEncode(sig)}`,
    expires_at_iso: new Date(payload.exp * 1000).toISOString(),
  };
}

export function verifySessionToken(
  token: string,
  nowEpochSeconds = Math.floor(Date.now() / 1000)
): { valid: true; payload: SessionPayload } | { valid: false; reason: string } {
  if (!token || !token.includes('.')) {
    return { valid: false, reason: 'Malformed session token.' };
  }
  const parts = token.split('.');
  if (parts.length !== 2) {
    return { valid: false, reason: 'Invalid session token structure.' };
  }
  const [encodedPayload, providedSig] = parts;
  const expectedSig = base64UrlEncode(
    crypto
      .createHmac('sha256', getSigningSecret())
      .update(`session:${encodedPayload}`)
      .digest()
  );

  const a = Buffer.from(providedSig);
  const b = Buffer.from(expectedSig);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
    return { valid: false, reason: 'Session token signature is invalid.' };
  }

  try {
    const payload = JSON.parse(base64UrlDecode(encodedPayload)) as SessionPayload;
    if (
      !payload.sub ||
      !payload.email ||
      (payload.role !== 'engineer' && payload.role !== 'stakeholder') ||
      typeof payload.exp !== 'number'
    ) {
      return { valid: false, reason: 'Session payload is incomplete.' };
    }
    if (nowEpochSeconds >= payload.exp) {
      return { valid: false, reason: 'Session has expired. Please sign in again.' };
    }
    return { valid: true, payload };
  } catch {
    return { valid: false, reason: 'Session payload could not be parsed.' };
  }
}

export function signInviteToken(
  pocId: string,
  ttlSeconds = 7 * 24 * 3600,
  label = 'External Steering Committee Reviewer',
  nowEpochSeconds = Math.floor(Date.now() / 1000)
): { token: string; expires_at_iso: string } {
  const payload: InvitePayload = {
    poc_id: pocId,
    role: 'stakeholder',
    label,
    iat: nowEpochSeconds,
    exp: nowEpochSeconds + ttlSeconds,
  };
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const sig = crypto
    .createHmac('sha256', getSigningSecret())
    .update(encodedPayload)
    .digest();
  const token = `${encodedPayload}.${base64UrlEncode(sig)}`;
  return {
    token,
    expires_at_iso: new Date(payload.exp * 1000).toISOString(),
  };
}

export function verifyInviteToken(
  token: string,
  nowEpochSeconds = Math.floor(Date.now() / 1000)
): { valid: true; payload: InvitePayload } | { valid: false; reason: string } {
  if (!token || !token.includes('.')) {
    return { valid: false, reason: 'Malformed invite token.' };
  }
  const parts = token.split('.');
  if (parts.length !== 2) {
    return { valid: false, reason: 'Invalid invite token structure.' };
  }
  const [encodedPayload, providedSig] = parts;
  const expectedSig = base64UrlEncode(
    crypto.createHmac('sha256', getSigningSecret()).update(encodedPayload).digest()
  );

  const a = Buffer.from(providedSig);
  const b = Buffer.from(expectedSig);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
    return { valid: false, reason: 'Invite link signature is invalid.' };
  }

  try {
    const payload = JSON.parse(base64UrlDecode(encodedPayload)) as InvitePayload;
    if (!payload.poc_id || payload.role !== 'stakeholder' || typeof payload.exp !== 'number') {
      return { valid: false, reason: 'Invite payload is incomplete.' };
    }
    if (nowEpochSeconds >= payload.exp) {
      return { valid: false, reason: 'This invite link has expired.' };
    }
    return { valid: true, payload };
  } catch {
    return { valid: false, reason: 'Invite payload could not be parsed.' };
  }
}

export function parseCookieHeader(cookieHeader?: string | string[]): Record<string, string> {
  const raw = Array.isArray(cookieHeader) ? cookieHeader.join('; ') : cookieHeader || '';
  const result: Record<string, string> = {};
  for (const part of raw.split(';')) {
    const idx = part.indexOf('=');
    if (idx <= 0) continue;
    const key = part.slice(0, idx).trim();
    const val = part.slice(idx + 1).trim();
    try {
      result[key] = decodeURIComponent(val);
    } catch {
      result[key] = val;
    }
  }
  return result;
}

export function canPerformAction(
  session: AuthSession,
  action:
    | 'view_poc'
    | 'comment_or_signoff'
    | 'edit_mappings'
    | 'switch_llm_provider'
    | 'approve_drafts'
    | 'manage_workspace'
    | 'generate_invite',
  targetPocId?: string
): { allowed: boolean; reason?: string } {
  if (!session.authenticated) {
    return { allowed: false, reason: 'Authentication required. Please sign in first.' };
  }
  if (
    session.scoped_poc_id &&
    targetPocId &&
    session.scoped_poc_id !== targetPocId
  ) {
    return {
      allowed: false,
      reason: 'Invite link is scoped to a single POC and cannot access other POCs.',
    };
  }

  const engineerOnly: Set<string> = new Set([
    'edit_mappings',
    'switch_llm_provider',
    'approve_drafts',
    'manage_workspace',
    'generate_invite',
  ]);

  if (engineerOnly.has(action) && session.role !== 'engineer') {
    return {
      allowed: false,
      reason: 'Stakeholder role cannot edit mappings, change LLM providers, or approve drafts.',
    };
  }
  return { allowed: true };
}

export function resolveRequestSession(headers: Record<string, string | string[] | undefined>): AuthSession {
  // 1. Scoped single-POC invite link
  const inviteHeader = headers['x-invite-token'];
  const inviteToken = Array.isArray(inviteHeader) ? inviteHeader[0] : inviteHeader;
  if (inviteToken) {
    const check = verifyInviteToken(inviteToken);
    if (check.valid) {
      return {
        authenticated: true,
        user_name: check.payload.label,
        user_email: `invite-${check.payload.poc_id}@external.guest`,
        role: 'stakeholder',
        auth_method: 'invite_link',
        scoped_poc_id: check.payload.poc_id,
        invite_expires_at: new Date(check.payload.exp * 1000).toISOString(),
      };
    }
    return {
      authenticated: false,
      user_name: 'Expired Guest',
      user_email: '',
      role: 'stakeholder',
      auth_method: 'invite_link',
      scoped_poc_id: null,
      invite_expires_at: null,
    };
  }

  // 2. Cryptographically signed user session (Bearer Authorization header or HttpOnly cookie)
  const authHeader = Array.isArray(headers['authorization'])
    ? headers['authorization'][0]
    : headers['authorization'];
  const bearerToken =
    authHeader && authHeader.toLowerCase().startsWith('bearer ')
      ? authHeader.slice(7).trim()
      : undefined;
  const cookies = parseCookieHeader(headers['cookie']);
  const sessionToken = bearerToken || cookies['pp_session'];

  if (sessionToken) {
    const verified = verifySessionToken(sessionToken);
    if (verified.valid) {
      return {
        authenticated: true,
        user_id: verified.payload.sub,
        user_name: verified.payload.name,
        user_email: verified.payload.email,
        role: verified.payload.role,
        auth_method: verified.payload.auth_method,
        scoped_poc_id: null,
        invite_expires_at: null,
      };
    }
    return {
      authenticated: false,
      user_name: 'Session Expired',
      user_email: '',
      role: 'stakeholder',
      auth_method: 'none',
      scoped_poc_id: null,
      invite_expires_at: null,
    };
  }

  // 3. Explicit test/header override (used by automated API contract tests)
  const roleHeader = headers['x-demo-role'];
  const rawRole = Array.isArray(roleHeader) ? roleHeader[0] : roleHeader;
  const emailHeader = headers['x-user-email'];
  const rawEmail = Array.isArray(emailHeader) ? emailHeader[0] : emailHeader;

  if (rawRole === 'engineer' || rawRole === 'stakeholder') {
    return {
      authenticated: true,
      user_id: rawRole === 'engineer' ? 'usr-priya' : 'usr-claire',
      user_name:
        rawRole === 'engineer'
          ? 'Priya Nair (Lead Cloud Engineer)'
          : 'Claire Bennett (VP Operations)',
      user_email:
        rawEmail ||
        (rawRole === 'engineer'
          ? 'priya.nair@acme-retail.example'
          : 'claire.bennett@acme-retail.example'),
      role: rawRole,
      auth_method: 'demo_session',
      scoped_poc_id: null,
      invite_expires_at: null,
    };
  }

  // 4. Default: unauthenticated (no anonymous access)
  return {
    authenticated: false,
    user_name: 'Anonymous',
    user_email: '',
    role: 'stakeholder',
    auth_method: 'none',
    scoped_poc_id: null,
    invite_expires_at: null,
  };
}
