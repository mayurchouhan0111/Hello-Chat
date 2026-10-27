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

  // 1. Check Nexus, Sumaiya, Enan, etc.
  const checkUids = [
    { label: 'Enan (100003 / 1002)', uid: 'PhFe53EOGzRxricZKawdA4DARcz2' },
    { label: 'Nexus (3242285117)', uid: 'atgusRov7dQWiST3F0b00nyfzV93' },
    { label: 'Sumaiya (7578602811)', uid: '7hLNXgGg0YZDtP7dtCXc8C4KLnh2' },
    { label: 'Urmi (5829766012)', uid: 'HVXpoCGEmrbUDKJW2TxjSxsSOCv2' },
    { label: 'REX (5621916410)', uid: 'pc6mVRnBCVOTV9nM5J7FErJ5WZc2' },
  ];

  console.log('--- USER PROFILE DETAILS ---');
  for (const item of checkUids) {
    const res = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users/${item.uid}`, {
      headers: { Authorization: `Bearer ${tok}` }
    });
    if (res.status === 200) {
      const d = await res.json();
      const u = fromDoc(d.fields);
      console.log(`\n[${item.label}]`);
      console.log(`  email: ${u.email}`);
      console.log(`  phone: ${u.phoneNumber}`);
      console.log(`  createdAt: ${u.createdAt}`);
      console.log(`  country: ${u.country}`);
      console.log(`  hasFcm: ${Boolean(u.fcmToken)}`);
      console.log(`  lastActive: ${u.lastActive}`);
      console.log(`  photo: ${u.profilePhotoUrl}`);
      console.log(`  bio: ${u.bio}`);
      console.log(`  isBanned: ${u.isBanned}`);
    } else {
      console.log(`[${item.label}] Not found (status ${res.status})`);
    }
  }

  // 2. Search for any explicitly fake / seeded users in users collection
  console.log('\n--- SEARCHING FOR SEEDED / FAKE USERS ---');
  const resUsers = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users?pageSize=300`, {
    headers: { Authorization: `Bearer ${tok}` }
  });
  const dataUsers = await resUsers.json();
  const allUsers = (dataUsers.documents || []).map(d => ({
    uid: d.name.split('/').pop(),
    ...fromDoc(d.fields)
  }));

  const fakeUsers = allUsers.filter(u => 
    u.uid.startsWith('fake_') || 
    u.uid.startsWith('test_') || 
    (u.email && (u.email.includes('fake') || u.email.includes('example.com') || u.email.includes('test.com'))) ||
    (u.profilePhotoUrl && u.profilePhotoUrl.includes('dicebear'))
  );

  console.log(`Total users scanned: ${allUsers.length}`);
  console.log(`Found ${fakeUsers.length} potential fake/seeded users:`);
  for (const f of fakeUsers) {
    console.log(`  uid=${f.uid} helloId=${f.helloId} name="${f.displayName}" email=${f.email}`);
  }
}

run().catch(console.error);
