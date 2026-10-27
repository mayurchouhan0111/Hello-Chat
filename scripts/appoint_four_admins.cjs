/**
 * Appoint the four client-requested Hello IDs as branch Admins through the
 * deployed `appointAdmin` callable (branch-prod-1, caller = Super Admin).
 * Auth: production test number +919000000002, OTP 123456 (Firebase Console
 * "Phone numbers for testing" — no real SMS).
 * Idempotent: re-run returns alreadyAdmin for already-appointed targets.
 */
const API_KEY = "AIzaSyDlt3B1TB0jY4nZfwkfObYOdLCBktFtnPQ";
const ENDPOINT = "https://us-central1-hellochat-e8965.cloudfunctions.net/appointAdmin";
const PHONE = "+919000000002";
const OTP = "123456";

const TARGETS = [
  { id: "3607188625", uid: "HgrLl9ubSmcZ0LdWi05MS0jHGvu1", agencyOverride: true,
    reason: "Client-approved appointment of agency owner VO4m5hbOpMwLc6PDF1bn as branch Admin." },
  { id: "3485703221", uid: "lDLp5QDDbXRzfT14qEAr4SauR0G3", agencyOverride: false },
  { id: "1805742773", uid: "aRdHp4qLLKdd8qUoVTcgTcpZpKf2", agencyOverride: false },
  { id: "0000100003", uid: "PhFe53EOGzRxricZKawdA4DARcz2", agencyOverride: false },
];

async function getIdToken() {
  const send = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:sendVerificationCode?key=${API_KEY}`,
    { method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ phoneNumber: PHONE }) });
  const sendJson = await send.json();
  if (!send.ok) throw new Error(`sendVerificationCode: ${JSON.stringify(sendJson)}`);
  const verify = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPhoneNumber?key=${API_KEY}`,
    { method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ phoneNumber: PHONE, code: OTP, sessionInfo: sendJson.sessionInfo }) });
  const verifyJson = await verify.json();
  if (!verify.ok) throw new Error(`signInWithPhoneNumber: ${JSON.stringify(verifyJson)}`);
  return { idToken: verifyJson.idToken, uid: verifyJson.localId };
}

async function appoint(idToken, t) {
  const payload = { targetIdentifier: t.id };
  if (t.agencyOverride) {
    payload.allowAgencyOverride = true;
    payload.overrideReason = t.reason;
  }
  const res = await fetch(ENDPOINT, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${idToken}` },
    body: JSON.stringify({ data: payload }) });
  const json = await res.json();
  if (json.error) throw new Error(`${t.id}: ${json.error.code} ${json.error.message}`);
  return json.result;
}

async function main() {
  const { idToken, uid } = await getIdToken();
  console.log(`authenticated as ${uid}`);
  for (const t of TARGETS) {
    try {
      const r = await appoint(idToken, t);
      console.log(`OK ${t.id} -> ${JSON.stringify(r)}`);
    } catch (e) {
      console.log(`FAIL ${t.id} -> ${e.message}`);
    }
  }
}
main().catch(e => { console.error("FATAL:", e.message); process.exit(1); });
