const { spawnSync } = require('child_process');
const q = (...a) => {
  const r = spawnSync(process.execPath, ['scripts/fsqa.cjs', ...a], { encoding: 'utf8', maxBuffer: 1 << 28 });
  try { return JSON.parse(r.stdout); } catch { return null; }
};
const RID = process.argv[2] || 'room_VJ1GwGfAwafIhCuHDaRTqBbdhYj2';
const r = q('get', 'rooms/' + RID);
if (!r) { console.log('ROOM NOT FOUND'); process.exit(1); }
console.log('roomId    =', r.roomId);
console.log('name      =', JSON.stringify(r.name));
console.log('theme     =', JSON.stringify(r.theme));
console.log('coverUrl  =', JSON.stringify(r.coverUrl));
console.log('capacity  =', r.capacity);
console.log('count     =', r.currentUsersCount);
const p = q('sublist', 'rooms/' + RID, 'participants', '100');
console.log('participantDocs =', p ? p.length : 0);
if (p) p.slice(0, 6).forEach(x => console.log('   ', (x.uid || '?').slice(0, 12), 'role=', x.role));
const m = q('sublist', 'rooms/' + RID, 'messages', '500');
console.log('messages  =', m ? m.length : 0);