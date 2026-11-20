import 'dotenv/config';
import express, { type NextFunction, type Request, type Response } from 'express';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { createServer as createViteServer } from 'vite';
import type {
  AuthSession,
  POC,
  ProjectHistoryAction,
  Requirement,
  SignOffDecision,
  UserRole,
} from './src/types/domain.ts';
import {
  canPerformAction,
  hashPassword,
  resolveRequestSession,
  signInviteToken,
  signSessionToken,
  verifyInviteToken,
  verifyPassword,
} from './server/domain/auth.ts';
import { evaluateAllChecks } from './server/domain/checks.ts';
import {
  encryptWorkspaceKey,
  LLMProviderRegistry,
  parseRequirementsDeterministically,
} from './server/domain/llm.ts';
import {
  buildPocFromInput,
  createEnvironmentProvider,
} from './server/domain/providers.ts';
import {
  AppStore,
  containsSecretLeak,
  toPublicUser,
  type StoredUserAccount,
} from './server/domain/store.ts';
import { simulateWhatIf } from './server/domain/whatif.ts';

function sanitizePocForRole(poc: POC, role: 'engineer' | 'stakeholder'): POC {
  if (role === 'engineer') {
    return poc;
  }
  // Stakeholders NEVER see unapproved LLM drafts or raw LLM prompt/model controls
  return {
    ...poc,
    requirements: poc.requirements.filter((r) => r.approved_by_engineer),
    pending_drafts: [],
  };
}

