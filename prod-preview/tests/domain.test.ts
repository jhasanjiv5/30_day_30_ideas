import assert from 'node:assert/strict';
import test from 'node:test';
import {
  canPerformAction,
  hashPassword,
  resolveRequestSession,
  signInviteToken,
  signSessionToken,
  verifyInviteToken,
  verifyPassword,
  verifySessionToken,
} from '../server/domain/auth.ts';
import { evaluateAllChecks } from '../server/domain/checks.ts';
import {
  decryptWorkspaceKey,
  encryptWorkspaceKey,
  LLMProviderRegistry,
} from '../server/domain/llm.ts';
import { MockProvider } from '../server/domain/providers.ts';
import { AppStore, containsSecretLeak } from '../server/domain/store.ts';
import { simulateWhatIf } from '../server/domain/whatif.ts';

test('check evaluators cover all 5 check types with measured/projected labels and evidence', async () => {
  const provider = new MockProvider();
  const [poc] = await provider.loadSeedPocs();
  const results = evaluateAllChecks(poc.requirements, poc.environment);

  assert.equal(results.length, 5);
  const types = new Set(results.map((r) => r.check_type));
  assert.deepEqual(
    types,
    new Set(['latency_p95', 'uptime', 'data_region', 'iam_exposure', 'monthly_cost'])
  );

  for (const r of results) {
    assert.ok(r.evidence.source_api.length > 0);
    assert.ok(r.evidence.resource_id.length > 0);
    if (r.check_type === 'monthly_cost') {
      assert.equal(r.measured_or_projected, 'projected');
    } else {
      assert.equal(r.measured_or_projected, 'measured');
    }
  }
});

test('what-if model scales x10 latency and cost quickly and reports region outage impact', async () => {
  const provider = new MockProvider();
  const [poc] = await provider.loadSeedPocs();

  const start = performance.now();
  const x10 = simulateWhatIf(poc.environment, {
    users_multiplier: 10,
    traffic_spike: 1,
    region_outage: false,
  });
  const elapsedMs = performance.now() - start;

  assert.ok(elapsedMs < 100, `Expected <100ms, got ${elapsedMs}ms`);
  assert.equal(x10.measured_or_projected, 'projected');
  assert.ok(x10.projected.monthly_cost_usd > x10.baseline.monthly_cost_usd);

  const outage = simulateWhatIf(poc.environment, {
    users_multiplier: 1,
    traffic_spike: 1,
    region_outage: true,
  });
  assert.equal(outage.projected.availability_pct, 0);
  assert.match(outage.what_breaks, /no backup region/i);
});

test('invite tokens enforce expiry, signature integrity, single-POC scope, and RBAC', () => {
  const now = 1_700_000_000;
  const { token } = signInviteToken('poc-retail-checkout', 60, 'External Reviewer', now);

  const valid = verifyInviteToken(token, now + 30);
  assert.equal(valid.valid, true);

  const expired = verifyInviteToken(token, now + 61);
  assert.equal(expired.valid, false);

  const tampered = verifyInviteToken(token.slice(0, -3) + 'xyz', now + 10);
  assert.equal(tampered.valid, false);

  const guestSession = resolveRequestSession({ 'x-invite-token': signInviteToken('poc-retail-checkout', 3600).token });
  assert.equal(guestSession.role, 'stakeholder');
  assert.equal(guestSession.scoped_poc_id, 'poc-retail-checkout');

  // Stakeholder cannot edit mappings or access another POC
  assert.equal(canPerformAction(guestSession, 'comment_or_signoff', 'poc-retail-checkout').allowed, true);
  assert.equal(canPerformAction(guestSession, 'view_poc', 'poc-claims-triage').allowed, false);
  assert.equal(canPerformAction(guestSession, 'edit_mappings', 'poc-retail-checkout').allowed, false);
  assert.equal(canPerformAction(guestSession, 'switch_llm_provider', 'poc-retail-checkout').allowed, false);
  assert.equal(canPerformAction(guestSession, 'approve_drafts', 'poc-retail-checkout').allowed, false);

  const anonSession = resolveRequestSession({ 'x-demo-role': 'anonymous' });
  assert.equal(canPerformAction(anonSession, 'comment_or_signoff', 'poc-retail-checkout').allowed, false);
});

