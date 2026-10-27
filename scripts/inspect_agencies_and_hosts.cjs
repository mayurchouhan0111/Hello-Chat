const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function run() {
  console.log("=== AUDIT: AGENCIES & HOSTS IN FIRESTORE ===");
  
  // 1. Check 'agencies' collection
  try {
    const agenciesSnap = await db.collection('agencies').get();
    console.log(`[agencies collection] Document count: ${agenciesSnap.size}`);
    agenciesSnap.forEach(doc => {
      console.log(` - Agency doc id: ${doc.id}, data:`, JSON.stringify(doc.data()));
    });
  } catch (e) {
    console.log(`[agencies collection] Error:`, e.message);
  }

  // 2. Check users with isAgencyOwner == true or role == 'agency'
  try {
    const agencyOwnersSnap = await db.collection('users')
      .where('isAgencyOwner', '==', true)
      .get();
    console.log(`[users where isAgencyOwner == true] Count: ${agencyOwnersSnap.size}`);
    agencyOwnersSnap.forEach(doc => {
      const d = doc.data();
      console.log(` - User ${doc.id}: name="${d.displayName}", helloId=${d.helloId}, role=${d.role}, isAgencyOwner=${d.isAgencyOwner}, agencyId=${d.agencyId}`);
    });
  } catch (e) {
    console.log(`[users isAgencyOwner] Error:`, e.message);
  }

  try {
    const agencyRoleSnap = await db.collection('users')
      .where('role', '==', 'agency')
      .get();
    console.log(`[users where role == 'agency'] Count: ${agencyRoleSnap.size}`);
    agencyRoleSnap.forEach(doc => {
      const d = doc.data();
      console.log(` - User ${doc.id}: name="${d.displayName}", helloId=${d.helloId}, role=${d.role}, isAgencyOwner=${d.isAgencyOwner}`);
    });
  } catch (e) {
    console.log(`[users role=='agency'] Error:`, e.message);
  }

  // 3. Check hosts (isHost == true or has agencyId)
  try {
    const hostsWithAgencySnap = await db.collection('users')
      .where('agencyId', '!=', null)
      .get();
    console.log(`[users where agencyId != null] Count: ${hostsWithAgencySnap.size}`);
    hostsWithAgencySnap.forEach(doc => {
      const d = doc.data();
      console.log(` - Host ${doc.id}: name="${d.displayName}", helloId=${d.helloId}, agencyId=${d.agencyId}, isHost=${d.isHost}`);
    });
  } catch (e) {
    console.log(`[users agencyId != null] Error:`, e.message);
  }

  try {
    const isHostSnap = await db.collection('users')
      .where('isHost', '==', true)
      .get();
    console.log(`[users where isHost == true] Count: ${isHostSnap.size}`);
  } catch (e) {
    console.log(`[users isHost == true] Error:`, e.message);
  }

  process.exit(0);
}

run().catch(err => {
  console.error("Fatal:", err);
  process.exit(1);
});
