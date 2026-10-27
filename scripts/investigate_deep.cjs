const fs = require('fs');
const os = require('os');
const path = require('path');

const CFG = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
const PROJECT = 'hellochat-e8965';

function loadCfg() { return JSON.parse(fs.readFileSync(CFG, 'utf8')); }
function saveCfg(c) { fs.writeFileSync(CFG, JSON.stringify(c, null, 2)); }

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
  const uid = 'PhFe53EOGzRxricZKawdA4DARcz2';

  // 1. List transactions WITHOUT orderBy to see ALL docs
  const listTxUrl = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users/${uid}/transactions?pageSize=100`;
  const txRes = await fetch(listTxUrl, { headers: { Authorization: `Bearer ${tok}` } });
  const txData = await txRes.json();
  const txDocs = (txData.documents || []).map(d => ({ id: d.name.split('/').pop(), ...fromDoc(d.fields) }));
  console.log('Total transactions in subcollection without orderBy filter:', txDocs.length);
  for (const d of txDocs) {
    if (!d.timestamp) {
      console.log('Doc without timestamp:', d.id, JSON.stringify(d));
    }
  }

  // 2. Fetch admin_logs
  console.log('\n--- ADMIN LOGS ---');
  const aRes = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/admin_logs?pageSize=50`, {
    headers: { Authorization: `Bearer ${tok}` }
  });
  const aData = await aRes.json();
  for (const doc of (aData.documents || [])) {
    console.log(doc.name.split('/').pop(), JSON.stringify(fromDoc(doc.fields)));
  }

  // 3. Query other users who have diamonds > 1,000,000,000
  console.log('\n--- USERS WITH > 100,000,000 DIAMONDS ---');
  const qBody = {
    structuredQuery: {
      from: [{ collectionId: 'users' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'diamonds' },
          op: 'GREATER_THAN',
          value: { integerValue: 100000000 }
        }
      },
      limit: 20
    }
  };
  const qRes = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents:runQuery`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${tok}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(qBody)
  });
  const highUsers = await qRes.json();
  for (const row of highUsers) {
    if (row.document) {
      const u = fromDoc(row.document.fields);
      console.log(`HelloID: ${u.helloId} (${u.displayName}) uid=${u.uid} diamonds=${u.diamonds} diamondBalance=${u.diamondBalance} totalWinning=${u.totalWinningEarned} sent=${u.totalDiamondsSent}`);
    }
  }
}

run().catch(console.error);
