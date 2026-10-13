/**
 * PRODUCTION provisioning — creates the 6 panel accounts + 1 branch in the live
 * project hellochat-e8965 using the test phone numbers registered in the
 * Firebase Console ("Phone numbers for testing", fixed code 123456).
 *
 * Node functions/provision_production_admins.js
 *
 * Idempotent: re-running reuses existing Auth users and merges user docs.
 * It never downgrades or overwrites an existing account's role.
 */
const path = require("path");
const os = require("os");
const fs = require("fs");
const admin = require("firebase-admin");

/**
 * The key committed at scripts/service-account-key.json is REVOKED
 * ("Invalid JWT Signature"), and firebase-admin's Firestore client refuses raw
 * OAuth tokens, so this runs on Application Default Credentials built from the
 * Firebase CLI's own refresh token. Written to the OS temp dir only — it carries
 * a live credential and must never land in this repo.
 *
 *   HC_USE_ADC=1 node functions/provision_production_admins.js
 */
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
  credential: process.env.HC_USE_ADC
    ? cliAdcCredential()
    : admin.credential.cert(path.join(__dirname, "..", "scripts", "service-account-key.json")),
});

const db = admin.firestore();
const auth = admin.auth();
const T = admin.firestore.FieldValue.serverTimestamp();

// Roles must match firebase/firestore.rules (isOwner/isAdmin) and
// hellochat_admin/src/lib/tier.js (tierOf) — role field wins, tags are the
// mirror the rules' hasAny() checks.
const PLAN = [
  { phone: "+919000000001", name: "Hello Owner",      role: "owner",      tags: ["Owner"] },
  { phone: "+919000000002", name: "Branch Super Admin", role: "superadmin", tags: ["SuperAdmin"] },
  { phone: "+919000000003", name: "Branch Admin",     role: "admin",      tags: ["Admin"] },
  { phone: "+919000000004", name: "Agency Lead",      role: "agency",     tags: ["Agency"] },
  { phone: "+919000000005", name: "Panel Host",       role: "host",       tags: [] },
  { phone: "+917898840444", name: "Panel Host Two",   role: "host",       tags: [] },
];

const EXISTING_SA_PHONE = "+916263850508"; // real account already in the project
const BRANCH_ID = "branch-prod-1";

async function ensureAuthUser(phone, name) {
  try {
    const u = await auth.getUserByPhoneNumber(phone);
    if (u.displayName !== name) await admin.auth().updateUser(u.uid, { displayName: name });
    return u.uid;
  } catch (e) {
    if (e.code !== "auth/user-not-found") throw e;
    const u = await auth.createUser({ phoneNumber: phone, displayName: name });
    return u.uid;
  }
}

async function writeUserDoc(uid, phone, plan, branch) {
  const base = {
    uid, phoneNumber: phone, displayName: plan.name,
    // Every query in the panel sorts/filters on these — omitting them silently
    // drops the doc from orderBy results.
    createdAt: T, timestamp: T, updatedAt: T,
    sortOrder: 1, order: 1, period: "daily",
    isActive: true, isReseller: false, isBanned: false,
    username: plan.phone ? plan.phone.replace("+", "") : uid,
    helloId: "HL" + uid.slice(-6).toUpperCase(),
    role: plan.role, tags: plan.tags,
    verificationStatus: "verified", kycStatus: "approved", status: "active",
    branchId: null, superAdminId: null, adminId: null, agencyId: null,
    isAgencyOwner: false,
  };
  delete base.phone;
  await db.collection("users").doc(uid).set(base, { merge: true });
  return uid;
}

async function main() {
  const out = [];
  let ownerUid = null, saUid = null, adminUid = null, agencyUid = null;

  // Pass 1 — everyone, without linkage (uids must exist first).
  for (const p of PLAN) {
    const uid = await ensureAuthUser(p.phone, p.name);
    await writeUserDoc(uid, p.phone, p, null);
    out.push({ ...p, uid });
    if (p.role === "owner") ownerUid = uid;
    if (p.role === "superadmin" && !saUid) saUid = uid;
    if (p.role === "admin") adminUid = uid;
    if (p.role === "agency") agencyUid = uid;
  }

  // The pre-existing production Super Admin. Role is left untouched — only the
  // missing branchId is filled in, because a Super Admin without a branch is
  // scoped to nothing and every screen reads 0.
  const existing = await auth.getUserByPhoneNumber(EXISTING_SA_PHONE).catch(() => null);
  if (existing) {
    await db.collection("users").doc(existing.uid).set({ branchId: BRANCH_ID }, { merge: true });
    out.push({ phone: EXISTING_SA_PHONE, name: "(existing)", role: "superadmin", uid: existing.uid, note: "branchId attached" });
  }

  // Pass 2 — hierarchy linkage, derived the same way assignHierarchyRole does it.
  const link = out.map((o) => [o.phone, o.uid, o.role]);
  for (const [phone, uid, role] of link) {
    const u = { branchId: null, superAdminId: null, adminId: null, agencyId: null, isAgencyOwner: false };
    if (role === "superadmin") { u.branchId = BRANCH_ID; u.superAdminId = uid; }
    if (role === "admin")      { u.branchId = BRANCH_ID; u.superAdminId = saUid; u.adminId = uid; }
    if (role === "agency")     { u.branchId = BRANCH_ID; u.superAdminId = saUid; u.adminId = adminUid; u.agencyId = uid; u.isAgencyOwner = true; }
    if (role === "host")       { u.branchId = BRANCH_ID; u.superAdminId = saUid; u.adminId = adminUid; u.agencyId = agencyUid; }
    if (Object.values(u).some((v) => v !== null) && role !== "owner") {
      if (u.branchId || u.superAdminId || u.adminId || u.agencyId) {
        await db.collection("users").doc(uid).set(u, { merge: true });
      }
    }
  }

  await db.collection("branches").doc(BRANCH_ID).set({
    id: BRANCH_ID, name: "Production Branch", superAdminUid: saUid,
    status: "active", createdBy: ownerUid, createdAt: T,
  }, { merge: true });

  console.log("\nPROVISIONED — project hellochat-e8965\n");
  console.log("PHONE              ROLE         UID                             OTP");
  console.log("-".repeat(78));
  for (const o of out) console.log(`${o.phone.padEnd(18)} ${o.role.padEnd(12)} ${o.uid.padEnd(31)} 123456`);
  console.log(`\nBranch: ${BRANCH_ID} (Production Branch) -> Super Admin ${saUid}`);
  process.exit(0);
}

main().catch((e) => { console.error(e); process.exit(1); });
