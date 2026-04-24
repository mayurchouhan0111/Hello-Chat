
const admin = require('firebase-admin');
if (!admin.apps.length) {
    admin.initializeApp({
        projectId: 'hellochat-e8965'
    });
}
const db = admin.firestore();

async function checkTransactions() {
    console.log("--- Checking Transactions ---");
    const snap = await db.collection("transactions").orderBy("timestamp", "desc").limit(5).get();
    if (snap.empty) {
        console.log("No transactions found in the collection.");
    } else {
        snap.forEach(doc => {
            console.log(`ID: ${doc.id}`);
            console.log(JSON.stringify(doc.data(), null, 2));
            console.log("---");
        });
    }
}

checkTransactions();
