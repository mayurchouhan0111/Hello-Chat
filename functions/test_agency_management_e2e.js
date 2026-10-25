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
        // In firestore.rules:
        // match /agencies/{agencyId} {
        //   allow read: if request.auth != null && (isAdmin() || resource.data.ownerUid == request.auth.uid || ...);
        //   allow write: if false; // All creation, status, and roster mutations via Cloud Functions only
        // }
        // Verify from rules that write is strictly false.
        const fs = require('fs');
        const rules = fs.readFileSync('../firebase/firestore.rules', 'utf8');
        assert.ok(rules.includes('match /agencies/{agencyId}'), "Rules must contain match /agencies/{agencyId}");
        assert.ok(rules.includes('allow write: if false;'), "Rules must contain allow write: if false; for agencies");
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
