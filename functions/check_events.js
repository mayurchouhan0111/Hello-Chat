const admin = require('firebase-admin');
try {
  admin.initializeApp();
} catch (e) {}

const db = admin.firestore();

async function check() {
  const snapshot = await db.collection('gift_events').get();
  console.log('Gift events count:', snapshot.size);
  snapshot.forEach(doc => {
    const data = doc.data();
    console.log(`- [${doc.id}] ${data.title} | enabled: ${data.enabled} | status: ${data.status} | start: ${data.startDate?.toDate ? data.startDate.toDate().toISOString() : data.startDate} | end: ${data.endDate?.toDate ? data.endDate.toDate().toISOString() : data.endDate}`);
  });
}

check().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
