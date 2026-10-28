// scripts/uat_edge_cases.cjs
//
// Emulator-only edge checks for the commission-wallet UAT. Refuses to run
// against any remote Firestore/Auth host.

if (!process.env.FIRESTORE_EMULATOR_HOST) process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8085";
if (!process.env.FIREBASE_AUTH_EMULATOR_HOST) process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";

if (!/^(127\.0\.0\.1|localhost|\[::1\]|10\.0\.2\.2)(:\d+)?$/.test(process.env.FIRESTORE_EMULATOR_HOST)) {
  console.error("FATAL: FIRESTORE_EMULATOR_HOST must be local.");
  process.exit(1);
}

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "hellochat-e8965";
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: process.env.GCLOUD_PROJECT });

const assert = require("assert");
const path = require("path");
const functionsModule = require(path.join(__dirname, "..", "functions", "index.js"));
const admin = require(path.join(__dirname, "..", "functions", "node_modules", "firebase-admin"));
const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const AGENCY_A = "uat-agency-alpha";
const AGENCY_B = "uat-agency-beta";
const OWNER = "uat-owner";
const ADMIN = "uat-admin-1";
const AGENCY_OWNER = "uat-agency-alpha-owner";
const HOST_ONE = "uat-host-alpha-1";
const HOST_TWO = "uat-host-alpha-2";
const USER_ONE = "uat-user-1";
const USER_THREE = "uat-user-3";
const TEMP_STALE = "uat-edge-stale-owner-agency";
const TEMP_ADMIN = "uat-edge-admin-owned-agency";
const TEMP_INACTIVE = "uat-edge-inactive-agency";
const TEMP_ZERO = "uat-edge-zero-agency";
const TEMP_SPLIT = "uat-edge-split-agency";

let passed = 0;

function auth(uid) {
  return { uid, token: { uid } };
}

async function call(name, data, uid) {
  const fn = functionsModule[name];
  if (!fn) throw new Error(`Missing function: ${name}`);
  const handler = fn.run || fn;
  return handler(data, { auth: auth(uid) });
}

function check(name, fn) {
  return Promise.resolve()
    .then(fn)
    .then(() => {
      passed++;
      console.log(`[PASS] ${name}`);
    });
}

async function get(pathName) {
  const snap = await db.doc(pathName).get();
  assert.ok(snap.exists, `${pathName} must exist`);
  return snap.data();
}

async function setUser(uid, patch) {
  await db.doc(`users/${uid}`).set(patch, { merge: true });
}

async function setAgency(id, patch) {
  await db.doc(`agencies/${id}`).set(patch, { merge: true });
}

async function setAgencyBaseline() {
  await setUser(AGENCY_OWNER, {
    role: "agency",
    previousRole: "user",
    isAgencyOwner: true,
    agencyId: AGENCY_A,
    tags: ["Agency"],
    usdCommissionBalance: 0,
    pendingWithdrawalBalance: 0,
    totalCommissionEarned: 0,
    totalRechargeGenerated: 0,
    totalWithdrawnUSD: 0,
  });
  await setUser(HOST_ONE, {
    role: "host",
    isHost: true,
    isAgencyOwner: false,
    agencyId: AGENCY_A,
    tags: [],
    adminId: ADMIN,
    usdCommissionBalance: 0,
  });
  await setUser(HOST_TWO, {
    role: "host",
    isHost: true,
    isAgencyOwner: false,
    agencyId: AGENCY_A,
    tags: [],
    adminId: "uat-admin-2",
    usdCommissionBalance: 0,
  });
  await setUser(USER_ONE, {
    role: "user",
    isAgencyOwner: false,
    agencyId: null,
    tags: [],
    usdCommissionBalance: 0,
  });
  await setUser(USER_THREE, {
    role: "user",
    isAgencyOwner: false,
    agencyId: null,
    tags: [],
    usdCommissionBalance: 0,
    diamondBalance: 0,
  });
  await setUser(ADMIN, {
    role: "admin",
    isAgencyOwner: false,
    agencyId: null,
    tags: ["Admin"],
    usdCommissionBalance: 0,
  });
  await setAgency(AGENCY_A, {
    id: AGENCY_A,
    name: "UAT Agency Alpha",
    ownerUid: AGENCY_OWNER,
    ownerName: "UAT Agency Alpha Owner",
    isActive: true,
    status: "active",
    hostUids: [HOST_ONE, HOST_TWO],
    hostCount: 2,
    beansBalance: 0,
    usdCommissionBalance: 0,
    pendingWithdrawalBalance: 0,
    totalCommissionEarned: 0,
    totalRechargeGenerated: 0,
    totalWithdrawnUSD: 0,
  });
  await setAgency(AGENCY_B, {
    id: AGENCY_B,
    name: "UAT Agency Beta",
    ownerUid: "uat-agency-beta-owner",
    ownerName: "UAT Agency Beta Owner",
    isActive: true,
    status: "active",
    hostUids: [],
    hostCount: 0,
    usdCommissionBalance: 0,
    pendingWithdrawalBalance: 0,
  });
}

