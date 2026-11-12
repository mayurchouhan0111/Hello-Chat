/**
 * Automated Test Suite: Payment Gateway (Revision 2 Specifications)
 * Tests all key edge cases from docs/Project Documentation.md:
 * - Single idempotent credit path: creditOrderIfPaid
 * - Double credit prevention & processed_payments deduplication
 * - Idempotency key reuse on createOrder
 * - Amount / currency tampering rejection
 * - HMAC SHA256 signature verification
 */

const assert = require("assert");
const crypto = require("crypto");
const { PaymentGatewayEngine, DEFAULT_RECHARGE_PACKAGES } = require("./lib/payment_gateway");

// In-Memory Mock Firestore Database for Fast, Isolated Unit Testing
class MockDocumentReference {
    constructor(collectionPath, id, store) {
        this.collectionPath = collectionPath;
        this.id = id;
        this.store = store;
        this._subcollections = {};
    }

    collection(subName) {
        const key = `${this.collectionPath}/${this.id}/${subName}`;
        if (!this._subcollections[key]) {
            this._subcollections[key] = new MockCollectionReference(key, this.store);
        }
        return this._subcollections[key];
    }

    async get() {
        const data = this.store.get(`${this.collectionPath}/${this.id}`);
        return {
            exists: !!data,
            id: this.id,
            data: () => (data ? JSON.parse(JSON.stringify(data)) : undefined)
        };
    }

    async set(data) {
        this.store.set(`${this.collectionPath}/${this.id}`, JSON.parse(JSON.stringify(data)));
    }

    async update(data) {
        const current = this.store.get(`${this.collectionPath}/${this.id}`) || {};
        for (const [k, v] of Object.entries(data)) {
            if (v && (v._isIncrement || v.operand !== undefined)) {
                const delta = v.operand !== undefined ? v.operand : v.delta;
                current[k] = (Number(current[k]) || 0) + Number(delta);
            } else if (v && (v._isServerTimestamp || (typeof v.isEqual === 'function' && v.toString().includes('serverTimestamp')))) {
                current[k] = new Date();
            } else {
                current[k] = v;
            }
        }
        this.store.set(`${this.collectionPath}/${this.id}`, current);
    }
}

class MockCollectionReference {
    constructor(path, store) {
        this.path = path;
        this.store = store;
        this._filters = [];
    }

