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

  // 1. Fetch all users
  const res = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users?pageSize=300`, {
    headers: { Authorization: `Bearer ${tok}` }
  });
  const data = await res.json();
  const allUsers = (data.documents || []).map(d => ({
    name: d.name,
    uid: d.name.split('/').pop(),
    ...fromDoc(d.fields)
  }));

  const fakeUsers = allUsers.filter(u => 
    u.uid.startsWith('fake_') || 
    u.uid.startsWith('test_') || 
    u.uid.startsWith('sim_')
  );

  console.log(`Found ${fakeUsers.length} synthetic/seeded fake users to remove:`);
  let deleted = 0;
  for (const u of fakeUsers) {
    console.log(`Deleting ${u.uid} (${u.displayName})...`);
    // Delete user doc
    const delRes = await fetch(`https://firestore.googleapis.com/v1/${u.name}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${tok}` }
    });
    if (delRes.ok) {
      deleted++;
      // If has username, delete from usernames index
      if (u.username) {
        await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/usernames/${u.username}`, {
          method: 'DELETE',
          headers: { Authorization: `Bearer ${tok}` }
        });
      }
    } else {
      console.error(`Failed to delete ${u.uid}:`, delRes.status);
    }
  }

  console.log(`\nSuccessfully removed ${deleted} fake/seeded users from Firestore!`);
}

run().catch(console.error);
