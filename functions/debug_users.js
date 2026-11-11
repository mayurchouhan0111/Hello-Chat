const admin = require('firebase-admin');
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'hellochat-e8965'
  });
}
const db = admin.firestore();
const auth = admin.auth();

async function run() {
  console.log("=== Checking users with displayName 'V' ===");
  const snap = await db.collection('users').where('displayName', '==', 'V').get();
  for (const d of snap.docs) {
    const data = d.data();
    console.log(`UID: ${d.id}`);
    console.log(`  helloId: ${data.helloId}`);
    console.log(`  phone: ${data.phoneNumber}`);
    console.log(`  email: ${data.email}`);
    console.log(`  phoneEmail: ${data.phoneEmail}`);
    console.log(`  hasPassword: ${data.hasPassword}`);
    try {
      const authUser = await auth.getUser(d.id);
      console.log(`  Auth Providers:`, authUser.providerData.map(p => ({ id: p.providerId, email: p.email, phone: p.phoneNumber })));
    } catch (e) {
      console.log(`  Auth Error: ${e.message}`);
    }
  }

  console.log("\n=== Checking 5 Most Recent Users in Firestore ===");
  const recent = await db.collection('users').orderBy('createdAt', 'desc').limit(5).get();
  for (const d of recent.docs) {
    const data = d.data();
    console.log(`UID: ${d.id} | helloId: ${data.helloId} | phone: ${data.phoneNumber} | email: ${data.email} | name: ${data.displayName}`);
    try {
      const authUser = await auth.getUser(d.id);
      console.log(`  Auth Providers:`, authUser.providerData.map(p => ({ id: p.providerId, email: p.email, phone: p.phoneNumber })));
    } catch (e) {
      console.log(`  Auth Error: ${e.message}`);
    }
  }
}

run().catch(console.error).finally(() => process.exit(0));

