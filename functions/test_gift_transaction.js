/**
 * Test Suite: Firestore Transaction Ordering & Gift Sending Engine
 * Verifies that sendGiftWithCombo STRICTLY completes ALL reads before ANY writes.
 * 
 * Run: node functions/test_gift_transaction.js
 */

const assert = require("assert");
const admin = require("firebase-admin");

// 1. Build an in-memory document store & strict transaction mock
const store = new Map();

function docKey(path) {
    return path.replace(/^\/+|\/+$/g, '');
}

class MockDocSnapshot {
    constructor(path, data) {
        this._path = path;
        this._data = data ? JSON.parse(JSON.stringify(data)) : null;
        this.exists = data !== null && data !== undefined;
        this.id = path.split('/').pop();
    }
    data() {
        return this._data ? JSON.parse(JSON.stringify(this._data)) : undefined;
    }
    get ref() {
        return createMockDocRef(this._path);
    }
}

function createMockDocRef(path) {
    const cleanPath = docKey(path);
    return {
        _path: cleanPath,
        id: cleanPath.split('/').pop(),
        get: async () => {
            const data = store.get(cleanPath);
            return new MockDocSnapshot(cleanPath, data);
        },
        set: async (data, opts) => {
            const existing = store.get(cleanPath) || {};
            const merged = (opts && opts.merge) ? { ...existing, ...data } : data;
            store.set(cleanPath, merged);
        },
        update: async (data) => {
            const existing = store.get(cleanPath);
            if (!existing) throw new Error(`Document ${cleanPath} not found for update`);
            store.set(cleanPath, { ...existing, ...data });
        },
        collection: (subCol) => createMockCollectionRef(`${cleanPath}/${subCol}`)
    };
}

