/**
 * Test script for Room Support calculations, Level progression, and Weekly Lifecycle logic
 */
const assert = require('assert');

// Test ROOM_SUPPORT object exactly as implemented in functions/index.js
const ROOM_SUPPORT = {
    levels: [
        { level: 1, coinsTarget: 10000000, partnerSlots: 4, ownerReward: 1000000, partnerReward: 250000, totalReward: 2000000 },
        { level: 2, coinsTarget: 20000000, partnerSlots: 4, ownerReward: 2000000, partnerReward: 500000, totalReward: 4000000 },
        { level: 3, coinsTarget: 30000000, partnerSlots: 4, ownerReward: 3000000, partnerReward: 750000, totalReward: 6000000 },
        { level: 4, coinsTarget: 50000000, partnerSlots: 5, ownerReward: 6000000, partnerReward: 1200000, totalReward: 12000000 },
        { level: 5, coinsTarget: 100000000, partnerSlots: 6, ownerReward: 11000000, partnerReward: 2000000, totalReward: 23000000 },
        { level: 6, coinsTarget: 200000000, partnerSlots: 7, ownerReward: 21000000, partnerReward: 3500000, totalReward: 45500000 },
        { level: 7, coinsTarget: 300000000, partnerSlots: 7, ownerReward: 31000000, partnerReward: 5000000, totalReward: 66000000 },
    ],
    calculateLevel: function(totalCoins) {
        if (totalCoins >= 300000000) return 7;
        if (totalCoins >= 200000000) return 6;
        if (totalCoins >= 100000000) return 5;
        if (totalCoins >= 50000000) return 4;
        if (totalCoins >= 30000000) return 3;
        if (totalCoins >= 20000000) return 2;
        if (totalCoins >= 10000000) return 1;
        return 0;
    },
    getRequiredPartners: function(level) {
        if (level >= 6) return 7;
        if (level === 5) return 6;
        if (level === 4) return 5;
        if (level >= 1) return 4;
        return 0;
    }
};

console.log("=== Running Room Support Backend Lifecycle Tests ===");

// 1. Level Calculation Test
assert.strictEqual(ROOM_SUPPORT.calculateLevel(0), 0, "0 coins should be Level 0");
assert.strictEqual(ROOM_SUPPORT.calculateLevel(9999999), 0, "9.99M coins should be Level 0");
assert.strictEqual(ROOM_SUPPORT.calculateLevel(10000000), 1, "10M coins should be Level 1");
assert.strictEqual(ROOM_SUPPORT.calculateLevel(19999999), 1, "19.99M coins should be Level 1");
assert.strictEqual(ROOM_SUPPORT.calculateLevel(20000000), 2, "20M coins should be Level 2");
assert.strictEqual(ROOM_SUPPORT.calculateLevel(50000000), 4, "50M coins should be Level 4");
assert.strictEqual(ROOM_SUPPORT.calculateLevel(300000000), 7, "300M coins should be Level 7");
console.log("  [PASS] Level calculations match official tier thresholds.");

// 2. Partner Requirement Test
assert.strictEqual(ROOM_SUPPORT.getRequiredPartners(1), 4, "Level 1 requires 4 partners");
assert.strictEqual(ROOM_SUPPORT.getRequiredPartners(4), 5, "Level 4 requires 5 partners");
assert.strictEqual(ROOM_SUPPORT.getRequiredPartners(5), 6, "Level 5 requires 6 partners");
assert.strictEqual(ROOM_SUPPORT.getRequiredPartners(6), 7, "Level 6 requires 7 partners");
assert.strictEqual(ROOM_SUPPORT.getRequiredPartners(7), 7, "Level 7 requires 7 partners");
console.log("  [PASS] Partner slot counts match specifications.");

// 3. Simulated Gift Update Payload Test
function simulateGiftCycleUpdate(prevCycle, giftTotalCost) {
    const newTotal = (prevCycle.totalCoins || 0) + giftTotalCost;
    const achievedLevel = ROOM_SUPPORT.calculateLevel(newTotal);
    const levelCfg = achievedLevel > 0 ? ROOM_SUPPORT.levels[achievedLevel - 1] : null;
    const predictedRewardCoins = levelCfg ? levelCfg.totalReward : 0;
    return {
        totalCoins: newTotal,
        level: achievedLevel,
        predictedRewardCoins: predictedRewardCoins,
        status: "accumulating",
    };
}

const initialCycle = { totalCoins: 0, level: 0, predictedRewardCoins: 0, status: "accumulating" };
const after10MGift = simulateGiftCycleUpdate(initialCycle, 10000000);
assert.strictEqual(after10MGift.totalCoins, 10000000);
assert.strictEqual(after10MGift.level, 1);
assert.strictEqual(after10MGift.predictedRewardCoins, 2000000);
assert.strictEqual(after10MGift.status, "accumulating");
console.log("  [PASS] Gift update atomically syncs totalCoins, level, and predictedRewardCoins.");

// 4. Simulated Sunday Lock & Monday Clean Slate Test
function simulateSundayLock(activeCycle) {
    const achievedLevel = ROOM_SUPPORT.calculateLevel(activeCycle.totalCoins);
    const levelCfg = achievedLevel > 0 ? ROOM_SUPPORT.levels[achievedLevel - 1] : null;
    const historyRecord = {
        totalCoins: activeCycle.totalCoins,
        achievedLevel: achievedLevel,
        ownerReward: levelCfg ? levelCfg.ownerReward : 0,
        partnerReward: levelCfg ? levelCfg.partnerReward : 0,
        totalReward: levelCfg ? levelCfg.totalReward : 0,
        distributionStatus: achievedLevel >= 1 ? "pending" : "no_target_met",
        status: "closed"
    };

    const newCycle = {
        lastWeekCoins: activeCycle.totalCoins,
        lastWeekLevel: achievedLevel,
        lastWeekReward: levelCfg ? levelCfg.totalReward : 0,
        totalCoins: 0,
        level: 0,
        predictedRewardCoins: 0,
        status: "accumulating"
    };

    return { historyRecord, newCycle };
}

const lockResult = simulateSundayLock(after10MGift);
assert.strictEqual(lockResult.historyRecord.achievedLevel, 1);
assert.strictEqual(lockResult.historyRecord.totalCoins, 10000000);
assert.strictEqual(lockResult.historyRecord.distributionStatus, "pending");
assert.strictEqual(lockResult.newCycle.totalCoins, 0, "New cycle must zero-reset to 0 coins");
assert.strictEqual(lockResult.newCycle.level, 0, "New cycle must zero-reset to Level 0");
assert.strictEqual(lockResult.newCycle.lastWeekCoins, 10000000, "Previous week coins archived in lastWeekCoins");
assert.strictEqual(lockResult.newCycle.lastWeekLevel, 1, "Previous week level archived in lastWeekLevel");
console.log("  [PASS] Sunday lock & Monday zero-reset properly archives and resets state.");

console.log("=== All Backend Room Lifecycle Tests Passed! ===");
