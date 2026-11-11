const path = require("path");
const os = require("os");
const fs = require("fs");
const admin = require("firebase-admin");

function cliAdcCredential() {
  const cfg = JSON.parse(fs.readFileSync(
    path.join(os.homedir(), ".config", "configstore", "firebase-tools.json"), "utf8"));
  const file = path.join(os.tmpdir(), "hc_adc.json");
  fs.writeFileSync(file, JSON.stringify({
    type: "authorized_user",
    client_id: "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com",
    client_secret: "j9iVZfS8kkCEFUPaAeJV0sAi",
    refresh_token: cfg.tokens.refresh_token,
  }, null, 2), { mode: 0o600 });
  process.env.GOOGLE_APPLICATION_CREDENTIALS = file;
  return admin.credential.applicationDefault();
}

admin.initializeApp({
  projectId: "hellochat-e8965",
  credential: cliAdcCredential(),
});

const db = admin.firestore();
const auth = admin.auth();

async function inspect() {
  try {
    const userDoc = await db.collection('users').doc('VJ1GwGfAwafIhCuHDaRTqBbdhYj2').get();
    console.log("=== FIRESTORE users/VJ1GwGfAwafIhCuHDaRTqBbdhYj2 ===");
    console.log(JSON.stringify(userDoc.data(), null, 2));

    const authUser = await auth.getUser('VJ1GwGfAwafIhCuHDaRTqBbdhYj2');
    console.log("=== FIREBASE AUTH USER ===");
    console.log({
      uid: authUser.uid,
      phoneNumber: authUser.phoneNumber,
      email: authUser.email,
      providerData: authUser.providerData.map(p => ({ providerId: p.providerId, uid: p.uid, email: p.email, phoneNumber: p.phoneNumber })),
      customClaims: authUser.customClaims
    });
  } catch (e) {
    console.error("Error inspecting:", e);
  }
}

inspect().finally(() => process.exit(0));
