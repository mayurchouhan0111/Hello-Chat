// Dry-run tests for the monthly archive/reset helpers.
// Run: node functions/test_monthly_reset.js
const assert = require("assert");
const { monthKeyFromDate, prevMonthKey, monthNameFor, belongsToMonth, filterRowsForMonth } = require("./monthly_reset_lib.js");

// monthKeyFromDate / prevMonthKey round-trip
assert.strictEqual(monthKeyFromDate(new Date(Date.UTC(2026, 9, 1))), "2026-10");
assert.strictEqual(prevMonthKey("2026-10"), "2026-09");
assert.strictEqual(prevMonthKey("2026-01"), "2025-12");
assert.strictEqual(prevMonthKey("2026-03"), "2026-02");
assert.strictEqual(monthNameFor("2026-09"), "September 2026");

// On-time run (1st of month, before any new-month gift): all Sept rows archive.
const onTime = [
    { uid: "a", monthlyDiamondsSent: 5000000, lastMonthlySentDate: "2026-09" },
    { uid: "b", monthlyDiamondsSent: 3000000, lastMonthlySentDate: "2026-09" },
    { uid: "c", monthlyDiamondsSent: 1000, lastMonthlySentDate: "" },
];
assert.strictEqual(filterRowsForMonth(onTime, "2026-09", "lastMonthlySentDate").length, 3);

// Late run: gift already landed in October -> its row must NOT be archived
// under 2026-09 nor zeroed by the 2026-09 reset.
const late = [
    { uid: "old", monthlyDiamondsSent: 5000000, lastMonthlySentDate: "2026-09" },
    { uid: "fresh", monthlyDiamondsSent: 700000, lastMonthlySentDate: "2026-10" },
    { uid: "legacy", monthlyDiamondsSent: 42, lastMonthlySentDate: undefined },
];
const archived = filterRowsForMonth(late, "2026-09", "lastMonthlySentDate");
assert.deepStrictEqual(archived.map((r) => r.uid).sort(), ["legacy", "old"]);
assert.ok(!archived.some((r) => r.uid === "fresh"), "fresh October row must be excluded");

// belongsToMonth edge cases
assert.strictEqual(belongsToMonth(undefined, "2026-09"), true, "missing stamp treated as belong");
assert.strictEqual(belongsToMonth("2026-10", "2026-09"), false, "newer stamp excluded");
assert.strictEqual(belongsToMonth("2026-09", "2026-09"), true, "same-month stamp included");

// Idempotency: filtering an already-reset (zero-stamped-old) row still includes it.
assert.strictEqual(belongsToMonth("2026-08", "2026-09"), true);

console.log("monthly_reset_lib: all dry-run assertions passed");
