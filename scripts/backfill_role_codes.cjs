// scripts/backfill_role_codes.cjs
//
// Backfills missing role codes for existing Super Admins, Admins, and Agencies
// using the canonical counters/role_codes transaction logic from functions/index.js.
//
// Safe by default:
//   node scripts/backfill_role_codes.cjs            <-- Defaults to --dry-run
//   node scripts/backfill_role_codes.cjs --dry-run  <-- Explicit dry-run
//   node scripts/backfill_role_codes.cjs --apply    <-- Explicit live write
//
// Idempotent: Skips entities that already carry a valid roleCode.

const fs = require("fs");
const path = require("path");
const os = require("os");

// 1. Load firebase-admin
let admin;
try {
  admin = require("firebase-admin");
} catch (e) {
  admin = require(path.join(__dirname, "..", "functions", "node_modules", "firebase-admin"));
}

// 2. Resolve credentials (CLI ADC token or applicationDefault)
function resolveCredential() {
  const cfgPath = path.join(os.homedir(), ".config", "configstore", "firebase-tools.json");
  if (fs.existsSync(cfgPath)) {
    try {
      const cfg = JSON.parse(fs.readFileSync(cfgPath, "utf8"));
      if (cfg.tokens && cfg.tokens.refresh_token) {
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
    } catch (e) {
      // fallback below
    }
  }
  return admin.credential.applicationDefault();
}

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: "hellochat-e8965",
    credential: resolveCredential(),
  });
}

const db = admin.firestore();

// Role Code Length Specifications (§7)
const ROLE_CODE_SPECS = {
  superadmin: { len: 4, min: 1000 },
  admin: { len: 5, min: 10000 },
  agency: { len: 6, min: 100000 },
};

function isValidRoleCode(code, role) {
  const spec = ROLE_CODE_SPECS[role];
  if (!spec) return false;
  const s = String(code || "").trim();
  return s.length === spec.len && /^\d+$/.test(s);
}

function normalizeTier(data) {
  if (!data) return "host";
  const tags = Array.isArray(data.tags) ? data.tags : [];
  if (data.role === "owner" || tags.includes("Owner")) return "owner";
  if (data.role === "superadmin" || tags.includes("SuperAdmin")) return "superadmin";
  if (data.role === "admin" || tags.includes("Admin")) return "admin";
  if (data.role === "agency" || data.isAgencyOwner === true || tags.includes("Agency")) return "agency";
  return "host";
}

/**
 * Transaction-safe role code allocation matching functions/index.js allocateRoleCodeTx
 */
async function allocateRoleCodeTx(transaction, role) {
  const spec = ROLE_CODE_SPECS[role];
  if (!spec) throw new Error(`No code spec for role "${role}".`);
  const counterRef = db.collection("counters").doc("role_codes");
  const snap = await transaction.get(counterRef);
  const stored = snap.exists ? Number(snap.data()[role]) : NaN;
  const next = Number.isFinite(stored) && stored >= spec.min ? stored : spec.min;
  const code = String(next);
  if (code.length !== spec.len) {
    throw new Error(
      `${role} ${spec.len}-digit code space exhausted. Report capacity limit before issuing more ${role} codes.`
    );
  }
  transaction.set(counterRef, { [role]: next + 1 }, { merge: true });
  return code;
}

function parseCreatedAt(data) {
  if (!data || !data.createdAt) return 0;
  if (typeof data.createdAt.toMillis === "function") return data.createdAt.toMillis();
  if (typeof data.createdAt === "string") return new Date(data.createdAt).getTime() || 0;
  if (typeof data.createdAt === "number") return data.createdAt;
  return 0;
}

function compareDeterministic(a, b) {
  const tA = parseCreatedAt(a.data);
  const tB = parseCreatedAt(b.data);
  if (tA !== tB) return tA - tB;
  return a.id.localeCompare(b.id);
}

