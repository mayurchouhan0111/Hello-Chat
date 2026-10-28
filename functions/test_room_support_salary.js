const assert = require("assert");
const fs = require("fs");
const path = require("path");
const {
    normalizeRoomSupportWeekId,
    isRoomSupportPartnerForWeek,
    getFinalizedRoomSupportCoins
} = require("./index.js");

let passed = 0;
let failed = 0;

function runTest(name, fn) {
    try {
        fn();
        passed++;
        console.log(`  [PASS] ${name}`);
    } catch (e) {
        failed++;
        console.error(`  [FAIL] ${name}`);
        console.error(`         ${e.message}`);
    }
}

console.log("\n==================================================");
console.log("ROOM SUPPORT SALARY TESTS");
console.log("==================================================");

runTest("legacy week_YYYY-MM-DD IDs normalize to ISO week IDs", () => {
    assert.strictEqual(normalizeRoomSupportWeekId("week_2026-10-25"), "2026-W43");
    assert.strictEqual(normalizeRoomSupportWeekId("week_2026-10-18"), "2026-W42");
    assert.strictEqual(normalizeRoomSupportWeekId("2026-W43"), "2026-W43");
    assert.strictEqual(normalizeRoomSupportWeekId(""), "");
    assert.strictEqual(normalizeRoomSupportWeekId(null), "");
});

runTest("partners count only for the week they were assigned to", () => {
    assert.strictEqual(isRoomSupportPartnerForWeek({ cycleWeekId: "week_2026-10-25" }, "2026-W43"), true);
    assert.strictEqual(isRoomSupportPartnerForWeek({ cycleWeekId: "2026-W43" }, "2026-W43"), true);
    assert.strictEqual(isRoomSupportPartnerForWeek({ cycleWeekId: "week_2026-10-18" }, "2026-W43"), false);
    assert.strictEqual(isRoomSupportPartnerForWeek({ cycleWeekId: "2026-W42" }, "2026-W43"), false);
    assert.strictEqual(isRoomSupportPartnerForWeek({}, "2026-W43"), false);
    assert.strictEqual(isRoomSupportPartnerForWeek({ cycleWeekId: "2026-W43" }, ""), false);
});

runTest("closing-week coins come from the right field", () => {
    assert.strictEqual(
        getFinalizedRoomSupportCoins({ weekId: "2026-W43", totalCoins: 340798200, lastWeekCoins: 4720 }, "2026-W43", "2026-W44"),
        340798200
    );
    assert.strictEqual(
        getFinalizedRoomSupportCoins({ weekId: "2026-W44", totalCoins: 1900, lastWeekCoins: 326800100 }, "2026-W43", "2026-W44"),
        326800100
    );
    assert.strictEqual(
        getFinalizedRoomSupportCoins({ weekId: "week_2026-10-25", totalCoins: 340798200 }, "2026-W43", "2026-W44"),
        340798200
    );
});

runTest("stale cycles cannot re-award an older week", () => {
    assert.strictEqual(
        getFinalizedRoomSupportCoins({ weekId: "2026-W43", totalCoins: 340798200, lastWeekCoins: 4720 }, "2026-W44", "2026-W45"),
        0
    );
    assert.strictEqual(
        getFinalizedRoomSupportCoins({ weekId: "2026-W42", totalCoins: 3780, lastWeekCoins: 119304 }, "2026-W43", "2026-W44"),
        0
    );
    assert.strictEqual(
        getFinalizedRoomSupportCoins({ totalCoins: 163123500 }, "2026-W43", "2026-W44"),
        0
    );
});

runTest("lock transaction reads partners and room before its first write", () => {
    const source = fs.readFileSync(path.join(__dirname, "index.js"), "utf8");
    const start = source.indexOf("exports.lockRoomSupportCycles");
    const end = source.indexOf("Shared worker to process Wednesday salary rewards");
    assert.ok(start > 0 && end > start, "lockRoomSupportCycles block not found");
    const block = source.slice(start, end);
    const firstWrite = block.indexOf("transaction.set(historyRef");
    const partnersRead = block.indexOf("const partnersSnap = await transaction.get");
    const roomRead = block.indexOf("const roomSnap = await transaction.get");
    assert.ok(firstWrite > 0, "history write not found");
    assert.ok(partnersRead > 0 && partnersRead < firstWrite, "partners must be read before writing history");
    assert.ok(roomRead > 0 && roomRead < firstWrite, "room must be read before writing history");
});

runTest("pending-weeks collection-group index exists", () => {
    const overrides = require("../firebase/firestore.indexes.json").fieldOverrides;
    const found = overrides.some(i =>
        i.collectionGroup === "weeks" &&
        i.fieldPath === "distributionStatus" &&
        i.indexes.some(idx => idx.queryScope === "COLLECTION_GROUP" && idx.order === "ASCENDING")
    );
    assert.ok(found, "missing collection-group index for weeks.distributionStatus");
});

console.log(`\nResult: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
