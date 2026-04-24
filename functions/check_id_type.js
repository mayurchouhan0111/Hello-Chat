
const admin = require('firebase-admin');
if (!admin.apps.length) {
    admin.initializeApp({
        projectId: 'hellochat-e8965'
    });
}
const db = admin.firestore();

async function checkIdType() {
    console.log("--- Checking User ID Types ---");
    const snap = await db.collection("users").limit(1).get();
    if (snap.empty) {
        console.log("No users found.");
    } else {
        const data = snap.docs[0].data();
        console.log(`User: ${data.displayName}`);
        console.log(`helloId: ${data.helloId} (${typeof data.helloId})`);
    }
}

checkIdType();
