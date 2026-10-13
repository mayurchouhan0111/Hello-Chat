const { spawnSync } = require('child_process');
const UID = 'VJ1GwGfAwafIhCuHDaRTqBbdhYj2';
function fsqa(...a) {
  const r = spawnSync(process.execPath, ['scripts/fsqa.cjs', ...a], { encoding: 'utf8', maxBuffer: 1 << 28 });
  if (r.status !== 0) return null;
  try { return JSON.parse(r.stdout); } catch { return null; }
}
const SALAD = ['tomato', 'cabbage', 'corn', 'carrot'];
const PIZZA = ['hotdog', 'skewer', 'kebab', 'chicken', 'steak'];
function normalize(b) { const o = {}; for (const [k, v] of Object.entries(b || {})) { const n = Number(v) || 0; if (n > 0) o[String(k).toLowerCase()] = n; } return o; }
function payout(bets, r) {
  const w = normalize(bets);
  const name = String((r && r.name) || '').trim().toLowerCase();
  const mult = Number(r && r.multiplier) || 0;
  const type = String((r && (r.type || r.category)) || '').toLowerCase();
  let p = 0;
  if (type === 'salad' || type === 'pizza') {
    const items = type === 'salad' ? SALAD : PIZZA, m = type === 'salad' ? 5 : 45;
    for (const it of items) p += Math.floor((w[it] || 0) * m);
    return p + Math.floor((w[type] || 0) * m);
  }
  p += Math.floor((w[name] || 0) * mult);
  if (SALAD.includes(name)) p += Math.floor((w['salad'] || 0) * 5);
  else if (PIZZA.includes(name)) p += Math.floor((w['pizza'] || 0) * 45);
  return p;
}

const rounds = fsqa('list', 'game_rounds', '1000') || [];
const rmap = {};
rounds.forEach(r => { rmap[String(r.id)] = r; });

console.log('=== game_rounds docs WITHOUT a usable outcome ===');
rounds.filter(r => !(r.outcome && r.outcome.name)).forEach(r => {
  console.log(` round ${r.id} status=${r.status} outcome=${JSON.stringify(r.outcome)}`);
  console.log(`   started ${r.roundStartedAt} settledAt=${r.settledAt}`);
});

const hist = fsqa('sublist', `users/${UID}`, 'game_history', '2000') || [];
const modern = hist.filter(h => h.roundId && h.bets);
const inWindow = modern.filter(h => rmap[String(h.roundId)]);
console.log(`\n=== user history: ${modern.length} modern records, ${inWindow.length} inside outcome retention ===`);
console.log(`    ${modern.length - inWindow.length} records have NO canonical outcome to verify against`);

const problems = [];
for (const h of inWindow) {
  const rid = String(h.roundId), r = rmap[rid], oc = r.outcome || {};
  const tag = `round ${rid} S/N${h.serialNumber}`;
  const bets = normalize(h.bets);
  const sum = Object.values(bets).reduce((a, b) => a + b, 0);
  if (sum !== Number(h.totalBet)) problems.push(`${tag}: totalBet ${h.totalBet} != sum(bets) ${sum}`);

  // roundId must equal floor(epochMs/40000) of the round window
  const startMs = new Date(r.roundStartedAt).getTime();
  const derived = Math.floor(startMs / 40000);
  if (String(derived) !== rid) problems.push(`${tag}: roundId ${rid} != floor(roundStartedAt/40000) = ${derived}`);

  // betting window must be 30s inside a 40s round
  const betEnd = Number(r.bettingEndsAt), spinStart = Number(r.spinStartsAt);
  if (betEnd && startMs && betEnd - startMs !== 30000) problems.push(`${tag}: betting window ${(betEnd - startMs) / 1000}s != 30s`);
  if (spinStart && startMs && spinStart !== betEnd) problems.push(`${tag}: spinStartsAt != bettingEndsAt`);

  if (Number(h.multiplier) !== Number(oc.multiplier)) problems.push(`${tag}: multiplier ${h.multiplier} != ${oc.multiplier}`);
  if (String(h.label) !== String(oc.label)) problems.push(`${tag}: label ${h.label} != ${oc.label}`);
  if (String(h.emoji) !== String(oc.emoji)) problems.push(`${tag}: emoji ${h.emoji} != ${oc.emoji}`);

  const exp = payout(h.bets, oc);
  if (exp !== Number(h.prize)) problems.push(`${tag}: prize ${h.prize} != formula ${exp} (winner ${oc.name} ${oc.multiplier}x bets ${JSON.stringify(h.bets)})`);

  if (r.status !== 'ROUND_SETTLED') problems.push(`${tag}: round status ${r.status}`);

  // settlement timing: outcomeCommittedAt must be at/after spinStartsAt
  if (r.outcomeCommittedAt && spinStart && Number(r.outcomeCommittedAt) < Number(spinStart))
    problems.push(`${tag}: outcomeCommittedAt BEFORE spin start (committed too early)`);
}

console.log(`\n=== ${problems.length} PROBLEM(S) in verifiable records ===`);
problems.forEach(p => console.log(' * ' + p));
if (!problems.length) console.log(' (none - every verifiable round matches exactly)');