/**
 * Live appointment of the two branch admins via the deployed `appointAdmin` callable.
 * Caller: owner VJ1GwGfAwafIhCuHDaRTqBbdhYj2 (branch-prod-1), minted as a custom token.
 * Idempotent: re-run returns alreadyAdmin / re-applies the same state.
 */
const path = require("path");
const os = require("os");
const fs = require("fs");
const admin = require("firebase-admin");

const API_KEY = "AIzaSyDlt3B1TB0jY4nZfwkfObYOdLCBktFtnPQ";
const ENDPOINT = "https://us-central1-hellochat-e8965.cloudfunctions.net/appointAdmin";
const CALLER_UID = "VJ1GwGfAwafIhCuHDaRTqBbdhYj2";
const BRANCH = "branch-prod-1";

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

async function getIdToken() {
  const customToken = await admin.auth().createCustomToken(CALLER_UID);
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${API_KEY}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ token: customToken, returnSecureToken: true }),
    });
  const json = await res.json();
  if (!res.ok) throw new Error(`signInWithCustomToken failed: ${JSON.stringify(json)}`);
  return json.idToken;
}

async function callAppoint(idToken, payload) {
  const res = await fetch(ENDPOINT, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${idToken}` },
    body: JSON.stringify({ data: payload }),
  });
  const json = await res.json();
  if (json.error) throw new Error(`${json.error.code}: ${json.error.message}`);
  return json.result;
}

async function verify(label, uid) {
  const d = (await db.collection("users").doc(uid).get()).data();
  console.log(`VERIFY ${label}: role=${d.role} branchId=${d.branchId} tags=${JSON.stringify(d.tags)} ` +
    `appointedBy=${d.appointedBy} previousRole=${d.previousRole} ` +
    `agencyOwnerFlag=${d.isAgencyOwner === true}`);
}

async function main() {
  const idToken = await getIdToken();

  console.log("APPOINT 3607188625 (agency override)...");
  const r1 = await callAppoint(idToken, {
    targetIdentifier: "3607188625",
    allowAgencyOverride: true,
    overrideReason: "Owner-approved appointment of agency owner as branch admin (production live run).",
  });
  console.log(" ->", JSON.stringify(r1));
  await verify("3607188625", "HgrLl9ubSmcZ0LdWi05MS0jHGvu1");

  console.log("APPOINT 1805742773 (standard)...");
  const r2 = await callAppoint(idToken, { targetIdentifier: "1805742773" });
  console.log(" ->", JSON.stringify(r2));
  await verify("1805742773", "aRdHp4qLLKdd8qUoVTcgTcpZpKf2");

  process.exit(0);
}
main().catch(e => { console.error("FAILED:", e.message); process.exit(1); });
