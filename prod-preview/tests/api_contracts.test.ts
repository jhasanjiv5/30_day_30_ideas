import assert from 'node:assert/strict';
import test from 'node:test';
import type { AddressInfo } from 'node:net';
import { createApp } from '../server.ts';
import { signInviteToken } from '../server/domain/auth.ts';

async function startTestServer() {
  process.env.SKIP_VITE_MIDDLEWARE = '1';
  process.env.FORCE_OFFLINE_LLM_FIXTURES = '1';
  process.env.OPENAI_API_KEY = 'sk-super-secret-never-leak-9999';
  const app = await createApp();
  const server = app.listen(0, '127.0.0.1');
  await new Promise<void>((resolve) => server.once('listening', resolve));
  const { port } = server.address() as AddressInfo;
  return {
    baseUrl: `http://127.0.0.1:${port}`,
    close: () => new Promise<void>((resolve) => server.close(() => resolve())),
  };
}

test('API enforces policy governance, provider switching, draft isolation, RBAC, and zero key leaks', async () => {
  const srv = await startTestServer();
  try {
    // 1. EU-only POC rejects US provider (openai) via API
    const blockedSwitch = await fetch(`${srv.baseUrl}/api/pocs/poc-retail-checkout/llm/provider`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', 'x-demo-role': 'engineer' },
      body: JSON.stringify({ provider_id: 'openai' }),
    });
    assert.equal(blockedSwitch.status, 403);

    // 2. Switching to "none" (manual) works immediately without restart
    const manualSwitch = await fetch(`${srv.baseUrl}/api/pocs/poc-retail-checkout/llm/provider`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', 'x-demo-role': 'engineer' },
      body: JSON.stringify({ provider_id: 'none' }),
    });
    assert.equal(manualSwitch.status, 200);

    // 3. Disabling a provider at workspace level blocks it in API
    const disableRes = await fetch(`${srv.baseUrl}/api/workspace/providers/azure_openai/toggle`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', 'x-demo-role': 'engineer' },
      body: JSON.stringify({ enabled: false }),
    });
    assert.equal(disableRes.status, 200);

    const useDisabled = await fetch(`${srv.baseUrl}/api/pocs/poc-retail-checkout/llm/provider`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', 'x-demo-role': 'engineer' },
      body: JSON.stringify({ provider_id: 'azure_openai' }),
    });
    assert.equal(useDisabled.status, 403);

    // Re-enable for cleanliness
    await fetch(`${srv.baseUrl}/api/workspace/providers/azure_openai/toggle`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', 'x-demo-role': 'engineer' },
      body: JSON.stringify({ enabled: true }),
    });

    // 4. Draft created by engineer is NOT visible to stakeholders until approved
    const draftRes = await fetch(`${srv.baseUrl}/api/pocs/poc-retail-checkout/llm/draft`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-demo-role': 'engineer' },
      body: JSON.stringify({
        provider_id: 'vertex_gemini',
        requirements_text: '- API latency must stay under 190 ms',
      }),
    });
    assert.equal(draftRes.status, 201);

    const stakeholderPocRes = await fetch(`${srv.baseUrl}/api/pocs/poc-retail-checkout`, {
      headers: { 'x-demo-role': 'stakeholder' },
    });
    const stakeholderBody = await stakeholderPocRes.text();
    assert.equal(stakeholderPocRes.status, 200);
    assert.equal(stakeholderBody.includes('190 ms'), false);
    assert.equal(stakeholderBody.includes(process.env.OPENAI_API_KEY!), false);

    // 5. Stakeholder invite token cannot edit mappings or access other POCs
    const { token } = signInviteToken('poc-retail-checkout', 3600);
    const forbiddenEdit = await fetch(`${srv.baseUrl}/api/pocs/poc-retail-checkout/llm/provider`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', 'x-invite-token': token },
      body: JSON.stringify({ provider_id: 'none' }),
    });
    assert.equal(forbiddenEdit.status, 403);

    const forbiddenOtherPoc = await fetch(`${srv.baseUrl}/api/pocs/poc-claims-triage`, {
      headers: { 'x-invite-token': token },
    });
    assert.equal(forbiddenOtherPoc.status, 403);

    // 6. Storing BYOK key never echoes the secret back; key readiness & delete work safely
    const byokRes = await fetch(`${srv.baseUrl}/api/workspace/byok`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-demo-role': 'engineer' },
      body: JSON.stringify({ provider_id: 'openai', api_key: 'sk-byok-secret-value-4567' }),
    });
    const byokText = await byokRes.text();
    assert.equal(byokRes.status, 201);
    assert.equal(byokText.includes('sk-byok-secret-value-4567'), false);

    const stakeholderKeysBlocked = await fetch(`${srv.baseUrl}/api/workspace/keys`, {
      headers: { 'x-demo-role': 'stakeholder' },
    });
    assert.equal(stakeholderKeysBlocked.status, 403);

    const keysRes = await fetch(`${srv.baseUrl}/api/workspace/keys`, {
      headers: { 'x-demo-role': 'engineer' },
    });
    const keysText = await keysRes.text();
    assert.equal(keysRes.status, 200);
    assert.equal(keysText.includes('sk-byok-secret-value-4567'), false);
    assert.equal(keysText.includes(process.env.OPENAI_API_KEY!), false);
    const keysJson = JSON.parse(keysText) as {
      providers: Array<{ id: string; has_byok_key: boolean; has_server_key: boolean }>;
    };
    const openaiEntry = keysJson.providers.find((p) => p.id === 'openai');
    assert.equal(openaiEntry?.has_byok_key, true);
    assert.equal(openaiEntry?.has_server_key, true);

    const deleteByokRes = await fetch(`${srv.baseUrl}/api/workspace/byok/openai`, {
      method: 'DELETE',
      headers: { 'x-demo-role': 'engineer' },
    });
    assert.equal(deleteByokRes.status, 200);

    // 7. Engineer can upload/create a new POC with terraform.tfstate; stakeholder is blocked (403)
    const tfState = JSON.stringify({
      resources: [
        { type: 'google_cloud_run_v2_service', name: 'invoice_api', instances: [{ attributes: { location: 'europe-west1' } }] },
        { type: 'google_sql_database_instance', name: 'invoice_db', instances: [{ attributes: { region: 'europe-west1', tier: 'db-custom-2-7680' } }] },
      ],
    });
    const stakeholderCreate = await fetch(`${srv.baseUrl}/api/pocs`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-demo-role': 'stakeholder' },
      body: JSON.stringify({ name: 'Blocked POC', business_summary: 'Should fail' }),
    });
    assert.equal(stakeholderCreate.status, 403);

    const engineerCreate = await fetch(`${srv.baseUrl}/api/pocs`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-demo-role': 'engineer' },
      body: JSON.stringify({
        name: 'Supplier Invoice Portal',
        business_summary: 'Validates vendor PDF invoice intake in Belgium.',
        primary_region: 'europe-west1',
        data_policy: 'eu_only',
        terraform_state_json: tfState,
        selected_llm_provider: 'none',
        requirements_text: '- Invoice portal latency <= 220 ms',
      }),
    });
    assert.equal(engineerCreate.status, 201);
    const createdJson = (await engineerCreate.json()) as { poc: { environment: { resources: Array<{ business_label: string }> } } };
    assert.equal(createdJson.poc.environment.resources.length, 2);
  } finally {
    await srv.close();
  }
});

