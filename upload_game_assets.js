// Uploads game/gift animations exactly the way the Admin Panel does:
//   Storage  gifts/animation_<ts>_<file>   (or gifts/image_<ts>_<file> for icons)
//   Firestore gifts/<autoId>               (same field set as GiftManagement.handleSave)
const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

const ROOT = path.join(__dirname, 'assets', 'animations', 'gifts');
admin.initializeApp({
  credential: admin.credential.cert(path.join(__dirname, 'scripts', 'service-account-key.json')),
  storageBucket: 'hellochat-e8965.appspot.com',
});
const bucket = admin.storage().bucket();
const db = admin.firestore();

// name, rel path, animationFormat | mode
const TARGETS = [
  { name: 'Game 138',            rel: '138.svga',            fmt: 'svga' },
  { name: 'Love You',            rel: 'Love You.svga',       fmt: 'svga' },
  { name: 'New Game Lottie',     rel: 'data.json',           fmt: 'json' },
  { name: 'VAP 169522',          rel: '169522/video.mp4',    fmt: 'mp4' },
  { name: 'VAP 219667',          rel: '219667/video.mp4',    fmt: 'mp4' },
  { name: 'VAP 251779',          rel: '251779/video.mp4',    fmt: 'mp4' },
  { name: 'VAP 2529',            rel: '2529/video.mp4',      fmt: 'mp4' },
  { name: 'VAP 256006',          rel: '256006/video.mp4',    fmt: 'mp4' },
  { name: 'VAP Music',           rel: 'tencent-VAP-music/video.mp4', fmt: 'mp4' },
  { name: 'VAP Lucky Bell',      rel: 'lucky gifts bell vap/lucky gifts bell vap/video.mp4', fmt: 'mp4' },
  { name: 'VAP Lucky Dates',     rel: 'normal gift/lucky gift dates/video.mp4', fmt: 'mp4' },
];

// The image-sequence Lottie is intentionally absent: it references external
// images/img_*.png, which cannot resolve against a flat Firebase Storage URL.

async function upload(rel, kind) {
  const abs = path.join(ROOT, rel);
  if (!fs.existsSync(abs)) throw new Error('missing source: ' + rel);
  const file = fs.readFileSync(abs);
  const dest = `gifts/${kind}_${Date.now()}_${path.basename(rel)}`;
  await bucket.file(dest).save(file, { resumable: false, metadata: { contentType: kind === 'image' ? 'image/png' : undefined } });
  const [url] = await bucket.file(dest).getSignedUrl({ action: 'read', expires: '2100-01-01' });
  // Admin panel uses getDownloadURL (token style). Emulate it for identical shape.
  const token = `${Date.now()}-${Math.random().toString(36).slice(2)}`;
  await bucket.file(dest).setMetadata({ metadata: { firebaseStorageDownloadTokens: token } });
  return `https://firebasestorage.googleapis.com/v0/b/hellochat-e8965.appspot.com/o/${encodeURIComponent(dest).replace(/%2F/g, '%2F')}?alt=media&token=${token}`;
}

async function main() {
  let iconUrl = '';
  // gift icon (the ???? .png next to data.json)
  const icons = fs.readdirSync(ROOT).filter((f) => f.toLowerCase().endsWith('.png'));
  if (icons.length) {
    iconUrl = await upload(icons[0], 'image');
    console.log(`icon      ${icons[0]} -> ${iconUrl.slice(0, 70)}...`);
  }

  let order = 200;
  for (const t of TARGETS) {
    const url = await upload(t.rel, 'animation');
    const id = db.collection('gifts').doc().id;
    const ref = db.collection('gifts').doc(id);
    await ref.set({
      name: t.name,
      priceInDiamonds: 100,
      category: 'Normal',
      imageUrl: iconUrl,
      lottieAssetPath: url,
      soundUrl: '',
      animationFormat: t.fmt,
      tier: '',
      durationMs: 0,
      minSvipLevel: 0,
      sortOrder: order++,
      isActive: true,
      giftId: id,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: false });
    console.log(`uploaded  ${t.rel} -> ${t.fmt}  doc=${id}`);
  }
  console.log('DONE');
}
main().catch((e) => { console.error('FAILED:', e.message); process.exit(1); });