test('LLM provider contract suite tests every adapter offline, fallback chain, compare mode, and encrypted BYOK', async () => {
  process.env.FORCE_OFFLINE_LLM_FIXTURES = '1';
  const registry = new LLMProviderRegistry();
  const provider = new MockProvider();
  const [, , globalPoc] = await provider.loadSeedPocs(); // global policy allows all 7 providers

  const sampleText = `- Checkout p95 under 250 ms\n- Availability >= 99.9%\n- Monthly cost <= $400`;
  const allProviderIds = [
    'none',
    'vertex_gemini',
    'vertex_claude',
    'anthropic',
    'openai',
    'azure_openai',
    'openai_compatible',
  ];

  for (const pid of allProviderIds) {
    const batch = await registry.draftWithReliability({
      poc: globalPoc,
      requestedProviderId: pid,
      requirementsText: sampleText,
      disabledInWorkspace: [],
      encryptedByokMap: {},
    });
    assert.equal(batch.audit.answered_by_provider, pid);
    assert.ok(batch.items.length >= 3);
    assert.equal(batch.status, 'pending_approval');
  }

  // Fallback chain test: simulate failure on vertex_gemini -> falls back to openai
  const fallbackBatch = await registry.draftWithReliability({
    poc: globalPoc,
    requestedProviderId: 'vertex_gemini',
    requirementsText: sampleText,
    disabledInWorkspace: [],
    encryptedByokMap: {},
    simulateFailureProvider: 'vertex_gemini',
  });
  assert.equal(fallbackBatch.audit.requested_provider, 'vertex_gemini');
  assert.equal(fallbackBatch.audit.answered_by_provider, 'openai');
  assert.equal(fallbackBatch.audit.used_fallback, true);

  // Compare mode test
  const cmp = await registry.compareProviders({
    poc: globalPoc,
    leftProviderId: 'vertex_gemini',
    rightProviderId: 'azure_openai',
    requirementsText: sampleText,
    disabledInWorkspace: [],
    encryptedByokMap: {},
  });
  assert.equal(cmp.left_batch.audit.answered_by_provider, 'vertex_gemini');
  assert.equal(cmp.right_batch.audit.answered_by_provider, 'azure_openai');
  assert.ok(cmp.differences.length >= 1);

  // Encrypted BYOK roundtrip & secret leak check
  const dummyKey = 'sk-test-secret-do-not-expose-123456';
  process.env.OPENAI_API_KEY = dummyKey;
  const encrypted = encryptWorkspaceKey(dummyKey);
  assert.notEqual(encrypted, dummyKey);
  assert.equal(decryptWorkspaceKey(encrypted), dummyKey);
  assert.equal(containsSecretLeak(`payload containing ${dummyKey}`), true);
  assert.equal(containsSecretLeak('clean payload with model gpt-4.1-mini'), false);
});

test('password hashing, signed session tokens, unauthenticated default, and per-user history isolation', async () => {
  const hash = hashPassword('ProdPreview2026!');
  assert.equal(verifyPassword('ProdPreview2026!', hash), true);
  assert.equal(verifyPassword('wrong-password', hash), false);

  const now = 1_700_000_000;
  const { token } = signSessionToken(
    {
      id: 'usr-1',
      email: 'alice@example.com',
      name: 'Alice',
      role: 'engineer',
      auth_method: 'password',
    },
    3600,
    now
  );
  const verified = verifySessionToken(token, now + 60);
  assert.equal(verified.valid, true);
  if (verified.valid) {
    assert.equal(verified.payload.email, 'alice@example.com');
    assert.equal(verified.payload.role, 'engineer');
  }

  assert.equal(verifySessionToken(token, now + 3601).valid, false);
  assert.equal(verifySessionToken(token.slice(0, -3) + 'bad', now + 10).valid, false);

  // Empty headers must NOT authenticate implicitly
  const defaultSession = resolveRequestSession({});
  assert.equal(defaultSession.authenticated, false);
  assert.equal(canPerformAction(defaultSession, 'view_poc', 'poc-retail-checkout').allowed, false);

  // Per-user history isolation in AppStore
  const store = new AppStore();
  await store.init();
  store.recordUserHistory({
    session: {
      authenticated: true,
      user_name: 'Alice',
      user_email: 'alice@example.com',
      role: 'engineer',
      auth_method: 'password',
      scoped_poc_id: null,
      invite_expires_at: null,
    },
    poc_id: 'poc-retail-checkout',
    poc_name: 'Retail Checkout Redesign',
    action: 'viewed',
    summary: 'Alice inspected Scorecard',
    tab: 'scorecard',
  });
  store.recordUserHistory({
    session: {
      authenticated: true,
      user_name: 'Bob',
      user_email: 'bob@example.com',
      role: 'stakeholder',
      auth_method: 'password',
      scoped_poc_id: null,
      invite_expires_at: null,
    },
    poc_id: 'poc-claims-triage',
    poc_name: 'Claims Triage Portal',
    action: 'signed_off',
    summary: 'Bob approved Check',
    tab: 'signoff',
  });

  const aliceHistory = store.getUserHistory('alice@example.com');
  const bobHistory = store.getUserHistory('bob@example.com');
  assert.ok(aliceHistory.history.some((e) => e.summary === 'Alice inspected Scorecard'));
  assert.equal(
    aliceHistory.history.some((e) => e.summary === 'Bob approved Check'),
    false
  );
  assert.ok(bobHistory.history.some((e) => e.summary === 'Bob approved Check'));
  assert.equal(
    bobHistory.history.some((e) => e.summary === 'Alice inspected Scorecard'),
    false
  );
});
