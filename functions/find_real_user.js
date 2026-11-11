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
  console.log("=== Searching for users with phone or ID ===");
  const snap = await db.collection("users").get();
  snap.forEach(d => {
    const data = d.data();
    const phone = data.phoneNumber || "";
    const name = data.displayName || "";
    const helloId = String(data.helloId || "");
    if (phone.includes("6263850508") || helloId.includes("1001") || name === "V" || name.includes("RESELLER")) {
      console.log(`FOUND: docId=${d.id} | helloId=${data.helloId} | name=${data.displayName} | phone=${data.phoneNumber} | email=${data.email} | role=${data.role} | diamonds=${data.diamondBalance}`);
    }
  });

  console.log("\n=== Checking Auth users ===");
  try {
    const authUsers = await auth.listUsers(100);
    authUsers.users.forEach(u => {
      if (u.phoneNumber?.includes("6263850508") || u.email?.includes("6263850508")) {
        console.log(`AUTH USER: uid=${u.uid} | phone=${u.phoneNumber} | email=${u.email} | providers=`, u.providerData.map(p => p.providerId));
      }
    });
  } catch (e) {
    console.error("Auth list error:", e.message);
  }
}

run().catch(console.error).finally(() => process.exit(0));

