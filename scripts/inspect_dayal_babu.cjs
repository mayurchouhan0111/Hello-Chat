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
  const uid = 'rsT0IEpsEZhGtIgQGzmCOnS8GO22';
  
  const uRes = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users/${uid}`, {
    headers: { Authorization: `Bearer ${tok}` }
  });
  const ud = await uRes.json();
  console.log('Dayal Babu full doc:');
  console.log(JSON.stringify(fromDoc(ud.fields), null, 2));

  // Let's check all txs:
  const txRes = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users/${uid}/transactions?pageSize=300`, {
    headers: { Authorization: `Bearer ${tok}` }
  });
  const td = await txRes.json();
  const txs = (td.documents || []).map(d => ({ id: d.name.split('/').pop(), ...fromDoc(d.fields) }));
  console.log(`Transactions (${txs.length}):`);
  for (const t of txs) {
    if (t.type !== 'game_bet' && t.type !== 'game_win') {
      console.log(`[${t.timestamp || t.createdAt}] type=${t.type} cat=${t.category} amt=${t.amount} desc="${t.description}"`);
    }
  }

  // Also check salaryPayouts where uid == Dayal Babu
  const spRes = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents:runQuery`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${tok}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: 'salaryPayouts' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'uid' },
            op: 'EQUAL',
            value: { stringValue: uid }
          }
        }
      }
    })
  });
  const spData = await spRes.json();
  console.log(`\nsalaryPayouts for Dayal Babu (${spData.length}):`);
  for (const r of spData) {
    if (r.document) {
      console.log(JSON.stringify(fromDoc(r.document.fields)));
    }
  }
}

run().catch(console.error);
