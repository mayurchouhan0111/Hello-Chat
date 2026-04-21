const admin = require('firebase-admin');
if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'hellochat-e8965' });
}
const db = admin.firestore();

async function check() {
  const noble = await db.collection('noble_tiers').get();
  const vip = await db.collection('vip_tiers').get();
  console.log('--- DB SUMMARY ---');
  console.log('Noble Tiers Count:', noble.size);
  console.log('VIP Tiers Count:', vip.size);
  if (noble.size > 0) console.log('First Noble:', noble.docs[0].id, noble.docs[0].data());
}

check().catch(console.error);
