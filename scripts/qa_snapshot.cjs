#!/usr/bin/env node
/* QA snapshot: dumps the state that the 9 audit areas depend on, so tests can diff before/after.
   usage:
     node scripts/qa_snapshot.cjs <uid> [<roomId>] > before.json
     node scripts/qa_snapshot.cjs <uid> [<roomId>] --cmp before.json
*/
const fs = require('fs');
const os = require('os');
const path = require('path');

const CFG = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
const PROJECT = 'hellochat-e8965';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;

async function tok() {
  const cfg = JSON.parse(fs.readFileSync(CFG, 'utf8'));
  if (Date.now() < (cfg.tokens.expires_at || 0) - 60000 && cfg.tokens.access_token) return cfg.tokens.access_token;
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
      client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
      refresh_token: cfg.tokens.refresh_token,
      grant_type: 'refresh_token',
    }),
  });
  if (!r.ok) throw new Error('refresh failed: ' + r.status + ' ' + (await r.text()));
  const j = await r.json();
  cfg.tokens.access_token = j.access_token;
  cfg.tokens.expires_at = Date.now() + (j.expires_in || 3600) * 1000;
  fs.writeFileSync(CFG, JSON.stringify(cfg, null, 2));
  return j.access_token;
}

function toJs(v) {
  if (!v) return null;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('stringValue' in v) return v.stringValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('nullValue' in v) return null;
  if ('timestampValue' in v) return v.timestampValue;
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(toJs);
  if ('mapValue' in v) return fd(v.mapValue.fields);
  if ('referenceValue' in v) return v.referenceValue;
  return v;
}
function fd(fl) { const o = {}; for (const [k, v] of Object.entries(fl || {})) o[k] = toJs(v); return o; }

