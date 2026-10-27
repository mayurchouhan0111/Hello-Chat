const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const outDir = path.join(__dirname, '..', 'assets', 'images', 'gifts');
if (!fs.existsSync(outDir)) {
  fs.mkdirSync(outDir, { recursive: true });
}

const vaps = [
  { id: 'vap_gift_1', file: 'gift_1.vap', ss: '00:00:03.0', rgb: [0, 0, 1280, 720], a: [0, 724, 640, 360] },
  { id: 'vap_gift_2', file: 'gift_2.vap', ss: '00:00:02.5', rgb: [0, 0, 478, 850], a: [482, 0, 239, 425] },
  { id: 'vap_gift_3', file: 'gift_3.vap', ss: '00:00:03.0', rgb: [0, 0, 720, 1280], a: [724, 0, 360, 640] },
  { id: 'vap_gift_4', file: 'gift_4.vap', ss: '00:00:03.0', rgb: [0, 0, 846, 1504], a: [850, 0, 423, 752] },
  { id: 'vap_gift_5', file: 'gift_5.vap', ss: '00:00:03.0', rgb: [0, 0, 1504, 846], a: [0, 850, 752, 423] },
  { id: 'vap_gift_6', file: 'gift_6.vap', ss: '00:00:03.0', rgb: [0, 0, 1504, 846], a: [0, 850, 752, 423] },
  { id: 'vap_gift_7', file: 'gift_7.vap', ss: '00:00:03.0', rgb: [0, 0, 846, 1504], a: [850, 0, 423, 752] },
  { id: 'vap_gift_8', file: 'gift_8.vap', ss: '00:00:04.0', rgb: [0, 0, 846, 1504], a: [850, 0, 423, 752] },
  { id: 'vap_gift_9', file: 'gift_9.vap', ss: '00:00:04.0', rgb: [0, 0, 846, 1504], a: [850, 0, 423, 752] },
  { id: 'vap_gift_10', file: 'gift_10.vap', ss: '00:00:02.5', rgb: [0, 0, 846, 1504], a: [850, 0, 423, 752] },
  { id: 'vap_gift_11', file: 'gift_11.vap', ss: '00:00:02.0', rgb: [0, 0, 846, 1504], a: [850, 0, 423, 752] },
  { id: 'vap_gift_12', file: 'gift_12.vap', ss: '00:00:02.0', rgb: [0, 0, 846, 1504], a: [850, 0, 423, 752] },
];

console.log('Extracting high-resolution transparent PNG icons from VAP assets...');

for (const v of vaps) {
  const inPath = path.join(__dirname, '..', 'assets', 'gifts-vap', v.file);
  const outPath = path.join(outDir, `${v.id}.png`);
  const filter = `[0:v]crop=${v.rgb[2]}:${v.rgb[3]}:${v.rgb[0]}:${v.rgb[1]}[rgb];[0:v]crop=${v.a[2]}:${v.a[3]}:${v.a[0]}:${v.a[1]},scale=${v.rgb[2]}:${v.rgb[3]}[a];[rgb][a]alphamerge[out]`;
  const cmd = `ffmpeg -y -ss ${v.ss} -i "${inPath}" -filter_complex "${filter}" -map "[out]" -frames:v 1 -update 1 "${outPath}"`;
  
  try {
    execSync(cmd, { stdio: 'pipe' });
    const stat = fs.statSync(outPath);
    console.log(`✅ ${v.id}.png (${(stat.size / 1024).toFixed(1)} KB)`);
  } catch (err) {
    console.error(`❌ Failed ${v.id}:`, err.message);
  }
}

console.log('All icons extracted successfully!');
