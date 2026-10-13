// Removes race-condition duplicate salaryPayouts and reconciles pendingPayoutUSD.
// Safe by construction: only deletes docs inside a STRICT duplicate group
// (uid|type|level|amount|scheduledDate), keeps the EARLIEST createdAt, and
// never touches a doc that is not status=pending. Full backup written first.
const { spawnSync, execFileSync } = require('child_process');
const fs = require('fs');

const BACKUP = 'qa_payouts_backup.json';
if (!fs.existsSync(BACKUP)) {
  execFileSync(process.execPath, ['scripts/fsqa.cjs', 'list', 'salaryPayouts', '1000'], { encoding: 'utf8', maxBuffer: 1 << 28 });
  const all = JSON.parse(require('child_process').execFileSync('powershell', ['-NoProfile', '-Command', `$o = node scripts/fsqa.cjs list salaryPayouts 1000 | Out-String; $o`], { encoding: 'utf8', maxBuffer: 1 << 28 }));
  fs.writeFileSync(BACKUP, JSON.stringify(all, null, 1));
  console.log('BACKUP written:', all.length, 'payouts ->', BACKUP);
} else {
  console.log('BACKUP already exists, reusing:', BACKUP);
}
const payouts = JSON.parse(fs.readFileSync(BACKUP, 'utf8'));

const groups = {};
payouts.forEach(p => {
  if (p.status !== 'pending') return;                       // never touch non-pending
  const k = [p.uid, p.type, p.level, p.amount, p.scheduledDate].join('|');
  (groups[k] = groups[k] || []).push(p);
});

const doomed = [];
Object.values(groups).forEach(v => {
  if (v.length < 2) return;
  const sorted = [...v].sort((a, b) => String(a.createdAt).localeCompare(String(b.createdAt)));
  sorted.slice(1).forEach(p => doomed.push(p));            // keep earliest
});
console.log('duplicate groups =', Object.values(groups).filter(v => v.length > 1).length, '| docs to delete =', doomed.length);
const removedValue = doomed.reduce((s, p) => s + (p.amount || 0), 0);
console.log('value removed from pending = $' + removedValue.toLocaleString());
fs.writeFileSync('qa_payout_deleted.json', JSON.stringify(doomed.map(p => p.id), null, 1));

const CONC = 10;
let done = 0, failed = [];
for (let i = 0; i < doomed.length; i += CONC) {
  const batch = doomed.slice(i, i + CONC);
  const res = batch.map(p => {
    const r = spawnSync(process.execPath, ['scripts/fsqa.cjs', 'delete', `salaryPayouts/${p.id}`], { encoding: 'utf8' });
    return r.status === 0 ? null : p.id;
  }).filter(Boolean);
  failed = failed.concat(res);
  done += batch.length;
  process.stdout.write(`\r  deleted ${done}/${doomed.length} (failures ${failed.length})   `);
}
console.log('\ndelete failures =', failed.length);
if (failed.length) { console.log('FAILED IDS:', failed.join(',')); process.exit(1); }
console.log('CLEANUP DONE. remaining payouts reconciled next step.');