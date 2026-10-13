const { spawnSync } = require('child_process');
const UID = 'VJ1GwGfAwafIhCuHDaRTqBbdhYj2';
const RID = 'vRe3mzy92bAN1JI4h0tQ';
const q = (...a) => {
  const r = spawnSync(process.execPath, ['scripts/fsqa.cjs', ...a], { encoding: 'utf8', maxBuffer: 1 << 28 });
  try { return JSON.parse(r.stdout); } catch { return null; }
};
const start = Date.now();
for (let i = 0; i < 11; i++) {
  const el = ((Date.now() - start) / 60000).toFixed(1);
  const list = q('sublist', 'rooms/' + RID, 'participants', '100');
  let state;
  if (!list) state = 'QUERY_FAIL';
  else {
    const me = list.find(p => p.uid === UID);
    if (!me) state = '>>> DELETED (user removed from room)';
    else state = 'alive role=' + me.role + ' lastActive=' + me.lastActive;
  }
  const u = q('get', 'users/' + UID);
  console.log(`t+${el.padStart(4)}min  participant: ${state}`);
  console.log(`              userDoc: status=${u && u.status} lastActive=${u && u.lastActive}`);
  if (i < 10) spawnSync('powershell', ['-NoProfile', '-Command', 'Start-Sleep -Seconds 50'], { encoding: 'utf8' });
}