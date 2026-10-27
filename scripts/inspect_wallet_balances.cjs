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

  // 1. Inspect REX
  const rexUid = 'pc6mVRnBCVOTV9nM5J7FErJ5WZc2';
  const rRes = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users/${rexUid}`, {
    headers: { Authorization: `Bearer ${tok}` }
  });
  const rd = await rRes.json();
  const rex = fromDoc(rd.fields);
  console.log('=== REX USER DATA ===');
  console.log('name:', rex.displayName || rex.name, 'email:', rex.email, 'helloId:', rex.helloId || rex.userId);
  console.log('walletBalance:', rex.walletBalance);
  console.log('diamonds:', rex.diamonds, 'diamondBalance:', rex.diamondBalance, 'beansBalance:', rex.beansBalance);

  // 2. Fetch REX transactions
  const txRes = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users/${rexUid}/transactions?pageSize=100`, {
    headers: { Authorization: `Bearer ${tok}` }
  });
  if (txRes.status === 200) {
    const td = await txRes.json();
    const txs = (td.documents || []).map(d => ({ id: d.name.split('/').pop(), ...fromDoc(d.fields) }));
    console.log(`\n=== REX TRANSACTIONS (${txs.length}) ===`);
    for (const t of txs) {
      console.log(`[${t.timestamp || t.createdAt}] type=${t.type} category=${t.category} amount=${t.amount} desc="${t.description || ''}"`);
    }
  }

  // 3. Scan all users to find who has walletBalance > 0
  console.log('\n=== SCANNING ALL USERS FOR walletBalance > 0 ===');
  let pageToken = '';
  let usersWithWallet = [];
  do {
    const url = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users?pageSize=300${pageToken ? '&pageToken=' + pageToken : ''}`;
    const uRes = await fetch(url, { headers: { Authorization: `Bearer ${tok}` } });
    const uData = await uRes.json();
    for (const d of (uData.documents || [])) {
      const u = fromDoc(d.fields);
      const uid = d.name.split('/').pop();
      if (u.walletBalance && u.walletBalance > 0) {
        usersWithWallet.push({ uid, name: u.displayName || u.name, helloId: u.helloId || u.userId, email: u.email, walletBalance: u.walletBalance, diamondBalance: u.diamondBalance, beansBalance: u.beansBalance });
      }
    }
    pageToken = uData.nextPageToken;
  } while (pageToken);

  console.log(`Found ${usersWithWallet.length} users with walletBalance > 0:`);
  for (const u of usersWithWallet) {
    console.log(`UID: ${u.uid} | Name: ${u.name} | HelloID: ${u.helloId} | Email: ${u.email} | walletBalance: $${u.walletBalance} | Diamonds: ${u.diamondBalance}`);
  }
}

run().catch(console.error);
