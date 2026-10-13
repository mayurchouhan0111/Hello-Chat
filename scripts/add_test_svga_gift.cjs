// One-off: registers the client-supplied SVGA test gift in Firestore.
// The animation plays from the bundled local asset (assets/svga/cat_gift.svga),
// so no Cloudinary upload is needed — see SvgaParserUtil.getLocalGiftSvgaPath.
//
//   node scripts/add_test_svga_gift.cjs
const fs = require('fs');
const path = require('path');
const os = require('os');

const PROJECT = 'hellochat-e8965';
const API = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const DOC = 'cat_gift';

const GIFT = {
  giftId: { stringValue: DOC },
  name: { stringValue: 'Cat Gift (SVGA Test)' },
  priceInDiamonds: { integerValue: '100' },
  category: { stringValue: 'Normal' },
  imageUrl: { stringValue: '🐱' },
  lottieAssetPath: { stringValue: 'https://local.test/cat_gift.svga' },
  soundUrl: { stringValue: '' },
  animationFormat: { stringValue: 'svga' },
  tier: { stringValue: '' },
  durationMs: { integerValue: '0' },
  minSvipLevel: { integerValue: '0' },
  sortOrder: { integerValue: '990' },
  isActive: { booleanValue: true },
  createdAt: { timestampValue: new Date().toISOString() },
  updatedAt: { timestampValue: new Date().toISOString() },
};

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
  throw new Error('No firebase CLI refresh token found. Run: firebase login');
}

async function getAccessToken() {
  const refresh_token = readRefreshToken();
  const client_id = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
  const client_secret = 'j9iVZfS8kkCEFUPaAeJV0sAi';
  for (const scope of ['https://www.googleapis.com/auth/cloud-platform', '']) {
    const body = new URLSearchParams({ refresh_token, client_id, client_secret, grant_type: 'refresh_token' });
    if (scope) body.set('scope', scope);
    const res = await fetch('https://www.googleapis.com/oauth2/v3/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body,
    });
    const json = await res.json().catch(() => ({}));
    if (json.access_token) return json.access_token;
    if (res.status === 400 || res.status === 401) {
      throw new Error(`Token exchange failed: ${JSON.stringify(json)} — run: firebase login --reauth`);
    }
  }
  throw new Error('Refresh token lacks required scopes — run: firebase login --reauth');
}

(async () => {
  const token = await getAccessToken();
  const res = await fetch(`${API}/gifts/${DOC}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields: GIFT }),
  });
  if (!res.ok) throw new Error(`Upsert failed ${res.status}: ${await res.text()}`);
  console.log(`OK: gifts/${DOC} written (Normal tab, plays local assets/svga/cat_gift.svga)`);
  process.exit(0);
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
