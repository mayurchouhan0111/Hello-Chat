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
  const uid = 'PhFe53EOGzRxricZKawdA4DARcz2';

  // Check recent gifts sent by querying gifts_history or room messages or whatever records gifts
  // Let's check root collections:
  const collections = ['gift_transactions', 'gifts_sent', 'room_messages', 'live_messages'];
  for (const c of collections) {
    const res = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/${c}?pageSize=10`, {
      headers: { Authorization: `Bearer ${tok}` }
    });
    console.log(c, res.status);
    if (res.status === 200) {
      const d = await res.json();
      console.log(`  Count in ${c}:`, (d.documents || []).length);
    }
  }

  // Check Urmi (5829766012) who also had 14 Billion diamonds!
  const urmiUid = 'HVXpoCGEmrbUDKJW2TxjSxsSOCv2';
  const uRes = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users/${urmiUid}`, {
    headers: { Authorization: `Bearer ${tok}` }
  });
  if (uRes.status === 200) {
    const ud = await uRes.json();
    const u = fromDoc(ud.fields);
    console.log('\n--- URMI DOC ---');
    console.log(`diamonds=${u.diamonds} balance=${u.diamondBalance} totalWinning=${u.totalWinningEarned} sent=${u.totalDiamondsSent}`);
  }

  // Check REX who had 324M diamonds
  const rexUid = 'pc6mVRnBCVOTV9nM5J7FErJ5WZc2';
  const rRes = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users/${rexUid}`, {
    headers: { Authorization: `Bearer ${tok}` }
  });
  if (rRes.status === 200) {
    const rd = await rRes.json();
    const r = fromDoc(rd.fields);
    console.log('\n--- REX DOC ---');
    console.log(`diamonds=${r.diamonds} balance=${r.diamondBalance} totalWinning=${r.totalWinningEarned} sent=${r.totalDiamondsSent}`);
  }
}

run().catch(console.error);