async function get(p) {
  const t = await tok();
  const r = await fetch(`${BASE}/${p}`, { headers: { Authorization: `Bearer ${t}` } });
  if (r.status === 404) return null;
  if (!r.ok) throw new Error(`${p} -> ${r.status} ${await r.text()}`);
  const j = await r.json();
  return { id: j.name.split('/').pop(), ...fd(j.fields) };
}
async function list(parent, coll, limit = 50) {
  const t = await tok();
  let url = `${BASE}:runQuery`;
  if (parent) {
    const res = `projects/${PROJECT}/databases/(default)/documents/${parent}`;
    url += `?parent=${encodeURIComponent(res)}`;
  }
  const r = await fetch(url, {
    method: 'POST', headers: { Authorization: `Bearer ${t}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ structuredQuery: { from: [{ collectionId: coll }], limit } }),
  });
  const j = await r.json();
  if (!r.ok) throw new Error(r.status + ' ' + JSON.stringify(j));
  return j.filter(x => x.document).map(x => ({ id: x.document.name.split('/').pop(), ...fd(x.document.fields) }));
}

const USER_FIELDS = [
  'displayName', 'level', 'diamondBalance', 'beansBalance', 'activeRoomId', 'xp', 'benchXP', 'princeXP',
  'dailyXP', 'weeklyXP', 'monthlyXP', 'dailyPrinceXP', 'weeklyPrinceXP', 'monthlyPrinceXP',
  'dailyDiamondsSent', 'weeklyDiamondsSent', 'monthlyDiamondsSent', 'totalDiamondsSent',
  'dailyBeansReceived', 'weeklyBeansReceived', 'monthlyBeansReceived', 'totalBeansReceived',
  'status', 'lastActive', 'totalDiamondsSpent', 'totalWinningEarned',
];
const ROOM_FIELDS = [
  'roomId', 'name', 'status', 'coverUrl', 'theme', 'ownerUid', 'admins', 'moderators', 'bannedUids',
  'currentUsersCount', 'capacity', 'isPrivate', 'passwordHash', 'lockedSeats', 'createdAt', 'endedAt',
  'dailyDiamondsSent', 'weeklyDiamondsSent', 'monthlyDiamondsSent', 'totalDiamondsSent', 'weeklyEarnings',
  'welcomeMessage', 'notice', 'micMode', 'backgroundMusic', 'updatedAt',
];

async function snap(uid, roomId) {
  const out = { uid, roomId: roomId || null, at: new Date().toISOString() };
  const u = await get(`users/${uid}`);
  if (u) {
    out.user = {};
    for (const f of USER_FIELDS) out.user[f] = u[f] === undefined ? null : u[f];
  }
  out.userTransactions = await list(`users/${uid}`, 'transactions', 10);
  out.userLedger = await list(`users/${uid}`, 'ledger', 10);
  out.userGameHistory = await list(`users/${uid}`, 'game_history', 10);

  if (roomId) {
    const r = await get(`rooms/${roomId}`);
    if (r) {
      out.room = {};
      for (const f of ROOM_FIELDS) out.room[f] = r[f] === undefined ? null : r[f];
    }
    out.participants = (await list(`rooms/${roomId}`, 'participants', 20)).map(p => ({
      id: p.id, role: p.role, isAdmin: p.isAdmin, seatIndex: p.seatIndex, isMuted: p.isMuted,
      lastActive: p.lastActive, joinedAt: p.joinedAt, comboCount: p.comboCount,
    }));
    out.messages = (await list(`rooms/${roomId}`, 'messages', 10)).map(m => ({
      id: m.id, type: m.type, uid: m.uid, text: (m.text || '').slice(0, 60), createdAt: m.createdAt,
      giftId: m.giftId, quantity: m.quantity, targetUid: m.targetUid,
    }));
    out.giftLeaderboardDaily = await list(`rooms/${roomId}/gift_leaderboard/daily`, '2026-10-03', 5).catch(() => 'N/A');
    out.roomKickLogs = await list(`rooms/${roomId}`, 'room_kick_logs', 10).catch(() => []);
    out.roomSalary = { weeklyEarnings: out.room ? out.room.weeklyEarnings : null };
  }
  return out;
}

function flatten(o, prefix = '', out = {}) {
  for (const [k, v] of Object.entries(o || {})) {
    const key = prefix ? `${prefix}.${k}` : k;
    if (v && typeof v === 'object' && !Array.isArray(v)) flatten(v, key, out);
    else out[key] = Array.isArray(v) ? JSON.stringify(v) : v;
  }
  return out;
}

function diff(a, b) {
  const fa = flatten(a), fb = flatten(b);
  const keys = new Set([...Object.keys(fa), ...Object.keys(fb)]);
  const rows = [];
  for (const k of [...keys].sort()) {
    const x = fa[k], y = fb[k];
    if (JSON.stringify(x) !== JSON.stringify(y)) rows.push({ field: k, before: x, after: y });
  }
  return rows;
}

async function main() {
  const args = process.argv.slice(2);
  const take = (flag) => { const i = args.indexOf(flag); return i >= 0 ? args.splice(i, 2).join(' ') : null; };
  const outIdx = args.indexOf('--out');
  const outFile = outIdx >= 0 ? args.splice(outIdx, 2)[1] : null;
  const cmpIdx = args.indexOf('--cmp');
  const cmpFile = cmpIdx >= 0 ? args.splice(cmpIdx, 2)[1] : null;
  const [uid, roomId] = args;
  if (!uid) { console.error('usage: <uid> [<roomId>] [--out f.json] [--cmp before.json]'); process.exit(1); }

  const cur = await snap(uid, roomId);
  if (cmpFile) {
    const before = JSON.parse(fs.readFileSync(cmpFile, 'utf8'));
    const d = diff(before, cur);
    const lines = d.length ? [`${d.length} field(s) changed:`] : ['NO CHANGES'];
    for (const r of d) lines.push(`  ${r.field}\n    - ${JSON.stringify(r.before)}\n    + ${JSON.stringify(r.after)}`);
    const text = lines.join('\n');
    if (outFile) fs.writeFileSync(outFile, text, 'utf8');
    console.log(text);
  } else {
    const text = JSON.stringify(cur, null, 1);
    if (outFile) fs.writeFileSync(outFile, text, 'utf8');
    else console.log(text);
  }
}
main().catch(e => { console.error('ERR:', e.message); process.exit(1); });
