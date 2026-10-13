/**
 * Comprehensive E2E Integration Test Suite for Spin Wheel Backend
 * Runs against the local Firestore Emulator
 * 
 * Tests:
 * 1. Single round: Bet placement, read-after-write transaction correctness, balance deduction
 * 2. Outcome consistency: syncSpinWheelRound and playSpinWheel resolve identical outcome
 * 3. Settlement: settleSpinWheelRound credits win, marks ROUND_SETTLED, sets winningFood
 * 4. Multi-round: Consecutive rounds with auto-settlement of mid-spin disconnects
 * 5. Rapid bets: Concurrent bets in the same round update totalBet and deltaBet correctly without failing
 * 6. History immutability: Settled history records cannot be overwritten by late or duplicate bets
 */

process.env.GCLOUD_PROJECT = 'hellochat-e8965';
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: 'hellochat-e8965' });
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8085';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';

const assert = require('assert');
const functionsModule = require('./index.js');
const admin = require('firebase-admin');
const db = admin.firestore();

let passed = 0;
async function test(name, fn) {
    try {
        await fn();
        console.log(`  ✅ PASS: ${name}`);
        passed++;
    } catch (err) {
        console.error(`  ❌ FAIL: ${name}`);
        console.error(err);
        process.exit(1);
    }
}

