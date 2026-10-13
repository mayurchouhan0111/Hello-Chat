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

// Client requested mapping:
// - Love You.svga → SVGA
// - 138.svga → SVGA
// - tencent-VAP-music.zip → VAP
// - 169522.zip → VAP
// - 2529.zip → VAP
// - 251779.zip → Medium Gifts / VAP
// - 256006.zip → Medium MP4
// - normal gift.zip → Normal Gifts
// - lucky gifts bell vap.zip → Lucky Gifts / VAP

const UPDATES = {
  // Love You.svga → SVGA
  'Tgwg0FbzV9LBcOCHupKo': {
    name: 'Love You',
    imageUrl: 'assets/images/gifts/love_you.png',
    category: 'SVGA',
    animationFormat: 'svga',
    tier: 'MEDIUM',
    priceInDiamonds: 520,
  },
  // 138.svga → SVGA
  'vEgsWq5deTbzuyvSloCG': {
    name: 'Moonlight Panda',
    imageUrl: 'assets/images/gifts/moonlight_panda.png',
    category: 'SVGA',
    animationFormat: 'svga',
    tier: 'LUXURY',
    priceInDiamonds: 1380,
  },
  // tencent-VAP-music.zip → VAP
  'PZjkxr8gMffDYFJ4qsAE': {
    name: 'Crystal Windchime',
    imageUrl: 'assets/images/gifts/crystal_windchime.png',
    category: 'VAP',
    animationFormat: 'vap',
    tier: 'LUXURY',
    priceInDiamonds: 2500,
  },
  // 169522.zip → VAP
  'klpyoRCQMkbibDPlRe5G': {
    name: 'Grand Piano',
    imageUrl: 'assets/images/gifts/grand_piano.png',
    category: 'VAP',
    animationFormat: 'vap',
    tier: 'LUXURY',
    priceInDiamonds: 3000,
  },
  // 2529.zip → VAP
  'APOJwtxO9PfKBJz0aSiv': {
    name: 'Gourmet Feast',
    imageUrl: 'assets/images/gifts/gourmet_feast.png',
    category: 'VAP',
    animationFormat: 'vap',
    tier: 'MEDIUM',
    priceInDiamonds: 1500,
  },
  // 251779.zip → Medium Gifts / VAP
  '4Kov1uz5BqFXjkvIkscS': {
    name: 'Sweet Romance',
    imageUrl: 'assets/images/gifts/sweet_romance.png',
    category: 'Medium',
    animationFormat: 'vap',
    tier: 'MEDIUM',
    priceInDiamonds: 800,
  },
  // 256006.zip → Medium MP4
  'x8Mo9Guuiz5XRstpjYkL': {
    name: 'Ruby Excalibur',
    imageUrl: 'assets/images/gifts/flame_excalibur.png',
    category: 'Medium',
    animationFormat: 'mp4',
    tier: 'MEDIUM',
    priceInDiamonds: 600,
  },
  // normal gift.zip → Normal Gifts
  '1KH8e0SllU6TMYt7XysW': {
    name: 'Golden Dates',
    imageUrl: 'assets/images/gifts/golden_dates.png',
    category: 'Normal',
    animationFormat: 'vap',
    tier: 'NORMAL',
    priceInDiamonds: 100,
  },
  // lucky gifts bell vap.zip → Lucky Gifts / VAP
  'adsj76GIQxiSYoPUIHJB': {
    name: 'Golden Bell',
    imageUrl: 'assets/images/gifts/golden_bell.png',
    category: 'Lucky',
    animationFormat: 'vap',
    tier: 'NORMAL',
    priceInDiamonds: 500,
  },
  // 219667 → Luxury VAP
  'bDMkvLHqDMRVvoXonxLn': {
    name: 'Crystal Princess',
    imageUrl: 'assets/images/gifts/crystal_princess.png',
    category: 'Luxury',
    animationFormat: 'vap',
    tier: 'LUXURY',
    priceInDiamonds: 2000,
  },
};

async function patchDoc(token, id, fields) {
  const fieldPaths = Object.keys(fields).map(k => `updateMask.fieldPaths=${k}`).join('&');
  const firestoreFields = {};
  for (const [k, v] of Object.entries(fields)) {
    if (typeof v === 'number') {
      firestoreFields[k] = { integerValue: String(v) };
    } else if (typeof v === 'boolean') {
      firestoreFields[k] = { booleanValue: v };
    } else {
      firestoreFields[k] = { stringValue: String(v) };
    }
  }

  const url = `${API}/gifts/${id}?${fieldPaths}`;
  const res = await fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields: firestoreFields }),
  });

  if (!res.ok) {
    throw new Error(`Failed to update ${id} (${res.status}): ${await res.text()}`);
  }
  console.log(`✅ Updated ${id}: ${fields.name} -> [${fields.category} / ${fields.animationFormat}]`);
}

async function main() {
  const token = await getAccessToken();
  console.log('Updating client gifts in Firestore...');
  for (const [id, fields] of Object.entries(UPDATES)) {
    await patchDoc(token, id, fields);
  }
  console.log('All client gifts successfully updated in Firestore!');
}

main().catch(console.error);
