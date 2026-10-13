const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const levels = [
  { level: 1, coinsTarget: 100000, partnerSlots: 4, ownerReward: 11250, partnerReward: 1875, totalReward: 18750 },
  { level: 2, coinsTarget: 300000, partnerSlots: 4, ownerReward: 32850, partnerReward: 4050, totalReward: 49050 },
  { level: 3, coinsTarget: 500000, partnerSlots: 4, ownerReward: 49700, partnerReward: 5075, totalReward: 70000 },
  { level: 4, coinsTarget: 1000000, partnerSlots: 5, ownerReward: 96600, partnerReward: 8680, totalReward: 140000 },
  { level: 5, coinsTarget: 2000000, partnerSlots: 5, ownerReward: 200000, partnerReward: 18000, totalReward: 290000 },
  { level: 6, coinsTarget: 3500000, partnerSlots: 6, ownerReward: 360000, partnerReward: 30000, totalReward: 540000 },
  { level: 7, coinsTarget: 5000000, partnerSlots: 6, ownerReward: 525000, partnerReward: 45000, totalReward: 795000 },
  { level: 8, coinsTarget: 8000000, partnerSlots: 7, ownerReward: 840000, partnerReward: 70000, totalReward: 1330000 },
  { level: 9, coinsTarget: 12000000, partnerSlots: 7, ownerReward: 1280000, partnerReward: 100000, totalReward: 1980000 },
  { level: 10, coinsTarget: 18000000, partnerSlots: 8, ownerReward: 1950000, partnerReward: 150000, totalReward: 3150000 },
  { level: 11, coinsTarget: 25000000, partnerSlots: 8, ownerReward: 2750000, partnerReward: 200000, totalReward: 4350000 },
  { level: 12, coinsTarget: 35000000, partnerSlots: 9, ownerReward: 3900000, partnerReward: 280000, totalReward: 6420000 },
  { level: 13, coinsTarget: 50000000, partnerSlots: 9, ownerReward: 5600000, partnerReward: 400000, totalReward: 9200000 },
  { level: 14, coinsTarget: 75000000, partnerSlots: 10, ownerReward: 8500000, partnerReward: 600000, totalReward: 14500000 },
  { level: 15, coinsTarget: 100000000, partnerSlots: 10, ownerReward: 11500000, partnerReward: 850000, totalReward: 20000000 },
  { level: 16, coinsTarget: 150000000, partnerSlots: 11, ownerReward: 17500000, partnerReward: 1250000, totalReward: 31250000 },
  { level: 17, coinsTarget: 200000000, partnerSlots: 11, ownerReward: 23500000, partnerReward: 1700000, totalReward: 42200000 },
  { level: 18, coinsTarget: 300000000, partnerSlots: 12, ownerReward: 35500000, partnerReward: 2500000, totalReward: 65500000 },
  { level: 19, coinsTarget: 450000000, partnerSlots: 12, ownerReward: 54000000, partnerReward: 3800000, totalReward: 99600000 },
  { level: 20, coinsTarget: 600000000, partnerSlots: 12, ownerReward: 72000000, partnerReward: 5000000, totalReward: 132000000 }
];

// Sanity check: Ensure strict sequential order
let prevTarget = 0;
for (let i = 0; i < levels.length; i++) {
  const l = levels[i];
  if (l.level !== i + 1) {
    throw new Error(`Level mismatch at index ${i}: expected ${i + 1}, got ${l.level}`);
  }
  if (l.coinsTarget <= prevTarget) {
    throw new Error(`Non-monotonic target at Level ${l.level}: ${l.coinsTarget} <= ${prevTarget}`);
  }
  prevTarget = l.coinsTarget;
}

console.log('Sanity check passed: all 20 levels are strictly ascending and valid!');

const payload = {
  levels,
  updatedAt: new Date().toISOString()
};

const tmpFile = path.join(__dirname, 'temp_room_support_levels.json');
fs.writeFileSync(tmpFile, JSON.stringify(payload, null, 2));

const res = spawnSync(process.execPath, [path.join(__dirname, 'fsqa.cjs'), 'set', 'room_support_configs/settings', '@' + tmpFile], {
  encoding: 'utf8'
});

console.log('fsqa output:', res.stdout || res.stderr);
fs.unlinkSync(tmpFile);
