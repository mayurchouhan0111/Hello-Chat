const fs = require('fs');
const os = require('os');
const path = require('path');

const CFG = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
const PROJECT = 'hellochat-e8965';

function loadCfg() { return JSON.parse(fs.readFileSync(CFG, 'utf8')); }

async function refreshToken() {
  const cfg = loadCfg();
  return cfg.tokens.access_token;
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

  // 1. Check reseller_transactions where recipientUid == uid or targetId == 1002
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents:runQuery`;
  
  console.log('Querying reseller_transactions...');
  const res1 = await fetch(url, {
    method: 'POST',
    headers: { Authorization: `Bearer ${tok}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: 'reseller_transactions' }],
        limit: 50
      }
    })
  });
  const rows1 = await res1.json();
  const rt = rows1.filter(r => r.document).map(r => ({ id: r.document.name.split('/').pop(), ...fromDoc(r.document.fields) }));
  console.log('Total reseller_transactions found:', rt.length);
  for (const r of rt) {
    console.log(JSON.stringify(r));
  }

  // 2. Check audit_logs
  console.log('\nQuerying audit_logs...');
  const res2 = await fetch(url, {
    method: 'POST',
    headers: { Authorization: `Bearer ${tok}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: 'audit_logs' }],
        orderBy: [{ field: { fieldPath: 'timestamp' }, direction: 'DESCENDING' }],
        limit: 20
      }
    })
  });
  const rows2 = await res2.json();
  const al = rows2.filter(r => r.document).map(r => ({ id: r.document.name.split('/').pop(), ...fromDoc(r.document.fields) }));
  console.log('Recent audit logs:', al.length);
  for (const a of al) {
    console.log(`[${a.timestamp}] action=${a.action} target=${a.targetUid || a.targetId} by=${a.performedBy} details=${JSON.stringify(a.details || a.metadata || {})}`);
  }
}

run().catch(console.error);
