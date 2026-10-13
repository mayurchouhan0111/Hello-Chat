const path = require("path");
const os = require("os");
const fs = require("fs");
const admin = require("firebase-admin");

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

try {
  admin.initializeApp({
    projectId: "hellochat-e8965",
  });
} catch(e) {}

const db = admin.firestore();
const auth = admin.auth();

async function grantApex() {
  const uids = ["VJ1GwGfAwafIhCuHDaRTqBbdhYj2", "wTFYRh1bCUWseZWR4SqrvHyHO8f2"];
  for (const uid of uids) {
    console.log(`Setting apex owner & superadmin for UID: ${uid}`);
    await db.collection("users").doc(uid).update({
      role: "owner",
      tags: admin.firestore.FieldValue.arrayUnion("Owner", "SuperAdmin", "Admin"),
      isSuperAdmin: true,
      isAdmin: true,
      isOwner: true,
      roleUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log(`  Updated Firestore doc: role='owner', tags includes 'Owner', 'SuperAdmin', 'Admin'`);

    try {
      await auth.setCustomUserClaims(uid, {
        role: "owner",
        owner: true,
        superadmin: true,
        admin: true
      });
      console.log(`  Updated Auth custom claims: { role: 'owner', owner: true, superadmin: true, admin: true }`);
    } catch(err) {
      console.error(`  Auth claim error:`, err.message);
    }
  }
}

grantApex().then(() => {
  console.log("Successfully granted Apex access to both test accounts!");
  process.exit(0);
}).catch(e => {
  console.error("Error:", e);
  process.exit(1);
});
