const { spawnSync } = require('child_process');
const q = (...a) => {
  const r = spawnSync(process.execPath, ['scripts/fsqa.cjs', ...a], { encoding: 'utf8', maxBuffer: 1 << 28 });
  try { return JSON.parse(r.stdout); } catch { return null; }
};

console.log('===== ITEM 3: RANKINGS =====');
const lr = q('list', 'leaderboards', '50') || [];
console.log('leaderboard boards =', lr.length);
lr.slice(0, 8).forEach(b => console.log('  ', b.id, '| keys:', Object.keys(b).slice(0, 6).join(',')));

console.log('\n===== ITEM 4: GAMES =====');
const rounds = q('list', 'game_rounds', '300') || [];
const settled = rounds.filter(r => r.status === 'SETTLED' || r.status === 'settled');
console.log('game_rounds fetched =', rounds.length, '| settled =', settled.length);
let payoutBad = 0, seqBad = 0;
settled.slice(0, 120).forEach(r => {
  const bets = r.bets || {};
  const totalBet = Object.values(bets).reduce((s, v) => s + (Number(v) || 0), 0);
  if (r.totalBet !== undefined && totalBet !== r.totalBet) { if (payoutBad < 4) console.log('  BET SUM MISMATCH', r.roundId, 'stored', r.totalBet, 'calc', totalBet); payoutBad++; }
  if (r.settledAt && r.bettingEndsAt && new Date(r.settledAt) < new Date(r.bettingEndsAt)) { if (seqBad < 4) console.log('  SETTLE BEFORE BET END', r.roundId); seqBad++; }
});
console.log('bet-sum mismatches =', payoutBad, '| settle-before-bet-end =', seqBad);

console.log('\n===== ITEM 9: GIFT EVENTS =====');
const gifts = q('list', 'gift_events', '200') || [];
console.log('gift_events =', gifts.length);
const dupGift = {};
gifts.forEach(g => { const k = g.eventId || g.id; dupGift[k] = (dupGift[k] || 0) + 1; });
const gd = Object.entries(dupGift).filter(([, v]) => v > 1);
console.log('duplicate eventIds =', gd.length);
let noSender = 0, negCost = 0;
gifts.forEach(g => { if (!g.senderUid && !g.senderId) noSender++; if ((g.cost || g.totalCost || 0) < 0) negCost++; });
console.log('gifts missing sender =', noSender, '| negative cost =', negCost);
gifts.slice(0, 3).forEach(g => console.log('  keys:', Object.keys(g).slice(0, 10).join(',')));

console.log('\n===== ITEM 7: GROUP CHAT / MESSAGES =====');
const chats = q('list', 'chats', '100') || [];
console.log('chats =', chats.length);
let chatBad = 0;
chats.slice(0, 40).forEach(c => {
  const m = Number(c.lastMessageCount || c.messageCount || 0);
  if (m < 0) chatBad++;
});
console.log('negative message counts =', chatBad);