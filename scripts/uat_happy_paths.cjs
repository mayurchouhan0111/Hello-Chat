// scripts/uat_happy_paths.cjs
//
// Runs the seeded UAT happy paths against the local emulator.
// Emulator only; it refuses to touch any remote project.

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

const AGENCY_A_ID = "uat-agency-alpha";
const OWNER_UID = "uat-owner";
const ADMIN_UID = "uat-admin-1";
const AGENCY_UID = "uat-agency-alpha-owner";
const HOST_ONE = "uat-host-alpha-1";
const HOST_TWO = "uat-host-alpha-2";
const USER_UID = "uat-user-1";
const ROOM_ID = "uat-room-alpha";
const GIFT_ID = "uat-gift-standard";
const RECHARGE_USD = 100;

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

async function doc(pathName) {
  const snap = await db.doc(pathName).get();
  assert.ok(snap.exists, `${pathName} must exist`);
  return snap.data();
}

async function main() {
  console.log("UAT happy paths against local Firebase emulators");
  console.log(`Firestore: ${process.env.FIRESTORE_EMULATOR_HOST}`);

  const now = admin.firestore.Timestamp.now();
  const batch = db.batch();
  batch.set(db.collection("rooms").doc(ROOM_ID), {
    id: ROOM_ID,
    name: "UAT Alpha Room",
    ownerUid: HOST_ONE,
    status: "active",
    isActive: true,
    createdAt: now,
    updatedAt: now,
  });
  batch.set(db.collection("gifts").doc(GIFT_ID), {
    id: GIFT_ID,
    name: "UAT Standard Gift",
    priceInDiamonds: 1000,
    category: "normal",
    imageUrl: "",
    isActive: true,
    createdAt: now,
  });
  await batch.commit();

  const seedAgency = await doc(`agencies/${AGENCY_A_ID}`);
  assert.strictEqual(seedAgency.usdCommissionBalance, 0);
  assert.strictEqual(seedAgency.beansBalance, 0);

  await check("gift to an agency host credits the agency bean wallet", async () => {
    const beforeAgency = await doc(`agencies/${AGENCY_A_ID}`);
    const beforeHost = await doc(`users/${HOST_ONE}`);
    const beforeSender = await doc(`users/${USER_UID}`);

    const result = await call("sendGiftWithCombo", {
      roomId: ROOM_ID,
      giftId: GIFT_ID,
      quantity: 1,
      targetUid: HOST_ONE,
      comboCount: 0,
      isMoment: false,
    }, USER_UID);
    assert.ok(result && result.success !== false, "gift callable must succeed");

    const afterAgency = await doc(`agencies/${AGENCY_A_ID}`);
    const afterHost = await doc(`users/${HOST_ONE}`);
    const afterSender = await doc(`users/${USER_UID}`);

    assert.strictEqual(afterAgency.beansBalance - beforeAgency.beansBalance, 100);
    assert.strictEqual(afterHost.beansBalance - beforeHost.beansBalance, 700);
    assert.strictEqual(afterSender.diamondBalance - beforeSender.diamondBalance, -1000);
    console.log(`       agency beans +${afterAgency.beansBalance - beforeAgency.beansBalance}, host beans +${afterHost.beansBalance - beforeHost.beansBalance}, sender diamonds ${afterSender.diamondBalance - beforeSender.diamondBalance}`);
  });

  await check("approved recharge credits agency and admin USD commission ledgers", async () => {
    const order = await call("issueRechargeOrder", {
      targetUid: HOST_ONE,
      diamonds: RECHARGE_USD * 1000000,
      usd: RECHARGE_USD,
      gateway: "bKash",
      paymentRef: "UAT-HAPPY-001",
    }, ADMIN_UID);

    const recharge = await call("rechargeDiamonds", { orderId: order.orderId }, HOST_ONE);
    assert.ok(recharge && recharge.success !== false, "recharge must succeed");

    const agency = await doc(`agencies/${AGENCY_A_ID}`);
    const adminUser = await doc(`users/${ADMIN_UID}`);
    const agencyLedger = await doc(`commission_transactions/rc_${order.orderId}_agency`);
    const adminLedger = await doc(`commission_transactions/rc_${order.orderId}_admin`);

    assert.strictEqual(agency.usdCommissionBalance, 30);
    assert.strictEqual(agency.totalCommissionEarned, 30);
    assert.strictEqual(agency.totalRechargeGenerated, RECHARGE_USD);
    assert.strictEqual(adminUser.usdCommissionBalance, 10);
    assert.strictEqual(agencyLedger.recipientUid, AGENCY_UID);
    assert.strictEqual(agencyLedger.commissionUSD, 30);
    assert.strictEqual(adminLedger.recipientUid, ADMIN_UID);
    assert.strictEqual(adminLedger.commissionUSD, 10);
    console.log(`       order ${order.orderId}; agency USD 30, admin USD 10`);
  });

  await check("agency owner can see the aggregated agency wallet", async () => {
    const agency = await doc(`agencies/${AGENCY_A_ID}`);
    assert.strictEqual(agency.ownerUid, AGENCY_UID);
    assert.strictEqual(agency.usdCommissionBalance, 30);
    console.log(`       owner ${AGENCY_UID} sees agency USD ${agency.usdCommissionBalance}`);
  });

  let requestId;
  await check("agency owner requests a $10 withdrawal from the agency wallet", async () => {
    const result = await call("submitCommissionWithdrawal", {
      usdAmount: 10,
      paymentMethod: "bKash",
      paymentAccountDetails: "01700000000",
      clientRequestId: `uat-happy-withdraw-${Date.now()}`,
    }, AGENCY_UID);
    requestId = result.requestId;
    assert.ok(requestId, "requestId required");

    const request = await doc(`commission_withdrawals/${requestId}`);
    const agency = await doc(`agencies/${AGENCY_A_ID}`);
    assert.strictEqual(request.status, "pending");
    assert.strictEqual(request.userDebitUSD, 0);
    assert.strictEqual(request.agencyDebitUSD, 10);
    assert.strictEqual(agency.usdCommissionBalance, 20);
    assert.strictEqual(agency.pendingWithdrawalBalance, 10);
    console.log(`       request ${requestId}; split user $0 / agency $10`);
  });

  await check("Owner processes, approves, and pays the withdrawal", async () => {
    await call("reviewCommissionWithdrawal", { requestId, action: "process" }, OWNER_UID);
    await call("reviewCommissionWithdrawal", { requestId, action: "approve" }, OWNER_UID);
    await call("reviewCommissionWithdrawal", { requestId, action: "pay" }, OWNER_UID);

    const request = await doc(`commission_withdrawals/${requestId}`);
    const agency = await doc(`agencies/${AGENCY_A_ID}`);
    assert.strictEqual(request.status, "paid");
    assert.strictEqual(request.approvedBy, OWNER_UID);
    assert.strictEqual(agency.pendingWithdrawalBalance, 0);
    assert.strictEqual(agency.totalWithdrawnUSD, 10);
    assert.strictEqual(agency.usdCommissionBalance, 20);
    console.log(`       paid by ${OWNER_UID}; agency balance $20, withdrawn $10`);
  });

  await check("agency owner removes a host from the agency roster", async () => {
    const result = await call("removeHost", { agencyId: AGENCY_A_ID, hostUid: HOST_TWO }, AGENCY_UID);
    assert.strictEqual(result.hostUid, HOST_TWO);
    const host = await doc(`users/${HOST_TWO}`);
    const agency = await doc(`agencies/${AGENCY_A_ID}`);
    assert.strictEqual(host.agencyId, null);
    assert.ok(!agency.hostUids.includes(HOST_TWO), "removed host must leave the roster");
    assert.strictEqual(agency.hostCount, 1);
    console.log(`       ${HOST_TWO} agencyId=null; roster count=${agency.hostCount}`);
  });

  await check("deactivating the agency releases remaining hosts and retains balances", async () => {
    const result = await call("deactivateAgency", { agencyUid: AGENCY_UID }, OWNER_UID);
    const agency = await doc(`agencies/${AGENCY_A_ID}`);
    const owner = await doc(`users/${AGENCY_UID}`);
    const host = await doc(`users/${HOST_ONE}`);

    assert.ok(result.releasedHosts >= 1, "at least one remaining host must be released");
    assert.strictEqual(agency.isActive, false);
    assert.strictEqual(agency.status, "deactivated");
    assert.strictEqual(agency.usdCommissionBalance, 20);
    assert.strictEqual(agency.totalWithdrawnUSD, 10);
    assert.strictEqual(owner.role, "host");
    assert.strictEqual(owner.isAgencyOwner, false);
    assert.strictEqual(host.agencyId, null);
    console.log(`       released ${result.releasedHosts} host(s); retained USD ${agency.usdCommissionBalance}`);
  });

  await check("deactivated agency cannot submit a new withdrawal", async () => {
    let denied = false;
    try {
      await call("submitCommissionWithdrawal", {
        usdAmount: 10,
        paymentMethod: "bKash",
        paymentAccountDetails: "01700000000",
      }, AGENCY_UID);
    } catch (err) {
      denied = true;
      assert.ok(/denied|available to Agency/i.test(err.message || ""), err.message);
    }
    assert.strictEqual(denied, true, "withdrawal must be denied after deactivation");
    console.log("       denied after deactivation");
  });

  console.log(`\nUAT_HAPPY_PATHS passed=${passed} failed=0`);
}

main().catch((err) => {
  console.error(`\nUAT_HAPPY_PATHS FAILED after ${passed} passing check(s)`);
  console.error(err.stack || err.message || err);
  process.exitCode = 1;
});
