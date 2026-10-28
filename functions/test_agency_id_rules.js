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
