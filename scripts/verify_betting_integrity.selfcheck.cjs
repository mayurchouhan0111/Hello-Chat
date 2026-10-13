#!/usr/bin/env node
/**
 * Self-check for verify_betting_integrity.cjs
 * ==========================================
 * A checker that only ever passes is decoration. This proves ours discriminates:
 * it reverts all 17 fixes in a throwaway copy of the sources, re-runs the checker,
 * and requires it to report 17/17 REGRESSIONS. Then it re-runs against the real
 * sources and requires 17/17 PASSES. Anything less and this exits nonzero.
 *
 * The real sources are never modified - the reverted copy lives in a temp dir that
 * is deleted on exit. This also guards against the checker silently drifting into
 * "always green" after a refactor (an anchor that no longer matches reports 0/17 here).
 *
 * Usage:  node scripts/verify_betting_integrity.selfcheck.cjs
 * Exit:   0 = checker discriminates, 1 = it is tautological or drifting.
 */

const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const ROOT = path.resolve(__dirname, "..");
const CHECKER = "verify_betting_integrity.cjs";
const TMP = fs.mkdtempSync(path.join(os.tmpdir(), "betcheck-"));
const cleanup = () => fs.rmSync(TMP, { recursive: true, force: true });
process.on("exit", cleanup);

const FILES = {
  screen: "lib/features/games/presentation/screens/spin_wheel_screen.dart",
  server: "functions/index.js",
  svc: "lib/core/services/game_service.dart",
};

for (const rel of Object.values(FILES)) {
  const dst = path.join(TMP, rel);
  fs.mkdirSync(path.dirname(dst), { recursive: true });
  fs.copyFileSync(path.join(ROOT, rel), dst);
}
fs.mkdirSync(path.join(TMP, "scripts"), { recursive: true });
fs.copyFileSync(path.join(ROOT, "scripts", CHECKER), path.join(TMP, "scripts", CHECKER));

const screenPath = path.join(TMP, FILES.screen);
let s = fs.readFileSync(screenPath, "utf8");

/** Replace `from` with `to` only inside the window starting at `anchor`. */
function revertInWindow(src, anchor, len, from, to) {
  const i = src.indexOf(anchor);
  if (i === -1) return null;
  const win = src.slice(i, i + len);
  if (!win.includes(from)) return null;
  return src.slice(0, i) + win.split(from).join(to) + src.slice(i + len);
}

// One mutation per surviving check. Each removes exactly one shipped guard.
const simple = [
  ["C1", "if (rSettled) {", "if (neverSettled) {"],
  ["C3", "? existing['bets'] as Map", "? sessionItem['bets'] as Map"],
  ["C4", "final finalPrize = isRemoteAuthoritative", "int finalPrize = 0;\n        finalPrize = calculated;\n        final finalPrize2 = isRemoteAuthoritative"],
  ["W1", "if (prize > 0 && _isBettingPhase) {", "if (prize > 0 && false) {"],
  ["W3", "NetworkConnectivityService().checkConnection().then((hasNetwork) {", "Future<bool>.value(false).then((hasNetwork) {"],
  ["W5", "final betTxnId = 'bet_$submissionRoundId';", "final betTxnId = 'bet_${submissionRoundId}_$requestSeq';"],
  ["W6", "final roundPendingKey = betTxnId;", "final roundPendingKey = 'bet_$submissionRoundId';"],
  ["W7", "        // Keep the staged wagers on screen.", "        _currentBets = {}; _betClickCounts = {}; _confirmedBets = {};"],
];

const windowed = [
  ["C5", "final rowKey = ", 400, "key: ValueKey(rowKey),", "key: null,"],
  ["W2", "void _showConnectionNotFoundDialog", 1400, "ScaffoldMessenger.of(context).showSnackBar(", "debugPrint('silenced',"],
  ["W4", "if (roundMovedOn) {", 900, "ScaffoldMessenger.of(context).showSnackBar(", "debugPrint('silenced',"],
];

const serverReverts = [
  ["S1", 'collection("game_history").doc(`spin_${', 'collection("game_history").doc(`live_${'],
  ["S2", "if (logData.settled === true) {", "if (logData.settled === false) {"],
  ["S3", "if (privateDoc.exists) {", "if (!privateDoc.exists) {"],
  ["S4", "winningFood: roundResult.name,", "winningFood: null,"],
  ["S5", "roundHistoryAlreadySettled", "roundHistoryWasSettled"],
];

const missing = [];
for (const [id, from, to] of simple) {
  if (!s.includes(from)) { missing.push(id); continue; }
  s = s.split(from).join(to);
}
for (const [id, anchor, len, from, to] of windowed) {
  const next = revertInWindow(s, anchor, len, from, to);
  if (next === null) { missing.push(id); continue; }
  s = next;
}
fs.writeFileSync(screenPath, s);

const serverPath = path.join(TMP, FILES.server);
let sv = fs.readFileSync(serverPath, "utf8");
for (const [id, from, to] of serverReverts) {
  if (!sv.includes(from)) { missing.push(id); continue; }
  sv = sv.split(from).join(to);
}
fs.writeFileSync(serverPath, sv);

const svcPath = path.join(TMP, FILES.svc);
let svc = fs.readFileSync(svcPath, "utf8");
if (!svc.includes("collection('game_history')")) missing.push("S6");
else fs.writeFileSync(svcPath, svc.split("collection('game_history')").join("collection('game_history_cache')"));

if (missing.length) {
  console.log("FAIL - checker drift, these mutations could not be applied: " + missing.join(", "));
  process.exit(1);
}

// The checker prints "<passed>/<total> invariants hold, <n> regression(s)", so m[1] is the
// PASSED count and m[2] is the TOTAL - not a failure count. Parse both plus the exit code.
function run(cwd) {
  const r = spawnSync(process.execPath, [path.join(cwd, "scripts", CHECKER)], {
    cwd,
    encoding: "utf8",
  });
  const out = String(r.stdout || "");
  const m = out.match(/(\d+)\/(\d+) invariants hold/);
  return { passed: Number(m ? m[1] : -1), total: Number(m ? m[2] : -1), out, code: r.status };
}

const mutated = run(TMP);
const real = run(ROOT);
const total = simple.length + windowed.length + serverReverts.length + 1;

console.log("mutated (all " + total + " fixes reverted): " + (mutated.total - mutated.passed) + "/" + total + " flagged as regressions (exit " + mutated.code + ")");
console.log("real sources:                       " + real.passed + "/" + total + " invariants hold (exit " + real.code + ")");

if (mutated.passed !== 0 || real.passed !== total || mutated.code !== 1 || real.code !== 0) {
  console.log("\nFAIL - checker is tautological or out of sync with the sources.");
  console.log(mutated.out || real.out || "");
  process.exit(1);
}
console.log("\nOK - every check is falsifiable and all " + total + " hold on the real sources.");
