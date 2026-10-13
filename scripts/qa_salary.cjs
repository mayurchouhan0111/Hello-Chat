const { spawnSync } = require('child_process');
const q = (...a) => {
  const r = spawnSync(process.execPath, ['scripts/fsqa.cjs', ...a], { encoding: 'utf8', maxBuffer: 1 << 28 });
  try { return JSON.parse(r.stdout); } catch { return null; }
};
const status = q('list', 'salaryStatus', '300') || [];
const payouts = q('list', 'salaryPayouts', '1000') || [];
console.log(`salaryStatus=${status.length}  salaryPayouts=${payouts.length}`);

const hostLedger = {};
let dupLevel = 0;
const seen = {};
payouts.filter(p => p.type === 'host').forEach(p => {
  hostLedger[p.uid] = (hostLedger[p.uid] || 0) + (p.amount || 0);
  const k = p.uid + '#' + p.level;
  if (seen[k]) dupLevel++; seen[k] = 1;
});
console.log('duplicate host level payouts =', dupLevel);

let checked = 0, mism = 0, totalLedger = 0;
status.forEach(d => {
  const id = d.docId || d.id;
  const wallet = (d.pendingPayoutUSD || 0) + (d.paidPayoutUSD || 0);
  if (wallet === 0 && !hostLedger[id]) return;
  checked++;
  const ledger = hostLedger[id] || 0;
  totalLedger += ledger;
  if (Math.abs(ledger - wallet) > 0.011) {
    mism++;
    if (mism <= 8) console.log(`  MISMATCH ${id.slice(0, 14)} ledger=${ledger} wallet=${wallet}`);
  }
});
console.log(`hosts cross-checked=${checked}  mismatches=${mism}  ledgerTotal=${totalLedger}`);

// pending vs paid consistency
let pp = 0;
status.forEach(d => {
  const id = d.docId || d.id;
  const pend = d.pendingPayoutUSD || 0;
  const expectPending = payouts.filter(p => p.type === 'host' && p.uid === id && p.status === 'pending')
    .reduce((s, p) => s + (p.amount || 0), 0);
  if (Math.abs(pend - expectPending) > 0.011) { pp++; if (pp <= 5) console.log(`  PENDING MISMATCH ${id.slice(0, 14)} wallet=${pend} ledgerPending=${expectPending}`); }
});
console.log('pendingUSD mismatches =', pp);