async function main() {
  const args = process.argv.slice(2);
  const isApply = args.includes("--apply");
  const modeLabel = isApply ? "APPLY (LIVE WRITES)" : "DRY-RUN (NO WRITES)";

  console.log("==================================================");
  console.log(`Hello-PMS Role Code Backfill Script`);
  console.log(`Execution Mode: ${modeLabel}`);
  console.log(`Target Project: hellochat-e8965`);
  console.log("==================================================");

  // 1. Fetch current entities
  console.log("Fetching users, agencies, and current counter state...");
  const [usersSnap, agenciesSnap, counterDoc] = await Promise.all([
    db.collection("users").get(),
    db.collection("agencies").get(),
    db.collection("counters").doc("role_codes").get(),
  ]);

  const currentCounters = counterDoc.exists ? counterDoc.data() : {};
  console.log("Current counters/role_codes:", JSON.stringify(currentCounters));

  // Build items needing audit/backfill
  const usersById = new Map();
  usersSnap.forEach(d => usersById.set(d.id, d.data()));

  const superAdmins = [];
  const admins = [];
  const agencyDocs = [];
  const agencyUsers = [];

  usersSnap.forEach(d => {
    const data = d.data();
    const tier = normalizeTier(data);
    if (tier === "superadmin") {
      superAdmins.push({ id: d.id, ref: d.ref, data, role: "superadmin" });
    } else if (tier === "admin") {
      admins.push({ id: d.id, ref: d.ref, data, role: "admin" });
    } else if (tier === "agency") {
      agencyUsers.push({ id: d.id, ref: d.ref, data, role: "agency" });
    }
  });

  agenciesSnap.forEach(d => {
    agencyDocs.push({ id: d.id, ref: d.ref, data: d.data(), role: "agency" });
  });

  // Sort deterministically
  superAdmins.sort(compareDeterministic);
  admins.sort(compareDeterministic);
  agencyDocs.sort(compareDeterministic);
  agencyUsers.sort(compareDeterministic);

  console.log(`Discovered: ${superAdmins.length} Super Admins, ${admins.length} Admins, ${agencyDocs.length} Agency Docs, ${agencyUsers.length} Agency Users.`);

  const summary = {
    superadmin: { assigned: 0, skipped: 0, failed: 0 },
    admin: { assigned: 0, skipped: 0, failed: 0 },
    agency: { assigned: 0, skipped: 0, failed: 0 },
  };

  // Dry-run simulated counters
  const simulatedCounters = {
    superadmin: Number(currentCounters.superadmin) >= ROLE_CODE_SPECS.superadmin.min ? Number(currentCounters.superadmin) : ROLE_CODE_SPECS.superadmin.min,
    admin: Number(currentCounters.admin) >= ROLE_CODE_SPECS.admin.min ? Number(currentCounters.admin) : ROLE_CODE_SPECS.admin.min,
    agency: Number(currentCounters.agency) >= ROLE_CODE_SPECS.agency.min ? Number(currentCounters.agency) : ROLE_CODE_SPECS.agency.min,
  };

  // ── 1. Process Super Admins ──────────────────────────────────────────────────
  console.log("\n--- Processing Super Admins (4 digits) ---");
  for (const item of superAdmins) {
    const existing = item.data.roleCode;
    if (isValidRoleCode(existing, "superadmin")) {
      console.log(`[SKIP] Super Admin ${item.id} already has valid roleCode: ${existing}`);
      summary.superadmin.skipped++;
      continue;
    }

    if (!isApply) {
      const code = String(simulatedCounters.superadmin++);
      console.log(`[DRY-RUN] Would assign roleCode "${code}" to Super Admin ${item.id} (${item.data.displayName || item.data.helloId || 'N/A'})`);
      summary.superadmin.assigned++;
    } else {
      try {
        let allocatedCode = null;
        await db.runTransaction(async (transaction) => {
          const fresh = await transaction.get(item.ref);
          if (fresh.exists && isValidRoleCode(fresh.data().roleCode, "superadmin")) {
            allocatedCode = fresh.data().roleCode;
            return;
          }
          allocatedCode = await allocateRoleCodeTx(transaction, "superadmin");
          transaction.update(item.ref, {
            roleCode: allocatedCode,
            roleUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });
        console.log(`[ASSIGNED] Super Admin ${item.id} -> roleCode: ${allocatedCode}`);
        summary.superadmin.assigned++;
      } catch (err) {
        console.error(`[FAIL] Super Admin ${item.id} assignment failed:`, err.message);
        summary.superadmin.failed++;
      }
    }
  }

  // ── 2. Process Admins ────────────────────────────────────────────────────────
  console.log("\n--- Processing Admins (5 digits) ---");
  for (const item of admins) {
    const existing = item.data.roleCode;
    if (isValidRoleCode(existing, "admin")) {
      console.log(`[SKIP] Admin ${item.id} already has valid roleCode: ${existing}`);
      summary.admin.skipped++;
      continue;
    }

    if (!isApply) {
      const code = String(simulatedCounters.admin++);
      console.log(`[DRY-RUN] Would assign roleCode "${code}" to Admin ${item.id} (${item.data.displayName || item.data.helloId || 'N/A'})`);
      summary.admin.assigned++;
    } else {
      try {
        let allocatedCode = null;
        await db.runTransaction(async (transaction) => {
          const fresh = await transaction.get(item.ref);
          if (fresh.exists && isValidRoleCode(fresh.data().roleCode, "admin")) {
            allocatedCode = fresh.data().roleCode;
            return;
          }
          allocatedCode = await allocateRoleCodeTx(transaction, "admin");
          transaction.update(item.ref, {
            roleCode: allocatedCode,
            roleUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });
        console.log(`[ASSIGNED] Admin ${item.id} -> roleCode: ${allocatedCode}`);
        summary.admin.assigned++;
      } catch (err) {
        console.error(`[FAIL] Admin ${item.id} assignment failed:`, err.message);
        summary.admin.failed++;
      }
    }
  }

  // ── 3. Process Agencies (Docs & Owner Users) ──────────────────────────────────
  console.log("\n--- Processing Agencies (6 digits) ---");
  // Keep track of agency-assigned owner UIDs so we don't double allocate
  const processedAgencyOwners = new Set();

  for (const item of agencyDocs) {
    const existingDocCode = item.data.code;
    const ownerUid = item.data.ownerUid;
    const ownerUser = ownerUid ? usersById.get(ownerUid) : null;
    const existingUserCode = ownerUser?.roleCode;

    const validCode = isValidRoleCode(existingDocCode, "agency")
      ? existingDocCode
      : (isValidRoleCode(existingUserCode, "agency") ? existingUserCode : null);

    if (validCode) {
      console.log(`[SKIP] Agency ${item.id} already has valid code: ${validCode}`);
      if (ownerUid) processedAgencyOwners.add(ownerUid);
      summary.agency.skipped++;
      continue;
    }

    if (!isApply) {
      const code = String(simulatedCounters.agency++);
      const isStaffOwner = ownerUser && ["owner", "superadmin", "admin"].includes(normalizeTier(ownerUser));
      const shouldSyncOwner = ownerUid && !isStaffOwner;
      console.log(`[DRY-RUN] Would assign code "${code}" to Agency Doc ${item.id} ("${item.data.name}")` + (shouldSyncOwner ? ` & sync to Owner User ${ownerUid}` : ` (owner ${ownerUid} is ${ownerUser ? normalizeTier(ownerUser) : 'staff'}; keeps staff code)`));
      if (ownerUid) processedAgencyOwners.add(ownerUid);
      summary.agency.assigned++;
    } else {
      try {
        let allocatedCode = null;
        let didSyncOwner = false;
        await db.runTransaction(async (transaction) => {
          const freshDoc = await transaction.get(item.ref);
          let freshOwner = null;
          let ownerRef = null;
          if (ownerUid) {
            ownerRef = db.collection("users").doc(ownerUid);
            freshOwner = await transaction.get(ownerRef);
          }

          if (freshDoc.exists && isValidRoleCode(freshDoc.data().code, "agency")) {
            allocatedCode = freshDoc.data().code;
          } else if (freshOwner?.exists && normalizeTier(freshOwner.data()) === "agency" && isValidRoleCode(freshOwner.data().roleCode, "agency")) {
            allocatedCode = freshOwner.data().roleCode;
          } else {
            allocatedCode = await allocateRoleCodeTx(transaction, "agency");
          }

          transaction.update(item.ref, {
            code: allocatedCode,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          const isStaffOwner = freshOwner?.exists && ["owner", "superadmin", "admin"].includes(normalizeTier(freshOwner.data()));
          if (ownerRef && freshOwner && freshOwner.exists && !isStaffOwner) {
            transaction.update(ownerRef, {
              roleCode: allocatedCode,
              roleUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            didSyncOwner = true;
          }
        });

        console.log(`[ASSIGNED] Agency Doc ${item.id} -> code: ${allocatedCode}` + (didSyncOwner ? ` (synced to owner ${ownerUid})` : " (owner is staff; kept staff code)"));
        if (ownerUid) processedAgencyOwners.add(ownerUid);
        summary.agency.assigned++;
      } catch (err) {
        console.error(`[FAIL] Agency ${item.id} assignment failed:`, err.message);
        summary.agency.failed++;
      }
    }
  }

  // Any remaining standalone agency users without an agency doc
  for (const item of agencyUsers) {
    if (processedAgencyOwners.has(item.id)) continue;
    const existing = item.data.roleCode;
    if (isValidRoleCode(existing, "agency")) {
      console.log(`[SKIP] Standalone Agency User ${item.id} already has valid roleCode: ${existing}`);
      summary.agency.skipped++;
      continue;
    }

    if (!isApply) {
      const code = String(simulatedCounters.agency++);
      console.log(`[DRY-RUN] Would assign roleCode "${code}" to Standalone Agency User ${item.id} (${item.data.displayName || item.data.helloId || 'N/A'})`);
      summary.agency.assigned++;
    } else {
      try {
        let allocatedCode = null;
        await db.runTransaction(async (transaction) => {
          const fresh = await transaction.get(item.ref);
          if (fresh.exists && isValidRoleCode(fresh.data().roleCode, "agency")) {
            allocatedCode = fresh.data().roleCode;
            return;
          }
          allocatedCode = await allocateRoleCodeTx(transaction, "agency");
          transaction.update(item.ref, {
            roleCode: allocatedCode,
            roleUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });
        console.log(`[ASSIGNED] Standalone Agency User ${item.id} -> roleCode: ${allocatedCode}`);
        summary.agency.assigned++;
      } catch (err) {
        console.error(`[FAIL] Standalone Agency User ${item.id} assignment failed:`, err.message);
        summary.agency.failed++;
      }
    }
  }

  // ── FINAL SUMMARY ────────────────────────────────────────────────────────────
  console.log("\n==================================================");
  console.log(`Role Code Backfill Summary (${modeLabel})`);
  console.log("==================================================");
  console.log(`Super Admins (4 digits): ${summary.superadmin.assigned} assigned, ${summary.superadmin.skipped} skipped, ${summary.superadmin.failed} failed`);
  console.log(`Admins       (5 digits): ${summary.admin.assigned} assigned, ${summary.admin.skipped} skipped, ${summary.admin.failed} failed`);
  console.log(`Agencies     (6 digits): ${summary.agency.assigned} assigned, ${summary.agency.skipped} skipped, ${summary.agency.failed} failed`);
  console.log("==================================================");

  const totalFailed = summary.superadmin.failed + summary.admin.failed + summary.agency.failed;
  if (totalFailed > 0) {
    console.error(`BACKFILL COMPLETED WITH ${totalFailed} FAILURES.`);
    process.exit(1);
  } else {
    console.log(`BACKFILL ${isApply ? "APPLIED SUCCESSFULLY" : "DRY-RUN COMPLETED CLEANLY"}.`);
  }
}

main().catch(err => {
  console.error("FATAL: Backfill process encountered an unhandled exception:", err);
  process.exit(1);
});
