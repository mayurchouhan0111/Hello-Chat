/**
 * HB-PMS pure logic: the 5-tier hierarchy, financial-policy validation and
 * money rounding.
 *
 * Extracted so that BOTH functions/index.js and test_hb_pms.js require the same
 * implementation. The other test_*.js files in this repo copy their helpers into
 * the test file "kept in sync with backend", which is precisely how the 30%/10%
 * rates ended up defined three times with three different behaviours. One copy,
 * one source of truth, tested directly.
 *
 * Nothing here touches Firestore - it is all pure functions, so it is testable
 * without the emulator.
 */

const { HttpsError } = require("firebase-functions/v2/https");

/** The 5 tiers, lowest authority first. */
const HB_TIERS = ["host", "agency", "admin", "superadmin", "owner"];

/** Privilege level per tier. Used for "may this tier manage that tier" checks. */
const HB_RANK = { host: 0, agency: 1, admin: 2, superadmin: 3, owner: 4 };

/**
 * Financial policy defaults - the single source of truth.
 * These were previously `|| 0.30` / `|| 1000000` fallbacks scattered across the
 * backend and hardcoded again in the admin panel, which is how a legitimate `0`
 * rate silently became 0.30.
 */
const DEFAULT_FINANCIAL_POLICIES = {
    agencyCommissionRate: 0.30,   // 30% of host recharge -> Agency USD wallet
    adminCommissionRate: 0.10,    // 10% of host recharge -> Admin USD wallet
    usdToDiamondRate: 1000000,   // 1 USD = 1,000,000 Diamonds
    minWithdrawalUSD: 10,        // floor below which a cashout is not worth the SLA
    // Weekly room-target salary: share of weeklyEarnings paid out. These were
    // hard-coded as `* 0.5` and `* 0.1` inside distributeWeeklySalary, so a rate
    // change needed a redeploy instead of an Owner edit.
    weeklySalaryRate: 0.5,
    agencySalaryShareRate: 0.1,
    supportedGateways: [
        "bKash", "Nagad", "Rocket", "Bank Transfer",
        "PayPal", "Wise", "Binance Pay", "USDT TRC20", "USDT BEP20"
    ]
};


/** Gateways accepted before the Owner has ever saved a policy document. */
const FALLBACK_GATEWAYS = DEFAULT_FINANCIAL_POLICIES.supportedGateways;

/**
 * Default salary slabs (bean milestones). Owner-overridable via
 * system_configs/financial_policies.salarySlabs.
 *
 * A "slab" is a bean threshold; crossing one for the first time pays out that
 * level exactly once. `completedLevels` in salaryStatus is what makes each slab
 * single-use, so an edit to a threshold only affects slabs not yet reached -
 * it can never retroactively double-pay an already-cleared level.
 */
const DEFAULT_SALARY_SLABS = [
    { level: 1, target: 1000000, label: "Lv.1 Beginner" },
    { level: 2, target: 2000000, label: "Lv.2 Rising Star" },
    { level: 3, target: 4000000, label: "Lv.3 Influencer" },
    { level: 4, target: 8000000, label: "Lv.4 Professional" },
    { level: 5, target: 15000000, label: "Lv.5 Elite" },
    { level: 6, target: 28000000, label: "Lv.6 Master" },
    { level: 7, target: 51000000, label: "Lv.7 Legend" },
    { level: 8, target: 87000000, label: "Lv.8 Mythic" },
    { level: 9, target: 141000000, label: "Lv.9 Immortal" },
    { level: 10, target: 209000000, label: "Lv.10 Ultimate" }
];

/**
 * Validate Owner-supplied salary slabs.
 * Refuses rather than clamps: a malformed slab set would silently reprice every
 * future payout, and a decreasing threshold would let one bean jump two levels.
 */
function validateSalarySlabs(slabs) {
    if (!Array.isArray(slabs) || slabs.length === 0) {
        throw new HttpsError("invalid-argument", "salarySlabs must be a non-empty array.");
    }
    let previous = 0;
    slabs.forEach((s, i) => {
        const level = Number(s.level);
        const target = Number(s.target);
        if (!Number.isInteger(level) || level < 1) {
            throw new HttpsError("invalid-argument", `Slab ${i}: level must be a positive integer.`);
        }
        if (!Number.isFinite(target) || target <= 0) {
            throw new HttpsError("invalid-argument", `Slab ${i}: target must be a positive number.`);
        }
        if (target <= previous) {
            throw new HttpsError("invalid-argument", `Slab ${i}: targets must strictly increase (got ${target} after ${previous}).`);
        }
        previous = target;
    });
}

/**
 * Collapse the redundant `role` field and the `tags` array into one tier.
 *
 * The codebase historically tested `role === 'x' || tags.includes('X')` in ~20
 * places with inconsistent coverage, so a role-only admin was invisible to some
 * checks while a stale SuperAdmin tag over-granted elsewhere.
 */
