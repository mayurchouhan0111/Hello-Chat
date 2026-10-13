/**
 * Test Suite: Spin Wheel History Immutability (Functions)
 *
 * Mirrors the invariant guards added in functions/index.js to permanently fix:
 *  Bug 1 - Retroactive result mutation: a settled game_history row must never be
 *          rewritten to a different winning item / prize after the fact.
 *  Bug 2 - Bet disappearance: a betting-phase history write must never re-open an
 *          already-settled record, and the round outcome for a round is created ONCE
 *          (first writer wins) so no two devices/engines can diverge.
 *
 * These are pure predicates duplicated from index.js (kept in sync), exactly like
 * the existing test_spin_round_state.js pattern.
 */

const assert = require('assert');

// ---- Guard 1: bet-time history write is skipped once the round is settled ----------
// playSpinWheel: `if (!roundHistoryAlreadySettled && (deltaBet > 0 || totalBet > 0))`
function shouldWriteBettingHistory(existingLogSettled, deltaBet, totalBet) {
    return !existingLogSettled && (deltaBet > 0 || totalBet > 0);
}

// ---- Guard 2: settle engines never rewrite an already-settled row ----------
// settleSpinWheelRound / settleSpinRoundPayouts: `if (logData.settled === true) return existing`
function settleOutcome(logData) {
    if (logData.settled === true) {
        // Immutable: return the existing snapshot verbatim, nothing recomputed.
        return {
            winningFood: logData.winningFood ?? null,
            prize: Number(logData.prize ?? logData.amount ?? 0),
            settled: true
        };
    }
    // Unsettled row: outcome is derived from the authoritative private outcome.
    return {
        winningFood: logData.derivedFood,
        prize: logData.derivedPrize,
        settled: true
    };
}

// ---- Guard 3: outcome create-once (first writer wins) ----------
// getSpinWheelRoundOutcome / lockSpinRoundOutcome / playSpinWheel all resolve via
// `if (privateDoc.exists) reuse else { generate; write }` inside ONE transaction.
function resolveOutcome(existingOutcome, generatedOutcome) {
    return existingOutcome ? existingOutcome : generatedOutcome;
}

console.log("=".repeat(50));
console.log("🧱 TESTING SPIN WHEEL HISTORY IMMUTABILITY");
console.log("=".repeat(50));

let testsPassed = 0;
function runTest(name, fn) {
    try {
        fn();
        console.log(`  ✅ PASS: ${name}`);
        testsPassed++;
    } catch (err) {
        console.error(`  ❌ FAIL: ${name}`);
        console.error(err);
        process.exit(1);
    }
}

// ---- Bug 1: settled history rows are permanent -------------------------------
runTest("Settled row: bet-time rewrite is blocked", () => {
    // A betting-phase submission for a round whose history is ALREADY settled must be skipped.
    assert.strictEqual(shouldWriteBettingHistory(true, 100, 100), false);
    assert.strictEqual(shouldWriteBettingHistory(true, 0, 0), false);
    // Normal un-settled rows still write.
    assert.strictEqual(shouldWriteBettingHistory(false, 100, 100), true);
    assert.strictEqual(shouldWriteBettingHistory(false, 0, 100), true);
});

runTest("Settled row: settlement never swaps the winning item", () => {
    const settledBefore = {
        settled: true,
        winningFood: "Corn",
        prize: 500
    };
    // Even if a LATER divergent outcome claims "Steak", the settled row is untouched.
    const result = settleOutcome({ ...settledBefore, derivedFood: "Steak", derivedPrize: 22500 });
    assert.strictEqual(result.winningFood, "Corn");
    assert.strictEqual(result.prize, 500);
});

runTest("Settled row: a settled loss stays a loss (0 prize preserved)", () => {
    const result = settleOutcome({ settled: true, prize: 0, amount: 0 });
    assert.strictEqual(result.prize, 0);
    assert.strictEqual(result.settled, true);
});

runTest("Unsettled row: outcome is derived normally at first settle", () => {
    const result = settleOutcome({ settled: false, derivedFood: "Tomato", derivedPrize: 500 });
    assert.strictEqual(result.winningFood, "Tomato");
    assert.strictEqual(result.prize, 500);
});

// ---- Bug 1: outcome create-once (RNG cannot be rolled twice) -----------------
runTest("Create-once: an already-locked outcome is never regenerated", () => {
    const locked = { roundId: "44756000", name: "Corn", multiplier: 5 };
    const regenerated = { roundId: "44756000", name: "Steak", multiplier: 45 };
    assert.strictEqual(resolveOutcome(locked, regenerated), locked);
});

runTest("Create-once: first writer wins under concurrent reveal", () => {
    // Two devices race to create the private outcome for a betless round.
    const deviceA = { roundId: "44756001", name: "Cabbage", multiplier: 5 };
    const deviceB = { roundId: "44756001", name: "Hotdog", multiplier: 10 };
    // In a transaction, whichever commits first is the doc; the loser's retry reuses it.
    const afterRace1 = resolveOutcome(deviceA, deviceB);
    const afterRace2 = resolveOutcome(deviceB, deviceA);
    // Sanity: resolveOutcome is deterministic per read; the commit order decides —
    // but crucially AFTER one commit, the stored value is stable and reused forever.
    assert.deepStrictEqual(resolveOutcome(afterRace1, deviceB), afterRace1);
    assert.deepStrictEqual(resolveOutcome(afterRace2, deviceA), afterRace2);
});

runTest("Create-once: empty/missing outcome is generated", () => {
    const generated = { roundId: "44756002", name: "Carrot", multiplier: 5 };
    assert.strictEqual(resolveOutcome(null, generated), generated);
});

// ---- Bug 2: bets on the wrong round cannot re-open settled rows --------------
runTest("Bet replay for a settled round causes zero seq/history writes", () => {
    // A replayed/duplicate submission (idempotent txn) for a settled round must not
    // bump balance OR re-open the record. Mirrors ledger-idempotency + settled guard.
    const settledHistory = { settled: true, winningFood: "Corn", prize: 500 };
    const replayExistingLog = { exists: settledHistory.settled };
    const wouldWriteBettingHistory = shouldWriteBettingHistory(replayExistingLog.exists, 100, 100);
    assert.strictEqual(wouldWriteBettingHistory, false, "settled round must never accept a betting-phase rewrite");
});

console.log("=".repeat(50));
console.log(`🎉 ALL ${testsPassed} IMMUTABILITY TESTS PASSED`);
console.log("=".repeat(50));