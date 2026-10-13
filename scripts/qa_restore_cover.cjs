const { spawnSync } = require('child_process');
const RID = 'room_VJ1GwGfAwafIhCuHDaRTqBbdhYj2';
const ORIGINAL = 'https://res.cloudinary.com/dceh4ob2i/image/upload/v1780210449/profile_photos/wjc5ejev1uhk2p6hbw5n.jpg';
const payload = JSON.stringify({ coverUrl: ORIGINAL, theme: 'Casual Chat' });
const r = spawnSync(process.execPath, ['scripts/fsqa.cjs', 'set', 'rooms/' + RID, payload], { encoding: 'utf8', maxBuffer: 1 << 28 });
console.log('restore exit=', r.status, (r.stdout || '').slice(0, 160), (r.stderr || '').slice(0, 160));
const c = spawnSync(process.execPath, ['scripts/fsqa.cjs', 'get', 'rooms/' + RID], { encoding: 'utf8', maxBuffer: 1 << 28 });
try {
  const d = JSON.parse(c.stdout);
  console.log('theme    =', JSON.stringify(d.theme));
  console.log('coverUrl =', d.coverUrl);
  console.log('cover restored =', d.coverUrl === ORIGINAL, '| theme restored =', d.theme === 'Casual Chat');
} catch { console.log('verify failed', (c.stdout || '').slice(0, 200)); }