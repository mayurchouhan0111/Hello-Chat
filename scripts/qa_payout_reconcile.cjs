// Reconciles salaryStatus.pendingPayoutUSD against the surviving ledger.
// pendingPayoutUSD is fully derivable = sum of pending host payouts for that uid.
// paidPayoutUSD is NOT derivable from this collection, so it is left untouched.
const { execFileSync } = require('child_process');
const payouts = JSON.parse(execFileSync(process.execPath, ['scripts/fsqa.cjs', 'list', 'salaryPayouts', '1000'], { encoding: 'utf8', maxBuffer: 1 << 28 }));
console.log('surviving payouts =', payouts.length);

const groups = {};
payouts.filter(p => p.type === 'host' && p.status === 'pending').forEach(p => {
  groups[p.uid] = (groups[p.uid] || 0) + (p.amount || 0);
});
const uids = Object.keys(groups);
console.log('uids with pending host payouts =', uids.length);

let fixed = 0, already = 0, missing = [];
for (const uid of uids) {
  const expected = groups[uid];
  let status;
  try { status = JSON.parse(execFileSync(process.execPath, ['scripts/fsqa.cjs', 'get', `salaryStatus/${uid}`], { encoding: 'utf8', maxBuffer: 1 << 26 })); }
  catch { missing.push(uid); continue; }
  if (!status || status.__missing) { missing.push(uid); continue; }
  const cur = status.pendingPayoutUSD || 0;
  if (cur === expected) { already++; continue; }
  console.log(`  ${uid}  pendingPayoutUSD ${cur} -> ${expected}  (drift ${expected - cur})`);
  execFileSync(process.execPath, ['scripts/fsqa.cjs', 'set', `salaryStatus/${uid}`, JSON.stringify({ pendingPayoutUSD: expected })], { encoding: 'utf8' });
  fixed++;
}
console.log(`\nreconciled = ${fixed} | already correct = ${already} | no salaryStatus doc = ${missing.length}`);
if (missing.length) console.log('missing uids:', missing.join(','));