const fs = require('fs');
const os = require('os');
const path = require('path');

const CFG = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
const PROJECT = 'hellochat-e8965';

async function refreshToken() {
  const cfg = JSON.parse(fs.readFileSync(CFG, 'utf8'));
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

async function listGifts() {
  const token = await refreshToken();
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/gifts?pageSize=100`;
  const r = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` }
  });
  const d = await r.json();
  const docs = d.documents || [];
  console.log(`Found ${docs.length} gift documents in Firestore:`);
  for (const doc of docs) {
    const id = doc.name.split('/').pop();
    const f = doc.fields || {};
    console.log(`- ID: ${id.padEnd(16)} | Name: ${(f.name?.stringValue || '').padEnd(18)} | Category: ${(f.category?.stringValue || '').padEnd(14)} | Tier: ${(f.tier?.stringValue || '').padEnd(8)} | Format: ${(f.animationFormat?.stringValue || '').padEnd(6)} | Active: ${f.isActive?.booleanValue}`);
  }
}

listGifts().catch(console.error);