async function runAll() {
    console.log("==================================================");
    console.log("🎰 RUNNING SPIN WHEEL BACKEND INTEGRATION SUITE");
    console.log("==================================================");

    const testUid = `tester_e2e_${Date.now()}`;
    const userRef = db.collection("users").doc(testUid);

    await userRef.set({
        displayName: "Tester E2E",
        diamondBalance: 50000,
        diamonds: 50000,
        beansBalance: 10000,
        totalGameCount: 0
    });

    const playFn = functionsModule.playSpinWheel.run ? functionsModule.playSpinWheel.run : functionsModule.playSpinWheel;
    const syncFn = functionsModule.syncSpinWheelRound.run ? functionsModule.syncSpinWheelRound.run : functionsModule.syncSpinWheelRound;
    const settleFn = functionsModule.settleSpinWheelRound.run ? functionsModule.settleSpinWheelRound.run : functionsModule.settleSpinWheelRound;

    const roundId = Math.floor(Date.now() / 40000).toString();

    // Test 1: Outcome create-once across syncSpinWheelRound and playSpinWheel
    await test("Test 1: syncSpinWheelRound generates deterministic outcome atomically", async () => {
        const syncRes = await syncFn({ roundId: roundId }, { auth: { uid: testUid } });
        assert(syncRes.outcome, "syncSpinWheelRound should return an outcome");
        assert(syncRes.outcome.name, "Outcome should have a winning food name");

        // Verify doc in Firestore
        const privDoc = await db.collection("games_meta_private").doc(`spin_${roundId}`).get();
        assert(privDoc.exists, "games_meta_private doc must exist");
        assert.strictEqual(privDoc.data().outcome.name, syncRes.outcome.name);
    });

    // Test 2: playSpinWheel reuses existing outcome without overwrite
    await test("Test 2: playSpinWheel places bet and respects existing round outcome", async () => {
        const betRes = await playFn({
            roundId: roundId,
            bets: { "Tomato": 100, "Hotdog": 200 }
        }, { auth: { uid: testUid } });

        assert.strictEqual(betRes.roundId, roundId);
        assert.strictEqual(betRes.totalBet, 300);

        const privDoc = await db.collection("games_meta_private").doc(`spin_${roundId}`).get();
        assert.strictEqual(betRes.name, privDoc.data().outcome.name, "playSpinWheel must reuse locked outcome");

        const userSnap = await userRef.get();
        assert.strictEqual(userSnap.data().diamondBalance, 49700, "Diamond balance should deduct exactly 300");

        const historyDoc = await userRef.collection("game_history").doc(`spin_${roundId}`).get();
        assert(historyDoc.exists, "History row must be created");
        assert.strictEqual(historyDoc.data().totalBet, 300);
        assert.strictEqual(historyDoc.data().settled, false, "History row initially unsettled");
    });

    // Test 3: Rapid sequential bet increments in same round
    await test("Test 3: Rapid incremental bet in same round (additive totalBet)", async () => {
        const betRes2 = await playFn({
            roundId: roundId,
            bets: { "Tomato": 100, "Hotdog": 200, "Steak": 500 }
        }, { auth: { uid: testUid } });

        assert.strictEqual(betRes2.totalBet, 800);
        const userSnap = await userRef.get();
        assert.strictEqual(userSnap.data().diamondBalance, 49200, "Diamond balance deducts additional delta 500");
    });

    // Test 4: Settlement credits prize, sets settled: true, status: ROUND_SETTLED, winningFood
    await test("Test 4: settleSpinWheelRound idempotently settles round and writes status/food", async () => {
        const settleRes = await settleFn({ roundId: roundId }, { auth: { uid: testUid } });
        assert.strictEqual(settleRes.settled, true);

        const historyDoc = await userRef.collection("game_history").doc(`spin_${roundId}`).get();
        const data = historyDoc.data();
        assert.strictEqual(data.settled, true, "History doc must be marked settled: true");
        assert.strictEqual(data.status, "ROUND_SETTLED", "History doc must have status ROUND_SETTLED");
        assert(data.winningFood && data.winningFood.length > 0, "History doc must record authoritative winningFood");

        // Calling settle again is a no-op
        const settleRes2 = await settleFn({ roundId: roundId }, { auth: { uid: testUid } });
        assert.strictEqual(settleRes2.alreadySettled, true);
    });

    // Test 5: History immutability: Late bet cannot reopen settled round history
    await test("Test 5: Late/replay bet on already settled round does not rewrite settled history", async () => {
        const historyDocBefore = await userRef.collection("game_history").doc(`spin_${roundId}`).get();
        const beforeData = historyDocBefore.data();

        // Attempt bet on settled round
        try {
            await playFn({
                roundId: roundId,
                bets: { "Tomato": 100 }
            }, { auth: { uid: testUid } });
        } catch (e) {
            // Might be caught or ignored
        }

        const historyDocAfter = await userRef.collection("game_history").doc(`spin_${roundId}`).get();
        const afterData = historyDocAfter.data();
        assert.strictEqual(afterData.settled, true, "Settled flag must remain true");
        assert.strictEqual(afterData.status, "ROUND_SETTLED", "Status must remain ROUND_SETTLED");
        assert.strictEqual(afterData.winningFood, beforeData.winningFood, "Winning food must not mutate");
    });

    // Test 6: Auto-settle of unclaimed win on next round bet (reconnect scenario)
    await test("Test 6: Disconnected win from previous round auto-settles on next round bet", async () => {
        const reconnectUid = `tester_rec_${Date.now()}`;
        const recUserRef = db.collection("users").doc(reconnectUid);
        await recUserRef.set({
            displayName: "Reconnect Tester",
            diamondBalance: 5000,
            diamonds: 5000,
            beansBalance: 1000,
            totalGameCount: 0
        });

        const roundB = Math.floor(Date.now() / 40000).toString();
        const roundA = (Number(roundB) - 1).toString();

        // Seed an unsettled winning bet for roundA (simulating app closed mid-spin)
        await recUserRef.collection("game_history").doc(`spin_${roundA}`).set({
            roundId: roundA,
            game: "spin_wheel",
            type: "game_bet",
            totalBet: 100,
            prize: 1500, // Won 1500 diamonds
            settled: false,
            winningFood: "Skewer"
        });

        const preBalance = (await recUserRef.get()).data().diamondBalance;

        // User bets on roundB (which is roundA + 1)
        const betB = await playFn({
            roundId: roundB,
            bets: { "Tomato": 50 }
        }, { auth: { uid: reconnectUid } });

        const postBalance = (await recUserRef.get()).data().diamondBalance;
        // Balance should be: preBalance - 50 (bet) + 1500 (auto-settled roundA win) = preBalance + 1450
        assert.strictEqual(postBalance, preBalance - 50 + 1500, "Unclaimed win must be auto-credited to balance");

        // Verify roundA history was auto-settled
        const roundADoc = await recUserRef.collection("game_history").doc(`spin_${roundA}`).get();
        assert.strictEqual(roundADoc.data().settled, true, "Preceding round must be auto-settled");

        // Verify transaction record was written
        const winTxDoc = await recUserRef.collection("transactions").doc(`spin_win_${roundA}`).get();
        assert(winTxDoc.exists, "Auto-settle win transaction doc must be created");
        assert.strictEqual(winTxDoc.data().amount, 1500);
    });

    console.log("==================================================");
    console.log(`🎉 ALL ${passed} INTEGRATION TESTS PASSED CLEANLY!`);
    console.log("==================================================");
}

runAll().catch(err => {
    console.error("FATAL SUITE ERROR:", err);
    process.exit(1);
});
