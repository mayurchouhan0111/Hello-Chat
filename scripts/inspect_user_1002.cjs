const fs = require('fs');
const os = require('os');
const path = require('path');

const CFG = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
const PROJECT = 'hellochat-e8965';

function loadCfg() { return JSON.parse(fs.readFileSync(CFG, 'utf8')); }
function saveCfg(c) { fs.writeFileSync(CFG, JSON.stringify(c, null, 2)); }

async function refreshToken() {
  const cfg = loadCfg();
  if (!cfg.tokens || !cfg.tokens.refresh_token) throw new Error('no refresh token in configstore');
  const expMs = cfg.tokens.expires_at || 0;
  if (Date.now() < expMs - 60000 && cfg.tokens.access_token) return cfg.tokens.access_token;
  const body = new URLSearchParams({
    client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
    refresh_token: cfg.tokens.refresh_token,
    grant_type: 'refresh_token',
  });
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });
  if (!r.ok) throw new Error('refresh failed: ' + r.status);
  const j = await r.json();
  cfg.tokens.access_token = j.access_token;
  cfg.tokens.expires_at = Date.now() + (j.expires_in || 3600) * 1000;
  saveCfg(cfg);
  return j.access_token;
}

function fromDoc(f) {
  if (!f) return null;
  const o = {};
  for (const [k, v] of Object.entries(f)) {
    if ('stringValue' in v) o[k] = v.stringValue;
    else if ('integerValue' in v) o[k] = Number(v.integerValue);
    else if ('doubleValue' in v) o[k] = Number(v.doubleValue);
    else if ('booleanValue' in v) o[k] = v.booleanValue;
    else if ('timestampValue' in v) o[k] = v.timestampValue;
    else if ('nullValue' in v) o[k] = null;
    else if ('mapValue' in v) o[k] = fromDoc(v.mapValue.fields);
    else if ('arrayValue' in v) o[k] = (v.arrayValue.values || []).map(x => fromDoc({ v: x })?.v);
    else o[k] = v;
  }
  return o;
}

async function run() {
  const tok = await refreshToken();
  const uid = 'PhFe53EOGzRxricZKawdA4DARcz2';
  const parent = `projects/${PROJECT}/databases/(default)/documents/users/${uid}`;
  const url = `https://firestore.googleapis.com/v1/${parent}:runQuery`;

  // Fetch all transactions
  const body = {
    structuredQuery: {
      from: [{ collectionId: 'transactions' }],
      orderBy: [{ field: { fieldPath: 'timestamp' }, direction: 'ASCENDING' }],
      limit: 300
    }
  };

  const res = await fetch(url, {
    method: 'POST',
    headers: { Authorization: `Bearer ${tok}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  });

  const rows = await res.json();
  console.log('Total transactions returned:', rows.length);
  
  const txs = rows
    .filter(r => r.document)
    .map(r => ({
      id: r.document.name.split('/').pop(),
      ...fromDoc(r.document.fields)
    }));

  console.log('\n--- ALL TRANSACTIONS CHRONOLOGICAL ---');
  for (const t of txs) {
    console.log(`[${t.timestamp}] type=${t.type} amount=${t.amount} before=${t.balanceBefore} after=${t.balanceAfter} desc="${t.description || ''}"`);
  }

  // Also check if user has other collections or fields
  console.log('\nDone.');
}

run().catch(console.error);
