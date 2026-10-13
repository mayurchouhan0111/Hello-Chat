/**
 * Test Suite: HB-PMS hierarchy + financial policy invariants
 *
 * Unlike the other test_*.js files in this folder, this one does NOT copy the
 * helpers it tests - it requires lib/hb_pms.js, the exact module functions/index.js
 * imports. Copying is how the 30%/10% rates ended up living in three places with
 * three different fallback behaviours, so a copied test proved nothing.
 *
 * Run:  node test_hb_pms.js
 */

const assert = require("assert");
const {
    HB_TIERS,
    HB_RANK,
    DEFAULT_FINANCIAL_POLICIES,
    normalizeTier,
    round2,
    assertValidRates,
    canManageTier,
    hierarchyScope,
    isTargetInScope,
    isSalaryEligible
} = require("./lib/hb_pms");

let testsPassed = 0;
let testsFailed = 0;

function runTest(name, fn) {
    try {
        fn();
        testsPassed++;
        console.log(`  [PASS] ${name}`);
    } catch (e) {
        testsFailed++;
        console.error(`  [FAIL] ${name}`);
        console.error(`         ${e.message}`);
    }
}

console.log("\n==================================================");
console.log("HB-PMS HIERARCHY + FINANCIAL POLICY TESTS");
console.log("==================================================");

// ─────────────────────────────────────────────────────────────
// 1. Tier normalisation: role field AND legacy tags must agree
// ─────────────────────────────────────────────────────────────
runTest("normalizeTier honours role, tags, and isAgencyOwner", () => {
    assert.strictEqual(normalizeTier({ role: "host" }), "host");
    assert.strictEqual(normalizeTier({ role: "admin" }), "admin");
    assert.strictEqual(normalizeTier({ role: "superadmin" }), "superadmin");
    assert.strictEqual(normalizeTier({ role: "owner" }), "owner");

    // Legacy docs that only carry tags (written before `role` existed).
    assert.strictEqual(normalizeTier({ tags: ["Admin"] }), "admin");
    assert.strictEqual(normalizeTier({ tags: ["Agency"] }), "agency");
    assert.strictEqual(normalizeTier({ tags: ["SuperAdmin", "Admin"] }), "superadmin", "highest tag must win");
    assert.strictEqual(normalizeTier({ tags: ["Owner"], role: "host" }), "owner", "Owner tag must not be downgraded");

    assert.strictEqual(normalizeTier({ isAgencyOwner: true }), "agency");
    assert.strictEqual(normalizeTier(null), "host", "null must fail closed to host");
    assert.strictEqual(normalizeTier({}), "host", "empty must fail closed to host");
});

runTest("5 tiers are strictly ordered owner > superadmin > admin > agency > host", () => {
    assert.deepStrictEqual(HB_TIERS, ["host", "agency", "admin", "superadmin", "owner"]);
    for (let i = 0; i < HB_TIERS.length - 1; i++) {
        assert.ok(HB_RANK[HB_TIERS[i]] < HB_RANK[HB_TIERS[i + 1]], `${HB_TIERS[i]} must rank below ${HB_TIERS[i + 1]}`);
    }
    assert.strictEqual(canManageTier("admin", "host"), true);
    assert.strictEqual(canManageTier("admin", "agency"), true);
    assert.strictEqual(canManageTier("admin", "admin"), false, "must not manage own tier");
    assert.strictEqual(canManageTier("admin", "superadmin"), false, "must not manage upward");
    assert.strictEqual(canManageTier("owner", "superadmin"), true);
});

// ─────────────────────────────────────────────────────────────
// 2. Query sandboxing: the server derives the filter, never the client
// ─────────────────────────────────────────────────────────────
runTest("hierarchyScope derives scope from the resolved caller, not the request", () => {
    assert.strictEqual(hierarchyScope({ role: "owner", uid: "o1" }), null, "Owner is unconstrained");

    assert.deepStrictEqual(
        hierarchyScope({ role: "superadmin", uid: "s1", branchId: "b1" }),
        { field: "branchId", value: "b1" },
        "Super Admin is confined to its own branch"
    );
    assert.deepStrictEqual(
        hierarchyScope({ role: "admin", uid: "a1" }),
        { field: "adminId", value: "a1" }
    );
    assert.deepStrictEqual(
        hierarchyScope({ role: "agency", uid: "g1" }),
        { field: "agencyId", value: "g1" }
    );
    assert.strictEqual(
        hierarchyScope({ role: "host", uid: "h1" }).field,
        "__selfOnly",
        "Host has no hierarchy field, so listing must be refused, not widened"
    );
});

