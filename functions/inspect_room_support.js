const admin = require('firebase-admin');

async function check(name, host) {
    console.log(`=== Checking ${name} (${host || 'Production'}) ===`);
    try {
        if (host) {
            process.env.FIRESTORE_EMULATOR_HOST = host;
        } else {
            delete process.env.FIRESTORE_EMULATOR_HOST;
        }
        const appName = 'app_' + name;
        const app = admin.initializeApp({ projectId: 'hello-chat-app' }, appName);
        const db = app.firestore();
        const doc = await db.collection('room_support_configs').doc('settings').get();
        if (doc.exists) {
            console.log('Document exists!');
            const data = doc.data();
            console.log('Levels count:', data.levels?.length);
            console.log('Levels full:', JSON.stringify(data.levels, null, 2));
        } else {
            console.log('Document does NOT exist in ' + name);
        }
    } catch (e) {
        console.error('Error:', e.message);
    }
}

async function main() {
    await check('emulator', '127.0.0.1:8085');
}

main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
