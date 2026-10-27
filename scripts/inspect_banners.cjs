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
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/app_banners?pageSize=100`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  const data = await res.json();
  const docs = data.documents || [];
  console.log(`Found ${docs.length} banners in app_banners:`);
  docs.forEach(d => {
    const id = d.name.split('/').pop();
    const f = d.fields || {};
    console.log(`[${id}] title: "${f.title?.stringValue}" | imageUrl: "${f.imageUrl?.stringValue}" | actionType: "${f.actionType?.stringValue}" | actionValue: "${f.actionValue?.stringValue}" | isActive: ${f.isActive?.booleanValue}`);
  });
}

main().catch(console.error);
