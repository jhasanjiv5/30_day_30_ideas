import type {
  AuthSession,
  CompareResult,
  MappingDraftBatch,
  MappingDraftItem,
  POC,
  ProjectHistoryAction,
  ProjectHistoryEntry,
  ProviderCatalogItem,
  SignOffDecision,
  UserAccountPublic,
  UserRecentPocSummary,
  UserRole,
  WhatIfParams,
  WhatIfProjection,
} from '../types/domain.ts';

export interface ClientAuthHeaders {
  role?: UserRole;
  sessionToken?: string | null;
  inviteToken?: string | null;
}

function buildHeaders(auth: ClientAuthHeaders): Record<string, string> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };
  if (auth.inviteToken) {
    headers['x-invite-token'] = auth.inviteToken;
  } else if (auth.sessionToken) {
    headers['Authorization'] = `Bearer ${auth.sessionToken}`;
  } else if (auth.role) {
    headers['x-demo-role'] = auth.role;
  }
  return headers;
}

async function apiFetch<T>(
  url: string,
  auth: ClientAuthHeaders,
  init?: RequestInit
): Promise<T> {
  const res = await fetch(url, {
    ...init,
    credentials: 'include',
    headers: {
      ...buildHeaders(auth),
      ...(init?.headers ?? {}),
    },
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error((data as { error?: string }).error || `Request failed (${res.status})`);
  }
  return data as T;
}

export interface AuthResponse {
  token: string;
  expires_at_iso: string;
  user: UserAccountPublic;
  session: AuthSession;
}

export async function loginApi(email: string, password: string): Promise<AuthResponse> {
  return apiFetch<AuthResponse>('/api/auth/login', {}, {
    method: 'POST',
    body: JSON.stringify({ email, password }),
  });
}

export async function registerApi(
  name: string,
  email: string,
  password: string,
  role: UserRole
): Promise<AuthResponse> {
  return apiFetch<AuthResponse>('/api/auth/register', {}, {
    method: 'POST',
    body: JSON.stringify({ name, email, password, role }),
  });
}

export async function googleSignInApi(
  email: string,
  name: string,
  role: UserRole
): Promise<AuthResponse> {
  return apiFetch<AuthResponse>('/api/auth/google', {}, {
    method: 'POST',
    body: JSON.stringify({ email, name, role }),
  });
}

export async function logoutApi(auth: ClientAuthHeaders): Promise<void> {
  await apiFetch<{ logged_out: boolean }>('/api/auth/logout', auth, {
    method: 'POST',
  });
}

export async function fetchSession(auth: ClientAuthHeaders): Promise<AuthSession> {
  const qs = auth.inviteToken ? `?invite=${encodeURIComponent(auth.inviteToken)}` : '';
  return apiFetch<AuthSession>(`/api/session${qs}`, auth);
}

export async function fetchUserHistoryApi(auth: ClientAuthHeaders): Promise<{
  history: ProjectHistoryEntry[];
  recent_pocs: UserRecentPocSummary[];
}> {
  return apiFetch('/api/history', auth);
}

export async function recordUserHistoryApi(
  payload: {
    poc_id: string;
    action: ProjectHistoryAction;
    summary: string;
    tab?: string;
  },
  auth: ClientAuthHeaders
): Promise<ProjectHistoryEntry | null> {
  const res = await apiFetch<{ entry: ProjectHistoryEntry | null }>('/api/history', auth, {
    method: 'POST',
    body: JSON.stringify(payload),
  });
  return res.entry;
}

export async function clearUserHistoryApi(auth: ClientAuthHeaders): Promise<void> {
  await apiFetch<{ cleared: boolean }>('/api/history', auth, {
    method: 'DELETE',
  });
}

export async function fetchPocs(auth: ClientAuthHeaders): Promise<POC[]> {
  const res = await apiFetch<{ pocs: POC[] }>('/api/pocs', auth);
  return res.pocs;
}

export interface CreatePocPayload {
  name: string;
  business_summary: string;
  owner_name: string;
  project_id: string;
  primary_region: string;
  data_policy: 'eu_only' | 'global';
  service_url?: string;
  budget_cap_usd: number;
  teardown_days: number;
  selected_llm_provider: string;
  terraform_state_json?: string;
  requirements_text?: string;
}

export async function createPocApi(
  payload: CreatePocPayload,
  auth: ClientAuthHeaders
): Promise<POC> {
  const res = await apiFetch<{ poc: POC }>('/api/pocs', auth, {
    method: 'POST',
    body: JSON.stringify(payload),
  });
  return res.poc;
}

export async function simulateWhatIfApi(
  pocId: string,
  params: WhatIfParams,
  auth: ClientAuthHeaders
): Promise<WhatIfProjection> {
  return apiFetch<WhatIfProjection>(`/api/pocs/${pocId}/whatif`, auth, {
    method: 'POST',
    body: JSON.stringify(params),
  });
}

export async function submitSignOffApi(
  pocId: string,
  payload: { requirement_id: string; decision: SignOffDecision; note: string },
  auth: ClientAuthHeaders
): Promise<POC> {
  const res = await apiFetch<{ poc: POC }>(`/api/pocs/${pocId}/signoffs`, auth, {
    method: 'POST',
    body: JSON.stringify(payload),
  });
  return res.poc;
}

export async function submitCommentApi(
  pocId: string,
  payload: { requirement_id: string; body: string },
  auth: ClientAuthHeaders
): Promise<POC> {
  const res = await apiFetch<{ poc: POC }>(`/api/pocs/${pocId}/comments`, auth, {
    method: 'POST',
    body: JSON.stringify(payload),
  });
  return res.poc;
}

export async function recheckPocApi(pocId: string, auth: ClientAuthHeaders): Promise<POC> {
  const res = await apiFetch<{ poc: POC }>(`/api/pocs/${pocId}/recheck`, auth, {
    method: 'POST',
  });
  return res.poc;
}

export async function fetchLlmProvidersApi(
  pocId: string,
  auth: ClientAuthHeaders
): Promise<{
  selected_provider: string;
  fallback_chain: string[];
  providers: ProviderCatalogItem[];
}> {
  return apiFetch(`/api/pocs/${pocId}/llm/providers`, auth);
}

export async function switchLlmProviderApi(
  pocId: string,
  providerId: string,
  auth: ClientAuthHeaders
): Promise<{ selected_provider: string; providers: ProviderCatalogItem[] }> {
  return apiFetch(`/api/pocs/${pocId}/llm/provider`, auth, {
    method: 'PUT',
    body: JSON.stringify({ provider_id: providerId }),
  });
}

export async function draftMappingsApi(
  pocId: string,
  requirementsText: string,
  providerId: string,
  auth: ClientAuthHeaders,
  simulateFailureProvider?: string
): Promise<{ batch: MappingDraftBatch; poc: POC }> {
  return apiFetch(`/api/pocs/${pocId}/llm/draft`, auth, {
    method: 'POST',
    body: JSON.stringify({
      requirements_text: requirementsText,
      provider_id: providerId,
      simulate_failure_provider: simulateFailureProvider,
    }),
  });
}

export async function compareLlmProvidersApi(
  pocId: string,
  leftProvider: string,
  rightProvider: string,
  requirementsText: string,
  auth: ClientAuthHeaders
): Promise<CompareResult> {
  return apiFetch(`/api/pocs/${pocId}/llm/compare`, auth, {
    method: 'POST',
    body: JSON.stringify({
      left_provider: leftProvider,
      right_provider: rightProvider,
      requirements_text: requirementsText,
    }),
  });
}

export async function approveDraftApi(
  pocId: string,
  batchId: string,
  items: MappingDraftItem[],
  auth: ClientAuthHeaders
): Promise<POC> {
  const res = await apiFetch<{ poc: POC }>(
    `/api/pocs/${pocId}/llm/drafts/${batchId}/approve`,
    auth,
    {
      method: 'POST',
      body: JSON.stringify({ items }),
    }
  );
  return res.poc;
}

export async function rejectDraftApi(
  pocId: string,
  batchId: string,
  auth: ClientAuthHeaders
): Promise<POC> {
  const res = await apiFetch<{ poc: POC }>(
    `/api/pocs/${pocId}/llm/drafts/${batchId}/reject`,
    auth,
    { method: 'POST' }
  );
  return res.poc;
}

export async function addManualRequirementApi(
  pocId: string,
  payload: {
    title: string;
    category: string;
    check_type: string;
    threshold: string;
    in_scope: boolean;
  },
  auth: ClientAuthHeaders
): Promise<POC> {
  const res = await apiFetch<{ poc: POC }>(
    `/api/pocs/${pocId}/requirements/manual`,
    auth,
    {
      method: 'POST',
      body: JSON.stringify(payload),
    }
  );
  return res.poc;
}

export async function toggleWorkspaceProviderApi(
  providerId: string,
  enabled: boolean,
  auth: ClientAuthHeaders
): Promise<{ disabled_providers: string[] }> {
  return apiFetch(`/api/workspace/providers/${providerId}/toggle`, auth, {
    method: 'PUT',
    body: JSON.stringify({ enabled }),
  });
}

export async function createInviteLinkApi(
  pocId: string,
  ttlHours: number,
  label: string,
  auth: ClientAuthHeaders
): Promise<{ poc_id: string; token: string; expires_at_iso: string; invite_url: string }> {
  return apiFetch(`/api/pocs/${pocId}/invites`, auth, {
    method: 'POST',
    body: JSON.stringify({ ttl_hours: ttlHours, label }),
  });
}
