const fs = require('fs');
const path = require('path');
const os = require('os');

const PROJECT = 'hellochat-e8965';
const API = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const SCOPES = ['https://www.googleapis.com/auth/cloud-platform', ''];

function readRefreshToken() {
  const candidates = [
    path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json'),
    path.join(process.env.APPDATA || '', 'configstore', 'firebase-tools.json'),
  ];
  for (const p of candidates) {
    if (!fs.existsSync(p)) continue;
    const cfg = JSON.parse(fs.readFileSync(p, 'utf8'));
    const rt = cfg.tokens && cfg.tokens.refresh_token;
    if (rt) return rt;
  }
  throw new Error('No firebase CLI refresh token found');
}

async function getAccessToken() {
  const refresh_token = readRefreshToken();
  const client_id = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
  const client_secret = 'j9iVZfS8kkCEFUPaAeJV0sAi';
  for (const scope of SCOPES) {
    const body = new URLSearchParams({ refresh_token, client_id, client_secret, grant_type: 'refresh_token' });
    if (scope) body.set('scope', scope);
    const res = await fetch('https://www.googleapis.com/oauth2/v3/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body,
    });
    const json = await res.json().catch(() => ({}));
    if (json.access_token) return json.access_token;
  }
  throw new Error('Failed to get token');
}

const UPDATES = {
  mystic_rings: {
    animationFormat: 'svga',
    tier: 'NORMAL',
  },
  crystal_palace: {
    animationFormat: 'svga',
    tier: 'LUXURY',
  },
  royal_carriage: {
    animationFormat: 'svga',
    tier: 'LUXURY',
  },
};

async function main() {
  const token = await getAccessToken();
  for (const [id, fields] of Object.entries(UPDATES)) {
    const fieldMask = Object.keys(fields).map(k => `updateMask.fieldPaths=${k}`).join('&');
    const body = {
      fields: {}
    };
    for (const [k, v] of Object.entries(fields)) {
      body.fields[k] = { stringValue: String(v) };
    }

    const res = await fetch(`${API}/gifts/${id}?${fieldMask}`, {
      method: 'PATCH',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(body)
    });
    const data = await res.json();
    console.log(`Updated ${id}:`, data.name ? 'SUCCESS' : data);
  }
}

main().catch(console.error);