function normalizeTier(data) {
    if (!data) return "host";
    const tags = data.tags || [];
    if (data.role === "owner" || tags.includes("Owner")) return "owner";
    if (data.role === "superadmin" || tags.includes("SuperAdmin")) return "superadmin";
    if (data.role === "admin" || tags.includes("Admin")) return "admin";
    if (data.role === "agency" || data.isAgencyOwner === true || tags.includes("Agency")) return "agency";
    return "host";
}

/** Round to cents. Money must never enter a ledger with sub-cent precision. */
function round2(n) {
    return Math.round((Number(n) + Number.EPSILON) * 100) / 100;
}

/**
 * Reject nonsensical financial configuration. Throws HttpsError.
 *
 * `extra` carries the rate-shaped fields that must sit in [0, 1]. Fields left out
 * are skipped, so this stays backwards-compatible with the two-argument callers.
 */
function assertValidRates(agencyRate, adminRate, extra = {}) {
    for (const [label, v] of [["Agency", agencyRate], ["Admin", adminRate]]) {
        if (typeof v !== "number" || Number.isNaN(v)) {
            throw new HttpsError("invalid-argument", `${label} commission rate must be a number.`);
        }
        if (v < 0 || v > 1) {
            throw new HttpsError("invalid-argument", `${label} commission rate must be between 0 and 1 (got ${v}).`);
        }
    }
    if (agencyRate + adminRate > 1) {
        throw new HttpsError(
            "invalid-argument",
            `Agency + Admin commission cannot exceed 100% (got ${((agencyRate + adminRate) * 100).toFixed(2)}%).`
        );
    }

    for (const [label, v] of Object.entries(extra)) {
        if (v === undefined) continue;
        if (typeof v !== "number" || Number.isNaN(v) || v < 0 || v > 1) {
            throw new HttpsError("invalid-argument", `${label} must be a rate between 0 and 1 (got ${v}).`);
        }
    }
}

/**
 * Reject a nonsensical conversion rate. Separate from assertValidRates because
 * usdToDiamondRate is a magnitude (1 USD = 1,000,000 diamonds), not a fraction.
 */
function assertValidConversionRate(rate) {
    if (typeof rate !== "number" || !Number.isFinite(rate) || rate <= 0) {
        throw new HttpsError("invalid-argument", `usdToDiamondRate must be a positive number (got ${rate}).`);
    }
    if (rate > 1e12) {
        throw new HttpsError("invalid-argument", `usdToDiamondRate ${rate} is implausibly large.`);
    }
}

/** True when `callerTier` is permitted to act on `targetTier`. */
function canManageTier(callerTier, targetTier) {
    return HB_RANK[callerTier] > HB_RANK[targetTier];
}

/**
 * AUTOMATIC QUERY SANDBOXING.
 *
 * The Firestore constraint that confines a management query to the caller's
 * branch. Callers never supply the filter - the server derives it, which is what
 * prevents IDOR and horizontal data leakage.
 *
 *   Owner       -> null (global authority)
 *   Super Admin -> branchId == me  (own branch only, never a peer branch)
 *   Admin       -> adminId  == me  (my agencies + their hosts)
 *   Agency      -> agencyId == me  (my hosts)
 *   Host        -> __selfOnly      (personal rows only)
 */
function hierarchyScope(h) {
    switch (h.role) {
        case "owner":
            return null;
        case "superadmin":
            return h.branchId
                ? { field: "branchId", value: h.branchId }
                : { field: "__selfOnly", value: h.uid, reason: "no branch assigned" };
        case "admin":
            return { field: "adminId", value: h.uid };
        case "agency":
            return { field: "agencyId", value: h.uid };
        default:
            return { field: "__selfOnly", value: h.uid };
    }
}

/**
 * Is `target` inside `caller`'s hierarchy scope?
 *
 * Two independent conditions must both hold: the target must sit strictly below
 * the caller in rank, and it must actually be linked to the caller's branch.
 * Either alone is insufficient - the rank check alone would let a Super Admin
 * reach a peer branch's admin, and the link check alone would let an Admin
 * promote a Super Admin.
 */
function isTargetInScope(caller, target) {
    if (caller.role === "owner") return true;
    if (target.uid === caller.uid) return true;
    if (!canManageTier(caller.role, target.role)) return false;

    if (caller.role === "superadmin") {
        return !!caller.branchId && target.branchId === caller.branchId;
    }
    if (caller.role === "admin") {
        return target.adminId === caller.uid;
    }
    if (caller.role === "agency") {
        return target.agencyId === caller.uid;
    }
    return false; // hosts manage nobody
}

/** Does this host's hierarchy position qualify it for the salary system? */
function isSalaryEligible(userData) {
    // Spec: Super Admin is EXCLUDED from the salary system entirely.
    return normalizeTier(userData) !== "superadmin";
}

module.exports = {
    HB_TIERS,
    HB_RANK,
    DEFAULT_FINANCIAL_POLICIES,
    FALLBACK_GATEWAYS,
    DEFAULT_SALARY_SLABS,
    normalizeTier,
    round2,
    assertValidRates,
    assertValidConversionRate,
    validateSalarySlabs,
    canManageTier,
    hierarchyScope,
    isTargetInScope,
    isSalaryEligible
};
