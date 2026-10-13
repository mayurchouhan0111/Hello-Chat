// Gift catalog categorizer for the 3-tier gifting engine.
//
//   node scripts/categorize_gifts.cjs          # report only (safe)
//   node scripts/categorize_gifts.cjs --apply  # write changes + backup
//
// Auth: reuses the firebase CLI's own refresh token (the service-account
// key in this folder was rotated server-side and no longer works).
// Normalizes legacy seed categories into the client's shelf list:
//   small/standard/gift/special -> Normal
//   luxury                      -> Luxury
//   lucky fruit                 -> Lucky
// Everything else is left untouched (admin can still edit legacy values).
const fs = require('fs');
const path = require('path');
const os = require('os');

const PROJECT = 'hellochat-e8965';
const API = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const SHELF = ['Normal', 'Lucky', 'Medium', 'Luxury', 'CP', 'Custom', 'Family Battle', 'VIP', 'SVIP'];
const MAP = {
  small: 'Normal',
  standard: 'Normal',
  gift: 'Normal',
  special: 'Normal',
  luxury: 'Luxury',
  'lucky fruit': 'Lucky',
  relationship: 'CP',
};
const SCOPES = [
  'https://www.googleapis.com/auth/cloud-platform',
  '',
];
const SCOPE_ERRORS = new Set(['invalid_scope', 'restricted_client']);

function derivedTier(category, tier) {
  const t = String(tier || '').toUpperCase();
  if (['NORMAL', 'MEDIUM', 'LUXURY'].includes(t)) return t;
  const c = String(category || '').toUpperCase();
  if (c === 'MEDIUM') return 'MEDIUM';
  if (c === 'LUXURY') return 'LUXURY';
  return 'NORMAL';
}

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
  const client_secret = 'j9iVZfS8kkCEFUPaAeJV0sAi'; // public constant in firebase-tools/lib/api.js
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
    if (SCOPE_ERRORS.has(json.error)) continue;
    if (res.status === 400 || res.status === 401) {
      throw new Error(`Token exchange failed: ${JSON.stringify(json)} — run: firebase login --reauth`);
    }
    throw new Error(`Token exchange failed: ${JSON.stringify(json)}`);
  }
  throw new Error('Refresh token lacks required scopes — run: firebase login --reauth');
}

const val = (f) => (f == null ? '' : f.stringValue ?? f.integerValue ?? f.doubleValue ?? '');

async function listGifts(token) {
  const docs = [];
  let pageToken = '';
  do {
    const url = `${API}/gifts?pageSize=300${pageToken ? `&pageToken=${pageToken}` : ''}`;
    const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
    if (!res.ok) throw new Error(`List failed ${res.status}: ${await res.text()}`);
    const json = await res.json();
    for (const d of json.documents || []) {
      const id = d.name.split('/').pop();
      docs.push({ id, name: val(d.fields?.name), category: val(d.fields?.category), tier: val(d.fields?.tier) });
    }
    pageToken = json.nextPageToken || '';
  } while (pageToken);
  return docs;
}

async function updateGift(token, id, category) {
  const res = await fetch(`${API}/gifts/${id}?updateMask.fieldPaths=category`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields: { category: { stringValue: category } } }),
  });
  if (!res.ok) throw new Error(`Update ${id} failed ${res.status}: ${await res.text()}`);
}

(async () => {
  const apply = process.argv.includes('--apply');
  const token = await getAccessToken();
  const gifts = await listGifts(token);

  const dist = {};
  const changes = [];
  for (const g of gifts) {
    dist[g.category] = (dist[g.category] || 0) + 1;
    const target = MAP[String(g.category).toLowerCase().trim()];
    if (target && target !== g.category) changes.push({ ...g, to: target, tier: derivedTier(target, g.tier) });
  }

  console.log(`=== ${gifts.length} gifts in catalog ===`);
  console.log('Category distribution:');
  for (const [cat, n] of Object.entries(dist).sort((a, b) => b[1] - a[1])) {
    const onShelf = SHELF.some((s) => s.toLowerCase() === String(cat).toLowerCase());
    console.log(`  ${onShelf ? 'OK     ' : 'LEGACY '} ${String(cat).padEnd(16)} x${n}`);
  }

  console.log(`\n${changes.length} doc(s) need remapping:`);
  for (const c of changes) console.log(`  ${c.id}  "${c.name}"  ${c.category} -> ${c.to}  (plays as ${c.tier})`);

  if (!apply) {
    console.log('\nReport only. Re-run with --apply to write (a backup JSON is saved first).');
  } else if (changes.length === 0) {
    console.log('\nNothing to change.');
  } else {
    const backup = {};
    for (const g of gifts) backup[g.id] = { name: g.name, category: g.category, tier: g.tier };
    const backupPath = path.join(__dirname, `gifts_backup_${Date.now()}.json`);
    fs.writeFileSync(backupPath, JSON.stringify(backup, null, 2));
    for (const c of changes) await updateGift(token, c.id, c.to);
    console.log(`\nApplied ${changes.length} update(s). Backup: ${backupPath}`);
  }
  process.exit(0);
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
