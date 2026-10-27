const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const results = [];

function walk(dir) {
  const files = fs.readdirSync(dir, { withFileTypes: true });
  for (const f of files) {
    if (f.name === 'node_modules' || f.name === '.git' || f.name === 'build' || f.name === '.dart_tool') continue;
    const full = path.join(dir, f.name);
    if (f.isDirectory()) {
      walk(full);
    } else if (/\.(dart|js|ts|tsx|cjs|json)$/.test(f.name)) {
      try {
        const content = fs.readFileSync(full, 'utf8');
        if (content.includes('walletBalance')) {
          const lines = content.split('\n');
          lines.forEach((line, idx) => {
            if (line.includes('walletBalance')) {
              results.push({
                file: path.relative(ROOT, full),
                line: idx + 1,
                text: line.trim()
              });
            }
          });
        }
      } catch (e) {}
    }
  }
}

walk(ROOT);
console.log(`Found ${results.length} occurrences of walletBalance:`);
results.forEach(r => console.log(`${r.file}:${r.line}: ${r.text}`));
