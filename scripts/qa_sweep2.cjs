const { spawnSync } = require('child_process');
const q = (...a) => {
  const r = spawnSync(process.execPath, ['scripts/fsqa.cjs', ...a], { encoding: 'utf8', maxBuffer: 1 << 28 });
  try { return JSON.parse(r.stdout); } catch { return null; }
};
const rounds = q('list', 'game_rounds', '300') || [];
const st = {};
rounds.forEach(r => { st[r.status] = (st[r.status] || 0) + 1; });
console.log('game_rounds status distribution =', JSON.stringify(st));
const withOutcome = rounds.filter(r => r.outcome);
console.log('rounds with outcome =', withOutcome.length);
let bad = 0;
withOutcome.slice(0, 100).forEach(r => {
  const bets = r.bets || {};
  const sum = Object.values(bets).reduce((s, v) => s + (Number(v) || 0), 0);
  if (r.totalBet !== undefined && sum !== r.totalBet) { if (bad < 5) console.log('  BET SUM', r.roundId, 'stored', r.totalBet, 'calc', sum); bad++; }
});
console.log('bet-sum mismatches =', bad);
// what top-level collections exist? probe common ranking names
for (const c of ['leaderboard', 'rankings', 'roomRankings', 'charmRankings', 'room_stats', 'rankingCache', 'weeklyRankings', 'roomRanking']) {
  const r = q('list', c, '5');
  if (Array.isArray(r) && r.length) { console.log('FOUND collection', c, 'docs=', r.length, 'keys=', Object.keys(r[0]).slice(0, 8).join(',')); }
}