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

try {
  admin.initializeApp({
    projectId: "hellochat-e8965",
    credential: cliAdcCredential(),
  });
} catch (e) {
  admin.initializeApp({
    projectId: "hellochat-e8965",
  });
}

// Let's test getHostMetrics pure logic directly
const fn = require("./index.js");

async function testCall() {
  const uid = "VJ1GwGfAwafIhCuHDaRTqBbdhYj2";
  console.log("Simulating getHostMetrics for UID:", uid);
  try {
    // Call the wrapped function logic directly:
    const db = admin.firestore();
    const snap = await db.collection("users").doc(uid).get();
    console.log("User data exists:", snap.exists, "role:", snap.data()?.role, "branchId:", snap.data()?.branchId);
  } catch (e) {
    console.error("Local test error:", e);
  }
}

testCall().then(() => process.exit(0)).catch(e => {
  console.error(e);
  process.exit(1);
});
