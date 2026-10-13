process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8085';
const admin = require('firebase-admin');
if (!admin.apps.length) {
    admin.initializeApp({ projectId: 'hello-chat-app' });
}
const db = admin.firestore();

async function main() {
    const s = await db.collection('gifts').limit(5).get();
    console.log('Gifts count in emulator:', s.size);
    s.forEach(d => {
        console.log('Doc ID:', d.id);
        console.log(JSON.stringify(d.data(), null, 2));
    });
}

main().then(() => process.exit(0)).catch(e => {
    console.error(e);
    process.exit(1);
});
