const { spawnSync } = require('child_process');
const q = (...a) => {
  const r = spawnSync(process.execPath, ['scripts/fsqa.cjs', ...a], { encoding: 'utf8', maxBuffer: 1 << 28 });
  try { return JSON.parse(r.stdout); } catch { return null; }
};
const payouts = q('list', 'salaryPayouts', '1000') || [];
const g = {};
payouts.filter(p => p.type === 'host').forEach(p => { (g[p.uid + '#' + p.level] = g[p.uid + '#' + p.level] || []).push(p); });
const dups = Object.entries(g).filter(([, v]) => v.length > 1);
console.log('duplicate (uid,level) groups =', dups.length);
dups.slice(0, 4).forEach(([k, v]) => {
  console.log('--- ' + k + '  x' + v.length);
  v.forEach(p => console.log(`    amount=${p.amount} status=${p.status} created=${p.createdAt} sched=${p.scheduledDate}`));
});
// does the host's completedLevels contain that level?
const first = dups[0] && dups[0][1][0];
if (first) {
  const st = q('get', 'salaryStatus/' + first.uid);
  console.log('host', first.uid.slice(0, 14), 'completedLevels=', JSON.stringify(st && st.completedLevels), 'currentLevel=', st && st.currentLevel);
}
const amts = dups.slice(0, 6).map(([, v]) => v.map(p => p.amount).join('+'));
console.log('sample amount groups:', amts.join('  '));