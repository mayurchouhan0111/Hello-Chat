const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, '..', 'assets', 'gifts-vap');
const files = fs.readdirSync(dir).filter(f => f.endsWith('.vap'));

files.sort();

console.log('Inspecting ' + files.length + ' VAP files in assets/gifts-vap:');

for (const file of files) {
  const filePath = path.join(dir, file);
  const buf = fs.readFileSync(filePath);
  const idx = buf.indexOf(Buffer.from('vapc'));
  if (idx !== -1) {
    const len = buf.readUInt32BE(idx - 4);
    const jsonStr = buf.slice(idx + 4, idx - 4 + len).toString('utf8');
    try {
      const parsed = JSON.parse(jsonStr);
      const info = parsed.info || {};
      console.log(`\n=== ${file} ===`);
      console.log(JSON.stringify(parsed, null, 2));
    } catch (e) {
      console.log(`${file}: vapc found but JSON parse error: ${e.message}`);
    }
  } else {
    console.log(`${file}: vapc box NOT found`);
  }
}
