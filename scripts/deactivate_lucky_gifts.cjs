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

const LUCKY_GIFT_IDS = [
  'adsj76GIQxiSYoPUIHJB',
  'lucky_bell',
  'lucky_chest',
  'lucky_fruit',
  'lucky_star'
];

async function main() {
  const token = await refreshToken();
  for (const id of LUCKY_GIFT_IDS) {
    const url = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/gifts/${id}?updateMask.fieldPaths=isActive`;
    const res = await fetch(url, {
      method: 'PATCH',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        fields: {
          isActive: { booleanValue: false }
        }
      })
    });
    if (res.ok) {
      console.log(`Deactivated lucky gift [${id}]`);
    } else {
      console.error(`Failed to deactivate [${id}]:`, await res.text());
    }
  }
}

main().catch(console.error);
