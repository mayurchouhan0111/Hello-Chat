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

async function main() {
  const token = await refreshToken();
  const listUrl = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users?pageSize=300`;
  const listRes = await fetch(listUrl, { headers: { Authorization: `Bearer ${token}` } });
  const listData = await listRes.json();
  const docs = listData.documents || [];
  console.log(`Checking ${docs.length} users for admin roles:`);
  for (const d of docs) {
    const f = d.fields || {};
    const role = f.role?.stringValue;
    const tags = (f.tags?.arrayValue?.values || []).map(v => v.stringValue);
    const helloId = f.helloId?.integerValue || f.helloId?.stringValue;
    const username = f.username?.stringValue || f.displayName?.stringValue;
    if (role === 'admin' || role === 'superadmin' || role === 'owner' || tags.includes('Admin') || tags.includes('SuperAdmin') || tags.includes('Owner')) {
      const uid = d.name.split('/').pop();
      console.log(`[${uid}] helloId: ${helloId} | name: ${username} | role: ${role} | tags: ${JSON.stringify(tags)} | branchId: ${f.branchId?.stringValue}`);
    }
  }
}

main().catch(console.error);
