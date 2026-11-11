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

async function run() {
  console.log("=== Checking users with helloId: 5473654825 (New User) ===");
  const snap1 = await db.collection("users").where("helloId", "in", [5473654825, "5473654825"]).get();
  snap1.forEach(d => console.log("New User Doc:", d.id, d.data()));

  console.log("\n=== Checking users with helloId: 1001 or 1000001001 or displayName 'V' ===");
  const snap2 = await db.collection("users").where("displayName", "==", "V").get();
  snap2.forEach(d => console.log("Real User V Doc:", d.id, "helloId=", d.data().helloId, "phone=", d.data().phoneNumber, "diamonds=", d.data().diamondBalance));
}

run().catch(console.error).finally(() => process.exit(0));

