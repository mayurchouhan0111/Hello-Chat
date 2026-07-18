const admin = require('firebase-admin');
if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'hellochat-e8965' });
}
const db = admin.firestore();

async function printSettings() {
  const doc = await db.collection('game_settings').doc('lucky_spin').get();
  if (doc.exists) {
    console.log('--- LUCKY SPIN SETTINGS ---');
    console.log(JSON.stringify(doc.data(), null, 2));
  } else {
    console.log('Document lucky_spin does not exist!');
  }
}

printSettings().catch(console.error);
