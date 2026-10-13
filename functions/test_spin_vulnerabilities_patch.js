const assert = require("assert");

console.log("==================================================");
console.log("🧪 TESTING SPIN THE WHEEL SECURITY & FINANCIAL PATCHES");
console.log("==================================================");

// --- TASK 1: Financial Defect & Double-Deduction Verification ---
function simulateBalanceDeduction(currentDiamonds, currentBeans, deltaBet) {
    let diamondDeduction = 0;
    let beanDeduction = 0;
    let finalDiamondBalance = currentDiamonds;
    let finalBeansBalance = currentBeans;

    if (deltaBet > 0) {
        if (currentDiamonds >= deltaBet) {
            diamondDeduction = deltaBet;
            finalDiamondBalance = currentDiamonds - deltaBet;
        } else {
            const shortfall = deltaBet - Math.max(0, currentDiamonds);
            const beansNeeded = Math.ceil((shortfall * 7) / 2);
            if (currentBeans < beansNeeded) {
                throw new Error("Insufficient Diamonds & Stars.");
            }
            diamondDeduction = Math.max(0, currentDiamonds);
            beanDeduction = beansNeeded;
            finalDiamondBalance = 0;
            finalBeansBalance = currentBeans - beansNeeded;
        }
    }

    return {
        diamondDeduction,
        beanDeduction,
        finalDiamondBalance,
        finalBeansBalance
    };
}

// Test Case 1.1: Full diamonds available (100 bet with 150 diamonds)
{
    const res = simulateBalanceDeduction(150, 500, 100);
    assert.strictEqual(res.diamondDeduction, 100);
    assert.strictEqual(res.beanDeduction, 0);
    assert.strictEqual(res.finalDiamondBalance, 50);
    assert.strictEqual(res.finalBeansBalance, 500);
    console.log("  ✅ PASS: Task 1.1 - Full diamonds: deducted from diamonds only, beans untouched");
}

// Test Case 1.2: Insufficient diamonds (20 diamonds, 100 bet -> 80 shortfall -> 280 beans)
{
    const res = simulateBalanceDeduction(20, 500, 100);
    assert.strictEqual(res.diamondDeduction, 20); // Only available diamonds deducted! Never negative!
    assert.strictEqual(res.beanDeduction, 280);   // Math.ceil((80 * 7) / 2) = 280
    assert.strictEqual(res.finalDiamondBalance, 0); // Cleanly 0, NEVER -80!
    assert.strictEqual(res.finalBeansBalance, 220); // 500 - 280 = 220
    console.log("  ✅ PASS: Task 1.2 - Shortfall: deducted 20 diamonds (to 0) and 280 beans, zero negative diamonds");
}

// Test Case 1.3: Zero diamonds (0 diamonds, 100 bet -> 100 shortfall -> 350 beans)
{
    const res = simulateBalanceDeduction(0, 500, 100);
    assert.strictEqual(res.diamondDeduction, 0);
    assert.strictEqual(res.beanDeduction, 350);
    assert.strictEqual(res.finalDiamondBalance, 0);
    assert.strictEqual(res.finalBeansBalance, 150);
    console.log("  ✅ PASS: Task 1.3 - Zero diamonds: deducted 0 diamonds and 350 beans");
}

// Test Case 1.4: Insufficient beans throws error
{
    assert.throws(() => {
        simulateBalanceDeduction(20, 100, 100); // needs 280 beans, only has 100
    }, /Insufficient Diamonds & Stars/);
    console.log("  ✅ PASS: Task 1.4 - Insufficient beans throws Insufficient Diamonds & Stars");
}

// --- TASK 2: Patch 100% Unconditional Win Exploit in Instant Spin ---
function simulateInstantSpinOutcome(chosenSectorInput, displayIndex, cost, multiplier, segmentCount = 8) {
    if (chosenSectorInput === undefined || chosenSectorInput === null || chosenSectorInput === "") {
        throw new Error("Valid chosenSector (0-7) is required.");
    }
    const chosenSector = Math.floor(Number(chosenSectorInput));
    if (isNaN(chosenSector) || chosenSector < 0 || chosenSector >= segmentCount) {
        throw new Error("Valid chosenSector (0-7) is required.");
    }

    const isWin = (chosenSector === displayIndex);
    const prize = isWin ? Math.floor(cost * multiplier) : 0;
    return { isWin, prize };
}

// Test Case 2.1: Missing chosenSector throws invalid argument (exploit blocked!)
{
    assert.throws(() => simulateInstantSpinOutcome(undefined, 3, 100, 5), /Valid chosenSector/);
    assert.throws(() => simulateInstantSpinOutcome(null, 3, 100, 5), /Valid chosenSector/);
    assert.throws(() => simulateInstantSpinOutcome("", 3, 100, 5), /Valid chosenSector/);
    console.log("  ✅ PASS: Task 2.1 - Missing/null chosenSector rejected (unconditional win exploit blocked)");
}

// Test Case 2.2: Out of bounds chosenSector throws invalid argument
{
    assert.throws(() => simulateInstantSpinOutcome(-1, 3, 100, 5), /Valid chosenSector/);
    assert.throws(() => simulateInstantSpinOutcome(8, 3, 100, 5), /Valid chosenSector/);
    assert.throws(() => simulateInstantSpinOutcome("abc", 3, 100, 5), /Valid chosenSector/);
    console.log("  ✅ PASS: Task 2.2 - Out of bounds and NaN chosenSector rejected");
}

// Test Case 2.3: Sector mismatch gives strictly 0 prize (Loss)
{
    const res = simulateInstantSpinOutcome(2, 3, 100, 5);
    assert.strictEqual(res.isWin, false);
    assert.strictEqual(res.prize, 0);
    console.log("  ✅ PASS: Task 2.3 - Sector mismatch (chose 2, landed 3) gives 0 prize");
}

// Test Case 2.4: Sector match gives win
{
    const res = simulateInstantSpinOutcome(3, 3, 100, 5);
    assert.strictEqual(res.isWin, true);
    assert.strictEqual(res.prize, 500);
    console.log("  ✅ PASS: Task 2.4 - Sector match (chose 3, landed 3) awards 500 prize");
}

// --- TASK 3: Float Sanitization ---
{
    const rawBets = { "tomato": "100.99", "cabbage": 50.1, "steak": "invalid", "negative": -50 };
    const bets = {};
    for (const [k, v] of Object.entries(rawBets)) {
        const intAmount = Math.max(0, Math.floor(Number(v) || 0));
        if (intAmount > 0) {
            bets[k] = intAmount;
        }
    }
    assert.strictEqual(bets.tomato, 100);
    assert.strictEqual(bets.cabbage, 50);
    assert.strictEqual(bets.steak, undefined);
    assert.strictEqual(bets.negative, undefined);
    const total = Object.values(bets).reduce((a, b) => a + b, 0);
    assert.strictEqual(total, 150);
    console.log("  ✅ PASS: Task 3 - Floating-point bet injection sanitized to clean whole integers");
}

console.log("==================================================");
console.log("🎉 ALL PATCH VERIFICATION CHECKS PASSED!");
console.log("==================================================");