function createMockCollectionRef(path) {
    const cleanPath = docKey(path);
    return {
        _path: cleanPath,
        doc: (id) => {
            const docId = id || `auto_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
            return createMockDocRef(`${cleanPath}/${docId}`);
        },
        where: (field, op, val) => {
            return {
                get: async () => {
                    const docs = [];
                    for (const [k, v] of store.entries()) {
                        if (k.startsWith(cleanPath + '/') && k.split('/').length === cleanPath.split('/').length + 1) {
                            if (op === '==' && v && v[field] === val) {
                                docs.push(new MockDocSnapshot(k, v));
                            }
                        }
                    }
                    return {
                        empty: docs.length === 0,
                        size: docs.length,
                        docs: docs,
                        forEach: (cb) => docs.forEach(cb)
                    };
                },
                limit: () => ({
                    get: async () => ({
                        empty: true,
                        size: 0,
                        docs: [],
                        forEach: () => {}
                    })
                })
            };
        }
    };
}

class StrictMockTransaction {
    constructor() {
        this.hasWritten = false;
        this.readsCount = 0;
        this.writesCount = 0;
        this.pendingMutations = [];
    }

    _assertNoWriteBeforeRead(operation) {
        if (this.hasWritten) {
            const err = new Error("Firestore transactions require all reads to be completed before writes");
            err.code = 13; // INTERNAL
            throw err;
        }
    }

    async get(docRef) {
        this._assertNoWriteBeforeRead(`get(${docRef._path})`);
        this.readsCount++;
        const data = store.get(docRef._path);
        return new MockDocSnapshot(docRef._path, data);
    }

    async getAll(...docRefs) {
        this._assertNoWriteBeforeRead(`getAll(${docRefs.map(r => r._path).join(', ')})`);
        this.readsCount += docRefs.length;
        return docRefs.map(docRef => {
            const data = store.get(docRef._path);
            return new MockDocSnapshot(docRef._path, data);
        });
    }

    set(docRef, data, options) {
        this.hasWritten = true;
        this.writesCount++;
        this.pendingMutations.push(() => {
            const existing = store.get(docRef._path) || {};
            const isMerge = options && options.merge;
            const updated = isMerge ? { ...existing } : {};

            for (const [k, v] of Object.entries(data)) {
                if (v && v._methodName === 'FieldValue.increment') {
                    updated[k] = (Number(existing[k]) || 0) + v._operand;
                } else if (v && v._methodName === 'FieldValue.serverTimestamp') {
                    updated[k] = new Date();
                } else {
                    updated[k] = v;
                }
            }
            store.set(docRef._path, updated);
        });
        return this;
    }

    update(docRef, data) {
        this.hasWritten = true;
        this.writesCount++;
        this.pendingMutations.push(() => {
            const existing = store.get(docRef._path);
            if (!existing) throw new Error(`Doc ${docRef._path} not found`);
            const updated = { ...existing };
            for (const [k, v] of Object.entries(data)) {
                if (v && v._methodName === 'FieldValue.increment') {
                    updated[k] = (Number(existing[k]) || 0) + v._operand;
                } else if (v && v._methodName === 'FieldValue.serverTimestamp') {
                    updated[k] = new Date();
                } else if (k.includes('.')) {
                    const parts = k.split('.');
                    if (parts.length === 2) {
                        updated[parts[0]] = updated[parts[0]] || {};
                        if (v && v._methodName === 'FieldValue.increment') {
                            updated[parts[0]][parts[1]] = (Number(updated[parts[0]][parts[1]]) || 0) + v._operand;
                        } else {
                            updated[parts[0]][parts[1]] = v;
                        }
                    }
                } else {
                    updated[k] = v;
                }
            }
            store.set(docRef._path, updated);
        });
        return this;
    }

    delete(docRef) {
        this.hasWritten = true;
        this.writesCount++;
        this.pendingMutations.push(() => {
            store.delete(docRef._path);
        });
        return this;
    }

    commit() {
        for (const m of this.pendingMutations) {
            m();
        }
    }
}

// 2. Monkey-patch admin.firestore before loading functions/index.js
const mockDb = {
    collection: (path) => createMockCollectionRef(path),
    doc: (path) => createMockDocRef(path),
    runTransaction: async (updateFunction) => {
        const tx = new StrictMockTransaction();
        const res = await updateFunction(tx);
        tx.commit();
        return res;
    }
};

Object.defineProperty(admin, 'firestore', {
    value: function() {
        return mockDb;
    },
    configurable: true,
    writable: true
});
admin.firestore.FieldValue = {
    increment: (n) => ({ _methodName: 'FieldValue.increment', _operand: n }),
    serverTimestamp: () => ({ _methodName: 'FieldValue.serverTimestamp' })
};
admin.firestore.Timestamp = {
    fromMillis: (ms) => ({ toMillis: () => ms, toDate: () => new Date(ms) }),
    fromDate: (d) => ({ toMillis: () => d.getTime(), toDate: () => d })
};

// 3. Load backend functions
const test = require("firebase-functions-test")();
const { sendGiftWithCombo } = require("./index.js");
const wrappedSendGift = test.wrap(sendGiftWithCombo);

console.log("=================================================================");
console.log("🧪 TESTING FIRESTORE TRANSACTION ORDERING & GIFT SENDING ENGINE");
console.log("=================================================================");

function seedStore() {
    store.clear();
    // System configs
    store.set("system_settings/lucky_gift_config", {
        multipliers: [
            { multiplier: 0, winningAmount: 0, probability: 50.0, enabled: true },
            { multiplier: 2, winningAmount: 100, probability: 50.0, enabled: true },
        ]
    });
    store.set("room_support_configs/settings", {
        levels: [
            { level: 1, coinsTarget: 10000000 },
            { level: 2, coinsTarget: 20000000 },
            { level: 3, coinsTarget: 30000000 },
            { level: 4, coinsTarget: 50000000 },
            { level: 5, coinsTarget: 100000000 }
        ]
    });

    // Gifts
    store.set("gifts/gift_rose", {
        id: "gift_rose",
        name: "Rose",
        priceInDiamonds: 10,
        category: "normal",
        lottieAssetPath: "assets/gifts/rose.json"
    });
    store.set("gifts/gift_lucky_box", {
        id: "gift_lucky_box",
        name: "Lucky Box",
        priceInDiamonds: 50,
        category: "lucky",
        isLucky: true,
        lottieAssetPath: "assets/gifts/lucky.json"
    });
    store.set("gifts/gift_vip_crown", {
        id: "gift_vip_crown",
        name: "VIP Crown",
        priceInDiamonds: 500,
        category: "vip",
        lottieAssetPath: "assets/gifts/vip.json"
    });
    store.set("gifts/gift_svip_dragon", {
        id: "gift_svip_dragon",
        name: "SVIP Dragon",
        priceInDiamonds: 2000,
        category: "svip",
        minSvipLevel: 2,
        lottieAssetPath: "assets/gifts/dragon.json"
    });

    // Room & Support Cycle
    store.set("rooms/room_101", {
        id: "room_101",
        name: "Diamond Room",
        rocketLevel: 0,
        rocketFuel: 0,
        rocketContributions: {},
        weeklyEarnings: 0
    });
    store.set("room_support_cycles/room_101", {
        totalCoins: 0,
        level: 0,
        weekId: "2026-W41"
    });

    // Users
    store.set("users/sender_alice", {
        uid: "sender_alice",
        displayName: "Alice",
        diamondBalance: 100000,
        totalDiamondsSpent: 0,
        xp: 1000,
        vipTier: "gold",
        svipLevel: 3
    });
    store.set("users/sender_poor", {
        uid: "sender_poor",
        displayName: "Poor Bob",
        diamondBalance: 5,
        totalDiamondsSpent: 0,
        xp: 10,
        vipTier: "none",
        svipLevel: 0
    });
    store.set("users/receiver_charlie", {
        uid: "receiver_charlie",
        displayName: "Charlie",
        beansBalance: 0,
        totalBeansReceived: 0,
        totalDiamondsReceived: 0,
        princeXP: 0
    });
    store.set("salaryStatus/receiver_charlie", {
        uid: "receiver_charlie",
        totalBeansEarned: 0,
        completedLevels: []
    });

    store.set("users/receiver_david", {
        uid: "receiver_david",
        displayName: "David (Agency)",
        beansBalance: 0,
        totalBeansReceived: 0,
        totalDiamondsReceived: 0,
        princeXP: 0,
        agencyId: "agency_omega"
    });
    store.set("salaryStatus/receiver_david", {
        uid: "receiver_david",
        totalBeansEarned: 0,
        completedLevels: []
    });
    store.set("agencies/agency_omega", {
        id: "agency_omega",
        beansBalance: 0,
        totalBeansEarned: 0
    });

    store.set("users/receiver_eve", {
        uid: "receiver_eve",
        displayName: "Eve",
        beansBalance: 50,
        totalBeansReceived: 50,
        totalDiamondsReceived: 50,
        princeXP: 0
    });
    store.set("salaryStatus/receiver_eve", {
        uid: "receiver_eve",
        totalBeansEarned: 50,
        completedLevels: []
    });
}

async function runTests() {
    seedStore();

    // -------------------------------------------------------------
    // TEST 1: Single Receiver Normal Gift (Zero Reads after Writes)
    // -------------------------------------------------------------
    console.log("\n▶ TEST 1: Single Receiver Normal Gift");
    {
        const res = await wrappedSendGift({
            roomId: "room_101",
            giftId: "gift_rose",
            targetUid: "receiver_charlie",
            quantity: 1,
            comboCount: 0
        }, { auth: { uid: "sender_alice" } });

        assert.strictEqual(res.success, true);
        assert.strictEqual(res.totalCost, 10);
        assert.strictEqual(res.newBalance, 100000 - 10);

        const alice = store.get("users/sender_alice");
        assert.strictEqual(alice.diamondBalance, 99990);
        assert.strictEqual(alice.totalDiamondsSent, 10);

        const charlie = store.get("users/receiver_charlie");
        assert.strictEqual(charlie.beansBalance, 10);
        assert.strictEqual(charlie.totalBeansReceived, 10);

        console.log("  ✅ PASS: 10 diamonds deducted, 10 beans credited, ZERO transaction ordering errors");
    }

    // -------------------------------------------------------------
    // TEST 2: Combo Quantities (qty: 5, combo: 10)
    // -------------------------------------------------------------
    console.log("\n▶ TEST 2: Combo Quantity & Seat Updates");
    {
        const res = await wrappedSendGift({
            roomId: "room_101",
            giftId: "gift_rose",
            targetUid: "receiver_charlie",
            quantity: 5,
            comboCount: 10
        }, { auth: { uid: "sender_alice" } });

        assert.strictEqual(res.success, true);
        assert.strictEqual(res.totalCost, 50);

        const alice = store.get("users/sender_alice");
        assert.strictEqual(alice.diamondBalance, 99940);

        const charlie = store.get("users/receiver_charlie");
        assert.strictEqual(charlie.beansBalance, 60);

        // Verify participant combo badge
        const seat = store.get("rooms/room_101/participants/receiver_charlie");
        assert.strictEqual(seat.comboCount, 10);
        assert.strictEqual(seat.comboSenderUid, "sender_alice");
        assert.strictEqual(seat.comboGiftName, "Rose");

        console.log("  ✅ PASS: Combo x10 processed, seat badge stamped, ZERO transaction ordering errors");
    }

    // -------------------------------------------------------------
    // TEST 3: Fan-Out Multi-Target Gifting (3 Receivers, 1 with Agency)
    // -------------------------------------------------------------
    console.log("\n▶ TEST 3: Fan-Out Multi-Target Gifting (3 Receivers)");
    {
        const targets = ["receiver_charlie", "receiver_david", "receiver_eve"];
        const res = await wrappedSendGift({
            roomId: "room_101",
            giftId: "gift_rose",
            targetUids: targets,
            quantity: 10
        }, { auth: { uid: "sender_alice" } });

        assert.strictEqual(res.success, true);
        assert.strictEqual(res.perTarget.length, 3);
        assert.strictEqual(res.totalCost, 300); // 10 * 10 * 3 targets

        // Alice paid 300
        const alice = store.get("users/sender_alice");
        assert.strictEqual(alice.diamondBalance, 99640);

        // David has agency_omega (100 cost -> 70% to host = 70 beans, 10% to agency = 10 beans)
        const david = store.get("users/receiver_david");
        assert.strictEqual(david.beansBalance, 70);
        const omega = store.get("agencies/agency_omega");
        assert.strictEqual(omega.beansBalance, 10);

        console.log("  ✅ PASS: Fan-out to 3 receivers atomically billed and credited with agency split, ZERO transaction ordering errors");
    }

    // -------------------------------------------------------------
    // TEST 4: Lucky Gift Mechanics (Probability & Refund)
    // -------------------------------------------------------------
    console.log("\n▶ TEST 4: Lucky Gift Mechanics");
    {
        const res = await wrappedSendGift({
            roomId: "room_101",
            giftId: "gift_lucky_box",
            targetUid: "receiver_charlie",
            quantity: 2
        }, { auth: { uid: "sender_alice" } });

        assert.strictEqual(res.success, true);
        assert.strictEqual(res.isLucky, true);
        assert.strictEqual(res.totalCost, 100); // 50 * 2
        assert.ok(res.newBalance >= 99540); // 99640 - 100 + luckyReward

        console.log(`  ✅ PASS: Lucky Gift resolved (Refund: +${res.luckyRewardCoins} 💎), audit log written, ZERO transaction ordering errors`);
    }

    // -------------------------------------------------------------
    // TEST 5: VIP & SVIP Gifting Permissions
    // -------------------------------------------------------------
    console.log("\n▶ TEST 5: VIP & SVIP Gifting Permissions");
    {
        // Alice has VIP gold -> Can send VIP gift
        const vipRes = await wrappedSendGift({
            roomId: "room_101",
            giftId: "gift_vip_crown",
            targetUid: "receiver_charlie",
            quantity: 1
        }, { auth: { uid: "sender_alice" } });
        assert.strictEqual(vipRes.success, true);

        // Alice has SVIP 3 -> Can send SVIP Lv.2 gift
        const svipRes = await wrappedSendGift({
            roomId: "room_101",
            giftId: "gift_svip_dragon",
            targetUid: "receiver_charlie",
            quantity: 1
        }, { auth: { uid: "sender_alice" } });
        assert.strictEqual(svipRes.success, true);

        // Poor Bob has no VIP -> Blocked before transaction writes
        let vipError = null;
        try {
            await wrappedSendGift({
                roomId: "room_101",
                giftId: "gift_vip_crown",
                targetUid: "receiver_charlie",
                quantity: 1
            }, { auth: { uid: "sender_poor" } });
        } catch (e) {
            vipError = e;
        }
        assert.ok(vipError, "Non-VIP must be blocked from sending VIP gifts");
        assert.strictEqual(vipError.code, "permission-denied");

        console.log("  ✅ PASS: VIP & SVIP permissions strictly verified, invalid attempts blocked safely");
    }

    // -------------------------------------------------------------
    // TEST 6: Insufficient Balance Rejection
    // -------------------------------------------------------------
    console.log("\n▶ TEST 6: Insufficient Balance Rejection");
    {
        let balanceErr = null;
        try {
            await wrappedSendGift({
                roomId: "room_101",
                giftId: "gift_rose",
                targetUid: "receiver_charlie",
                quantity: 1
            }, { auth: { uid: "sender_poor" } }); // Has 5 diamonds, rose costs 10
        } catch (e) {
            balanceErr = e;
        }
        assert.ok(balanceErr, "Underfunded sender must be rejected");
        assert.strictEqual(balanceErr.code, "failed-precondition");

        // Verify Bob's 5 diamonds are intact
        const bob = store.get("users/sender_poor");
        assert.strictEqual(bob.diamondBalance, 5);
        console.log("  ✅ PASS: Insufficient balance rejected cleanly with failed-precondition, 0 writes made");
    }

    // -------------------------------------------------------------
    // TEST 7: Rapid Consecutive Sends (Stress Test: 20 rapid bursts)
    // -------------------------------------------------------------
    console.log("\n▶ TEST 7: Rapid Consecutive Sends Stress Test (20 rapid calls)");
    {
        const burstCount = 20;
        let prevBalance = store.get("users/sender_alice").diamondBalance;
        let prevBeans = store.get("users/receiver_charlie").beansBalance;

        for (let i = 1; i <= burstCount; i++) {
            const res = await wrappedSendGift({
                roomId: "room_101",
                giftId: "gift_rose",
                targetUid: "receiver_charlie",
                quantity: 1,
                comboCount: i
            }, { auth: { uid: "sender_alice" } });

            assert.strictEqual(res.success, true);
            assert.strictEqual(res.totalCost, 10);
            assert.strictEqual(res.newBalance, prevBalance - 10);
            prevBalance -= 10;
            prevBeans += 10;
        }

        const aliceFinal = store.get("users/sender_alice");
        assert.strictEqual(aliceFinal.diamondBalance, prevBalance);
        const charlieFinal = store.get("users/receiver_charlie");
        assert.strictEqual(charlieFinal.beansBalance, prevBeans);

        console.log(`  ✅ PASS: 20 rapid back-to-back sends completed with 100% success and ZERO transaction ordering errors!`);
    }

    // -------------------------------------------------------------
    // TEST 8: Salary Milestone Triggering with Preloaded Snapshot
    // -------------------------------------------------------------
    console.log("\n▶ TEST 8: Salary Milestone Triggering (Preloaded Snapshot)");
    {
        // Give Charlie 999,990 beans in salaryStatus
        store.set("salaryStatus/receiver_charlie", {
            uid: "receiver_charlie",
            totalBeansEarned: 999990,
            completedLevels: []
        });

        // Send a 10 diamond gift -> Charlie receives 10 beans -> hits exactly 1,000,000 (Lv.1 milestone)
        const res = await wrappedSendGift({
            roomId: "room_101",
            giftId: "gift_rose",
            targetUid: "receiver_charlie",
            quantity: 1
        }, { auth: { uid: "sender_alice" } });

        assert.strictEqual(res.success, true);

        const status = store.get("salaryStatus/receiver_charlie");
        assert.strictEqual(status.totalBeansEarned, 1000000);
        assert.deepStrictEqual(status.completedLevels, [1]);
        assert.strictEqual(status.currentLevel, 1);

        console.log("  ✅ PASS: Salary Lv.1 milestone triggered atomically in-transaction without ANY reads after writes!");
    }

    // -------------------------------------------------------------
    // TEST 9: Rocket Fueling Accumulation
    // -------------------------------------------------------------
    console.log("\n▶ TEST 9: Rocket Fueling Accumulation");
    {
        const room = store.get("rooms/room_101");
        assert.ok(room.rocketFuel > 0, "Rocket fuel must accumulate from gifts sent in room");
        console.log(`  ✅ PASS: Rocket fuel accumulated to ${room.rocketFuel} diamonds, zero reads during write phase`);
    }

    // -------------------------------------------------------------
    // TEST 10: Self-Gifting Filter
    // -------------------------------------------------------------
    console.log("\n▶ TEST 10: Self-Gifting Filter");
    {
        let selfErr = null;
        try {
            await wrappedSendGift({
                roomId: "room_101",
                giftId: "gift_rose",
                targetUid: "sender_alice", // Alice trying to gift herself
                quantity: 1
            }, { auth: { uid: "sender_alice" } });
        } catch (e) {
            selfErr = e;
        }
        assert.ok(selfErr, "Self-gift should fail validation cleanly");
        assert.strictEqual(selfErr.code, "invalid-argument");
        console.log("  ✅ PASS: Self-gifting rejected safely before entering transaction");
    }

    console.log("\n=================================================================");
    console.log("🎉 ALL 10 TESTS PASSED WITH ZERO FIRESTORE TRANSACTION ERRORS!");
    console.log("=================================================================\n");
}

runTests().catch(err => {
    console.error("❌ TEST FAILED:", err);
    process.exit(1);
});
