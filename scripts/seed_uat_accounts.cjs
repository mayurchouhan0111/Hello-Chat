// scripts/seed_uat_accounts.cjs
//
// Creates the UAT hierarchy in the Firebase emulator or a staging project.
// Production writes require BOTH the exact acknowledgement flag and an
// approval token. Re-running resets the seeded account documents.

const path = require("path");

let admin;
try {
  admin = require("firebase-admin");
} catch (_) {
  admin = require(path.join(__dirname, "..", "functions", "node_modules", "firebase-admin"));
}

const PRODUCTION_PROJECT = "hellochat-e8965";
const DEFAULT_PROJECT = PRODUCTION_PROJECT;
const DEFAULT_PASSWORD = "UatTest!2026";
const BRANCH_ID = "uat-branch-main";
const AGENCY_A_ID = "uat-agency-alpha";
const AGENCY_B_ID = "uat-agency-beta";
const ROLE_CODE_SPECS = {
  superadmin: { len: 4, min: 1000 },
  admin: { len: 5, min: 10000 },
  agency: { len: 6, min: 100000 },
};

function usage() {
  console.log([
    "Usage: node scripts/seed_uat_accounts.cjs [options]",
    "",
    "  --emulator                 Use local Auth/Firestore emulators",
    "  --project <id>             Target project (default: hellochat-e8965)",
    "  --password <value>         Shared UAT password (production requires this)",
    "  --i-understand-this-writes-to-production",
    "  --approval-token <token>   Required with the production flag",
    "",
    "Production approval token: OWNER_APPROVED_UAT",
    "Environment alternative: UAT_PASSWORD",
  ].join("\n"));
}

function parseArgs(argv) {
  const out = { emulator: false, productionAck: false };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--help" || arg === "-h") out.help = true;
    else if (arg === "--emulator") out.emulator = true;
    else if (arg === "--i-understand-this-writes-to-production") out.productionAck = true;
    else if (arg === "--project") out.project = argv[++i];
    else if (arg.startsWith("--project=")) out.project = arg.slice("--project=".length);
    else if (arg === "--password") out.password = argv[++i];
    else if (arg.startsWith("--password=")) out.password = arg.slice("--password=".length);
    else if (arg === "--approval-token") out.approvalToken = argv[++i];
    else if (arg.startsWith("--approval-token=")) out.approvalToken = arg.slice("--approval-token=".length);
    else throw new Error(`Unknown argument: ${arg}`);
  }
  return out;
}

function isLocalHost(value) {
  if (!value) return false;
  return /^(127\.0\.0\.1|localhost|\[::1\]|10\.0\.2\.2)(:\d+)?$/.test(value);
}

function configureTarget(args) {
  if (args.emulator) {
    if (!process.env.FIRESTORE_EMULATOR_HOST) process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8085";
    if (!process.env.FIREBASE_AUTH_EMULATOR_HOST) process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";
  }

  const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
  const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const emulatorMode = !!(firestoreHost || authHost);

  if (emulatorMode) {
    if (!firestoreHost || !authHost || !isLocalHost(firestoreHost) || !isLocalHost(authHost)) {
      throw new Error("Emulator mode requires local FIRESTORE_EMULATOR_HOST and FIREBASE_AUTH_EMULATOR_HOST.");
    }
  }

  const project = args.project || process.env.GCLOUD_PROJECT || DEFAULT_PROJECT;
  const production = !emulatorMode && project === PRODUCTION_PROJECT;

  if (production) {
    if (!args.productionAck) {
      throw new Error([
        "REFUSED: this would write UAT accounts to the production project.",
        "Re-run with --project <staging-project> for staging.",
        "A production write also requires --i-understand-this-writes-to-production",
        "and --approval-token OWNER_APPROVED_UAT.",
      ].join("\n"));
    }
    if (args.approvalToken !== "OWNER_APPROVED_UAT") {
      throw new Error("REFUSED: production approval token is missing or incorrect.");
    }
  }

  const password = args.password || process.env.UAT_PASSWORD || DEFAULT_PASSWORD;
  if (production && password === DEFAULT_PASSWORD) {
    throw new Error("REFUSED: set a non-default --password or UAT_PASSWORD for production.");
  }
  if (!password || password.length < 10) {
    throw new Error("The UAT password must be at least 10 characters.");
  }

  return { project, emulatorMode, production, password };
}

