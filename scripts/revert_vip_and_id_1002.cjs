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

async function run() {
  const tok = await refreshToken();
  const uid = 'PhFe53EOGzRxricZKawdA4DARcz2';
  
  // Revert helloId to 100003, remove prettyId, revert vipTier to VIP 1, reset XP and level
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users/${uid}?updateMask.fieldPaths=helloId&updateMask.fieldPaths=prettyId&updateMask.fieldPaths=vipTier&updateMask.fieldPaths=level&updateMask.fieldPaths=xp&updateMask.fieldPaths=benchXP&updateMask.fieldPaths=dailyXP&updateMask.fieldPaths=weeklyXP&updateMask.fieldPaths=monthlyXP&updateMask.fieldPaths=chatBubble&updateMask.fieldPaths=equippedMicWave&updateMask.fieldPaths=entryAnimation&updateMask.fieldPaths=badgeIcon&updateMask.fieldPaths=equippedCrown`;
  
  const res = await fetch(url, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${tok}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        helloId: { integerValue: 100003 },
        prettyId: { nullValue: null },
        vipTier: { stringValue: 'VIP 1' },
        level: { integerValue: 1 },
        xp: { integerValue: 0 },
        benchXP: { integerValue: 0 },
        dailyXP: { integerValue: 0 },
        weeklyXP: { integerValue: 0 },
        monthlyXP: { integerValue: 0 },
        chatBubble: { nullValue: null },
        equippedMicWave: { nullValue: null },
        entryAnimation: { nullValue: null },
        badgeIcon: { stringValue: 'assets/VIP/VIP 1/Crown 1.svga' },
        equippedCrown: { nullValue: null }
      }
    })
  });
  console.log('Reverted user 1002 back to original Hello ID 100003, Level 1, VIP 1:', res.status);
}

run().catch(console.error);