async function deleteTempAgency(id) {
  await db.doc(`agencies/${id}`).delete().catch(() => {});
}

async function main() {
  console.log("UAT edge cases against local Firebase emulators");
  console.log(`Firestore: ${process.env.FIRESTORE_EMULATOR_HOST}`);
  await setAgencyBaseline();

  try {
    await check("normal user who owns an agency cannot withdraw or spend agency USD", async () => {
      await setUser(USER_THREE, {
        role: "user",
        isAgencyOwner: false,
        agencyId: TEMP_STALE,
        usdCommissionBalance: 0,
        diamondBalance: 0,
      });
      await setAgency(TEMP_STALE, {
        id: TEMP_STALE,
        name: "UAT Stale Owner Agency",
        ownerUid: USER_THREE,
        isActive: true,
        status: "active",
        usdCommissionBalance: 50,
      });

      await assert.rejects(
        () => call("submitCommissionWithdrawal", {
          usdAmount: 10,
          paymentMethod: "bKash",
          paymentAccountDetails: "01700000000",
          clientRequestId: `edge-stale-${Date.now()}`,
        }, USER_THREE),
        /permission-denied|Agency and Admin/i,
      );
      await assert.rejects(
        () => call("convertCommissionToDiamonds", {
          usdAmount: 10,
          clientRequestId: `edge-stale-convert-${Date.now()}`,
        }, USER_THREE),
        /insufficient|Insufficient/i,
      );

      const agency = await get(`agencies/${TEMP_STALE}`);
      const user = await get(`users/${USER_THREE}`);
      assert.strictEqual(agency.usdCommissionBalance, 50);
      assert.strictEqual(user.diamondBalance, 0);
      console.log("       agency USD 50 remains locked; conversion did not touch it");
    });

    await check("Admin-tier agency owner can spend the agency wallet", async () => {
      await setUser(ADMIN, {
        role: "admin",
        isAgencyOwner: true,
        agencyId: TEMP_ADMIN,
        tags: ["Admin"],
        usdCommissionBalance: 0,
        diamondBalance: 0,
      });
      await setAgency(TEMP_ADMIN, {
        id: TEMP_ADMIN,
        name: "UAT Admin Owned Agency",
        ownerUid: ADMIN,
        isActive: true,
        status: "active",
        usdCommissionBalance: 40,
      });

      await call("convertCommissionToDiamonds", {
        usdAmount: 5,
        clientRequestId: `edge-admin-${Date.now()}`,
      }, ADMIN);

      const agency = await get(`agencies/${TEMP_ADMIN}`);
      assert.strictEqual(agency.usdCommissionBalance, 35);
      console.log("       admin owner converted $5 from agency USD 40 -> 35");
    });

    await check("non-owner agency staff cannot spend another owner's agency wallet", async () => {
      await setUser(USER_ONE, {
        role: "agency",
        isAgencyOwner: false,
        agencyId: AGENCY_A,
        tags: ["Agency"],
        usdCommissionBalance: 0,
      });
      await setAgency(AGENCY_A, { usdCommissionBalance: 20, pendingWithdrawalBalance: 0 });

      await assert.rejects(
        () => call("submitCommissionWithdrawal", {
          usdAmount: 10,
          paymentMethod: "bKash",
          paymentAccountDetails: "01700000000",
          clientRequestId: `edge-staff-${Date.now()}`,
        }, USER_ONE),
        /insufficient|Insufficient/i,
      );

      const agency = await get(`agencies/${AGENCY_A}`);
      assert.strictEqual(agency.usdCommissionBalance, 20);
      assert.strictEqual(agency.pendingWithdrawalBalance, 0);
      console.log("       agency USD 20 unchanged; request rejected");
    });

    await check("inactive agency wallet is not spendable", async () => {
      await setUser(USER_THREE, {
        role: "agency",
        isAgencyOwner: true,
        agencyId: TEMP_INACTIVE,
        tags: ["Agency"],
        usdCommissionBalance: 5,
        diamondBalance: 0,
      });
      await setAgency(TEMP_INACTIVE, {
        id: TEMP_INACTIVE,
        name: "UAT Inactive Agency",
        ownerUid: USER_THREE,
        isActive: false,
        status: "deactivated",
        usdCommissionBalance: 40,
        pendingWithdrawalBalance: 0,
      });

      await assert.rejects(
        () => call("convertCommissionToDiamonds", {
          usdAmount: 10,
          clientRequestId: `edge-inactive-${Date.now()}`,
        }, USER_THREE),
        /insufficient|Insufficient/i,
      );

      const agency = await get(`agencies/${TEMP_INACTIVE}`);
      const user = await get(`users/${USER_THREE}`);
      assert.strictEqual(agency.usdCommissionBalance, 40);
      assert.strictEqual(user.usdCommissionBalance, 5);
      assert.strictEqual(user.diamondBalance, 0);
      console.log("       inactive agency USD 40 untouched; only legacy $5 was visible");
    });

    await check("zero balance request fails without writing a request", async () => {
      await setUser(USER_THREE, {
        role: "agency",
        isAgencyOwner: true,
        agencyId: TEMP_ZERO,
        tags: ["Agency"],
        usdCommissionBalance: 0,
      });
      await setAgency(TEMP_ZERO, {
        id: TEMP_ZERO,
        name: "UAT Zero Agency",
        ownerUid: USER_THREE,
        isActive: true,
        status: "active",
        usdCommissionBalance: 0,
        pendingWithdrawalBalance: 0,
      });
      const before = await db.collection("commission_withdrawals")
        .where("userId", "==", USER_THREE).get();

      await assert.rejects(
        () => call("submitCommissionWithdrawal", {
          usdAmount: 10,
          paymentMethod: "bKash",
          paymentAccountDetails: "01700000000",
          clientRequestId: `edge-zero-${Date.now()}`,
        }, USER_THREE),
        /insufficient|Insufficient/i,
      );

      const after = await db.collection("commission_withdrawals")
        .where("userId", "==", USER_THREE).get();
      assert.strictEqual(after.size, before.size);
      console.log("       no withdrawal document created");
    });

    await check("legacy balance is spent before agency balance with no double debit", async () => {
      await setUser(USER_THREE, {
        role: "agency",
        isAgencyOwner: true,
        agencyId: TEMP_SPLIT,
        tags: ["Agency"],
        usdCommissionBalance: 5,
        diamondBalance: 0,
      });
      await setAgency(TEMP_SPLIT, {
        id: TEMP_SPLIT,
        name: "UAT Split Agency",
        ownerUid: USER_THREE,
        isActive: true,
        status: "active",
        usdCommissionBalance: 10,
        pendingWithdrawalBalance: 0,
      });

      const clientRequestId = `edge-split-${Date.now()}`;
      await call("convertCommissionToDiamonds", { usdAmount: 12, clientRequestId }, USER_THREE);

      const agency = await get(`agencies/${TEMP_SPLIT}`);
      const user = await get(`users/${USER_THREE}`);
      const logs = await db.collection("commission_diamond_conversions")
        .where("userId", "==", USER_THREE).get();
      assert.ok(!logs.empty, "conversion log required");
      const log = logs.docs
        .map((d) => d.data())
        .sort((a, b) => (b.createdAt?.toMillis?.() || 0) - (a.createdAt?.toMillis?.() || 0))[0];
      assert.strictEqual(agency.usdCommissionBalance, 3);
      assert.strictEqual(user.usdCommissionBalance, 0);
      assert.strictEqual(user.diamondBalance, 12000000);
      assert.strictEqual(log.userDebitUSD, 5);
      assert.strictEqual(log.agencyDebitUSD, 7);
      console.log("       split user $5 + agency $7; agency left $3; diamonds 12,000,000");
    });

    await check("releaseHostFromAgency also removes the host from the agency roster", async () => {
      await setUser(HOST_TWO, { role: "host", agencyId: AGENCY_A, adminId: "uat-admin-2" });
      await setAgency(AGENCY_A, { hostUids: [HOST_ONE, HOST_TWO], hostCount: 2 });

      await call("releaseHostFromAgency", { hostUid: HOST_TWO }, OWNER);

      const host = await get(`users/${HOST_TWO}`);
      const agency = await get(`agencies/${AGENCY_A}`);
      assert.strictEqual(host.agencyId, null);
      assert.deepStrictEqual(agency.hostUids, [HOST_ONE]);
      assert.strictEqual(agency.hostCount, 1);
      console.log("       roster [" + agency.hostUids.join(", ") + "], hostCount 1");
    });

    await check("deactivateAgency clears the roster while retaining balances", async () => {
      await setUser(AGENCY_OWNER, {
        role: "agency",
        isAgencyOwner: true,
        agencyId: AGENCY_A,
        tags: ["Agency"],
        previousRole: "user",
      });
      await setUser(HOST_ONE, { role: "host", isHost: true, agencyId: AGENCY_A });
      await setAgency(AGENCY_A, {
        isActive: true,
        status: "active",
        hostUids: [HOST_ONE],
        hostCount: 1,
        usdCommissionBalance: 20,
        pendingWithdrawalBalance: 0,
      });

      await call("deactivateAgency", { agencyUid: AGENCY_OWNER }, OWNER);

      const agency = await get(`agencies/${AGENCY_A}`);
      const owner = await get(`users/${AGENCY_OWNER}`);
      assert.strictEqual(agency.isActive, false);
      assert.deepStrictEqual(agency.hostUids, []);
      assert.strictEqual(agency.hostCount, 0);
      assert.strictEqual(agency.usdCommissionBalance, 20);
      assert.strictEqual(owner.role, "host");
      assert.strictEqual(owner.isAgencyOwner, false);
      console.log("       inactive, roster empty, USD 20 retained, owner role host");
    });
  } finally {
    await Promise.all([
      TEMP_STALE, TEMP_ADMIN, TEMP_INACTIVE, TEMP_ZERO, TEMP_SPLIT,
    ].map(deleteTempAgency));
    await setUser(HOST_TWO, { role: "host", isHost: true, agencyId: AGENCY_A, adminId: "uat-admin-2" });
    await setUser(HOST_ONE, { role: "host", isHost: true, agencyId: AGENCY_A, adminId: ADMIN });
    await setUser(USER_ONE, { role: "user", isAgencyOwner: false, agencyId: null, tags: [] });
    await setUser(USER_THREE, { role: "user", isAgencyOwner: false, agencyId: null, tags: [] });
    await setUser(ADMIN, { role: "admin", isAgencyOwner: false, agencyId: null, tags: ["Admin"] });
    await setUser(AGENCY_OWNER, {
      role: "agency",
      previousRole: "user",
      isAgencyOwner: true,
      agencyId: AGENCY_A,
      tags: ["Agency"],
    });
    await setAgency(AGENCY_A, {
      isActive: true,
      status: "active",
      hostUids: [HOST_ONE, HOST_TWO],
      hostCount: 2,
      usdCommissionBalance: 0,
      pendingWithdrawalBalance: 0,
    });
  }

  console.log(`\nTOTAL: ${passed} edge checks passed.`);
}

main().catch((err) => {
  console.error("UAT edge runner failed:", err);
  process.exit(1);
});
