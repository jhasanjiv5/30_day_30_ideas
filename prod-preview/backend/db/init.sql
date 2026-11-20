CREATE TABLE IF NOT EXISTS pocs (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  business_summary TEXT NOT NULL,
  owner_name TEXT NOT NULL,
  workspace_id TEXT NOT NULL,
  data_policy TEXT NOT NULL,
  selected_llm_provider TEXT NOT NULL,
  environment_json JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS requirements (
  id TEXT NOT NULL,
  poc_id TEXT NOT NULL REFERENCES pocs(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  check_type TEXT NOT NULL,
  threshold TEXT NOT NULL,
  in_scope BOOLEAN NOT NULL DEFAULT TRUE,
  approved_by_engineer BOOLEAN NOT NULL DEFAULT FALSE,
  source_provider TEXT,
  PRIMARY KEY (poc_id, id)
);

CREATE TABLE IF NOT EXISTS sign_offs (
  id TEXT PRIMARY KEY,
  poc_id TEXT NOT NULL REFERENCES pocs(id) ON DELETE CASCADE,
  requirement_id TEXT NOT NULL,
  decision TEXT NOT NULL,
  reviewer_name TEXT NOT NULL,
  reviewer_email TEXT NOT NULL,
  reviewer_role TEXT NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS comments (
  id TEXT PRIMARY KEY,
  poc_id TEXT NOT NULL REFERENCES pocs(id) ON DELETE CASCADE,
  requirement_id TEXT NOT NULL,
  author_name TEXT NOT NULL,
  author_role TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS llm_audit_log (
  id TEXT PRIMARY KEY,
  poc_id TEXT NOT NULL REFERENCES pocs(id) ON DELETE CASCADE,
  requested_provider TEXT NOT NULL,
  answered_by_provider TEXT NOT NULL,
  model TEXT NOT NULL,
  prompt_version TEXT NOT NULL,
  latency_ms INTEGER NOT NULL,
  input_tokens INTEGER NOT NULL,
  output_tokens INTEGER NOT NULL,
  estimated_cost_usd NUMERIC(12, 6) NOT NULL,
  used_fallback BOOLEAN NOT NULL DEFAULT FALSE,
  approved BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS workspace_byok_keys (
  workspace_id TEXT NOT NULL,
  provider_id TEXT NOT NULL,
  encrypted_key TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (workspace_id, provider_id)
);

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  role TEXT NOT NULL,
  auth_provider TEXT NOT NULL,
  password_hash TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_login_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_project_history (
  id TEXT PRIMARY KEY,
  user_email TEXT NOT NULL,
  user_name TEXT NOT NULL,
  user_role TEXT NOT NULL,
  poc_id TEXT NOT NULL REFERENCES pocs(id) ON DELETE CASCADE,
  poc_name TEXT NOT NULL,
  action TEXT NOT NULL,
  summary TEXT NOT NULL,
  tab TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_project_history_email
  ON user_project_history (user_email, created_at DESC);