function isValidRoleCode(code, role) {
  const spec = ROLE_CODE_SPECS[role];
  return !!spec && typeof code === "string" && code.length === spec.len && /^\d+$/.test(code);
}

async function allocateRoleCode(db, role) {
  return db.runTransaction(async (transaction) => {
    const ref = db.collection("counters").doc("role_codes");
    const snap = await transaction.get(ref);
    const spec = ROLE_CODE_SPECS[role];
    const stored = snap.exists ? Number(snap.data()[role]) : NaN;
    const next = Number.isFinite(stored) && stored >= spec.min ? stored : spec.min;
    const code = String(next);
    if (code.length !== spec.len) throw new Error(`${role} role-code space exhausted.`);
    transaction.set(ref, { [role]: next + 1 }, { merge: true });
    return code;
  });
}

async function ensureRoleCode(db, uid, role) {
  const snap = await db.collection("users").doc(uid).get();
  const existing = snap.exists ? snap.data().roleCode : null;
  if (isValidRoleCode(existing, role)) return existing;
  return allocateRoleCode(db, role);
}

async function ensureAuthUser(auth, account, password) {
  let existing = null;
  try {
    existing = await auth.getUser(account.uid);
  } catch (err) {
    if (err.code !== "auth/user-not-found") throw err;
  }

  if (existing) {
    await auth.updateUser(account.uid, {
      email: account.email,
      password,
      displayName: account.displayName,
      emailVerified: true,
      disabled: false,
    });
    return;
  }

  await auth.createUser({
    uid: account.uid,
    email: account.email,
    password,
    displayName: account.displayName,
    emailVerified: true,
    disabled: false,
  });
}

function buildAccounts(roleCodes) {
  const common = (uid, helloId, displayName, username, email) => ({
    uid,
    helloId,
    displayName,
    username,
    email,
    bio: "Hello Chat UAT account",
    country: "BD",
  });

  const accounts = [
    {
      ...common("uat-owner", "9900000001", "UAT Owner", "uat_owner", "uat.owner@hellochat-uat.test"),
      role: "owner",
      tags: ["Owner"],
    },
    {
      ...common("uat-superadmin", "9900000002", "UAT Super Admin", "uat_superadmin", "uat.superadmin@hellochat-uat.test"),
      role: "superadmin",
      tags: ["SuperAdmin"],
      roleCode: roleCodes.superadmin,
      branchId: BRANCH_ID,
      superAdminId: "uat-superadmin",
    },
    {
      ...common("uat-admin-1", "9900000011", "UAT Admin One", "uat_admin_one", "uat.admin1@hellochat-uat.test"),
      role: "admin",
      tags: ["Admin"],
      roleCode: roleCodes.admin1,
      branchId: BRANCH_ID,
      superAdminId: "uat-superadmin",
    },
    {
      ...common("uat-admin-2", "9900000012", "UAT Admin Two", "uat_admin_two", "uat.admin2@hellochat-uat.test"),
      role: "admin",
      tags: ["Admin"],
      roleCode: roleCodes.admin2,
      branchId: BRANCH_ID,
      superAdminId: "uat-superadmin",
    },
    {
      ...common("uat-agency-alpha-owner", "9900000021", "UAT Agency Alpha Owner", "uat_agency_alpha", "uat.agency.alpha@hellochat-uat.test"),
      role: "agency",
      tags: ["Agency"],
      roleCode: roleCodes.agencyA,
      isAgencyOwner: true,
      previousRole: "user",
      branchId: BRANCH_ID,
      adminId: "uat-admin-1",
      superAdminId: "uat-superadmin",
      agencyId: AGENCY_A_ID,
    },
    {
      ...common("uat-agency-beta-owner", "9900000022", "UAT Agency Beta Owner", "uat_agency_beta", "uat.agency.beta@hellochat-uat.test"),
      role: "agency",
      tags: ["Agency"],
      roleCode: roleCodes.agencyB,
      isAgencyOwner: true,
      previousRole: "user",
      branchId: BRANCH_ID,
      adminId: "uat-admin-2",
      superAdminId: "uat-superadmin",
      agencyId: AGENCY_B_ID,
    },
    {
      ...common("uat-host-alpha-1", "9900000031", "UAT Host Alpha One", "uat_host_alpha_one", "uat.host.a1@hellochat-uat.test"),
      role: "host",
      tags: ["Host"],
      isHost: true,
      branchId: BRANCH_ID,
      adminId: "uat-admin-1",
      superAdminId: "uat-superadmin",
      agencyId: AGENCY_A_ID,
      diamondBalance: 0,
    },
    {
      ...common("uat-host-alpha-2", "9900000032", "UAT Host Alpha Two", "uat_host_alpha_two", "uat.host.a2@hellochat-uat.test"),
      role: "host",
      tags: ["Host"],
      isHost: true,
      branchId: BRANCH_ID,
      adminId: "uat-admin-1",
      superAdminId: "uat-superadmin",
      agencyId: AGENCY_A_ID,
      diamondBalance: 0,
    },
    {
      ...common("uat-host-beta-1", "9900000033", "UAT Host Beta One", "uat_host_beta_one", "uat.host.b1@hellochat-uat.test"),
      role: "host",
      tags: ["Host"],
      isHost: true,
      branchId: BRANCH_ID,
      adminId: "uat-admin-2",
      superAdminId: "uat-superadmin",
      agencyId: AGENCY_B_ID,
      diamondBalance: 0,
    },
    {
      ...common("uat-host-beta-2", "9900000034", "UAT Host Beta Two", "uat_host_beta_two", "uat.host.b2@hellochat-uat.test"),
      role: "host",
      tags: ["Host"],
      isHost: true,
      branchId: BRANCH_ID,
      adminId: "uat-admin-2",
      superAdminId: "uat-superadmin",
      agencyId: AGENCY_B_ID,
      diamondBalance: 0,
    },
    {
      ...common("uat-user-1", "9900000041", "UAT Normal One", "uat_normal_one", "uat.user1@hellochat-uat.test"),
      role: "user",
      tags: [],
      branchId: BRANCH_ID,
      adminId: "uat-admin-1",
      superAdminId: "uat-superadmin",
      diamondBalance: 1000000,
    },
    {
      ...common("uat-user-2", "9900000042", "UAT Normal Two", "uat_normal_two", "uat.user2@hellochat-uat.test"),
      role: "user",
      tags: [],
      branchId: BRANCH_ID,
      adminId: "uat-admin-1",
      superAdminId: "uat-superadmin",
      diamondBalance: 0,
    },
    {
      ...common("uat-user-3", "9900000043", "UAT Normal Three", "uat_normal_three", "uat.user3@hellochat-uat.test"),
      role: "user",
      tags: [],
      branchId: BRANCH_ID,
      adminId: "uat-admin-2",
      superAdminId: "uat-superadmin",
      diamondBalance: 0,
    },
  ];

  return accounts;
}

