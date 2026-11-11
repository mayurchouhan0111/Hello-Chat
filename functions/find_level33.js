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
  console.log("=== Finding user with level 33 or friends 25 or following 25 ===");
  const snap = await db.collection("users").get();
  snap.forEach(d => {
    const data = d.data();
    if (data.level === 33 || data.followingCount === 25 || data.friendsCount === 25 || data.fansCount === 31 || data.followerCount === 31) {
      console.log(`MATCH: docId=${d.id} | helloId=${data.helloId} | name=${data.displayName} | level=${data.level} | phone=${data.phoneNumber} | email=${data.email}`);
      console.log(JSON.stringify(data, null, 2));
    }
  });
}

run().catch(console.error).finally(() => process.exit(0));

