/**
 * Firestore rules tests for canonical users.agencyId document IDs.
 *
 * Run against the emulator:
 *   firebase emulators:exec --only firestore "node functions/test_agency_id_rules.js"
 */

const fs = require("fs");
const path = require("path");
const {
    initializeTestEnvironment,
    assertFails,
    assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
    doc,
    getDoc,
    setDoc,
    collection,
    query,
    where,
    getDocs,
} = require("firebase/firestore");

let passedCount = 0;
let failedCount = 0;

async function runTest(name, fn) {
    try {
        await fn();
        console.log(`  [PASS] ${name}`);
        passedCount++;
    } catch (err) {
        console.error(`  [FAIL] ${name}`);
        console.error(`         ${err.message || err}`);
        failedCount++;
    }
}

async function main() {
    const emulator = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8085";
    const [host, port] = emulator.split(":");
    const testEnv = await initializeTestEnvironment({
        projectId: "hellochat-e8965",
        firestore: {
            host,
            port: Number(port),
            rules: fs.readFileSync(path.join(__dirname, "..", "firebase", "firestore.rules"), "utf8"),
        },
    });

    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await setDoc(doc(db, "users", "agencyA"), {
            role: "agency",
            isAgencyOwner: true,
            agencyId: "agencyDocA",
        });
        await setDoc(doc(db, "users", "hostA"), {
            role: "host",
            agencyId: "agencyDocA",
        });
        await setDoc(doc(db, "users", "agencyB"), {
            role: "agency",
            isAgencyOwner: true,
            agencyId: "agencyDocB",
        });
        await setDoc(doc(db, "users", "hostB"), {
            role: "host",
            agencyId: "agencyDocB",
        });
        await setDoc(doc(db, "users", "normalUser"), {
            role: "user",
        });

        // Backward-compatibility fixtures for the existing client surfaces.
        await setDoc(doc(db, "agencies", "agencyDocA"), {
            ownerUid: "agencyA",
            name: "Agency A",
            usdCommissionBalance: 12.34,
            totalCommissionEarned: 12.34,
        });
        await setDoc(doc(db, "agencies", "agencyDocB"), {
            ownerUid: "agencyB",
            name: "Agency B",
            usdCommissionBalance: 99.99,
        });
        await setDoc(doc(db, "gifts", "gift1"), { name: "Rose", price: 10 });
        await setDoc(doc(db, "rooms", "room1"), { ownerUid: "agencyA", admins: [] });
        await setDoc(doc(db, "host_metrics", "hostA"), { agencyId: "agencyDocA" });
        await setDoc(doc(db, "host_metrics", "hostB"), { agencyId: "agencyDocB" });
        await setDoc(doc(db, "host_metrics", "normalUser"), { agencyId: null });
        await setDoc(doc(db, "users", "normalUser", "transactions", "tx1"), { amount: 10 });
        await setDoc(doc(db, "users", "hostB", "transactions", "tx1"), { amount: 10 });
        await setDoc(doc(db, "users", "normalUser", "salary_history", "s1"), { amount: 1 });
        await setDoc(doc(db, "users", "hostB", "salary_history", "s1"), { amount: 1 });
        await setDoc(doc(db, "commission_transactions", "txA"), { recipientUid: "agencyA" });
        await setDoc(doc(db, "commission_withdrawals", "w1"), { userId: "normalUser", status: "pending" });
    });

    const agencyDb = testEnv.authenticatedContext("agencyA").firestore();
    const normalDb = testEnv.authenticatedContext("normalUser").firestore();

    await runTest("agency can get its own host", async () => {
        await assertSucceeds(getDoc(doc(agencyDb, "users", "hostA")));
    });

    await runTest("agency cannot get a cross-agency host", async () => {
        await assertFails(getDoc(doc(agencyDb, "users", "hostB")));
    });

    await runTest("agency can list only its own agencyId", async () => {
        await assertSucceeds(getDocs(query(collection(agencyDb, "users"), where("agencyId", "==", "agencyDocA"))));
        await assertFails(getDocs(query(collection(agencyDb, "users"), where("agencyId", "==", "agencyDocB"))));
    });

    await runTest("normal user cannot self-assign agencyId", async () => {
        await assertFails(setDoc(doc(normalDb, "users", "normalUser"), {
            agencyId: "agencyDocA",
        }, { merge: true }));
    });

    await runTest("normal user can still update a non-protected field", async () => {
        await assertSucceeds(setDoc(doc(normalDb, "users", "normalUser"), {
            bio: "still allowed",
        }, { merge: true }));
    });

    await runTest("normal user can read own profile and wallet transaction", async () => {
        await assertSucceeds(getDoc(doc(normalDb, "users", "normalUser")));
        await assertSucceeds(getDoc(doc(normalDb, "users", "normalUser", "transactions", "tx1")));
        await assertFails(getDoc(doc(normalDb, "users", "hostB", "transactions", "tx1")));
    });

    await runTest("gift catalog stays readable by normal users", async () => {
        await assertSucceeds(getDoc(doc(normalDb, "gifts", "gift1")));
    });

    await runTest("room read, room create, participant and message flows still work", async () => {
        await assertSucceeds(getDoc(doc(normalDb, "rooms", "room1")));
        await assertSucceeds(setDoc(doc(normalDb, "rooms", "room2"), { ownerUid: "normalUser" }));
        await assertSucceeds(setDoc(doc(normalDb, "rooms", "room1", "participants", "normalUser"), { seatIndex: 1 }));
        await assertFails(setDoc(doc(normalDb, "rooms", "room1", "participants", "normalUser"), { seatIndex: 0 }));
        await assertSucceeds(setDoc(doc(normalDb, "rooms", "room1", "messages", "m1"), { uid: "normalUser", text: "hi" }));
    });

    await runTest("salary history remains self-only", async () => {
        await assertSucceeds(getDoc(doc(normalDb, "users", "normalUser", "salary_history", "s1")));
        await assertFails(getDoc(doc(normalDb, "users", "hostB", "salary_history", "s1")));
    });

    await runTest("host metrics follow hierarchy scope", async () => {
        await assertSucceeds(getDoc(doc(normalDb, "host_metrics", "normalUser")));
        await assertSucceeds(getDoc(doc(agencyDb, "host_metrics", "hostA")));
        await assertFails(getDoc(doc(agencyDb, "host_metrics", "hostB")));
    });

    await runTest("agency portal can read/update its own descriptive fields", async () => {
        await assertSucceeds(getDoc(doc(agencyDb, "agencies", "agencyDocA")));
        await assertFails(getDoc(doc(agencyDb, "agencies", "agencyDocB")));
        await assertSucceeds(setDoc(doc(agencyDb, "agencies", "agencyDocA"), {
            description: "updated by owner",
        }, { merge: true }));
        await assertFails(setDoc(doc(agencyDb, "agencies", "agencyDocA"), {
            usdCommissionBalance: 999999,
        }, { merge: true }));
    });

    await runTest("agency commission ledger is readable by its owner only", async () => {
        await assertSucceeds(getDoc(doc(agencyDb, "commission_transactions", "txA")));
        await assertFails(getDoc(doc(normalDb, "commission_transactions", "txA")));
    });

    await runTest("withdrawal requester can read own request only", async () => {
        await assertSucceeds(getDoc(doc(normalDb, "commission_withdrawals", "w1")));
        await assertFails(getDoc(doc(agencyDb, "commission_withdrawals", "w1")));
    });

    await testEnv.cleanup();

    console.log("\n==================================================");
    console.log(`TOTAL TESTS: ${passedCount + failedCount} | PASSED: ${passedCount} | FAILED: ${failedCount}`);
    console.log("==================================================");

    if (failedCount > 0) process.exit(1);
}

main().catch((err) => {
    console.error("Rules test runner failed:", err);
    process.exit(1);
});
