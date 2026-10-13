const fs = require('fs');
const path = require('path');
const file = path.join(__dirname, 'index.js');
const s = fs.readFileSync(file, 'utf8');
const lines = s.split(/\r?\n/);
lines.forEach((l, i) => {
    if (l.includes('sendGiftWithCombo') || l.includes('exports.sendGift')) {
        console.log(`${i + 1}: ${l}`);
    }
});
