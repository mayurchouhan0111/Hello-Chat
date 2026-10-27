const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');

const CFG = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
const PROJECT = 'hellochat-e8965';

const CLOUD_NAME = 'dceh4ob2i';
const API_KEY = '256641331991177';
const API_SECRET = 'eNzBz9AxS9d_VF2ebvSoAth18s0';

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

async function uploadIconToCloudinary(giftId, filePath) {
  if (!fs.existsSync(filePath)) {
    console.warn(`File not found: ${filePath}, using local path`);
    return `assets/images/gifts/${giftId}.png`;
  }
  const timestamp = Math.floor(Date.now() / 1000);
  const folder = 'gifts/icons';
  const signature = generateSignature(folder, timestamp);

  const fileBuffer = fs.readFileSync(filePath);
  const blob = new Blob([fileBuffer], { type: 'image/png' });
  const formData = new FormData();
  formData.append('file', blob, `${giftId}.png`);
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
    console.warn(`Cloudinary upload failed for ${giftId}: ${errText}, falling back to asset path`);
    return `assets/images/gifts/${giftId}.png`;
  }

  const data = await res.json();
  return data.secure_url;
}

const vapCatalog = [
  // NORMAL
  {
    giftId: 'vap_gift_12',
    name: 'Mini Rose',
    assetPath: 'assets/gifts-vap/gift_12.vap',
    tier: 'NORMAL',
    durationMs: 5333,
    priceInDiamonds: 10,
    sortOrder: 1,
  },
  {
    giftId: 'vap_gift_11',
    name: 'Twinkle Star',
    assetPath: 'assets/gifts-vap/gift_11.vap',
    tier: 'NORMAL',
    durationMs: 6000,
    priceInDiamonds: 20,
    sortOrder: 2,
  },
  {
    giftId: 'vap_gift_10',
    name: 'Candy Heart',
    assetPath: 'assets/gifts-vap/gift_10.vap',
    tier: 'NORMAL',
    durationMs: 6667,
    priceInDiamonds: 50,
    sortOrder: 3,
  },
  // MEDIUM
  {
    giftId: 'vap_gift_2',
    name: 'Sweet Bear',
    assetPath: 'assets/gifts-vap/gift_2.vap',
    tier: 'MEDIUM',
    durationMs: 7800,
    priceInDiamonds: 200,
    sortOrder: 4,
  },
  {
    giftId: 'vap_gift_1',
    name: 'Aurora Lights',
    assetPath: 'assets/gifts-vap/gift_1.vap',
    tier: 'MEDIUM',
    durationMs: 9600,
    priceInDiamonds: 300,
    sortOrder: 5,
  },
  {
    giftId: 'vap_gift_3',
    name: 'Neon Heart',
    assetPath: 'assets/gifts-vap/gift_3.vap',
    tier: 'MEDIUM',
    durationMs: 9600,
    priceInDiamonds: 300,
    sortOrder: 6,
  },
  {
    giftId: 'vap_gift_4',
    name: 'Pink Kiss',
    assetPath: 'assets/gifts-vap/gift_4.vap',
    tier: 'MEDIUM',
    durationMs: 10000,
    priceInDiamonds: 500,
    sortOrder: 7,
  },
  {
    giftId: 'vap_gift_5',
    name: 'Rhythm Bell',
    assetPath: 'assets/gifts-vap/gift_5.vap',
    tier: 'MEDIUM',
    durationMs: 10000,
    priceInDiamonds: 500,
    sortOrder: 8,
  },
  {
    giftId: 'vap_gift_6',
    name: 'Heart Wand',
    assetPath: 'assets/gifts-vap/gift_6.vap',
    tier: 'MEDIUM',
    durationMs: 10000,
    priceInDiamonds: 800,
    sortOrder: 9,
  },
  {
    giftId: 'vap_gift_7',
    name: 'Treasure Chest',
    assetPath: 'assets/gifts-vap/gift_7.vap',
    tier: 'MEDIUM',
    durationMs: 10000,
    priceInDiamonds: 1000,
    sortOrder: 10,
  },
  // LUXURY
  {
    giftId: 'vap_gift_9',
    name: 'Crystal Castle',
    assetPath: 'assets/gifts-vap/gift_9.vap',
    tier: 'LUXURY',
    durationMs: 11900,
    priceInDiamonds: 2000,
    sortOrder: 11,
  },
  {
    giftId: 'vap_gift_8',
    name: 'Royal Crown',
    assetPath: 'assets/gifts-vap/gift_8.vap',
    tier: 'LUXURY',
    durationMs: 15567,
    priceInDiamonds: 5000,
    sortOrder: 12,
  },
];

async function seedVapGifts() {
  console.log('--- SEEDING 12 TENCENT VAP GIFTS TO FIRESTORE ---');
  const token = await refreshToken();

  for (const gift of vapCatalog) {
    const iconLocalPath = path.join(__dirname, '..', 'assets', 'images', 'gifts', `${gift.giftId}.png`);
    console.log(`\nProcessing ${gift.giftId} ("${gift.name}")...`);
    
    let uploadedUrl = '';
    try {
      uploadedUrl = await uploadIconToCloudinary(gift.giftId, iconLocalPath);
      console.log(`  Uploaded icon: ${uploadedUrl}`);
    } catch (e) {
      console.warn(`  Failed uploading icon: ${e.message}`);
      uploadedUrl = `assets/images/gifts/${gift.giftId}.png`;
    }

    const docUrl = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/gifts/${gift.giftId}`;
    const payload = {
      fields: {
        giftId: { stringValue: gift.giftId },
        name: { stringValue: gift.name },
        priceInDiamonds: { integerValue: gift.priceInDiamonds },
        category: { stringValue: gift.tier.toLowerCase() },
        tier: { stringValue: gift.tier },
        imageUrl: { stringValue: uploadedUrl },
        lottieAssetPath: { stringValue: gift.assetPath },
        soundUrl: { stringValue: '' },
        animationFormat: { stringValue: 'vap' },
        durationMs: { integerValue: gift.durationMs },
        minSvipLevel: { integerValue: 0 },
        sortOrder: { integerValue: gift.sortOrder },
        isActive: { booleanValue: true },
        updatedAt: { timestampValue: new Date().toISOString() }
      }
    };

    const res = await fetch(docUrl, {
      method: 'PATCH',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    });

    if (!res.ok) {
      const errText = await res.text();
      console.error(`  ❌ Failed seeding ${gift.giftId}: ${errText}`);
    } else {
      console.log(`  ✅ Successfully seeded ${gift.giftId} to Firestore!`);
    }
  }

  console.log('\n--- ALL 12 VAP GIFTS SEEDED SUCCESSFULLY! ---');
}

seedVapGifts().catch(console.error);
