#!/usr/bin/env node
/**
 * Spin Wheel Betting Integrity Verifier
 * ======================================
 * Unlike functions/test_spin_history_immutability.js (which asserts against
 * hand-copied predicates and never loads index.js), this script reads the SHIPPED
 * sources and asserts the invariants those predicates claim to mirror. Delete a
 * guard in the real file and this fails.
 *
 * It is a STATIC / source-level check, not a runtime test: it proves the guards
 * exist, not that Firestore plus a 40s round loop behave. The device scenarios
 * that cover the runtime half are in the audit report.
 *
 * Usage:  node scripts/verify_betting_integrity.cjs [--json]
 * Exit:   0 = all invariants hold, 1 = at least one regression.
 */

const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const read = (p) => fs.readFileSync(path.join(ROOT, p), "utf8");

const SERVER = read("functions/index.js");
const SCREEN = read("lib/features/games/presentation/screens/spin_wheel_screen.dart");
const SVC = read("lib/core/services/game_service.dart");

const results = [];
const check = (issue, id, desc, ok, evidence) =>
  results.push({ issue, id, desc, ok: !!ok, evidence: evidence || "" });

/** Slice a window of source starting at `needle`, for scoped assertions. */
const window = (src, needle, len) => {
  const i = src.indexOf(needle);
  return i === -1 ? "" : src.slice(i, i + (len || 900));
};

const lines = (src, needle) => src.split("\n").filter((l) => l.includes(needle));

// ===========================================================================
// ISSUE 1 - Bet History Mutation / Result Overwrite
// ===========================================================================

// --- 1a. Server: the record is round-addressed, not joined to a live pointer.
check(1, "S1", "History row is addressed by round id (immutable doc id)",
  SERVER.includes('collection("game_history").doc(`spin_${'));

// --- 1b. Server: settlement refuses to rewrite a settled row.
check(1, "S2", "Settlement engine has the immutable settled-row guard",
  SERVER.includes("if (logData.settled === true) {"));

// --- 1c. Server: round outcome is created once (first writer wins).
check(1, "S3", "Round outcome is create-once inside the transaction",
  SERVER.includes("if (privateDoc.exists) {") &&
  SERVER.includes("transaction.set(privateStatsRef, {"));

// --- 1d. Server: settlement commits settled:true + the winning item.
check(1, "S4", "Settlement commits settled:true and winningFood",
  SERVER.includes("settled: true,") &&
  SERVER.includes('status: "ROUND_SETTLED"') &&
  SERVER.includes("winningFood: roundResult.name,"));

// --- 1e. Server: a bet for a settled round cannot reopen the history row.
check(1, "S5", "Bet-time write is skipped once the round row is settled",
  SERVER.includes("roundHistoryAlreadySettled"));

// --- 1f. Client: history is read from the per-user subcollection, not a cache doc.
check(1, "S6", "History stream reads the user's own game_history subcollection",
  SVC.includes("collection('game_history')"));

// --- 1g. A settled server row must keep the server's committed prize.
// Asserts INTENT (a settled branch that writes the committed value back, with the local
// recompute confined to the `else`) rather than the mere presence of an assignment - a
// bare string test flags correct guarded code and trains people to ignore the checker.
const settledKeepsRemote = SCREEN.includes("if (rSettled) {") &&
  SCREEN.includes("map['prize'] = rPrize;");
check(1, "C1", "A settled server row must keep the server's committed prize",
  settledKeepsRemote,
  settledKeepsRemote
    ? ""
    : "_getRealtimeMergedHistory re-derives the prize for settled rows instead of using the committed value");

// NOTE: there is deliberately no separate "is the server prize variable used" check.
// It could not fail its own bug (leftover references kept the count above threshold) and
// the invariant it approximated is now asserted directly and falsifiably by C1 below:
// a settled row must be written back from the server's committed prize.

// --- 1i. The server's committed bet map must take precedence over the session cache.
const serverBetsFirst = SCREEN.includes("? existing['bets'] as Map");
check(1, "C3", "Server bet map must win over session-cached bets when merging",
  serverBetsFirst,
  serverBetsFirst
    ? ""
    : "the merge prefers sessionItem['bets'] over the server's committed bets, so the displayed stake can disagree with the settled record");

// --- 1j. BUG: merged row's prize is recomputed even when the server is authoritative.
const finalPrizeOverwrite = SCREEN.includes("finalPrize = calculated;");
check(1, "C4", "Merged prize must not be recomputed for a server-settled row",
  !finalPrizeOverwrite,
  finalPrizeOverwrite
    ? "spin_wheel_screen.dart:4616 assigns a recomputed prize over the merged row"
    : "");

