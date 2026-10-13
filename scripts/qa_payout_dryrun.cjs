const { spawnSync } = require('child_process');
const fs = require('fs');
const q = (...a) => {
  const r = spawnSync(process.execPath, ['scripts/fsqa.cjs', ...a], { encoding: 'utf8', maxBuffer: 1 << 28 });
  try { return JSON.parse(r.stdout); } catch { return null; }
};
const payouts = q('list', 'salaryPayouts', '1000') || [];
console.log('total payout docs =', payouts.length);

const st = {}; payouts.forEach(p => { st[p.status || '(none)'] = (st[p.status || '(none)'] || 0) + 1; });
console.log('status distribution =', JSON.stringify(st));
const ty = {}; payouts.forEach(p => { ty[p.type || '(none)'] = (ty[p.type || '(none)'] || 0) + 1; });
console.log('type distribution  =', JSON.stringify(ty));

// Group by the STRICT identity a race-duplicate would share.
const groups = {};
payouts.forEach(p => {
  const k = [p.uid, p.type, p.level, p.amount, p.scheduledDate].join('|');
  (groups[k] = groups[k] || []).push(p);
});
const dupGroups = Object.entries(groups).filter(([, v]) => v.length > 1);
const removable = dupGroups.reduce((s, [, v]) => s + (v.length - 1), 0);
console.log('\nSTRICT duplicate groups (uid|type|level|amount|scheduledDate) =', dupGroups.length);
console.log('docs that would be REMOVED (keep 1 per group) =', removable);

let touchPaid = 0, removablePending = 0, mixedStatus = 0;
dupGroups.forEach(([, v]) => {
  const hasPaid = v.some(p => p.status === 'paid');
  if (hasPaid) { touchPaid++; return; }
  if (v.some(p => p.status !== 'pending')) mixedStatus++;
  removablePending += (v.length - 1);
});
console.log('groups containing a PAID doc -> EXCLUDE =', touchPaid);
console.log('groups with mixed status -> EXCLUDE =', mixedStatus);
console.log('SAFE removable (all-pending dup groups) =', removablePending);

// Same uid+level but DIFFERENT amount/schedule => different slab era, NOT a race dup.
const lvl = {};
payouts.filter(p => p.type === 'host').forEach(p => { (lvl[p.uid + '#' + p.level] = lvl[p.uid + '#' + p.level] || []).push(p); });
const crossEra = Object.entries(lvl).filter(([, v]) => {
  const sig = new Set(v.map(p => p.amount + '@' + p.scheduledDate));
  return sig.size > 1;
});
console.log('\n(uid,level) pairs spanning DIFFERENT amount/date =', crossEra.length, '-> these are slab-config changes, NOT duplicates');

const est = dupGroups.filter(([, v]) => v.every(p => p.status === 'pending'))
  .reduce((s, [, v]) => s + (v.length - 1) * (v[0].amount || 0), 0);
console.log('\nTotal $ value of safe removals = $' + est.toLocaleString());
fs.writeFileSync('qa_payout_dupes.json', JSON.stringify(dupGroups.map(([k, v]) => ({ k, ids: v.map(p => p.id) })), null, 1));
console.log('wrote qa_payout_dupes.json');