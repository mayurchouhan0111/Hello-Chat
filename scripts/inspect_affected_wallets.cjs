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
    'pc6mVRnBCVOTV9nM5J7FErJ5WZc2', // REX ($89980.01)
    'wTFYRh1bCUWseZWR4SqrvHyHO8f2', // hello chat ($119789980.01)
    '9luwjmIkkOaio4BC830y4TbkHSk2', // prince ($90000)
    'L0bls9dIfWbCOsXNXTZjG3A5HbI2', // legend ($6000)
  ];

  for (const uid of uids) {
    console.log(`\n=================== UID: ${uid} ===================`);
    
    // Check user doc fields
    const uRes = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users/${uid}`, {
      headers: { Authorization: `Bearer ${tok}` }
    });
    const ud = await uRes.json();
    const u = fromDoc(ud.fields);
    console.log('User fields:');
    console.log(`  name: ${u.displayName || u.name}, helloId: ${u.helloId || u.userId}`);
    console.log(`  walletBalance: ${u.walletBalance}`);
    console.log(`  diamondBalance: ${u.diamondBalance}, diamonds: ${u.diamonds}, beansBalance: ${u.beansBalance}`);
    console.log(`  tags: ${JSON.stringify(u.tags)}, role: ${u.role}, isReseller: ${u.isReseller}`);

    // Check user's subcollections or recent transactions
    const txRes = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users/${uid}/transactions?pageSize=50`, {
      headers: { Authorization: `Bearer ${tok}` }
    });
    if (txRes.status === 200) {
      const td = await txRes.json();
      const txs = (td.documents || []).map(d => ({ id: d.name.split('/').pop(), ...fromDoc(d.fields) }));
      console.log(`  Transactions count: ${txs.length}`);
      const salaryOrWalletTx = txs.filter(t => t.category === 'wallet' || t.type === 'salary_reward' || t.type === 'purchase' || (t.amount && t.amount > 1000));
      for (const t of (salaryOrWalletTx.length > 0 ? salaryOrWalletTx : txs.slice(0, 10))) {
        console.log(`    [${t.timestamp || t.createdAt}] type=${t.type} cat=${t.category} amt=${t.amount} desc="${t.description}"`);
      }
    }

    // Check salaryStatus for this user
    const ssRes = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/salaryStatus/${uid}`, {
      headers: { Authorization: `Bearer ${tok}` }
    });
    if (ssRes.status === 200) {
      const ssd = await ssRes.json();
      console.log('  salaryStatus:', JSON.stringify(fromDoc(ssd.fields)));
    } else {
      console.log('  salaryStatus: not found');
    }
  }
}

run().catch(console.error);