    doc(id) {
        const docId = id || `mock_doc_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
        return new MockDocumentReference(this.path, docId, this.store);
    }

    where(field, op, val) {
        const next = new MockCollectionReference(this.path, this.store);
        next._filters = [...this._filters, { field, op, val }];
        return next;
    }

    limit(n) {
        this._limit = n;
        return this;
    }

    async get() {
        const prefix = `${this.path}/`;
        let docs = [];
        for (const [key, value] of this.store.entries()) {
            if (key.startsWith(prefix) && key.replace(prefix, "").indexOf("/") === -1) {
                const id = key.replace(prefix, "");
                let match = true;
                for (const f of this._filters) {
                    if (f.op === "==" && value[f.field] !== f.val) {
                        match = false;
                        break;
                    }
                }
                if (match) {
                    docs.push({
                        id,
                        data: () => JSON.parse(JSON.stringify(value))
                    });
                }
            }
        }
        return {
            empty: docs.length === 0,
            size: docs.length,
            docs: this._limit ? docs.slice(0, this._limit) : docs
        };
    }
}

class MockFirestore {
    constructor() {
        this.store = new Map();
        this._txChain = Promise.resolve();
    }

    collection(path) {
        return new MockCollectionReference(path, this.store);
    }

    async runTransaction(updateFunction) {
        // Real Firestore serializes concurrent transactions on the same document sets
        return new Promise((resolve, reject) => {
            this._txChain = this._txChain.then(async () => {
                const transaction = {
                    get: async (ref) => await ref.get(),
                    getAll: async (...refs) => await Promise.all(refs.map(r => r.get())),
                    set: (ref, data) => ref.set(data),
                    update: (ref, data) => ref.update(data)
                };
                try {
                    const result = await updateFunction(transaction);
                    resolve(result);
                } catch (err) {
                    reject(err);
                }
            });
        });
    }
}

// Custom FieldValue mock
global.mockFieldValue = {
    increment: (delta) => ({ _isIncrement: true, delta }),
    serverTimestamp: () => ({ _isServerTimestamp: true })
};

async function runTestSuite() {
    console.log("=== RUNNING PAYMENT GATEWAY (REVISION 2) TEST SUITE ===");
    let passed = 0;
    let failed = 0;

    const mockDb = new MockFirestore();
    let commissionCalledCount = 0;
    let svipCalledCount = 0;

    const engine = new PaymentGatewayEngine(mockDb, {
        applyCommissionFn: async (tx, uid, usd, src, pol, hostDoc) => {
            commissionCalledCount++;
        },
        processSvipFn: (tx, userRef, userData, usd) => {
            svipCalledCount++;
        }
    });

    // Seed test user
    const testUid = "user_qa_101";
    await mockDb.collection("users").doc(testUid).set({
        uid: testUid,
        displayName: "QA Test User",
        diamondBalance: 100,
        monthlyRecharge: 0,
        totalRechargeGenerated: 0
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 1: Create Order & Idempotency Key Reuse
    // ─────────────────────────────────────────────────────────────────────────
    try {
        const order1 = await engine.createOrder({
            uid: testUid,
            packageId: "pack_70",
            gateway: "razorpay",
            idempotencyKey: "idemp_test_key_001"
        });
        assert.strictEqual(order1.status, "created");
        assert.strictEqual(order1.amount, 9900);
        assert.strictEqual(order1.currency, "inr");

        // Call again with same idempotencyKey -> must return same order
        const order2 = await engine.createOrder({
            uid: testUid,
            packageId: "pack_70",
            gateway: "razorpay",
            idempotencyKey: "idemp_test_key_001"
        });
        assert.strictEqual(order2.orderId, order1.orderId, "Must return existing orderId on duplicate idempotency key");
        assert.strictEqual(order2.isReused, true, "Must indicate reused order");

        console.log("✅ Test 1: Order creation & idempotency key reuse passed");
        passed++;
    } catch (err) {
        console.error("❌ Test 1 Failed:", err.message);
        failed++;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 2: Single Credit Path (creditOrderIfPaid) & Balance Mutation
    // ─────────────────────────────────────────────────────────────────────────
    let orderToCreditId = "";
    try {
        const createdOrder = await engine.createOrder({
            uid: testUid,
            packageId: "pack_350", // 350 + 20 = 370 diamonds
            gateway: "razorpay",
            idempotencyKey: "idemp_test_key_002"
        });
        orderToCreditId = createdOrder.orderId;

        const creditResult = await engine.creditOrderIfPaid(orderToCreditId, "pay_rzp_mock_001", {
            isWebhook: false,
            amountPaidMinor: 49900,
            currencyPaid: "inr"
        });

        assert.strictEqual(creditResult.status, "completed");
        assert.strictEqual(creditResult.alreadyProcessed, false);
        assert.strictEqual(creditResult.diamondsCredited, 370);

        // Verify user diamond balance incremented from 100 to 470
        const updatedUser = (await mockDb.collection("users").doc(testUid).get()).data();
        assert.strictEqual(updatedUser.diamondBalance, 470, "User diamond balance must be 470");
        assert.strictEqual(commissionCalledCount, 1, "Agency commission calculation must be invoked once");
        assert.strictEqual(svipCalledCount, 1, "SVIP points calculation must be invoked once");

        // Verify processed_payments record exists
        const processedDoc = await mockDb.collection("processed_payments").doc("pay_rzp_mock_001").get();
        assert.strictEqual(processedDoc.exists, true, "processed_payments document must exist");

        // Verify order status is completed
        const orderDoc = (await mockDb.collection("payment_orders").doc(orderToCreditId).get()).data();
        assert.strictEqual(orderDoc.status, "completed");

        console.log("✅ Test 2: Single credit path and balance atomic mutation passed");
        passed++;
    } catch (err) {
        console.error("❌ Test 2 Failed:", err.message);
        failed++;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 3: Idempotency Protection (5 Replays -> Exactly 1 Credit)
    // ─────────────────────────────────────────────────────────────────────────
    try {
        const initialBalance = (await mockDb.collection("users").doc(testUid).get()).data().diamondBalance;

        // Replay 5 times with same payment ID
        for (let i = 1; i <= 5; i++) {
            const replayResult = await engine.creditOrderIfPaid(orderToCreditId, "pay_rzp_mock_001", {
                isWebhook: true
            });
            assert.strictEqual(replayResult.status, "completed");
            assert.strictEqual(replayResult.alreadyProcessed, true, `Replay ${i} must report alreadyProcessed: true`);
        }

        const afterReplaysBalance = (await mockDb.collection("users").doc(testUid).get()).data().diamondBalance;
        assert.strictEqual(initialBalance, afterReplaysBalance, "Balance must not change on replayed webhooks/credits");

        console.log("✅ Test 3: Idempotency protection (5 replayed webhooks -> exactly 1 credit) passed");
        passed++;
    } catch (err) {
        console.error("❌ Test 3 Failed:", err.message);
        failed++;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 4: Client Fast-Path and Webhook Parallel Race (Promise.all)
    // ─────────────────────────────────────────────────────────────────────────
    try {
        const raceOrder = await engine.createOrder({
            uid: testUid,
            packageId: "pack_70", // 70 diamonds
            gateway: "stripe",
            idempotencyKey: "idemp_test_key_003"
        });

        const startBalance = (await mockDb.collection("users").doc(testUid).get()).data().diamondBalance;

        // Launch both client verify and webhook concurrently
        const [fastPathRes, webhookRes] = await Promise.all([
            engine.creditOrderIfPaid(raceOrder.orderId, "pi_stripe_mock_race_001", { isWebhook: false }),
            engine.creditOrderIfPaid(raceOrder.orderId, "pi_stripe_mock_race_001", { isWebhook: true })
        ]);

        const endBalance = (await mockDb.collection("users").doc(testUid).get()).data().diamondBalance;
        assert.strictEqual(endBalance, startBalance + 70, "Exactly 70 diamonds must be credited, never double (140)");
        
        // One must be fresh, the other must be alreadyProcessed (or both return completed safely)
        const freshCount = (!fastPathRes.alreadyProcessed ? 1 : 0) + (!webhookRes.alreadyProcessed ? 1 : 0);
        assert.strictEqual(freshCount, 1, "Exactly one caller must perform the fresh credit");

        console.log("✅ Test 4: Client verify and webhook parallel race condition passed");
        passed++;
    } catch (err) {
        console.error("❌ Test 4 Failed:", err.message);
        failed++;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 5: Amount and Currency Tampering Detection
    // ─────────────────────────────────────────────────────────────────────────
    try {
        const tamperOrder = await engine.createOrder({
            uid: testUid,
            packageId: "pack_700", // ₹999.00 (99900 paise)
            gateway: "razorpay",
            idempotencyKey: "idemp_test_key_004"
        });

        let tamperCaught = false;
        try {
            await engine.creditOrderIfPaid(tamperOrder.orderId, "pay_tamper_001", {
                isWebhook: true,
                amountPaidMinor: 100, // Attacker paid ₹1 instead of ₹999
                currencyPaid: "inr"
            });
        } catch (e) {
            tamperCaught = true;
        }

        assert.strictEqual(tamperCaught, true, "Tampered amount must be rejected");

        // Verify order was marked flagged
        const flaggedOrder = (await mockDb.collection("payment_orders").doc(tamperOrder.orderId).get()).data();
        assert.strictEqual(flaggedOrder.status, "flagged", "Tampered order must be marked flagged");

        console.log("✅ Test 5: Amount and currency tampering detection passed");
        passed++;
    } catch (err) {
        console.error("❌ Test 5 Failed:", err.message);
        failed++;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 6: HMAC SHA256 Webhook Signature Verification
    // ─────────────────────────────────────────────────────────────────────────
    try {
        const secret = "whsec_test_secret_998877";
        const rawPayload = JSON.stringify({ event: "payment.captured", id: "evt_12345" });
        const validSig = crypto.createHmac("sha256", secret).update(rawPayload).digest("hex");
        const invalidSig = "bad_signature_abc_123";

        const isValid = engine.verifyWebhookSignature(rawPayload, validSig, secret);
        const isInvalid = engine.verifyWebhookSignature(rawPayload, invalidSig, secret);

        assert.strictEqual(isValid, true, "Valid HMAC signature must verify to true");
        assert.strictEqual(isInvalid, false, "Invalid HMAC signature must verify to false");

        console.log("✅ Test 6: Webhook HMAC SHA256 cryptographic signature verification passed");
        passed++;
    } catch (err) {
        console.error("❌ Test 6 Failed:", err.message);
        failed++;
    }

    console.log(`\n=== RESULTS: ${passed} PASSED, ${failed} FAILED ===\n`);
    if (failed > 0) process.exit(1);
}

runTestSuite().catch(err => {
    console.error("Fatal Test Suite Error:", err);
    process.exit(1);
});
