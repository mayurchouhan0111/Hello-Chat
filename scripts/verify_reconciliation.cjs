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
  const uids = [
    { name: 'REX', uid: 'pc6mVRnBCVOTV9nM5J7FErJ5WZc2' },
    { name: 'Hello Chat', uid: 'wTFYRh1bCUWseZWR4SqrvHyHO8f2' }
  ];

  for (const item of uids) {
    const res = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users/${item.uid}`, {
      headers: { Authorization: `Bearer ${tok}` }
    });
    const d = await res.json();
    const u = fromDoc(d.fields);
    console.log(`[VERIFY ${item.name}] UID: ${item.uid}`);
    console.log(`  walletBalance: ${u.walletBalance}`);
    console.log(`  diamondBalance: ${u.diamondBalance}`);
    console.log(`  beansBalance: ${u.beansBalance}`);

    // Check latest transaction
    const txRes = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users/${item.uid}/transactions?pageSize=5`, {
      headers: { Authorization: `Bearer ${tok}` }
    });
    const txData = await txRes.json();
    const latestTx = (txData.documents || []).map(doc => fromDoc(doc.fields))[0];
    console.log(`  Latest Transaction:`, latestTx);
    console.log('--------------------------------------------------');
  }
}

run().catch(console.error);
