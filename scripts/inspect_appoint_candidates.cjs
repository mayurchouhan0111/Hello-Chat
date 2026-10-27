/** Read-only: inspect the two appointment targets and potential callers. */
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

admin.initializeApp({ projectId: "hellochat-e8965", credential: cliAdcCredential() });
const db = admin.firestore();

const TARGETS = ["3607188625", "HgrLl9ubSmcZ0LdWi05MS0jHGvu1",
                 "1805742773", "aRdHp4qLLKdd8qUoVTcgTcpZpKf2"];

async function main() {
  for (const id of TARGETS) {
    const byDoc = await db.collection("users").doc(id).get();
    let snap = byDoc;
    if (!byDoc.exists) {
      const q = await db.collection("users").where("helloId", "==", Number(id)).limit(1).get();
      snap = q.docs[0] || null;
    }
    if (!snap || !snap.exists) { console.log(id, "-> NOT FOUND"); continue; }
    const d = snap.data();
    console.log(`${id} -> uid=${snap.id} role=${d.role} branchId=${d.branchId || null} ` +
      `tags=${JSON.stringify(d.tags || [])} isAgencyOwner=${!!d.isAgencyOwner} ` +
      `helloId=${d.helloId} agencyId=${d.agencyId || null}`);
  }

  const owners = await db.collection("users").where("role", "==", "owner").limit(10).get();
  const supers = await db.collection("users").where("role", "==", "superadmin").limit(10).get();
  console.log("\n--- potential callers ---");
  for (const s of [...owners.docs, ...supers.docs]) {
    const d = s.data();
    console.log(`uid=${s.id} role=${d.role} branchId=${d.branchId || null} helloId=${d.helloId || "?"} name=${d.displayName || d.name || "?"}`);
  }
  process.exit(0);
}
main().catch(e => { console.error(e); process.exit(1); });