function userDocument(account, now) {
  return {
    uid: account.uid,
    helloId: account.helloId,
    displayName: account.displayName,
    displayName_lowercase: account.displayName.toLowerCase(),
    username: account.username,
    username_lowercase: account.username.toLowerCase(),
    email: account.email,
    phoneNumber: "",
    bio: account.bio,
    country: account.country,
    countryFlag: "",
    gender: "male",
    profilePhotoUrl: "",
    photoUrl: "",
    role: account.role,
    tags: account.tags,
    previousRole: account.previousRole || null,
    roleCode: account.roleCode || null,
    branchId: account.branchId || null,
    superAdminId: account.superAdminId || null,
    adminId: account.adminId || null,
    agencyId: account.agencyId || null,
    isHost: account.isHost === true,
    isAgencyOwner: account.isAgencyOwner === true,
    isBanned: false,
    isVerified: true,
    diamondBalance: account.diamondBalance || 0,
    diamonds: account.diamondBalance || 0,
    beansBalance: 0,
    usdCommissionBalance: 0,
    pendingWithdrawalBalance: 0,
    totalWithdrawnUSD: 0,
    totalCommissionEarned: 0,
    totalRechargeGenerated: 0,
    level: 1,
    xp: 0,
    princeXP: 0,
    vipTier: "none",
    svipLevel: 0,
    isReseller: false,
    createdAt: now,
    updatedAt: now,
    lastActive: now,
    roleUpdatedAt: now,
  };
}

function publicUserDocument(userDoc) {
  const allowed = [
    "uid", "helloId", "displayName", "displayName_lowercase", "username",
    "username_lowercase", "bio", "country", "countryFlag", "gender",
    "profilePhotoUrl", "photoUrl", "level", "xp", "princeXP", "vipTier",
    "isReseller", "isAgencyOwner", "status", "createdAt", "isVerified", "tags",
    "svipLevel", "dailyDiamondsSent", "weeklyDiamondsSent",
    "monthlyDiamondsSent", "totalDiamondsSent", "dailyBeansReceived",
    "weeklyBeansReceived", "monthlyBeansReceived", "totalBeansReceived",
  ];
  const out = {};
  for (const key of allowed) {
    if (userDoc[key] !== undefined) out[key] = userDoc[key];
  }
  return out;
}

