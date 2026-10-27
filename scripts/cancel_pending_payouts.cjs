const fs = require('fs');
const os = require('os');
const path = require('path');

const CFG = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
const PROJECT = 'hellochat-e8965';

function loadCfg() { return JSON.parse(fs.readFileSync(CFG, 'utf8')); }

async function refreshToken() {
  const cfg = loadCfg();
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
  const j = await r.json();
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
  
  // 1. Fetch all pending salary payouts
  const qBody = {
    structuredQuery: {
      from: [{ collectionId: 'salaryPayouts' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'status' },
          op: 'EQUAL',
          value: { stringValue: 'pending' }
        }
      },
      limit: 200
    }
  };
  const qRes = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents:runQuery`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${tok}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(qBody)
  });
  const rows = await qRes.json();
  const pending = rows.filter(r => r.document).map(r => ({
    name: r.document.name,
    id: r.document.name.split('/').pop(),
    ...fromDoc(r.document.fields)
  }));
  console.log(`Found ${pending.length} pending payouts to cancel.`);

  let updated = 0;
  for (const p of pending) {
    const updateUrl = `https://firestore.googleapis.com/v1/${p.name}?updateMask.fieldPaths=status&updateMask.fieldPaths=cancelledReason&updateMask.fieldPaths=cancelledAt`;
    const res = await fetch(updateUrl, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${tok}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        fields: {
          status: { stringValue: 'cancelled' },
          cancelledReason: { stringValue: 'Automated distribution disabled by administrator' },
          cancelledAt: { timestampValue: new Date().toISOString() }
        }
      })
    });
    if (res.ok) {
      updated++;
    } else {
      console.error(`Failed to cancel ${p.id}:`, res.status);
    }
  }

  console.log(`Successfully cancelled ${updated} pending payouts.`);
}

run().catch(console.error);
