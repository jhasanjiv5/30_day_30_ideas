import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const ROOT = process.cwd();
const ENV_EXAMPLE_PATH = path.join(ROOT, '.env.example');
const ENV_PATH = path.join(ROOT, '.env');

const INTERNAL_SECRET_KEYS = [
  'SESSION_TOKEN_SECRET',
  'INVITE_TOKEN_SECRET',
  'BYOK_ENCRYPTION_KEY',
];

function isUnsetOrPlaceholder(val) {
  if (!val) return true;
  const cleaned = val.replace(/^["']|["']$/g, '').trim();
  return (
    cleaned.length < 16 ||
    cleaned.startsWith('YOUR_') ||
    cleaned.startsWith('dev-replace') ||
    cleaned.includes('PLACEHOLDER')
  );
}

function parseEnvLines(raw) {
  const map = new Map();
  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx <= 0) continue;
    const k = trimmed.slice(0, eqIdx).trim();
    const v = trimmed.slice(eqIdx + 1).trim();
    map.set(k, v);
  }
  return map;
}

function main() {
  if (!fs.existsSync(ENV_EXAMPLE_PATH)) {
    throw new Error('.env.example not found');
  }

  const templateRaw = fs.readFileSync(ENV_EXAMPLE_PATH, 'utf8');
  const existingRaw = fs.existsSync(ENV_PATH) ? fs.readFileSync(ENV_PATH, 'utf8') : '';
  const existingMap = parseEnvLines(existingRaw);

  const updatedKeys = [];
  const preservedKeys = [];

  const nextLines = templateRaw.split(/\r?\n/).map((line) => {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#') || !trimmed.includes('=')) {
      return line;
    }
    const eqIdx = line.indexOf('=');
    const key = line.slice(0, eqIdx).trim();
    const existingVal = existingMap.get(key);

    if (INTERNAL_SECRET_KEYS.includes(key)) {
      if (existingVal && !isUnsetOrPlaceholder(existingVal)) {
        preservedKeys.push(key);
        return `${key}=${existingVal}`;
      }
      const generated = crypto.randomBytes(32).toString('hex');
      updatedKeys.push(key);
      return `${key}="${generated}"`;
    }

    if (existingVal !== undefined) {
      return `${key}=${existingVal}`;
    }
    return line;
  });

  // Preserve any extra user-added keys from .env that were not in .env.example
  const templateMap = parseEnvLines(templateRaw);
  for (const [k, v] of existingMap.entries()) {
    if (!templateMap.has(k)) {
      nextLines.push(`${k}=${v}`);
    }
  }

  fs.writeFileSync(ENV_PATH, nextLines.join('\n').replace(/\n{3,}/g, '\n\n'), {
    encoding: 'utf8',
    mode: 0o600,
  });

  console.log('Configured .env (chmod 600, gitignored).');
  if (updatedKeys.length > 0) {
    console.log(`Generated 256-bit cryptographic secrets for: ${updatedKeys.join(', ')}`);
  }
  if (preservedKeys.length > 0) {
    console.log(`Preserved existing secrets for: ${preservedKeys.join(', ')}`);
  }
  console.log(
    'External API keys (GEMINI_API_KEY, ANTHROPIC_API_KEY, OPENAI_API_KEY, AZURE_OPENAI_API_KEY) remain placeholders until added to .env or Secret Manager.'
  );
}

main();
