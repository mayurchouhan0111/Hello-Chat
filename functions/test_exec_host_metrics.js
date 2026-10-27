const path = require("path");
const os = require("os");
const fs = require("fs");

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
process.env.GCLOUD_PROJECT = "hellochat-e8965";

const f = require("./index.js");

async function run() {
  const uid = "VJ1GwGfAwafIhCuHDaRTqBbdhYj2";
  console.log("Calling getHostMetrics logic for:", uid);
  const result = await f.getHostMetrics.run({}, { auth: { uid } });
  console.log("Result:", JSON.stringify(result, null, 2).slice(0, 500));
}

run().then(() => process.exit(0)).catch(e => {
  console.error("getHostMetrics failed with error:", e);
  process.exit(1);
});
