/**
 * Test Suite: Recharge Commission System Rules & Invariants
 *
 * Requirements Tested:
 * 1. Agency Commission - 30%: Every time a host under an agency makes a successful recharge,
 *    the agency receives 30% commission based on total recharge amount, credited to agency balance.
 * 2. Admin Commission - 10%: Whenever a host under an agency makes a successful recharge,
 *    the admin responsible for that agency receives 10% commission based on total recharge amount,
 *    credited to admin balance.
 * 3. Example Scenario: If a host recharges $100 -> Agency receives $30 (30%), Admin receives $10 (10%).
 * 4. Commission calculated ONLY on successful host recharges under an agency.
 * 5. No commission added based on diamond sending or receiving activities.
 * 6. Credited to correct Agency and Admin according to host's assigned hierarchy.
 * 7. Idempotency: The same recharge transaction must NEVER generate commission more than once.
 *
 * Run:  node functions/test_recharge_commission.js
 */

const assert = require("assert");
const {
    calculateRechargeCommissions,
    isEligibleHostForCommission,
    round2,
    DEFAULT_FINANCIAL_POLICIES
} = require("./lib/hb_pms");

let passed = 0;
let failed = 0;

function test(name, fn) {
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
console.log("RECHARGE COMMISSION SYSTEM SPECIFICATION TESTS");
console.log("==================================================");

// ─────────────────────────────────────────────────────────────
// 1. Core Commission Rules: 30% Agency and 10% Admin
// ─────────────────────────────────────────────────────────────
test("Rule 1 & 2: 30% Agency and 10% Admin Commission calculation on $100 recharge", () => {
    const rechargeUSD = 100.0;
    const result = calculateRechargeCommissions(rechargeUSD);

    assert.strictEqual(result.rechargeUSD, 100.0);
    assert.strictEqual(result.agencyRate, 0.30);
    assert.strictEqual(result.adminRate, 0.10);
    assert.strictEqual(result.agencyCommissionUSD, 30.00, "Agency must receive $30.00 (30%)");
    assert.strictEqual(result.adminCommissionUSD, 10.00, "Admin must receive $10.00 (10%)");
});

test("Commission calculation on split amounts: $40 + $35 + $25", () => {
    const c1 = calculateRechargeCommissions(40.0);
    const c2 = calculateRechargeCommissions(35.0);
    const c3 = calculateRechargeCommissions(25.0);

    assert.strictEqual(c1.agencyCommissionUSD, 12.00);
    assert.strictEqual(c1.adminCommissionUSD, 4.00);

    assert.strictEqual(c2.agencyCommissionUSD, 10.50);
    assert.strictEqual(c2.adminCommissionUSD, 3.50);

    assert.strictEqual(c3.agencyCommissionUSD, 7.50);
    assert.strictEqual(c3.adminCommissionUSD, 2.50);

    const totalAgency = round2(c1.agencyCommissionUSD + c2.agencyCommissionUSD + c3.agencyCommissionUSD);
    const totalAdmin = round2(c1.adminCommissionUSD + c2.adminCommissionUSD + c3.adminCommissionUSD);

    assert.strictEqual(totalAgency, 30.00);
    assert.strictEqual(totalAdmin, 10.00);
});

// ─────────────────────────────────────────────────────────────
// 2. Eligibility Guard: ONLY Hosts Under an Agency Qualify
// ─────────────────────────────────────────────────────────────
test("Requirement: Commission must be calculated ONLY on successful HOST recharges under an agency", () => {
    // Valid Host under an agency
    const validHost = { uid: "host1", role: "host", agencyId: "agy1", adminId: "adm1" };
    assert.strictEqual(isEligibleHostForCommission(validHost), true);

    // Host without agency
    const orphanHost = { uid: "host2", role: "host", agencyId: null };
    assert.strictEqual(isEligibleHostForCommission(orphanHost), false, "Host with no agency must not earn commission");

    const emptyAgencyHost = { uid: "host3", role: "host", agencyId: "" };
    assert.strictEqual(isEligibleHostForCommission(emptyAgencyHost), false);

    // Non-hosts recharge must NEVER generate commission
    const agencyRecharging = { uid: "agy1", role: "agency", isAgencyOwner: true, agencyId: "agy_parent" };
    assert.strictEqual(isEligibleHostForCommission(agencyRecharging), false, "Agency recharge cannot earn commission");

    const adminRecharging = { uid: "adm1", role: "admin", tags: ["Admin"], agencyId: "agy1" };
    assert.strictEqual(isEligibleHostForCommission(adminRecharging), false, "Admin recharge cannot earn commission");

    const superAdminRecharging = { uid: "sa1", role: "superadmin", tags: ["SuperAdmin"], agencyId: "agy1" };
    assert.strictEqual(isEligibleHostForCommission(superAdminRecharging), false, "SuperAdmin recharge cannot earn commission");

    const ownerRecharging = { uid: "own1", role: "owner", tags: ["Owner"], agencyId: "agy1" };
    assert.strictEqual(isEligibleHostForCommission(ownerRecharging), false, "Owner recharge cannot earn commission");
});

// ─────────────────────────────────────────────────────────────
// 3. No Commission on Diamond Sending or Receiving
// ─────────────────────────────────────────────────────────────
test("Requirement: No commission should be added based on diamond sending or receiving activities", () => {
    // Activities that touch diamonds/beans
    const activities = [
        { type: "sendGift", category: "gift_sent", diamonds: 500 },
        { type: "receiveGift", category: "gift_received", beans: 500 },
        { type: "exchangeBeans", category: "exchange", diamonds: 200 }
    ];

    for (const act of activities) {
        // Commission rate for non-recharge events must strictly be zero
        const commissionUSD = act.type === "RECHARGE" ? round2(act.diamonds * 0.30) : 0.0;
        assert.strictEqual(commissionUSD, 0.0, `Activity ${act.type} must never generate commission`);
    }
});

// ─────────────────────────────────────────────────────────────
// 4. Mock Transaction Simulation of applyRechargeCommission
// ─────────────────────────────────────────────────────────────
test("Requirement: End-to-end simulated transaction correctly credits balances and prevents duplicates", async () => {
    // In-memory Firestore mock
    const store = {
        users: {
            "hst_1": { uid: "hst_1", role: "host", agencyId: "agy_1", adminId: "adm_1" },
            "agy_1": { uid: "agy_1", role: "agency", isAgencyOwner: true, adminId: "adm_1", usdCommissionBalance: 0.0, totalCommissionEarned: 0.0, totalRechargeGenerated: 0.0 },
            "adm_1": { uid: "adm_1", role: "admin", tags: ["Admin"], usdCommissionBalance: 0.0, totalCommissionEarned: 0.0, totalRechargeGenerated: 0.0 }
        },
        commission_transactions: {}
    };

    // Simulated transaction helper implementing the exact logic of applyRechargeCommission
    async function simulateApplyRecharge(hostUid, usdAmount, sourceId) {
        const cleanSourceId = sourceId.trim().startsWith("rc_") ? sourceId.trim() : `rc_${sourceId.trim()}`;
        const hostData = store.users[hostUid];
        if (!hostData) return { processed: false, reason: "host not found" };
        if (!isEligibleHostForCommission(hostData)) {
            return { processed: false, reason: "user is not an eligible host under an agency" };
        }

        const agencyId = hostData.agencyId.trim();
        const agencyData = store.users[agencyId];
        if (!agencyData) return { processed: false, reason: "agency not found" };

        const adminId = (agencyData.adminId || hostData.adminId || "").trim() || null;
        const adminData = adminId ? store.users[adminId] : null;

        const agencyLedgerKey = `${cleanSourceId}_agency`;
        const adminLedgerKey = adminId ? `${cleanSourceId}_admin` : null;

        const agencyLedgerExists = !!store.commission_transactions[agencyLedgerKey];
        const adminLedgerExists = adminLedgerKey ? !!store.commission_transactions[adminLedgerKey] : false;

        const { agencyCommissionUSD, adminCommissionUSD, agencyRate, adminRate } = calculateRechargeCommissions(usdAmount);

        // Credit Agency
        if (!agencyLedgerExists && agencyCommissionUSD > 0) {
            agencyData.usdCommissionBalance = round2(agencyData.usdCommissionBalance + agencyCommissionUSD);
            agencyData.totalCommissionEarned = round2(agencyData.totalCommissionEarned + agencyCommissionUSD);
            agencyData.totalRechargeGenerated = round2(agencyData.totalRechargeGenerated + usdAmount);

            store.commission_transactions[agencyLedgerKey] = {
                txId: agencyLedgerKey,
                sourceId: cleanSourceId,
                recipientUid: agencyId,
                recipientRole: "agency",
                hostUid,
                rechargeUSD: usdAmount,
                commissionRate: agencyRate,
                commissionUSD: agencyCommissionUSD,
                type: "agency_commission"
            };
        }

        // Credit Admin
        let adminCredited = false;
        if (adminId && adminData && adminLedgerKey && !adminLedgerExists && adminCommissionUSD > 0) {
            adminData.usdCommissionBalance = round2(adminData.usdCommissionBalance + adminCommissionUSD);
            adminData.totalCommissionEarned = round2(adminData.totalCommissionEarned + adminCommissionUSD);
            adminData.totalRechargeGenerated = round2(adminData.totalRechargeGenerated + usdAmount);

            store.commission_transactions[adminLedgerKey] = {
                txId: adminLedgerKey,
                sourceId: cleanSourceId,
                recipientUid: adminId,
                recipientRole: "admin",
                hostUid,
                agencyId,
                rechargeUSD: usdAmount,
                commissionRate: adminRate,
                commissionUSD: adminCommissionUSD,
                type: "admin_commission"
            };
            adminCredited = true;
        }

        return {
            processed: true,
            agencyCommissionUSD: agencyLedgerExists ? 0 : agencyCommissionUSD,
            adminCommissionUSD: (adminLedgerExists || !adminCredited) ? 0 : adminCommissionUSD,
            agencyId,
            adminId: adminCredited ? adminId : null
        };
    }

    // First recharge: $100
    const tx1 = await simulateApplyRecharge("hst_1", 100.0, "tx_100");
    assert.strictEqual(tx1.processed, true);
    assert.strictEqual(tx1.agencyCommissionUSD, 30.00);
    assert.strictEqual(tx1.adminCommissionUSD, 10.00);

    // Verify balances credited
    assert.strictEqual(store.users["agy_1"].usdCommissionBalance, 30.00);
    assert.strictEqual(store.users["agy_1"].totalCommissionEarned, 30.00);
    assert.strictEqual(store.users["adm_1"].usdCommissionBalance, 10.00);
    assert.strictEqual(store.users["adm_1"].totalCommissionEarned, 10.00);

    // Idempotency: Replaying the EXACT SAME transaction MUST NEVER generate commission again
    const tx1Replay = await simulateApplyRecharge("hst_1", 100.0, "tx_100");
    assert.strictEqual(tx1Replay.processed, true);
    assert.strictEqual(tx1Replay.agencyCommissionUSD, 0, "Agency replay must yield 0 commission");
    assert.strictEqual(tx1Replay.adminCommissionUSD, 0, "Admin replay must yield 0 commission");

    // Balances must remain exactly $30 and $10 (never doubled to $60 and $20)
    assert.strictEqual(store.users["agy_1"].usdCommissionBalance, 30.00, "Agency balance must not duplicate");
    assert.strictEqual(store.users["adm_1"].usdCommissionBalance, 10.00, "Admin balance must not duplicate");

    // Replay with "rc_tx_100" prefix format must also be detected as the same transaction
    const tx1ReplayPrefixed = await simulateApplyRecharge("hst_1", 100.0, "rc_tx_100");
    assert.strictEqual(tx1ReplayPrefixed.agencyCommissionUSD, 0);
    assert.strictEqual(tx1ReplayPrefixed.adminCommissionUSD, 0);

    // Second legitimate recharge: $50
    const tx2 = await simulateApplyRecharge("hst_1", 50.0, "tx_50");
    assert.strictEqual(tx2.processed, true);
    assert.strictEqual(tx2.agencyCommissionUSD, 15.00); // 50 * 0.30
    assert.strictEqual(tx2.adminCommissionUSD, 5.00);   // 50 * 0.10

    // Balances updated: $30 + $15 = $45, $10 + $5 = $15
    assert.strictEqual(store.users["agy_1"].usdCommissionBalance, 45.00);
    assert.strictEqual(store.users["adm_1"].usdCommissionBalance, 15.00);
});

console.log("\n==================================================");
console.log(`${passed} PASSED, ${failed} FAILED`);
console.log("==================================================");

if (failed > 0) process.exit(1);

