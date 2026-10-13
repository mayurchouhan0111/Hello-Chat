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

const val = (f) => (f == null ? '' : f.stringValue ?? f.integerValue ?? f.doubleValue ?? f.booleanValue ?? '');

async function main() {
  const token = await getAccessToken();
  const res = await fetch(`${API}/gifts?pageSize=300`, {
    headers: { Authorization: `Bearer ${token}` }
  });
  const json = await res.json();
  console.log(`Fetched ${json.documents?.length || 0} gifts:`);
  for (const d of json.documents || []) {
    const id = d.name.split('/').pop();
    const f = d.fields || {};
    console.log(id);
    console.log('  name:', val(f.name));
    console.log('  category:', val(f.category));
    console.log('  format:', val(f.animationFormat) || val(f.animation_type));
    console.log('  tier:', val(f.tier));
    console.log('  price:', val(f.priceInDiamonds));
    console.log('  animUrl:', val(f.lottieAssetPath) || val(f.animation_url));
    console.log('  imageUrl:', val(f.imageUrl));
  }
}
main().catch(console.error);
