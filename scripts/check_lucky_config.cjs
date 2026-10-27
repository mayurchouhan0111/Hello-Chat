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
  
  // 1. Fetch system_settings/lucky_gift_config
  const res = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/system_settings/lucky_gift_config`, {
    headers: { Authorization: `Bearer ${tok}` }
  });
  console.log('lucky_gift_config status:', res.status);
  if (res.status === 200) {
    const data = await res.json();
    console.log(JSON.stringify(fromDoc(data.fields), null, 2));
  }

  // 2. Fetch all system_settings documents
  const sRes = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/system_settings`, {
    headers: { Authorization: `Bearer ${tok}` }
  });
  const sData = await sRes.json();
  console.log('\nAll system_settings docs:');
  for (const doc of (sData.documents || [])) {
    console.log('-', doc.name.split('/').pop());
  }

  // 3. Check gifts collection - find gifts in 'lucky' category or with 'bell' or isLucky
  const gRes = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/gifts?pageSize=100`, {
    headers: { Authorization: `Bearer ${tok}` }
  });
  const gData = await gRes.json();
  const luckyGifts = (gData.documents || [])
    .map(d => ({ id: d.name.split('/').pop(), ...fromDoc(d.fields) }))
    .filter(g => (g.category || '').toLowerCase() === 'lucky' || g.isLucky || (g.name || '').toLowerCase().includes('bell'));
  console.log('\nLucky gifts count:', luckyGifts.length);
  for (const g of luckyGifts) {
    console.log(`Lucky Gift: ${g.id} name="${g.name}" price=${g.priceInDiamonds || g.price} category=${g.category} isLucky=${g.isLucky}`);
  }
}

run().catch(console.error);
