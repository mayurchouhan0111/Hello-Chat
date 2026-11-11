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

const auth = admin.auth();

async function run() {
  const u = await auth.getUser("VJ1GwGfAwafIhCuHDaRTqBbdhYj2");
  console.log("Auth User VJ1GwGfAwafIhCuHDaRTqBbdhYj2:");
  console.log("creationTime:", u.metadata.creationTime);
  console.log("lastSignInTime:", u.metadata.lastSignInTime);
  console.log("phoneNumber:", u.phoneNumber);
  console.log("email:", u.email);
  console.log("providerData:", u.providerData);
}

run().catch(console.error).finally(() => process.exit(0));

