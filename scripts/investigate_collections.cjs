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
  
  // 1. List root collections
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
  
  // Let's query users with helloId == 1002 to inspect all fields
  const queryUrl = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents:runQuery`;
  const qBody = {
    structuredQuery: {
      from: [{ collectionId: 'users' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'helloId' },
          op: 'EQUAL',
          value: { integerValue: 1002 }
        }
      }
    }
  };
  const qRes = await fetch(queryUrl, {
    method: 'POST',
    headers: { Authorization: `Bearer ${tok}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(qBody)
  });
  const uData = await qRes.json();
  console.log('User 1002 doc fields:');
  if (uData[0] && uData[0].document) {
    const fields = fromDoc(uData[0].document.fields);
    console.log(JSON.stringify(fields, null, 2));
  }

  // 2. Query spin_wheel rounds around 44799860 - 44799875
  console.log('\n--- Checking Spin Wheel Rounds ---');
  // Or check game_history / betting history
  const collectionsToCheck = [
    'spin_wheel_history',
    'game_bets',
    'game_rounds',
    'admin_logs',
    'recharge_history',
    'diamond_distributions',
    'salary_payouts'
  ];

  for (const coll of collectionsToCheck) {
    const cRes = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/${coll}?pageSize=5`, {
      headers: { Authorization: `Bearer ${tok}` }
    });
    console.log(`Collection ${coll}: status=${cRes.status}`);
    if (cRes.status === 200) {
      const cd = await cRes.json();
      console.log(`  Count in ${coll}:`, cd.documents ? cd.documents.length : 0);
    }
  }
}

run().catch(console.error);
