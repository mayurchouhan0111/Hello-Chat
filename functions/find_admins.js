
const admin = require('firebase-admin');
if (!admin.apps.length) {
    admin.initializeApp({
        projectId: 'hellochat-e8965'
    });
}
const db = admin.firestore();

async function findAdmins() {
    console.log("--- Finding Admins ---");
    const snap = await db.collection("users").get();
    let found = false;
    snap.forEach(doc => {
        const data = doc.data();
        const tags = data.tags || [];
        if (tags.includes("Admin") || tags.includes("SuperAdmin") || data.isReseller) {
            console.log(`User: ${data.displayName || 'Unnamed'} (@${data.username})`);
            console.log(`UID: ${doc.id}`);
            console.log(`Tags: ${tags.join(', ')}`);
            console.log(`isReseller: ${data.isReseller}`);
            console.log("---");
            found = true;
        }
    });
    if (!found) console.log("No admins found.");
}

findAdmins();