function agencyDocument(id, name, owner, adminId, hostUids, now) {
  return {
    id,
    name,
    ownerUid: owner.uid,
    ownerName: owner.displayName,
    ownerHelloId: owner.helloId,
    code: owner.roleCode,
    adminId,
    branchId: BRANCH_ID,
    superAdminId: "uat-superadmin",
    description: "UAT agency",
    contactPhone: "",
    country: "BD",
    commissionRate: 0.30,
    isActive: true,
    status: "active",
    hostUids,
    hostCount: hostUids.length,
    beansBalance: 0,
    totalBeansEarned: 0,
    usdCommissionBalance: 0,
    totalCommissionEarned: 0,
    totalRechargeGenerated: 0,
    pendingWithdrawalBalance: 0,
    totalWithdrawnUSD: 0,
    createdBy: "uat-owner",
    createdAt: now,
    updatedAt: now,
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    usage();
    return;
  }

  const target = configureTarget(args);
  if (!admin.apps.length) {
    const appOptions = { projectId: target.project };
    if (!target.emulatorMode) {
      appOptions.credential = admin.credential.applicationDefault();
    }
    admin.initializeApp(appOptions);
  }

  const auth = admin.auth();
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();

  const roleCodes = {
    superadmin: await ensureRoleCode(db, "uat-superadmin", "superadmin"),
    admin1: await ensureRoleCode(db, "uat-admin-1", "admin"),
    admin2: await ensureRoleCode(db, "uat-admin-2", "admin"),
    agencyA: await ensureRoleCode(db, "uat-agency-alpha-owner", "agency"),
    agencyB: await ensureRoleCode(db, "uat-agency-beta-owner", "agency"),
  };

  const accounts = buildAccounts(roleCodes);
  for (const account of accounts) {
    await ensureAuthUser(auth, account, target.password);
  }

  const byUid = Object.fromEntries(accounts.map(account => [account.uid, account]));
  const hostA = ["uat-host-alpha-1", "uat-host-alpha-2"];
  const hostB = ["uat-host-beta-1", "uat-host-beta-2"];

  const batch = db.batch();
  batch.set(db.collection("branches").doc(BRANCH_ID), {
    id: BRANCH_ID,
    name: "UAT Main Branch",
    superAdminUid: "uat-superadmin",
    createdBy: "uat-owner",
    createdAt: now,
    status: "active",
  });

  for (const account of accounts) {
    const doc = userDocument(account, now);
    batch.set(db.collection("users").doc(account.uid), doc);
    batch.set(db.collection("publicUsers").doc(account.uid), publicUserDocument(doc));
    batch.set(db.collection("usernames").doc(account.username.toLowerCase()), {
      uid: account.uid,
      createdAt: now,
    });
  }

  batch.set(
    db.collection("agencies").doc(AGENCY_A_ID),
    agencyDocument(AGENCY_A_ID, "UAT Agency Alpha", byUid["uat-agency-alpha-owner"], "uat-admin-1", hostA, now),
  );
  batch.set(
    db.collection("agencies").doc(AGENCY_B_ID),
    agencyDocument(AGENCY_B_ID, "UAT Agency Beta", byUid["uat-agency-beta-owner"], "uat-admin-2", hostB, now),
  );

  await batch.commit();

  console.log(`Target: ${target.emulatorMode ? "LOCAL EMULATORS" : `PROJECT ${target.project}`}`);
  console.log(`Password: ${target.password}`);
  console.log("Alias                 Role        Hello ID     UID");
  console.log("--------------------  ----------  -----------  ------------------------------");
  for (const account of accounts) {
    const alias = account.username.padEnd(20);
    const role = account.role.padEnd(10);
    const hello = String(account.helloId).padEnd(11);
    console.log(`${alias}  ${role}  ${hello}  ${account.uid}`);
  }
  console.log(`Branch: ${BRANCH_ID}`);
  console.log(`Agencies: ${AGENCY_A_ID}, ${AGENCY_B_ID}`);
  console.log("Seeded account balances and roles were reset to baseline.");
}

main().catch((err) => {
  console.error(err.stack || err.message || err);
  process.exitCode = 1;
});