test('API enforces real user authentication, Bearer RBAC, and strict per-user project history isolation', async () => {
  const srv = await startTestServer();
  try {
    // 1. Unauthenticated access to protected endpoints returns 401
    const unauthPocs = await fetch(`${srv.baseUrl}/api/pocs`);
    assert.equal(unauthPocs.status, 401);
    const unauthHistory = await fetch(`${srv.baseUrl}/api/history`);
    assert.equal(unauthHistory.status, 401);

    // 2. Wrong password rejected with 401
    const badLogin = await fetch(`${srv.baseUrl}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'claire.bennett@acme-retail.example',
        password: 'wrong-password',
      }),
    });
    assert.equal(badLogin.status, 401);

    // 3. Register User A (stakeholder) & verify password_hash is never returned
    const uniqueEmail = `usera-${Date.now()}@example.com`;
    const regA = await fetch(`${srv.baseUrl}/api/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'User Alpha',
        email: uniqueEmail,
        password: 'StrongPassword123!',
        role: 'stakeholder',
      }),
    });
    assert.equal(regA.status, 201);
    const regAText = await regA.text();
    assert.equal(regAText.includes('password_hash'), false);
    const regAJson = JSON.parse(regAText) as { token: string; session: { role: string } };
    assert.equal(regAJson.session.role, 'stakeholder');

    // Stakeholder Bearer token cannot create POCs (403)
    const blockedCreate = await fetch(`${srv.baseUrl}/api/pocs`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${regAJson.token}`,
      },
      body: JSON.stringify({ name: 'Should fail', business_summary: 'Denied' }),
    });
    assert.equal(blockedCreate.status, 403);

    // 4. Sign in User B via Google Workspace endpoint (engineer)
    const userBEmail = `userb-${Date.now()}@example.com`;
    const googleB = await fetch(`${srv.baseUrl}/api/auth/google`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: userBEmail,
        name: 'User Beta',
        role: 'engineer',
      }),
    });
    assert.equal(googleB.status, 200);
    const googleBJson = (await googleB.json()) as { token: string };

    // 5. User A records a comment & what-if; User B triggers recheck -> verify strict isolation
    const commentRes = await fetch(`${srv.baseUrl}/api/pocs/poc-retail-checkout/comments`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${regAJson.token}`,
      },
      body: JSON.stringify({
        requirement_id: 'req-latency',
        body: 'Alpha private history check comment',
      }),
    });
    assert.equal(commentRes.status, 201);

    const recheckRes = await fetch(`${srv.baseUrl}/api/pocs/poc-claims-triage/recheck`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${googleBJson.token}`,
      },
    });
    assert.equal(recheckRes.status, 200);

    const histARes = await fetch(`${srv.baseUrl}/api/history`, {
      headers: { Authorization: `Bearer ${regAJson.token}` },
    });
    const histA = (await histARes.json()) as {
      history: Array<{ user_email: string; poc_id: string }>;
    };
    assert.ok(histA.history.some((h) => h.poc_id === 'poc-retail-checkout'));
    assert.equal(
      histA.history.some((h) => h.user_email !== uniqueEmail),
      false
    );

    const histBRes = await fetch(`${srv.baseUrl}/api/history`, {
      headers: { Authorization: `Bearer ${googleBJson.token}` },
    });
    const histB = (await histBRes.json()) as {
      history: Array<{ user_email: string; poc_id: string }>;
    };
    assert.ok(histB.history.some((h) => h.poc_id === 'poc-claims-triage'));
    assert.equal(
      histB.history.some((h) => h.user_email === uniqueEmail),
      false
    );

    // 6. Clearing User A history leaves User B history intact
    const clearA = await fetch(`${srv.baseUrl}/api/history`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${regAJson.token}` },
    });
    assert.equal(clearA.status, 200);

    const histAAfter = (await (
      await fetch(`${srv.baseUrl}/api/history`, {
        headers: { Authorization: `Bearer ${regAJson.token}` },
      })
    ).json()) as { history: unknown[] };
    assert.equal(histAAfter.history.length, 0);

    const histBAfter = (await (
      await fetch(`${srv.baseUrl}/api/history`, {
        headers: { Authorization: `Bearer ${googleBJson.token}` },
      })
    ).json()) as { history: unknown[] };
    assert.ok(histBAfter.history.length > 0);
  } finally {
    await srv.close();
  }
});