runTest("Super Admin with no branch fails CLOSED to self, never global", () => {
    // Regression: an unprovisioned Super Admin must not read the whole platform.
    const scope = hierarchyScope({ role: "superadmin", uid: "s1", branchId: null });
    assert.strictEqual(scope.field, "__selfOnly");
    assert.notStrictEqual(scope.field, "__global__");
});

// ─────────────────────────────────────────────────────────────
// 3. Scope enforcement: rank AND linkage, both required
// ─────────────────────────────────────────────────────────────
runTest("isTargetInScope requires BOTH lower rank and real linkage", () => {
    const branchSuper = { role: "superadmin", uid: "s1", branchId: "b1" };

    // Same branch, lower rank -> allowed.
    assert.strictEqual(
        isTargetInScope(branchSuper, { uid: "a1", role: "admin", branchId: "b1" }),
        true
    );
    // Peer branch, lower rank -> DENIED. The rank check alone is not enough.
    assert.strictEqual(
        isTargetInScope(branchSuper, { uid: "a9", role: "admin", branchId: "bOTHER" }),
        false,
        "cross-branch access must be denied"
    );
    // Same branch, but higher rank -> DENIED. The linkage check alone is not enough.
    assert.strictEqual(
        isTargetInScope({ role: "admin", uid: "a1" }, { uid: "s1", role: "superadmin", adminId: "a1" }),
        false,
        "escalation must be denied"
    );
    assert.strictEqual(isTargetInScope({ role: "owner", uid: "o1" }, { uid: "anyone", role: "owner" }), true);
    assert.strictEqual(
        isTargetInScope({ role: "host", uid: "h1" }, { uid: "h2", role: "host" }),
        false,
        "hosts manage nobody"
    );
});

// ─────────────────────────────────────────────────────────────
// 4. Money: rounding and rate validation
// ─────────────────────────────────────────────────────────────
runTest("round2 kills sub-cent precision and float drift", () => {
    assert.strictEqual(round2(10.005), 10.01);
    assert.strictEqual(round2(0.1 + 0.2), 0.3, "float drift must not reach the ledger");
    assert.strictEqual(round2(33.333333), 33.33);
    assert.strictEqual(round2(1.004999), 1, "must round down below the half-cent");
    assert.strictEqual(round2(1234.5678), 1234.57);
});

runTest("a legitimate 0 rate is accepted (regression: || 0.30 turned 0 into 0.30)", () => {
    // The original bug: `data.agencyCommissionRate || 0.30` silently turned a
    // deliberate 0 ("disable agency commission") back into 0.30.
    assert.doesNotThrow(() => assertValidRates(0, 0));
    assert.doesNotThrow(() => assertValidRates(0, 0.1), "one rate may be zeroed independently");
    assert.strictEqual(DEFAULT_FINANCIAL_POLICIES.agencyCommissionRate, 0.30);
    assert.strictEqual(DEFAULT_FINANCIAL_POLICIES.adminCommissionRate, 0.10);
});

runTest("assertValidRates rejects configs that would drain the platform", () => {
    assert.throws(() => assertValidRates(1.5, 0.1), /between 0 and 1/);
    assert.throws(() => assertValidRates(-0.1, 0.1), /between 0 and 1/);
    assert.throws(() => assertValidRates(0.95, 0.10), /cannot exceed 100%/);
    assert.throws(() => assertValidRates("0.3", 0.1), /must be a number/);
    assert.throws(() => assertValidRates(NaN, 0.1), /must be a number/);
    assert.doesNotThrow(() => assertValidRates(0.9, 0.1), "exactly 100% is the boundary and is legal");
});

// ─────────────────────────────────────────────────────────────
// 5. Salary eligibility
// ─────────────────────────────────────────────────────────────
runTest("Super Admin is excluded from the salary system", () => {
    assert.strictEqual(isSalaryEligible({ role: "superadmin" }), false);
    assert.strictEqual(isSalaryEligible({ tags: ["SuperAdmin"] }), false, "tag-only Super Admin also excluded");
    assert.strictEqual(isSalaryEligible({ role: "admin" }), true);
    assert.strictEqual(isSalaryEligible({ role: "agency" }), true);
    assert.strictEqual(isSalaryEligible({ role: "host" }), true);
    assert.strictEqual(isSalaryEligible({ role: "owner" }), true);
});

console.log("\n==================================================");
console.log(`${testsPassed} PASSED, ${testsFailed} FAILED`);
console.log("==================================================");

if (testsFailed > 0) process.exit(1);
