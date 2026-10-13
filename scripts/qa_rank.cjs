const { spawnSync } = require('child_process');
const q = (...a) => {
  const r = spawnSync(process.execPath, ['scripts/fsqa.cjs', ...a], { encoding: 'utf8', maxBuffer: 1 << 28 });
  try { return JSON.parse(r.stdout); } catch { return null; }
};
for (const c of ['gift_leaderboard', 'sender_rankings', 'relationship_rankings', 'monthly_leaderboard_history']) {
  const docs = q('list', c, '100');
  const n = Array.isArray(docs) ? docs.length : 0;
  console.log(`\n=== ${c}: ${n} docs`);
  if (n) {
    console.log('   keys:', Object.keys(docs[0]).slice(0, 12).join(','));
    let nan = 0, neg = 0, noRank = 0;
    docs.forEach(d => {
      for (const [k, v] of Object.entries(d)) {
        if (typeof v === 'number') {
          if (!isFinite(v)) nan++;
          if (v < 0 && /amount|total|diamond|score|points|spent|contribut/i.test(k)) neg++;
        }
      }
      if (d.rank === undefined && d.position === undefined) noRank++;
    });
    console.log(`   NaN=${nan} negative-money=${neg} missingRank=${noRank}`);
    console.log('   sample:', JSON.stringify(docs[0]).slice(0, 220));
  }
}