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
  
  // Find users with huge beansBalance or totalBeansReceived
  const qBody = {
    structuredQuery: {
      from: [{ collectionId: 'users' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'beansBalance' },
          op: 'GREATER_THAN',
          value: { integerValue: 10000000 }
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
  const rows = await qRes.json();
  console.log('Users with > 10M Beans:');
  for (const r of rows) {
    if (r.document) {
      const u = fromDoc(r.document.fields);
      console.log(`HelloID: ${u.helloId} (${u.displayName}) uid=${u.uid} beansBalance=${u.beansBalance} totalBeansReceived=${u.totalBeansReceived} dailyBeansReceived=${u.dailyBeansReceived}`);
    }
  }

  // Also check salaryStatus collection - who has pending salary or huge beans
  console.log('\nChecking salaryStatus collection:');
  const sRes = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/salaryStatus?pageSize=20`, {
    headers: { Authorization: `Bearer ${tok}` }
  });
  const sData = await sRes.json();
  for (const doc of (sData.documents || [])) {
    const s = fromDoc(doc.fields);
    console.log(`Host UID: ${doc.name.split('/').pop()} totalBeansEarned=${s.totalBeansEarned} currentLevel=${s.currentLevel}`);
  }
}

run().catch(console.error);