export async function createApp(httpServer?: http.Server) {
  const app = express();
  app.use(express.json({ limit: '1mb' }));

  const store = new AppStore();
  await store.init();
  const envProvider = createEnvironmentProvider();
  const llmRegistry = new LLMProviderRegistry();

  // Security middleware: ensure no server-side secret ever leaks into HTTP JSON responses
  app.use((_req: Request, res: Response, next: NextFunction) => {
    const origJson = res.json.bind(res);
    res.json = (body: unknown) => {
      const serialized = JSON.stringify(body);
      if (containsSecretLeak(serialized)) {
        return res.status(500).json({ error: 'Blocked unsafe secret serialization' });
      }
      return origJson(body);
    };
    next();
  });

  const setSessionCookie = (res: Response, token: string) => {
    res.setHeader(
      'Set-Cookie',
      `pp_session=${encodeURIComponent(token)}; Path=/; HttpOnly; SameSite=Lax; Max-Age=${24 * 3600}`
    );
  };

  const buildSessionForUser = (user: StoredUserAccount): AuthSession => ({
    authenticated: true,
    user_id: user.id,
    user_name: user.name,
    user_email: user.email,
    role: user.role,
    auth_method: user.auth_provider,
    scoped_poc_id: null,
    invite_expires_at: null,
  });

  app.get('/api/health', (_req, res) => {
    res.json({
      status: 'ok',
      environment_provider: envProvider.name,
      timestamp: new Date().toISOString(),
    });
  });

  // --- User Sign-In, Registration, Google Sign-In & Logout ---
  app.post('/api/auth/register', (req, res) => {
    const name = String(req.body?.name || '').trim();
    const email = String(req.body?.email || '').trim().toLowerCase();
    const password = String(req.body?.password || '');
    const role: UserRole = req.body?.role === 'engineer' ? 'engineer' : 'stakeholder';

    if (!name || name.length < 2) {
      return res.status(400).json({ error: 'Full name must be at least 2 characters.' });
    }
    if (!email || !email.includes('@')) {
      return res.status(400).json({ error: 'Please enter a valid work email address.' });
    }
    if (password.length < 8) {
      return res.status(400).json({ error: 'Password must be at least 8 characters.' });
    }
    if (store.findUserByEmail(email)) {
      return res.status(409).json({ error: 'An account with this email already exists. Please sign in.' });
    }

    const now = new Date().toISOString();
    const newUser: StoredUserAccount = {
      id: `usr-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
      name,
      email,
      role,
      auth_provider: 'password',
      password_hash: hashPassword(password),
      created_at: now,
      last_login_at: now,
    };

    const state = store.getState();
    state.users.push(newUser);
    store.persist();

    const { token, expires_at_iso } = signSessionToken({
      id: newUser.id,
      email: newUser.email,
      name: newUser.name,
      role: newUser.role,
      auth_method: 'password',
    });
    setSessionCookie(res, token);
    res.status(201).json({
      token,
      expires_at_iso,
      user: toPublicUser(newUser),
      session: buildSessionForUser(newUser),
    });
  });

  app.post('/api/auth/login', (req, res) => {
    const email = String(req.body?.email || '').trim().toLowerCase();
    const password = String(req.body?.password || '');

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required.' });
    }

    const user = store.findUserByEmail(email);
    if (!user || !user.password_hash || !verifyPassword(password, user.password_hash)) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    user.last_login_at = new Date().toISOString();
    store.persist();

    const { token, expires_at_iso } = signSessionToken({
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      auth_method: 'password',
    });
    setSessionCookie(res, token);
    res.json({
      token,
      expires_at_iso,
      user: toPublicUser(user),
      session: buildSessionForUser(user),
    });
  });

  app.post('/api/auth/google', (req, res) => {
    const email = String(req.body?.email || '').trim().toLowerCase();
    const name = String(req.body?.name || '').trim();
    const requestedRole: UserRole = req.body?.role === 'engineer' ? 'engineer' : 'stakeholder';

    if (!email || !email.includes('@')) {
      return res.status(400).json({ error: 'Valid Google Workspace email is required.' });
    }

    const now = new Date().toISOString();
    let user = store.findUserByEmail(email);
    if (!user) {
      user = {
        id: `usr-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
        name: name || email.split('@')[0],
        email,
        role: requestedRole,
        auth_provider: 'google_identity',
        created_at: now,
        last_login_at: now,
      };
      store.getState().users.push(user);
    } else {
      user.last_login_at = now;
    }
    store.persist();

    const { token, expires_at_iso } = signSessionToken({
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      auth_method: 'google_identity',
    });
    setSessionCookie(res, token);
    res.json({
      token,
      expires_at_iso,
      user: toPublicUser(user),
      session: buildSessionForUser(user),
    });
  });

  app.post('/api/auth/logout', (_req, res) => {
    res.setHeader('Set-Cookie', 'pp_session=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0');
    res.json({ logged_out: true });
  });

  app.get('/api/session', (req, res) => {
    const inviteQuery = typeof req.query.invite === 'string' ? req.query.invite : undefined;
    const headers = { ...req.headers };
    if (inviteQuery && !headers['x-invite-token']) {
      headers['x-invite-token'] = inviteQuery;
    }
    const inviteToken = Array.isArray(headers['x-invite-token'])
      ? headers['x-invite-token'][0]
      : headers['x-invite-token'];

    if (inviteToken) {
      const check = verifyInviteToken(inviteToken);
      if (!check.valid) {
        return res.status(401).json({
          authenticated: false,
          error: check.reason,
        });
      }
    }

    const session = resolveRequestSession(headers);
    res.json(session);
  });

  // --- Per-User Project History ---
  app.get('/api/history', (req, res) => {
    const session = resolveRequestSession(req.headers);
    if (!session.authenticated) {
      return res.status(401).json({ error: 'Authentication required to view project history.' });
    }
    const data = store.getUserHistory(session.user_email, session.scoped_poc_id);
    res.json(data);
  });

  app.post('/api/history', (req, res) => {
    const session = resolveRequestSession(req.headers);
    if (!session.authenticated) {
      return res.status(401).json({ error: 'Authentication required to record history.' });
    }
    const pocId = String(req.body?.poc_id || '').trim();
    const action = String(req.body?.action || 'viewed') as ProjectHistoryAction;
    const summary = String(req.body?.summary || 'Opened project view').trim();
    const tab = req.body?.tab ? String(req.body.tab) : undefined;

    if (!pocId) {
      return res.status(400).json({ error: 'poc_id is required.' });
    }
    const perm = canPerformAction(session, 'view_poc', pocId);
    if (!perm.allowed) {
      return res.status(403).json({ error: perm.reason });
    }
    const poc = store.getPoc(pocId);
    if (!poc) {
      return res.status(404).json({ error: 'POC not found.' });
    }

    const entry = store.recordUserHistory({
      session,
      poc_id: poc.id,
      poc_name: poc.name,
      action,
      summary,
      tab,
    });
    res.status(201).json({ entry });
  });

  app.delete('/api/history', (req, res) => {
    const session = resolveRequestSession(req.headers);
    if (!session.authenticated) {
      return res.status(401).json({ error: 'Authentication required.' });
    }
    const email = session.user_email.toLowerCase();
    const state = store.getState();
    state.history = state.history.filter((h) => h.user_email.toLowerCase() !== email);
    store.persist();
    res.json({ cleared: true });
  });

  app.get('/api/pocs', (req, res) => {
    const session = resolveRequestSession(req.headers);
    const perm = canPerformAction(session, 'view_poc');
    if (!perm.allowed) {
      return res.status(401).json({ error: perm.reason });
    }
    const state = store.getState();
    const visible = state.pocs
      .filter((p) => !session.scoped_poc_id || p.id === session.scoped_poc_id)
      .map((p) => sanitizePocForRole(p, session.role));

    res.json({ pocs: visible });
  });

  app.post('/api/pocs', async (req, res) => {
    const session = resolveRequestSession(req.headers);
    const perm = canPerformAction(session, 'edit_mappings');
    if (!perm.allowed) {
      return res.status(session.authenticated ? 403 : 401).json({ error: perm.reason });
    }

    const {
      name,
      business_summary,
      owner_name,
      project_id,
      primary_region = 'europe-west1',
      data_policy = 'eu_only',
      service_url,
      budget_cap_usd = 450,
      teardown_days = 7,
      selected_llm_provider = 'none',
      terraform_state_json,
      requirements_text,
    } = req.body ?? {};

    if (!name || !String(name).trim() || !business_summary || !String(business_summary).trim()) {
      return res.status(400).json({ error: 'POC name and plain-language summary are required.' });
    }

    const parsedManualReqs: Requirement[] | undefined =
      requirements_text && String(requirements_text).trim() && selected_llm_provider === 'none'
        ? parseRequirementsDeterministically(String(requirements_text)).map((item) => ({
            id: item.id,
            title: item.title,
            category: item.category,
            check_type: item.check_type,
            threshold: item.threshold,
            in_scope: item.in_scope,
            approved_by_engineer: true,
            source_provider: 'none',
          }))
        : undefined;

    const newPoc = buildPocFromInput({
      name: String(name).trim(),
      business_summary: String(business_summary).trim(),
      owner_name: String(owner_name || session.user_name),
      project_id: String(project_id || ''),
      primary_region: String(primary_region),
      data_policy: data_policy === 'global' ? 'global' : 'eu_only',
      service_url: service_url ? String(service_url) : undefined,
      budget_cap_usd: Number(budget_cap_usd),
      teardown_days: Number(teardown_days),
      selected_llm_provider: String(selected_llm_provider),
      terraform_state_json: terraform_state_json ? String(terraform_state_json) : undefined,
      requirements: parsedManualReqs,
    });

    const state = store.getState();

    // If an LLM provider was chosen with pasted requirements text, stage the draft for engineer approval
    if (
      requirements_text &&
      String(requirements_text).trim() &&
      newPoc.selected_llm_provider !== 'none'
    ) {
      try {
        const batch = await llmRegistry.draftWithReliability({
          poc: newPoc,
          requestedProviderId: newPoc.selected_llm_provider,
          requirementsText: String(requirements_text),
          disabledInWorkspace: state.disabled_providers,
          encryptedByokMap: state.encrypted_byok_keys,
        });
        newPoc.pending_drafts.unshift(batch);
        newPoc.audit_log.unshift(batch.audit);
      } catch (err) {
        return res.status(403).json({
          error: err instanceof Error ? err.message : 'Selected LLM provider failed policy check.',
        });
      }
    }

    state.pocs.unshift(newPoc);
    store.recordUserHistory({
      session,
      poc_id: newPoc.id,
      poc_name: newPoc.name,
      action: 'created_poc',
      summary: `Created POC environment in ${newPoc.environment.region_display}`,
      tab: newPoc.pending_drafts.length > 0 ? 'console' : 'scorecard',
    });
    res.status(201).json({ poc: newPoc });
  });

  app.get('/api/pocs/:pocId', (req, res) => {
    const session = resolveRequestSession(req.headers);
    const perm = canPerformAction(session, 'view_poc', req.params.pocId);
    if (!perm.allowed) {
      return res.status(session.authenticated ? 403 : 401).json({ error: perm.reason });
    }
    const poc = store.getPoc(req.params.pocId);
    if (!poc) {
      return res.status(404).json({ error: 'POC not found' });
    }
    res.json({ poc: sanitizePocForRole(poc, session.role) });
  });

  app.post('/api/pocs/:pocId/recheck', async (req, res) => {
    const session = resolveRequestSession(req.headers);
    const perm = canPerformAction(session, 'edit_mappings', req.params.pocId);
    if (!perm.allowed) {
      return res.status(session.authenticated ? 403 : 401).json({ error: perm.reason });
    }
    const poc = store.getPoc(req.params.pocId);
    if (!poc) return res.status(404).json({ error: 'POC not found' });

    try {
      poc.environment = await envProvider.refreshEnvironment(poc);
      poc.checks = evaluateAllChecks(poc.requirements, poc.environment);
      store.recordUserHistory({
        session,
        poc_id: poc.id,
        poc_name: poc.name,
        action: 'rechecked',
        summary: `Triggered live check refresh via ${poc.environment.provider_name}`,
        tab: 'console',
      });
      res.json({ poc });
    } catch (err) {
      res.status(502).json({
        error: err instanceof Error ? err.message : 'Failed to refresh environment checks',
      });
    }
  });

  app.post('/api/pocs/:pocId/whatif', (req, res) => {
    const session = resolveRequestSession(req.headers);
    const perm = canPerformAction(session, 'view_poc', req.params.pocId);
    if (!perm.allowed) {
      return res.status(session.authenticated ? 403 : 401).json({ error: perm.reason });
    }
    const poc = store.getPoc(req.params.pocId);
    if (!poc) return res.status(404).json({ error: 'POC not found' });

    const { users_multiplier = 1, traffic_spike = 1, region_outage = false } = req.body ?? {};
    const parsedParams = {
      users_multiplier: Number(users_multiplier),
      traffic_spike: Number(traffic_spike),
      region_outage: Boolean(region_outage),
    };
    const projection = simulateWhatIf(poc.environment, parsedParams);
    if (
      parsedParams.users_multiplier !== 1 ||
      parsedParams.traffic_spike !== 1 ||
      parsedParams.region_outage
    ) {
      store.recordUserHistory({
        session,
        poc_id: poc.id,
        poc_name: poc.name,
        action: 'ran_whatif',
        summary: `Simulated ×${parsedParams.users_multiplier} users, ×${parsedParams.traffic_spike} burst${parsedParams.region_outage ? ' + region outage' : ''}`,
        tab: 'whatif',
      });
    }
    res.json(projection);
  });

  app.post('/api/pocs/:pocId/signoffs', (req, res) => {
    const session = resolveRequestSession(req.headers);
    const perm = canPerformAction(session, 'comment_or_signoff', req.params.pocId);
    if (!perm.allowed) {
      return res.status(session.authenticated ? 403 : 401).json({ error: perm.reason });
    }
    const poc = store.getPoc(req.params.pocId);
    if (!poc) return res.status(404).json({ error: 'POC not found' });

    const { requirement_id, decision, note = '' } = req.body ?? {};
    if (!requirement_id || !['approved', 'changes_requested', 'pending'].includes(decision)) {
      return res.status(400).json({ error: 'Invalid requirement_id or decision' });
    }

    const existingIdx = poc.sign_offs.findIndex(
      (s) => s.requirement_id === requirement_id && s.reviewer_email === session.user_email
    );
    const record = {
      id: existingIdx >= 0 ? poc.sign_offs[existingIdx].id : `so-${Date.now()}`,
      poc_id: poc.id,
      requirement_id: String(requirement_id),
      decision: decision as SignOffDecision,
      reviewer_name: session.user_name,
      reviewer_email: session.user_email,
      reviewer_role: session.role,
      note: String(note).slice(0, 500),
      updated_at: new Date().toISOString(),
    };
    if (existingIdx >= 0) {
      poc.sign_offs[existingIdx] = record;
    } else {
      poc.sign_offs.push(record);
    }
    store.recordUserHistory({
      session,
      poc_id: poc.id,
      poc_name: poc.name,
      action: 'signed_off',
      summary: `${decision === 'approved' ? 'Approved' : 'Requested changes on'} ${record.requirement_id}`,
      tab: 'signoff',
    });
    res.json({ sign_off: record, poc: sanitizePocForRole(poc, session.role) });
  });

  app.post('/api/pocs/:pocId/comments', (req, res) => {
    const session = resolveRequestSession(req.headers);
    const perm = canPerformAction(session, 'comment_or_signoff', req.params.pocId);
    if (!perm.allowed) {
      return res.status(session.authenticated ? 403 : 401).json({ error: perm.reason });
    }
    const poc = store.getPoc(req.params.pocId);
    if (!poc) return res.status(404).json({ error: 'POC not found' });

    const { requirement_id, body } = req.body ?? {};
    if (!requirement_id || !body || !String(body).trim()) {
      return res.status(400).json({ error: 'Comment body and requirement_id are required' });
    }

    const comment = {
      id: `cmt-${Date.now()}`,
      poc_id: poc.id,
      requirement_id: String(requirement_id),
      author_name: session.user_name,
      author_role: session.role,
      body: String(body).trim().slice(0, 1000),
      created_at: new Date().toISOString(),
    };
    poc.comments.push(comment);
    store.recordUserHistory({
      session,
      poc_id: poc.id,
      poc_name: poc.name,
      action: 'commented',
      summary: `Commented on ${comment.requirement_id}`,
      tab: 'signoff',
    });
    res.status(201).json({ comment, poc: sanitizePocForRole(poc, session.role) });
  });

  // --- Engineer-Only LLM Provider & Mapping Console Routes ---
  app.get('/api/pocs/:pocId/llm/providers', (req, res) => {
    const session = resolveRequestSession(req.headers);
    const perm = canPerformAction(session, 'switch_llm_provider', req.params.pocId);
    if (!perm.allowed) {
      return res.status(session.authenticated ? 403 : 401).json({ error: perm.reason });
    }
    const poc = store.getPoc(req.params.pocId);
    if (!poc) return res.status(404).json({ error: 'POC not found' });

    const state = store.getState();
    const providers = llmRegistry.listCatalogForPoc(
      poc,
      state.disabled_providers,
      state.encrypted_byok_keys
    );
    res.json({
      selected_provider: poc.selected_llm_provider,
      fallback_chain: llmRegistry.getFallbackChain(),
      providers,
    });
  });

  app.put('/api/pocs/:pocId/llm/provider', (req, res) => {
    const session = resolveRequestSession(req.headers);
    const perm = canPerformAction(session, 'switch_llm_provider', req.params.pocId);
    if (!perm.allowed) {
      return res.status(session.authenticated ? 403 : 401).json({ error: perm.reason });
    }
    const poc = store.getPoc(req.params.pocId);
    if (!poc) return res.status(404).json({ error: 'POC not found' });

    const providerId = String(req.body?.provider_id || '');
    const state = store.getState();
    try {
      llmRegistry.assertProviderAllowed(providerId, poc, state.disabled_providers);
      poc.selected_llm_provider = providerId;
      store.persist();
      res.json({
        selected_provider: poc.selected_llm_provider,
        providers: llmRegistry.listCatalogForPoc(
          poc,
          state.disabled_providers,
          state.encrypted_byok_keys
        ),
      });
    } catch (err) {
      res.status(403).json({
        error: err instanceof Error ? err.message : 'Provider blocked by workspace or POC policy',
      });
    }
  });

  app.post('/api/pocs/:pocId/llm/draft', async (req, res) => {
    const session = resolveRequestSession(req.headers);
    const perm = canPerformAction(session, 'edit_mappings', req.params.pocId);
    if (!perm.allowed) {
      return res.status(session.authenticated ? 403 : 401).json({ error: perm.reason });
    }
    const poc = store.getPoc(req.params.pocId);
    if (!poc) return res.status(404).json({ error: 'POC not found' });

    const requirementsText = String(req.body?.requirements_text || '').trim();
    if (!requirementsText) {
      return res.status(400).json({ error: 'requirements_text is required' });
    }

    const requestedProvider = String(req.body?.provider_id || poc.selected_llm_provider);
    const simulateFailureProvider =
      typeof req.body?.simulate_failure_provider === 'string'
        ? req.body.simulate_failure_provider
        : undefined;

    const state = store.getState();
    try {
      const batch = await llmRegistry.draftWithReliability({
        poc,
        requestedProviderId: requestedProvider,
        requirementsText,
        disabledInWorkspace: state.disabled_providers,
        encryptedByokMap: state.encrypted_byok_keys,
        simulateFailureProvider,
      });
      poc.pending_drafts.unshift(batch);
      poc.audit_log.unshift(batch.audit);
      store.recordUserHistory({
        session,
        poc_id: poc.id,
        poc_name: poc.name,
        action: 'drafted_mapping',
        summary: `Drafted ${batch.items.length} mapping(s) with ${batch.audit.answered_by_provider}`,
        tab: 'console',
      });
      res.status(201).json({ batch, poc });
    } catch (err) {
      res.status(403).json({
        error: err instanceof Error ? err.message : 'Draft failed',
      });
    }
  });

  app.post('/api/pocs/:pocId/llm/compare', async (req, res) => {
    const session = resolveRequestSession(req.headers);
    const perm = canPerformAction(session, 'edit_mappings', req.params.pocId);
    if (!perm.allowed) {
      return res.status(session.authenticated ? 403 : 401).json({ error: perm.reason });
    }
    const poc = store.getPoc(req.params.pocId);
    if (!poc) return res.status(404).json({ error: 'POC not found' });

    const requirementsText = String(req.body?.requirements_text || '').trim();
    const leftProviderId = String(req.body?.left_provider || 'vertex_gemini');
    const rightProviderId = String(req.body?.right_provider || 'azure_openai');
    if (!requirementsText) {
      return res.status(400).json({ error: 'requirements_text is required' });
    }

    const state = store.getState();
    try {
      const comparison = await llmRegistry.compareProviders({
        poc,
        leftProviderId,
        rightProviderId,
        requirementsText,
        disabledInWorkspace: state.disabled_providers,
        encryptedByokMap: state.encrypted_byok_keys,
      });
      res.json(comparison);
    } catch (err) {
      res.status(403).json({
        error: err instanceof Error ? err.message : 'Compare failed',
      });
    }
  });

  app.post('/api/pocs/:pocId/llm/drafts/:batchId/approve', (req, res) => {
    const session = resolveRequestSession(req.headers);
    const perm = canPerformAction(session, 'approve_drafts', req.params.pocId);
    if (!perm.allowed) {
      return res.status(session.authenticated ? 403 : 401).json({ error: perm.reason });
    }
    const poc = store.getPoc(req.params.pocId);
    if (!poc) return res.status(404).json({ error: 'POC not found' });

    const batch = poc.pending_drafts.find((d) => d.id === req.params.batchId);
    if (!batch) return res.status(404).json({ error: 'Draft batch not found' });

    const overrideItems = Array.isArray(req.body?.items) ? req.body.items : batch.items;
    const newReqs: Requirement[] = overrideItems.map((item: any) => ({
      id: String(item.id),
      title: String(item.title),
      category: item.category,
      check_type: item.check_type,
      threshold: String(item.threshold),
      in_scope: Boolean(item.in_scope),
      approved_by_engineer: true,
      source_provider: batch.audit.answered_by_provider,
    }));

    // Merge approved requirements (replace same ID or append)
    for (const nr of newReqs) {
      const idx = poc.requirements.findIndex((r) => r.id === nr.id);
      if (idx >= 0) {
        poc.requirements[idx] = nr;
      } else {
        poc.requirements.push(nr);
      }
    }

    batch.status = 'approved';
    batch.audit.approved = true;
    const aud = poc.audit_log.find((a) => a.id === batch.audit.id);
    if (aud) aud.approved = true;
    poc.pending_drafts = poc.pending_drafts.filter((d) => d.id !== batch.id);
    poc.checks = evaluateAllChecks(poc.requirements, poc.environment);
    store.recordUserHistory({
      session,
      poc_id: poc.id,
      poc_name: poc.name,
      action: 'approved_mapping',
      summary: `Approved ${newReqs.length} requirement mapping(s) for stakeholder view`,
      tab: 'console',
    });
    res.json({ poc });
  });

  app.post('/api/pocs/:pocId/llm/drafts/:batchId/reject', (req, res) => {
    const session = resolveRequestSession(req.headers);
    const perm = canPerformAction(session, 'approve_drafts', req.params.pocId);
    if (!perm.allowed) {
      return res.status(session.authenticated ? 403 : 401).json({ error: perm.reason });
    }
    const poc = store.getPoc(req.params.pocId);
    if (!poc) return res.status(404).json({ error: 'POC not found' });

    poc.pending_drafts = poc.pending_drafts.filter((d) => d.id !== req.params.batchId);
    store.persist();
    res.json({ poc });
  });

  app.post('/api/pocs/:pocId/requirements/manual', (req, res) => {
    const session = resolveRequestSession(req.headers);
    const perm = canPerformAction(session, 'edit_mappings', req.params.pocId);
    if (!perm.allowed) {
      return res.status(session.authenticated ? 403 : 401).json({ error: perm.reason });
    }
    const poc = store.getPoc(req.params.pocId);
    if (!poc) return res.status(404).json({ error: 'POC not found' });

    const { id, title, category, check_type, threshold, in_scope = true } = req.body ?? {};
    if (!title || !check_type || !threshold) {
      return res.status(400).json({ error: 'title, check_type, and threshold are required' });
    }

    const newReq: Requirement = {
      id: String(id || `REQ-M${poc.requirements.length + 1}`),
      title: String(title),
      category: category || 'Performance',
      check_type,
      threshold: String(threshold),
      in_scope: Boolean(in_scope),
      approved_by_engineer: true,
      source_provider: 'none',
    };

    poc.requirements.push(newReq);
    poc.checks = evaluateAllChecks(poc.requirements, poc.environment);
    store.persist();
    res.status(201).json({ requirement: newReq, poc });
  });

  app.put('/api/workspace/providers/:providerId/toggle', (req, res) => {
    const session = resolveRequestSession(req.headers);
    const perm = canPerformAction(session, 'manage_workspace');
    if (!perm.allowed) {
      return res.status(session.authenticated ? 403 : 401).json({ error: perm.reason });
    }
    const providerId = req.params.providerId;
    if (providerId === 'none') {
      return res.status(400).json({ error: 'Manual mapping ("none") cannot be disabled.' });
    }
    const enabled = Boolean(req.body?.enabled);
    const state = store.getState();
    if (enabled) {
      state.disabled_providers = state.disabled_providers.filter((id) => id !== providerId);
    } else if (!state.disabled_providers.includes(providerId)) {
      state.disabled_providers.push(providerId);
    }
    store.persist();
    res.json({ disabled_providers: state.disabled_providers });
  });

  app.get('/api/workspace/keys', (req, res) => {
    const session = resolveRequestSession(req.headers);
    const perm = canPerformAction(session, 'manage_workspace');
    if (!perm.allowed) {
      return res.status(session.authenticated ? 403 : 401).json({ error: perm.reason });
    }
    const state = store.getState();
    res.json(llmRegistry.getKeyReadiness(state.encrypted_byok_keys));
  });

  app.post('/api/workspace/byok', (req, res) => {
    const session = resolveRequestSession(req.headers);
    const perm = canPerformAction(session, 'manage_workspace');
    if (!perm.allowed) {
      return res.status(session.authenticated ? 403 : 401).json({ error: perm.reason });
    }
    const { provider_id, api_key } = req.body ?? {};
    if (!provider_id || !api_key || String(api_key).length < 6) {
      return res.status(400).json({ error: 'Valid provider_id and api_key required' });
    }
    const state = store.getState();
    state.encrypted_byok_keys[String(provider_id)] = encryptWorkspaceKey(String(api_key));
    store.persist();
    // Never return the key or ciphertext
    res.status(201).json({ provider_id: String(provider_id), stored: true });
  });

  app.delete('/api/workspace/byok/:providerId', (req, res) => {
    const session = resolveRequestSession(req.headers);
    const perm = canPerformAction(session, 'manage_workspace');
    if (!perm.allowed) {
      return res.status(session.authenticated ? 403 : 401).json({ error: perm.reason });
    }
    const state = store.getState();
    const providerId = String(req.params.providerId);
    delete state.encrypted_byok_keys[providerId];
    store.persist();
    res.json({ provider_id: providerId, removed: true });
  });

  app.post('/api/pocs/:pocId/invites', (req, res) => {
    const session = resolveRequestSession(req.headers);
    const perm = canPerformAction(session, 'generate_invite', req.params.pocId);
    if (!perm.allowed) {
      return res.status(session.authenticated ? 403 : 401).json({ error: perm.reason });
    }
    const poc = store.getPoc(req.params.pocId);
    if (!poc) return res.status(404).json({ error: 'POC not found' });

    const ttlHours = Math.max(0.01, Math.min(720, Number(req.body?.ttl_hours ?? 168)));
    const label = String(req.body?.label || 'Steering Committee Stakeholder').slice(0, 80);
    const { token, expires_at_iso } = signInviteToken(poc.id, Math.round(ttlHours * 3600), label);
    const baseUrl = `${req.protocol}://${req.get('host')}`;
    store.recordUserHistory({
      session,
      poc_id: poc.id,
      poc_name: poc.name,
      action: 'created_invite',
      summary: `Generated ${ttlHours}h invite link for ${label}`,
      tab: 'console',
    });
    res.status(201).json({
      poc_id: poc.id,
      token,
      expires_at_iso,
      invite_url: `${baseUrl}/?invite=${encodeURIComponent(token)}`,
    });
  });

  if (process.env.NODE_ENV !== 'production' && !process.env.SKIP_VITE_MIDDLEWARE) {
    const vite = await createViteServer({
      server: {
        middlewareMode: true,
        hmr: false,
        ws: httpServer ? { server: httpServer } : false,
        watch: null,
      },
      appType: 'spa',
    });
    app.use(vite.middlewares);
  } else {
    const distDir = path.resolve(process.cwd(), 'dist');
    if (fs.existsSync(distDir)) {
      app.use(express.static(distDir));
      app.get('*', (_req, res) => {
        res.sendFile(path.join(distDir, 'index.html'));
      });
    }
  }

  return app;
}

const isMain =
  import.meta.url === `file://${process.argv[1]}` ||
  process.argv[1]?.endsWith('server.ts');

if (isMain) {
  const portArgIdx = process.argv.indexOf('--port');
  const cliPort = portArgIdx >= 0 ? Number(process.argv[portArgIdx + 1]) : NaN;
  const port = Number.isFinite(cliPort) ? cliPort : Number(process.env.DEFAULT_APP_PORT) || 3000;
  const httpServer = http.createServer();
  createApp(httpServer).then((app) => {
    httpServer.on('request', app);
    httpServer.listen(port, '0.0.0.0', () => {
      console.log(`Prod Preview server running on http://0.0.0.0:${port}`);
    });
  });
}
