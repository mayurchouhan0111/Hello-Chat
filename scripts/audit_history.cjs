// Audit: every game_history record must be exactly reproducible from game_rounds.
// Mirrors computeSpinWheelPayout() in functions/index.js (line 5105) verbatim.
const { execFileSync } = require('child_process');

const UID = process.argv[2] || 'VJ1GwGfAwafIhCuHDaRTqBbdhYj2';
const FSQA = 'scripts/fsqa.cjs';

function fsqa(...args) {
  const r = require('child_process').spawnSync(process.execPath, [FSQA, ...args], {
    encoding: 'utf8', maxBuffer: 64 * 1024 * 1024,
  });
  if (r.status !== 0) return null;
  try { return JSON.parse(r.stdout); } catch { return null; }
}

const SALAD = ['tomato', 'cabbage', 'corn', 'carrot'];
const PIZZA = ['hotdog', 'skewer', 'kebab', 'chicken', 'steak'];

function normalize(bets) {
  const o = {};
  for (const [k, v] of Object.entries(bets || {})) {
    const n = Number(v) || 0;
    if (n > 0) o[String(k).toLowerCase()] = n;
  }
  return o;
}

// exact port of the server payout
function payout(bets, r) {
  const w = normalize(bets);
  const name = String((r && r.name) || '').trim().toLowerCase();
  const mult = Number(r && r.multiplier) || 0;
  const type = String((r && (r.type || r.category)) || '').toLowerCase();
  let prize = 0;
  if (type === 'salad' || type === 'pizza') {
    const items = type === 'salad' ? SALAD : PIZZA;
    const m = type === 'salad' ? 5 : 45;
    for (const it of items) prize += Math.floor((w[it] || 0) * m);
    prize += Math.floor((w[type] || 0) * m);
    return prize;
  }
  prize += Math.floor((w[name] || 0) * mult);
  if (SALAD.includes(name)) prize += Math.floor((w['salad'] || 0) * 5);
  else if (PIZZA.includes(name)) prize += Math.floor((w['pizza'] || 0) * 45);
  return prize;
}

const history = fsqa('sublist', `users/${UID}`, 'game_history', '500');
console.log(`history records: ${history.length}`);

// group by schema shape
const modern = [], legacy = [];
for (const h of history) (h.roundId && h.bets ? modern : legacy).push(h);
console.log(`  modern schema (roundId+bets): ${modern.length}`);
console.log(`  legacy/other schema: ${legacy.length}`);

// fetch canonical rounds (dedup)
const roundIds = [...new Set(modern.map(h => String(h.roundId)))];
const rounds = {};
for (const rid of roundIds) {
  try { rounds[rid] = fsqa('get', `game_rounds/${rid}`); }
  catch (e) { rounds[rid] = null; }
}

const problems = [];
const seenSN = new Map();
const seenRound = new Map();
let withRound = 0, noRound = 0;

for (const h of modern) {
  const rid = String(h.roundId);
  const r = rounds[rid];
  const tag = `round ${rid} (S/N ${h.serialNumber ?? '-'})`;
  const bets = normalize(h.bets);

  // 1. totalBet == sum(bets)
  const sum = Object.values(bets).reduce((a, b) => a + b, 0);
  if (sum !== Number(h.totalBet)) {
    problems.push(`${tag}: totalBet=${h.totalBet} but sum(bets)=${sum}`);
  }

  // 5. balance math (always checkable)
  if (h.balanceBefore != null && h.balanceAfter != null) {
    const bb = Number(h.balanceBefore), ba = Number(h.balanceAfter);
    const tb = Number(h.totalBet), pz = Number(h.prize);
    if (bb - tb + pz !== ba) {
      problems.push(`${tag}: balance math broken: ${bb} - ${tb} + ${pz} = ${bb - tb + pz}, recorded balanceAfter=${ba}`);
    }
  }

  // 8. duplicate detection
  if (h.serialNumber != null) {
    if (seenSN.has(h.serialNumber)) problems.push(`${tag}: DUPLICATE serialNumber (also ${seenSN.get(h.serialNumber)})`);
    else seenSN.set(h.serialNumber, rid);
  }
  if (seenRound.has(rid)) problems.push(`${tag}: DUPLICATE roundId in history (also ${seenRound.get(rid)})`);
  else seenRound.set(rid, h.serialNumber);

  if (!r) { noRound++; continue; }
  withRound++;
  const oc = r.outcome || {};

  // 3. multiplier / label / emoji must equal canonical outcome
  if (Number(h.multiplier) !== Number(oc.multiplier))
    problems.push(`${tag}: multiplier ${h.multiplier} != round ${oc.multiplier}`);
  if (String(h.label) !== String(oc.label))
    problems.push(`${tag}: label "${h.label}" != round "${oc.label}"`);
  if (String(h.emoji) !== String(oc.emoji))
    problems.push(`${tag}: emoji "${h.emoji}" != round "${oc.emoji}"`);
  if (oc.roundId && String(oc.roundId) !== rid)
    problems.push(`${tag}: outcome.roundId ${oc.roundId} != doc id ${rid}`);

  // 4. prize must equal the exact server formula
  const expect = payout(h.bets, oc);
  if (expect !== Number(h.prize))
    problems.push(`${tag}: prize=${h.prize} but formula gives ${expect} (winner ${oc.name} ${oc.multiplier}x, bets ${JSON.stringify(h.bets)})`);

  // 6. resultType vs canonical category
  if (h.resultType && oc.category && String(h.resultType) !== String(oc.category))
    problems.push(`${tag}: resultType "${h.resultType}" != outcome category "${oc.category}"`);

  // 7. round settled?
  if (r.status && r.status !== 'ROUND_SETTLED')
    problems.push(`${tag}: game_rounds status=${r.status} (not settled)`);
}

console.log(`\nverifiable against canonical game_rounds: ${withRound}`);
console.log(`internal-consistency only (round doc gone): ${noRound}`);

// 9. serialNumber continuity
const sns = [...seenSN.keys()].sort((a, b) => a - b);
if (sns.length) {
  const gaps = [];
  for (let i = 1; i < sns.length; i++) if (sns[i] !== sns[i - 1] + 1) gaps.push(`${sns[i - 1]}->${sns[i]}`);
  console.log(`serialNumber range: ${sns[0]}..${sns[sns.length - 1]} (${sns.length} unique)`);
  if (gaps.length) console.log(`  GAPS in serialNumber sequence: ${gaps.join(', ')}`);
}

// 10. round id ordering vs timestamp
const ordered = [...modern].sort((a, b) => Number(a.roundId) - Number(b.roundId));
let outOfOrder = 0;
for (let i = 1; i < ordered.length; i++) {
  if (new Date(ordered[i].timestamp) < new Date(ordered[i - 1].timestamp)) outOfOrder++;
}
console.log(`roundId ascending vs timestamp ascending mismatches: ${outOfOrder}`);

console.log(`\n=== ${problems.length} PROBLEM(S) ===`);
problems.forEach(p => console.log(' * ' + p));

if (legacy.length) {
  console.log(`\n=== ${legacy.length} record(s) with non-modern schema ===`);
  legacy.forEach(l => console.log(` * id=${l.id} keys=[${Object.keys(l).join(',')}] ts=${l.timestamp}`));
}