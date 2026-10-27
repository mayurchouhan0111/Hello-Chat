const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');

const CFG = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
const PROJECT = 'hellochat-e8965';

const CLOUD_NAME = 'dceh4ob2i';
const API_KEY = '256641331991177';
const API_SECRET = 'eNzBz9AxS9d_VF2ebvSoAth18s0';

const IMAGE_PATH = 'C:\\Users\\Lenovo\\.gemini\\antigravity-ide\\brain\\49e9632b-5076-4b8a-a7b2-359ada36af16\\recharge_bonus_event_banner_1792151689903.jpg';

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

function generateSignature(folder, timestamp) {
  const params = `folder=${folder}&timestamp=${timestamp}${API_SECRET}`;
  return crypto.createHash('sha1').update(params).digest('hex');
}

async function uploadToCloudinary(filePath) {
  const timestamp = Math.floor(Date.now() / 1000);
  const folder = 'banners';
  const signature = generateSignature(folder, timestamp);

  const fileBuffer = fs.readFileSync(filePath);
  const blob = new Blob([fileBuffer], { type: 'image/jpeg' });
  const formData = new FormData();
  formData.append('file', blob, 'recharge_bonus_event_banner.jpg');
  formData.append('api_key', API_KEY);
  formData.append('timestamp', timestamp.toString());
  formData.append('signature', signature);
  formData.append('folder', folder);

  const res = await fetch(`https://api.cloudinary.com/v1_1/${CLOUD_NAME}/image/upload`, {
    method: 'POST',
    body: formData,
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Cloudinary upload failed: ${errText}`);
  }

  const data = await res.json();
  return data.secure_url;
}

async function updateFirestoreBanner(newUrl) {
  const token = await refreshToken();
  const bannerId = 'PzEJJAwf7i2RGoc8FMAw';
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/app_banners/${bannerId}?updateMask.fieldPaths=imageUrl&updateMask.fieldPaths=title&updateMask.fieldPaths=subtitle&updateMask.fieldPaths=updatedAt`;

  const res = await fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      fields: {
        imageUrl: { stringValue: newUrl },
        title: { stringValue: 'Recharge Bonus Event' },
        subtitle: { stringValue: '1 $ = 3m coins' },
        updatedAt: { timestampValue: new Date().toISOString() }
      }
    })
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Firestore update failed: ${errText}`);
  }

  console.log('Successfully updated banner in Firestore!');
}

async function main() {
  console.log('Uploading new banner to Cloudinary...');
  const newUrl = await uploadToCloudinary(IMAGE_PATH);
  console.log('Uploaded successfully! URL:', newUrl);

  console.log('Updating banner in Firestore...');
  await updateFirestoreBanner(newUrl);
  console.log('Done!');
}

main().catch(console.error);
