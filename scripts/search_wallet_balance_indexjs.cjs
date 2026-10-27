const fs = require('fs');
const content = fs.readFileSync('functions/index.js', 'utf8');
const lines = content.split('\n');
console.log('Matches in functions/index.js:');
lines.forEach((line, idx) => {
  if (line.includes('walletBalance')) {
    console.log(`Line ${idx + 1}: ${line.trim()}`);
  }
});
