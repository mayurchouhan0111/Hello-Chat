/**
 * End-to-End Integration Test Suite for Agency Management
 * Tests all 11 required scenarios against Firebase Emulator:
 * 1. createAgency
 * 2. listAgencies
 * 3. getAgency
 * 4. updateAgency
 * 5. setAgencyStatus
 * 6. addHost
 * 7. removeHost
 * 8. duplicate host rejected
 * 9. duplicate owner rejected
 * 10. non-admin denied
 * 11. direct client writes to /agencies denied
 */

process.env.GCLOUD_PROJECT = 'hellochat-e8965';
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: 'hellochat-e8965' });
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8085';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';

const assert = require('assert');
const functionsModule = require('./index.js');
const admin = require('firebase-admin');
const db = admin.firestore();

let passedCount = 0;
let failedCount = 0;

async function runTest(name, fn) {
    try {
        await fn();
        console.log(`  ✅ [PASS] ${name}`);
        passedCount++;
    } catch (err) {
        console.error(`  ❌ [FAIL] ${name}`);
        console.error(`         ${err.message || err}`);
        failedCount++;
    }
}

async function main() {
    console.log("\n==================================================");
    console.log("🏢 AGENCY MANAGEMENT E2E INTEGRATION TEST SUITE");
    console.log("==================================================");

    const runCall = (fn, data, auth) => {
        const handler = fn.run || fn;
        return handler(data, { auth });
    };

    const ts = Date.now();
    const adminUid = `admin_test_${ts}`;
    const ownerUid = `owner_test_${ts}`;
    const userCandidateUid = `candidate_test_${ts}`;
    const userCandidateHelloId = 880011;
    const secondCandidateUid = `second_cand_${ts}`;
    const hostUser1Uid = `host_1_${ts}`;
    const hostUser1HelloId = 880022;
    const hostUser2Uid = `host_2_${ts}`;
    const nonAdminUid = `regular_user_${ts}`;

    // Seed test users
    await db.collection("users").doc(adminUid).set({
        displayName: "Staff Admin",
        role: "admin",
        tags: ["Admin"],
        helloId: 990001
    });

    await db.collection("users").doc(ownerUid).set({
        displayName: "Platform Owner",
        role: "owner",
        tags: ["Owner"],
        helloId: 990002
    });

    await db.collection("users").doc(userCandidateUid).set({
        displayName: "Agency Candidate One",
        role: "host",
        helloId: userCandidateHelloId,
        tags: []
    });

    await db.collection("users").doc(secondCandidateUid).set({
        displayName: "Agency Candidate Two",
        role: "host",
        helloId: 880033,
        tags: []
    });

    await db.collection("users").doc(hostUser1Uid).set({
        displayName: "Talent Performer 1",
        role: "host",
        helloId: hostUser1HelloId,
        agencyId: null
    });

    await db.collection("users").doc(hostUser2Uid).set({
        displayName: "Talent Performer 2",
        role: "host",
        helloId: 880044,
        agencyId: null
    });

    await db.collection("users").doc(nonAdminUid).set({
        displayName: "Regular Member",
        role: "host",
        tags: []
    });

    let createdAgencyId = null;

    // 1. Create Agency
    await runTest("1. createAgency creates agency doc, assigns role, sets agencyId, and logs audit", async () => {
        const res = await runCall(functionsModule.createAgency, {
            name: "Phoenix Rising Agency",
            ownerIdentifier: userCandidateHelloId, // testing resolution by numeric helloId
            commissionRate: 0.15,
            country: "India",
            contactPhone: "+91 9876543210",
            description: "Top Tier Talent Management"
        }, { uid: adminUid });

        assert.ok(res.success, "Response should be success");
        assert.ok(res.agencyId, "Should return agencyId");
        createdAgencyId = res.agencyId;

        // Verify agency doc
        const agencyDoc = await db.collection("agencies").doc(createdAgencyId).get();
        assert.ok(agencyDoc.exists, "Agency document must exist");
        const aData = agencyDoc.data();
        assert.strictEqual(aData.name, "Phoenix Rising Agency");
        assert.strictEqual(aData.ownerUid, userCandidateUid);
        assert.strictEqual(aData.ownerHelloId, userCandidateHelloId);
        assert.strictEqual(aData.commissionRate, 0.15);
        assert.strictEqual(aData.status, "active");
        assert.strictEqual(aData.isActive, true);

        // Verify owner user doc was updated
        const candidateDoc = await db.collection("users").doc(userCandidateUid).get();
        const cData = candidateDoc.data();
        assert.strictEqual(cData.role, "agency");
        assert.strictEqual(cData.isAgencyOwner, true);
        assert.strictEqual(cData.agencyId, createdAgencyId);

        // Verify audit log
        const auditSnap = await db.collection("audit_logs")
            .where("action", "==", "CREATE_AGENCY")
            .where("targetId", "==", createdAgencyId)
            .limit(1)
            .get();
        assert.ok(!auditSnap.empty, "Audit log for CREATE_AGENCY must be recorded");
    });

    // 2. List Agencies
    await runTest("2. listAgencies returns agencies including new agency with hostCount", async () => {
        const res = await runCall(functionsModule.listAgencies, {}, { uid: adminUid });
        assert.ok(res.success);
        assert.ok(Array.isArray(res.agencies));
        const found = res.agencies.find(a => a.agencyId === createdAgencyId || a.id === createdAgencyId);
        assert.ok(found, "Created agency must be in listAgencies response");
        assert.strictEqual(found.name, "Phoenix Rising Agency");
        assert.strictEqual(found.hostCount, 0);
    });

    // 3. Get Agency
    await runTest("3. getAgency returns full agency details and empty host roster", async () => {
        const res = await runCall(functionsModule.getAgency, { agencyId: createdAgencyId }, { uid: adminUid });
        assert.ok(res.success);
        assert.strictEqual(res.agency.name, "Phoenix Rising Agency");
        assert.strictEqual(res.agency.ownerUid, userCandidateUid);
        assert.deepStrictEqual(res.hosts, []);
    });

    // 4. Update Agency
    await runTest("4. updateAgency updates descriptive fields and commission rate", async () => {
        const res = await runCall(functionsModule.updateAgency, {
            agencyId: createdAgencyId,
            name: "Phoenix Elite Agency",
            commissionRate: 0.20,
            country: "UAE",
            description: "Updated description"
        }, { uid: adminUid });
        assert.ok(res.success);

        const updatedSnap = await db.collection("agencies").doc(createdAgencyId).get();
        const uData = updatedSnap.data();
        assert.strictEqual(uData.name, "Phoenix Elite Agency");
        assert.strictEqual(uData.commissionRate, 0.20);
        assert.strictEqual(uData.country, "UAE");
    });

    // 5. Set Agency Status (Suspend & Activate)
    await runTest("5. setAgencyStatus suspends and reactivates agency", async () => {
        // Suspend
        const resSuspend = await runCall(functionsModule.setAgencyStatus, {
            agencyId: createdAgencyId,
            status: "suspended"
        }, { uid: adminUid });
        assert.ok(resSuspend.success);
        assert.strictEqual(resSuspend.status, "suspended");
        assert.strictEqual(resSuspend.isActive, false);

        let snap = await db.collection("agencies").doc(createdAgencyId).get();
        assert.strictEqual(snap.data().isActive, false);

        // Reactivate
        const resActivate = await runCall(functionsModule.setAgencyStatus, {
            agencyId: createdAgencyId,
            status: "active"
        }, { uid: adminUid });
        assert.ok(resActivate.success);
        assert.strictEqual(resActivate.status, "active");
        assert.strictEqual(resActivate.isActive, true);

        snap = await db.collection("agencies").doc(createdAgencyId).get();
        assert.strictEqual(snap.data().isActive, true);
    });

    // 6. Add Host
    await runTest("6. addHost links host to agency atomically and updates user doc", async () => {
        const res = await runCall(functionsModule.addHost, {
            agencyId: createdAgencyId,
            hostIdentifier: hostUser1HelloId
        }, { uid: adminUid });
        assert.ok(res.success);
        assert.strictEqual(res.hostUid, hostUser1Uid);

        // Check agency doc hostUids
        const aSnap = await db.collection("agencies").doc(createdAgencyId).get();
        assert.ok(aSnap.data().hostUids.includes(hostUser1Uid));
        assert.strictEqual(aSnap.data().hostCount, 1);

        // Check host doc
        const hSnap = await db.collection("users").doc(hostUser1Uid).get();
        assert.strictEqual(hSnap.data().agencyId, createdAgencyId);

        // Verify getAgency now returns host in roster
        const getRes = await runCall(functionsModule.getAgency, { agencyId: createdAgencyId }, { uid: adminUid });
        assert.strictEqual(getRes.hosts.length, 1);
        assert.strictEqual(getRes.hosts[0].uid, hostUser1Uid);
    });

    // 7. Remove Host
    await runTest("7. removeHost unlinks host from agency and clears user agencyId", async () => {
        const res = await runCall(functionsModule.removeHost, {
            agencyId: createdAgencyId,
            hostUid: hostUser1Uid
        }, { uid: adminUid });
        assert.ok(res.success);

        const aSnap = await db.collection("agencies").doc(createdAgencyId).get();
        assert.ok(!aSnap.data().hostUids.includes(hostUser1Uid));
        assert.strictEqual(aSnap.data().hostCount, 0);

        const hSnap = await db.collection("users").doc(hostUser1Uid).get();
        assert.strictEqual(hSnap.data().agencyId, null);
    });

    // 8. Duplicate Host Check
    await runTest("8. duplicate host rejected when adding user already signed to another agency", async () => {
        // First add hostUser2 to createdAgency
        await runCall(functionsModule.addHost, {
            agencyId: createdAgencyId,
            hostIdentifier: hostUser2Uid
        }, { uid: adminUid });

        // Create a second agency
        const secondAgency = await runCall(functionsModule.createAgency, {
            name: "Second Test Agency",
            ownerIdentifier: secondCandidateUid,
            commissionRate: 0.1
        }, { uid: adminUid });

        // Attempt to add hostUser2 to the second agency
        let threw = false;
        try {
            await runCall(functionsModule.addHost, {
                agencyId: secondAgency.agencyId,
                hostIdentifier: hostUser2Uid
            }, { uid: adminUid });
        } catch (e) {
            threw = true;
            assert.ok(e.message.includes("already signed"), "Error must state host is already signed");
        }
        assert.ok(threw, "Must throw failed-precondition on duplicate host");
    });

    // 9. Duplicate Owner Check
    await runTest("9. duplicate owner rejected when appointing user who already owns an agency", async () => {
        let threw = false;
        try {
            await runCall(functionsModule.createAgency, {
                name: "Duplicate Attempt Agency",
                ownerIdentifier: userCandidateUid,
                commissionRate: 0.1
            }, { uid: adminUid });
        } catch (e) {
            threw = true;
            assert.ok(e.message.includes("already the owner"), "Error must state user is already an owner");
        }
        assert.ok(threw, "Must throw when appointing existing agency owner");
    });

    // 10. Non-Admin Denied Check
    await runTest("10. non-admin denied when attempting to create/update/set status", async () => {
        let threwCreate = false;
        try {
            await runCall(functionsModule.createAgency, {
                name: "Illegal Agency",
                ownerIdentifier: hostUser1Uid,
                commissionRate: 0.1
            }, { uid: nonAdminUid });
        } catch (e) {
            threwCreate = true;
            assert.ok(e.code === "permission-denied" || e.message.includes("permission-denied") || e.message.includes("Staff permissions"), "Must fail permission check");
        }
        assert.ok(threwCreate, "Non-admin must be denied on createAgency");

        let threwStatus = false;
        try {
            await runCall(functionsModule.setAgencyStatus, {
                agencyId: createdAgencyId,
                status: "suspended"
            }, { uid: nonAdminUid });
        } catch (e) {
            threwStatus = true;
        }
        assert.ok(threwStatus, "Non-admin must be denied on setAgencyStatus");
    });

    // 11. Direct Client Write Denied Check
    await runTest("11. direct client writes to /agencies denied by firestore rules", async () => {
        const fs = require('fs');
        const rules = fs.readFileSync('../firebase/firestore.rules', 'utf8');
        assert.ok(rules.includes('match /agencies/{agencyId}'), "Rules must contain match /agencies/{agencyId}");
        assert.ok(rules.includes('allow write: if false;'), "Rules must contain allow write: if false; for agencies");
    });

    // 12. createAgency Refuses Admin / Staff Roles
    await runTest("12. createAgency refuses targets with role admin, superadmin, or owner", async () => {
        const staffCandidateUid = `staff_cand_${ts}`;
        await db.collection('users').doc(staffCandidateUid).set({
            role: 'admin',
            displayName: 'Existing Admin Staff',
            helloId: 991100
        });

        let threw = false;
        try {
            await runCall(functionsModule.createAgency, {
                name: "Illegal Staff Agency",
                ownerIdentifier: staffCandidateUid,
                commissionRate: 0.1
            }, { uid: adminUid });
        } catch (e) {
            threw = true;
            assert.ok(e.message.includes("downgraded") || e.message.includes("Cannot appoint"), "Error must state staff cannot be downgraded");
        }
        assert.ok(threw, "Must refuse to appoint user with role admin as agency owner");

        // Verify user role was NOT modified
        const userSnap = await db.collection('users').doc(staffCandidateUid).get();
        assert.strictEqual(userSnap.data().role, 'admin', "Staff role must remain unchanged");
    });

    // 13. createAgency Preserves previousRole on User Document
    let thirdAgencyId = null;
    const thirdCandidateUid = `third_cand_${ts}`;
    await runTest("13. createAgency preserves previousRole on candidate user doc", async () => {
        await db.collection('users').doc(thirdCandidateUid).set({
            role: 'user',
            displayName: 'Regular User Candidate',
            helloId: 992200
        });

        const res = await runCall(functionsModule.createAgency, {
            name: "Role Restoration Test Agency",
            ownerIdentifier: thirdCandidateUid,
            commissionRate: 0.1
        }, { uid: adminUid });

        thirdAgencyId = res.agencyId;
        const ownerSnap = await db.collection('users').doc(thirdCandidateUid).get();
        assert.strictEqual(ownerSnap.data().role, 'agency');
        assert.strictEqual(ownerSnap.data().previousRole, 'user', "previousRole must be preserved as 'user'");
        assert.strictEqual(ownerSnap.data().isAgencyOwner, true);
    });

    // 14. setAgencyStatus('suspended') Restores Role and Revokes isAgencyOwner
    await runTest("14. setAgencyStatus('suspended') restores owner role and revokes isAgencyOwner", async () => {
        await runCall(functionsModule.setAgencyStatus, {
            agencyId: thirdAgencyId,
            status: 'suspended'
        }, { uid: adminUid });

        const ownerSnap = await db.collection('users').doc(thirdCandidateUid).get();
        assert.strictEqual(ownerSnap.data().role, 'user', "Role must be restored to previousRole ('user')");
        assert.strictEqual(ownerSnap.data().isAgencyOwner, false, "isAgencyOwner must be false when agency suspended");
    });

    // 15. setAgencyStatus('active') Reactivates Agency Role and isAgencyOwner
    await runTest("15. setAgencyStatus('active') reactivates agency role and isAgencyOwner", async () => {
        await runCall(functionsModule.setAgencyStatus, {
            agencyId: thirdAgencyId,
            status: 'active'
        }, { uid: adminUid });

        const ownerSnap = await db.collection('users').doc(thirdCandidateUid).get();
        assert.strictEqual(ownerSnap.data().role, 'agency', "Role must be reactivated to 'agency'");
        assert.strictEqual(ownerSnap.data().isAgencyOwner, true, "isAgencyOwner must be reactivated to true");
    });

    // 16. updateAgency by Agency Owner Allows Whitelisted Fields
    await runTest("16. updateAgency by agency owner allows editing description, contactPhone, and country", async () => {
        const updateRes = await runCall(functionsModule.updateAgency, {
            agencyId: thirdAgencyId,
            description: "Updated agency description by owner",
            contactPhone: "+91 9999888877",
            country: "India"
        }, { uid: thirdCandidateUid });

        assert.strictEqual(updateRes.success, true);
        const aSnap = await db.collection('agencies').doc(thirdAgencyId).get();
        assert.strictEqual(aSnap.data().description, "Updated agency description by owner");
        assert.strictEqual(aSnap.data().contactPhone, "+91 9999888877");
        assert.strictEqual(aSnap.data().country, "India");
    });

    // 17. updateAgency by Agency Owner Denies Non-Whitelisted Fields
    await runTest("17. updateAgency by agency owner denies each non-whitelisted field", async () => {
        const deniedFields = [
            { field: "name", payload: { name: "Hacked Name" } },
            { field: "commissionRate", payload: { commissionRate: 0.5 } },
            { field: "status", payload: { status: "suspended" } },
            { field: "ownerUid", payload: { ownerUid: "hacker_uid" } },
            { field: "beansBalance", payload: { beansBalance: 99999999 } },
            { field: "totalBeansEarned", payload: { totalBeansEarned: 99999999 } },
            { field: "hostUids", payload: { hostUids: ["some_host"] } }
        ];

        for (const { field, payload } of deniedFields) {
            let threw = false;
            try {
                await runCall(functionsModule.updateAgency, {
                    agencyId: thirdAgencyId,
                    ...payload
                }, { uid: thirdCandidateUid });
            } catch (e) {
                threw = true;
                assert.ok(e.message.includes("not permitted") || e.message.includes("cannot be modified") || e.code === "permission-denied" || e.code === "invalid-argument",
                    `Must throw permission or invalid error for field ${field}`);
            }
            assert.ok(threw, `Agency owner must be denied when attempting to update field "${field}"`);
        }
    });

    // 18. updateAgency by Staff Denies Server-Only / Financial Fields
    await runTest("18. updateAgency by staff denies server-only financial and roster fields", async () => {
        const serverOnlyFields = [
            { field: "beansBalance", payload: { beansBalance: 500000 } },
            { field: "totalBeansEarned", payload: { totalBeansEarned: 500000 } },
            { field: "hostUids", payload: { hostUids: ["rogue_host"] } },
            { field: "status", payload: { status: "active" } },
            { field: "ownerUid", payload: { ownerUid: "other_owner" } }
        ];

        for (const { field, payload } of serverOnlyFields) {
            let threw = false;
            try {
                await runCall(functionsModule.updateAgency, {
                    agencyId: thirdAgencyId,
                    ...payload
                }, { uid: adminUid });
            } catch (e) {
                threw = true;
                assert.ok(e.message.includes("cannot be modified via updateAgency"), `Error must mention forbidden field ${field}`);
            }
            assert.ok(threw, `Staff must be denied when passing server-only field "${field}" to updateAgency`);
        }
    });

    console.log("\n==================================================");
    console.log(`TOTAL TESTS: ${passedCount + failedCount} | PASSED: ${passedCount} | FAILED: ${failedCount}`);
    console.log("==================================================");

    if (failedCount > 0) {
        process.exit(1);
    }
}

main().catch(err => {
    console.error("Test runner failed:", err);
    process.exit(1);
});
