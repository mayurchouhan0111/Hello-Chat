const fs = require('fs');
const path = process.argv[2];
const lines = fs.readFileSync(path, 'utf8').split(/\r?\n/);

const FIELDS = ['source','oldBalance','newBalance','delta','direction','transactionId','roundId','walletSeq','eventName'];
const recs = [];
let cur = null;

for (const L of lines) {
  if (/\[WALLET_MUTATION\]/.test(L)) {
    if (cur) recs.push(cur);
    const ts = (L.match(/^(\d\d-\d\d \d\d:\d\d:\d\d\.\d+)/) || [])[1] || '?';
    cur = { ts };
    continue;
  }
  if (!cur) continue;
  for (const f of FIELDS) {
    const re = new RegExp(f + ': (.*)$');
    const m = L.match(re);
    if (m) { cur[f] = m[1].trim(); break; }
  }
}
if (cur) recs.push(cur);

console.log('total wallet mutations:', recs.length);
const bySource = {};
recs.forEach(r => { const k = r.source || '?'; bySource[k] = (bySource[k] || 0) + 1; });
console.log('\n--- sources ---');
Object.entries(bySource).sort((a, b) => b[1] - a[1]).forEach(([k, v]) => console.log(String(v).padStart(4), k));

console.log('\n--- nonzero-delta mutations only (the ones the user sees) ---');
recs.filter(r => r.delta && r.delta !== '0' && r.delta !== 'undefined')
     .forEach(r => console.log(r.ts, '|', String(r.oldBalance) + '->' + String(r.newBalance), '| d=' + r.delta, '|', r.source, '|', r.transactionId, '|', r.eventName, '| round', r.roundId));

console.log('\n--- every client_optimistic_bet + phase transitions ---');
recs.filter(r => r.source === 'client_optimistic_bet' || (r.source === 'phase_transition'))
     .forEach(r => console.log(r.ts, '| d=' + r.delta, '|', String(r.source).padEnd(20), '|', r.transactionId, '|', r.eventName, '| old=' + r.oldBalance, 'new=' + r.newBalance));