// functions/test_salary_behavioral_suite.js
const assert = require("assert");
const path = require("path");
const admin = require("firebase-admin");

// Trim emulator host to prevent cmd space issues
process.env.FIRESTORE_EMULATOR_HOST = (process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8085").trim();


if (!admin.apps.length) {
    admin.initializeApp({ projectId: "hellochat-e8965" });
}
const db = admin.firestore();

const { executeRoomSupportRewardDistribution } = require("./index.js");

let passed = 0;
let failed = 0;

async function runAsyncTest(name, fn) {
    try {
        await fn();
        passed++;
        console.log(`  [PASS] ${name}`);
    } catch (e) {
        failed++;
        console.error(`  [FAIL] ${name}`);
        console.error(`         ${e.stack || e.message}`);
    }
}

async function main() {
    console.log("==================================================");
    console.log("ROOM SUPPORT SALARY & MIGRATION BEHAVIORAL SUITE");
    console.log("Target Emulator:", process.env.FIRESTORE_EMULATOR_HOST);
    console.log("==================================================");

    const runId = Date.now();
    const testUid = `user_owner_${runId}`;
    const testRoomId = `room_${runId}`;
    const testWeekId = "2026-W44";

    // ----------------------------------------------------
    // TEST 1: End-to-end salary payout execution on Firestore
    // ----------------------------------------------------
    await runAsyncTest("1. Payout writes type: reward, category: room_support_salary, correct amount and description", async () => {
        // 1. Seed user with initial balance
        const userRef = db.collection("users").doc(testUid);
        await userRef.set({
            displayName: "Test Owner",
            diamondBalance: 50000,
            role: "user"
        });

        // 2. Seed room
        const roomRef = db.collection("rooms").doc(testRoomId);
        await roomRef.set({
            roomId: testRoomId,
            ownerUid: testUid,
            roomName: "Test Room"
        });

        // 3. Seed pending week history (achievedLevel: 1 -> 60,000 diamonds)
        const weekRef = roomRef.collection("weeks").doc(testWeekId);
        await weekRef.set({
            weekId: testWeekId,
            achievedLevel: 1,
            totalCoins: 2000000,
            distributionStatus: "pending"
        });

        // 3b. Seed 4 required partners in room_support_cycles
        const cyclePartnersCol = db.collection("room_support_cycles").doc(testRoomId).collection("partners");
        for (let i = 1; i <= 4; i++) {
            await cyclePartnersCol.doc(`partner_uid_${i}`).set({
                uid: `partner_uid_${i}`,
                cycleWeekId: testWeekId,
                status: "active"
            });
            await db.collection("users").doc(`partner_uid_${i}`).set({
                displayName: `Partner ${i}`,
                diamondBalance: 1000
            });
        }

        // 4. Run payout distribution
        const result = await executeRoomSupportRewardDistribution({ bypassDayCheck: true, testing: true });
        assert.strictEqual(result.success, true, "distribution should succeed");

        // 5. Assert user balance incremented
        const updatedUser = (await userRef.get()).data();
        assert.strictEqual(updatedUser.diamondBalance, 61250, "balance must be incremented by 11,250");

        // 6. Assert transaction document in users/{uid}/transactions
        const txSnap = await userRef.collection("transactions").get();
        assert.strictEqual(txSnap.size, 1, "exactly 1 transaction record must be created");
        const txData = txSnap.docs[0].data();

        assert.strictEqual(txData.type, "reward", "tx.type must be 'reward'");
        assert.strictEqual(txData.category, "room_support_salary", "tx.category must be 'room_support_salary'");
        assert.strictEqual(txData.action, "room_support_salary", "tx.action must be 'room_support_salary'");
        assert.strictEqual(txData.amount, 11250, "tx.amount must be 11250");
        assert.strictEqual(txData.role, "owner", "tx.role must be 'owner'");
        assert.strictEqual(txData.level, 1, "tx.level must be 1");
        assert.strictEqual(txData.roomId, testRoomId, "tx.roomId must match");
        assert.strictEqual(txData.weekId, testWeekId, "tx.weekId must match");
        assert.strictEqual(
            txData.description,
            `Official Weekly Room Owner Salary Reward (Room ${testRoomId}, Level 1)`,
            "tx.description must match official reward text"
        );
        assert.ok(txData.amount > 0, "tx direction must be positive (credit)");

        // 7. Assert deterministic reward doc exists
        const deterministicRewardId = `reward_${testWeekId}_${testUid}`;
        const rewardDoc = await db.collection("room_support_rewards").doc(deterministicRewardId).get();
        assert.ok(rewardDoc.exists, "reward document must exist in room_support_rewards");
        assert.strictEqual(rewardDoc.data().amount, 11250);

        // 8. Assert week history status marked distributed
        const updatedWeek = (await weekRef.get()).data();
        assert.strictEqual(updatedWeek.distributionStatus, "distributed");
    });

    // ----------------------------------------------------
    // TEST 2: Idempotency on retry (no duplicate, balance unchanged)
    // ----------------------------------------------------
    await runAsyncTest("2. Idempotency on retry: no second transaction, balance completely unchanged", async () => {
        const userRef = db.collection("users").doc(testUid);

        // Record balance before retry
        const balanceBefore = (await userRef.get()).data().diamondBalance;

        // Run payout distribution AGAIN
        const retryResult = await executeRoomSupportRewardDistribution({ bypassDayCheck: true, testing: true });
        assert.strictEqual(retryResult.success, true);

        // Assert balance UNCHANGED
        const balanceAfter = (await userRef.get()).data().diamondBalance;
        assert.strictEqual(balanceAfter, balanceBefore, "balance must NOT change on retry");

        // Assert transaction count remains exactly 1
        const txSnap = await userRef.collection("transactions").get();
        assert.strictEqual(txSnap.size, 1, "transactions count must remain 1 on retry (no duplicate)");
    });

    // ----------------------------------------------------
    // TEST 3: Migration script lifecycle on emulator (--apply, second apply no-op, --rollback)
    // ----------------------------------------------------
    await runAsyncTest("3. Migration lifecycle on emulator: apply -> no-op second apply -> rollback", async () => {
        const migUid = "user_migration_test_1";
        const migUserRef = db.collection("users").doc(migUid);
        await migUserRef.set({ displayName: "Migration User" });

        // Seed 3 transactions
        const txCol = migUserRef.collection("transactions");
        const doc1Ref = txCol.doc("salary_w43_test");
        await doc1Ref.set({
            type: "official_salary",
            action: "official_salary",
            amount: 35500000,
            description: "Official Weekly Room Owner Salary - W43 catch-up (Room room_test, Level 18)",
            timestamp: admin.firestore.Timestamp.now()
        });

        const doc2Ref = txCol.doc("reversal_test");
        await doc2Ref.set({
            type: "balance_reconciliation",
            category: "wallet",
            amount: -90000,
            description: "System adjustment: Neutralized unauthorized automated salary milestone credit",
            timestamp: admin.firestore.Timestamp.now()
        });

        const doc3Ref = txCol.doc("genuine_recharge_test");
        await doc3Ref.set({
            type: "recharge",
            category: "official_recharge",
            amount: 1000000,
            description: "Official Diamond Recharge (+1,000,000 Diamonds)",
            timestamp: admin.firestore.Timestamp.now()
        });

        // Load migration functions
        const migScript = require("../scripts/migrate_salary_reward_category.cjs");

        // Step A: First Apply
        const applyReport = await migScript.executeMigration({
            isApply: true,
            isRollback: false,
            targetUid: migUid,
            db
        });
        assert.strictEqual(applyReport.matched, 2, "2 salary/reversal records must match");
        assert.strictEqual(applyReport.changed, 2, "2 records must be changed");
        assert.strictEqual(applyReport.genuineRecharges, 1, "1 genuine recharge must be detected");

        // Assert doc1 updated
        const doc1After = (await doc1Ref.get()).data();
        assert.strictEqual(doc1After.type, "reward");
        assert.strictEqual(doc1After.category, "room_support_salary");
        assert.strictEqual(doc1After.migratedFrom, "official_salary");

        // Assert doc2 updated
        const doc2After = (await doc2Ref.get()).data();
        assert.strictEqual(doc2After.type, "reward");
        assert.strictEqual(doc2After.category, "reward_adjustment");
        assert.strictEqual(doc2After.migratedFrom, "balance_reconciliation");

        // Assert doc3 (genuine recharge) completely unchanged
        const doc3After = (await doc3Ref.get()).data();
        assert.strictEqual(doc3After.type, "recharge");
        assert.strictEqual(doc3After.category, "official_recharge");
        assert.strictEqual(doc3After.migratedFrom, undefined);

        // Step B: Second Apply (Idempotent NO-OP)
        const secondApplyReport = await migScript.executeMigration({
            isApply: true,
            isRollback: false,
            targetUid: migUid,
            db
        });
        assert.strictEqual(secondApplyReport.changed, 0, "second apply must make 0 changes");
        assert.strictEqual(secondApplyReport.alreadyMigrated, 2, "2 records must be identified as already migrated");

        // Step C: Rollback
        const rollbackReport = await migScript.executeMigration({
            isApply: false,
            isRollback: true,
            targetUid: migUid,
            db
        });
        assert.strictEqual(rollbackReport.changed, 2, "rollback must revert 2 records");

        // Assert doc1 reverted
        const doc1Reverted = (await doc1Ref.get()).data();
        assert.strictEqual(doc1Reverted.type, "official_salary");
        assert.strictEqual(doc1Reverted.migratedFrom, undefined);

        // Assert doc2 reverted
        const doc2Reverted = (await doc2Ref.get()).data();
        assert.strictEqual(doc2Reverted.type, "balance_reconciliation");
        assert.strictEqual(doc2Reverted.migratedFrom, undefined);

        // Assert doc3 still untouched
        const doc3Reverted = (await doc3Ref.get()).data();
        assert.strictEqual(doc3Reverted.type, "recharge");
        assert.strictEqual(doc3Reverted.category, "official_recharge");
    });

    console.log("==================================================");
    console.log(`Behavioral Test Results: ${passed} passed, ${failed} failed`);
    console.log("==================================================");

    if (failed > 0) process.exit(1);
}

if (require.main === module) {
    main().catch(err => {
        console.error("Fatal test error:", err);
        process.exit(1);
    });
}

module.exports = { main };