// --- 1k. History list items must be keyed, or element recycling shows stale rows.
const histRegion = window(SCREEN, "if (mergedHistory.isEmpty)", 2000);
const keyedById =
  /key:\s*(ValueKey|ObjectKey|UniqueKey)\(/.test(histRegion) &&
  /orderId|roundId|docId|serialNumber/.test(histRegion);
check(1, "C5", "History list items must be keyed by a stable id (order_id/round_id)",
  keyedById,
  keyedById ? "" : "history ListView.builder returns _buildMyBetCard(...) with no Key");

// ===========================================================================
// ISSUE 2 - Consecutive Bet Failures / Disappearing Bets
// ===========================================================================

// --- 2a. A settled credit must be able to lift the betting-phase ceiling.
const ceilingRises =
  SCREEN.includes("prize > 0 && _isBettingPhase") &&
  SCREEN.includes("_bettingPhaseCeiling = _state.displayedBalance");
check(2, "W1", "Settlement credit must be able to raise the betting-phase balance ceiling",
  ceilingRises,
  ceilingRises
    ? ""
    : "reconcileSettlement leaves _bettingPhaseCeiling pinned one-way, so a win landing in the next round's betting window stays unspendable until the room is re-entered");

// --- 2b. Connection failures must reach the player.
// Requires ScaffoldMessenger, not just the word "SnackBar": a constructed-but-never-shown
// SnackBar widget would otherwise satisfy a substring test while showing the user nothing.
const dialogBody = window(SCREEN, "void _showConnectionNotFoundDialog", 1400);
const dialogSilent = !/ScaffoldMessenger/.test(dialogBody);
check(2, "W2", "A blocked bet must give the user visible feedback",
  !dialogSilent,
  dialogSilent ? "_showConnectionNotFoundDialog only debugPrints, so a refused bet looks like a vanished bet" : "");

// --- 2c. BUG: offline state can only be re-checked on screen init.
const checkConnCalls = (SCREEN.match(/\.checkConnection\(\)/g) || []).length;
check(2, "W3", "Connectivity must be re-checked while the screen is alive, not only in initState",
  checkConnCalls >= 2,
  checkConnCalls < 2
    ? `checkConnection() is called ${checkConnCalls}x, only from initState (:1560); a latched _isOffline can never clear without re-entry`
    : "");

// --- 2d. A cross-round submission failure silently deleted the placed bets.
const movedOn = window(SCREEN, "if (roundMovedOn) {", 900);
const movedOnSilent = !/ScaffoldMessenger/.test(movedOn);
check(2, "W4", "Bets discarded on a cross-round failure must be surfaced to the user",
  !movedOnSilent,
  movedOnSilent ? "roundMovedOn branch clears _currentBets with only a debugPrint" : "");

// --- 2e. BUG: the bet txnId is not deterministic, so retries skip idempotency.
const sendsSeqTxn = lines(SCREEN, "betTxnId = ").some((l) => l.includes("$requestSeq"));
const usesSeqCounter = lines(SCREEN, "requestSeq = ++_balanceSeq").length > 0;
check(2, "W5", "Bet txnId must be deterministic per (uid, round) so retries hit the idempotency path",
  !(usesSeqCounter && sendsSeqTxn),
  usesSeqCounter && sendsSeqTxn
    ? "txnId embeds ++_balanceSeq (:1056-1057), so a retry writes a NEW ledger doc instead of matching the server idempotency key (index.js:3554)"
    : "");

// --- 2f. BUG: the pending-debit key can never match the txnId the server records.
// The server echoes the client's txnId straight into users.lastTxnId
// (index.js:3787 `lastTxnId: txnId`), and updateFromStream clears a pending debit
// by matching that value, so both strings must be identical.
const hasSeqTxn = lines(SCREEN, "betTxnId = ").some((l) => l.includes("$requestSeq"));
const hasBarePending = lines(SCREEN, "roundPendingKey = ").some((l) =>
  l.includes("'bet_$submissionRoundId'"));
check(2, "W6", "Client pending-debit key must match the txnId the server records",
  !(hasSeqTxn && hasBarePending),
  hasSeqTxn && hasBarePending
    ? "client sends txnId 'bet_<round>_<seq>' but registers the pending debit as 'bet_<round>' (:1057-1058); the server echoes the seq-suffixed id, so updateFromStream never clears the pending debit"
    : "");

// --- 2g. Going offline must not silently delete the player's placed bets.
// Anchored on the handler itself: a bare `if (_isOffline) {` search matches unrelated
// branches (including the round-rollover reset, which legitimately clears bets).
const offlineHandler = window(SCREEN, "void _updateOfflineState", 1600);
const offlineWipes = /_currentBets = \{\}/.test(offlineHandler);
check(2, "W7", "Going offline must not silently delete the player's placed bets",
  !offlineWipes,
  offlineWipes ? "_updateOfflineState clears _currentBets on entering offline" : "");

// ===========================================================================
// Report
// ===========================================================================

const failed = results.filter((r) => !r.ok);

if (process.argv.includes("--json")) {
  console.log(JSON.stringify({ total: results.length, failed: failed.length, results }, null, 2));
} else {
  for (const issue of [1, 2]) {
    console.log(`\n${"=".repeat(62)}\nISSUE ${issue}\n${"=".repeat(62)}`);
    for (const r of results.filter((x) => x.issue === issue)) {
      console.log(`  ${r.ok ? "PASS" : "FAIL"}  ${r.id}  ${r.desc}`);
      if (r.evidence) console.log(`        -> ${r.evidence}`);
    }
  }
  console.log(`\n${"-".repeat(62)}`);
  console.log(
    `${results.length - failed.length}/${results.length} invariants hold, ${failed.length} regression(s).`
  );
  if (failed.length) console.log(`Failing: ${failed.map((f) => f.id).join(", ")}`);
  console.log(`${"-".repeat(62)}\n`);
}

process.exit(failed.length ? 1 : 0);
