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

async function run() {
  console.log("=== All users in Firestore users collection ===");
  const snap = await db.collection("users").get();
  console.log(`Total users in Firestore: ${snap.size}`);
  snap.forEach(d => {
    const data = d.data();
    console.log(`${d.id} | helloId=${data.helloId} | name=${data.displayName} | phone=${data.phoneNumber} | diamonds=${data.diamondBalance} | role=${data.role}`);
  });
}

run().catch(console.error).finally(() => process.exit(0));

