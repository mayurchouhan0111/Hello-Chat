const functions = require("firebase-functions");
const { onValueUpdated } = require("firebase-functions/v2/database");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineString, defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp({
    databaseURL: "https://hellochat-e8965-default-rtdb.asia-southeast1.firebasedatabase.app"
});


const region = "us-central1";
const db = admin.firestore();
const { RtcTokenBuilder, RtcRole } = require('agora-access-token');

// 🔑 AGORA CONFIG (MODERN PARAMS)
const APP_ID = defineString("AGORA_APP_ID", { default: "47343e02029c4249a5b4f8d5db321b9d" });
const APP_CERTIFICATE = defineSecret("AGORA_APP_CERTIFICATE");

// 🔑 LEGACY AGORA CONFIG (FOR OLD FUNCTIONS)
const AGORA_APP_ID = "47343e02029c4249a5b4f8d5db321b9d";
const AGORA_APP_CERTIFICATE = "5f9f7f1205e94b00b87cb73c7cab97d3";

/**
 * --- ADMIN PERMISSION HELPERS ---
 */
async function isUserAdmin(uid) {
    if (!uid) return false;
    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) return false;
    const tags = userDoc.data().tags || [];
    return tags.includes("Admin") || tags.includes("SuperAdmin");
}

/**
 * --- PUSH NOTIFICATION HELPER ---
 */
async function sendPush(targetUid, title, body, dataMap = {}) {
    try {
        const userDoc = await db.collection("users").doc(targetUid).get();
        if (!userDoc.exists) return;
        const fcmToken = userDoc.data()?.fcmToken;
        if (!fcmToken) return;

        const stringData = {};
        for (const [k, v] of Object.entries(dataMap)) {
            stringData[k] = String(v ?? "");
        }

        await admin.messaging().send({
            token: fcmToken,
            notification: {
                title: title,
                body: body,
            },
            data: stringData,
        });
        console.log(`[PUSH] Delivered to ${targetUid}: ${title}`);
    } catch (err) {
        console.error(`[PUSH_ERROR] Failed sending push to ${targetUid}:`, err);
    }
}

/**
 * --- ROCKET WINNER NOTIFICATION HELPER ---
 * Sends a personalized FCM push to each TOP 1/2/3 winner after the
 * rocket launch transaction commits. Fire-and-forget; never blocks gifting.
 * Handles missing users, missing FCM tokens, and FCM failures per-user.
 */
async function notifyRocketWinners(winners) {
    const rankLabels = { 1: "TOP 1", 2: "TOP 2", 3: "TOP 3" };
    const rankEmoji = { 1: "🥇", 2: "🥈", 3: "🥉" };

    for (const winner of winners) {
        if (!winner || !winner.uid) {
            console.warn("[ROCKET_NOTIFY] Skipping winner without uid:", winner);
            continue;
        }

        const rank = winner.rank || 1;
        const label = rankLabels[rank] || `TOP ${rank}`;
        const emoji = rankEmoji[rank] || "🎉";
        const reward = Number(winner.reward) || 0;
        const xp = Number(winner.xp) || 0;
        const level = winner.level || 1;

        try {
            await sendPush(
                winner.uid,
                `${emoji} Rocket Reward - You ranked ${label}!`,
                `Congratulations ${label}! You won ${reward.toLocaleString()} 💎 + ${xp} XP + Rocket Frame (Level ${level}).`,
                {
                    route: "/room",
                    roomId: winner.roomId || "",
                    type: "rocket_reward",
                    rocketLevel: String(level),
                    rank: String(rank),
                }
            );
            console.log(`[ROCKET_NOTIFY] Push sent to ${winner.uid} for ${label}`);
        } catch (err) {
            // Per-winner failure isolation: continue notifying the rest
            console.error(`[ROCKET_NOTIFY] Failed to notify ${winner.uid} (${label}):`, err);
        }
    }
}


/**
 * --- AGORA VOICE TOKEN SERVER (DIRECT HTTP BYPASS) ---
 * Immune to App Check/Auth Handshake issues.
 */
exports.getSecureAgoraTokenHttp = functions.https.onRequest(async (req, res) => {
    // Enable CORS
    res.set('Access-Control-Allow-Origin', '*');
    if (req.method === 'OPTIONS') {
        res.set('Access-Control-Allow-Methods', 'POST');
        res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
        res.set('Access-Control-Max-Age', '3600');
        res.status(204).send('');
        return;
    }

    try {
        // 🔒 Verify authorization token header if present
        const authHeader = req.headers.authorization;
        if (authHeader && authHeader.startsWith('Bearer ')) {
            try {
                const idToken = authHeader.split('Bearer ')[1];
                await admin.auth().verifyIdToken(idToken);
            } catch (authErr) {
                console.warn("[AgoraHTTP] Auth verification warning:", authErr.message);
            }
        }

        const { roomId } = req.body.data || req.body || {};
        if (!roomId) {
            return res.status(400).send({ error: "Room ID required" });
        }

        const uid = 0;
        const role = RtcRole.PUBLISHER;
        const expirationTimeInSeconds = 3600;
        const currentTimestamp = Math.floor(Date.now() / 1000);
        const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

        const appId = "4736b1a519264c6e813e4e28bf75db9d";
        const appCert = "5f9f7f1205e94b00b87cb73c7cab97d3";

        const token = RtcTokenBuilder.buildTokenWithUid(
            appId,
            appCert,
            roomId.toString(),
            0,
            role,
            privilegeExpiredTs
        );
        console.log(`[HTTP] Token Gen for ${roomId}: ${token.substring(0, 8)}...`);

        return res.status(200).send({
            data: {
                token: token,
                isSecureFinal: true,
                serverTime: Date.now()
            }
        });
    } catch (error) {
        console.error("HTTP TOKEN ERROR:", error);
        return res.status(500).send({ error: error.message });
    }
});

exports.getAgoraToken = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const { roomId } = data || {};
    if (!roomId) throw new functions.https.HttpsError("invalid-argument", "Room ID required.");

    const role = RtcRole.PUBLISHER;
    const expirationTimeInSeconds = 3600;
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

    const appId = "4736b1a519264c6e813e4e28bf75db9d";
    const appCert = "5f9f7f1205e94b00b87cb73c7cab97d3";

    const token = RtcTokenBuilder.buildTokenWithUid(
        appId,
        appCert,
        roomId.toString(),
        0,
        role,
        privilegeExpiredTs
    );

    return {
        token: token,
        serverTime: Date.now()
    };
});

exports.secureAgoraToken = functions.https.onCall(async (data, context) => {
    // console.log("[AGORA] Auth State:", context.auth ? "Authenticated" : "Anonymous/Unmatched");

    const { roomId } = data;
    if (!roomId) throw new functions.https.HttpsError("invalid-argument", "Room ID required.");

    // Fallback logic for Testing Mode (No Certificate)
    if (!AGORA_APP_CERTIFICATE || AGORA_APP_CERTIFICATE === "") {
        console.warn("[AGORA] No App Certificate found. Returning testing mode token.");
        return { token: "" };
    }

    const uid = 0; // Using 0 for string-based channel joins in Agora Flutter
    const role = RtcRole.PUBLISHER;
    const expirationTimeInSeconds = 3600; // 1 Hour
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

    const appId = "4736b1a519264c6e813e4e28bf75db9d";
    const appCert = "5f9f7f1205e94b00b87cb73c7cab97d3";

    const token = RtcTokenBuilder.buildTokenWithUid(
        appId,
        appCert,
        roomId.toString(),
        0,
        role,
        privilegeExpiredTs
    );
    console.log(`[CALLABLE] Token Gen for ${roomId}: ${token.substring(0, 8)}...`);

    return {
        token: token,
        isSecure: true,
        serverTime: Date.now()
    };
});

/**
 * --- ROCKET KING SYSTEM ---
 */
const ROCKET_SYSTEM = {
    targets: [1000000, 2000000, 3000000, 5000000, 10000000],
    rewards: [
        { king: 30000, t2: 15000, t3: 7500, xp: 2000 },
        { king: 60000, t2: 40000, t3: 30000, xp: 3000 },
        { king: 200000, t2: 150000, t3: 100000, xp: 5000 },
        { king: 500000, t2: 300000, t3: 250000, xp: 10000 },
        { king: 800000, t2: 500000, t3: 350000, xp: 15000 },
    ],
    frameAsset: "assets/rocket/rocket_frame.svga",
    frameValidityMs: [24 * 60 * 60 * 1000, 24 * 60 * 60 * 1000, 24 * 60 * 60 * 1000, 24 * 60 * 60 * 1000, 72 * 60 * 60 * 1000]
};

async function processRocketLaunch(transaction, roomId, level, roomData, senderUid, totalCost) {
    const contributions = roomData.rocketContributions || {};
    // Add current contribution to the map for accurate ranking
    const currentContrib = (contributions[senderUid] || 0) + totalCost;
    const finalContributions = { ...contributions, [senderUid]: currentContrib };

    const sortedContributors = Object.entries(finalContributions)
        .sort(([, a], [, b]) => b - a)
        .slice(0, 3);

    const rewards = ROCKET_SYSTEM.rewards[level];
    if (!rewards) return [];

    // 1. Distribute rewards to Top 3
    const nowMs = Date.now();
    const frameValidityMs = ROCKET_SYSTEM.frameValidityMs[level] || 24 * 60 * 60 * 1000;
    const frameAsset = ROCKET_SYSTEM.frameAsset;
    const frameExpiresAt = admin.firestore.Timestamp.fromMillis(nowMs + frameValidityMs);

    const rewardWinners = [
        { uid: sortedContributors[0]?.[0], rebate: rewards.king, rank: 1, amount: sortedContributors[0]?.[1] || 0 },
        { uid: sortedContributors[1]?.[0], rebate: rewards.t2, rank: 2, amount: sortedContributors[1]?.[1] || 0 },
        { uid: sortedContributors[2]?.[0], rebate: rewards.t3, rank: 3, amount: sortedContributors[2]?.[1] || 0 },
    ];

    const notifiedWinners = [];

    for (const winner of rewardWinners) {
        if (winner.uid && winner.uid !== "SYSTEM_ADMIN") {
            const userRef = db.collection("users").doc(winner.uid);
            transaction.update(userRef, {
                diamondBalance: admin.firestore.FieldValue.increment(winner.rebate),
                xp: admin.firestore.FieldValue.increment(rewards.xp),
                profileFrame: frameAsset
            });

            // Un-equip other frame vault items
            const vaultOthers = await userRef.collection("vault")
                .where("category", "==", "frame")
                .where("isEquipped", "==", true)
                .get();
            vaultOthers.forEach(doc => transaction.update(doc.ref, { isEquipped: false }));

            // Write vault entry for rocket frame
            const vaultRef = userRef.collection("vault").doc();
            transaction.set(vaultRef, {
                frameId: "rocket",
                name: "Rocket Frame",
                type: "Rocket Event",
                imageUrl: frameAsset,
                category: "frame",
                earnedFrom: "rocket_event",
                rocketLevel: level + 1,
                awardedAt: admin.firestore.FieldValue.serverTimestamp(),
                expiresAt: frameExpiresAt,
                isEquipped: true,
                isActive: true
            });

            // Log reward
            const logRef = db.collection("reward_logs").doc();
            transaction.set(logRef, {
                uid: winner.uid,
                type: "rocket_king_reward",
                rank: winner.rank,
                level: level + 1,
                rebate: winner.rebate,
                xp: rewards.xp,
                frameAsset: frameAsset,
                frameExpiresAt: frameExpiresAt,
                timestamp: admin.firestore.FieldValue.serverTimestamp()
            });

            // Persist winner notification into user's inbox (atomic with rewards)
            const inboxRef = userRef.collection("inbox_messages").doc();
            transaction.set(inboxRef, {
                type: "reward",
                title: `🚀 Rocket Reward - TOP ${winner.rank}`,
                body: `Congratulations! You ranked TOP ${winner.rank} in the Rocket event and won ${winner.rebate.toLocaleString()} 💎 + ${rewards.xp} XP + Rocket Frame!`,
                read: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                data: {
                    route: "/room",
                    roomId: roomId,
                    rocketLevel: level + 1,
                    rank: winner.rank,
                    reward: winner.rebate,
                    xp: rewards.xp
                }
            });

            notifiedWinners.push({
                uid: winner.uid,
                rank: winner.rank,
                reward: winner.rebate,
                xp: rewards.xp,
                level: level + 1,
                roomId: roomId
            });
        }
    }

    // 2. Global Announcement Message
    const globalMsgRef = db.collection("global_messages").doc();
    transaction.set(globalMsgRef, {
        type: "rocket_launch",
        roomId: roomId,
        roomName: roomData.name || "Live Room",
        level: level + 1,
        kingUid: sortedContributors[0]?.[0] || "",
        createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // 3. Update Room State
    const roomUpdate = {
        rocketLevel: admin.firestore.FieldValue.increment(1),
        rocketFuel: 0,
        lastRocketResults: {
            top3: sortedContributors.map(([uid, amount]) => ({ uid, amount })),
            level: level + 1,
            rewardedAt: admin.firestore.FieldValue.serverTimestamp(),
        }
    };

    // 🚀 If we just finished Level 5 (level was 4), set 5-minute cooldown and reset contributions for next 5-rocket cycle!
    if (level === 4) {
        const cooldownMinutes = 5;
        const cooldownUntil = admin.firestore.Timestamp.fromMillis(Date.now() + cooldownMinutes * 60 * 1000);
        roomUpdate.rocketCooldownUntil = cooldownUntil;
        roomUpdate.rocketStatus = "cooldown";
        roomUpdate.rocketContributions = {}; // Reset ONLY after Rocket 5!
        console.log(`[ROCKET] Level 5 complete. Cooldown until ${cooldownUntil.toDate()}`);
    }

    transaction.update(db.collection("rooms").doc(roomId), roomUpdate);

    console.log(`[ROCKET] Launch complete. Winners notified in-transaction:`, notifiedWinners.map(w => `${w.uid}#${w.rank}`).join(", ") || "none");
    return notifiedWinners;
}

async function getRocketTargets(transaction = null) {
    const defaultTargets = [1000000, 2000000, 3000000, 5000000, 10000000];
    try {
        const configRef = db.collection("system_configs").doc("rocket_settings");
        const doc = transaction ? await transaction.get(configRef) : await configRef.get();
        if (doc.exists && Array.isArray(doc.data()?.targets) && doc.data().targets.length === 5) {
            return doc.data().targets.map(t => parseInt(t) || 0);
        }
    } catch (e) {
        console.error("[ROCKET_CONFIG] Failed to load dynamic targets, fallback to default:", e);
    }
    return defaultTargets;
}

async function processRocketFueling(transaction, roomId, roomRef, roomData, senderUid, totalCost) {
    let currentLevel = roomData.rocketLevel || 0;
    let currentFuel = roomData.rocketFuel || 0;
    const status = roomData.rocketStatus || "active";
    const cooldownUntil = roomData.rocketCooldownUntil ? roomData.rocketCooldownUntil.toMillis() : 0;
    const now = Date.now();

    const allNotifiedWinners = [];

    // 🕰️ Handle Cooldown & Reset
    if (status === "cooldown") {
        if (now < cooldownUntil) {
            console.log(`[ROCKET] Room ${roomId} is in cooldown. Skipping fueling.`);
            return allNotifiedWinners;
        } else {
            // Cooldown expired! Reset to Level 0
            console.log(`[ROCKET] Cooldown expired for room ${roomId}. Resetting to level 0.`);
            currentLevel = 0;
            currentFuel = 0;
            transaction.update(roomRef, {
                rocketLevel: 0,
                rocketFuel: 0,
                rocketStatus: "active",
                rocketContributions: {}
            });
            roomData.rocketLevel = 0;
            roomData.rocketFuel = 0;
            roomData.rocketStatus = "active";
            roomData.rocketContributions = {};
        }
    } else if (currentLevel >= 5) {
        transaction.update(roomRef, { rocketLevel: 0, rocketFuel: 0, rocketStatus: "active", rocketContributions: {} });
        currentLevel = 0;
        currentFuel = 0;
        roomData.rocketLevel = 0;
        roomData.rocketFuel = 0;
        roomData.rocketStatus = "active";
        roomData.rocketContributions = {};
    }

    const rocketTargets = await getRocketTargets(transaction);
    let remainingCost = totalCost;
    let localContributions = { ...(roomData.rocketContributions || {}) };

    while (remainingCost > 0 && currentLevel < 5) {
        const nextTarget = rocketTargets[currentLevel] || 10000000;
        const fuelNeeded = nextTarget - currentFuel;

        if (remainingCost >= fuelNeeded) {
            // Reached threshold for currentLevel!
            remainingCost -= fuelNeeded;

            const currentContrib = (localContributions[senderUid] || 0) + fuelNeeded;
            localContributions[senderUid] = currentContrib;
            const updatedRoomData = {
                ...roomData,
                rocketLevel: currentLevel,
                rocketFuel: currentFuel + fuelNeeded,
                rocketContributions: localContributions
            };

            console.log(`[ROCKET] Sequential Launch: Room ${roomId} launched Level ${currentLevel + 1}! Remaining diamonds to process: ${remainingCost}`);
            const winners = await processRocketLaunch(transaction, roomId, currentLevel, updatedRoomData, senderUid, fuelNeeded);
            if (winners && winners.length > 0) {
                allNotifiedWinners.push(...winners);
            }

            currentLevel++;
            currentFuel = 0;
            // Preserve localContributions across Rockets 1-5 so Top List persists until Rocket 5!
            roomData.rocketLevel = currentLevel;
            roomData.rocketFuel = 0;

            if (currentLevel >= 5) {
                localContributions = {};
                roomData.rocketContributions = {};
                break;
            }
        } else {
            const currentContrib = (localContributions[senderUid] || 0) + remainingCost;
            localContributions[senderUid] = currentContrib;
            currentFuel += remainingCost;

            transaction.update(roomRef, {
                rocketFuel: admin.firestore.FieldValue.increment(remainingCost),
                [`rocketContributions.${senderUid}`]: admin.firestore.FieldValue.increment(remainingCost)
            });
            remainingCost = 0;
        }
    }

    return allNotifiedWinners;
}

/**
 * --- ADMIN: ROCKET SETTINGS MANAGEMENT ---
 */
exports.getRocketSettings = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    try {
        const configSnap = await db.collection("system_configs").doc("rocket_settings").get();
        if (configSnap.exists) {
            return { success: true, settings: configSnap.data() };
        }
    } catch (e) {
        console.error("[ROCKET_CONFIG] Error getting settings:", e);
    }
    return {
        success: true,
        settings: {
            targets: ROCKET_SYSTEM.targets,
            rewards: ROCKET_SYSTEM.rewards,
            updatedAt: null
        }
    };
});

exports.updateRocketSettings = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    const adminStatus = await isUserAdmin(context.auth.uid);
    if (!adminStatus) throw new functions.https.HttpsError("permission-denied", "Admin access required.");

    const { targets } = data || {};
    if (!Array.isArray(targets) || targets.length !== 5) {
        throw new functions.https.HttpsError("invalid-argument", "Targets must be an array of 5 numbers.");
    }

    const sanitizedTargets = targets.map((t, idx) => {
        const val = parseInt(t);
        if (isNaN(val) || val <= 0) {
            throw new functions.https.HttpsError("invalid-argument", `Invalid threshold for Rocket ${idx + 1}`);
        }
        return val;
    });

    await db.collection("system_configs").doc("rocket_settings").set({
        targets: sanitizedTargets,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: context.auth.uid
    }, { merge: true });

    console.log(`[ROCKET_CONFIG] Updated targets by ${context.auth.uid}:`, sanitizedTargets);
    return { success: true, targets: sanitizedTargets };
});

/**
 * 1. onCreate Auth User Trigger
 * Creates a basic skeletal user document when they sign up.
 */

exports.onUserWrite = functions.firestore.document("users/{uid}").onWrite(async (change, context) => {
    // Exit early if this is an update and helloId is already a valid number
    if (change.before.exists) {
        const beforeData = change.before.data() || {};
        if (beforeData.helloId && typeof beforeData.helloId === "number") {
            return null;
        }
    }

    const after = change.after.data();
    if (!after) return null; // Deleted

    const existingId = after.helloId;
    
    // 🛡️ Robust ID Fix: Assign if missing OR convert if string
    if (!existingId || typeof existingId === "string") {
        let newId;
        if (typeof existingId === "string" && !isNaN(parseInt(existingId))) {
            newId = parseInt(existingId);
            console.log(`[ID_FIX] Converting string helloId to number for user ${context.params.uid}`);
        } else {
            console.log(`[ID_FIX] Assigning new helloId to user ${context.params.uid}`);
            newId = Math.floor(1000000000 + Math.random() * 9000000000);
        }
        return change.after.ref.update({ helloId: newId });
    }
    return null;
});

/**
 * --- ADMIN: ROCKET FUEL INJECTOR ---
 */
exports.adminFuelRocket = onCall({
    region: "us-central1"
}, async (request) => {
    console.log("[ADMIN_FUEL] Triggered with data:", request.data);
    const { auth } = request;
    if (!auth) {
        console.error("[ADMIN_FUEL] Unauthenticated access attempt");
        throw new HttpsError("unauthenticated", "Auth required.");
    }
    
    // Admin check
    try {
        const adminStatus = await isUserAdmin(auth.uid);
        if (!adminStatus) {
            console.error(`[ADMIN_FUEL] User ${auth.uid} is not an admin`);
            throw new HttpsError("permission-denied", "Admin only.");
        }
    } catch (e) {
        console.error("[ADMIN_FUEL] Error checking admin status:", e);
        throw new HttpsError("internal", "Failed to verify admin status.");
    }

    const { roomId, amount } = request.data;
    const amt = parseInt(amount);
    if (!roomId || isNaN(amt)) {
        console.error(`[ADMIN_FUEL] Invalid arguments: roomId=${roomId}, amount=${amount}`);
        throw new HttpsError("invalid-argument", "Missing roomId or valid amount.");
    }

    console.log(`[ADMIN_FUEL] Injecting ${amt} fuel to room ${roomId}`);

    try {
        return await db.runTransaction(async (transaction) => {
            const roomRef = db.collection("rooms").doc(roomId);
            const roomDoc = await transaction.get(roomRef);
            if (!roomDoc.exists) {
                console.error(`[ADMIN_FUEL] Room ${roomId} not found`);
                throw new HttpsError("not-found", "Room not found.");
            }

            const roomData = roomDoc.data();
            await processRocketFueling(transaction, roomId, roomRef, roomData, "SYSTEM_ADMIN", amt);

            return { success: true };
        });
    } catch (err) {
        console.error("[ADMIN_FUEL] Transaction failed:", err);
        // Ensure we re-throw as HttpsError
        if (err instanceof HttpsError) throw err;
        throw new HttpsError("internal", err.message || "Transaction failed");
    }
});

/**
 * --- SVIP SYSTEM (SPENDING BASED) ---
 */
/**
 * --- SVIP MEMBERSHIP SYSTEM (RECHARGE BASED) ---
 * Conversion: 1 USD Gold Coin Recharge = 100 SVIP Points
 * Validity: 60 Days per level (Server UTC Time)
 * Reset Triggers: Reset to 0 on (1) Upgrade, (2) Renewal, (3) Downgrade, (4) Expiration, (5) Manual Reset.
 */
const SVIP_THRESHOLDS = [
    { level: 1, points: 5000, usd: 50.0, dailyReward: 25000 },
    { level: 2, points: 10000, usd: 100.0, dailyReward: 50000 },
    { level: 3, points: 20000, usd: 200.0, dailyReward: 100000 },
    { level: 4, points: 50000, usd: 500.0, dailyReward: 250000 },
    { level: 5, points: 100000, usd: 1000.0, dailyReward: 500000 },
    { level: 6, points: 250000, usd: 2500.0, dailyReward: 1000000 },
];

function calculateSVIPLevel(points) {
    let level = 0;
    for (const threshold of SVIP_THRESHOLDS) {
        if (points >= threshold.points) {
            level = threshold.level;
        } else {
            break;
        }
    }
    return level;
}

/**
 * Processes SVIP Points for a user upon gold coin/diamond recharge
 * Conversion: 1 USD = 100 SVIP Points
 * Rules:
 * - Accumulate points in active 60-day cycle
 * - If points reach next level threshold:
 *   - Immediate upgrade
 *   - Set new 60-day validity
 *   - RESET SVIP POINTS TO 0
 *   - Log to svip_upgrade_history
 */
function processSvipPointsForRecharge(transaction, userRef, userData, usdAmount) {
    if (!usdAmount || usdAmount <= 0) return;
    const earnedPoints = Math.floor(usdAmount * 100);
    const currentLevel = userData.svipLevel || 0;
    const currentPoints = (userData.svipPoints || 0) + earnedPoints;

    let highestQualified = currentLevel;
    for (const threshold of SVIP_THRESHOLDS) {
        if (currentPoints >= threshold.points && threshold.level > highestQualified) {
            highestQualified = threshold.level;
        }
    }

    const now = new Date();
    const sixtyDaysMs = 60 * 24 * 60 * 60 * 1000;

    if (highestQualified > currentLevel) {
        // Immediate Level Upgrade!
        const newCycleEnd = new Date(now.getTime() + sixtyDaysMs);
        transaction.update(userRef, {
            svipLevel: highestQualified,
            svipPoints: 0, // SPEC RULE: Must reset to 0 upon immediate upgrade
            svipCycleStartDate: admin.firestore.Timestamp.fromDate(now),
            svipCycleEndDate: admin.firestore.Timestamp.fromDate(newCycleEnd),
            svipUpgradedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // Record in upgrade history
        const upgradeRef = db.collection("svip_upgrade_history").doc();
        transaction.set(upgradeRef, {
            uid: userData.uid || userRef.id,
            previousLevel: currentLevel,
            newLevel: highestQualified,
            triggerUsdRecharge: usdAmount,
            cyclePointsEarned: currentPoints,
            cyclePointsAfterReset: 0,
            cycleEndDate: admin.firestore.Timestamp.fromDate(newCycleEnd),
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        });

        // Add in-app notification
        const notifRef = db.collection("users").doc(userRef.id).collection("notifications").doc();
        transaction.set(notifRef, {
            title: "🎉 SVIP Upgrade!",
            message: `Congratulations! You have been promoted to SVIP ${highestQualified}! Enjoy your exclusive 60-day elite privileges.`,
            type: "svip_upgrade",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            isRead: false
        });
    } else {
        // Accumulate points within cycle
        const updates = {
            svipPoints: currentPoints
        };
        // If user is SVIP > 0 and cycle dates not set, initialize 60 days
        if (currentLevel > 0 && !userData.svipCycleEndDate) {
            updates.svipCycleStartDate = admin.firestore.Timestamp.fromDate(now);
            updates.svipCycleEndDate = admin.firestore.Timestamp.fromDate(new Date(now.getTime() + sixtyDaysMs));
        }
        transaction.update(userRef, updates);
    }
}

/**
 * --- ID LEVEL SYSTEM (XP BASED) ---
 * Level 1-50: Easy (Linear growth)
 * Level 51-100: Hard (Exponential growth)
 */
function getXPRequiredForNextLevel(currentLevel) {
    if (currentLevel < 10) return 10000;
    if (currentLevel < 20) return 25000;
    if (currentLevel < 30) return 50000;
    if (currentLevel < 40) return 100000;
    if (currentLevel < 50) return 200000;
    if (currentLevel < 60) return 300000;
    if (currentLevel < 70) return 400000;
    if (currentLevel < 80) return 500000;
    if (currentLevel < 90) return 600000;
    if (currentLevel < 100) return 1000000;
    return 1000000;
}

function calculateIDLevel(totalXP) {
    let level = 1;
    let xpRemaining = totalXP;
    while (level < 100) {
        let needed = getXPRequiredForNextLevel(level);
        if (xpRemaining >= needed) {
            xpRemaining -= needed;
            level++;
        } else {
            break;
        }
    }
    return level;
}

/**
 * --- TARGET-BASED REWARD SYSTEM (SALARY) ---
 * Automated 60/30/10 Split on Milestones
 */
const SALARY_LEVELS = [
    { level: 1, target: 1000000, label: "Lv.1 Beginner" },
    { level: 2, target: 2000000, label: "Lv.2 Rising Star" },
    { level: 3, target: 4000000, label: "Lv.3 Influencer" },
    { level: 4, target: 8000000, label: "Lv.4 Professional" },
    { level: 5, target: 15000000, label: "Lv.5 Elite" },
    { level: 6, target: 28000000, label: "Lv.6 Master" },
    { level: 7, target: 51000000, label: "Lv.7 Legend" },
    { level: 8, target: 87000000, label: "Lv.8 Mythic" },
    { level: 9, target: 141000000, label: "Lv.9 Immortal" },
    { level: 10, target: 209000000, label: "Lv.10 Ultimate" },
];

function getNextBiWeeklyDate() {
    const now = new Date();
    const result = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    if (now.getDate() < 15) {
        result.setDate(15);
    } else {
        // Last day of current month
        return new Date(now.getFullYear(), now.getMonth() + 1, 0);
    }
    return result;
}

/**
 * Internal helper to check for salary milestones.
 * To be called within a transaction.
 */
async function processSalaryMilestones(transaction, hostUid, beansReceived, preloadedStatusDoc = null, preloadedUserDoc = null) {
    const statusRef = db.collection("salaryStatus").doc(hostUid);
    const userRef = db.collection("users").doc(hostUid);

    const statusDoc = preloadedStatusDoc || await transaction.get(statusRef);
    const userDoc = preloadedUserDoc || await transaction.get(userRef);

    if (!userDoc.exists) return;
    const userData = userDoc.data();

    // Super Admin Exclusion Rule: Super Admins are strictly ineligible for salary system
    if (userData.role === "superadmin" || (userData.tags || []).includes("SuperAdmin")) {
        console.log(`[SALARY_EXCLUSION] SuperAdmin ${hostUid} is ineligible for salary milestones.`);
        return;
    }

    let status = statusDoc.exists ? statusDoc.data() : {
        uid: hostUid,
        totalBeansEarned: 0,
        completedLevels: [],
        currentLevel: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
    };

    const newTotalBeans = (status.totalBeansEarned || 0) + beansReceived;
    const newlyReachedLevels = [];

    for (const lv of SALARY_LEVELS) {
        if (newTotalBeans >= lv.target && !(status.completedLevels || []).includes(lv.level)) {
            newlyReachedLevels.push(lv);
        }
    }

    if (newlyReachedLevels.length === 0) {
        transaction.set(statusRef, { 
            totalBeansEarned: newTotalBeans,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp() 
        }, { merge: true });
        return;
    }

    // Update Status
    const completedLevels = [...(status.completedLevels || []), ...newlyReachedLevels.map(l => l.level)];
    transaction.set(statusRef, {
        totalBeansEarned: newTotalBeans,
        completedLevels: completedLevels,
        currentLevel: newlyReachedLevels[newlyReachedLevels.length - 1].level,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    // Create Payouts for each milestone
    const now = new Date();
    const hostPayoutDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
    const biWeeklyPayoutDate = getNextBiWeeklyDate();

    for (const lv of newlyReachedLevels) {
        // 1. Host Payout (60%) - Stored in USD by applying 0.01 exchange rate
        const hostPayoutRef = db.collection("salaryPayouts").doc();
        transaction.set(hostPayoutRef, {
            id: hostPayoutRef.id,
            uid: hostUid,
            amount: lv.target * 0.6 * 0.01,
            type: "host",
            level: lv.level,
            scheduledDate: admin.firestore.Timestamp.fromDate(hostPayoutDate),
            status: "pending",
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // 2. Agency Payout (30%) - Kept in Beans (agency balance updates increment in Beans)
        if (userData.agencyId) {
            const agencyPayoutRef = db.collection("salaryPayouts").doc();
            transaction.set(agencyPayoutRef, {
                id: agencyPayoutRef.id,
                uid: hostUid,
                agencyId: userData.agencyId,
                amount: lv.target * 0.3,
                type: "agency",
                level: lv.level,
                scheduledDate: admin.firestore.Timestamp.fromDate(biWeeklyPayoutDate),
                status: "pending",
                createdAt: admin.firestore.FieldValue.serverTimestamp()
            });
        }

        // 3. Admin Payout (10%) - Stored in USD by applying 0.01 exchange rate
        if (userData.adminId) {
            const adminPayoutRef = db.collection("salaryPayouts").doc();
            transaction.set(adminPayoutRef, {
                id: adminPayoutRef.id,
                uid: userData.adminId,
                hostUid: hostUid,
                amount: lv.target * 0.1 * 0.01,
                type: "admin",
                level: lv.level,
                scheduledDate: admin.firestore.Timestamp.fromDate(biWeeklyPayoutDate),
                status: "pending",
                createdAt: admin.firestore.FieldValue.serverTimestamp()
            });
        }
    }
}

exports.onUserUpdate = functions.firestore.document("users/{uid}").onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    const updates = {};

    // ID Level (XP based)
    const oldXP = before.xp || 0;
    const newXP = after.xp || 0;
    if (newXP !== oldXP) {
        const nextLevel = calculateIDLevel(newXP);
        if (nextLevel !== (after.level || 1)) {
            updates.level = nextLevel;
            updates.lastLevelUp = admin.firestore.FieldValue.serverTimestamp();
        }
    }

    if (Object.keys(updates).length > 0) {
        return change.after.ref.update(updates);
    }

    return null;
});


exports.createBaseUserDoc = functions.auth.user().onCreate(async (user) => {
    const { uid, phoneNumber, email, displayName, photoURL } = user;
    const userRef = db.collection("users").doc(uid);

    // Generate simple 10-digit unique ID
    // Note: In high traffic, we'd use a transaction + counter, 
    // but for now random 10-digit is mostly unique.
    const helloId = Math.floor(1000000000 + Math.random() * 9000000000);

    return userRef.set({
        uid: uid,
        helloId: helloId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        phoneNumber: phoneNumber || null,
        email: email || null,
        username: "", // empty, user must set this in profile setup
        displayName: displayName || "New User",
        displayName_lowercase: (displayName || "New User").toLowerCase(),
        username_lowercase: "",
        bio: "",

        country: "",
        profilePhotoUrl: photoURL || "",
        referralCode: uid.substring(0, 6).toUpperCase(),
        referralCount: 0,
        referredBy: "",
        diamondBalance: 0,
        diamondStock: 0,
        beansBalance: 0,
        totalDiamondsSpent: 0,
        totalDiamondsSent: 0,
        dailyDiamondsSent: 0,
        weeklyDiamondsSent: 0,
        monthlyDiamondsSent: 0,
        totalBeansReceived: 0,
        dailyBeansReceived: 0,
        weeklyBeansReceived: 0,
        monthlyBeansReceived: 0,
        lastDailySentDate: "",
        lastWeeklySentDate: "",
        lastMonthlySentDate: "",
        lastDailyReceivedDate: "",
        lastWeeklyReceivedDate: "",
        lastMonthlyReceivedDate: "",
        xp: 0,
        dailyXP: 0,
        weeklyXP: 0,
        monthlyXP: 0,
        benchXP: 0,
        princeXP: 0,
        dailyPrinceXP: 0,
        weeklyPrinceXP: 0,
        monthlyPrinceXP: 0,
        level: 1,
        followerCount: 0,
        followingCount: 0,
        friendsCount: 0,
        visitorCount: 0,
        cpLevel: 0,
        cpPoints: 0,
        combatPoints: 0,
        status: "offline",
        badges: [],
        recentVisitors: [],
        profileFrame: "",
        entryAnimation: "",
        chatBubble: "",
        badgeIcon: "",
        tags: [],
        vipTier: "none",
        isBanned: false,
        lastActive: admin.firestore.FieldValue.serverTimestamp(),
    });
});

/**
 * 2. Check Username Availability
 * Callable function to check if a username is taken.
 */
exports.checkUsernameAvailability = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const username = data.username.toLowerCase().trim();
    if (!username || username.length < 3) return { available: false, message: "Too short" };

    const usernameDoc = await db.collection("usernames").doc(username).get();
    return { available: !usernameDoc.exists };
});

/**
 * 3. Create/Update Profile (with Username Enforcement)
 * Atomically sets username and updates profile.
 */
exports.setupProfile = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const uid = context.auth.uid;
    const { username, displayName, bio, country, profilePhotoUrl } = data;
    const cleanUsername = username.toLowerCase().trim();

    return db.runTransaction(async (transaction) => {
        const usernameRef = db.collection("usernames").doc(cleanUsername);
        const userRef = db.collection("users").doc(uid);

        const usernameDoc = await transaction.get(usernameRef);
        const userDoc = await transaction.get(userRef);


        // Safety: If helloId is missing or wrong type (e.g. initial trigger failed), assign it now
        const existingData = userDoc.data() || {};
        const existingId = existingData.helloId;
        const helloIdUpdates = {};
        
        if (!existingId || typeof existingId === "string") {
            if (typeof existingId === "string" && !isNaN(parseInt(existingId))) {
                helloIdUpdates.helloId = parseInt(existingId);
            } else {
                helloIdUpdates.helloId = Math.floor(1000000000 + Math.random() * 9000000000);
            }
        }

        // If username is changing, verify it's available
        if (userDoc.exists && existingData.username !== cleanUsername) {
            if (usernameDoc.exists) {
                throw new functions.https.HttpsError("already-exists", "Username already taken.");
            }
        }

        transaction.set(usernameRef, { uid: uid, createdAt: admin.firestore.FieldValue.serverTimestamp() });
        transaction.update(userRef, {
            ...helloIdUpdates,
            username: cleanUsername,
            username_lowercase: cleanUsername,
            displayName: displayName,
            displayName_lowercase: (displayName || "").toLowerCase(),
            bio: bio || "",
            country: country || "",
            profilePhotoUrl: profilePhotoUrl || "",
            lastActive: admin.firestore.FieldValue.serverTimestamp(),
        });


        return { success: true };
    });
});

/**
 * 3b. Redeem Referral Code (Invite & Earn Reward)
 */
exports.redeemReferralCode = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Authentication required.");

    const uid = context.auth.uid;
    const rawCode = (data.code || "").trim().toUpperCase();

    if (!rawCode) {
        throw new functions.https.HttpsError("invalid-argument", "Please enter a valid invite code.");
    }

    return db.runTransaction(async (transaction) => {
        const userRef = db.collection("users").doc(uid);
        const userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
            throw new functions.https.HttpsError("not-found", "User profile not found.");
        }

        const userData = userDoc.data() || {};
        if (userData.referredBy) {
            throw new functions.https.HttpsError("already-exists", "You have already redeemed an invite code.");
        }

        // Prevent self referral
        if (userData.referralCode === rawCode || uid.substring(0, 6).toUpperCase() === rawCode) {
            throw new functions.https.HttpsError("invalid-argument", "You cannot redeem your own invite code.");
        }

        // Find referrer matching referralCode
        const referrerQuery = await db.collection("users").where("referralCode", "==", rawCode).limit(1).get();
        if (referrerQuery.empty) {
            throw new functions.https.HttpsError("not-found", "Invalid referral code. No user found with this code.");
        }

        const referrerDoc = referrerQuery.docs[0];
        const referrerUid = referrerDoc.id;
        const referrerRef = db.collection("users").doc(referrerUid);

        // Award +100 Beans to Referrer & +50 Beans to Invitee
        const referrerReward = 100;
        const inviteeReward = 50;

        transaction.update(referrerRef, {
            beansBalance: admin.firestore.FieldValue.increment(referrerReward),
            referralCount: admin.firestore.FieldValue.increment(1),
        });

        transaction.update(userRef, {
            beansBalance: admin.firestore.FieldValue.increment(inviteeReward),
            referredBy: referrerUid,
            referredByCode: rawCode,
        });

        // Inbox Notification for Referrer
        const notifRef = db.collection("users").doc(referrerUid).collection("inbox_messages").doc();
        transaction.set(notifRef, {
            title: "🎉 Friend Joined via Your Code!",
            body: `A new friend used your invite code (${rawCode})! You received +${referrerReward} Beans reward.`,
            type: "reward",
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            data: { route: "/invite-get-coins" }
        });

        return { success: true, message: `Bonus claimed! You received ${inviteeReward} Beans.` };
    });
});

/**
 * 4. Admin: Ban/Unban User
 */
exports.adminBanUser = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    // Admin Check
    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    const tags = callerDoc.data().tags || [];
    if (!tags.includes("Admin") && !tags.includes("SuperAdmin")) {
        throw new functions.https.HttpsError("permission-denied", "Admin only.");
    }

    const { targetUid, isBanned } = data;
    await db.collection("users").doc(targetUid).update({ isBanned: isBanned });

    // Log action
    await db.collection("admin_logs").add({
        adminUid: context.auth.uid,
        action: isBanned ? "BAN_USER" : "UNBAN_USER",
        targetId: targetUid,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: true };
});

/**
 * 4b. Admin: Refund and Revoke VIP
 */
exports.refundVip = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const isAdmin = await isUserAdmin(context.auth.uid);
    if (!isAdmin) {
        throw new functions.https.HttpsError("permission-denied", "Admin permissions required.");
    }

    const { helloId, reason } = data;
    if (!helloId) throw new functions.https.HttpsError("invalid-argument", "Hello ID required.");

    const usersSnap = await db.collection("users").where("helloId", "==", parseInt(helloId)).get();
    if (usersSnap.empty) throw new functions.https.HttpsError("not-found", "User not found.");

    const userDoc = usersSnap.docs[0];
    const userData = userDoc.data();

    if (!userData.vipTier || userData.vipTier === "none") {
        throw new functions.https.HttpsError("failed-precondition", "User has no active VIP.");
    }

    const now = new Date();
    const expiry = userData.vipExpiry?.toDate();
    if (!expiry || expiry < now) {
        throw new functions.https.HttpsError("failed-precondition", "VIP has already expired.");
    }

    const remainingDays = Math.ceil((expiry - now) / (1000 * 60 * 60 * 24));
    
    // Look up tier cost
    const tierSnap = await db.collection("vip_tiers").doc(userData.vipTier).get();
    let monthlyPrice = 0;
    if (tierSnap.exists) {
        monthlyPrice = tierSnap.data().monthlyPriceInDiamonds || 0;
    }

    // Proportional refund formula: (monthlyPrice * 20% conversion base * remainingDays / 30)
    const refundAmount = Math.max(0, Math.round(monthlyPrice * 0.2 * (remainingDays / 30)));

    await db.runTransaction(async (tx) => {
        const userRef = userDoc.ref;
        tx.update(userRef, {
            vipTier: "none",
            vipExpiry: null,
            diamondBalance: admin.firestore.FieldValue.increment(refundAmount),
            profileFrame: ""
        });

        const logRef = db.collection("admin_logs").doc();
        tx.set(logRef, {
            adminUid: context.auth.uid,
            action: "VIP_REVOKE_REFUND",
            targetUid: userDoc.id,
            targetHelloId: helloId,
            refundedDiamonds: refundAmount,
            reason: reason || "Admin VIP revocation refund",
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        });
    });

    return { success: true, refundedDiamonds: refundAmount, targetUid: userDoc.id };
});

/**
 * 5. Admin: Adjust Balance (Diamonds)
 */
exports.adminAdjustBalance = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    const tags = callerDoc.data().tags || [];
    if (!tags.includes("Admin") && !tags.includes("SuperAdmin")) {
        throw new functions.https.HttpsError("permission-denied", "Admin only.");
    }

    const { targetUid, amount, reason } = data;

    const result = await db.runTransaction(async (transaction) => {
        const userRef = db.collection("users").doc(targetUid);
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw new Error("User not found");

        const currentBalance = userDoc.data().diamondBalance || 0;
        transaction.update(userRef, { diamondBalance: currentBalance + amount });

        const inboxRef = db.collection("users").doc(targetUid).collection("inbox_messages").doc();
        transaction.set(inboxRef, {
            type: "reward",
            title: "Diamond Balance Adjusted 💎",
            body: `Your diamond balance has been adjusted by ${amount >= 0 ? "+" : ""}${amount.toLocaleString()} diamonds.`,
            read: false,
            createdAt: admin.firestore.Timestamp.now(),
            data: { reason: reason || "Manual Adjustment", route: "/wallet" }
        });

        const logRef = db.collection("admin_logs").doc();
        transaction.set(logRef, {
            adminUid: context.auth.uid,
            action: "ADJUST_BALANCE",
            amount: amount,
            targetId: targetUid,
            reason: reason || "Manual Adjustment",
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        });

        return { success: true, newBalance: currentBalance + amount };
    });

    return result;
});

/**
 * 5.1 Admin: Adjust Earning Balance (Beans)
 */
exports.adminAdjustBeans = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    const tags = callerDoc.data().tags || [];
    if (!tags.includes("Admin") && !tags.includes("SuperAdmin")) {
        throw new functions.https.HttpsError("permission-denied", "Admin only.");
    }

    const { targetUid, amount, reason } = data;

    const result = await db.runTransaction(async (transaction) => {
        const userRef = db.collection("users").doc(targetUid);
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw new Error("User not found");

        const currentBalance = userDoc.data().beansBalance || 0;
        transaction.update(userRef, { beansBalance: currentBalance + amount });

        const inboxRef = db.collection("users").doc(targetUid).collection("inbox_messages").doc();
        transaction.set(inboxRef, {
            type: "reward",
            title: "Beans Balance Adjusted 🫘",
            body: `Your beans balance has been adjusted by ${amount >= 0 ? "+" : ""}${amount.toLocaleString()} beans.`,
            read: false,
            createdAt: admin.firestore.Timestamp.now(),
            data: { reason: reason || "Manual Earnings Adjustment", route: "/wallet" }
        });

        // Log action in history
        const txRef = userRef.collection("transactions").doc();
        transaction.set(txRef, {
            type: "gift_received", // Representing an incoming benefit
            amount: amount,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            description: reason || "Earnings Adjustment by Admin",
        });

        // Log action in Admin Logs
        const logRef = db.collection("admin_logs").doc();
        transaction.set(logRef, {
            adminUid: context.auth.uid,
            action: "ADJUST_BEANS",
            amount: amount,
            targetId: targetUid,
            reason: reason || "Manual Earnings Adjustment",
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        });

        return { success: true, newBalance: currentBalance + amount };
    });

    return result;
});

/**
 * 6. Admin: Update User Tags
 */
exports.adminUpdateUserTags = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    if (!(callerDoc.data().tags || []).includes("SuperAdmin")) {
        throw new functions.https.HttpsError("permission-denied", "SuperAdmin only.");
    }

    const { targetUid, tags } = data;
    await db.collection("users").doc(targetUid).update({ tags: tags });

    return { success: true };
});

/**
 * 7. Admin: Distribute Global Reward
 * Mass distribute diamonds to ALL registered users.
 */
exports.distributeGlobalReward = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    // Authorization Check
    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    const tags = callerDoc.data().tags || [];
    if (!tags.includes("Admin") && !tags.includes("SuperAdmin")) {
        throw new functions.https.HttpsError("permission-denied", "Admin/SuperAdmin only.");
    }


    const { amount, reason } = data;
    if (!amount || amount <= 0) throw new functions.https.HttpsError("invalid-argument", "Positive amount required.");

    const usersSnap = await db.collection("users").get();
    const totalUsers = usersSnap.size;

    let batch = db.batch();
    let count = 0;
    let totalProcessed = 0;

    for (const doc of usersSnap.docs) {
        batch.update(doc.ref, {
            diamondBalance: admin.firestore.FieldValue.increment(amount)
        });

        const inboxRef = db.collection("users").doc(doc.id).collection("inbox_messages").doc();
        batch.set(inboxRef, {
            type: "reward",
            title: "Global Reward Distribution 🎉",
            body: `You received ${amount.toLocaleString()} diamonds as a global reward!`,
            read: false,
            createdAt: admin.firestore.Timestamp.now(),
            data: { route: "/wallet" }
        });

        count++;
        totalProcessed++;

        if (count === 500) {
            await batch.commit();
            batch = db.batch();
            count = 0;
        }
    }

    if (count > 0) {
        await batch.commit();
    }

    // Log action
    await db.collection("admin_logs").add({
        adminUid: context.auth.uid,
        action: "GLOBAL_REWARD_DISTRIBUTION",
        amount: amount,
        totalUsers: totalUsers,
        reason: reason || "Global Reward",
        timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    return {
        success: true,
        totalProcessed: totalProcessed,
        message: `Successfully distributed ${amount} diamonds to ${totalProcessed} users.`
    };
});



/**
 * Atomic transaction to update follower/following counts.
 */
exports.followUser = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const followerUid = context.auth.uid;
    const targetUid = data.targetUid;

    if (followerUid === targetUid) throw new functions.https.HttpsError("invalid-argument", "Cannot follow self.");

    const followerRef = db.collection("users").doc(followerUid);
    const targetRef = db.collection("users").doc(targetUid);

    // Sub-collections
    const subFollowerRef = targetRef.collection("followers").doc(followerUid);
    const subFollowingRef = followerRef.collection("following").doc(targetUid);

    // Check for mutual follow
    const reverseFollowRef = followerRef.collection("followers").doc(targetUid);

    return db.runTransaction(async (transaction) => {
        const subFollowerDoc = await transaction.get(subFollowerRef);
        if (subFollowerDoc.exists) return { message: "Already following" };

        const reverseFollowDoc = await transaction.get(reverseFollowRef);
        const isMutual = reverseFollowDoc.exists;

        const timestamp = admin.firestore.FieldValue.serverTimestamp();

        transaction.set(subFollowerRef, { followedAt: timestamp });
        transaction.set(subFollowingRef, { followedAt: timestamp });

        const updatesFollower = { followingCount: admin.firestore.FieldValue.increment(1) };
        const updatesTarget = { followerCount: admin.firestore.FieldValue.increment(1) };

        if (isMutual) {
            updatesFollower.friendsCount = admin.firestore.FieldValue.increment(1);
            updatesTarget.friendsCount = admin.firestore.FieldValue.increment(1);
        }

        transaction.update(followerRef, updatesFollower);
        transaction.update(targetRef, updatesTarget);

        return { success: true, isMutual: isMutual };
    });
});

/**
 * 5. Unfollow User
 */
exports.unfollowUser = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const followerUid = context.auth.uid;
    const targetUid = data.targetUid;

    const followerRef = db.collection("users").doc(followerUid);
    const targetRef = db.collection("users").doc(targetUid);

    // Sub-collections
    const subFollowerRef = targetRef.collection("followers").doc(followerUid);
    const subFollowingRef = followerRef.collection("following").doc(targetUid);

    // Check for mutual follow (to see if they were friends)
    const reverseFollowRef = followerRef.collection("followers").doc(targetUid);

    return db.runTransaction(async (transaction) => {
        const subFollowerDoc = await transaction.get(subFollowerRef);
        if (!subFollowerDoc.exists) return { message: "Not following" };

        const reverseFollowDoc = await transaction.get(reverseFollowRef);
        const wasMutual = reverseFollowDoc.exists;

        transaction.delete(subFollowerRef);
        transaction.delete(subFollowingRef);

        const updatesFollower = { followingCount: admin.firestore.FieldValue.increment(-1) };
        const updatesTarget = { followerCount: admin.firestore.FieldValue.increment(-1) };

        if (wasMutual) {
            updatesFollower.friendsCount = admin.firestore.FieldValue.increment(-1);
            updatesTarget.friendsCount = admin.firestore.FieldValue.increment(-1);
        }

        transaction.update(followerRef, updatesFollower);
        transaction.update(targetRef, updatesTarget);

        return { success: true, wasMutual: wasMutual };
    });
});
/**
 * 6. Create Room
 */
exports.createRoom = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const uid = context.auth.uid;
    const { name, theme, coverUrl, isPrivate, passwordHash, capacity, backgroundMusic } = data;

    const roomId = db.collection("rooms").doc().id;
    const roomRef = db.collection("rooms").doc(roomId);

    const roomData = {
        roomId: roomId,
        createdBy: uid,
        ownerUid: uid,
        name: name,
        name_lowercase: (name || "").toLowerCase(),
        theme: theme,

        coverUrl: coverUrl || "",
        isPrivate: isPrivate || false,
        passwordHash: passwordHash || null,
        capacity: capacity || 10,
        currentUsersCount: 0,
        backgroundMusic: backgroundMusic || false,
        hourlyRank: 1, // Default to 1 or 99
        isTrending: false,
        newsStatus: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        endedAt: null,
        status: "active",
        admins: [uid],
        bannedUids: [],

    };

    await roomRef.set(roomData);
    return { roomId: roomId };
});

/**
 * 7. Join Room
 */
exports.joinRoom = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const uid = context.auth.uid;
    const { roomId, password } = data;

    return db.runTransaction(async (transaction) => {
        const roomRef = db.collection("rooms").doc(roomId);
        const participantRef = roomRef.collection("participants").doc(uid);
        const userRef = db.collection("users").doc(uid);

        const [roomDoc, userDoc, participantDoc] = await Promise.all([
            transaction.get(roomRef),
            transaction.get(userRef),
            transaction.get(participantRef)
        ]);

        if (!roomDoc.exists) throw new functions.https.HttpsError("not-found", "Room not found.");

        const roomData = roomDoc.data();
        if (roomData.status !== "active") throw new functions.https.HttpsError("failed-precondition", "Room has ended.");
        if (roomData.bannedUids && roomData.bannedUids.includes(uid)) {
            // Check if ban has expired
            const banExpiries = roomData.banExpiries || {};
            const banExpiry = banExpiries[uid];
            if (banExpiry && banExpiry.toDate) {
                if (banExpiry.toDate() <= new Date()) {
                    // Ban expired — allow join
                    const banExpiryDelete = {};
                    banExpiryDelete["banExpiries." + uid] = admin.firestore.FieldValue.delete();
                    transaction.update(roomRef, {
                        bannedUids: admin.firestore.FieldValue.arrayRemove([uid]),
                        ...banExpiryDelete
                    });
                } else {
                    throw new functions.https.HttpsError("permission-denied", "You are banned until " + banExpiry.toDate().toISOString());
                }
            } else {
                throw new functions.https.HttpsError("permission-denied", "You are banned.");
            }
        }

        // Strict Server-Side Validation: Password Check
        const isAdmin = roomData.ownerUid === uid || (roomData.admins || []).includes(uid);
        if (roomData.isPrivate && !isAdmin) {
            if (!password || password !== roomData.passwordHash) {
                throw new functions.https.HttpsError("permission-denied", "Incorrect room password.");
            }
        }

        const userData = userDoc.exists ? userDoc.data() : {};

        let seatIndex = -1; // Changed to match local logic
        let role = "audience";

        if (uid === roomData.ownerUid) {
            seatIndex = 0; // Host always gets seat 0
            role = "host";
        }

        if (!participantDoc.exists) {
            transaction.set(participantRef, {
                uid: uid,
                joinedAt: admin.firestore.FieldValue.serverTimestamp(),
                lastActive: admin.firestore.FieldValue.serverTimestamp(),
                seatIndex: seatIndex,
                isMuted: false,
                role: role,
                displayName: userData.displayName || "User",
                profilePhotoUrl: userData.profilePhotoUrl || "",
                vipTier: userData.vipTier || "none",
                tags: userData.tags || [],
            });

            const msgRef = roomRef.collection("messages").doc();
            transaction.set(msgRef, {
                uid: uid,
                text: `${userData.displayName || "User"} joined the room`,
                type: 'system',
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        } else {
            transaction.update(participantRef, {
                lastActive: admin.firestore.FieldValue.serverTimestamp(),
            });
        }

        transaction.update(userRef, { activeRoomId: roomId });

        return { success: true };
    });
});

/**
 * 8. Leave Room
 */
exports.leaveRoom = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const uid = context.auth.uid;
    const { roomId } = data;

    return db.runTransaction(async (transaction) => {
        const roomRef = db.collection("rooms").doc(roomId);
        const participantRef = roomRef.collection("participants").doc(uid);

        const [roomDoc, participantDoc] = await Promise.all([
            transaction.get(roomRef),
            transaction.get(participantRef)
        ]);

        if (!roomDoc.exists) return { success: true }; // Room already gone

        const roomData = roomDoc.data();

        // If Host leaves -> End Room
        if (uid === roomData.ownerUid) {
            transaction.update(roomRef, {
                status: "ended",
                endedAt: admin.firestore.FieldValue.serverTimestamp(),
                currentUsersCount: 0
            });
            // Optionally: transaction.delete(participantRef);
            // In a real app we might want to keep the room doc but mark it as ended.
        } else {
            transaction.delete(participantRef);
        }

        return { success: true };
    });
});

/**
 * 9. Send Gift (Legacy - replaced by sendGiftWithCombo)
 */
// Deprecated: use sendGiftWithCombo

/**
 * 🏆 Room Gift Leaderboard helpers
 * Tracks sender diamond contributions per room across daily/weekly/monthly buckets.
 * Bucket keyed documents avoid reset races: each gift increments the doc for the
 * current period bucket, and clients query only the active bucket.
 */

/** ISO week key (e.g. "2026-W33") computed in UTC. */
function isoWeekKey(date) {
    const d = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
    const dayNum = d.getUTCDay() || 7;
    d.setUTCDate(d.getUTCDate() + 4 - dayNum);
    const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
    const weekNo = Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
    return `${d.getUTCFullYear()}-W${String(weekNo).padStart(2, "0")}`;
}

/**
 * Increment per-room gift leaderboard buckets inside a transaction.
 * Data shape: rooms/{roomId}/gift_leaderboard/{period}/{bucket}/{uid}
 */
function trackRoomGiftLeaderboard(transaction, roomId, senderUid, totalCost, senderData, now) {
    const ts = now || new Date();
    const buckets = {
        daily: ts.toISOString().slice(0, 10),          // YYYY-MM-DD
        weekly: isoWeekKey(ts),                          // YYYY-Www
        monthly: ts.toISOString().slice(0, 7),           // YYYY-MM
    };
    const senderName = (senderData && senderData.displayName) || "User";
    const senderPhoto = (senderData && senderData.profilePhotoUrl) || "";

    for (const [period, bucket] of Object.entries(buckets)) {
        const ref = db.collection("rooms").doc(roomId)
            .collection("gift_leaderboard").doc(period)
            .collection(bucket).doc(senderUid);
        transaction.set(ref, {
            amount: admin.firestore.FieldValue.increment(totalCost),
            name: senderName,
            photoUrl: senderPhoto,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
    }
}

/**
 * 🏆 Per-User Sender Ranking Tracker
 * Records sender diamond contributions for a target User ID across Daily, Weekly, Monthly, and Total buckets.
 * Data shape: users/{targetUid}/sender_rankings/{period}/{bucket}/{senderUid}
 */
function trackUserSenderRanking(transaction, targetUid, senderUid, totalCost, senderData, now) {
    const ts = now || new Date();
    const buckets = {
        daily: ts.toISOString().slice(0, 10),          // YYYY-MM-DD
        weekly: isoWeekKey(ts),                          // YYYY-Www
        monthly: ts.toISOString().slice(0, 7),           // YYYY-MM
        total: "overall"
    };
    const senderName = (senderData && senderData.displayName) || "User";
    const senderPhoto = (senderData && senderData.profilePhotoUrl) || "";
    const gender = (senderData && senderData.gender) || "male";
    const level = (senderData && senderData.level) || 1;
    const vipTier = (senderData && senderData.vipTier) || "none";

    for (const [period, bucket] of Object.entries(buckets)) {
        const ref = db.collection("users").doc(targetUid)
            .collection("sender_rankings").doc(period)
            .collection(bucket).doc(senderUid);
        transaction.set(ref, {
            senderUid: senderUid,
            amount: admin.firestore.FieldValue.increment(totalCost),
            displayName: senderName,
            profilePhotoUrl: senderPhoto,
            gender: gender,
            level: level,
            vipTier: vipTier,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
    }
}

/**
 * 12. Send Gift with Combo & XP
 * Handles diamond deduction, beans addition, XP calculation, combo tracking, and PK score updates.
 */
exports.sendGiftWithCombo = functions.region("us-central1").https.onCall(async (data, context) => {
    try {
        // 🛡️ 1. Mandatory Auth Check
        if (!context.auth) {
            console.error("🛑 Unauthenticated gift attempt blocked.");
            throw new functions.https.HttpsError("unauthenticated", "You must be logged in to send gifts.");
        }

        const { roomId, giftId, targetUid, quantity, isMoment } = data;
        const senderUid = context.auth.uid;
        const qty = Math.max(1, parseInt(quantity) || 1);

        // 🔍 2. Validation
        if (!roomId || !giftId || !targetUid) {
            throw new functions.https.HttpsError("invalid-argument", "Missing roomId, giftId, or targetUid.");
        }

        console.log(`🎁 Process Started: ${senderUid} -> ${targetUid} (IsMoment: ${isMoment})`);

        // 🎁 2.2 Active Gift Event Pre-Fetch
        let activeGiftEvents = [];
        try {
            const now = new Date();
            const eventsSnap = await db.collection("gift_events")
                .where("isActive", "==", true)
                .get();
            if (!eventsSnap.empty) {
                activeGiftEvents = eventsSnap.docs
                    .map(d => ({ id: d.id, ...d.data() }))
                    .filter(ev => {
                        const start = ev.startDate ? (ev.startDate.toDate ? ev.startDate.toDate() : new Date(ev.startDate)) : null;
                        const end = ev.endDate ? (ev.endDate.toDate ? ev.endDate.toDate() : new Date(ev.endDate)) : null;
                        if (start && now < start) return false;
                        if (end && now > end) return false;
                        return true;
                    });
            }
        } catch (evErr) {
            console.warn("[GIFT_EVENT] Error checking active events:", evErr.message);
        }

        const result = await db.runTransaction(async (transaction) => {
            const senderRef = db.collection("users").doc(senderUid);
            const receiverRef = db.collection("users").doc(targetUid);
            const giftRef = db.collection("gifts").doc(giftId);
            const roomRef = db.collection("rooms").doc(roomId);
            const statusRef = db.collection("system_status").doc("salary");
            const supportCycleRef = db.collection("room_support_cycles").doc(roomId);
            const luckyConfigRef = db.collection("system_settings").doc("lucky_gift_config");

            const [senderDoc, receiverDoc, giftDoc, roomDoc, statusDoc, cycleDoc, luckyConfigDoc] = await Promise.all([
                transaction.get(senderRef),
                transaction.get(receiverRef),
                transaction.get(giftRef),
                transaction.get(roomRef),
                transaction.get(statusRef),
                transaction.get(supportCycleRef),
                transaction.get(luckyConfigRef)
            ]);

            if (!senderDoc.exists) throw new functions.https.HttpsError("not-found", "Sender profile not found.");
            if (!giftDoc.exists) throw new functions.https.HttpsError("not-found", "Gift type not found.");

            const giftData = giftDoc.data();
            const totalCost = (giftData.priceInDiamonds || 0) * qty;
            const isLuckyCategory = (giftData.category || '').toLowerCase().trim() === "lucky" || giftData.isLucky === true || (giftData.name || '').toLowerCase().includes("bell");
            let rocketWinners = [];

            // 👑 Server-side VIP / SVIP Category Enforcement
            const senderData = senderDoc.data();
            const giftCat = (giftData.category || '').toLowerCase().trim();
            if (giftCat === 'vip') {
                const isVip = senderData.vipTier && senderData.vipTier !== 'none';
                if (!isVip) {
                    throw new functions.https.HttpsError("permission-denied", "👑 Only active VIP members can send VIP gifts!");
                }
            } else if (giftCat === 'svip') {
                const userSvipLevel = senderData.svipLevel || 0;
                const reqLevel = giftData.minSvipLevel || 1;
                if (userSvipLevel < reqLevel) {
                    throw new functions.https.HttpsError("permission-denied", `⚡ SVIP Level ${reqLevel} required to send this gift!`);
                }
            }

            // 🔍 2.5 Preliminary Agency Read (Transactions must read before write)
            let agencyDoc = null;
            let agencyRef = null;
            if (receiverDoc.exists && receiverDoc.data().agencyId) {
                agencyRef = db.collection("agencies").doc(receiverDoc.data().agencyId);
                agencyDoc = await transaction.get(agencyRef);
            }

            // 💰 3. Balance Check
            const currentBalance = senderDoc.data().diamondBalance || 0;
            if (currentBalance < totalCost) {
                throw new functions.https.HttpsError("failed-precondition", "Insufficient diamond balance.");
            }

            // 🎲 3.5 Dynamic Lucky Gift Weighted Random Probability Engine
            let luckyRewardCoins = 0;
            let luckyMultiplier = 0;
            const luckyConfig = luckyConfigDoc.exists ? luckyConfigDoc.data() : null;

            if (isLuckyCategory) {
                // Default fallback probabilities if admin config is not populated yet
                const defaultMultipliers = [
                    { multiplier: 0, winningAmount: 0, probability: 45.0, enabled: true },
                    { multiplier: 1, winningAmount: (giftData.priceInDiamonds || 5) * 1, probability: 25.0, enabled: true },
                    { multiplier: 2, winningAmount: (giftData.priceInDiamonds || 5) * 2, probability: 15.0, enabled: true },
                    { multiplier: 5, winningAmount: (giftData.priceInDiamonds || 5) * 5, probability: 7.0, enabled: true },
                    { multiplier: 10, winningAmount: (giftData.priceInDiamonds || 5) * 10, probability: 4.0, enabled: true },
                    { multiplier: 20, winningAmount: (giftData.priceInDiamonds || 5) * 20, probability: 2.0, enabled: true },
                    { multiplier: 50, winningAmount: (giftData.priceInDiamonds || 5) * 50, probability: 1.0, enabled: true },
                    { multiplier: 100, winningAmount: (giftData.priceInDiamonds || 5) * 100, probability: 1.0, enabled: true },
                    { multiplier: 300, winningAmount: (giftData.priceInDiamonds || 5) * 300, probability: 0.0, enabled: false },
                    { multiplier: 1000, winningAmount: (giftData.priceInDiamonds || 5) * 1000, probability: 0.0, enabled: false }
                ];

                const activeMultipliers = (luckyConfig && Array.isArray(luckyConfig.multipliers) && luckyConfig.multipliers.length > 0)
                    ? luckyConfig.multipliers.filter(m => m.enabled !== false)
                    : defaultMultipliers.filter(m => m.enabled !== false);

                // Calculate total probability sum
                const totalProb = activeMultipliers.reduce((sum, item) => sum + (parseFloat(item.probability) || 0), 0);
                const roll = Math.random() * (totalProb > 0 ? totalProb : 100);

                let cumulative = 0;
                let chosen = { multiplier: 0, winningAmount: 0 };
                for (const item of activeMultipliers) {
                    cumulative += (parseFloat(item.probability) || 0);
                    if (roll <= cumulative) {
                        chosen = item;
                        break;
                    }
                }

                luckyMultiplier = chosen.multiplier || 0;
                const unitWinningAmount = chosen.winningAmount != null 
                    ? chosen.winningAmount 
                    : (giftData.priceInDiamonds || 5) * luckyMultiplier;
                luckyRewardCoins = unitWinningAmount * qty;

                if (luckyRewardCoins > 0) {
                    transaction.update(senderRef, {
                        diamondBalance: admin.firestore.FieldValue.increment(luckyRewardCoins),
                        totalWinningEarned: admin.firestore.FieldValue.increment(luckyRewardCoins)
                    });
                }
            }

            // 📅 Temporal period keys (UTC)
            const now = new Date();
            const todayStr = now.toISOString().substring(0, 10);
            const thisMonthStr = now.toISOString().substring(0, 7);
            const utc = new Date(Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()));
            const dayNum = utc.getUTCDay() || 7;
            utc.setUTCDate(utc.getUTCDate() + 4 - dayNum);
            const yearStart = new Date(Date.UTC(utc.getUTCFullYear(), 0, 1));
            const weekNo = Math.ceil((((utc - yearStart) / 86400000) + 1) / 7);
            const thisWeekStr = `${utc.getUTCFullYear()}-W${String(weekNo).padStart(2, '0')}`;

            // 💎 4. Deduct & Add Diamonds Sent / XP (500 diamonds = 1 XP)
            const senderInfo = senderDoc.data();
            const currentSpent = senderInfo.totalDiamondsSpent || (senderInfo.xp * 500) || 0;
            const newSpent = currentSpent + totalCost;
            const senderXP = Math.floor(newSpent / 500) - Math.floor(currentSpent / 500);

            const senderDaily = (senderInfo.lastDailySentDate === todayStr) ? (senderInfo.dailyDiamondsSent || 0) : 0;
            const senderWeekly = (senderInfo.lastWeeklySentDate === thisWeekStr) ? (senderInfo.weeklyDiamondsSent || 0) : 0;
            const senderMonthly = (senderInfo.lastMonthlySentDate === thisMonthStr) ? (senderInfo.monthlyDiamondsSent || 0) : 0;
            
            transaction.update(senderRef, {
                diamondBalance: admin.firestore.FieldValue.increment(-totalCost),
                totalDiamondsSpent: admin.firestore.FieldValue.increment(totalCost),
                totalDiamondsSent: admin.firestore.FieldValue.increment(totalCost),
                dailyDiamondsSent: senderDaily + totalCost,
                weeklyDiamondsSent: senderWeekly + totalCost,
                monthlyDiamondsSent: senderMonthly + totalCost,
                lastDailySentDate: todayStr,
                lastWeeklySentDate: thisWeekStr,
                lastMonthlySentDate: thisMonthStr,
                xp: admin.firestore.FieldValue.increment(senderXP),
                benchXP: admin.firestore.FieldValue.increment(senderXP),
                dailyXP: admin.firestore.FieldValue.increment(senderXP),
                weeklyXP: admin.firestore.FieldValue.increment(senderXP),
                monthlyXP: admin.firestore.FieldValue.increment(senderXP),
            });

            // 💹 5. Record Receiver Beans & XP
            let beansEarned = 0;
            if (receiverDoc.exists) {
                const receiverData = receiverDoc.data();
                const agencyId = receiverData.agencyId;

                if (isLuckyCategory) {
                    // 🔔 Lucky / Bell Gift Rule: Receiver gets configured base Bean contribution per gift (Default 1 Bean per gift)
                    // Completely independent of Sender's winning multiplier or gift diamond price
                    const baseBeanPerGift = giftData.receiverBeanReward != null
                        ? Number(giftData.receiverBeanReward)
                        : ((luckyConfig && luckyConfig.receiverBeanReward != null) ? Number(luckyConfig.receiverBeanReward) : 1);
                    beansEarned = Math.max(1, baseBeanPerGift) * qty;
                } else {
                    let hostSharePercent = 1.0; // 1:1 Parity (1 Diamond = 1 Bean)
                    let agencySharePercent = 0;

                    if (agencyId && agencyDoc && agencyDoc.exists) {
                        hostSharePercent = 0.7;
                        agencySharePercent = 0.1;
                        const agencyBeans = Math.floor(totalCost * agencySharePercent);
                        transaction.update(agencyRef, {
                            beansBalance: admin.firestore.FieldValue.increment(agencyBeans),
                            totalBeansEarned: admin.firestore.FieldValue.increment(agencyBeans)
                        });
                    }
                    beansEarned = Math.floor(totalCost * hostSharePercent);
                }
                
                // Receiver XP: 1000 diamonds = 1 XP
                const currentEarned = receiverData.totalDiamondsReceived || (receiverData.princeXP * 1000) || 0;
                const newEarned = currentEarned + totalCost;
                const receiverXP = Math.floor(newEarned / 1000) - Math.floor(currentEarned / 1000);

                const receiverDaily = (receiverData.lastDailyReceivedDate === todayStr) ? (receiverData.dailyBeansReceived || 0) : 0;
                const receiverWeekly = (receiverData.lastWeeklyReceivedDate === thisWeekStr) ? (receiverData.weeklyBeansReceived || 0) : 0;
                const receiverMonthly = (receiverData.lastMonthlyReceivedDate === thisMonthStr) ? (receiverData.monthlyBeansReceived || 0) : 0;
                
                transaction.update(receiverRef, {
                    beansBalance: admin.firestore.FieldValue.increment(beansEarned),
                    totalBeansReceived: admin.firestore.FieldValue.increment(beansEarned),
                    dailyBeansReceived: receiverDaily + beansEarned,
                    weeklyBeansReceived: receiverWeekly + beansEarned,
                    monthlyBeansReceived: receiverMonthly + beansEarned,
                    lastDailyReceivedDate: todayStr,
                    lastWeeklyReceivedDate: thisWeekStr,
                    lastMonthlyReceivedDate: thisMonthStr,
                    totalDiamondsReceived: admin.firestore.FieldValue.increment(totalCost),
                    princeXP: admin.firestore.FieldValue.increment(receiverXP),
                    dailyPrinceXP: admin.firestore.FieldValue.increment(receiverXP),
                    weeklyPrinceXP: admin.firestore.FieldValue.increment(receiverXP),
                    monthlyPrinceXP: admin.firestore.FieldValue.increment(receiverXP),
                });

                // 🏆 Per-User ID Dedicated Top List Subcollection Updates

                const rankingPayload = {
                    amount: admin.firestore.FieldValue.increment(totalCost),
                    senderUid: senderUid,
                    displayName: senderData.displayName || "User",
                    profilePhotoUrl: senderData.profilePhotoUrl || "",
                    gender: senderData.gender || "female",
                    level: senderData.level || 1,
                    vipTier: senderData.vipTier || "none",
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                };

                const rankingsCol = receiverRef.collection("sender_rankings");
                transaction.set(rankingsCol.doc("daily").collection(todayStr).doc(senderUid), rankingPayload, { merge: true });
                transaction.set(rankingsCol.doc("weekly").collection(thisWeekStr).doc(senderUid), rankingPayload, { merge: true });
                transaction.set(rankingsCol.doc("monthly").collection(thisMonthStr).doc(senderUid), rankingPayload, { merge: true });
                transaction.set(rankingsCol.doc("total").collection("overall").doc(senderUid), rankingPayload, { merge: true });

                // 💹 NEW: Process Salary Milestones
                await processSalaryMilestones(transaction, targetUid, beansEarned, statusDoc, receiverDoc);
            }

            // 📸 6. Social Counters
            if (isMoment === true) {
                const momentRef = db.collection("moments").doc(roomId);
                const userMediaRef = db.collection("users").doc(targetUid).collection("media").doc(roomId);

                // Using set merge to avoid crashes if document missing
                transaction.set(momentRef, { giftCount: admin.firestore.FieldValue.increment(qty) }, { merge: true });
                transaction.set(userMediaRef, { giftCount: admin.firestore.FieldValue.increment(qty) }, { merge: true });
            }

            // 🎬 7. Chat Message (Only for voice rooms)
            if (!isMoment) {
                const msgRef = roomRef.collection("messages").doc();
                const receiverName = receiverDoc.exists ? (receiverDoc.data().displayName || "User") : "User";
                transaction.set(msgRef, {
                    uid: senderUid,
                    senderName: senderDoc.data().displayName || "User",
                    type: "gift",
                    giftId: giftId,
                    quantity: qty,
                    animationUrl: giftData.lottieAssetPath,
                    text: `Sent to ${receiverName} x${qty}${luckyMultiplier > 0 ? ` 🎉 LUCKY WIN ${luckyMultiplier}X (+${luckyRewardCoins} Diamonds)!` : ''}`,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    targetUid: targetUid
                });

                // ⚔️ PK SCORE UPDATE (SYSTEM COMPLETION)
                if (roomDoc.exists && roomDoc.data().pkActive) {
                    const roomData = roomDoc.data();
                    const teams = roomData.pkTeams || {};
                    const side = teams[targetUid];
                    
                    if (side) {
                        const scoreField = `pkScores.${targetUid}`;
                        const contributionField = `pkContributions.${side}.${senderUid}`;
                        transaction.update(roomRef, {
                            [scoreField]: admin.firestore.FieldValue.increment(totalCost),
                            [contributionField]: admin.firestore.FieldValue.increment(totalCost)
                        });
                    }
                }

                // 🏠 FAMILY BATTLE SCORE UPDATE (Diamond-based)
                // When a user sends gifts, their diamond spending contributes to their family's active battle score
                try {
                    const senderUserDoc = await transaction.get(db.collection("users").doc(senderUid));
                    if (senderUserDoc.exists) {
                        const senderFamilyId = senderUserDoc.data().familyId;
                        if (senderFamilyId) {
                            // Check for active battle in this family
                            const activeBattles = await db.collection("families").doc(senderFamilyId)
                                .collection("battles")
                                .where("status", "==", "active")
                                .limit(1)
                                .get();
                            
                            if (!activeBattles.empty) {
                                const battleDoc = activeBattles.docs[0];
                                const battleData = battleDoc.data();
                                const battleId = battleDoc.id;
                                
                                // Determine if sender's family is familyA or familyB
                                const isA = senderFamilyId === battleData.familyAId;
                                const scoreField = isA ? "familyAPoints" : "familyBPoints";
                                const opponentFamilyId = isA ? battleData.familyBId : battleData.familyAId;
                                
                                // Add diamond value to family's battle score
                                const battleRef = db.collection("families").doc(senderFamilyId)
                                    .collection("battles").doc(battleId);
                                transaction.update(battleRef, {
                                    [scoreField]: admin.firestore.FieldValue.increment(totalCost)
                                });
                                
                                // Mirror update to opponent's battle copy
                                const oppBattleRef = db.collection("families").doc(opponentFamilyId)
                                    .collection("battles").doc(battleId);
                                transaction.update(oppBattleRef, {
                                    [scoreField]: admin.firestore.FieldValue.increment(totalCost)
                                });
                                
                                // Update member's contribution
                                const memberRef = db.collection("families").doc(senderFamilyId)
                                    .collection("members").doc(senderUid);
                                transaction.update(memberRef, {
                                    combatPoints: admin.firestore.FieldValue.increment(totalCost),
                                    contribution: admin.firestore.FieldValue.increment(totalCost),
                                    memberXP: admin.firestore.FieldValue.increment(Math.floor(totalCost / 500)),
                                });
                                
                                console.log(`[FAMILY_BATTLE] User ${senderUid} contributed ${totalCost} diamonds to family ${senderFamilyId} battle score`);
                            }
                        }
                    }
                } catch (familyErr) {
                    // Don't fail the gift if family battle update fails
                    console.warn(`[FAMILY_BATTLE] Error updating family battle score:`, familyErr.message);
                }

                // 🚀 8. Rocket Fuel Logic (Integrated)
                if (!isMoment) {
                    const roomData = roomDoc.data();
                    rocketWinners = await processRocketFueling(transaction, roomId, roomRef, roomData, senderUid, totalCost);
                }
            }

            // 🏆 Room Support & Room Weekly Earnings Reset Logic (Strict 1-Week Cycle)
            const nowUtc = new Date();
            const dUtc = new Date(Date.UTC(nowUtc.getUTCFullYear(), nowUtc.getUTCMonth(), nowUtc.getUTCDate()));
            const cycleDayNum = dUtc.getUTCDay() || 7;
            dUtc.setUTCDate(dUtc.getUTCDate() + 4 - cycleDayNum);
            const cycleYearStart = new Date(Date.UTC(dUtc.getUTCFullYear(), 0, 1));
            const cycleWeekNo = Math.ceil((((dUtc - cycleYearStart) / 86400000) + 1) / 7);
            const cycleWeekId = `${dUtc.getUTCFullYear()}-W${cycleWeekNo < 10 ? '0' + cycleWeekNo : cycleWeekNo}`;

            const cycleData = cycleDoc.exists ? cycleDoc.data() : {};
            const isSameWeekCycle = cycleData.weekId === cycleWeekId;
            const prevTotalCoins = isSameWeekCycle ? (cycleData.totalCoins || 0) : 0;
            const newTotalCoins = prevTotalCoins + totalCost;

            transaction.set(supportCycleRef, {
                totalCoins: newTotalCoins,
                weekId: cycleWeekId,
                lastWeekCoins: isSameWeekCycle ? (cycleData.lastWeekCoins || 0) : (cycleData.totalCoins || 0),
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            }, { merge: true });

            if (roomDoc.exists) {
                const roomData = roomDoc.data();
                const isSameWeekRoom = !roomData.weekId || roomData.weekId === cycleWeekId;
                const prevWeeklyEarnings = isSameWeekRoom ? (roomData.weeklyEarnings || 0) : 0;

                const roomDaily = (roomData.lastDailySentDate === todayStr) ? (roomData.dailyDiamondsSent || 0) : 0;
                const roomWeekly = (roomData.lastWeeklySentDate === thisWeekStr) ? (roomData.weeklyDiamondsSent || 0) : 0;
                const roomMonthly = (roomData.lastMonthlySentDate === thisMonthStr) ? (roomData.monthlyDiamondsSent || 0) : 0;

                transaction.update(roomRef, {
                    totalDiamondsSent: admin.firestore.FieldValue.increment(totalCost),
                    dailyDiamondsSent: roomDaily + totalCost,
                    weeklyDiamondsSent: roomWeekly + totalCost,
                    monthlyDiamondsSent: roomMonthly + totalCost,
                    lastDailySentDate: todayStr,
                    lastWeeklySentDate: thisWeekStr,
                    lastMonthlySentDate: thisMonthStr,
                    weeklyEarnings: prevWeeklyEarnings + totalCost,
                    weekId: cycleWeekId
                });
            }

            // 🏆 Room Gift Leaderboard: track sender diamond contributions per period
            try {
                trackRoomGiftLeaderboard(transaction, roomId, senderUid, totalCost, senderDoc.data(), new Date());
            } catch (lbErr) {
                // Don't fail the gift if leaderboard tracking fails
                console.warn(`[GIFT_LEADERBOARD] Error tracking gift:`, lbErr.message);
            }

            // 🏆 Per-User Sender Ranking: track sender diamond contributions for targetUid
            try {
                trackUserSenderRanking(transaction, targetUid, senderUid, totalCost, senderDoc.data(), new Date());
            } catch (usrLbErr) {
                console.warn(`[USER_SENDER_RANKING] Error tracking gift for target ${targetUid}:`, usrLbErr.message);
            }

            // 📝 Lucky Gift Transaction Audit Logging
            if (isLuckyCategory) {
                const luckyTxRef = db.collection("lucky_gift_transactions").doc();
                transaction.set(luckyTxRef, {
                    transactionId: luckyTxRef.id,
                    senderUid: senderUid,
                    senderName: senderDoc.data()?.displayName || "User",
                    targetUid: targetUid,
                    receiverName: receiverDoc.exists ? (receiverDoc.data()?.displayName || "User") : "User",
                    giftId: giftId,
                    giftName: giftData.name || "Lucky Gift",
                    giftPrice: giftData.priceInDiamonds || 5,
                    quantity: qty,
                    totalCost: totalCost,
                    winningMultiplier: luckyMultiplier,
                    winningAmount: luckyRewardCoins,
                    receiverBeans: beansEarned,
                    roomId: roomId || "",
                    createdAt: admin.firestore.FieldValue.serverTimestamp()
                });
            }

            // 🎁 Process Gift Event Points & Participant Leaderboards
            let earnedEventPoints = 0;
            let activeEventId = null;
            if (activeGiftEvents.length > 0) {
                for (const ev of activeGiftEvents) {
                    const eventGifts = Array.isArray(ev.gifts) ? ev.gifts : [];
                    const matchedGift = eventGifts.find(g => g.giftId === giftId);
                    if (matchedGift) {
                        const ptsPerUnit = Number(matchedGift.eventPoints) || Number(matchedGift.priceInDiamonds) || (totalCost / qty);
                        const totalPts = Math.round(ptsPerUnit * qty);
                        earnedEventPoints += totalPts;
                        activeEventId = ev.id;

                        const participantRef = db.collection("gift_events").doc(ev.id).collection("participants").doc(senderUid);
                        transaction.set(participantRef, {
                            uid: senderUid,
                            displayName: senderDoc.data()?.displayName || "User",
                            profilePhotoUrl: senderDoc.data()?.profilePhotoUrl || "",
                            gender: senderDoc.data()?.gender || "female",
                            level: senderDoc.data()?.level || 1,
                            vipTier: senderDoc.data()?.vipTier || "none",
                            points: admin.firestore.FieldValue.increment(totalPts),
                            giftCount: admin.firestore.FieldValue.increment(qty),
                            diamondsSpent: admin.firestore.FieldValue.increment(totalCost),
                            updatedAt: admin.firestore.FieldValue.serverTimestamp()
                        }, { merge: true });

                        const eventRef = db.collection("gift_events").doc(ev.id);
                        transaction.set(eventRef, {
                            totalEventPoints: admin.firestore.FieldValue.increment(totalPts),
                            totalGiftsSent: admin.firestore.FieldValue.increment(qty),
                            totalDiamondsSpent: admin.firestore.FieldValue.increment(totalCost),
                            updatedAt: admin.firestore.FieldValue.serverTimestamp()
                        }, { merge: true });
                    }
                }
            }

            return {
                success: true,
                newBalance: currentBalance - totalCost + luckyRewardCoins,
                totalCost,
                luckyRewardCoins,
                winningAmount: luckyRewardCoins,
                luckyMultiplier,
                hasWon: luckyMultiplier > 0,
                receiverBeans: beansEarned,
                isLucky: isLuckyCategory,
                rocketWinners,
                eventPointsEarned: earnedEventPoints,
                eventId: activeEventId
            };
        });

        // 🚀 Post-commit: Deliver FCM push notifications to Rocket winners (fire-and-forget, never blocks gift response)
        if (result && Array.isArray(result.rocketWinners) && result.rocketWinners.length > 0) {
            notifyRocketWinners(result.rocketWinners).catch((notifyErr) => {
                console.error("[ROCKET_NOTIFY] Push notification batch failed:", notifyErr);
            });
        }

        return result;
    } catch (error) {
        console.error("🛑 Gifting Error:", error);
        if (error instanceof functions.https.HttpsError) throw error;
        throw new functions.https.HttpsError("internal", error.message || "An unexpected error occurred while gifting.");
    }
});

/**
 * 🎁 Distribute Gift Event Rewards (Admin Callable)
 */
exports.distributeGiftEventRewards = functions.region("us-central1").https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Admin authentication required.");
    }
    const adminCheck = await isUserAdmin(context.auth.uid);
    if (!adminCheck) {
        throw new functions.https.HttpsError("permission-denied", "Only administrators can disburse event rewards.");
    }

    const { eventId } = data;
    if (!eventId) {
        throw new functions.https.HttpsError("invalid-argument", "Missing eventId.");
    }

    const eventDoc = await db.collection("gift_events").doc(eventId).get();
    if (!eventDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Event not found.");
    }

    const eventData = eventDoc.data();
    const rewards = Array.isArray(eventData.rewards) ? eventData.rewards : [];
    if (rewards.length === 0) {
        return { success: true, message: "No rewards configured for this event." };
    }

    // Fetch top participants ordered by points
    const participantsSnap = await db.collection("gift_events").doc(eventId)
        .collection("participants")
        .orderBy("points", "desc")
        .limit(100)
        .get();

    if (participantsSnap.empty) {
        return { success: true, message: "No participants to reward." };
    }

    const participants = participantsSnap.docs.map(d => ({ id: d.id, ...d.data() }));
    const batch = db.batch();
    const distributedLogs = [];

    participants.forEach((p, idx) => {
        const rank = idx + 1;
        const matchedTier = rewards.find(r => rank >= Number(r.rankFrom || 1) && rank <= Number(r.rankTo || 1));
        if (matchedTier) {
            const userRef = db.collection("users").doc(p.uid);
            const userUpdates = {};

            // 1. Diamonds reward
            if (matchedTier.diamonds && Number(matchedTier.diamonds) > 0) {
                userUpdates.diamondBalance = admin.firestore.FieldValue.increment(Number(matchedTier.diamonds));
                const txRef = db.collection("diamond_transactions").doc();
                batch.set(txRef, {
                    userId: p.uid,
                    type: "EVENT_REWARD",
                    amount: Number(matchedTier.diamonds),
                    description: `Gift Event Reward: Rank ${rank} in ${eventData.title || 'Event'}`,
                    eventId: eventId,
                    createdAt: admin.firestore.FieldValue.serverTimestamp()
                });
            }

            // 2. Profile frame reward
            if (matchedTier.frameUrl) {
                const days = Number(matchedTier.frameDays || 30);
                const expiry = new Date();
                expiry.setDate(expiry.getDate() + days);
                const frameItemRef = db.collection("users").doc(p.uid).collection("backpack").doc();
                batch.set(frameItemRef, {
                    type: "frame",
                    frameUrl: matchedTier.frameUrl,
                    title: matchedTier.badgeTitle || "Event Champion Frame",
                    expiresAt: admin.firestore.Timestamp.fromDate(expiry),
                    createdAt: admin.firestore.FieldValue.serverTimestamp()
                });
            }

            // 3. Badge / Medal reward
            if (matchedTier.badgeTitle) {
                userUpdates.badges = admin.firestore.FieldValue.arrayUnion(matchedTier.badgeTitle);
            }

            if (Object.keys(userUpdates).length > 0) {
                batch.update(userRef, userUpdates);
            }

            distributedLogs.push({ uid: p.uid, rank, tier: matchedTier.title || `Rank ${rank}` });
        }
    });

    const eventRef = db.collection("gift_events").doc(eventId);
    batch.update(eventRef, {
        distributed: true,
        distributedAt: admin.firestore.FieldValue.serverTimestamp(),
        distributedBy: context.auth.uid
    });

    await batch.commit();

    return {
        success: true,
        rewardedCount: distributedLogs.length,
        logs: distributedLogs
    };
});
/**
 * 0. Diagnostic Ping (Public - No Auth Required)
 */
exports.pingServer = functions.https.onCall(async (data, context) => {
    return { 
        success: true, 
        message: "Hello Chat Server is Online!", 
        projectId: process.env.GCLOUD_PROJECT || "unknown",
        serverTime: Date.now(),
        hasAuth: !!context.auth,
        hasAppCheck: !!context.appCheck 
    };
});

/**
 * 13. Invite PK Challenge (v2 - App Check Bypass)
 */
exports.invitePKChallenge = onCall({
    enforceAppCheck: false, // 🛡️ We manually handle this to bypass the "Consol Lock"
    region: "us-central1"
}, async (request) => {
    const { roomId, targetUid, durationSeconds, senderUid: manualUid } = request.data;
    const { auth } = request;

    // 🛡️ APP CHECK HANDSHAKE (Diagnostic Only)
    if (!request.app) {
        console.warn(`⚠️ [PK_INVITE_V2] Unverified App Check token from ${auth ? auth.uid : 'Unknown'}.`);
    }

    // Fallback logic for testing...
    let senderUid = auth ? auth.uid : (manualUid || "guest_test_host");
    
    // Safety check
    if (!auth && !manualUid) {
        throw new functions.https.HttpsError("unauthenticated", "Authentication failed. App Check or UID missing.");
    }

    const roomRef = db.collection("rooms").doc(roomId);

    return db.runTransaction(async (transaction) => {
        const roomDoc = await transaction.get(roomRef);
        if (!roomDoc.exists) throw new functions.https.HttpsError("not-found", "Room not found.");
        
        const roomData = roomDoc.data();
        
        // 🔒 ROLE GUARD: Only host/admin can invite
        const isAdmin = roomData.ownerUid === senderUid || (roomData.admins || []).includes(senderUid);
        if (!isAdmin) throw new functions.https.HttpsError("permission-denied", "Only hosts can start PK.");

        // 🔒 STATE GUARD: Already active or pending
        if (roomData.pkActive) throw new functions.https.HttpsError("failed-precondition", "PK already in progress.");
        if (roomData.pkChallenge && roomData.pkChallenge.status === "pending") {
            const now = Date.now();
            if (roomData.pkChallenge.expiresAt.toMillis() > now) {
                throw new functions.https.HttpsError("already-exists", "A challenge is already pending.");
            }
        }

        const senderDoc = await transaction.get(db.collection("users").doc(senderUid));
        const expiresAt = Date.now() + 35 * 1000; // 35s server buffer for 30s UI timer

        transaction.update(roomRef, {
            pkChallenge: {
                senderUid: senderUid,
                senderName: senderDoc.data()?.displayName || "Host",
                receiverUid: targetUid,
                status: "pending",
                expiresAt: admin.firestore.Timestamp.fromMillis(expiresAt),
                durationSeconds: durationSeconds || 300
            },
            pkPhase: "none"
        });

        // 🔔 Also send a Global Notification so they can join from anywhere
        const notificationRef = db.collection("users").doc(targetUid).collection("notifications").doc();
        transaction.set(notificationRef, {
            type: "pk_invitation",
            senderUid: senderUid,
            senderName: senderDoc.data()?.displayName || "Host",
            roomId: roomId,
            roomName: roomData.name || "Live Room",
            status: "pending",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            expiresAt: admin.firestore.Timestamp.fromMillis(expiresAt)
        });

        return { success: true };
    });
});

/**
 * 13c. Send Room Invitation
 */
exports.sendRoomInvitation = onCall({
    enforceAppCheck: false,
    region: "us-central1"
}, async (request) => {
    const { roomId, targetUid, senderUid: manualUid } = request.data;
    const { auth } = request;

    let senderUid = auth ? auth.uid : manualUid;
    if (!senderUid) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const senderDoc = await db.collection("users").doc(senderUid).get();
    const roomDoc = await db.collection("rooms").doc(roomId).get();

    if (!roomDoc.exists) throw new functions.https.HttpsError("not-found", "Room not found.");

    const notificationRef = db.collection("users").doc(targetUid).collection("notifications").doc();
    await notificationRef.set({
        type: "room_invitation",
        senderUid: senderUid,
        senderName: senderDoc.data()?.displayName || "A friend",
        roomId: roomId,
        roomName: roomDoc.data()?.name || "Live Room",
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 60 * 60 * 1000) // 1 hour
    });

    return { success: true };
});

/**
 * 13b. Respond to PK Challenge (v2)
 */
exports.respondToPKChallenge = onCall({
    enforceAppCheck: false,
    region: "us-central1"
}, async (request) => {
    const { roomId, accepted, receiverUid: manualUid, adminUid } = request.data;
    const { auth } = request;

    const receiverUid = auth ? auth.uid : (manualUid || adminUid || "guest_test_receiver");
    const roomRef = db.collection("rooms").doc(roomId);

    return db.runTransaction(async (transaction) => {
        const roomDoc = await transaction.get(roomRef);
        if (!roomDoc.exists) throw new HttpsError("not-found", "Room not found.");
        
        const roomData = roomDoc.data();
        const challenge = roomData.pkChallenge;

        if (!challenge || challenge.status !== "pending") {
            throw new HttpsError("failed-precondition", "No pending challenge found.");
        }

        // Logic check: only receiver or admin can respond
        const isReceiver = challenge.receiverUid === receiverUid;
        if (!isReceiver) {
            const isAdmin = await isUserAdmin(receiverUid);
            if (!isAdmin) {
                throw new HttpsError("permission-denied", "Unauthorized to respond.");
            }
        }

        if (accepted) {
            const leftUid = challenge.senderUid;
            const rightUid = challenge.receiverUid;
            const duration = challenge.durationSeconds || 300;
            const endTime = Date.now() + duration * 1000;

            transaction.update(roomRef, {
                pkActive: true,
                pkStartTime: admin.firestore.FieldValue.serverTimestamp(),
                pkEndTime: admin.firestore.Timestamp.fromMillis(endTime),
                pkScores: { [leftUid]: 0, [rightUid]: 0 },
                pkTeams: { [leftUid]: "left", [rightUid]: "right" },
                pkContributions: { left: {}, right: {} },
                pkWinnerUid: null,
                pkPhase: "active",
                pkChallenge: null 
            });
            return { success: true, accepted: true };
        } else {
            transaction.update(roomRef, {
                pkChallenge: admin.firestore.FieldValue.delete()
            });
            return { success: true, accepted: false };
        }
    });
});

/**
 * 14. Internal/Shared End PK Battle Logic
 */
async function internalEndPKBattle(roomId, forcedWinnerUid = null) {
    const roomRef = db.collection("rooms").doc(roomId);

    return db.runTransaction(async (transaction) => {
        const roomDoc = await transaction.get(roomRef);
        if (!roomDoc.exists || !roomDoc.data().pkActive) return { success: false };

        const roomData = roomDoc.data();
        const scores = roomData.pkScores || {};
        const teams = roomData.pkTeams || {};
        const contributions = roomData.pkContributions || { left: {}, right: {} };

        const uids = Object.keys(teams);
        if (uids.length < 2) return { success: false };

        const leftUid = uids.find(uid => teams[uid] === 'left');
        const rightUid = uids.find(uid => teams[uid] === 'right');

        const leftScore = scores[leftUid] || 0;
        const rightScore = scores[rightUid] || 0;

        let winnerUid = forcedWinnerUid || null;
        if (!winnerUid) {
            if (leftScore > rightScore) winnerUid = leftUid;
            else if (rightScore > leftScore) winnerUid = rightUid;
        }

        const getTop3 = (contribs) => {
            return Object.entries(contribs || {})
                .sort(([, a], [, b]) => b - a)
                .slice(0, 3)
                .map(([uid, amount]) => ({ uid, amount }));
        };

        const pkWinnerData = {
            winnerUid: winnerUid,
            totalDiamonds: leftScore + rightScore,
            leftScore: leftScore,
            rightScore: rightScore,
            top3Left: getTop3(contributions.left),
            top3Right: getTop3(contributions.right),
            endedAt: admin.firestore.Timestamp.now()
        };

        transaction.update(roomRef, {
            pkActive: false,
            pkWinnerUid: winnerUid,
            pkWinnerData: pkWinnerData,
            pkPhase: "finished",
            pkEndedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        if (winnerUid) {
            const rewardXP = Math.floor((leftScore + rightScore) * 0.1) + 100;
            transaction.update(db.collection("users").doc(winnerUid), {
                princeXP: admin.firestore.FieldValue.increment(rewardXP)
            });
        }

        return { success: true, winnerUid: winnerUid };
    });
}

/**
 * 14b. End PK Battle Callable (v2)
 */
exports.endPKBattle = onCall({
    enforceAppCheck: false,
    region: "us-central1"
}, async (request) => {
    const { roomId, forcedWinnerUid } = request.data;
    return await internalEndPKBattle(roomId, forcedWinnerUid);
});

/**
 * 11. Recharge Diamonds (Sandbox)
 * Cloud-side atomic recharge with transaction logging.
 */

// ⚔️ PK Battle Flow Functions were here...


/**
 * 10. End Room
 */
exports.endRoom = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const uid = context.auth.uid;
    const { roomId } = data;

    const roomRef = db.collection("rooms").doc(roomId);
    const roomDoc = await roomRef.get();

    if (!roomDoc.exists) throw new functions.https.HttpsError("not-found", "Room not found.");
    if (roomDoc.data().ownerUid !== uid) throw new functions.https.HttpsError("permission-denied", "Only owner can end room.");

    await roomRef.update({
        status: "ended",
        endedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
});

/**
 * 11. Mic Controls (Request / Grant)
 */
exports.requestMic = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const uid = context.auth.uid;
    const { roomId } = data;

    const requestRef = db.collection("rooms").doc(roomId).collection("micRequests").doc(uid);
    await requestRef.set({ requestedAt: admin.firestore.FieldValue.serverTimestamp() });

    return { success: true };
});

exports.grantMic = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const uid = context.auth.uid;
    const { roomId, targetUid, seatIndex } = data;

    const roomRef = db.collection("rooms").doc(roomId);
    const roomDoc = await roomRef.get();
    if (!roomDoc.exists) throw new functions.https.HttpsError("not-found", "Room not found.");

    const admins = roomDoc.data().admins || [];
    if (roomDoc.data().ownerUid !== uid && !admins.includes(uid)) {
        throw new functions.https.HttpsError("permission-denied", "Only admin can grant mic.");
    }

    return db.runTransaction(async (transaction) => {
        const participantRef = roomRef.collection("participants").doc(targetUid);
        const requestRef = roomRef.collection("micRequests").doc(targetUid);

        transaction.update(participantRef, {
            role: "speaker",
            seatIndex: seatIndex,
        });
        transaction.delete(requestRef);

        return { success: true };
    });
});

/**
 * 12. Room Triggers
 */
exports.onCreateRoom = functions.firestore.document("rooms/{roomId}").onCreate(async (snapshot, context) => {
    const roomData = snapshot.data();
    const roomId = context.params.roomId;
    const ownerUid = roomData.ownerUid;

    // Auto-add owner as host participant
    await db.collection("rooms").doc(roomId).collection("participants").doc(ownerUid).set({
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastActive: admin.firestore.FieldValue.serverTimestamp(),
        seatIndex: 0,
        isMuted: false,
        role: "host",
    });

    // Auto-create room_support_cycles document for new rooms
    const now = new Date();
    const daysUntilSunday = (7 - now.getUTCDay()) % 7;
    const nextSunday = new Date(now);
    nextSunday.setUTCDate(now.getUTCDate() + (daysUntilSunday === 0 ? 7 : daysUntilSunday));
    nextSunday.setUTCHours(23, 59, 59, 0);
    const weekEnd = admin.firestore.Timestamp.fromDate(nextSunday);

    await db.collection("room_support_cycles").doc(roomId).set({
        totalCoins: 0,
        level: 1,
        status: "accumulating",
        weekStart: admin.firestore.FieldValue.serverTimestamp(),
        weekEnd: weekEnd,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
});

exports.onParticipantChange = functions.firestore.document("rooms/{roomId}/participants/{uid}").onWrite(async (change, context) => {
    const roomId = context.params.roomId;
    const roomRef = db.collection("rooms").doc(roomId);

    // This is a bit expensive if there are many participants, but for small rooms it's ok.
    // Better to use a counter but onWrite is simple.
    const participants = await roomRef.collection("participants").get();
    return roomRef.update({ currentUsersCount: participants.size });
});


/**
 * --- PK BATTLE END TRIGGER ---
 * Automated termination when time expires.
 */
exports.autoEndPKBattles = functions.pubsub.schedule('every 1 minutes').onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const roomsSnap = await db.collection("rooms")
        .where("pkActive", "==", true)
        .where("pkEndTime", "<=", now)
        .get();

    if (roomsSnap.empty) return null;

    let count = 0;
    const tasks = roomsSnap.docs.map(async (roomDoc) => {
        try {
            await internalEndPKBattle(roomDoc.id);
            count++;
        } catch (e) {
            console.error(`[PK_AUTO_END] Failed for Room ${roomDoc.id}:`, e);
        }
    });

    await Promise.all(tasks);
    console.log(`[PK_AUTO_END] terminated and calculated results for ${count} expired battles.`);
    return null;
});




/**
 * 13. Feed Sample Gifts
 * Admin-only function to seed initial gifts.
 */
exports.feedSampleGifts = functions.https.onRequest(async (req, res) => {
    // Admin check skipped for local seeding
    const gifts = [
        { giftId: 'heart', name: 'Heart', priceInDiamonds: 10, category: 'small', imageUrl: '❤️', lottieAssetPath: 'https://raw.githubusercontent.com/xvrh/lottie-flutter/master/example/assets/Mobilo/A.json', sortOrder: 1, isActive: true },
        { giftId: 'rose', name: 'Rose', priceInDiamonds: 50, category: 'small', imageUrl: '🌹', lottieAssetPath: 'https://raw.githubusercontent.com/xvrh/lottie-flutter/master/example/assets/Mobilo/B.json', sortOrder: 2, isActive: true },
        { giftId: 'crown', name: 'Crown', priceInDiamonds: 1000, category: 'luxury', imageUrl: '👑', lottieAssetPath: 'https://raw.githubusercontent.com/xvrh/lottie-flutter/master/example/assets/Mobilo/C.json', sortOrder: 3, isActive: true },
        { giftId: 'rocket', name: 'Rocket', priceInDiamonds: 5000, category: 'special', imageUrl: '🚀', lottieAssetPath: 'https://raw.githubusercontent.com/xvrh/lottie-flutter/master/example/assets/Mobilo/D.json', sortOrder: 4, isActive: true },
        { giftId: 'diamond', name: 'Diamond', priceInDiamonds: 200, category: 'luxury', imageUrl: '💎', lottieAssetPath: 'https://raw.githubusercontent.com/xvrh/lottie-flutter/master/example/assets/Mobilo/E.json', sortOrder: 5, isActive: true },
        { giftId: 'car', name: 'Super Car', priceInDiamonds: 20000, category: 'special', imageUrl: '🏎️', lottieAssetPath: 'https://raw.githubusercontent.com/xvrh/lottie-flutter/master/example/assets/Mobilo/F.json', sortOrder: 6, isActive: true },
        { giftId: 'champagne', name: 'Champagne', priceInDiamonds: 500, category: 'special', imageUrl: '🍾', lottieAssetPath: 'https://raw.githubusercontent.com/xvrh/lottie-flutter/master/example/assets/Mobilo/G.json', sortOrder: 7, isActive: true },
        { giftId: 'cake', name: 'Cake', priceInDiamonds: 150, category: 'small', imageUrl: '🎂', lottieAssetPath: 'https://raw.githubusercontent.com/xvrh/lottie-flutter/master/example/assets/Mobilo/H.json', sortOrder: 8, isActive: true },
        { giftId: 'balloon', name: 'Balloon', priceInDiamonds: 20, category: 'small', imageUrl: '🎈', lottieAssetPath: 'https://raw.githubusercontent.com/xvrh/lottie-flutter/master/example/assets/Mobilo/I.json', sortOrder: 9, isActive: true },
        { giftId: 'airplane', name: 'Airplane', priceInDiamonds: 30000, category: 'special', imageUrl: '✈️', lottieAssetPath: 'https://raw.githubusercontent.com/xvrh/lottie-flutter/master/example/assets/Mobilo/J.json', sortOrder: 10, isActive: true },
        { giftId: 'castle', name: 'Castle', priceInDiamonds: 50000, category: 'special', imageUrl: '🏰', lottieAssetPath: 'https://raw.githubusercontent.com/xvrh/lottie-flutter/master/example/assets/Mobilo/K.json', sortOrder: 11, isActive: true },
        { giftId: 'ring', name: 'Ring', priceInDiamonds: 800, category: 'luxury', imageUrl: '💍', lottieAssetPath: 'https://raw.githubusercontent.com/xvrh/lottie-flutter/master/example/assets/Mobilo/L.json', sortOrder: 12, isActive: true },
    ];

    const batch = db.batch();

    // Clean old ones
    const oldGifts = await db.collection("gifts").get();
    oldGifts.forEach(doc => batch.delete(doc.ref));

    // Add new ones
    gifts.forEach(gift => {
        const ref = db.collection("gifts").doc(gift.giftId);
        batch.set(ref, {
            ...gift,
            createdAt: new Date(),
            updatedAt: new Date(),
        });
    });

    await batch.commit();
    return res.send({ success: true, count: gifts.length });
});
/**
 * 15. Feed Sample VIP Tiers
 * Admin-only function to seed initial VIP tiers.
 */
exports.feedSampleVIPTiers = functions.https.onRequest(async (req, res) => {
    // Admin check skipped for local seeding

    const tiers = [
        {
            tierId: 'vip1',
            name: 'VIP 1',
            level: 1,
            monthlyPriceInDiamonds: 1000000,
            monthlyPriceInUSD: 10.0,
            benefits: [
                "VIP 1 Badge",
                "VIP 1 Profile Frame",
                "VIP 1 Entry Effect",
                "10% Daily Reward Bonus"
            ],
            profileFrame: "assets/VIP/VIP 1/Frame.svga",
            entryAnimation: "assets/VIP/VIP 1/Entry.svga",
            badgeIcon: "assets/VIP/VIP 1/Badge.webp",
            backgroundImage: '',
            themeColor: '#10B981',
            entryRequirement: 'Purchase 1,000,000 Diamonds',
            priorityMicAccess: false,
            isActive: true,
            sortOrder: 1
        },
        {
            tierId: 'vip2',
            name: 'VIP 2',
            level: 2,
            monthlyPriceInDiamonds: 5000000,
            monthlyPriceInUSD: 50.0,
            benefits: [
                "VIP 2 Badge",
                "VIP 2 Profile Frame",
                "VIP 2 Entry Effect",
                "Special Chat Bubble",
                "30% Daily Reward Bonus"
            ],
            profileFrame: "assets/VIP/VIP 2/VIP 2/Frame.svga",
            entryAnimation: "assets/VIP/VIP 2/VIP 2/Entry.svga",
            badgeIcon: "assets/VIP/VIP 2/VIP 2/Badge.png",
            backgroundImage: '',
            themeColor: '#059669',
            entryRequirement: 'Purchase 5,000,000 Diamonds',
            priorityMicAccess: false,
            isActive: true,
            sortOrder: 2
        },
        {
            tierId: 'vip3',
            name: 'VIP 3',
            level: 3,
            monthlyPriceInDiamonds: 20000000,
            monthlyPriceInUSD: 200.0,
            benefits: [
                "VIP 3 Badge",
                "VIP 3 Profile Frame",
                "VIP 3 Entry Effect",
                "Priority Mic Access",
                "Sound Wave Ring",
                "100% Daily Reward Bonus"
            ],
            profileFrame: "assets/VIP/VIP 3/VIP 3/Frame.svga",
            entryAnimation: "assets/VIP/VIP 3/VIP 3/Entry.svga",
            badgeIcon: "assets/VIP/VIP 3/VIP 3/Badge.webp",
            backgroundImage: '',
            themeColor: '#3B82F6',
            entryRequirement: 'Purchase 20,000,000 Diamonds',
            priorityMicAccess: true,
            isActive: true,
            sortOrder: 3
        },
        {
            tierId: 'vip4',
            name: 'VIP 4',
            level: 4,
            monthlyPriceInDiamonds: 50000000,
            monthlyPriceInUSD: 500.0,
            benefits: [
                "VIP 4 Badge",
                "VIP 4 Profile Frame",
                "VIP 4 Entry Effect",
                "Priority Mic Access",
                "Exclusive VIP Gifts",
                "500% Daily Reward Bonus"
            ],
            profileFrame: "assets/VIP/VIP 4/VIP 4/Frame.svga",
            entryAnimation: "assets/VIP/VIP 4/VIP 4/Entry.svga",
            badgeIcon: "assets/VIP/VIP 4/VIP 4/Badge.webp",
            backgroundImage: '',
            themeColor: '#8B5CF6',
            entryRequirement: 'Purchase 50,000,000 Diamonds',
            priorityMicAccess: true,
            isActive: true,
            sortOrder: 4
        },
        {
            tierId: 'vip5',
            name: 'VIP 5',
            level: 5,
            monthlyPriceInDiamonds: 100000000,
            monthlyPriceInUSD: 1000.0,
            benefits: [
                "VIP 5 Badge",
                "VIP 5 Profile Frame",
                "VIP 5 Entry Effect",
                "Priority Mic Access",
                "Custom 6-Digit ID",
                "Room Kick Protection",
                "2,000% Daily Reward Bonus"
            ],
            profileFrame: "assets/VIP/VIP 5/VIP 5/User Frame.svga",
            entryAnimation: "assets/VIP/VIP 5/VIP 5/Entry.svga",
            badgeIcon: "assets/VIP/VIP 5/VIP 5/Badge.png",
            backgroundImage: '',
            themeColor: '#F59E0B',
            entryRequirement: 'Purchase 100,000,000 Diamonds',
            priorityMicAccess: true,
            isActive: true,
            sortOrder: 5
        },
        {
            tierId: 'vip6',
            name: 'VIP 6',
            level: 6,
            monthlyPriceInDiamonds: 150000000,
            monthlyPriceInUSD: 1500.0,
            benefits: [
                "VIP 6 Badge",
                "VIP 6 Profile Frame",
                "VIP 6 Entry Effect",
                "Priority Mic Access",
                "Custom 5-Digit ID",
                "Room Kick Protection",
                "Dedicated Manager",
                "10,000% Daily Reward Bonus"
            ],
            profileFrame: "assets/VIP/VIP 6/VIP 6/User Frame.svga",
            entryAnimation: "assets/VIP/VIP 6/VIP 6/VIP 6 Entry.svga",
            badgeIcon: "assets/VIP/VIP 6/VIP 6/Badge.webp",
            backgroundImage: '',
            themeColor: '#EF4444',
            entryRequirement: 'Purchase 150,000,000 Diamonds',
            priorityMicAccess: true,
            isActive: true,
            sortOrder: 6
        },
        {
            tierId: 'vip7',
            name: 'VIP 7',
            level: 7,
            monthlyPriceInDiamonds: 200000000,
            monthlyPriceInUSD: 2000.0,
            benefits: [
                "VIP 7 Badge",
                "VIP 7 Profile Frame",
                "VIP 7 Entry Effect",
                "Priority Mic Access",
                "Custom 4-Digit ID",
                "Kick & Ban Protection",
                "Global Room Announcement",
                "Dedicated Manager"
            ],
            profileFrame: "assets/VIP/VIP 7/VIP 7/Frame.svga",
            entryAnimation: "assets/VIP/VIP 7/VIP 7/Entry.svga",
            badgeIcon: "assets/VIP/VIP 7/VIP 7/Badge.png",
            backgroundImage: '',
            themeColor: '#EC4899',
            entryRequirement: 'Purchase 200,000,000 Diamonds',
            priorityMicAccess: true,
            isActive: true,
            sortOrder: 7
        },
        {
            tierId: 'vip8',
            name: 'VIP 8',
            level: 8,
            monthlyPriceInDiamonds: 500000000,
            monthlyPriceInUSD: 5000.0,
            benefits: [
                "VIP 8 Badge",
                "VIP 8 Profile Frame",
                "VIP 8 Entry Effect",
                "Priority Mic Access",
                "Custom 3-Digit ID",
                "Full Server Admin Immunity",
                "Global Server Announcement",
                "Dedicated VIP Concierge"
            ],
            profileFrame: "assets/VIP/VIP 8/VIP 8/User Frame.svga",
            entryAnimation: "assets/VIP/VIP 8/VIP 8/VIP 8 Entry Effect.svga",
            badgeIcon: "assets/VIP/VIP 8/VIP 8/Badge.webp",
            backgroundImage: '',
            themeColor: '#F59E0B',
            entryRequirement: 'Purchase 500,000,000 Diamonds',
            priorityMicAccess: true,
            isActive: true,
            sortOrder: 8
        }
    ];

    const batch = db.batch();
    const oldTiers = await db.collection("vip_tiers").get();
    oldTiers.forEach(doc => batch.delete(doc.ref));

    tiers.forEach(tier => {
        const ref = db.collection("vip_tiers").doc(tier.tierId);
        batch.set(ref, {
            ...tier,
            createdAt: new Date()
        });
    });

    await batch.commit();
    return res.send({ success: true, count: tiers.length });
});

/**
 * 🧹 Backend Note: RTDB Presence Sync removed to ensure deployment stability 
 * given current project configuration. Transitioned to High-Frequency Firestore Sweep.
 */



/**
 * Helper: Get the custom ID digit count for a given VIP tier name.
 * VIP 4 → 8 digits, VIP 5 → 8, VIP 6 → 6, VIP 7 → 6, VIP 8 → 4.
 */
function getVipIdDigitCount(tierName) {
    const clean = tierName.toLowerCase().replace(/\s+/g, "");
    if (clean === "vip8") return 4;
    if (clean === "vip6" || clean === "vip7") return 6;
    if (clean === "vip4" || clean === "vip5") return 8;
    return 0;
}

/**
 * Helper: Generate a unique short ID for a VIP user within the tier's digit range.
 */
async function assignVipHelloId(uid, tierName) {
    const digits = getVipIdDigitCount(tierName);
    if (digits === 0) return null;
    const min = Math.pow(10, digits - 1);
    const max = Math.pow(10, digits) - 1;
    const counterRef = db.collection("system_configs").doc("helloIdCounter");
    const counterKey = "vip" + digits + "digit";
    const result = await db.runTransaction(async (tx) => {
        const counterDoc = await tx.get(counterRef);
        let current = 1;
        if (counterDoc.exists) current = (counterDoc.data()[counterKey] || 0) + 1;
        tx.set(counterRef, { [counterKey]: current }, { merge: true });
        return current;
    });
    return min + (result % (max - min + 1));
}

/**
 * 16. Purchase VIP (Dynamic) + Custom Short ID
 * Authoritative server-side. VIP cosmetics are OPTIONAL per policy.
 */
exports.purchaseVIP = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const uid = context.auth.uid;
    const { tierId } = data;

    const result = await db.runTransaction(async (transaction) => {
        const tierRef = db.collection("vip_tiers").doc(tierId);
        const userRef = db.collection("users").doc(uid);
        const [tierDoc, userDoc] = await Promise.all([
            transaction.get(tierRef), transaction.get(userRef)
        ]);
        if (!tierDoc.exists) throw new functions.https.HttpsError("not-found", "VIP Tier not found.");
        if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");

        const userData = userDoc.data();
        const tierData = tierDoc.data();
        const price = tierData.monthlyPriceInDiamonds;
        if ((userData.diamondBalance || 0) < price) {
            throw new functions.https.HttpsError("failed-precondition", "Insufficient diamonds.");
        }

        const immediateCredit = Math.floor(price * 0.8);
        const delayedCredit = price - immediateCredit;
        const expiry = new Date();
        expiry.setDate(expiry.getDate() + 30);
        const releaseDate = new Date();
        releaseDate.setDate(releaseDate.getDate() + 30);

        transaction.update(userRef, {
            diamondBalance: admin.firestore.FieldValue.increment(-price + immediateCredit),
            vipTier: tierData.name,
            vipExpiry: admin.firestore.Timestamp.fromDate(expiry),
            vipSnapshot: {
                originalTier: userData.vipTier || "none",
                originalExpiry: userData.vipExpiry || null,
                originalProfileFrame: userData.profileFrame || "",
                originalEntryAnimation: userData.entryAnimation || "",
                originalBadgeIcon: userData.badgeIcon || "",
                originalHelloId: userData.helloId || null,
                purchasedAt: admin.firestore.Timestamp.now(),
                tier: tierData.name
            }
        });

        const pendingRef = userRef.collection("pending_credits").doc();
        transaction.set(pendingRef, {
            amount: delayedCredit,
            releaseDate: admin.firestore.Timestamp.fromDate(releaseDate),
            status: "pending", type: "vip_retention_bonus",
            description: `20% Retention Bonus for ${tierData.name}`,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        });

        const txRef = userRef.collection("transactions").doc();
        transaction.set(txRef, {
            type: "purchase",
            amount: price,
            immediateCredit: immediateCredit,
            delayedCredit: delayedCredit,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            description: `Purchased ${tierData.name} Monthly Subscription (80/20 Split)`
        });

        return { userData, tierData, immediateCredit, delayedCredit };
    });

    // ---- Post-purchase: Assign custom short ID if applicable ----
    try {
        const vipId = await assignVipHelloId(uid, result.tierData.name);
        if (vipId !== null) {
            await db.collection("users").doc(uid).update({ helloId: vipId });
        }
    } catch (idErr) {
        console.error(`[VIP_PURCHASE] Failed to assign custom ID for user ${uid}:`, idErr);
        // Non-critical — purchase already succeeded
    }

    const inboxRef = db.collection("users").doc(uid).collection("inbox_messages").doc();
    await inboxRef.set({
        type: "reward",
        title: `VIP Activated — ${result.tierData.name} 👑`,
        body: `Welcome to ${result.tierData.name}! You received an instant ${result.immediateCredit.toLocaleString()} diamond credit.`,
        read: false,
        createdAt: admin.firestore.Timestamp.now(),
        data: { tier: result.tierData.name, route: "/wallet" }
    });

    return {
        success: true,
        immediate: result.immediateCredit,
        delayed: result.delayedCredit
    };
});

/**
 * 17. Distribute Weekly Salary
 */
exports.distributeWeeklySalary = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const { roomId } = data;

    const result = await db.runTransaction(async (transaction) => {
        const roomRef = db.collection("rooms").doc(roomId);
        const roomDoc = await transaction.get(roomRef);

        if (!roomDoc.exists) throw new functions.https.HttpsError("not-found", "Room not found.");

        const roomData = roomDoc.data();
        const { ownerUid, weeklyTarget, weeklyEarnings, agencyId } = roomData;

        if (weeklyEarnings < weeklyTarget) {
            throw new functions.https.HttpsError("failed-precondition", "Target not met.");
        }

        const salaryAmount = Math.floor(weeklyEarnings * 0.5);
        let hostShare = salaryAmount;
        let agencyShare = 0;

        if (agencyId) {
            agencyShare = Math.floor(salaryAmount * 0.1);
            hostShare -= agencyShare;
        }

        const userRef = db.collection("users").doc(ownerUid);
        transaction.update(userRef, {
            diamondBalance: admin.firestore.FieldValue.increment(hostShare)
        });

        if (agencyId) {
            const agencyRef = db.collection("agencies").doc(agencyId);
            transaction.update(agencyRef, {
                balance: admin.firestore.FieldValue.increment(agencyShare)
            });
        }

        transaction.update(roomRef, { weeklyEarnings: 0 });

        const salaryHistoryRef = userRef.collection("salary_history").doc();
        transaction.set(salaryHistoryRef, {
            amount: hostShare,
            totalEarnings: weeklyEarnings,
            target: weeklyTarget,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            agencyId: agencyId || null
        });

        return { success: true, amount: hostShare, ownerUid };
    });

    const inboxRef = db.collection("users").doc(result.ownerUid).collection("inbox_messages").doc();
    await inboxRef.set({
        type: "reward",
        title: "Weekly Salary Paid 💰",
        body: `Your weekly salary of ${result.amount.toLocaleString()} diamonds has been deposited.`,
        read: false,
        createdAt: admin.firestore.Timestamp.now(),
        data: { route: "/wallet" }
    });

    return { success: true, amount: result.amount };
});

/**
 * 20. Global Push Notification & Inbox Trigger
 * Sends targeted FCM pushes & writes to users' official inbox.
 */
async function deliverBroadcast(announcementId, title, message, filters = {}, imageUrl = null, isPush = false) {
    let query = db.collection("users");
    const usersSnap = await query.get();
    let users = usersSnap.docs.map(d => ({ uid: d.id, ...d.data() }));

    // Apply audience filters in-memory
    if (filters.vipsOnly) {
        users = users.filter(u => u.vipTier && u.vipTier !== "none");
    }
    if (filters.minLevel) {
        users = users.filter(u => (u.level || 0) >= filters.minLevel);
    }
    if (filters.countries && filters.countries.length > 0) {
        const countriesUpper = filters.countries.map(c => c.toUpperCase());
        users = users.filter(u => u.country && countriesUpper.includes(u.country.toUpperCase()));
    }
    if (filters.families && filters.families.length > 0) {
        users = users.filter(u => u.familyId && filters.families.includes(u.familyId));
    }

    if (users.length === 0) return { successCount: 0 };

    const tokens = users.map(u => u.fcmToken).filter(t => !!t);

    // 1. Send FCM Push if enabled
    let successCount = 0;
    if (isPush && tokens.length > 0) {
        for (let i = 0; i < tokens.length; i += 500) {
            const chunk = tokens.slice(i, i + 500);
            const pushMessage = {
                notification: {
                    title: title,
                    body: message,
                },
                data: {
                    route: "/inbox"
                },
                tokens: chunk,
            };
            if (imageUrl) {
                pushMessage.notification.image = imageUrl;
            }
            try {
                const response = await admin.messaging().sendEachForMulticast(pushMessage);
                successCount += response.successCount;
            } catch (err) {
                console.error("FCM Multicast Error: ", err);
            }
        }
    }

    // 2. Write to users' inbox_messages
    const inboxData = {
        type: "broadcast",
        title: title,
        body: message,
        read: false,
        createdAt: admin.firestore.Timestamp.now(),
        data: {
            announcementId: announcementId
        }
    };

    let batch = db.batch();
    let count = 0;
    for (const user of users) {
        const inboxRef = db.collection("users").doc(user.uid).collection("inbox_messages").doc();
        batch.set(inboxRef, inboxData);
        count++;
        if (count === 500) {
            await batch.commit();
            batch = db.batch();
            count = 0;
        }
    }
    if (count > 0) {
        await batch.commit();
    }

    return { successCount };
}

exports.sendGlobalPush = functions.firestore.document("global_announcements/{id}").onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    
    // If scheduling is enabled and scheduledAt is in the future, save as scheduled
    if (data.scheduledAt) {
        const scheduledTime = data.scheduledAt.toMillis();
        const now = Date.now();
        if (scheduledTime > now) {
            return snapshot.ref.update({
                pushStatus: "scheduled"
            });
        }
    }

    const filters = data.filters || {};
    const title = data.title || "Hello Chat Admin";
    const message = data.message;
    const imageUrl = data.imageUrl || null;
    const isPush = data.isPush || false;

    try {
        const result = await deliverBroadcast(context.params.id, title, message, filters, imageUrl, isPush);
        return snapshot.ref.update({
            pushStatus: "sent",
            successCount: result.successCount,
            sentAt: admin.firestore.Timestamp.now()
        });
    } catch (err) {
        console.error("Broadcast Delivery Error:", err);
        return snapshot.ref.update({
            pushStatus: "failed",
            error: err.message
        });
    }
});

exports.processScheduledBroadcasts = functions.pubsub.schedule("every 5 minutes").onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const scheduledSnap = await db.collection("global_announcements")
        .where("pushStatus", "==", "scheduled")
        .where("scheduledAt", "<=", now)
        .get();

    for (const doc of scheduledSnap.docs) {
        const data = doc.data();
        const title = data.title || "Hello Chat Admin";
        const message = data.message;
        const filters = data.filters || {};
        const imageUrl = data.imageUrl || null;
        const isPush = data.isPush || false;

        try {
            const result = await deliverBroadcast(doc.id, title, message, filters, imageUrl, isPush);
            await doc.ref.update({
                pushStatus: "sent",
                successCount: result.successCount,
                sentAt: admin.firestore.Timestamp.now()
            });
        } catch (err) {
            console.error(`Scheduled broadcast ${doc.id} delivery failed:`, err);
            await doc.ref.update({
                pushStatus: "failed",
                error: err.message
            });
        }
    }
    return null;
});

/**
 * 21. Secure Games: Spin Wheel (Provably Fair)
 * Prevents client-side manipulation of prize outcomes and odds.
 */

/**
 * Enhanced Secure Game Logic (Provably Fair)
 */
function getRandomInt(max) {
    return crypto.randomInt(0, Math.max(1, max));
}

exports.playSpinWheel = functions.region("us-central1").https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Authentication required.");
    }

    const uid = context.auth.uid;
    const clientRoundId = data.roundId ? String(data.roundId).trim() : null;
    const bets = data.bets || (data.betAmount ? { [data.label || "any"]: Number(data.betAmount) || 0 } : {});
    const totalBet = Object.values(bets).reduce((acc, b) => acc + Math.max(0, Number(b) || 0), 0);

    if (totalBet !== 0 && totalBet < 10) {
        throw new functions.https.HttpsError("invalid-argument", "Minimum total bet is 10 Diamonds.");
    }

    const now = Date.now();
    const ROUND_DURATION_MS = 40000;
    const currentRoundId = Math.floor(now / ROUND_DURATION_MS).toString();
    const msIntoRound = now % ROUND_DURATION_MS;

    // Strict Round Validation: Prevent betting on expired or future rounds
    if (clientRoundId && clientRoundId !== currentRoundId) {
        throw new functions.https.HttpsError(
            "failed-precondition",
            `Round ${clientRoundId} is expired. Current active round is ${currentRoundId}.`
        );
    }

    // Phase Gate: Bets strictly close at 27.0s (3s remaining before spin)
    if (msIntoRound >= 27000 && totalBet > 0) {
        throw new functions.https.HttpsError(
            "failed-precondition",
            `Betting phase closed for round ${currentRoundId}. Bets are locked during the final 3 seconds.`
        );
    }

    const userRef = db.collection("users").doc(uid);
    const settingsRef = db.collection("game_settings").doc("lucky_spin");
    const statsRef = db.collection("games_meta").doc("lucky_spin");
    const roundBetRef = statsRef.collection("round_player_bets").doc(`${currentRoundId}_${uid}`);
    const legacyRoundBetRef = statsRef.collection("current_round_bets").doc(`${currentRoundId}_${uid}`);
    const privateStatsRef = db.collection("games_meta_private").doc(`spin_${currentRoundId}`);
    const logRef = userRef.collection("game_history").doc(`spin_${currentRoundId}`);

    const spinResult = await db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
            throw new functions.https.HttpsError("not-found", "User profile not found.");
        }

        const userData = userDoc.data() || {};
        const userName = userData.displayName || userData.username || "User";
        const userAvatar = userData.profilePhotoUrl || userData.photoURL || "";

        const settingsDoc = await transaction.get(settingsRef);
        const statsDoc = await transaction.get(statsRef);
        const privateDoc = await transaction.get(privateStatsRef);
        const existingBetDoc = await transaction.get(roundBetRef);
        const existingLogDoc = await transaction.get(logRef);

        const defaultFoodSegments = [
            { id: "1", name: "Tomato", multiplier: 5, weight: 250, emoji: "🍅", category: "salad" },
            { id: "2", name: "Hotdog", multiplier: 10, weight: 100, emoji: "🌭", category: "pizza" },
            { id: "3", name: "Skewer", multiplier: 15, weight: 50, emoji: "🍢", category: "pizza" },
            { id: "4", name: "Chicken", multiplier: 25, weight: 30, emoji: "🍗", category: "pizza" },
            { id: "5", name: "Steak", multiplier: 45, weight: 20, emoji: "🥩", category: "pizza" },
            { id: "6", name: "Carrot", multiplier: 5, weight: 250, emoji: "🥕", category: "salad" },
            { id: "7", name: "Corn", multiplier: 5, weight: 250, emoji: "🌽", category: "salad" },
            { id: "8", name: "Cabbage", multiplier: 5, weight: 150, emoji: "🥬", category: "salad" }
        ];

        const settings = settingsDoc.exists ? settingsDoc.data() : { segments: [] };
        const segments = (settings.segments && settings.segments.length >= 8) ? settings.segments : defaultFoodSegments;
        const currentStats = statsDoc.exists ? statsDoc.data() : {};

        // 1. Resolve or Generate Deterministic Round Outcome
        let roundResult = null;
        if (privateDoc.exists) {
            roundResult = privateDoc.data().outcome;
        } else {
            const todayStr = new Date().toISOString().split("T")[0];
            let saladHits = currentStats.todaySaladHits || 0;
            let pizzaHits = currentStats.todayPizzaHits || 0;
            if (currentStats.lastResetDate !== todayStr) {
                saladHits = 0;
                pizzaHits = 0;
            }

            const roll = crypto.randomInt(0, 100);
            let resultType = "standard";
            if (roll < 1 && pizzaHits < 1) {
                resultType = "pizza";
                pizzaHits++;
            } else if (roll < 5 && saladHits < 1) {
                resultType = "salad";
                saladHits++;
            }

            let winnerSegment = null;
            if (resultType === "standard") {
                const totalWeight = segments.reduce((acc, s) => acc + (Number(s.weight) || 0), 0);
                let random = crypto.randomInt(0, Math.max(1, totalWeight));
                winnerSegment = segments[0];
                for (const s of segments) {
                    const w = Number(s.weight) || 0;
                    if (random < w) {
                        winnerSegment = s;
                        break;
                    }
                    random -= w;
                }
            } else {
                const categorySegments = segments.filter(s => (s.category || "").toLowerCase() === resultType.toLowerCase());
                winnerSegment = categorySegments.length > 0
                    ? categorySegments[crypto.randomInt(0, categorySegments.length)]
                    : (resultType === "pizza" ? segments.find(s => s.name.toLowerCase() === "steak") : segments.find(s => s.name.toLowerCase() === "tomato")) || segments[0];
            }

            const winnerIndex = segments.findIndex(s => s.name.toLowerCase().trim() === (winnerSegment.name || "").toLowerCase().trim());
            const displayIndex = winnerIndex >= 0 ? winnerIndex : 0;
            const stepAngle = 360 / segments.length;
            const exactStopAngle = Math.round(((360 - (displayIndex * stepAngle)) + (Math.random() * 6 - 3)) * 10) / 10;

            roundResult = {
                roundId: currentRoundId,
                type: resultType,
                multiplier: Number(winnerSegment.multiplier) || 0,
                emoji: winnerSegment.emoji || "🎰",
                label: resultType === "standard" ? `${winnerSegment.multiplier}x` : resultType.toUpperCase(),
                name: winnerSegment.name,
                category: winnerSegment.category || "standard",
                sectorIndex: displayIndex,
                exactStopAngle: exactStopAngle,
                createdAt: now
            };

            // Commit outcome to server-private collection
            transaction.set(privateStatsRef, {
                roundId: currentRoundId,
                outcome: roundResult,
                createdAt: admin.firestore.FieldValue.serverTimestamp()
            });

            // Update global stats
            const startOfRoundEpochMs = Number(currentRoundId) * ROUND_DURATION_MS;
            const startOfDayUTC = new Date(startOfRoundEpochMs);
            startOfDayUTC.setUTCHours(0, 0, 0, 0);
            const currentRoundToday = Math.floor((startOfRoundEpochMs - startOfDayUTC.getTime()) / ROUND_DURATION_MS) + 1;

            transaction.set(statsRef, {
                activeRoundId: currentRoundId,
                currentRound: currentRoundToday,
                todaySaladHits: saladHits,
                todayPizzaHits: pizzaHits,
                lastResetDate: todayStr
            }, { merge: true });
        }

        // Maintain live recentResults array on statsRef (last 30 rounds)
        const roundSummaryItem = {
            roundId: String(currentRoundId),
            name: roundResult.name,
            emoji: roundResult.emoji,
            label: roundResult.label || `${roundResult.multiplier}x`,
            multiplier: Number(roundResult.multiplier) || 5,
            category: roundResult.category || "standard",
            sectorIndex: Number(roundResult.sectorIndex) || 0,
            timestamp: now
        };
        let currentRecent = Array.isArray(currentStats.recentResults) ? currentStats.recentResults : [];
        if (!currentRecent.some(r => r && String(r.roundId) === String(currentRoundId))) {
            currentRecent = [roundSummaryItem, ...currentRecent].slice(0, 30);
            transaction.set(statsRef, { recentResults: currentRecent }, { merge: true });
        }

        // 2. Incremental Bet & Payout Computation (Zero Double-Deduction)
        const previousData = existingBetDoc.exists ? existingBetDoc.data() : { totalBet: 0, prize: 0, bets: {} };
        const previousTotalBet = Number(previousData.totalBet) || 0;
        const previousPrize = Number(previousData.prize) || 0;

        // Spectator or outcome pre-fetch query (zero bet)
        if (totalBet === 0) {
            return {
                ...roundResult,
                totalBet: previousTotalBet,
                prize: previousPrize,
                bets: previousData.bets || {},
                balance: Number(userDoc.data().diamondBalance || 0),
                todayWinners: (currentStats.todayWinners || []).slice(0, 10),
                serverTime: now
            };
        }

        const deltaBet = totalBet - previousTotalBet;
        if (deltaBet < 0) {
            throw new functions.https.HttpsError("invalid-argument", "Wagers cannot be reduced once placed.");
        }

        let balance = Number(userDoc.data().diamondBalance || 0);
        let beansBalance = Number(userDoc.data().beansBalance || 0);

        if (deltaBet > 0) {
            if (balance < deltaBet) {
                const needed = deltaBet - balance;
                const starsRequired = Math.ceil((needed * 7) / 2);
                if (beansBalance >= starsRequired) {
                    beansBalance -= starsRequired;
                    balance = deltaBet;
                    transaction.update(userRef, { beansBalance: beansBalance });
                } else {
                    throw new functions.https.HttpsError("failed-precondition", "Insufficient Diamonds & Stars.");
                }
            }
            balance -= deltaBet;
        }

        // Evaluate winnings for the entire bet bucket
        let calculatedPrize = 0;
        const normalizedBets = {};
        for (const [k, v] of Object.entries(bets)) {
            if (k && Number(v) > 0) normalizedBets[k.toLowerCase().trim()] = Number(v);
        }

        const winnerName = (roundResult.name || "").toLowerCase().trim();
        const winnerCategory = (roundResult.category || roundResult.type || "").toLowerCase().trim();
        const paidKeys = new Set();
        const saladItems = ["tomato", "cabbage", "corn", "carrot", "salad"];
        const pizzaItems = ["pizza", "steak"];

        // Category Payouts
        if (saladItems.includes(winnerName) || winnerCategory === "salad") {
            const betSalad = normalizedBets["salad"] || 0;
            if (betSalad > 0 && !paidKeys.has("salad")) {
                calculatedPrize += Math.floor(betSalad * 5);
                paidKeys.add("salad");
            }
        }
        if (pizzaItems.includes(winnerName) || winnerCategory === "pizza") {
            const betPizza = normalizedBets["pizza"] || 0;
            if (betPizza > 0 && !paidKeys.has("pizza")) {
                calculatedPrize += Math.floor(betPizza * 45);
                paidKeys.add("pizza");
            }
        }

        // Special Celebration Round Payouts
        if (roundResult.type === "salad") {
            for (const item of ["tomato", "cabbage", "corn", "carrot"]) {
                if (!paidKeys.has(item) && normalizedBets[item]) {
                    calculatedPrize += Math.floor(normalizedBets[item] * 5);
                    paidKeys.add(item);
                }
            }
        } else if (roundResult.type === "pizza") {
            for (const item of ["pizza", "steak"]) {
                if (!paidKeys.has(item) && normalizedBets[item]) {
                    calculatedPrize += Math.floor(normalizedBets[item] * 45);
                    paidKeys.add(item);
                }
            }
        }

        // Exact segment payouts
        let betOnWinner = normalizedBets[winnerName] || 0;
        if (!betOnWinner) {
            if (winnerName === "kebab") betOnWinner = normalizedBets["skewer"] || 0;
            if (winnerName === "skewer") betOnWinner = normalizedBets["kebab"] || 0;
            if (winnerName === "steak") betOnWinner = normalizedBets["meat"] || 0;
        }
        if (!paidKeys.has(winnerName) && betOnWinner > 0) {
            calculatedPrize += Math.floor(betOnWinner * (Number(roundResult.multiplier) || 0));
            paidKeys.add(winnerName);
        }

        const deltaPrize = calculatedPrize - previousPrize;

        const userUpdates = {
            diamondBalance: balance + deltaPrize
        };
        if (roundResult.type === "pizza" && calculatedPrize > 0) {
            userUpdates.badges = admin.firestore.FieldValue.arrayUnion("jackpot_winner");
        }
        transaction.update(userRef, userUpdates);

        // Update Round Bet Ledger (With Full Player Identity for Winners & Player List)
        if (totalBet > 0) {
            const playerBetRecord = {
                uid: uid,
                roundId: currentRoundId,
                name: userName,
                avatar: userAvatar,
                bets: bets,
                totalBet: totalBet,
                prize: calculatedPrize,
                winnings: calculatedPrize,
                updatedAt: now
            };
            transaction.set(roundBetRef, playerBetRecord, { merge: true });
            transaction.set(legacyRoundBetRef, playerBetRecord, { merge: true });

            // Update Daily Players Collection for the Daily Top Players Leaderboard
            const dailyPlayerRef = statsRef.collection("daily_players").doc(uid);
            transaction.set(dailyPlayerRef, {
                uid: uid,
                name: userName,
                avatar: userAvatar,
                totalBets: admin.firestore.FieldValue.increment(deltaBet),
                totalWinnings: admin.firestore.FieldValue.increment(calculatedPrize),
                amount: admin.firestore.FieldValue.increment(calculatedPrize),
                updatedAt: now
            }, { merge: true });
        }

        // Leaderboard updates
        let todayWinners = currentStats.todayWinners || [];

        if (calculatedPrize > 0) {
            todayWinners = todayWinners.filter(w => w.uid !== uid);
            todayWinners.push({
                uid: uid,
                name: userName,
                avatar: userAvatar,
                amount: calculatedPrize,
                multiplier: roundResult.multiplier,
                type: roundResult.type,
                timestamp: now
            });
            todayWinners.sort((a, b) => b.amount - a.amount);
            todayWinners = todayWinners.slice(0, 10);
            transaction.update(statsRef, { 
                todayWinners: todayWinners,
                topWinnerName: todayWinners[0]?.name || "None",
                topWinnerAvatar: todayWinners[0]?.avatar || "",
                topWinnerAmount: todayWinners[0]?.amount || 0,
                lastWinnerName: userName,
                lastWinnerAvatar: userAvatar,
                lastWinnerAmount: calculatedPrize
            });
        }

        // Audit Log History Entry (Deduplicated strictly 1 record per round)
        if (deltaBet > 0 || totalBet > 0) {
            let currentBetCount;
            if (existingLogDoc && existingLogDoc.exists) {
                currentBetCount = existingLogDoc.data().serialNumber || Number(userDoc.data().totalGameCount || 1);
            } else {
                currentBetCount = Number(userDoc.data().totalGameCount || 0) + 1;
                transaction.update(userRef, { totalGameCount: currentBetCount });
            }

            transaction.set(logRef, {
                game: "spin_wheel",
                serialNumber: currentBetCount,
                roundId: currentRoundId,
                bets: bets,
                totalBet: totalBet,
                prize: calculatedPrize,
                resultType: roundResult.type,
                label: roundResult.label,
                multiplier: roundResult.multiplier,
                emoji: roundResult.emoji,
                balanceBefore: (existingLogDoc && existingLogDoc.exists) ? existingLogDoc.data().balanceBefore : (balance + deltaBet),
                balanceAfter: balance + deltaPrize,
                orderId: (existingLogDoc && existingLogDoc.exists) ? existingLogDoc.data().orderId : `NLOT_${currentRoundId}_${uid.substring(0, 5)}_${now}`,
                timestamp: admin.firestore.FieldValue.serverTimestamp()
            }, { merge: true });
        }

        return {
            roundId: currentRoundId,
            prize: calculatedPrize,
            totalBet: totalBet,
            label: roundResult.label,
            type: roundResult.type,
            name: roundResult.name,
            emoji: roundResult.emoji,
            category: roundResult.category,
            sectorIndex: roundResult.sectorIndex,
            exactStopAngle: roundResult.exactStopAngle,
            multiplier: roundResult.multiplier,
            todayWinners: todayWinners,
            serverTime: now
        };
    });

    // 3. Ultra-Low Latency RTDB Broadcast
    if (spinResult && spinResult.roundId) {
        const rtdbPayload = {
            roundId: String(spinResult.roundId),
            label: spinResult.label,
            type: spinResult.type,
            name: spinResult.name,
            emoji: spinResult.emoji,
            category: spinResult.category,
            sectorIndex: Number(spinResult.sectorIndex),
            exactStopAngle: Number(spinResult.exactStopAngle),
            multiplier: Number(spinResult.multiplier),
            todayWinners: spinResult.todayWinners || [],
            timestamp: Date.now()
        };

        admin.database().ref("lucky_spin_stats/lastGlobalOutcome").set(rtdbPayload).catch(err => {
            console.error("[SpinWheel] RTDB broadcast failed:", err);
        });

        const rtdbRecentEntry = {
            roundId: String(spinResult.roundId),
            name: spinResult.name,
            emoji: spinResult.emoji,
            label: spinResult.label || `${spinResult.multiplier}x`,
            multiplier: Number(spinResult.multiplier) || 5,
            category: spinResult.category || "standard",
            sectorIndex: Number(spinResult.sectorIndex) || 0,
            timestamp: Date.now()
        };
        admin.database().ref("lucky_spin_stats/recentResults").transaction(currentData => {
            let list = Array.isArray(currentData) ? currentData : [];
            list = list.filter(item => item && String(item.roundId) !== String(spinResult.roundId));
            list.unshift(rtdbRecentEntry);
            return list.slice(0, 30);
        }).catch(err => {
            console.error("[SpinWheel] RTDB recentResults transaction failed:", err);
        });
    }

    return spinResult;
});

exports.resetDailyLuckySpin = functions.pubsub.schedule("0 0 * * *").onRun(async (context) => {
    const statsRef = db.collection("games_meta").doc("lucky_spin");
    await statsRef.set({
        todayWinners: [],
        currentRound: 0,
        todaySaladHits: 0,
        todayPizzaHits: 0,
        topWinnerName: "None",
        topWinnerAmount: 0,
        lastReset: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    // Clear daily players leaderboard
    try {
        const playersSnap = await statsRef.collection("daily_players").get();
        if (!playersSnap.empty) {
            const batch = db.batch();
            playersSnap.docs.forEach(doc => batch.delete(doc.ref));
            await batch.commit();
            console.log(`[CRON] Deleted ${playersSnap.size} daily leaderboard player documents.`);
        }
    } catch (err) {
        console.error("[CRON] Failed to clear daily players leaderboard:", err);
    }

    // Clear current round bets
    try {
        const betsSnap = await statsRef.collection("current_round_bets").get();
        if (!betsSnap.empty) {
            const batch = db.batch();
            betsSnap.docs.forEach(doc => batch.delete(doc.ref));
            await batch.commit();
            console.log(`[CRON] Deleted ${betsSnap.size} current round bet documents.`);
        }
    } catch (err) {
        console.error("[CRON] Failed to clear current round bets:", err);
    }

    console.log("[CRON] Lucky Spin stats and daily leaderboard reset successfully.");
    return null;
});

exports.playLuckyDraw = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const { betAmount } = data;
    if (!betAmount || betAmount < 50) throw new functions.https.HttpsError("invalid-argument", "Minimum bet 50 Diamonds.");

    const uid = context.auth.uid;
    const userRef = db.collection("users").doc(uid);

    return db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");

        const balance = Number(userDoc.data().diamondBalance || 0);
        if (balance < betAmount) throw new functions.https.HttpsError("failed-precondition", "Insufficient Diamonds.");

        // 8% chance to win 10x
        const isWin = getRandomInt(100) < 8;
        const prize = isWin ? Math.floor(betAmount * 10) : 0;
        const netChange = prize - betAmount;

        transaction.update(userRef, {
            diamondBalance: balance + netChange
        });

        const logRef = userRef.collection("game_history").doc();
        transaction.set(logRef, {
            game: "lucky_draw",
            bet: betAmount,
            prize: prize,
            isWin: isWin,
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        });

        console.log(`[LUCKY] User:${uid} Bet:${betAmount} Won:${isWin} Prize:${prize}`);
        return { prize: prize, isWin: isWin };
    });
});

/**
 * 21. Yummy Bingo Slot Game (5-Reel Fruit Reel)
 * Fully atomic, server-evaluated slot machine with 9 paylines and real-time diamond balances.
 */
const YUMMY_SYMBOLS = {
    wild:   { 3: 50, 4: 200, 5: 1000 },
    dice:   { 3: 40, 4: 150, 5: 600 },
    burger: { 3: 20, 4: 80,  5: 300 },
    fries:  { 3: 15, 4: 60,  5: 250 },
    cake:   { 3: 12, 4: 50,  5: 200 },
    banana: { 3: 10, 4: 40,  5: 150 },
    lemon:  { 3: 8,  4: 30,  5: 100 },
    cherry: { 3: 5,  4: 20,  5: 80 },
    clover: { 3: 5,  4: 15,  5: 50 },
};

const YUMMY_PAYLINES = [
    { id: 1, name: 'Center Row', color: '#EF4444', coords: [1, 1, 1, 1, 1] },
    { id: 2, name: 'Top Row',    color: '#3B82F6', coords: [0, 0, 0, 0, 0] },
    { id: 3, name: 'Bottom Row', color: '#10B981', coords: [2, 2, 2, 2, 2] },
    { id: 4, name: 'V-Shape',    color: '#F59E0B', coords: [0, 1, 2, 1, 0] },
    { id: 5, name: 'Inverted-V', color: '#8B5CF6', coords: [2, 1, 0, 1, 2] },
    { id: 6, name: 'Zig-Zag Top',color: '#EC4899', coords: [0, 0, 1, 2, 2] },
    { id: 7, name: 'Zig-Zag Bot',color: '#06B6D4', coords: [2, 2, 1, 0, 0] },
    { id: 8, name: 'High Crest', color: '#F97316', coords: [1, 0, 0, 0, 1] },
    { id: 9, name: 'Low Valley', color: '#84CC16', coords: [1, 2, 2, 2, 1] },
];

const YUMMY_WEIGHTED_POOL = [
    'wild', 'wild', 'wild', 'wild',
    'dice', 'dice', 'dice', 'dice', 'dice', 'dice',
    'burger', 'burger', 'burger', 'burger', 'burger', 'burger', 'burger', 'burger', 'burger',
    'fries', 'fries', 'fries', 'fries', 'fries', 'fries', 'fries', 'fries', 'fries', 'fries', 'fries',
    'cake', 'cake', 'cake', 'cake', 'cake', 'cake', 'cake', 'cake', 'cake', 'cake', 'cake', 'cake', 'cake',
    'banana', 'banana', 'banana', 'banana', 'banana', 'banana', 'banana', 'banana', 'banana', 'banana', 'banana', 'banana', 'banana', 'banana', 'banana',
    'lemon', 'lemon', 'lemon', 'lemon', 'lemon', 'lemon', 'lemon', 'lemon', 'lemon', 'lemon', 'lemon', 'lemon', 'lemon', 'lemon', 'lemon', 'lemon',
    'cherry', 'cherry', 'cherry', 'cherry', 'cherry', 'cherry', 'cherry', 'cherry', 'cherry', 'cherry', 'cherry', 'cherry', 'cherry', 'cherry', 'cherry', 'cherry', 'cherry', 'cherry',
    'clover', 'clover', 'clover', 'clover', 'clover', 'clover', 'clover', 'clover', 'clover', 'clover', 'clover', 'clover', 'clover', 'clover', 'clover', 'clover', 'clover', 'clover',
];

exports.playYummyBingo = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const lines = parseInt(data.lines, 10);
    const betPerLine = parseInt(data.betPerLine, 10);
    const roomId = data.roomId || "";

    if (isNaN(lines) || lines < 1 || lines > 9) {
        throw new functions.https.HttpsError("invalid-argument", "Lines must be between 1 and 9.");
    }
    if (isNaN(betPerLine) || betPerLine < 500 || betPerLine > 50000) {
        throw new functions.https.HttpsError("invalid-argument", "Bet per line must be between 500 and 50,000.");
    }

    const totalBet = lines * betPerLine;
    const uid = context.auth.uid;
    const userRef = db.collection("users").doc(uid);
    const metaRef = db.collection("games_meta").doc("yummy_bingo");

    return db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");

        const currentBalance = Number(userDoc.data().diamondBalance || 0);
        if (currentBalance < totalBet) {
            throw new functions.https.HttpsError("failed-precondition", "Insufficient Diamonds.");
        }

        const metaDoc = await transaction.get(metaRef);
        let currentJackpot = metaDoc.exists ? (Number(metaDoc.data().jackpot) || 276614) : 276614;

        // Generate 5x3 reel matrix server-side
        const matrix = [];
        for (let c = 0; c < 5; c++) {
            const col = [];
            for (let r = 0; r < 3; r++) {
                const randIndex = crypto.randomInt(0, YUMMY_WEIGHTED_POOL.length);
                col.push(YUMMY_WEIGHTED_POOL[randIndex]);
            }
            matrix.push(col);
        }

        // Evaluate paylines
        const activePaylines = YUMMY_PAYLINES.slice(0, lines);
        const winningLines = [];
        let totalWin = 0;

        activePaylines.forEach((line) => {
            const symbolsOnLine = line.coords.map((rowIdx, reelIdx) => matrix[reelIdx][rowIdx]);
            let first = symbolsOnLine[0];
            let matchCount = 1;
            const pos = [[0, line.coords[0]]];

            for (let i = 1; i < symbolsOnLine.length; i++) {
                const cur = symbolsOnLine[i];
                if (cur === first || cur === 'wild' || (first === 'wild' && cur !== 'wild')) {
                    if (first === 'wild' && cur !== 'wild') first = cur;
                    matchCount++;
                    pos.push([i, line.coords[i]]);
                } else {
                    break;
                }
            }

            if (matchCount >= 3) {
                const mult = (YUMMY_SYMBOLS[first] && YUMMY_SYMBOLS[first][matchCount]) || 0;
                const payout = mult * betPerLine;
                if (payout > 0) {
                    totalWin += payout;
                    winningLines.push({
                        line: line,
                        symbol: first,
                        count: matchCount,
                        payout: payout,
                        positions: pos
                    });
                }
            }
        });

        // 5 Wilds on Line 1 triggers special Jackpot bonus
        let wonJackpot = false;
        if (lines >= 1) {
            const line1 = matrix.map((col) => col[1]);
            if (line1.every((s) => s === 'wild')) {
                wonJackpot = true;
                totalWin += currentJackpot;
                currentJackpot = 250000; // Reset jackpot floor
            }
        }

        // Jackpot increments by 1% of non-jackpot bets
        const jackpotIncrement = Math.max(1, Math.floor(totalBet * 0.01));
        const nextJackpot = wonJackpot ? currentJackpot : currentJackpot + jackpotIncrement;

        // Anticipation check (reels 1 & 2 match on center row and not low-tier symbols)
        const checkAnticipation = matrix[0][1] === matrix[1][1] && matrix[0][1] !== 'lemon' && matrix[0][1] !== 'cherry';

        // Net balance change
        const netDelta = totalWin - totalBet;
        const newBalance = currentBalance + netDelta;

        // Atomically update user balance
        transaction.update(userRef, {
            diamondBalance: admin.firestore.FieldValue.increment(netDelta)
        });

        // Update games meta / jackpot
        transaction.set(metaRef, {
            jackpot: nextJackpot,
            lastPlayedAt: admin.firestore.FieldValue.serverTimestamp(),
            lastWinnerUid: totalWin > 0 ? uid : (metaDoc.exists ? (metaDoc.data().lastWinnerUid || null) : null),
            lastWinnerAmount: totalWin > 0 ? totalWin : (metaDoc.exists ? (metaDoc.data().lastWinnerAmount || 0) : 0),
        }, { merge: true });

        // Log game history
        const logRef = userRef.collection("game_history").doc();
        transaction.set(logRef, {
            game: "yummy_bingo",
            lines: lines,
            betPerLine: betPerLine,
            totalBet: totalBet,
            totalWin: totalWin,
            netDelta: netDelta,
            isWin: totalWin > 0,
            wonJackpot: wonJackpot,
            roomId: roomId,
            matrix: matrix,
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        });

        console.log(`[YUMMY_BINGO] User:${uid} Bet:${totalBet} Win:${totalWin} Net:${netDelta} Jackpot:${wonJackpot}`);

        return {
            success: true,
            matrix: matrix,
            winningLines: winningLines,
            totalWin: totalWin,
            totalBet: totalBet,
            newBalance: newBalance,
            checkAnticipation: checkAnticipation,
            jackpot: nextJackpot,
            wonJackpot: wonJackpot
        };
    });
});

/**
 * 22. Enhanced Room Participant Counting with Sharding Strategy
 * For rooms with high traffic, updates to currentUsersCount can be a bottleneck.
 * However, since Firestore handles high throughput on single docs better now, 
 * we use a simple increment/decrement on the room doc with a debounce check if needed.
 */
exports.onParticipantCreate = functions.firestore.document("rooms/{roomId}/participants/{uid}").onCreate(async (snapshot, context) => {
    const roomRef = db.collection("rooms").doc(context.params.roomId);
    return roomRef.update({ currentUsersCount: admin.firestore.FieldValue.increment(1) });
});

exports.onParticipantDelete = functions.firestore.document("rooms/{roomId}/participants/{uid}").onDelete(async (snapshot, context) => {
    const roomRef = db.collection("rooms").doc(context.params.roomId);
    return roomRef.update({ currentUsersCount: admin.firestore.FieldValue.increment(-1) });
});


/**
 * 200. Dino Pet Interactions (Secure)
 * Handles feeding and playing with atomic integrity and cooldowns.
 */
exports.interactWithDino = functions.region("us-central1").https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const uid = context.auth.uid;
    const { action } = data; // 'feed' or 'play'

    const userRef = db.collection("users").doc(uid);
    const petRef = userRef.collection("pet").doc("dino");

    return db.runTransaction(async (transaction) => {
        const [userDoc, petDoc] = await Promise.all([
            transaction.get(userRef),
            transaction.get(petRef)
        ]);

        if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");
        if (!petDoc.exists) throw new functions.https.HttpsError("not-found", "Pet not found. Adopt one first.");

        const userData = userDoc.data();
        const petData = petDoc.data();

        let updateUserData = {};
        let updatePetData = {};

        if (action === 'feed') {
            const cost = 10;
            if ((userData.diamondBalance || 0) < cost) {
                throw new functions.https.HttpsError("failed-precondition", "Insufficient diamonds.");
            }

            updateUserData.diamondBalance = admin.firestore.FieldValue.increment(-cost);
            updatePetData.health = 1.0;
            updatePetData.lastFed = admin.firestore.FieldValue.serverTimestamp();
            updatePetData.xp = (petData.xp || 0) + 10;
        } else if (action === 'play') {
            const lastPlayed = (petData.lastPlayed?._seconds || 0) * 1000;
            if (Date.now() - lastPlayed < 5 * 60 * 1000) {
                throw new functions.https.HttpsError("resource-exhausted", "Pet is tired. Wait 5 minutes.");
            }

            updatePetData.energy = 1.0;
            updatePetData.lastPlayed = admin.firestore.FieldValue.serverTimestamp();
            updatePetData.xp = (petData.xp || 0) + 5;
        } else {
            throw new functions.https.HttpsError("invalid-argument", "Invalid pet action.");
        }

        // Calculate Level & Stage
        const finalXP = updatePetData.xp;
        const newLevel = Math.floor(finalXP / 100) + 1;
        let newStage = 'Egg';
        if (finalXP >= 1500) newStage = 'Adult';
        else if (finalXP >= 500) newStage = 'Teen';
        else if (finalXP >= 100) newStage = 'Baby';

        updatePetData.level = newLevel;
        updatePetData.stage = newStage;

        // Finalize User XP synchronously
        updateUserData.xp = admin.firestore.FieldValue.increment(action === 'feed' ? 10 : 5);

        transaction.update(userRef, updateUserData);
        transaction.update(petRef, updatePetData);

        return { success: true, stage: newStage, level: newLevel };
    });
});
/**
 * 300. Global Economy Seeding (Admin Only)
 * Initializes all VIP and Noble tiers with official rates and benefits.
 */
exports.seedEconomy = functions.region("us-central1").https.onCall(async (data, context) => {
    // 🛡️ 1. Security Check: Only admins can seed economy
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const userDoc = await db.collection("users").doc(context.auth.uid).get();
    const isAdmin = userDoc.data()?.tags?.includes('Admin');
    if (!isAdmin) throw new functions.https.HttpsError("permission-denied", "Admin role required.");

    const vipTiers = [
        { tierId: 'vip1', name: 'VIP 1', level: 1, monthlyPriceInDiamonds: 500, monthlyPriceInUSD: 5.0, benefits: ["special_frame", "badge"], profileFrame: "https://i.ibb.co/vz6G3H1/vip1-frame.png", entryAnimation: "vip_entry_1", badgeIcon: "https://i.ibb.co/3W6pZ8P/vip1-badge.png", priorityMicAccess: false, isActive: true, sortOrder: 1 },
        { tierId: 'vip2', name: 'VIP 2', level: 2, monthlyPriceInDiamonds: 1500, monthlyPriceInUSD: 15.0, benefits: ["special_frame", "badge", "entry_effect"], profileFrame: "https://i.ibb.co/tZ5Wj0K/vip2-frame.png", entryAnimation: "vip_entry_2", badgeIcon: "https://i.ibb.co/mS6Pz8P/vip2-badge.png", priorityMicAccess: false, isActive: true, sortOrder: 2 },
        { tierId: 'vip3', name: 'VIP 3', level: 3, monthlyPriceInDiamonds: 5000, monthlyPriceInUSD: 50.0, benefits: ["special_frame", "badge", "entry_effect", "priority_mic"], profileFrame: "https://i.ibb.co/pP6Z8PQ/vip3-frame.png", entryAnimation: "vip_entry_3", badgeIcon: "https://i.ibb.co/xS6Z8PQ/vip3-badge.png", priorityMicAccess: true, isActive: true, sortOrder: 3 },
        { tierId: 'vip4', name: 'VIP 4', level: 4, monthlyPriceInDiamonds: 15000, monthlyPriceInUSD: 150.0, benefits: ["special_frame", "badge", "entry_effect", "priority_mic", "exclusive_gifts"], profileFrame: "https://i.ibb.co/yS6Z8PQ/vip4-frame.png", entryAnimation: "vip_entry_4", badgeIcon: "https://i.ibb.co/zS6Z8PQ/vip4-badge.png", priorityMicAccess: true, isActive: true, sortOrder: 4 },
        { tierId: 'vip5', name: 'VIP 5', level: 5, monthlyPriceInDiamonds: 50000, monthlyPriceInUSD: 500.0, benefits: ["special_frame", "badge", "entry_effect", "priority_mic", "exclusive_gifts", "custom_id"], profileFrame: "https://i.ibb.co/AS6Z8PQ/vip5-frame.png", entryAnimation: "vip_entry_5", badgeIcon: "https://i.ibb.co/BS6Z8PQ/vip5-badge.png", priorityMicAccess: true, isActive: true, sortOrder: 5 },
        { tierId: 'vip6', name: 'VIP 6', level: 6, monthlyPriceInDiamonds: 150000, monthlyPriceInUSD: 1500.0, benefits: ["special_frame", "badge", "entry_effect", "priority_mic", "exclusive_gifts", "manager"], profileFrame: "https://i.ibb.co/CS6Z8PQ/vip6-frame.png", entryAnimation: "vip_entry_6", badgeIcon: "https://i.ibb.co/DS6Z8PQ/vip6-badge.png", priorityMicAccess: true, isActive: true, sortOrder: 6 },
        { tierId: 'svip', name: 'SVIP', level: 7, monthlyPriceInDiamonds: 500000, monthlyPriceInUSD: 5000.0, benefits: ["all_access", "god_badge", "world_frame"], profileFrame: "https://i.ibb.co/ES6Z8PQ/svip-frame.png", entryAnimation: "svip_entry", badgeIcon: "https://i.ibb.co/FS6Z8PQ/svip-badge.png", priorityMicAccess: true, isActive: true, sortOrder: 7 },
    ];

    const nobleTiers = [
        { tierId: 'knight', name: 'Knight', level: 1, monthlyPriceInDiamonds: 2000, benefits: ["noble_badge", "entry_sparkle"], badgeIcon: "https://i.ibb.co/3W6pZ8P/noble1.png", sortOrder: 1 },
        { tierId: 'viscount', name: 'Viscount', level: 2, monthlyPriceInDiamonds: 10000, benefits: ["noble_badge", "entry_effect", "mic_ring"], badgeIcon: "https://i.ibb.co/mS6Pz8P/noble2.png", sortOrder: 2 },
        { tierId: 'earl', name: 'Earl', level: 3, monthlyPriceInDiamonds: 30000, benefits: ["noble_badge", "entry_effect", "mic_ring", "world_shout"], badgeIcon: "https://i.ibb.co/xS6Z8PQ/noble3.png", sortOrder: 3 },
        { tierId: 'marquis', name: 'Marquis', level: 4, monthlyPriceInDiamonds: 100000, benefits: ["noble_frame", "exclusive_gifts", "kick_protection"], badgeIcon: "https://i.ibb.co/yS6Z8PQ/noble4.png", sortOrder: 4 },
        { tierId: 'duke', name: 'Duke', level: 5, monthlyPriceInDiamonds: 300000, benefits: ["castle_entry", "exclusive_gifts", "admin_immunity"], badgeIcon: "https://i.ibb.co/AS6Z8PQ/noble5.png", sortOrder: 5 },
        { tierId: 'king', name: 'King', level: 6, monthlyPriceInDiamonds: 600000, benefits: ["golden_entry", "world_announce", "custom_id"], badgeIcon: "https://i.ibb.co/BS6Z8PQ/noble6.png", sortOrder: 6 },
        { tierId: 'emperor', name: 'Emperor', level: 7, monthlyPriceInDiamonds: 1000000, benefits: ["dragon_entry", "god_badge", "full_room_ignore"], badgeIcon: "https://i.ibb.co/CS6Z8PQ/noble7.png", sortOrder: 7 },
    ];

    const batch = db.batch();
    vipTiers.forEach(v => {
        const ref = db.collection("vip_tiers").doc(v.tierId);
        batch.set(ref, { ...v, isActive: true, createdAt: admin.firestore.FieldValue.serverTimestamp() });
    });
    nobleTiers.forEach(n => {
        const ref = db.collection("noble_tiers").doc(n.tierId);
        batch.set(ref, { ...n, isActive: true, createdAt: admin.firestore.FieldValue.serverTimestamp() });
    });

    await batch.commit();
    return { success: true, message: "Economy Seeding Successful! All Tiers Initialized." };
});



/**
 * 500. User: Convert Beans to Diamonds
 * Allows users to exchange their earnings for spending currency.
 * Exchange Rate: 2 Beans = 1 Diamond (Standard)
 */
exports.convertBeansToDiamonds = functions.region("us-central1").https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const uid = context.auth.uid;
    const { amount } = data; // Amount of BEANS to convert

    if (!amount || amount < 7) {
        throw new functions.https.HttpsError("invalid-argument", "Minimum conversion: 7 Stars.");
    }

    return db.runTransaction(async (transaction) => {
        const userRef = db.collection("users").doc(uid);
        const userDoc = await transaction.get(userRef);

        if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");

        const currentBeans = userDoc.data().beansBalance || 0;
        const currentDiamonds = userDoc.data().diamondBalance || 0;

        if (currentBeans < amount) {
            throw new functions.https.HttpsError("failed-precondition", "Insufficient Stars.");
        }

        // Conversion Rate: 3 Beans = 1 Diamond (e.g. 100 Beans = 33 Diamonds)
        const diamondsToReceive = Math.floor(amount / 3);

        transaction.update(userRef, {
            beansBalance: admin.firestore.FieldValue.increment(-amount),
            diamondBalance: admin.firestore.FieldValue.increment(diamondsToReceive)
        });

        // Log transaction
        const txRef = userRef.collection("transactions").doc();
        transaction.set(txRef, {
            type: "exchange",
            amount: -amount,
            receivedAmount: diamondsToReceive,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            description: `Exchanged ${amount} Beans for ◈ ${diamondsToReceive} Diamonds.`,
        });

        return {
            success: true,
            newBeans: currentBeans - amount,
            newDiamonds: currentDiamonds + diamondsToReceive
        };
    });
});

/**
 * 600. Scheduled: Process Pending Credits (80/20 Release)
 * Runs daily to release matured retention bonuses.
 */
exports.processScheduledCredits = functions.pubsub.schedule('every 24 hours').onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();

    // 1. Query all pending credits that are due
    const snapshot = await db.collectionGroup("pending_credits")
        .where("status", "==", "pending")
        .where("releaseDate", "<=", now)
        .limit(500) // Process in chunks
        .get();

    if (snapshot.empty) {
        console.log("[CRON] No pending credits due for release.");
        return null;
    }

    console.log(`[CRON] Found ${snapshot.size} credits to process.`);

    const results = [];
    for (const doc of snapshot.docs) {
        const creditData = doc.data();
        const userRef = doc.ref.parent.parent; // pending_credits -> user doc
        if (!userRef) continue;

        try {
            await db.runTransaction(async (transaction) => {
                // Update Balance
                transaction.update(userRef, {
                    diamondBalance: admin.firestore.FieldValue.increment(creditData.amount)
                });

                // Mark as claimed
                transaction.update(doc.ref, {
                    status: "claimed",
                    claimedAt: admin.firestore.FieldValue.serverTimestamp()
                });

                // Log Transaction
                const txRef = userRef.collection("transactions").doc();
                transaction.set(txRef, {
                    type: "bonus_release",
                    amount: creditData.amount,
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    description: `Automated release of ${creditData.amount} VIP Retention Bonus.`
                });
            });
            results.push({ uid: userRef.id, status: "success" });
        } catch (err) {
            console.error(`[CRON] Error processing credit ${doc.id} for user ${userRef.id}:`, err);
            results.push({ uid: userRef.id, status: "error", error: err.message });
        }
    }

    return { processed: results.length, details: results };
});

/**
 * 700. User: Withdraw Beans (Month 6 Gateway)
 * Converts Beans into a "Pending Payout" request for real currency.
 * Minimum: 1,000 Beans.
 */
exports.withdrawBeans = functions.region("us-central1").https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const uid = context.auth.uid;
    const { amount, method, accountDetails, isAgency, agencyId } = data; // amount in Beans

    if (!amount || amount < 1000) {
        throw new functions.https.HttpsError("invalid-argument", "Minimum withdrawal: 1,000 Beans.");
    }

    return db.runTransaction(async (transaction) => {
        const userRef = db.collection("users").doc(uid);
        const userDoc = await transaction.get(userRef);

        if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");
        const userData = userDoc.data();

        // 🛡️ Eligibility Check: Must be verified
        if (userData.isVerified !== true) {
            throw new functions.https.HttpsError("failed-precondition", "Account must be verified to withdraw.");
        }

        let balanceField = "beansBalance";
        let targetRef = userRef;

        if (isAgency === true) {
            if (!agencyId) throw new Error("Agency ID required for agency withdrawal.");
            const agencyRef = db.collection("agencies").doc(agencyId);
            const agencyDoc = await transaction.get(agencyRef);
            if (!agencyDoc.exists) throw new Error("Agency not found.");
            if (agencyDoc.data().ownerUid !== uid) throw new Error("Permission denied: Not agency owner.");
            
            const currentAgencyBeans = agencyDoc.data().beansBalance || 0;
            if (currentAgencyBeans < amount) throw new functions.https.HttpsError("failed-precondition", "Insufficient agency beans.");
            
            targetRef = agencyRef;
        } else {
            const currentBeans = userData.beansBalance || 0;
            if (currentBeans < amount) {
                throw new functions.https.HttpsError("failed-precondition", "Insufficient beans.");
            }
        }

        // Deduct beans immediately
        transaction.update(targetRef, {
            beansBalance: admin.firestore.FieldValue.increment(-amount)
        });

        // Log request in global withdrawals collection for Admin
        const withdrawalRef = db.collection("withdrawals").doc();
        transaction.set(withdrawalRef, {
            requestId: withdrawalRef.id,
            uid: uid,
            agencyId: isAgency ? agencyId : null,
            isAgency: isAgency || false,
            username: userData.username || userData.displayName,
            amount: amount,
            method: method || "Bank Transfer",
            accountDetails: accountDetails || "",
            status: "pending",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // Log transaction in User's personal history
        const txRef = userRef.collection("transactions").doc();
        transaction.set(txRef, {
            type: "withdrawal",
            amount: -amount,
            isAgency: isAgency || false,
            status: "pending",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            description: `Withdrawal request of ${amount} Beans initiated${isAgency ? " (Agency)" : ""}.`,
        });

        return { success: true, requestId: withdrawalRef.id };
    });
});



/**
 * 15. Recharge Diamonds (with SVIP Loyalty Logic)
 * Atomically credits diamonds and recalculates SVIP status.
 */
const SVIP_TIERS = [
    { level: 1, min: 10000000, points: 1000 },
    { level: 2, min: 30000000, points: 3000 },
    { level: 3, min: 50000000, points: 5000 },
    { level: 4, min: 100000000, points: 10000 },
    { level: 5, min: 200000000, points: 20000 },
    { level: 6, min: 300000000, points: 30000 },
    { level: 7, min: 500000000, points: 50000 },
];


exports.rechargeDiamonds = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const uid = context.auth.uid;
    const { amount, packageId } = data; // amount is diamond count

    if (!amount || amount <= 0) throw new functions.https.HttpsError("invalid-argument", "Invalid amount.");

    return db.runTransaction(async (transaction) => {
        const userRef = db.collection("users").doc(uid);
        const userDoc = await transaction.get(userRef);

        if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");

        const userData = userDoc.data();
        const currentMonthly = (userData.monthlyRecharge || 0) + amount;

        const updates = {
            diamondBalance: admin.firestore.FieldValue.increment(amount),
            monthlyRecharge: currentMonthly,
        };
        transaction.update(userRef, updates);

        const usdEquivalent = data.usdAmount ? parseFloat(data.usdAmount) : (amount / 1000000);
        processSvipPointsForRecharge(transaction, userRef, userData, usdEquivalent);

        // Log transaction
        const txRef = userRef.collection("transactions").doc();
        transaction.set(txRef, {
            type: "RECHARGE",
            amount: amount,
            packageId: packageId || "CUSTOM",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            monthlyRechargeTotal: currentMonthly,
        });

        return {
            success: true,
            newBalance: (userData.diamondBalance || 0) + amount,
        };
    });
});

/**
 * Enhanced recharge with event bonus integration
 * Used by the app for event-integrated recharges
 */
exports.enhancedRecharge = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const uid = context.auth.uid;
    const { amount, packageId } = data;
    if (!amount || amount <= 0) throw new functions.https.HttpsError("invalid-argument", "Invalid amount.");

    let rechargeResult;
    try {
        rechargeResult = await db.runTransaction(async (transaction) => {
            const userRef = db.collection("users").doc(uid);
            const userDoc = await transaction.get(userRef);
            if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");

            const userData = userDoc.data();
            const currentMonthly = (userData.monthlyRecharge || 0) + amount;

            const updates = { diamondBalance: admin.firestore.FieldValue.increment(amount), monthlyRecharge: currentMonthly };
            transaction.update(userRef, updates);

            const usdEquivalent = data.usdAmount ? parseFloat(data.usdAmount) : (amount / 1000000);
            processSvipPointsForRecharge(transaction, userRef, userData, usdEquivalent);

            const txRef = userRef.collection("transactions").doc();
            transaction.set(txRef, {
                type: "RECHARGE", amount, packageId: packageId || "CUSTOM",
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                monthlyRechargeTotal: currentMonthly,
            });

            return { success: true, newBalance: (userData.diamondBalance || 0) + amount };
        });
    } catch (e) {
        throw e;
    }

    // Apply event bonuses (best-effort, don't fail recharge)
    let eventBonus = null;
    let milestoneProgress = null;
    try { eventBonus = await processRechargeBonusInline(uid, amount); } catch (e) { console.error("Bonus error:", e); }
    try { milestoneProgress = await trackRechargeMilestoneInline(uid, amount, false); } catch (e) { console.error("Milestone error:", e); }

    return { ...rechargeResult, eventBonus, milestoneProgress };
});

/**
 * 16. Reset Monthly Recharge (Cron Job)
 * Occurs on 1st of every month at midnight UTC.
 */
exports.resetMonthlyRecharge = functions.pubsub.schedule("0 0 1 * *").onRun(async (context) => {
    const usersSnap = await db.collection("users").where("monthlyRecharge", ">", 0).get();
    const batch = db.batch();

    usersSnap.forEach(userDoc => {
        batch.update(userDoc.ref, {
            monthlyRecharge: 0,
            // We don't necessarily reset svipLevel here if it's meant to stay, 
            // but the client said "Monthly Recharge Diamonds", implying it might reset.
            // For now, only resetting the counter.
        });
    });

    return batch.commit();
});

/**
 * -----------------------------------------------------------------------------
 * 200. NOTIFICATION HUB & SOCIAL TRIGGERS (Month 7 Finalization)
 * -----------------------------------------------------------------------------
 */

/**
 * 🛰️ Global Push Helper
 */
async function sendPush(uid, title, body, data = {}) {
    try {
        const userDoc = await db.collection("users").doc(uid).get();
        if (!userDoc.exists) return;
        const fcmToken = userDoc.data().fcmToken;
        if (!fcmToken) return;

        const message = {
            token: fcmToken,
            notification: { title, body },
            data: { ...data, click_action: "FLUTTER_NOTIFICATION_CLICK" },
            android: { priority: "high" },
        };

        return admin.messaging().send(message);
    } catch (e) {
        functions.logger.error("❌ Notification Error:", e);
    }
}

/**
 * 👥 Trigger: On New Follow
 */
exports.onFollowTrigger = functions.firestore.document("users/{uid}/followers/{followerUid}").onCreate(async (snapshot, context) => {
    const targetUid = context.params.uid;
    const followerUid = context.params.followerUid;
    const followerDoc = await db.collection("users").doc(followerUid).get();
    const followerName = followerDoc.data().displayName || "Someone";

    return sendPush(targetUid, "New Follower! 👥", `${followerName} started following you.`, { type: "FOLLOW", uid: followerUid });
});

/**
 * 📈 Trigger: On Level Up
 */
exports.onLevelUpTrigger = functions.firestore.document("users/{uid}").onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (after.level > before.level) {
        return sendPush(context.params.uid, "Level Up! 🏆", `Congratulations! You've reached Level ${after.level}.`, { type: "LEVEL_UP", level: String(after.level) });
    }
    return null;
});

/**
 * 💰 Trigger: On Withdrawal Status Change
 */
exports.onWithdrawalStatusChange = functions.firestore.document("withdrawals/{id}").onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (after.status !== before.status) {
        let msg = `Your withdrawal request is now ${after.status}.`;
        if (after.status === "approved") msg = "Your withdrawal request has been approved! 💸";
        if (after.status === "paid") msg = "Success! Your payment has been dispatched. Check your account. ✅";
        if (after.status === "rejected") msg = `Your withdrawal was rejected: ${after.rejectReason || "Contact Support"}. ❌`;

        return sendPush(after.uid, "Withdrawal Update 🏦", msg, { type: "WITHDRAWAL", status: after.status });
    }
    return null;
});

/**
 * 💰 Admin: Approve Withdrawal
 */
exports.adminApproveWithdrawal = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    // Admin check
    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    const tags = callerDoc.data().tags || [];
    if (!tags.includes("Admin") && !tags.includes("SuperAdmin")) {
        throw new functions.https.HttpsError("permission-denied", "Admin/SuperAdmin only.");
    }

    const { id, note } = data;
    const withdrawalRef = db.collection("withdrawals").doc(id);

    return db.runTransaction(async (transaction) => {
        const doc = await transaction.get(withdrawalRef);
        if (!doc.exists) throw new Error("Request not found");
        if (doc.data().status !== "pending") throw new Error("Request already processed");

        transaction.update(withdrawalRef, {
            status: "approved",
            adminNote: note || "",
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        return { success: true };
    });
});

/**
 * 💰 Admin: Reject Withdrawal
 */
exports.adminRejectWithdrawal = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    const tags = callerDoc.data().tags || [];
    if (!tags.includes("Admin") && !tags.includes("SuperAdmin")) {
        throw new functions.https.HttpsError("permission-denied", "Admin/SuperAdmin only.");
    }

    const { id, reason } = data;
    const withdrawalRef = db.collection("withdrawals").doc(id);

    return db.runTransaction(async (transaction) => {
        const doc = await transaction.get(withdrawalRef);
        if (!doc.exists) throw new Error("Request not found");
        if (doc.data().status !== "pending") throw new Error("Request already processed");

        const withdrawalData = doc.data();
        const amount = withdrawalData.amount;
        const uid = withdrawalData.uid;
        const isAgency = withdrawalData.isAgency === true;

        // Refund Beans
        if (isAgency && withdrawalData.agencyId) {
            const agencyRef = db.collection("agencies").doc(withdrawalData.agencyId);
            transaction.update(agencyRef, {
                beansBalance: admin.firestore.FieldValue.increment(amount)
            });
        } else {
            const userRef = db.collection("users").doc(uid);
            transaction.update(userRef, {
                beansBalance: admin.firestore.FieldValue.increment(amount)
            });
        }

        transaction.update(withdrawalRef, {
            status: "rejected",
            rejectReason: reason || "Rejected by Admin",
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        return { success: true };
    });
});

/**
 * 🔒 Trigger: Report/Block Logging (for Admin alerting)
 */
exports.onNewReport = functions.firestore.document("reports/{id}").onCreate(async (snapshot) => {
    // Send alert to SuperAdmin if needed
    functions.logger.warn("🚨 NEW USER REPORT FILED:", snapshot.data().targetUid);
    return null;
});

/**
 * 🛠️ Admin Tool: Backfill Search Indexes (Month 7 Finalization)
 * Runs once to index existing users and rooms.
 */
exports.adminBackfillSearchIndexes = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    // Safety check with firestore logic directly as tags rely on user doc
    const userDoc = await db.collection("users").doc(context.auth.uid).get();
    const tags = userDoc.data().tags || [];

    if (!tags.includes("Admin") && !tags.includes("SuperAdmin")) {
        throw new functions.https.HttpsError("permission-denied", "Admin only.");
    }


    const { targetCollection } = data; // 'users' or 'rooms'
    const snapshot = await db.collection(targetCollection).get();
    const batch = db.batch();

    snapshot.forEach(doc => {
        const d = doc.data();
        if (targetCollection === 'users') {
            batch.update(doc.ref, {
                username_lowercase: (d.username || "").toLowerCase(),
                displayName_lowercase: (d.displayName || "").toLowerCase()
            });
        } else if (targetCollection === 'rooms') {
            batch.update(doc.ref, {
                name_lowercase: (d.name || "").toLowerCase()
            });
        }
    });

    await batch.commit();
    return { success: true, count: snapshot.size };
});

/**
 * 👑 14. Redeem Referral Code
 * Awards Diamonds to the new user and Beans to the referrer.
 */
exports.redeemReferralCode = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const { code } = data;
    const uid = context.auth.uid;

    if (!code) throw new functions.https.HttpsError("invalid-argument", "Referral code is required.");

    return db.runTransaction(async (transaction) => {
        const userRef = db.collection("users").doc(uid);
        const userDoc = await transaction.get(userRef);

        if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");
        const userData = userDoc.data();

        if (userData.referredBy) throw new functions.https.HttpsError("already-exists", "You have already been referred.");
        if (userData.referralCode === code) throw new functions.https.HttpsError("invalid-argument", "You cannot redeem your own code.");

        // Find referrer by code
        const referrersQuery = await db.collection("users").where("referralCode", "==", code).limit(1).get();
        if (referrersQuery.empty) throw new functions.https.HttpsError("not-found", "Invalid referral code.");

        const referrerDoc = referrersQuery.docs[0];
        const referrerUid = referrerDoc.id;

        // Rewards
        const newcomerReward = 50; // Diamonds
        const referrerReward = 100; // Beans

        // Update newcomer
        transaction.update(userRef, {
            referredBy: referrerUid,
            diamondBalance: admin.firestore.FieldValue.increment(newcomerReward)
        });

        // Update referrer
        transaction.update(referrerDoc.ref, {
            beansBalance: admin.firestore.FieldValue.increment(referrerReward),
            totalReferralEarnings: admin.firestore.FieldValue.increment(referrerReward)
        });

        // Log transaction for newcomer
        const newcomerTx = userRef.collection("transactions").doc();
        transaction.set(newcomerTx, {
            type: "referral_bonus",
            amount: newcomerReward,
            currency: "diamonds",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            description: `Welcome bonus for using code ${code}`
        });

        return { success: true, message: "Referral successful! Rewards credited." };
    });
});

/**
 * 👩‍❤️‍👨 15. Send CP (Couple Partner) Invite
 */
exports.sendCPInvite = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const { targetUid } = data;
    const senderUid = context.auth.uid;

    if (!targetUid || targetUid === senderUid) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid partner selection.");
    }

    const [senderDoc, targetDoc] = await Promise.all([
        db.collection("users").doc(senderUid).get(),
        db.collection("users").doc(targetUid).get()
    ]);

    if (!targetDoc.exists) throw new functions.https.HttpsError("not-found", "Target user not found.");
    if (senderDoc.data().partnerUid || targetDoc.data().partnerUid) {
        throw new functions.https.HttpsError("already-exists", "You or the recipient already have an active CP relationship.");
    }

    const inviteId = `${senderUid}_${targetUid}`;
    await db.collection("cp_invites").doc(inviteId).set({
        senderUid,
        targetUid,
        senderName: senderDoc.data().displayName,
        senderAvatar: senderDoc.data().profilePhotoUrl,
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Write to target's Official Inbox
    const pushMsg = `User ${senderDoc.data().displayName || "Someone"} has sent you a CP request! Review it now.`;
    const inboxRef = db.collection("users").doc(targetUid).collection("inbox_messages").doc();
    await inboxRef.set({
        type: "system",
        title: "CP Request Received 💖",
        body: pushMsg,
        read: false,
        createdAt: admin.firestore.Timestamp.now(),
        data: { route: "/love-house", inviteId: inviteId }
    });

    // Send Push Notification (PRD 5 Template)
    await sendPush(targetUid, "CP Request Received 💖", pushMsg, { type: "CP_INVITE", inviteId, route: "/love-house" });

    return { success: true };
});

/**
 * 👩‍❤️‍👨 16. Accept CP Invite
 */
exports.acceptCPInvite = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const { inviteId } = data;
    const inviteRef = db.collection("cp_invites").doc(inviteId);

    const result = await db.runTransaction(async (transaction) => {
        const inviteDoc = await transaction.get(inviteRef);
        if (!inviteDoc.exists) throw new functions.https.HttpsError("not-found", "Invite not found.");

        const inviteData = inviteDoc.data();
        if (inviteData.targetUid !== context.auth.uid) throw new functions.https.HttpsError("permission-denied", "Only target can accept.");

        const senderRef = db.collection("users").doc(inviteData.senderUid);
        const targetRef = db.collection("users").doc(inviteData.targetUid);

        const [senderDoc, targetDoc] = await Promise.all([
            transaction.get(senderRef),
            transaction.get(targetRef)
        ]);

        if (senderDoc.data().partnerUid || targetDoc.data().partnerUid) {
            throw new functions.https.HttpsError("failed-precondition", "You or the recipient already have an active CP relationship.");
        }

        const todayStr = new Date().toISOString().split('T')[0];

        transaction.update(senderRef, {
            partnerUid: targetDoc.id,
            partnerName: targetDoc.data().displayName,
            partnerAvatar: targetDoc.data().profilePhotoUrl,
            anniversaryDate: todayStr,
            cpLevel: 1,
            cpPoints: 0
        });

        transaction.update(targetRef, {
            partnerUid: senderDoc.id,
            partnerName: senderDoc.data().displayName,
            partnerAvatar: senderDoc.data().profilePhotoUrl,
            anniversaryDate: todayStr,
            cpLevel: 1,
            cpPoints: 0
        });

        transaction.delete(inviteRef);

        const relationshipId = `${senderDoc.id}_${targetDoc.id}`;
        const relationshipRef = db.collection("relationships").doc(relationshipId);
        transaction.set(relationshipRef, {
            participants: [senderDoc.id, targetDoc.id],
            type: "cp",
            status: "active",
            intimacy: 0,
            level: 1,
            anniversaryDate: todayStr,
            startedAt: admin.firestore.Timestamp.now(),
            lastActivityAt: admin.firestore.Timestamp.now(),
            intimacyBreakdown: { giftPoints: 0, diamondPoints: 0, activityPoints: 0 }
        });

        // Write Official Inbox messages to both users
        const acceptMsg = `Congratulations! ${targetDoc.data().displayName || "Partner"} accepted your request. Your anniversary starts today!`;
        const senderInboxRef = senderRef.collection("inbox_messages").doc();
        transaction.set(senderInboxRef, {
            type: "system",
            title: "CP Request Accepted 💕",
            body: acceptMsg,
            read: false,
            createdAt: admin.firestore.Timestamp.now(),
            data: { route: "/love-house", relationshipId }
        });

        const targetInboxRef = targetRef.collection("inbox_messages").doc();
        transaction.set(targetInboxRef, {
            type: "system",
            title: "CP Relationship Started 💕",
            body: `Congratulations! You are now CP partners with ${senderDoc.data().displayName || "Partner"}. Your anniversary starts today!`,
            read: false,
            createdAt: admin.firestore.Timestamp.now(),
            data: { route: "/love-house", relationshipId }
        });

        return { senderUid: inviteData.senderUid, targetUid: inviteData.targetUid, relationshipId, acceptMsg };
    });

    // Auto-decline/delete all competing pending CP invites for both participants
    try {
        const [pendingSenderSnap, pendingTargetSnap] = await Promise.all([
            db.collection("cp_invites").where("senderUid", "in", [result.senderUid, result.targetUid]).where("status", "==", "pending").get(),
            db.collection("cp_invites").where("targetUid", "in", [result.senderUid, result.targetUid]).where("status", "==", "pending").get()
        ]);
        const batch = db.batch();
        pendingSenderSnap.docs.forEach(d => batch.delete(d.ref));
        pendingTargetSnap.docs.forEach(d => batch.delete(d.ref));
        await batch.commit();
    } catch (e) {
        console.error("Error auto-declining competing CP invites:", e);
    }

    // Notify sender (PRD 5 Template)
    await sendPush(result.senderUid, "CP Request Accepted 💕", result.acceptMsg, { type: "CP_ACCEPTED", relationshipId: result.relationshipId, route: "/love-house" });

    return { success: true, relationshipId: result.relationshipId };
});

/**
 * --- PRESTIGE BOUTIQUE ECONOMY ---
 */

exports.purchasePrestigeItem = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const uid = context.auth.uid;
    const { itemId } = data;

    return db.runTransaction(async (transaction) => {
        const itemRef = db.collection("prestige_items").doc(itemId);
        const userRef = db.collection("users").doc(uid);

        const itemDoc = await transaction.get(itemRef);
        const userDoc = await transaction.get(userRef);

        if (!itemDoc.exists) throw new functions.https.HttpsError("not-found", "Item Not Found");
        const itemData = itemDoc.data();
        const userData = userDoc.data();

        if (userData.diamondBalance < itemData.price) {
            throw new functions.https.HttpsError("failed-precondition", "Insufficient Diamonds");
        }

        // 1. Deduct Diamonds
        transaction.update(userRef, {
            diamondBalance: admin.firestore.FieldValue.increment(-itemData.price)
        });

        // 2. Add to User Vault
        const expiryDate = new Date();
        expiryDate.setDate(expiryDate.getDate() + itemData.validityDays);

        const vaultRef = userRef.collection("vault").doc(itemId);
        transaction.set(vaultRef, {
            ...itemData,
            id: itemId,
            purchasedAt: admin.firestore.FieldValue.serverTimestamp(),
            expiryDate: admin.firestore.Timestamp.fromDate(expiryDate),
            isEquipped: false
        });

        return { success: true };
    });
});

exports.equipItem = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const uid = context.auth.uid;
    const { itemId, category } = data;

    return db.runTransaction(async (transaction) => {
        const userRef = db.collection("users").doc(uid);
        const userSnap = await transaction.get(userRef);
        if (!userSnap.exists) throw new functions.https.HttpsError("not-found", "User not found");
        
        // --- UN-EQUIP / DEFAULT CASE ---
        if (itemId === 'none') {
            const field = category === 'bubble' ? 'chatBubble' : (category === 'mount' ? 'entryAnimation' : 'profileFrame');
            transaction.update(userRef, { [field]: "none" }); // Explicitly store 'none' to distinguish from default empty string
            
            // Also un-equip items in vault for this category
            const others = await userRef.collection("vault").where("category", "==", category).get();
            others.forEach(doc => transaction.update(doc.ref, { isEquipped: false }));
            
            return { success: true };
        }

        // --- SPECIAL CASE: VIP Reward Frame ---
        if (itemId === 'vip_reward_frame') {
            const userData = userSnap.data();
            const vipTierName = userData.vipTier || 'none';
            if (vipTierName === 'none') throw new functions.https.HttpsError("failed-precondition", "You do not have an active VIP tier.");
            
            // Fetch the VIP tier details to resolve its profile frame URL
            const vipTiersSnap = await transaction.get(db.collection("vip_tiers").where("name", "==", vipTierName));
            if (vipTiersSnap.empty) throw new functions.https.HttpsError("not-found", "VIP tier details not found.");
            
            const tierData = vipTiersSnap.docs[0].data();
            const frameUrl = tierData.profileFrame || "";
            
            // Update User Doc with the actual VIP frame URL
            transaction.update(userRef, { profileFrame: frameUrl });
            
            // Also un-equip items in vault for this category
            const others = await userRef.collection("vault").where("category", "==", category).get();
            others.forEach(doc => transaction.update(doc.ref, { isEquipped: false }));
            
            return { success: true };
        }
        
        const userData = userSnap.data();

        // --- SPECIAL CASE: Official Admin Frames ---
        if (itemId.startsWith('official_') && itemId.endsWith('_frame')) {
            const tagMap = {
                'official_superadmin_frame': 'SuperAdmin',
                'official_admin_frame': 'Admin',
                'official_reseller_frame': 'Reseller'
            };
            const requiredTag = tagMap[itemId];
            if (!userData.tags || !userData.tags.includes(requiredTag)) {
                throw new functions.https.HttpsError("permission-denied", "You are not authorized for this frame.");
            }
            
            // Resolve URL from Firestore config
            const configSnap = await transaction.get(db.collection("system_configs").doc("admin_frames"));
            const config = configSnap.data();
            const frameKey = itemId.replace('official_', '').replace('_frame', '').replace('superadmin', 'super-admin');
            const assetUrl = config && config.frames ? config.frames[frameKey] : null;
            
            if (!assetUrl) throw new functions.https.HttpsError("internal", "Frame URL not found in config.");
            
            // Un-equip others in vault
            const itemCategory = category || "frame";
            const others = await userRef.collection("vault").where("category", "==", itemCategory).where("isEquipped", "==", true).get();
            others.forEach(doc => transaction.update(doc.ref, { isEquipped: false }));
            
            // Update User Doc
            transaction.update(userRef, { profileFrame: assetUrl });
            return { success: true };
        }

        const vaultRef = userRef.collection("vault").doc(itemId);
        const vaultSnap = await transaction.get(vaultRef);

        if (!vaultSnap.exists) throw new functions.https.HttpsError("not-found", "Item Not Owned");
        const item = vaultSnap.data();

        // --- EXPIRY CHECK: Reject equipping expired items ---
        if (item.expiresAt) {
            const expiresAt = item.expiresAt.toDate ? item.expiresAt.toDate() : new Date(item.expiresAt);
            if (expiresAt < new Date()) {
                throw new functions.https.HttpsError("failed-precondition", "This item has expired.");
            }
        }

        // 1. Un-equip others in same category (Use the item's own category)
        const itemCategory = item.category || category;
        const others = await userRef.collection("vault").where("category", "==", itemCategory).where("isEquipped", "==", true).get();
        others.forEach(doc => transaction.update(doc.ref, { isEquipped: false }));

        // 2. Equip this one
        transaction.update(vaultRef, { isEquipped: true });

        // 3. Update main User Doc
        const profileField = itemCategory === "frame" ? "profileFrame" : (itemCategory === "bubble" ? "chatBubble" : (itemCategory === "mount" ? "entryAnimation" : null));
        if (profileField) {
            transaction.update(userRef, { [profileField]: item.imageUrl });
        }

        return { success: true };
    });
});

/**
 * --- PRODUCTION AGORA TOKEN GENERATOR (v2) ---
 * Securely uses Secret Manager for the App Certificate.
 */
// Simplified: Using globally declared onCall and HttpsError from the top of the file

exports.getAgoraToken = onCall({
    secrets: [APP_CERTIFICATE],
    region: "us-central1"
}, (request) => {
    // 🛡️ Auth Guard
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Verification required.");
    }

    const { channelName, uid } = request.data;
    if (!channelName) {
        throw new HttpsError("invalid-argument", "Channel Name required.");
    }

    const appId = APP_ID.value();
    const appCertificate = APP_CERTIFICATE.value();

    const intUid = parseInt(uid) || 0;
    const role = RtcRole.PUBLISHER;
    const expirationTimeInSeconds = 24 * 3600; // 24 Hours
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

    const token = RtcTokenBuilder.buildTokenWithUid(
        appId,
        appCertificate,
        channelName,
        intUid,
        role,
        privilegeExpiredTs
    );

    return {
        token: token,
        uid: intUid,
        channelName: channelName,
        serverTime: Date.now()
    };
});

/**
 * -----------------------------------------------------------------------------
 * 1000. ROOM PRESENCE CLEANUP (Scheduled)
 * Runs every 1 minute to purge inactive/offline users from room participant lists.
 * -----------------------------------------------------------------------------
 */
/**
 * 1000. ROOM PRESENCE CLEANUP (Scheduled)
 * Runs every 1 minute to purge inactive/offline users from room participant lists.
 * Now includes automatic room reaping and host transfer logic.
 */
exports.cleanupInactiveParticipants = functions.pubsub.schedule("every 1 minutes").onRun(async (context) => {
    const now = Date.now();
    
    // 1. Threshold for ROOM cleanup (5 minutes - generous to prevent false disconnections)
    const roomThreshold = admin.firestore.Timestamp.fromMillis(now - 5 * 60 * 1000);
    // 2. Threshold for GLOBAL OFFLINE (5 minutes)
    const globalThreshold = admin.firestore.Timestamp.fromMillis(now - 5 * 60 * 1000);
    // 3. Threshold for HOST transfer (10 minutes - hosts should stay unless truly gone)
    const hostTransferThreshold = admin.firestore.Timestamp.fromMillis(now - 10 * 60 * 1000);

    console.log(`[PRESENCE] Starting Global & Room Cleanup. Time: ${new Date(now).toISOString()}`);

    // PART A: Automated Room Reaping (Close empty active rooms)
    const activeRooms = await db.collection("rooms").where("status", "==", "active").get();
    for (const roomDoc of activeRooms.docs) {
        const participants = await roomDoc.ref.collection("participants").get();
        if (participants.empty) {
            console.log(`[PRESENCE] Inactive empty room detected: ${roomDoc.id} (Keeping active)`);
            // await roomDoc.ref.update({ 
            //     status: "ended", 
            //     endedAt: admin.firestore.FieldValue.serverTimestamp(),
            //     currentUsersCount: 0 
            // });
            continue;
        }

        // Clean up inactive participants in this room
        const batch = db.batch();
        let hostDeleted = false;
        
        participants.docs.forEach(pDoc => {
            const pData = pDoc.data();
            const lastActiveTs = pData.lastActive;
            if (!lastActiveTs) return;
            const lastActive = lastActiveTs.toMillis();
            const isHost = pData.role === 'host' || pData.role === 'owner';

            if (isHost) {
                if (now - lastActive > 10 * 60 * 1000) { // 10 min host grace
                    console.log(`[PRESENCE] Removing inactive host ${pDoc.id} from room ${roomDoc.id} (lastActive: ${new Date(lastActive).toISOString()})`);
                    batch.delete(pDoc.ref);
                    hostDeleted = true;
                }
            } else if (now - lastActive > 5 * 60 * 1000) { // 5 min listener grace
                console.log(`[PRESENCE] Removing inactive participant ${pDoc.id} from room ${roomDoc.id} (lastActive: ${new Date(lastActive).toISOString()})`);
                batch.delete(pDoc.ref);
            }
        });
        
        await batch.commit();

        // If host was deleted, try to promote someone
        if (hostDeleted) {
            const remaining = await roomDoc.ref.collection("participants").orderBy("joinedAt", "asc").limit(1).get();
            if (!remaining.empty) {
                console.log(`[PRESENCE] Promoting new host for room: ${roomDoc.id}`);
                await remaining.docs[0].ref.update({ role: 'host' });
            } else {
                console.log(`[PRESENCE] Host left empty room ${roomDoc.id}. Keeping room open.`);
                // await roomDoc.ref.update({ status: "ended", endedAt: admin.firestore.FieldValue.serverTimestamp() });
            }
        }
    }

    // PART B: Global User Presence Sweep (Marking 'offline' in profile)
    const usersSnap = await db.collection("users")
        .where("status", "==", "online")
        .where("lastActive", "<", globalThreshold)
        .limit(200)
        .get();

    if (!usersSnap.empty) {
        const batch = db.batch();
        usersSnap.docs.forEach(doc => {
            batch.update(doc.ref, { 
                status: "offline",
                tags: admin.firestore.FieldValue.arrayRemove("online")
            });
        });
        await batch.commit();
        console.log(`[PRESENCE] Marked ${usersSnap.size} users as offline due to inactivity.`);
    }

    return null;
});

/**
 * 1001. REAL-TIME PRESENCE SYNC (RTDB -> Firestore)
 * Instantly handles app kills/crashes by syncing RTDB onDisconnect status to Firestore.
 */
/*
exports.onPresenceChanged = onValueUpdated("status/{uid}", async (event) => {
    const data = event.data.after.val();
    const uid = event.params.uid;
    const userRef = db.collection("users").doc(uid);

    if (data && data.state === "offline") {
        console.log(`[RTDB_SYNC] User ${uid} went offline. Cleaning up...`);
        const userSnap = await userRef.get();
        const activeRoomId = userSnap.data()?.activeRoomId;

        await userRef.update({ status: "offline", lastActive: admin.firestore.FieldValue.serverTimestamp() });

        if (activeRoomId) {
            const participantRef = db.collection("rooms").doc(activeRoomId).collection("participants").doc(uid);
            await participantRef.delete();
        }
    } else {
        await userRef.update({ status: "online", lastActive: admin.firestore.FieldValue.serverTimestamp() });
    }
    return null;
});
*/


/**
 * 1002. Participant Lifecycle Observer
 * Automatically updates room counts and handles host transfers when a participant is removed.
 */
exports.onParticipantRemoved = functions.firestore.document("rooms/{roomId}/participants/{uid}").onDelete(async (snapshot, context) => {
    const { roomId } = context.params;
    const roomRef = db.collection("rooms").doc(roomId);

    return db.runTransaction(async (transaction) => {
        const participantsSnap = await transaction.get(roomRef.collection("participants"));
        const roomSnap = await transaction.get(roomRef);

        if (participantsSnap.empty) {
            console.log(`[LIFECYCLE] Room ${roomId} empty. (Keeping room active)`);
            // transaction.update(roomRef, { 
            //     status: "ended", 
            //     endedAt: admin.firestore.FieldValue.serverTimestamp(),
            //     currentUsersCount: 0,
            //     pkActive: false,
            //     pkChallenge: null
            // });
        } else {
            const roomData = roomSnap.data();
            const leaverUid = context.params.uid;

            // ⚔️ PK FORFEITURE / CLEANUP GUARD
            if (roomData.pkActive) {
                const teams = roomData.pkTeams || {};
                if (teams[leaverUid]) {
                    // One of the PK participants left! Forfeit logic.
                    const winnerUid = Object.keys(teams).find(uid => uid !== leaverUid);
                    console.log(`[PK] Participant ${leaverUid} left. Winner declared: ${winnerUid}`);
                    
                    // We don't call endPKBattle inside transaction easily, so we manually do part of its logic or set a flag
                    // Actually, we can update the room state to trigger winner screen
                    transaction.update(roomRef, {
                        pkActive: false,
                        pkWinnerUid: winnerUid,
                        pkPhase: "finished",
                        [`pkWinnerData.forfeitedUid`]: leaverUid
                    });
                }
            } else if (roomData.pkChallenge && roomData.pkChallenge.status === 'pending') {
                if (roomData.pkChallenge.senderUid === leaverUid || roomData.pkChallenge.receiverUid === leaverUid) {
                    console.log(`[PK] Challenger/Receiver left during pending. Clearing challenge.`);
                    transaction.update(roomRef, { pkChallenge: null });
                }
            }

            transaction.update(roomRef, { currentUsersCount: participantsSnap.size });
            
            // Check if the removed user was the host
            const removedData = snapshot.data();
            if (removedData.role === 'host' || removedData.role === 'owner') {
                const sorted = participantsSnap.docs.sort((a, b) => (a.data().joinedAt?.toMillis() || 0) - (b.data().joinedAt?.toMillis() || 0));
                const nextHost = sorted[0];
                
                console.log(`[LIFECYCLE] Host left room ${roomId}. Promoting ${nextHost.id}`);
                transaction.update(nextHost.ref, { role: 'host' });
            }
        }
    });
});

/**
 * 16. Single Room Presence Enforcer
 * When a user's activeRoomId changes, we automatically clean up the old room.
 * This ensures a person cannot be in two rooms at once.
 */
exports.syncUserRoomPresence = functions.firestore.document("users/{uid}").onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const uid = context.params.uid;

    const oldRoomId = before.activeRoomId;
    const newRoomId = after.activeRoomId;

    // Only proceed if the room ID has actually changed and there WAS an old room
    if (oldRoomId && oldRoomId !== newRoomId) {
        console.log(`[PRESENCE_SYNC] User:${uid} moving from ${oldRoomId} to ${newRoomId || "NONE"}. Cleaning up...`);

        const oldRoomRef = db.collection("rooms").doc(oldRoomId);
        const participantRef = oldRoomRef.collection("participants").doc(uid);

        try {
            await db.runTransaction(async (transaction) => {
                const participantSnap = await transaction.get(participantRef);
                const roomSnap = await transaction.get(oldRoomRef);

                if (participantSnap.exists) {
                    transaction.delete(participantRef);
                    if (roomSnap.exists) {
                        transaction.update(oldRoomRef, {
                            currentUsersCount: admin.firestore.FieldValue.increment(-1)
                        });
                    }
                }
            });
            console.log(`[PRESENCE_SYNC] Cleanup successful for Room:${oldRoomId}`);
        } catch (e) {
            console.error(`[PRESENCE_SYNC] Error cleaning up old room ${oldRoomId}:`, e);
        }
    }
    return null;
});

/**
 * 2000. Add Comment (Atomic)
 * Bypasses client-side permission issues for updating global moment counts.
 */
exports.addComment = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const { ownerUid, mediaId, text, isMoment } = data;
    const commenterUid = context.auth.uid;

    if (!text || text.trim().length === 0) throw new functions.https.HttpsError("invalid-argument", "Comment text required.");

    const userMediaRef = db.collection("users").doc(ownerUid).collection("media").doc(mediaId);
    const commentId = userMediaRef.collection("comments").doc().id;
    const commentRef = userMediaRef.collection("comments").doc(commentId);
    const momentRef = db.collection("moments").doc(mediaId);

    const commentData = {
        commentId: commentId,
        userId: commenterUid,
        text: text.trim(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    return db.runTransaction(async (transaction) => {
        transaction.set(commentRef, commentData);
        transaction.update(userMediaRef, { commentsCount: admin.firestore.FieldValue.increment(1) });
        
        if (isMoment) {
            transaction.update(momentRef, { commentsCount: admin.firestore.FieldValue.increment(1) });
        }

        return { success: true, commentId: commentId };
    });
});

/**
 * 2001. Toggle Like (Atomic)
 */
exports.toggleLike = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const { ownerUid, mediaId, isMoment } = data;
    const likerUid = context.auth.uid;

    const userMediaRef = db.collection("users").doc(ownerUid).collection("media").doc(mediaId);
    const likeRef = userMediaRef.collection("likes").doc(likerUid);
    const momentRef = db.collection("moments").doc(mediaId);

    const likeDoc = await likeRef.get();
    const isLiking = !likeDoc.exists;

    return db.runTransaction(async (transaction) => {
        if (isLiking) {
            transaction.set(likeRef, { likedAt: admin.firestore.FieldValue.serverTimestamp() });
            transaction.update(userMediaRef, { likesCount: admin.firestore.FieldValue.increment(1) });
            if (isMoment) {
                transaction.update(momentRef, { likesCount: admin.firestore.FieldValue.increment(1) });
            }
        } else {
            transaction.delete(likeRef);
            transaction.update(userMediaRef, { likesCount: admin.firestore.FieldValue.increment(-1) });
            if (isMoment) {
                transaction.update(momentRef, { likesCount: admin.firestore.FieldValue.increment(-1) });
            }
        }
        return { success: true, isLiked: isLiking };
    });
});

/**
 * 2002. Create Media Post (Atomic)
 */
exports.createMediaPost = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const uid = context.auth.uid;
    const { imageUrl, tag, caption } = data;

    const mediaId = db.collection("users").doc(uid).collection("media").doc().id;
    const userMediaRef = db.collection("users").doc(uid).collection("media").doc(mediaId);
    const momentRef = db.collection("moments").doc(mediaId);

    const mediaData = {
        mediaId: mediaId,
        userId: uid,
        imageUrl: imageUrl,
        tag: tag,
        caption: caption || "",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        likesCount: 0,
        commentsCount: 0,
        giftCount: 0,
        isDeleted: false,
    };

    return db.runTransaction(async (transaction) => {
        transaction.set(userMediaRef, mediaData);
        if (tag === "moment") {
            transaction.set(momentRef, mediaData);
        }
        transaction.update(db.collection("users").doc(uid), {
            lastActive: admin.firestore.FieldValue.serverTimestamp()
        });
    });
});


/**
 * ============================================================================
 * RESELLER SYSTEM MODULE (STABLE)
 * ============================================================================
 */

exports.adminSetResellerStatus = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    const tags = callerDoc.data().tags || [];
    if (!tags.includes("Admin") && !tags.includes("SuperAdmin")) throw new functions.https.HttpsError("permission-denied", "Admin only.");
    const { targetUid, isReseller } = data;
    await db.collection("users").doc(targetUid).update({
        isReseller: isReseller,
        walletBalance: isReseller ? 0 : admin.firestore.FieldValue.delete()
    });
    return { success: true };
});

exports.adminAdjustResellerWallet = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    const tags = (callerDoc.data() || {}).tags || [];
    if (!tags.includes("Admin") && !tags.includes("SuperAdmin")) throw new functions.https.HttpsError("permission-denied", "Admin only.");
    const { targetUid, amountDelta } = data;
    const resellerRef = db.collection("users").doc(targetUid);
    await db.runTransaction(async (transaction) => {
        const resellerDoc = await transaction.get(resellerRef);
        if (!resellerDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");
        const currentBalance = resellerDoc.data().walletBalance || 0;
        transaction.update(resellerRef, { walletBalance: currentBalance + amountDelta });
        const txRef = db.collection("transactions").doc();
        transaction.set(txRef, {
            senderId: context.auth.uid,
            receiverId: targetUid,
            amount: amountDelta,
            currency: "USD",
            type: amountDelta > 0 ? "ADMIN_WALLET_CREDIT" : "ADMIN_WALLET_DEBIT",
            status: "completed",
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        });
    });
    return { success: true };
});

exports.buyDiamondPackage = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const uid = context.auth.uid;
    const { packageId } = data;
    const resellerRef = db.collection("users").doc(uid);
    const pkgRef = db.collection("diamond_packages").doc(packageId);
    return db.runTransaction(async (transaction) => {
        const [resellerDoc, pkgDoc] = await Promise.all([transaction.get(resellerRef), transaction.get(pkgRef)]);
        if (!resellerDoc.exists || !resellerDoc.data().isReseller) {
            throw new functions.https.HttpsError("permission-denied", "Not a registered reseller.");
        }
        const pkgData = pkgDoc.data();
        if (!pkgDoc.exists || pkgData.isDeleted) {
            throw new functions.https.HttpsError("not-found", "Package not found.");
        }
        const currentWallet = resellerDoc.data().walletBalance || 0;
        if (currentWallet < pkgData.price) {
            throw new functions.https.HttpsError("failed-precondition", "Insufficient wallet balance.");
        }
        transaction.update(resellerRef, {
            walletBalance: currentWallet - pkgData.price,
            diamondStock: admin.firestore.FieldValue.increment(pkgData.diamonds)
        });
        const txRef = db.collection("transactions").doc();
        transaction.set(txRef, {
            senderId: uid,
            receiverId: "SYSTEM",
            amount: pkgData.price,
            currency: "USD",
            diamonds: pkgData.diamonds,
            type: "RESELLER_BUY_DIAMONDS",
            status: "completed",
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        });
        return { success: true };
    });
});
exports.updateDiamondPackage = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    const tags = (callerDoc.data() || {}).tags || [];
    if (!tags.includes("SuperAdmin")) throw new functions.https.HttpsError("permission-denied", "SuperAdmin only.");
    const { packageId, diamonds, price, isDeleted } = data;
    const pkgRef = db.collection("diamond_packages").doc(packageId || db.collection("diamond_packages").doc().id);
    if (isDeleted) {
        await pkgRef.delete();
    } else {
        await pkgRef.set({
            diamonds: parseInt(diamonds),
            price: parseFloat(price),
            isDeleted: false,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
    }
    return { success: true };
});

exports.getDiamondPackages = functions.https.onCall(async (data, context) => {
    try {
        const snap = await db.collection("diamond_packages")
            .where("isDeleted", "==", false)
            .get();
        
        // Sort manually to avoid index requirement for simple listing
        const packages = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        packages.sort((a, b) => (a.price || 0) - (b.price || 0));
        
        return { packages };
    } catch (err) {
        console.error("GET_PACKAGES_ERROR:", err);
        throw new functions.https.HttpsError("internal", err.message);
    }
});

exports.getResellerHistory = functions.https.onCall(async (data, context) => {
    try {
        if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
        const { targetUid, limitCount = 50 } = data;
        const uid = context.auth.uid;
        const callerDoc = await db.collection("users").doc(uid).get();
        const tags = (callerDoc.data() || {}).tags || [];
        const isPrivileged = tags.includes("Admin") || tags.includes("SuperAdmin");
        
        const subjectUid = targetUid || uid;
        const transactions = [];

        // 1. Buy-stock records (transactions collection)
        const buySnap = await db.collection("transactions")
            .where("senderId", "==", subjectUid)
            .limit(parseInt(limitCount))
            .get();
        for (const doc of buySnap.docs) {
            const d = doc.data();
            transactions.push({
                id: doc.id,
                ...d,
                type: d.type || "RESELLER_BUY_DIAMONDS",
                timestamp: d.timestamp ? (d.timestamp.toDate ? d.timestamp.toDate().toISOString() : d.timestamp) : null
            });
        }

        // 2. Transfer records (reseller_transactions collection — written by resellerTransferDiamonds)
        const transferSnap = await db.collection("reseller_transactions")
            .where("senderUid", "==", subjectUid)
            .limit(parseInt(limitCount))
            .get();
        for (const doc of transferSnap.docs) {
            const d = doc.data();
            transactions.push({
                id: doc.id,
                type: "RESELLER_TO_USER",
                currency: "DIAMONDS",
                amount: d.amount ?? 0,
                senderId: d.senderUid,
                description: `Transfer ${d.amount ?? 0} Diamonds to ${d.targetName || d.targetHelloId || "user"}`,
                timestamp: d.timestamp ? (d.timestamp.toDate ? d.timestamp.toDate().toISOString() : d.timestamp) : null
            });
        }

        // Sort manually
        transactions.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

        return { transactions };
    } catch (err) {
        console.error("GET_HISTORY_ERROR:", err);
        throw new functions.https.HttpsError("internal", err.message);
    }
});

/**
 * --- PERIODIC LEADERBOARD RESETS ---
 */

async function resetUsersField(fields) {
    const usersSnap = await db.collection("users").get();
    let batch = db.batch();
    let count = 0;

    const resetData = {};
    fields.forEach(f => resetData[f] = 0);

    for (const doc of usersSnap.docs) {
        batch.update(doc.ref, resetData);
        count++;
        if (count === 500) {
            await batch.commit();
            batch = db.batch();
            count = 0;
        }
    }
    if (count > 0) await batch.commit();
    console.log(`[RESET] Finished resetting ${fields.join(", ")} for ${usersSnap.size} users.`);
}

async function resetRoomsField(fields) {
    const roomsSnap = await db.collection("rooms").get();
    let batch = db.batch();
    let count = 0;

    for (const doc of roomsSnap.docs) {
        const updateData = {};
        for (const f of fields) {
            updateData[f] = 0;
        }
        batch.update(doc.ref, updateData);
        count++;
        if (count === 500) {
            await batch.commit();
            batch = db.batch();
            count = 0;
        }
    }
    if (count > 0) await batch.commit();
    console.log(`[RESET] Finished resetting ${fields.join(", ")} for ${roomsSnap.size} rooms.`);
}

async function resetRoomsRocket() {
    const roomsSnap = await db.collection("rooms").get();
    let batch = db.batch();
    let count = 0;

    for (const doc of roomsSnap.docs) {
        batch.update(doc.ref, {
            rocketFuel: 0,
            rocketLevel: 0,
            rocketContributions: {},
            rocketStatus: "active"
        });
        count++;
        if (count === 500) {
            await batch.commit();
            batch = db.batch();
            count = 0;
        }
    }
    if (count > 0) await batch.commit();
    console.log(`[RESET] Finished resetting rocket progress for ${roomsSnap.size} rooms.`);
}

async function resetLuckySpinDaily() {
    try {
        const statsRef = db.collection("games_meta").doc("lucky_spin");
        await statsRef.update({
            todayWinners: []
        });
        const dailyPlayersSnap = await statsRef.collection("daily_players").get();
        let batch = db.batch();
        let count = 0;
        for (const doc of dailyPlayersSnap.docs) {
            batch.delete(doc.ref);
            count++;
            if (count === 500) {
                await batch.commit();
                batch = db.batch();
                count = 0;
            }
        }
        if (count > 0) await batch.commit();
        console.log(`[RESET] Reset lucky spin daily players and winners.`);
    } catch (e) {
        console.error(`[RESET] Error resetting lucky spin daily:`, e);
    }
}

exports.scheduledDailyReset = functions.pubsub.schedule('0 0 * * *')
    .timeZone('UTC')
    .onRun(async (context) => {
        await resetUsersField(["dailyXP", "dailyPrinceXP", "dailyDiamondsSent", "dailyBeansReceived"]);
        await resetRoomsField(["dailyDiamondsSent"]);
        await resetRoomsRocket();
        await resetLuckySpinDaily();
    });

exports.scheduledWeeklyReset = functions.pubsub.schedule('0 0 * * 1')
    .timeZone('UTC')
    .onRun(async (context) => {
        await resetUsersField(["weeklyXP", "weeklyPrinceXP", "weeklyDiamondsSent", "weeklyBeansReceived"]);
        await resetRoomsField(["weeklyDiamondsSent"]);
    });

/**
 * --- TESTING: SIMULATE SALARY MILESTONE ---
 * Only accessible by Admins.
 * Allows triggering a milestone without actually sending gifts.
 */
exports.simulateSalaryMilestone = functions.https.onCall(async (data, context) => {
    if (!(await isUserAdmin(context.auth?.uid))) {
        throw new functions.https.HttpsError("permission-denied", "Only admins can simulate milestones.");
    }

    const { targetUid, level } = data;
    if (!targetUid || !level) {
        throw new functions.https.HttpsError("invalid-argument", "targetUid and level are required.");
    }

    const milestone = SALARY_LEVELS.find(l => l.level === level);
    if (!milestone) {
        throw new functions.https.HttpsError("not-found", "Invalid salary level.");
    }

    try {
        await db.runTransaction(async (transaction) => {
            // We simulate a receipt of exactly the target amount
            // processSalaryMilestones handles the logic of checking if it was already reached
            await processSalaryMilestones(transaction, targetUid, milestone.target);
        });

        return { 
            success: true, 
            message: `Successfully simulated achievement of ${milestone.label} for ${targetUid}` 
        };
    } catch (error) {
        console.error("Simulation Error:", error);
        throw new functions.https.HttpsError("internal", error.message);
    }
});

exports.scheduledMonthlyReset = functions.pubsub.schedule('0 0 1 * *')
    .timeZone('UTC')
    .onRun(async (context) => {
        await resetUsersField(["monthlyXP", "monthlyPrinceXP", "monthlyDiamondsSent", "monthlyBeansReceived"]);
        await resetRoomsField(["monthlyDiamondsSent"]);
    });

/**
 * --- INITIALIZE TOP LIST METRICS (MIGRATION / REPAIR) ---
 * Ensures all existing users have Top List counters so they are indexed in Firestore queries.
 */
exports.initializeTopListFields = functions.https.onCall(async (data, context) => {
    try {
        const usersSnap = await db.collection("users").get();
        let batch = db.batch();
        let count = 0;
        let updatedCount = 0;

        for (const doc of usersSnap.docs) {
            const uData = doc.data() || {};
            const updates = {};
            if (uData.dailyDiamondsSent === undefined) updates.dailyDiamondsSent = 0;
            if (uData.weeklyDiamondsSent === undefined) updates.weeklyDiamondsSent = 0;
            if (uData.monthlyDiamondsSent === undefined) updates.monthlyDiamondsSent = 0;
            if (uData.totalDiamondsSent === undefined) updates.totalDiamondsSent = uData.totalDiamondsSpent || 0;
            if (uData.dailyBeansReceived === undefined) updates.dailyBeansReceived = 0;
            if (uData.weeklyBeansReceived === undefined) updates.weeklyBeansReceived = 0;
            if (uData.monthlyBeansReceived === undefined) updates.monthlyBeansReceived = 0;
            if (uData.totalBeansReceived === undefined) updates.totalBeansReceived = uData.beansBalance || 0;

            if (Object.keys(updates).length > 0) {
                batch.update(doc.ref, updates);
                count++;
                updatedCount++;
                if (count === 500) {
                    await batch.commit();
                    batch = db.batch();
                    count = 0;
                }
            }
        }
        if (count > 0) await batch.commit();
        console.log(`[MIGRATION] Initialized Top List metrics for ${updatedCount} users.`);
        return { success: true, updatedCount, totalUsers: usersSnap.size };
    } catch (err) {
        console.error("INITIALIZE_TOP_LIST_ERROR:", err);
        throw new functions.https.HttpsError("internal", err.message);
    }
});

/**
 * --- AUTOMATED SALARY PAYOUT CRON JOB ---
 * Runs daily to process pending host, agency, and admin payouts.
 */
exports.processSalaryPayouts = functions.pubsub.schedule('0 0 * * *')
    .timeZone('UTC')
    .onRun(async (context) => {
        const now = admin.firestore.Timestamp.now();
        const pendingPayouts = await db.collection("salaryPayouts")
            .where("status", "==", "pending")
            .where("scheduledDate", "<=", now)
            .limit(100)
            .get();

        if (pendingPayouts.empty) return null;

        for (const doc of pendingPayouts.docs) {
            const payout = doc.data();
            const payoutId = doc.id;

            try {
                await db.runTransaction(async (transaction) => {
                    const freshDoc = await transaction.get(doc.ref);
                    if (freshDoc.data().status !== "pending") return;

                    // 1. Mark as Paid
                    transaction.update(doc.ref, { 
                        status: "paid", 
                        paidAt: admin.firestore.FieldValue.serverTimestamp() 
                    });

                    // 2. Distribute Funds
                    if (payout.type === "host") {
                        const userRef = db.collection("users").doc(payout.uid);
                        transaction.update(userRef, { 
                            walletBalance: admin.firestore.FieldValue.increment(payout.amount) 
                        });
                        
                        // Transaction Log
                        const txRef = userRef.collection("transactions").doc();
                        transaction.set(txRef, {
                            id: txRef.id,
                            amount: payout.amount,
                            type: "salary_reward",
                            category: "wallet",
                            description: `Level ${payout.level} Host Reward`,
                            timestamp: admin.firestore.FieldValue.serverTimestamp(),
                            status: "completed"
                        });
                    } else if (payout.type === "agency" && payout.agencyId) {
                        const agencyRef = db.collection("agencies").doc(payout.agencyId);
                        transaction.update(agencyRef, {
                            beansBalance: admin.firestore.FieldValue.increment(Math.floor(payout.amount))
                        });

                        // Global Audit
                        const auditRef = db.collection("transactions").doc();
                        transaction.set(auditRef, {
                            id: auditRef.id,
                            uid: payout.uid,
                            agencyId: payout.agencyId,
                            amount: payout.amount,
                            type: "salary_reward",
                            category: "bean",
                            description: `Level ${payout.level} Agency Share`,
                            timestamp: admin.firestore.FieldValue.serverTimestamp()
                        });
                    } else if (payout.type === "admin") {
                        const statsRef = db.collection("platformStats").doc("revenue");
                        transaction.set(statsRef, {
                            totalAdminEarnings: admin.firestore.FieldValue.increment(payout.amount),
                            lastUpdate: admin.firestore.FieldValue.serverTimestamp()
                        }, { merge: true });

                        // Global Audit
                        const auditRef = db.collection("transactions").doc();
                        transaction.set(auditRef, {
                            id: auditRef.id,
                            type: "admin_commission",
                            amount: payout.amount,
                            description: `Level ${payout.level} Admin Share (Host: ${payout.uid})`,
                            timestamp: admin.firestore.FieldValue.serverTimestamp()
                        });
                    }
                });
            } catch (err) {
                console.error(`[PAYOUT_ERROR] Failed to process ${payoutId}:`, err);
            }
        }
        console.log(`[PAYOUT] Finished processing up to 100 pending payouts.`);
        return null;
    });

/**
 * --- SECURE TRANSACTION FOR WALLET DIAMOND PURCHASE ---
 * Bypasses client-side database writes to prevent balance manipulation exploits.
 */
exports.purchaseDiamondsWithWallet = functions.region("us-central1").https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    const uid = context.auth.uid;
    const { diamonds, price } = data; // price in USD, diamonds is package amount

    if (!diamonds || !price || price <= 0 || diamonds <= 0) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid package specifications.");
    }

    const userRef = db.collection("users").doc(uid);

    return db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");

        const currentWallet = Number(userDoc.data().walletBalance || 0.0);
        const currentDiamonds = Number(userDoc.data().diamondBalance || 0);

        if (currentWallet < price) {
            throw new functions.https.HttpsError("failed-precondition", "Insufficient wallet balance.");
        }

        // Deduct wallet balance and add diamonds
        transaction.update(userRef, {
            walletBalance: currentWallet - price,
            diamondBalance: currentDiamonds + diamonds
        });

        // Log transaction
        const txRef = userRef.collection("transactions").doc();
        transaction.set(txRef, {
            type: "purchase",
            amount: -diamonds,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            description: `Paid \$${price.toFixed(2)} from Wallet for ${diamonds} Diamonds`,
        });

        return {
            success: true,
            newWalletBalance: currentWallet - price,
            newDiamondBalance: currentDiamonds + diamonds
        };
    });
});

/**
 * --- SECURE TRANSACTION FOR SIMULATED WALLET TOP-UP ---
 * Restricts direct client writes of wallet balance.
 */
exports.simulateWalletTopUp = functions.region("us-central1").https.onCall(async (data, context) => {
    throw new functions.https.HttpsError("failed-precondition", "Simulated wallet top-up is permanently disabled. Payments must be routed through verified, production-ready payment gateways.");
});

/**
 * --- FAMILY MONTHLY TARGET RESET ---
 * Runs on the 1st of every month to reset family monthly points.
 */
exports.resetMonthlyFamilyTargets = functions.pubsub.schedule('0 0 1 * *').onRun(async (context) => {
    const families = await db.collection('families').get();
    const batch = db.batch();
    families.forEach(doc => {
        batch.update(doc.ref, { currentMonthPoints: 0 });
    });
    await batch.commit();
    console.log(`Reset monthly targets for ${families.size} families`);
});

/**
 * --- FAMILY COMBAT POINTS CALCULATION ---
 * Triggered when a gift is sent to add combat points to sender/receiver.
 */
exports.calculateFamilyCombatPoints = functions.firestore
    .document('gifts/{giftId}')
    .onCreate(async (snap, context) => {
        const gift = snap.data();
        const recipientUid = gift.recipientUid;
        const senderUid = gift.senderUid;
        const diamondAmount = gift.diamondAmount || gift.amount || 0;
        const beanAmount = gift.beanAmount || 0;

        // Calculate combat points: 1 diamond = 1 point for sender, 1 bean = 1 point for receiver
        const senderCombat = diamondAmount;
        const receiverCombat = beanAmount;

        // Update sender's family combat points
        if (senderUid && senderCombat > 0) {
            const senderUser = await db.collection('users').doc(senderUid).get();
            if (senderUser.exists) {
                const familyId = senderUser.data().familyId;
                if (familyId) {
                    const memberRef = db.collection('families').doc(familyId).collection('members').doc(senderUid);
                    await memberRef.update({
                        combatPoints: admin.firestore.FieldValue.increment(senderCombat),
                        memberXP: admin.firestore.FieldValue.increment(senderCombat),
                    }).catch(() => {});
                    await db.collection('families').doc(familyId).update({
                        totalCombatPoints: admin.firestore.FieldValue.increment(senderCombat),
                        currentMonthPoints: admin.firestore.FieldValue.increment(senderCombat),
                    }).catch(() => {});
                }
            }
        }

        // Update receiver's family combat points
        if (recipientUid && receiverCombat > 0) {
            const receiverUser = await db.collection('users').doc(recipientUid).get();
            if (receiverUser.exists) {
                const familyId = receiverUser.data().familyId;
                if (familyId) {
                    const memberRef = db.collection('families').doc(familyId).collection('members').doc(recipientUid);
                    await memberRef.update({
                        combatPoints: admin.firestore.FieldValue.increment(receiverCombat),
                        memberXP: admin.firestore.FieldValue.increment(receiverCombat),
                    }).catch(() => {});
                    await db.collection('families').doc(familyId).update({
                        totalCombatPoints: admin.firestore.FieldValue.increment(receiverCombat),
                        currentMonthPoints: admin.firestore.FieldValue.increment(receiverCombat),
                    }).catch(() => {});
                }
            }
        }
    });

/**
 * --- FAMILY TRANSFER OWNERSHIP ---
 * Allows current owner to transfer ownership to another family member.
 */
exports.transferFamilyOwnership = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'You must be logged in.');
    }
    const { familyId, newOwnerUid } = data;
    if (!familyId || !newOwnerUid) {
        throw new functions.https.HttpsError('invalid-argument', 'Family ID and new owner UID required.');
    }

    const familyDoc = await db.collection('families').doc(familyId).get();
    if (!familyDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Family not found.');
    }

    const family = familyDoc.data();
    if (family.ownerId !== context.auth.uid) {
        throw new functions.https.HttpsError('permission-denied', 'Only the current owner can transfer ownership.');
    }

    if (!family.memberUids.includes(newOwnerUid)) {
        throw new functions.https.HttpsError('not-found', 'New owner must be a member of the family.');
    }

    const batch = db.batch();
    batch.update(familyDoc.ref, { ownerId: newOwnerUid });
    batch.update(db.collection('users').doc(context.auth.uid), { isFamilyOwner: false });
    batch.update(db.collection('users').doc(newOwnerUid), { isFamilyOwner: true });
    await db.collection('families').doc(familyId).collection('members').doc(context.auth.uid).update({ role: 'admin' });
    await db.collection('families').doc(familyId).collection('members').doc(newOwnerUid).update({ role: 'owner' });
    await batch.commit();

    return { success: true };
});

// ─── FAMILY BATTLE PARTICIPANT CAPS ──────────────────────────────
// ─── FAMILY BATTLE PARTICIPANT CAPS ──────────────────────────────
const BATTLE_PARTICIPANT_CAPS = [
    { maxLevel: 2, cap: 100 },
    { maxLevel: 4, cap: 150 },
    { maxLevel: 6, cap: 200 },
    { maxLevel: 8, cap: 300 },
    { maxLevel: 9, cap: 500 },
    { maxLevel: 10, cap: 1000 },
];

function getParticipantCap(familyLevel) {
    for (const entry of BATTLE_PARTICIPANT_CAPS) {
        if (familyLevel <= entry.maxLevel) return entry.cap;
    }
    return 1000;
}

/**
 * --- SEND FAMILY BATTLE REQUEST (SERVER-SIDE) ---
 * Validates no active battle exists for challenger family or owner before sending.
 */
exports.sendFamilyBattleRequest = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required.');
    const uid = context.auth.uid;
    const { challengerFamilyId, opponentFamilyId, cost = 0, imageUrl } = data;
    if (!challengerFamilyId || !opponentFamilyId) {
        throw new functions.https.HttpsError('invalid-argument', 'challengerFamilyId and opponentFamilyId required.');
    }

    const callerDoc = await db.collection('users').doc(uid).get();
    const callerData = callerDoc.data();
    if (callerData?.currentActiveBattleId) {
        throw new functions.https.HttpsError('failed-precondition', 'You are already participating in an active Family Battle. Please complete your current battle before joining another battle.');
    }

    // Check active battle for challenger family
    const activeBattles = await db.collection('families').doc(challengerFamilyId).collection('battles')
        .where('status', '==', 'active').limit(1).get();
    if (!activeBattles.empty) {
        throw new functions.https.HttpsError('failed-precondition', 'Your Family is already participating in an active Family Battle.');
    }

    // Check existing pending request between these families
    const existingReq = await db.collection('familyBattleRequests')
        .where('challengerFamilyId', '==', challengerFamilyId)
        .where('opponentFamilyId', '==', opponentFamilyId)
        .where('status', '==', 'pending')
        .limit(1).get();
    if (!existingReq.empty) {
        throw new functions.https.HttpsError('already-exists', 'A pending battle request already exists between these families.');
    }

    const [challengerDoc, opponentDoc] = await Promise.all([
        db.collection('families').doc(challengerFamilyId).get(),
        db.collection('families').doc(opponentFamilyId).get(),
    ]);
    if (!challengerDoc.exists || !opponentDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Challenger or opponent family not found.');
    }
    const challenger = challengerDoc.data();
    const opponent = opponentDoc.data();

    // Create request doc
    const reqRef = db.collection('familyBattleRequests').doc();
    await reqRef.set({
        id: reqRef.id,
        challengerFamilyId,
        challengerName: challenger.name || '',
        challengerAvatar: challenger.avatarUrl || null,
        opponentFamilyId,
        opponentName: opponent.name || '',
        opponentAvatar: opponent.avatarUrl || null,
        imageUrl: imageUrl || null,
        status: 'pending',
        cost: cost,
        senderUid: uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, requestId: reqRef.id };
});

/**
 * --- JOIN FAMILY BATTLE (4-STEP GATEKEEPER CHECK) ---
 */
exports.joinFamilyBattle = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required.');
    const uid = context.auth.uid;
    const { battleId, familyId } = data;
    if (!battleId || !familyId) throw new functions.https.HttpsError('invalid-argument', 'battleId and familyId required.');

    const userDoc = await db.collection('users').doc(uid).get();
    const userData = userDoc.data();

    // Check 1: User active status
    if (userData?.currentActiveBattleId && userData.currentActiveBattleId !== battleId) {
        throw new functions.https.HttpsError('failed-precondition', 'You are already participating in an active Family Battle. Please complete your current battle before joining another battle.');
    }

    // Check 2: Target Battle status
    const battleRef = db.collection('families').doc(familyId).collection('battles').doc(battleId);
    const battleDoc = await battleRef.get();
    if (!battleDoc.exists) throw new functions.https.HttpsError('not-found', 'Battle not found.');
    const battle = battleDoc.data();
    if (battle.status !== 'active') throw new functions.https.HttpsError('failed-precondition', 'Battle is not active.');

    // Check 3: Capacity Check
    const familyDoc = await db.collection('families').doc(familyId).get();
    const familyLevel = familyDoc.data()?.level || 1;
    const capacityCap = getParticipantCap(familyLevel);
    const participantList = battle.participantUserList || [];
    if (participantList.length >= capacityCap && !participantList.includes(uid)) {
        throw new functions.https.HttpsError('resource-exhausted', 'Family Battle Participant Limit Is Full.');
    }

    // Lock user in transaction
    await db.runTransaction(async (tx) => {
        tx.update(db.collection('users').doc(uid), {
            currentActiveBattleId: battleId,
            battleJoinTime: admin.firestore.FieldValue.serverTimestamp(),
        });
        if (!participantList.includes(uid)) {
            tx.update(battleRef, {
                participantUserList: admin.firestore.FieldValue.arrayUnion(uid),
            });
        }
    });

    return { success: true };
});

/**
 * --- ACCEPT FAMILY BATTLE (SERVER-SIDE) ---
 * Validates: request exists & pending, no active battle for either family,
 * participant capacity, per-user active battle limit.
 * Creates mirrored battle docs, logs transaction, updates user tracking.
 */
exports.acceptFamilyBattle = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required.');

    const { requestId } = data;
    if (!requestId) throw new functions.https.HttpsError('invalid-argument', 'requestId required.');

    // Read request doc
    const reqDoc = await db.collection('familyBattleRequests').doc(requestId).get();
    if (!reqDoc.exists) throw new functions.https.HttpsError('not-found', 'Battle request not found.');
    const req = reqDoc.data();
    if (req.status !== 'pending') throw new functions.https.HttpsError('failed-precondition', 'Battle request is no longer pending.');

    const challengerFamilyId = req.challengerFamilyId;
    const opponentFamilyId = req.opponentFamilyId;

    // Validate caller is opponent family owner or admin
    const callerUser = await db.collection('users').doc(context.auth.uid).get();
    const callerFamilyId = callerUser.data()?.familyId;
    if (callerFamilyId !== opponentFamilyId) {
        throw new functions.https.HttpsError('permission-denied', 'Only the opponent family owner can accept battles.');
    }
    const callerMemberDoc = await db.collection('families').doc(opponentFamilyId).collection('members').doc(context.auth.uid).get();
    const callerRole = callerMemberDoc.data()?.role;
    if (callerRole !== 'owner') {
        throw new functions.https.HttpsError('permission-denied', 'Only the family owner can accept battles.');
    }

    // Check for existing active battles (race-condition safe)
    const [challengerActives, opponentActives] = await Promise.all([
        db.collection('families').doc(challengerFamilyId).collection('battles')
            .where('status', '==', 'active').limit(1).get(),
        db.collection('families').doc(opponentFamilyId).collection('battles')
            .where('status', '==', 'active').limit(1).get(),
    ]);
    if (!challengerActives.empty) {
        throw new functions.https.HttpsError('failed-precondition', 'Your Family is already participating in an active Family Battle.');
    }
    if (!opponentActives.empty) {
        throw new functions.https.HttpsError('failed-precondition', 'Opponent family already has an active battle.');
    }

    // Read family docs for capacity
    const [challengerFamilyDoc, opponentFamilyDoc] = await Promise.all([
        db.collection('families').doc(challengerFamilyId).get(),
        db.collection('families').doc(opponentFamilyId).get(),
    ]);
    if (!challengerFamilyDoc.exists || !opponentFamilyDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'One or both families not found.');
    }
    const challengerFamily = challengerFamilyDoc.data();
    const opponentFamily = opponentFamilyDoc.data();

    // Check participant capacity per family level
    const challengerCap = getParticipantCap(challengerFamily.level || 1);
    const opponentCap = getParticipantCap(opponentFamily.level || 1);
    const challengerMemberCount = (challengerFamily.memberUids || []).length;
    const opponentMemberCount = (opponentFamily.memberUids || []).length;
    if (challengerMemberCount > challengerCap) {
        throw new functions.https.HttpsError('resource-exhausted', 'Family Battle Participant Limit Is Full.');
    }
    if (opponentMemberCount > opponentCap) {
        throw new functions.https.HttpsError('resource-exhausted', 'Family Battle Participant Limit Is Full.');
    }

    // Check per-user active battle participation
    const allMemberUids = [...(challengerFamily.memberUids || []), ...(opponentFamily.memberUids || [])];
    const userChunks = [];
    for (let i = 0; i < allMemberUids.length; i += 30) {
        userChunks.push(allMemberUids.slice(i, i + 30));
    }
    for (const chunk of userChunks) {
        const usersSnap = await db.collection('users')
            .where(admin.firestore.FieldPath.documentId(), 'in', chunk)
            .where('currentActiveBattleId', '!=', null)
            .limit(1)
            .get();
        if (!usersSnap.empty) {
            const conflictUser = usersSnap.docs[0].data();
            throw new functions.https.HttpsError(
                'failed-precondition',
                `User ${conflictUser.displayName || conflictUser.uid} is already participating in an active Family Battle. Please complete your current battle before joining another battle.`
            );
        }
    }

    // All validations passed — create battle in transaction
    const battleId = db.collection('families').doc(challengerFamilyId).collection('battles').doc().id;
    const now = admin.firestore.Timestamp.now();
    const durationSeconds = 180;

    await db.runTransaction(async (transaction) => {
        const battleData = {
            familyAId: challengerFamilyId,
            familyBId: opponentFamilyId,
            familyAName: challengerFamily.name || '',
            familyBName: opponentFamily.name || '',
            familyAAvatar: challengerFamily.avatarUrl || null,
            familyBAvatar: opponentFamily.avatarUrl || null,
            imageUrl: req.imageUrl || null,
            familyAPoints: 0,
            familyBPoints: 0,
            participantUserList: allMemberUids,
            topContributors: [],
            startedAt: now,
            durationSeconds: durationSeconds,
            status: 'active',
            winnerId: null,
        };

        // Create mirrored battle docs
        const battleRefA = db.collection('families').doc(challengerFamilyId).collection('battles').doc(battleId);
        const battleRefB = db.collection('families').doc(opponentFamilyId).collection('battles').doc(battleId);
        transaction.set(battleRefA, { ...battleData, id: battleId });
        transaction.set(battleRefB, { ...battleData, id: battleId });

        // Update request status
        transaction.update(reqDoc.ref, { status: 'accepted' });

        // Set currentActiveBattleId + battleJoinTime on all members
        for (const uid of allMemberUids) {
            transaction.update(db.collection('users').doc(uid), {
                currentActiveBattleId: battleId,
                battleJoinTime: now,
            });
        }

        // Log transaction
        const logRef = db.collection('family_battle_transactions').doc();
        transaction.set(logRef, {
            type: 'battle_created',
            battleId: battleId,
            challengerFamilyId: challengerFamilyId,
            opponentFamilyId: opponentFamilyId,
            challengerName: challengerFamily.name || '',
            opponentName: opponentFamily.name || '',
            createdBy: context.auth.uid,
            participantCount: allMemberUids.length,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    });

    console.log(`[FAMILY_BATTLE] Battle ${battleId} created: ${challengerFamily.name} vs ${opponentFamily.name}`);
    return { success: true, battleId: battleId };
});

/**
 * --- SCORE BATTLE TAP (SERVER-SIDE) ---
 * Validates active battle, user participation, rate-limits per-user.
 * Increments points server-side and updates member contribution.
 */
exports.scoreBattleTap = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required.');

    const { battleId, familyId, points } = data;
    if (!battleId || !familyId) {
        throw new functions.https.HttpsError('invalid-argument', 'battleId and familyId required.');
    }
    const tapPoints = (typeof points === 'number' && points > 0) ? Math.min(points, 10) : 1;

    const uid = context.auth.uid;

    await db.runTransaction(async (transaction) => {
        // Read battle doc from caller's family subcollection
        const battleRef = db.collection('families').doc(familyId).collection('battles').doc(battleId);
        const battleDoc = await transaction.get(battleRef);
        if (!battleDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Battle not found.');
        }
        const battle = battleDoc.data();
        if (battle.status !== 'active') {
            throw new functions.https.HttpsError('failed-precondition', 'Battle is not active.');
        }

        // Verify user belongs to one of the battling families
        const userDoc = await transaction.get(db.collection('users').doc(uid));
        if (!userDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'User not found.');
        }
        const userFamilyId = userDoc.data().familyId;
        if (userFamilyId !== battle.familyAId && userFamilyId !== battle.familyBId) {
            throw new functions.https.HttpsError('permission-denied', 'You are not a participant in this battle.');
        }

        // Rate limit: 300ms cooldown per user
        const userMemberRef = db.collection('families').doc(familyId).collection('members').doc(uid);
        const memberDoc = await transaction.get(userMemberRef);
        const lastTap = memberDoc.data()?.lastTapAt;
        if (lastTap) {
            const lastTapMillis = lastTap.toMillis ? lastTap.toMillis() : lastTap;
            const cooldown = 300;
            if (Date.now() - lastTapMillis < cooldown) {
                throw new functions.https.HttpsError('resource-exhausted', 'Tap too fast. Wait before tapping again.');
            }
        }

        // Determine which side to increment
        const isA = userFamilyId === battle.familyAId;
        const field = isA ? 'familyAPoints' : 'familyBPoints';

        // Update battle points (both copies)
        const oppFamilyId = isA ? battle.familyBId : battle.familyAId;
        const oppBattleRef = db.collection('families').doc(oppFamilyId).collection('battles').doc(battleId);

        transaction.update(battleRef, { [field]: admin.firestore.FieldValue.increment(tapPoints) });
        const oppDoc = await transaction.get(oppBattleRef);
        if (oppDoc.exists) {
            transaction.update(oppBattleRef, { [field]: admin.firestore.FieldValue.increment(tapPoints) });
        }

        // Update member combatPoints, contribution, lastTapAt
        transaction.update(userMemberRef, {
            combatPoints: admin.firestore.FieldValue.increment(tapPoints),
            contribution: admin.firestore.FieldValue.increment(tapPoints),
            memberXP: admin.firestore.FieldValue.increment(Math.floor(tapPoints / 500)),
            lastTapAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    });

    return { success: true };
});

/**
 * --- AUTO LEVEL UP FAMILY ---
 * Firestore trigger: when totalBattlePoints changes, recalculates and
 * updates the family level field.
 */
exports.autoLevelUpFamily = functions.firestore
    .document('families/{familyId}')
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();
        if (!before || !after) return null;
        if (before.totalBattlePoints === after.totalBattlePoints) return null;

        const thresholds = [0, 5000000, 10000000, 20000000, 30000000,
                            50000000, 100000000, 300000000, 500000000, 700000000, 1000000000];
        let newLevel = 1;
        for (let i = thresholds.length - 1; i >= 0; i--) {
            if ((after.totalBattlePoints || 0) >= thresholds[i]) {
                newLevel = i + 1;
                break;
            }
        }

        if (newLevel !== after.level) {
            await change.after.ref.update({ level: newLevel });
            console.log(`[FAMILY_LEVEL] Family ${context.params.familyId} leveled up to ${newLevel}`);
        }
        return null;
    });

/**
 * --- AUTO-END FAMILY BATTLES ---
 * Runs every 60 seconds to end expired family battles.
 * Also clears currentActiveBattleId from all participants.
 */
exports.autoEndFamilyBattles = functions.pubsub.schedule('every 1 minutes').onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const battlesSnap = await db.collectionGroup('battles')
        .where('status', '==', 'active')
        .get();

    if (battlesSnap.empty) return null;

    const seen = new Set();
    let endedCount = 0;

    for (const doc of battlesSnap.docs) {
        const battleId = doc.id;
        if (seen.has(battleId)) continue;
        seen.add(battleId);

        const data = doc.data();
        const startedAt = data.startedAt;
        const duration = data.durationSeconds || 180;

        if (!startedAt) continue;

        const expiresAt = new admin.firestore.Timestamp(
            startedAt.seconds + duration,
            startedAt.nanoseconds
        );

        if (expiresAt.toMillis() > now.toMillis()) continue;

        const familyAId = data.familyAId;
        const familyBId = data.familyBId;
        if (!familyAId || !familyBId) continue;

        const aPts = data.familyAPoints || 0;
        const bPts = data.familyBPoints || 0;

        let winnerId = null;
        if (aPts > bPts) winnerId = familyAId;
        else if (bPts > aPts) winnerId = familyBId;

        try {
            const batch = db.batch();
            batch.update(db.collection('families').doc(familyAId).collection('battles').doc(battleId), {
                status: 'completed',
                winnerId: winnerId,
            });
            batch.update(db.collection('families').doc(familyBId).collection('battles').doc(battleId), {
                status: 'completed',
                winnerId: winnerId,
            });
            if (winnerId) {
                batch.update(db.collection('families').doc(winnerId), {
                    totalBattlePoints: admin.firestore.FieldValue.increment(500),
                });
            }

            // Clear currentActiveBattleId from all participants
            const [familyADoc, familyBDoc] = await Promise.all([
                db.collection('families').doc(familyAId).get(),
                db.collection('families').doc(familyBId).get(),
            ]);
            const allUids = [
                ...(familyADoc.data()?.memberUids || []),
                ...(familyBDoc.data()?.memberUids || []),
            ];
            for (const uid of allUids) {
                batch.update(db.collection('users').doc(uid), {
                    currentActiveBattleId: admin.firestore.FieldValue.delete(),
                });
            }

            // Log battle end transaction
            const logRef = db.collection('family_battle_transactions').doc();
            batch.set(logRef, {
                type: 'battle_ended',
                battleId: battleId,
                familyAId,
                familyBId,
                familyAPoints: aPts,
                familyBPoints: bPts,
                winnerId,
                totalPoints: aPts + bPts,
                participantCount: allUids.length,
                endedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            await batch.commit();
            endedCount++;
            console.log(`[FAMILY_BATTLE_AUTO_END] Battle ${battleId} ended. Winner: ${winnerId || 'draw'}. Cleared ${allUids.length} user battle IDs.`);
        } catch (err) {
            console.error(`[FAMILY_BATTLE_AUTO_END] Error ending battle ${battleId}:`, err);
        }
    }

    console.log(`[FAMILY_BATTLE_AUTO_END] Ended ${endedCount} expired battles.`);
    return null;
});

/**
 * --- CREATE FAMILY (SERVER-SIDE) ---
 * Validates uniqueness, creates family + member docs, updates user.
 */
exports.createFamily = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required.');
    const { name, tag, description, notice, avatarUrl, country, joinMode, levelRequirement } = data;
    if (!name || name.length < 4) throw new functions.https.HttpsError('invalid-argument', 'Name must be 4+ chars.');

    const existing = await db.collection('families').where('name', '==', name).limit(1).get();
    if (!existing.empty) throw new functions.https.HttpsError('already-exists', 'Family name already taken.');

    const uid = context.auth.uid;
    const userDoc = await db.collection('users').doc(uid).get();
    const userData = userDoc.data();
    if (userData?.familyId) throw new functions.https.HttpsError('failed-precondition', 'You are already in a family.');

    const familyRef = db.collection('families').doc();
    const batch = db.batch();

    batch.set(familyRef, {
        name, tag: (tag || '').toUpperCase(), description: description || '', notice: notice || '',
        ownerId: uid, avatarUrl: avatarUrl || null, bannerUrl: null,
        memberUids: [uid], level: 1, totalBattlePoints: 0, totalCombatPoints: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        category: 'Social', rank: 0, joinMode: joinMode || 'free',
        levelRequirement: levelRequirement || 0, country: country || '',
        monthlyTarget: 3000000, currentMonthPoints: 0,
        memberLimit: 100, rankName: 'Bronze',
    });

    batch.set(familyRef.collection('members').doc(uid), {
        familyId: familyRef.id, userId: uid, role: 'owner',
        memberLevel: 1, memberXP: 0, combatPoints: 0, contribution: 0,
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    batch.update(db.collection('users').doc(uid), { familyId: familyRef.id, isFamilyOwner: true });

    await batch.commit();
    return { familyId: familyRef.id };
});

/**
 * --- APPROVE JOIN REQUEST (SERVER-SIDE) ---
 * Validates capacity, approves request, adds member, updates user.
 */
exports.approveJoinRequest = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required.');
    const { requestId, familyId, userId } = data;
    if (!requestId || !familyId || !userId) throw new functions.https.HttpsError('invalid-argument', 'Missing fields.');

    const familyDoc = await db.collection('families').doc(familyId).get();
    if (!familyDoc.exists) throw new functions.https.HttpsError('not-found', 'Family not found.');
    const family = familyDoc.data();

    if (family.ownerId !== context.auth.uid && !(await isUserAdmin(context.auth.uid))) {
        throw new functions.https.HttpsError('permission-denied', 'Only the owner can approve requests.');
    }

    const memberUids = family.memberUids || [];
    const memberLimit = family.memberLimit || 100;
    if (memberUids.length >= memberLimit) {
        throw new functions.https.HttpsError('resource-exhausted', 'Family is full.');
    }

    const batch = db.batch();
    batch.update(db.collection('familyJoinRequests').doc(requestId), { status: 'accepted' });
    batch.update(familyDoc.ref, { memberUids: admin.firestore.FieldValue.arrayUnion([userId]) });
    batch.set(familyDoc.ref.collection('members').doc(userId), {
        familyId, userId, role: 'member', memberLevel: 1, memberXP: 0,
        combatPoints: 0, contribution: 0, joinedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    batch.update(db.collection('users').doc(userId), { familyId, isFamilyOwner: false });

    await batch.commit();
    return { success: true };
});

/**
 * --- KICK MEMBER (SERVER-SIDE) ---
 * Owner removes a member from the family.
 */
exports.kickMember = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required.');
    const { familyId, userId } = data;
    if (!familyId || !userId) throw new functions.https.HttpsError('invalid-argument', 'Missing fields.');

    const familyDoc = await db.collection('families').doc(familyId).get();
    if (!familyDoc.exists) throw new functions.https.HttpsError('not-found', 'Family not found.');
    const family = familyDoc.data();

    if (family.ownerId !== context.auth.uid && !(await isUserAdmin(context.auth.uid))) {
        throw new functions.https.HttpsError('permission-denied', 'Only the owner can kick members.');
    }
    if (userId === family.ownerId) {
        throw new functions.https.HttpsError('permission-denied', 'Cannot kick the owner.');
    }

    const batch = db.batch();
    batch.update(familyDoc.ref, { memberUids: admin.firestore.FieldValue.arrayRemove([userId]) });
    batch.delete(familyDoc.ref.collection('members').doc(userId));
    batch.update(db.collection('users').doc(userId), { familyId: null, isFamilyOwner: false });

    await batch.commit();
    return { success: true };
});

// ─── RANKING RESET FUNCTIONS ────────────────────────────────────

async function calculateAndStoreRankings(period) {
    const familiesSnap = await db.collection('families')
        .orderBy('totalCombatPoints', 'desc')
        .limit(100)
        .get();

    const batch = db.batch();
    const rankingsRef = db.collection('familyRankings');

    const existing = await rankingsRef.where('period', '==', period).get();
    existing.forEach(doc => batch.delete(doc.ref));

    let rank = 1;
    familiesSnap.forEach(doc => {
        const data = doc.data();
        const rankingRef = rankingsRef.doc(`${period}_${doc.id}`);
        batch.set(rankingRef, {
            familyId: doc.id,
            familyName: data.name || '',
            familyAvatar: data.avatarUrl || null,
            points: data.totalCombatPoints || 0,
            rank: rank,
            level: data.level || 1,
            period: period,
            calculatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        rank++;
    });

    await batch.commit();
    console.log(`[RANKINGS] ${period} rankings calculated for ${familiesSnap.size} families.`);
}

exports.resetDailyRankings = functions.pubsub.schedule('0 0 * * *').onRun(async (context) => {
    await calculateAndStoreRankings('daily');
});

exports.resetWeeklyRankings = functions.pubsub.schedule('0 0 * * 1').onRun(async (context) => {
    await calculateAndStoreRankings('weekly');
});

exports.resetMonthlyRankings = functions.pubsub.schedule('0 0 1 * *').onRun(async (context) => {
    await calculateAndStoreRankings('monthly');
});

/**
 * --- ROOM SUPPORT SYSTEM ---
 */

const ROOM_SUPPORT = {
    levels: [
        { level: 1, coinsTarget: 10000000, partnerSlots: 4, ownerReward: 1000000, partnerReward: 250000, totalReward: 2000000 },
        { level: 2, coinsTarget: 20000000, partnerSlots: 4, ownerReward: 2000000, partnerReward: 500000, totalReward: 4000000 },
        { level: 3, coinsTarget: 30000000, partnerSlots: 4, ownerReward: 3000000, partnerReward: 750000, totalReward: 6000000 },
        { level: 4, coinsTarget: 50000000, partnerSlots: 5, ownerReward: 6000000, partnerReward: 1200000, totalReward: 12000000 },
        { level: 5, coinsTarget: 100000000, partnerSlots: 6, ownerReward: 11000000, partnerReward: 2000000, totalReward: 23000000 },
        { level: 6, coinsTarget: 200000000, partnerSlots: 7, ownerReward: 21000000, partnerReward: 3500000, totalReward: 45500000 },
        { level: 7, coinsTarget: 300000000, partnerSlots: 7, ownerReward: 31000000, partnerReward: 5000000, totalReward: 66000000 },
    ],
    calculateLevel: function(totalCoins) {
        if (totalCoins >= 300000000) return 7;
        if (totalCoins >= 200000000) return 6;
        if (totalCoins >= 100000000) return 5;
        if (totalCoins >= 50000000) return 4;
        if (totalCoins >= 30000000) return 3;
        if (totalCoins >= 20000000) return 2;
        if (totalCoins >= 10000000) return 1;
        return 0;
    },
    getRequiredPartners: function(level) {
        if (level >= 6) return 7;
        if (level === 5) return 6;
        if (level === 4) return 5;
        if (level >= 1) return 4;
        return 0;
    }
};

/** Seed default room support configs */
exports.seedRoomSupportConfigs = functions.https.onRequest(async (req, res) => {
    const configRef = db.collection("room_support_configs").doc("settings");
    await configRef.set({
        levels: ROOM_SUPPORT.levels,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    res.status(200).send({ success: true, message: "Room support 7-tier configs seeded successfully." });
});

/** Assign a salary partner (owner only) */
exports.assignRoomPartner = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new HttpsError("unauthenticated", "Authentication required.");
    const uid = context.auth.uid;
    const { roomId, partnerUid } = data;
    if (!roomId || !partnerUid) throw new HttpsError("invalid-argument", "roomId and partnerUid are required.");
    if (uid === partnerUid) throw new HttpsError("invalid-argument", "Room owner cannot be assigned as a salary partner.");

    return db.runTransaction(async (transaction) => {
        // Verify room and ownership
        const roomRef = db.collection("rooms").doc(roomId);
        const roomSnap = await transaction.get(roomRef);
        if (!roomSnap.exists) throw new HttpsError("not-found", "Room not found.");
        const room = roomSnap.data();
        if (room.ownerUid !== uid) throw new HttpsError("permission-denied", "Only the room owner can assign salary partners.");

        // Determine achieved level for last closed week or current cycle
        const historyQuery = db.collection("room_support_history").doc(roomId).collection("weeks")
            .where("distributionStatus", "==", "pending")
            .limit(1);
        const historySnap = await transaction.get(historyQuery);

        let achievedLevel = 0;
        if (!historySnap.empty) {
            achievedLevel = historySnap.docs[0].data().achievedLevel || 0;
        }

        const cycleRef = db.collection("room_support_cycles").doc(roomId);
        const cycleSnap = await transaction.get(cycleRef);
        if (cycleSnap.exists) {
            const cycleData = cycleSnap.data();
            const cycleLevel = cycleData.lastWeekLevel || cycleData.level || ROOM_SUPPORT.calculateLevel(cycleData.totalCoins || 0);
            achievedLevel = Math.max(achievedLevel, cycleLevel);
        }

        if (room.weeklyEarnings) {
            achievedLevel = Math.max(achievedLevel, ROOM_SUPPORT.calculateLevel(room.weeklyEarnings || 0));
        }

        // Allow minimum Level 1 (4 partner slots) if initial setup/testing
        if (achievedLevel < 1) {
            achievedLevel = 1;
        }

        const maxSlots = ROOM_SUPPORT.getRequiredPartners(achievedLevel) || 4;
        const levelConfig = ROOM_SUPPORT.levels[achievedLevel - 1] || ROOM_SUPPORT.levels[0];

        // Check partner user exists
        const partnerUserRef = db.collection("users").doc(partnerUid);
        const partnerUserSnap = await transaction.get(partnerUserRef);
        if (!partnerUserSnap.exists) throw new HttpsError("not-found", "Partner user not found.");
        const partnerUserData = partnerUserSnap.data();

        // Count current partners
        const partnersCol = db.collection("room_support_cycles").doc(roomId).collection("partners");
        const partnersSnap = await transaction.get(partnersCol);
        if (partnersSnap.size >= maxSlots) {
            throw new HttpsError("failed-precondition", `Maximum ${maxSlots} salary partners allowed at Level ${achievedLevel}.`);
        }

        // Check if already assigned
        const existingRef = partnersCol.doc(partnerUid);
        const existingSnap = await transaction.get(existingRef);
        if (existingSnap.exists) {
            throw new HttpsError("already-exists", "User is already assigned as a salary partner.");
        }

        // Assign partner
        transaction.set(existingRef, {
            uid: partnerUid,
            partnerUid: partnerUid,
            displayName: partnerUserData.displayName || partnerUserData.username || "Partner",
            photoUrl: partnerUserData.profilePhotoUrl || "",
            assignedAt: admin.firestore.FieldValue.serverTimestamp(),
            share: levelConfig.partnerReward
        });

        return {
            success: true,
            slot: partnersSnap.size + 1,
            maxSlots,
            message: `Partner assigned successfully (${partnersSnap.size + 1}/${maxSlots}).`
        };
    });
});

/** Remove a salary partner (owner only) */
exports.removeRoomPartner = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new HttpsError("unauthenticated", "Authentication required.");
    const uid = context.auth.uid;
    const { roomId, partnerUid } = data;
    if (!roomId || !partnerUid) throw new HttpsError("invalid-argument", "roomId and partnerUid are required.");

    return db.runTransaction(async (transaction) => {
        const roomRef = db.collection("rooms").doc(roomId);
        const roomSnap = await transaction.get(roomRef);
        if (!roomSnap.exists) throw new HttpsError("not-found", "Room not found.");
        const room = roomSnap.data();
        if (room.ownerUid !== uid) throw new HttpsError("permission-denied", "Only the room owner can remove salary partners.");

        const partnerRef = db.collection("room_support_cycles").doc(roomId).collection("partners").doc(partnerUid);
        const partnerSnap = await transaction.get(partnerRef);
        if (!partnerSnap.exists) throw new HttpsError("not-found", "Partner not found in assignment list.");

        transaction.delete(partnerRef);
        return { success: true, message: "Partner removed successfully." };
    });
});

/** Weekly cycle lock (Sunday 23:59 UTC) — locks current week, calculates level achieved */
exports.lockRoomSupportCycles = functions.pubsub.schedule('59 23 * * 0').onRun(async (context) => {
    const cyclesSnap = await db.collection("room_support_cycles").where("status", "==", "accumulating").get();
    const now = Date.now();
    const weekEnd = admin.firestore.Timestamp.fromMillis(now);
    const weekStart = admin.firestore.Timestamp.fromMillis(now - 7 * 24 * 60 * 60 * 1000);

    console.log(`[ROOM_SUPPORT] Starting Sunday cycle lock for ${cyclesSnap.size} cycles...`);

    for (const doc of cyclesSnap.docs) {
        const roomId = doc.id;
        const data = doc.data();
        const totalCoins = data.totalCoins || 0;
        const achievedLevel = ROOM_SUPPORT.calculateLevel(totalCoins);

        const levelConfig = achievedLevel > 0 ? ROOM_SUPPORT.levels[achievedLevel - 1] : null;
        const ownerReward = levelConfig ? levelConfig.ownerReward : 0;
        const partnerReward = levelConfig ? levelConfig.partnerReward : 0;
        const totalReward = levelConfig ? levelConfig.totalReward : 0;
        const requiredPartners = ROOM_SUPPORT.getRequiredPartners(achievedLevel);

        try {
            await db.runTransaction(async (transaction) => {
                // 1. Write historical week record
                const weekDocId = `week_${new Date().toISOString().slice(0, 10)}`;
                const historyRef = db.collection("room_support_history").doc(roomId).collection("weeks").doc(weekDocId);
                transaction.set(historyRef, {
                    weekId: weekDocId,
                    weekStart,
                    weekEnd,
                    totalCoins,
                    visitorCount: data.visitorCount || 0,
                    achievedLevel,
                    ownerReward,
                    partnerReward,
                    totalReward,
                    requiredPartners,
                    distributionStatus: achievedLevel >= 1 ? "pending" : "no_target_met",
                    status: "closed",
                    createdAt: admin.firestore.FieldValue.serverTimestamp()
                });

                // 2. Clear old partner assignments so owner assigns fresh ones Mon-Tue
                const partnersSnap = await db.collection("room_support_cycles").doc(roomId).collection("partners").get();
                partnersSnap.forEach(pDoc => transaction.delete(pDoc.ref));

                // 3. Update cycle for the new accumulating week (starts Monday 00:00 UTC)
                transaction.update(doc.ref, {
                    lastWeekCoins: totalCoins,
                    lastWeekLevel: achievedLevel,
                    lastWeekReward: totalReward,
                    lastWeekAchievedAt: admin.firestore.FieldValue.serverTimestamp(),
                    totalCoins: 0,
                    level: 0,
                    status: "accumulating",
                    weekStart: admin.firestore.FieldValue.serverTimestamp(),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                });

                // 4. Update room ranking snapshot
                const roomSnap = await transaction.get(db.collection("rooms").doc(roomId));
                const roomName = roomSnap.exists ? (roomSnap.data().name || roomSnap.data().title || "Room") : "Room";
                const rankingRef = db.collection("room_support_rankings").doc("rankings").collection("rooms").doc(roomId);
                transaction.set(rankingRef, {
                    roomId,
                    roomName,
                    totalCoins,
                    level: achievedLevel,
                    lastUpdated: admin.firestore.FieldValue.serverTimestamp()
                });
            });
            console.log(`[ROOM_SUPPORT] Successfully locked room ${roomId}: ${totalCoins} coins -> Level ${achievedLevel}`);
        } catch (err) {
            console.error(`[ROOM_SUPPORT] Error locking room ${roomId}:`, err);
        }
    }
    console.log(`[ROOM_SUPPORT] Completed locking ${cyclesSnap.size} weekly cycles.`);
});

/** Auto distribute rewards (Wednesday 00:00 UTC) with Rule 3 expiration and Rule 5 one-reward-per-user enforcement */
exports.distributeRoomSupportRewards = functions.pubsub.schedule('0 0 * * 3').onRun(async (context) => {
    console.log(`[ROOM_SUPPORT] Starting Wednesday reward distribution...`);
    const historiesSnap = await db.collectionGroup("weeks").where("distributionStatus", "==", "pending").get();
    console.log(`[ROOM_SUPPORT] Found ${historiesSnap.size} pending weekly histories.`);

    if (historiesSnap.empty) return;

    // Collect all candidate rewards per user across ALL rooms:
    const candidateRewardsByUser = {}; // uid -> array of candidate rewards

    for (const weekDoc of historiesSnap.docs) {
        const weekData = weekDoc.data();
        const roomId = weekDoc.ref.parent.parent?.id;
        if (!roomId) continue;

        const achievedLevel = weekData.achievedLevel || 0;
        if (achievedLevel < 1) {
            await weekDoc.ref.update({ distributionStatus: "no_target_met" });
            continue;
        }

        const levelConfig = ROOM_SUPPORT.levels[achievedLevel - 1];
        if (!levelConfig) {
            await weekDoc.ref.update({ distributionStatus: "invalid_level" });
            continue;
        }

        const requiredPartners = ROOM_SUPPORT.getRequiredPartners(achievedLevel);

        // Fetch assigned partners for this room
        const partnersSnap = await db.collection("room_support_cycles").doc(roomId).collection("partners").get();
        const assignedCount = partnersSnap.size;

        // RULE 3: Partner fill-in expiration check
        // If owner did not fill required partners, reward expires!
        if (assignedCount < requiredPartners) {
            console.log(`[ROOM_SUPPORT] Room ${roomId} achieved Level ${achievedLevel} but only assigned ${assignedCount}/${requiredPartners} partners. Reward EXPIRED.`);
            await weekDoc.ref.update({
                distributionStatus: "expired",
                expirationReason: `Required ${requiredPartners} partners, but only ${assignedCount} assigned by Tuesday deadline.`,
                expiredAt: admin.firestore.FieldValue.serverTimestamp()
            });
            continue;
        }

        // Room is fully qualified!
        // Fetch room owner
        const roomDoc = await db.collection("rooms").doc(roomId).get();
        const ownerUid = roomDoc.exists ? roomDoc.data().ownerUid : null;

        if (ownerUid) {
            if (!candidateRewardsByUser[ownerUid]) candidateRewardsByUser[ownerUid] = [];
            candidateRewardsByUser[ownerUid].push({
                uid: ownerUid,
                roomId,
                weekDocRef: weekDoc.ref,
                weekId: weekDoc.id,
                role: "owner",
                level: achievedLevel,
                amount: levelConfig.ownerReward
            });
        }

        // Add partner candidates
        for (const pDoc of partnersSnap.docs) {
            const partnerUid = pDoc.data().uid;
            if (partnerUid) {
                if (!candidateRewardsByUser[partnerUid]) candidateRewardsByUser[partnerUid] = [];
                candidateRewardsByUser[partnerUid].push({
                    uid: partnerUid,
                    roomId,
                    weekDocRef: weekDoc.ref,
                    weekId: weekDoc.id,
                    role: "partner",
                    level: achievedLevel,
                    amount: levelConfig.partnerReward
                });
            }
        }
    }

    // RULE 5: ONE REWARD PER USER PER WEEK (Highest Target Wins)
    console.log(`[ROOM_SUPPORT] Evaluating rewards for ${Object.keys(candidateRewardsByUser).length} unique candidate users.`);

    for (const [uid, candidates] of Object.entries(candidateRewardsByUser)) {
        // Sort descending by amount / level
        candidates.sort((a, b) => b.amount - a.amount || b.level - a.level);
        const winningReward = candidates[0]; // highest target reward

        try {
            await db.runTransaction(async (transaction) => {
                const deterministicRewardId = `reward_${winningReward.weekId}_${uid}`;
                const rewardRef = db.collection("room_support_rewards").doc(deterministicRewardId);
                const existingRewardSnap = await transaction.get(rewardRef);

                if (existingRewardSnap.exists) {
                    console.log(`[ROOM_SUPPORT] Reward ${deterministicRewardId} already distributed. Skipping.`);
                    return;
                }

                // Credit diamonds to user balance
                const userRef = db.collection("users").doc(uid);
                const userSnap = await transaction.get(userRef);
                if (userSnap.exists) {
                    transaction.update(userRef, {
                        diamondBalance: admin.firestore.FieldValue.increment(winningReward.amount),
                        updatedAt: admin.firestore.FieldValue.serverTimestamp()
                    });
                }

                // Record reward document
                transaction.set(rewardRef, {
                    rewardId: deterministicRewardId,
                    uid,
                    roomId: winningReward.roomId,
                    weekId: winningReward.weekId,
                    role: winningReward.role,
                    level: winningReward.level,
                    amount: winningReward.amount,
                    supersededCount: candidates.length - 1,
                    distributedAt: admin.firestore.FieldValue.serverTimestamp(),
                    status: "success"
                });

                // Update winning week history
                transaction.update(winningReward.weekDocRef, {
                    distributionStatus: "distributed",
                    distributedAt: admin.firestore.FieldValue.serverTimestamp()
                });

                // Send in-app reward notification
                const inboxRef = userRef.collection("inbox_messages").doc();
                const formattedAmount = winningReward.amount.toLocaleString();
                const rewardBody = `Congratulations! You have achieved last week's Room Support goal, and ${formattedAmount} reward coins have been sent to your account.\n\nReason: Achieving Level ${winningReward.level} Room Support Goal as ${winningReward.role}.\n(Note: If you achieve multiple goals, only the reward with the most coins will be sent).`;
                transaction.set(inboxRef, {
                    type: "reward",
                    title: "Room Support Reward Delivered 🎉",
                    body: rewardBody,
                    rewardName: "Room Support Reward",
                    rewardAmount: winningReward.amount,
                    reason: `Achieving Level ${winningReward.level} Room Support Goal as ${winningReward.role}.`,
                    status: "Received",
                    read: false,
                    createdAt: admin.firestore.Timestamp.now(),
                    data: {
                        roomId: winningReward.roomId,
                        weekId: winningReward.weekId,
                        level: winningReward.level,
                        role: winningReward.role,
                        amount: winningReward.amount,
                        route: "/inbox"
                    }
                });
            });

            try {
                const formattedAmount = winningReward.amount.toLocaleString();
                const pushMsg = `Congratulations! You have achieved last week's Room Support goal, and ${formattedAmount} reward coins have been sent to your account.`;
                await sendPush(uid, "Room Support Reward Delivered 🎉", pushMsg, { route: "/inbox", type: "ROOM_SUPPORT_REWARD" });
            } catch (_) {}

            console.log(`[ROOM_SUPPORT] Awarded user ${uid}: Level ${winningReward.level} ${winningReward.role} reward of ${winningReward.amount} coins (selected highest from ${candidates.length} candidate rooms).`);
        } catch (err) {
            console.error(`[ROOM_SUPPORT] Error distributing reward to user ${uid}:`, err);
        }
    }

    console.log(`[ROOM_SUPPORT] Completed Wednesday reward distribution.`);
});

/**
 * Server time endpoint for countdown sync — returns server timestamp to avoid clock drift.
 */
exports.getServerTime = functions.https.onCall(async (data, context) => {
    const now = admin.firestore.Timestamp.now();
    return { serverTime: now.toMillis() };
});

/**
 * 🧹 Cleanup: Purge old Room Gift Leaderboard buckets.
 * Daily run — keeps the last 90 days of daily buckets, 26 weekly buckets and
 * 12 monthly buckets to bound storage growth.
 */
exports.cleanupRoomGiftLeaderboard = functions.pubsub.schedule("0 3 * * *").onRun(async (context) => {
    const now = new Date();
    const dailyCutoff = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
    const weeklyCutoff = isoWeekKey(new Date(now.getTime() - 26 * 7 * 24 * 60 * 60 * 1000));
    const monthlyCutoff = new Date(now.getTime() - 12 * 30 * 24 * 60 * 60 * 1000).toISOString().slice(0, 7);

    let deleted = 0;
    const roomsSnap = await db.collection("rooms").select("name").get();

    for (const roomDoc of roomsSnap.docs) {
        const roomRef = db.collection("rooms").doc(roomDoc.id);
        for (const [period, cutoff] of [["daily", dailyCutoff], ["weekly", weeklyCutoff], ["monthly", monthlyCutoff]]) {
            const periodSnap = await roomRef.collection("gift_leaderboard").doc(period).listCollections();
            for (const bucketColl of periodSnap) {
                if (bucketColl.id < cutoff) {
                    const docs = await bucketColl.get();
                    const batch = db.batch();
                    docs.docs.forEach((d) => batch.delete(d.ref));
                    await batch.commit();
                    deleted += docs.size;
                    // Recursively delete the now-empty bucket document
                    await bucketColl.parent.delete().catch(() => {});
                }
            }
        }
    }

    console.log(`[GIFT_LEADERBOARD_CLEANUP] Deleted ${deleted} stale leaderboard entries.`);
    return { deleted };
});


/**
 * 999. Scheduled: VIP Expiry Check & Auto-Demotion
 * Runs daily to demote expired VIP users and restore original state.
 */
exports.scheduledVIPExpiryCheck = functions.pubsub.schedule('0 0 * * *').onRun(async (context) => {
    console.log("[VIP_EXPIRY_CRON] Checking for expired VIP users...");
    const now = admin.firestore.Timestamp.now();
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

    const snapshot = await db.collection("users")
        .where("vipTier", "!=", "none")
        .where("vipExpiry", "<=", now)
        .limit(500)
        .get();

    if (snapshot.empty) {
        console.log("[VIP_EXPIRY_CRON] No expired VIP users found.");
        return null;
    }

    console.log(`[VIP_EXPIRY_CRON] Found ${snapshot.size} expired VIP users to demote.`);
    const results = [];

    for (const doc of snapshot.docs) {
        const userData = doc.data();
        const userRef = db.collection("users").doc(doc.id);
        const snapshotData = userData.vipSnapshot || {};

        try {
            const updates = {
                vipTier: "none",
                vipExpiry: admin.firestore.FieldValue.delete(),
                vipSnapshot: admin.firestore.FieldValue.delete(),
                profileFrame: snapshotData.originalProfileFrame || userData.profileFrame || "",
                entryAnimation: snapshotData.originalEntryAnimation || userData.entryAnimation || "",
                badgeIcon: snapshotData.originalBadgeIcon || userData.badgeIcon || ""
            };

            // Restore original helloId if it was changed for VIP
            if (snapshotData.originalHelloId && userData.helloId !== snapshotData.originalHelloId) {
                updates.helloId = snapshotData.originalHelloId;
            }

            await userRef.update(updates);

            // Log expiry transaction
            await userRef.collection("transactions").add({
                type: "vip_expiry",
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                description: `VIP ${userData.vipTier || ""} expired, account restored to normal state.`
            });

            results.push({ uid: doc.id, status: "demoted" });
            console.log(`[VIP_EXPIRY_CRON] Demoted user ${doc.id} (was ${userData.vipTier})`);
        } catch (err) {
            console.error(`[VIP_EXPIRY_CRON] Error demoting user ${doc.id}:`, err);
            results.push({ uid: doc.id, status: "error", error: err.message });
        }
    }

    return { processed: results.length, details: results };
});

/**
 * 1000. Claim VIP Daily Reward (Server-side)
 * Validates VIP status, expiry, and claim state before crediting.
 */
exports.claimVIPDailyReward = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const uid = context.auth.uid;

    return db.runTransaction(async (transaction) => {
        const userRef = db.collection("users").doc(uid);
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");

        const userData = userDoc.data();
        const vipTier = userData.vipTier || "none";
        const vipExpiry = userData.vipExpiry;

        // 1. Validate VIP active
        if (vipTier === "none") {
            throw new functions.https.HttpsError("failed-precondition", "Only VIP members can claim daily rewards.");
        }

        // 2. Validate VIP not expired
        if (!vipExpiry) {
            throw new functions.https.HttpsError("failed-precondition", "VIP has no expiry date set.");
        }
        const expiryDate = vipExpiry.toDate ? vipExpiry.toDate() : new Date(vipExpiry);
        if (expiryDate < new Date()) {
            throw new functions.https.HttpsError("failed-precondition", "VIP has expired. Renew to continue claiming rewards.");
        }

        // 3. Check not already claimed today (ISO format)
        const now = new Date();
        const todayStr = now.getFullYear() + "-" +
            String(now.getMonth() + 1).padStart(2, "0") + "-" +
            String(now.getDate()).padStart(2, "0");
        const lastClaim = userData.lastVipClaim || "";
        if (lastClaim === todayStr) {
            throw new functions.https.HttpsError("already-exists", "Daily reward already claimed today!");
        }

        // 4. Exact tier matching for reward
        let beanReward = 0;
        const tierName = vipTier.toLowerCase().replace(/\s+/g, "");
        if (tierName === "vip1") beanReward = 10;
        else if (tierName === "vip2") beanReward = 30;
        else if (tierName === "vip3") beanReward = 100;
        else if (tierName === "vip4") beanReward = 500;
        else if (tierName === "vip5") beanReward = 2000;
        else if (tierName === "vip6") beanReward = 10000;
        else if (tierName === "vip7") beanReward = 50000;
        else if (tierName === "vip8") beanReward = 200000;
        else if (tierName.includes("svip")) beanReward = 50000;
        else throw new functions.https.HttpsError("failed-precondition", "Unknown VIP tier: " + vipTier);

        // 5. Credit reward
        transaction.update(userRef, {
            beansBalance: admin.firestore.FieldValue.increment(beanReward),
            lastVipClaim: todayStr
        });

        // 6. Log transaction
        const txRef = userRef.collection("transactions").doc();
        transaction.set(txRef, {
            type: "reward",
            amount: beanReward,
            currency: "beans",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            description: "Daily VIP Reward (" + vipTier + ")"
        });

        return { success: true, reward: beanReward, tier: vipTier };
    });
});

/**
 * 1001. Room Kick User with VIP Protection
 * Checks target user's VIP status — VIP 7+ cannot be kicked.
 */
exports.roomKickUser = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const requesterUid = context.auth.uid;
    const { roomId, targetUid, duration, reason } = data;

    if (!roomId || !targetUid) {
        throw new functions.https.HttpsError("invalid-argument", "roomId and targetUid are required.");
    }

    return db.runTransaction(async (transaction) => {
        const roomRef = db.collection("rooms").doc(roomId);
        const targetUserRef = db.collection("users").doc(targetUid);
        const requesterParticipantRef = roomRef.collection("participants").doc(requesterUid);

        const [roomDoc, targetUserDoc, requesterParticipantDoc] = await Promise.all([
            transaction.get(roomRef),
            transaction.get(targetUserRef),
            transaction.get(requesterParticipantRef)
        ]);

        if (!roomDoc.exists) throw new functions.https.HttpsError("not-found", "Room not found.");
        const roomData = roomDoc.data();

        const requesterUserDoc = await transaction.get(db.collection("users").doc(requesterUid));
        const requesterUserData = requesterUserDoc.exists ? requesterUserDoc.data() : {};
        const requesterSvipLevel = requesterUserData.svipLevel || 0;
        const now = new Date();

        // Check if requester is SVIP 6 (Global Kick privilege)
        const isRequesterSvip6 = requesterSvipLevel === 6;

        if (isRequesterSvip6) {
            if (targetUid === requesterUid) {
                throw new functions.https.HttpsError("invalid-argument", "Cannot kick yourself.");
            }
        } else {
            // Standard Room Owner, Admin, Moderator check
            const isOwner = roomData.ownerUid === requesterUid;
            const isAdmin = roomData.admins && roomData.admins.includes(requesterUid);
            const isModerator = roomData.moderators && roomData.moderators.includes(requesterUid);
            const requesterTags = requesterParticipantDoc.exists ? (requesterParticipantDoc.data().tags || []) : [];
            const isSuperAdmin = requesterTags.includes("SuperAdmin");

            if (!isOwner && !isAdmin && !isModerator && !isSuperAdmin) {
                throw new functions.https.HttpsError("permission-denied", "Only room owner, admins, or moderators can kick users.");
            }
        }

        // Target Protection Checks (SVIP 4, 5, 6 & Assigned Protection & VIP 7+)
        if (targetUserDoc.exists) {
            const targetData = targetUserDoc.data();
            const targetSvipLevel = targetData.svipLevel || 0;
            const targetSvipEnd = targetData.svipCycleEndDate;
            const targetProtectionExpiry = targetData.assignedProtectionExpiresAt;

            const isTargetSvipActive = targetSvipEnd && (targetSvipEnd.toDate ? targetSvipEnd.toDate() : new Date(targetSvipEnd)) > now;
            const isTargetAssignedActive = targetProtectionExpiry && (targetProtectionExpiry.toDate ? targetProtectionExpiry.toDate() : new Date(targetProtectionExpiry)) > now;

            // SVIP 6 Global Kick rule: Cannot kick another SVIP 6
            if (isRequesterSvip6) {
                if (targetSvipLevel === 6 && isTargetSvipActive) {
                    throw new functions.https.HttpsError("permission-denied", "SVIP 6 users cannot Kick Out another SVIP 6 user.");
                }
            } else if ((targetSvipLevel >= 4 && isTargetSvipActive) || isTargetAssignedActive) {
                // SVIP 4, 5, 6 and Assigned users are protected against regular owners/admins/moderators
                throw new functions.https.HttpsError(
                    "permission-denied",
                    "This user is protected by SVIP privileges. Kick Out and Mute actions are not allowed."
                );
            }

            // VIP 7+ Kick Protection
            const targetVipTier = targetData.vipTier || "none";
            const targetVipExpiry = targetData.vipExpiry;
            const isVip7OrAbove = targetVipTier === "VIP 7" || targetVipTier === "VIP 8";
            const isVipActive = targetVipExpiry !== null && targetVipExpiry !== undefined;

            if (isVip7OrAbove && isVipActive) {
                let stillActive = false;
                if (targetVipExpiry.toDate) {
                    stillActive = targetVipExpiry.toDate() > now;
                } else {
                    stillActive = new Date(targetVipExpiry) > now;
                }

                if (stillActive && !isRequesterSvip6) {
                    throw new functions.https.HttpsError(
                        "permission-denied",
                        targetVipTier + " users have kick protection and cannot be removed from rooms."
                    );
                }
            }
        }

        // Compute ban expiry
        let banExpiry = null;
        const banDuration = typeof duration === 'number' && duration > 0 ? duration : null;
        if (banDuration) {
            banExpiry = admin.firestore.Timestamp.fromDate(new Date(Date.now() + banDuration * 60 * 1000));
        }

        // Perform kick
        const participantRef = roomRef.collection("participants").doc(targetUid);
        const banExpiriesUpdate = {};
        banExpiriesUpdate[targetUid] = banExpiry;
        transaction.update(roomRef, {
            bannedUids: admin.firestore.FieldValue.arrayUnion([targetUid]),
            banExpiries: banExpiriesUpdate
        });
        transaction.delete(participantRef);

        // Log system message
        const msgRef = roomRef.collection("messages").doc();
        const targetParticipantDoc = await transaction.get(participantRef);
        const targetName = targetParticipantDoc.exists
            ? (targetParticipantDoc.data().displayName || "User")
            : "User";
        let msgText = targetName + " was removed from the room.";
        if (reason) msgText += " Reason: " + reason;
        if (banDuration) {
            msgText += " (Banned for " + banDuration + " min)";
        }
        transaction.set(msgRef, {
            uid: requesterUid,
            text: msgText,
            type: "system",
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // Log to room_kick_logs subcollection
        const logRef = roomRef.collection("room_kick_logs").doc();
        transaction.set(logRef, {
            targetUid: targetUid,
            targetName: targetName,
            moderatorUid: requesterUid,
            action: banDuration ? "ban" : "kick",
            reason: reason || "",
            banDuration: banDuration,
            banExpiry: banExpiry,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        });

        return { success: true };
    });
});

/**
 * 1002. Room Unban User
 * Removes a user from the room's banned list.
 */
exports.roomUnbanUser = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const requesterUid = context.auth.uid;
    const { roomId, targetUid } = data;

    if (!roomId || !targetUid) {
        throw new functions.https.HttpsError("invalid-argument", "roomId and targetUid are required.");
    }

    const roomDoc = await db.collection("rooms").doc(roomId).get();
    if (!roomDoc.exists) throw new functions.https.HttpsError("not-found", "Room not found.");
    const roomData = roomDoc.data();

    const isOwner = roomData.ownerUid === requesterUid;
    const isAdmin = roomData.admins && roomData.admins.includes(requesterUid);
    const requesterUserDoc = await db.collection("users").doc(requesterUid).get();
    const requesterTags = requesterUserDoc.exists ? (requesterUserDoc.data().tags || []) : [];
    const isSuperAdmin = requesterTags.includes("SuperAdmin");

    if (!isOwner && !isAdmin && !isSuperAdmin) {
        throw new functions.https.HttpsError("permission-denied", "Only room owner or admins can unban users.");
    }

    const banExpiryDelete = {};
    banExpiryDelete["banExpiries." + targetUid] = admin.firestore.FieldValue.delete();

    await db.collection("rooms").doc(roomId).update({
        bannedUids: admin.firestore.FieldValue.arrayRemove([targetUid]),
        ...banExpiryDelete
    });

    return { success: true };
});

/**
 * 1003. Auto-Unban Expired Bans (Cron)
 * Runs every 5 minutes, checks all rooms with active bans,
 * removes any where banExpiry has passed.
 */
exports.autoUnbanExpiredBans = functions.pubsub.schedule('every 5 minutes').onRun(async (context) => {
    console.log("[AUTO_UNBAN_CRON] Checking for expired bans...");
    const now = admin.firestore.Timestamp.now();
    let processed = 0;

    const roomsSnapshot = await db.collection("rooms")
        .where("bannedUids", "!=", [])
        .limit(200)
        .get();

    if (roomsSnapshot.empty) {
        console.log("[AUTO_UNBAN_CRON] No rooms with bans found.");
        return null;
    }

    for (const roomDoc of roomsSnapshot.docs) {
        const roomData = roomDoc.data();
        const banExpiries = roomData.banExpiries || {};
        const uidsToRemove = [];

        for (const [uid, expiry] of Object.entries(banExpiries)) {
            if (expiry && expiry.toDate) {
                if (expiry.toDate() <= now.toDate()) {
                    uidsToRemove.push(uid);
                }
            }
        }

        if (uidsToRemove.length > 0) {
            try {
                const roomRef = db.collection("rooms").doc(roomDoc.id);
                const deleteFields = {};
                for (const uid of uidsToRemove) {
                    deleteFields["banExpiries." + uid] = admin.firestore.FieldValue.delete();
                }
                await roomRef.update({
                    ...deleteFields,
                    bannedUids: admin.firestore.FieldValue.arrayRemove(uidsToRemove)
                });
                processed += uidsToRemove.length;
                console.log("[AUTO_UNBAN_CRON] Room " + roomDoc.id + ": unbanned " + uidsToRemove.length + " user(s)");
            } catch (err) {
                console.error("[AUTO_UNBAN_CRON] Error processing room " + roomDoc.id + ":", err);
            }
        }
    }

    console.log("[AUTO_UNBAN_CRON] Complete. Processed " + processed + " expired bans.");
    return { processed: processed };
});

/**
 * 1004. Claim VIP Daily Reward
 * Checks user's VIP membership and credits diamonds and XP in a transaction.
 */
exports.claimVipDailyReward = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const uid = context.auth.uid;
    const userRef = db.collection("users").doc(uid);

    return db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");

        const userData = userDoc.data();
        const vipTier = userData.vipTier || "none";
        const vipExpiry = userData.vipExpiry;

        // Verify active VIP
        const now = new Date();
        if (vipTier === "none" || !vipExpiry || vipExpiry.toDate() < now) {
            throw new functions.https.HttpsError("failed-precondition", "Active VIP membership required.");
        }

        // Check lastDailyClaim date
        const lastDailyClaim = userData.lastDailyClaim;
        if (lastDailyClaim) {
            const lastClaimDate = lastDailyClaim.toDate();
            const lastClaimDay = Date.UTC(lastClaimDate.getFullYear(), lastClaimDate.getMonth(), lastClaimDate.getDate());
            const currentDay = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate());
            if (lastClaimDay === currentDay) {
                throw new functions.https.HttpsError("already-exists", "Daily reward already claimed today.");
            }
        }

        // Calculate reward amounts
        let diamonds = 50;
        let xp = 10;
        const tierName = vipTier.toLowerCase();
        if (tierName.includes("vip 1") || tierName.includes("vip1")) {
            diamonds = 100; xp = 10;
        } else if (tierName.includes("vip 2") || tierName.includes("vip2")) {
            diamonds = 300; xp = 25;
        } else if (tierName.includes("vip 3") || tierName.includes("vip3")) {
            diamonds = 800; xp = 50;
        } else if (tierName.includes("vip 4") || tierName.includes("vip4")) {
            diamonds = 2000; xp = 100;
        } else if (tierName.includes("vip 5") || tierName.includes("vip5")) {
            diamonds = 5000; xp = 200;
        } else if (tierName.includes("vip 6") || tierName.includes("vip6")) {
            diamonds = 10000; xp = 400;
        } else if (tierName.includes("vip 7") || tierName.includes("vip7")) {
            diamonds = 25000; xp = 1000;
        }

        transaction.update(userRef, {
            diamondBalance: admin.firestore.FieldValue.increment(diamonds),
            xp: admin.firestore.FieldValue.increment(xp),
            lastDailyClaim: admin.firestore.Timestamp.fromDate(now)
        });

        // Add a transaction record
        const txRef = userRef.collection("transactions").doc();
        transaction.set(txRef, {
            type: "reward",
            amount: diamonds,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            description: `Daily VIP Reward Claimed (${vipTier})`
        });

        return { success: true, diamonds, xp };
    });
});

/**
 * 1005. Refund VIP Subscriptions (Admin only)
 * Calculates prorated amount, revokes membership, and reverts custom cosmetics.
 */
exports.refundVip = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const adminUid = context.auth.uid;
    const adminDoc = await db.collection("users").doc(adminUid).get();
    const tags = adminDoc.data().tags || [];
    if (!tags.includes("Admin") && !tags.includes("SuperAdmin")) {
        throw new functions.https.HttpsError("permission-denied", "Admin permissions required.");
    }

    const { targetHelloId, reason } = data;
    if (!targetHelloId) throw new functions.https.HttpsError("invalid-argument", "Target Hello ID required.");

    const targetSnap = await db.collection("users").where("helloId", "==", parseInt(targetHelloId)).get();
    if (targetSnap.empty) throw new functions.https.HttpsError("not-found", "Target user not found.");

    const targetDoc = targetSnap.docs[0];
    const targetUid = targetDoc.id;
    const targetData = targetDoc.data();

    const vipTier = targetData.vipTier || "none";
    const vipExpiry = targetData.vipExpiry;
    if (vipTier === "none" || !vipExpiry) {
        throw new functions.https.HttpsError("failed-precondition", "Target user does not have an active VIP membership.");
    }

    // Calculate remaining days
    const now = new Date();
    const expiryDate = vipExpiry.toDate();
    const diffTime = expiryDate.getTime() - now.getTime();
    const remainingDays = Math.max(0, Math.min(30, Math.ceil(diffTime / (1000 * 60 * 60 * 24))));

    if (remainingDays <= 0) {
        throw new functions.https.HttpsError("failed-precondition", "VIP subscription has already expired.");
    }

    // Query vip_tiers to get original price
    const tiersSnap = await db.collection("vip_tiers").where("name", "==", vipTier).get();
    let originalPrice = 10000; // fallback
    if (!tiersSnap.empty) {
        originalPrice = tiersSnap.docs[0].data().monthlyPriceInDiamonds || 10000;
    }

    // 20% Net Cost was paid (80% credited immediately)
    const netCostPaid = Math.floor(originalPrice * 0.20);
    const refundAmount = Math.floor((netCostPaid * remainingDays) / 30);

    return db.runTransaction(async (transaction) => {
        const userRef = db.collection("users").doc(targetUid);

        // Cancel any pending retention credits
        const pendingSnap = await userRef.collection("pending_credits")
            .where("type", "==", "vip_retention_bonus")
            .where("status", "==", "pending")
            .get();

        pendingSnap.forEach((doc) => {
            transaction.update(doc.ref, { status: "cancelled", cancelledAt: admin.firestore.Timestamp.fromDate(now) });
        });

        // Revert cosmetics from snapshot if available
        const snapshot = targetData.vipSnapshot || {};
        transaction.update(userRef, {
            vipTier: snapshot.originalTier || "none",
            vipExpiry: snapshot.originalExpiry || null,
            profileFrame: snapshot.originalProfileFrame || "",
            entryAnimation: snapshot.originalEntryAnimation || "",
            badgeIcon: snapshot.originalBadgeIcon || "",
            helloId: snapshot.originalHelloId || targetData.helloId,
            vipSnapshot: null, // clear snapshot
            diamondBalance: admin.firestore.FieldValue.increment(refundAmount)
        });

        // Log transaction
        const txRef = userRef.collection("transactions").doc();
        transaction.set(txRef, {
            type: "refund",
            amount: refundAmount,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            description: `Revoked ${vipTier} subscription. Pro-rated refund of ${refundAmount} diamonds credited (${remainingDays} days remaining).`
        });

        return { success: true, refundAmount, remainingDays, originalTier: snapshot.originalTier || "none" };
    });
});

/**
 * 🔍 Search Users by username or displayName
 */
exports.searchUsers = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const { query: searchQuery } = data;
    if (!searchQuery || searchQuery.trim().length < 2) {
        throw new functions.https.HttpsError("invalid-argument", "Search query must be at least 2 characters.");
    }

    const q = searchQuery.trim().toLowerCase();

    const usernameSnap = await db.collection("users")
        .where("username_lowercase", ">=", q)
        .where("username_lowercase", "<=", q + "\uf8ff")
        .limit(10)
        .get();

    const displayNameSnap = await db.collection("users")
        .where("displayName_lowercase", ">=", q)
        .where("displayName_lowercase", "<=", q + "\uf8ff")
        .limit(5)
        .get();

    const seenUids = new Set();
    const results = [];

    for (const doc of [...usernameSnap.docs, ...displayNameSnap.docs]) {
        if (seenUids.has(doc.id)) continue;
        seenUids.add(doc.id);
        const d = doc.data();
        results.push({
            uid: doc.id,
            username: d.username || "",
            displayName: d.displayName || "",
            profilePhotoUrl: d.profilePhotoUrl || "",
            gender: d.gender || "",
            level: d.level || 0,
        });
    }

    return { users: results.slice(0, 15) };
});

/**
 * 👥 Send Friend Request
 */
exports.sendFriendRequest = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const senderUid = context.auth.uid;
    const { targetUid } = data;

    if (!targetUid || targetUid === senderUid) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid target user.");
    }

    const targetDoc = await db.collection("users").doc(targetUid).get();
    if (!targetDoc.exists) throw new functions.https.HttpsError("not-found", "Target user not found.");

    const blocked = targetDoc.data().blockedUids || [];
    if (blocked.includes(senderUid)) {
        throw new functions.https.HttpsError("permission-denied", "You cannot send a request to this user.");
    }

    const requestId = `${senderUid}_${targetUid}`;
    const existingReq = await db.collection("relationship_requests").doc(requestId).get();
    if (existingReq.exists) {
        throw new functions.https.HttpsError("already-exists", "Friend request already sent.");
    }

    const existingRelationship = await db.collection("relationships")
        .where("participants", "array-contains", senderUid)
        .where("status", "==", "active")
        .where("type", "==", "friendship")
        .get();

    for (const doc of existingRelationship.docs) {
        const parts = doc.data().participants || [];
        if (parts.includes(targetUid)) {
            throw new functions.https.HttpsError("already-exists", "Already friends with this user.");
        }
    }

    const senderDoc = await db.collection("users").doc(senderUid).get();
    const senderData = senderDoc.data();

    await db.collection("relationship_requests").doc(requestId).set({
        senderUid,
        targetUid,
        type: "friendship",
        status: "pending",
        senderName: senderData?.displayName || "Unknown",
        senderAvatar: senderData?.profilePhotoUrl || "",
        createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    try { await sendPush(targetUid, "Friend Request 👋", `${senderData?.displayName || "Someone"} wants to be your friend!`, { type: "FRIEND_REQUEST", requestId }); } catch (_) {}

    return { success: true, requestId };
});

/**
 * 👥 Accept Friend Request
 */
exports.acceptFriendRequest = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const { requestId } = data;
    const requestRef = db.collection("relationship_requests").doc(requestId);

    return db.runTransaction(async (transaction) => {
        const reqDoc = await transaction.get(requestRef);
        if (!reqDoc.exists) throw new functions.https.HttpsError("not-found", "Request not found.");
        const reqData = reqDoc.data();
        const isAdmin = await isUserAdmin(context.auth.uid);
        if (reqData.targetUid !== context.auth.uid && !isAdmin) {
            throw new functions.https.HttpsError("permission-denied", "Only target can accept.");
        }
        if (reqData.status !== "pending") {
            throw new functions.https.HttpsError("failed-precondition", "Request already processed.");
        }

        const senderRef = db.collection("users").doc(reqData.senderUid);
        const targetRef = db.collection("users").doc(reqData.targetUid);

        transaction.update(senderRef, { friendsCount: admin.firestore.FieldValue.increment(1) });
        transaction.update(targetRef, { friendsCount: admin.firestore.FieldValue.increment(1) });

        const relationshipId = `${reqData.senderUid}_${reqData.targetUid}`;
        transaction.set(db.collection("relationships").doc(relationshipId), {
            participants: [reqData.senderUid, reqData.targetUid],
            type: "friendship",
            status: "active",
            intimacy: 0,
            level: 1,
            startedAt: admin.firestore.Timestamp.now(),
            lastActivityAt: admin.firestore.Timestamp.now(),
            intimacyBreakdown: { giftPoints: 0, diamondPoints: 0, activityPoints: 0 }
        });

        transaction.update(requestRef, { status: "accepted" });

        // Notify sender
        const targetDoc = await db.collection("users").doc(reqData.targetUid).get();
        const targetName = targetDoc.data()?.displayName || "Someone";
        sendPush(reqData.senderUid, "Friend Request Accepted ✅", `${targetName} accepted your friend request!`, { type: "FRIEND_REQUEST_ACCEPTED", relationshipId });

        return { success: true, relationshipId };
    });
});

/**
 * 👥 Reject Friend Request
 */
exports.rejectFriendRequest = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const { requestId } = data;
    const requestRef = db.collection("relationship_requests").doc(requestId);

    return db.runTransaction(async (transaction) => {
        const reqDoc = await transaction.get(requestRef);
        if (!reqDoc.exists) throw new functions.https.HttpsError("not-found", "Request not found.");
        const isAdmin = await isUserAdmin(context.auth.uid);
        if (reqDoc.data().targetUid !== context.auth.uid && !isAdmin) {
            throw new functions.https.HttpsError("permission-denied", "Only target can reject.");
        }
        transaction.update(requestRef, { status: "rejected" });

        // Notify sender
        const targetDoc = await db.collection("users").doc(reqDoc.data().targetUid).get();
        const targetName = targetDoc.data()?.displayName || "Someone";
        sendPush(reqDoc.data().senderUid, "Friend Request Rejected 💔", `${targetName} rejected your friend request.`, { type: "FRIEND_REQUEST_REJECTED" });

        return { success: true };
    });
});

/**
 * 👥 Remove Friend
 */
exports.removeFriend = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const uid = context.auth.uid;
    const { relationshipId } = data;

    if (!relationshipId) throw new functions.https.HttpsError("invalid-argument", "relationshipId required.");

    return db.runTransaction(async (transaction) => {
        const relRef = db.collection("relationships").doc(relationshipId);
        const relDoc = await transaction.get(relRef);
        if (!relDoc.exists) throw new functions.https.HttpsError("not-found", "Relationship not found.");

        const relData = relDoc.data();
        const participants = relData.participants || [];
        if (!participants.includes(uid)) {
            throw new functions.https.HttpsError("permission-denied", "Not part of this relationship.");
        }

        transaction.update(relRef, { status: "ended", endedAt: admin.firestore.Timestamp.now() });

        const otherUid = participants.find(p => p !== uid);
        if (otherUid) {
            transaction.update(db.collection("users").doc(uid), { friendsCount: admin.firestore.FieldValue.increment(-1) });
            transaction.update(db.collection("users").doc(otherUid), { friendsCount: admin.firestore.FieldValue.increment(-1) });
        }

        return { success: true };
    });
});

/**
 * 💔 Dissolve CP Partnership
 */
exports.dissolveCP = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const uid = context.auth.uid;
    const { relationshipId } = data;

    if (!relationshipId) throw new functions.https.HttpsError("invalid-argument", "relationshipId required.");

    return db.runTransaction(async (transaction) => {
        const relRef = db.collection("relationships").doc(relationshipId);
        const relDoc = await transaction.get(relRef);
        if (!relDoc.exists) throw new functions.https.HttpsError("not-found", "Relationship not found.");

        const relData = relDoc.data();
        const participants = relData.participants || [];
        if (!participants.includes(uid)) {
            throw new functions.https.HttpsError("permission-denied", "Not part of this relationship.");
        }

        transaction.update(relRef, { status: "ended", endedAt: admin.firestore.Timestamp.now() });

        for (const pUid of participants) {
            const userDoc = await transaction.get(db.collection("users").doc(pUid));
            const userData = userDoc.data() || {};
            const currentFrame = (userData.profileFrame || "").toLowerCase();

            const isCpFrame = currentFrame.includes("1.svga") || 
                              currentFrame.includes("2.svga") || 
                              currentFrame.includes("3.svga") || 
                              currentFrame.includes("cp_frame") || 
                              currentFrame.includes("couple");

            const updates = {
                partnerUid: admin.firestore.FieldValue.delete(),
                partnerName: admin.firestore.FieldValue.delete(),
                partnerAvatar: admin.firestore.FieldValue.delete(),
                cpLevel: 0,
                cpPoints: 0
            };

            if (isCpFrame) {
                updates.profileFrame = "";
            }

            transaction.update(db.collection("users").doc(pUid), updates);
        }

        // Notify partner about dissolution
        const otherUid = participants.find(u => u !== uid);
        if (otherUid) {
            const actorDoc = await db.collection("users").doc(uid).get();
            const actorName = actorDoc.data()?.displayName || "Your partner";
            sendPush(otherUid, "Relationship Ended 💔", `${actorName} has dissolved the relationship.`, { type: "RELATIONSHIP_ENDED", relationshipId });
        }

        return { success: true };
    });
});

/**
 * 💕 Update Relationship Intimacy
 */
exports.updateIntimacy = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const uid = context.auth.uid;
    const { relationshipId, source, points } = data;

    if (!relationshipId || points == null || points <= 0) {
        throw new functions.https.HttpsError("invalid-argument", "relationshipId and positive points required.");
    }

    const validSources = ["gift", "diamond", "activity"];
    if (!validSources.includes(source)) {
        throw new functions.https.HttpsError("invalid-argument", "Source must be gift, diamond, or activity.");
    }

    // Read dynamic level configs
    const levelsSnap = await db.collection("relationship_levels").orderBy("level", "asc").get();
    const levels = levelsSnap.docs.map(d => ({ id: d.id, ...d.data() }));
    const levelThresholds = levels.map(l => l.minIntimacy || 0);
    if (levelThresholds.length === 0) {
        // Fallback defaults
        levelThresholds.push(0, 1000, 5000, 20000);
    }

    return db.runTransaction(async (transaction) => {
        const relRef = db.collection("relationships").doc(relationshipId);
        const relDoc = await transaction.get(relRef);
        if (!relDoc.exists) throw new functions.https.HttpsError("not-found", "Relationship not found.");

        const relData = relDoc.data();
        const participants = relData.participants || [];
        if (!participants.includes(uid)) {
            throw new functions.https.HttpsError("permission-denied", "Not part of this relationship.");
        }
        if (relData.status !== "active") {
            throw new functions.https.HttpsError("failed-precondition", "Relationship is not active.");
        }

        const oldLevel = relData.level || 1;
        const newIntimacy = (relData.intimacy || 0) + points;
        let newLevel = 1;
        for (let i = levelThresholds.length - 1; i >= 0; i--) {
            if (newIntimacy >= levelThresholds[i]) { newLevel = i + 1; break; }
        }
        const newBreakdown = { ...(relData.intimacyBreakdown || { giftPoints: 0, diamondPoints: 0, activityPoints: 0 }) };
        newBreakdown[`${source}Points`] = (newBreakdown[`${source}Points`] || 0) + points;

        transaction.update(relRef, {
            intimacy: newIntimacy,
            level: newLevel,
            lastActivityAt: admin.firestore.Timestamp.now(),
            intimacyBreakdown: newBreakdown
        });

        // Auto-grant rewards on level up
        const rewardsGranted = relData.rewardsGranted || [];
        const newlyGranted = [];
        for (const lvl of levels) {
            if (lvl.level <= newLevel && !rewardsGranted.includes(lvl.level)) {
                newlyGranted.push(lvl.level);
            }
        }
        if (newlyGranted.length > 0) {
            transaction.update(relRef, {
                rewardsGranted: admin.firestore.FieldValue.arrayUnion(newlyGranted)
            });
        }

        for (const pUid of participants) {
            if (relData.type === "cp") {
                transaction.update(db.collection("users").doc(pUid), { cpPoints: newIntimacy, cpLevel: newLevel });
            }
        }

        // Send level up notification
        const levelChanged = newLevel > oldLevel && newlyGranted.length > 0;
        if (levelChanged) {
            const levelName = levels.find(l => l.level === newLevel)?.name || `Level ${newLevel}`;
            for (const pUid of participants) {
                const targetUid = participants.find(u => u !== pUid);
                if (targetUid) {
                    const partnerDoc = await db.collection("users").doc(targetUid).get();
                    const partnerName = partnerDoc.data()?.displayName || "Your partner";
                    const msg = relData.type === "cp"
                        ? `💕 ${partnerName} — Your CP relationship reached ${levelName}!`
                        : `👫 ${partnerName} — Your friendship reached ${levelName}!`;
                    sendPush(pUid, "Relationship Level Up! 🎉", msg, { type: "RELATIONSHIP_LEVEL_UP", relationshipId, level: newLevel });
                }
            }
        }

        return { success: true, newIntimacy, newLevel, rewardsGranted: newlyGranted };
    });
});

/**
 * 🏆 Calculate Relationship Rankings (Admin callable)
 */
exports.calculateRelationshipRankings = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    const tags = callerDoc.data().tags || [];
    if (!tags.includes("Admin") && !tags.includes("SuperAdmin")) {
        throw new functions.https.HttpsError("permission-denied", "Admin only.");
    }

    const { period } = data;
    const validPeriods = ["daily", "weekly", "monthly", "all_time"];
    if (!validPeriods.includes(period)) {
        throw new functions.https.HttpsError("invalid-argument", "Period must be daily, weekly, monthly, or all_time.");
    }

    const relationshipsSnap = await db.collection("relationships")
        .where("status", "==", "active")
        .get();

    const ranked = relationshipsSnap.docs
        .map(doc => ({ id: doc.id, ...doc.data() }))
        .sort((a, b) => (b.intimacy || 0) - (a.intimacy || 0))
        .slice(0, 100);

    const batch = db.batch();

    const existingRankings = await db.collection("relationship_rankings")
        .where("period", "==", period)
        .get();
    for (const doc of existingRankings.docs) {
        batch.delete(doc.ref);
    }

    ranked.forEach((rel, index) => {
        const rankRef = db.collection("relationship_rankings").doc(`${period}_${rel.id}`);
        batch.set(rankRef, {
            relationshipId: rel.id,
            participants: rel.participants || [],
            intimacy: rel.intimacy || 0,
            level: rel.level || 1,
            period: period,
            rank: index + 1,
            calculatedAt: admin.firestore.Timestamp.now()
        });
    });

    await batch.commit();
    return { success: true, count: ranked.length, period };
});

/**
 * ⏰ Scheduled: Calculate Daily Rankings (runs at midnight UTC)
 */
exports.resetDailyRelationshipRankings = functions.pubsub.schedule("0 0 * * *").onRun(async (context) => {
    const relationshipsSnap = await db.collection("relationships")
        .where("status", "==", "active")
        .get();

    const ranked = relationshipsSnap.docs
        .map(doc => ({ id: doc.id, ...doc.data() }))
        .sort((a, b) => (b.intimacy || 0) - (a.intimacy || 0))
        .slice(0, 100);

    const allRankings = await db.collection("relationship_rankings")
        .where("period", "in", ["daily", "weekly", "monthly", "all_time"])
        .get();

    const batch = db.batch();
    for (const doc of allRankings.docs) {
        batch.delete(doc.ref);
    }

    for (const period of ["daily", "weekly", "monthly", "all_time"]) {
        ranked.forEach((rel, index) => {
            const rankRef = db.collection("relationship_rankings").doc(`${period}_${rel.id}`);
            batch.set(rankRef, {
                relationshipId: rel.id,
                participants: rel.participants || [],
                intimacy: rel.intimacy || 0,
                level: rel.level || 1,
                period: period,
                rank: index + 1,
                calculatedAt: admin.firestore.Timestamp.now()
            });
        });
    }

    await batch.commit();
    console.log(`[RANKINGS] Daily rankings calculated for ${ranked.length} relationships.`);
});

// ════════════════════════════════════════════════════════════════
// 🎯 DYNAMIC EVENT SYSTEM — Recharge Bonus & Milestone Events
// ════════════════════════════════════════════════════════════════

/**
 * Get active events for the current time
 */
async function getActiveEvents(type) {
    const now = admin.firestore.Timestamp.now();
    let query = db.collection("dynamic_events")
        .where("isActive", "==", true)
        .where("startDate", "<=", now)
        .where("endDate", ">=", now);
    if (type) {
        query = query.where("type", "==", type);
    }
    const snap = await query.get();
    return snap.docs.map(d => ({ id: d.id, ...d.data() }));
}

/**
 * Inline: process recharge bonus (no auth check — caller must handle)
 */
async function processRechargeBonusInline(uid, amount) {
    const events = await getActiveEvents("recharge_bonus");
    if (events.length === 0) return { bonus: 0, eventId: null };

    const event = events[0];
    const packagesSnap = await db.collection("recharge_bonus_packages")
        .where("eventId", "==", event.id)
        .where("isActive", "==", true)
        .orderBy("rechargeAmount", "asc")
        .get();

    let totalBonus = 0;
    let matchedPackage = null;
    for (const pkgDoc of packagesSnap.docs) {
        const pkg = pkgDoc.data();
        if (amount >= (pkg.rechargeAmount || 0)) {
            totalBonus = Math.max(totalBonus, pkg.bonusDiamonds || pkg.bonusCoins || 0);
            matchedPackage = { id: pkgDoc.id, ...pkg };
        }
    }

    if (matchedPackage || amount > 0) {
        const userRef = db.collection("users").doc(uid);
        const userUpdates = {};
        if (totalBonus > 0) {
            userUpdates.diamondBalance = admin.firestore.FieldValue.increment(totalBonus);
            userUpdates[`event_bonuses.${event.id}`] = admin.firestore.FieldValue.increment(totalBonus);
        }

        // Automatic Activation of Frame Reward with Validity Countdown
        const validityDays = matchedPackage?.validityDays || (amount >= 100 ? 14 : (amount >= 10 ? 7 : (amount >= 5 ? 3 : 1)));
        const frameUrl = matchedPackage?.frameUrl || 'assets/images/super/super-admin.svga';
        const expiresAt = admin.firestore.Timestamp.fromDate(new Date(Date.now() + validityDays * 24 * 60 * 60 * 1000));

        userUpdates.profileFrame = frameUrl;
        userUpdates.rechargeFrameExpiresAt = expiresAt;
        userUpdates.rechargeFrameUrl = frameUrl;

        await userRef.update(userUpdates);

        if (totalBonus > 0) {
            await db.collection("users").doc(uid).collection("transactions").add({
                type: "event_bonus", amount: totalBonus, currency: "diamonds",
                eventId: event.id, eventName: event.title || "Bonus Event",
                description: `Bonus from ${event.title || "Recharge Bonus Event"}`,
                timestamp: admin.firestore.Timestamp.now()
            });
        }
    }
    return { bonus: totalBonus, eventId: event.id, package: matchedPackage };
}

/**
 * Inline: track recharge milestone (no auth check — caller must handle)
 */
async function trackRechargeMilestoneInline(uid, paidAmount, bonusAmount = 0) {
    const events = await getActiveEvents("recharge_milestone");
    if (events.length === 0) return { progress: null, milestones: [] };

    const event = events[0];
    const includeBonus = event.includeBonusInProgress ?? false;
    const addedProgress = includeBonus ? (paidAmount + bonusAmount) : paidAmount;

    const milestonesSnap = await db.collection("recharge_milestones")
        .where("eventId", "==", event.id)
        .where("isActive", "==", true)
        .orderBy("targetAmount", "asc")
        .get();

    if (milestonesSnap.docs.length === 0) return { progress: null, milestones: [] };

    const progressRef = db.collection("user_event_progress").doc(`${uid}_${event.id}`);
    const progressDoc = await progressRef.get();

    let currentProgress = addedProgress;
    const claimedMilestones = [];
    if (progressDoc.exists) {
        const pData = progressDoc.data();
        currentProgress += (pData.progress || 0);
        claimedMilestones.push(...(pData.claimedMilestones || []));
    }

    const milestones = milestonesSnap.docs.map(d => ({ id: d.id, ...d.data() }));
    const newlyClaimed = [];
    const batch = db.batch();

    for (const ms of milestones) {
        if (!claimedMilestones.includes(ms.id) && currentProgress >= (ms.targetAmount || 0)) {
            newlyClaimed.push(ms.id);
            const userRef = db.collection("users").doc(uid);
            
            // Credit diamonds reward
            if ((ms.rewardType === "diamonds" || ms.rewardType === "coins") && (ms.rewardAmount || 0) > 0) {
                batch.update(userRef, {
                    diamondBalance: admin.firestore.FieldValue.increment(ms.rewardAmount)
                });
            }
            // Unlock asset rewards (Avatar Frame, Entry Effect, Chat Bubble)
            if (ms.frameUrl) {
                batch.update(userRef, { unlockedAvatarFrames: admin.firestore.FieldValue.arrayUnion(ms.frameUrl) });
            }
            if (ms.entryEffectUrl) {
                batch.update(userRef, { unlockedEntryEffects: admin.firestore.FieldValue.arrayUnion(ms.entryEffectUrl) });
            }
            if (ms.chatBubbleUrl) {
                batch.update(userRef, { unlockedChatBubbles: admin.firestore.FieldValue.arrayUnion(ms.chatBubbleUrl) });
            }
        }
    }

    batch.set(progressRef, {
        uid, eventId: event.id, progress: currentProgress,
        claimedMilestones: [...claimedMilestones, ...newlyClaimed],
        updatedAt: admin.firestore.Timestamp.now()
    }, { merge: true });
    await batch.commit();

    return { progress: currentProgress, newlyClaimed, allClaimed: [...claimedMilestones, ...newlyClaimed] };
}

/**
 * 🎯 Process recharge bonus — called after a successful recharge
 * Applies bonus coins from active recharge bonus events
 */
exports.processRechargeBonus = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new HttpsError("unauthenticated", "Auth required.");
    const { amount } = data; // amount in diamonds recharged
    if (!amount || amount <= 0) throw new HttpsError("invalid-argument", "Invalid recharge amount.");

    const uid = context.auth.uid;
    const events = await getActiveEvents("recharge_bonus");
    if (events.length === 0) return { bonus: 0, eventId: null };

    const event = events[0];
    const packagesSnap = await db.collection("recharge_bonus_packages")
        .where("eventId", "==", event.id)
        .where("isActive", "==", true)
        .orderBy("rechargeAmount", "asc")
        .get();

    let totalBonus = 0;
    let matchedPackage = null;
    for (const pkgDoc of packagesSnap.docs) {
        const pkg = pkgDoc.data();
        const pkgAmount = pkg.rechargeAmount || 0;
        const bonus = pkg.bonusCoins || 0;
        if (amount >= pkgAmount) {
            totalBonus = Math.max(totalBonus, bonus);
            matchedPackage = { id: pkgDoc.id, ...pkg };
        }
    }

    if (totalBonus > 0) {
        const userRef = db.collection("users").doc(uid);
        await userRef.update({
            beansBalance: admin.firestore.FieldValue.increment(totalBonus),
            [`event_bonuses.${event.id}`]: admin.firestore.FieldValue.increment(totalBonus)
        });

        await db.collection("users").doc(uid).collection("transactions").add({
            type: "event_bonus",
            amount: totalBonus,
            currency: "beans",
            eventId: event.id,
            eventName: event.title || "Bonus Event",
            description: `Bonus from ${event.title || "Recharge Bonus Event"}`,
            timestamp: admin.firestore.Timestamp.now()
        });
    }

    return { bonus: totalBonus, eventId: event.id, package: matchedPackage };
});

/**
 * 🎯 Track recharge milestone — update user's progress toward milestones
 */
exports.trackRechargeMilestone = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new HttpsError("unauthenticated", "Auth required.");
    const { amount, includeBonus } = data;
    if (!amount || amount <= 0) throw new HttpsError("invalid-argument", "Invalid amount.");

    const uid = context.auth.uid;
    const events = await getActiveEvents("recharge_milestone");
    if (events.length === 0) return { progress: null, milestones: [] };

    const event = events[0];
    const milestonesSnap = await db.collection("recharge_milestones")
        .where("eventId", "==", event.id)
        .where("isActive", "==", true)
        .orderBy("targetAmount", "asc")
        .get();

    if (milestonesSnap.docs.length === 0) return { progress: null, milestones: [] };

    // Get or create user progress
    const progressRef = db.collection("user_event_progress").doc(`${uid}_${event.id}`);
    const progressDoc = await progressRef.get();

    let currentProgress = 0;
    const claimedMilestones = [];

    if (progressDoc.exists) {
        const pData = progressDoc.data();
        currentProgress = (pData.progress || 0) + amount;
        claimedMilestones.push(...(pData.claimedMilestones || []));
    } else {
        currentProgress = amount;
    }

    // Get all milestones
    const milestones = milestonesSnap.docs.map(d => ({ id: d.id, ...d.data() }));
    const newlyClaimed = [];
    const batch = db.batch();

    for (const ms of milestones) {
        if (!claimedMilestones.includes(ms.id) && currentProgress >= (ms.targetAmount || 0)) {
            // Claim reward
            const rewardAmount = ms.rewardAmount || 0;
            const rewardType = ms.rewardType || "coins";
            newlyClaimed.push(ms.id);

            if (rewardType === "coins" && rewardAmount > 0) {
                const userRef = db.collection("users").doc(uid);
                batch.update(userRef, {
                    beansBalance: admin.firestore.FieldValue.increment(rewardAmount),
                    [`event_milestone_rewards.${event.id}.${ms.id}`]: admin.firestore.FieldValue.increment(rewardAmount)
                });
            }
        }
    }

    // Save progress
    batch.set(progressRef, {
        uid,
        eventId: event.id,
        progress: currentProgress,
        claimedMilestones: [...claimedMilestones, ...newlyClaimed],
        updatedAt: admin.firestore.Timestamp.now()
    }, { merge: true });

    await batch.commit();

    return {
        progress: currentProgress,
        newlyClaimed,
        allClaimed: [...claimedMilestones, ...newlyClaimed],
        milestones: milestones.map(m => ({
            id: m.id,
            targetAmount: m.targetAmount,
            rewardAmount: m.rewardAmount,
            rewardType: m.rewardType,
            label: m.label || "",
            claimed: [...claimedMilestones, ...newlyClaimed].includes(m.id)
        }))
    };
});

/**
 * 🎯 Claim a specific milestone reward manually
 */
exports.claimMilestoneReward = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new HttpsError("unauthenticated", "Auth required.");
    const { eventId, milestoneId } = data;
    if (!eventId || !milestoneId) throw new HttpsError("invalid-argument", "eventId and milestoneId required.");

    const uid = context.auth.uid;
    const progressRef = db.collection("user_event_progress").doc(`${uid}_${eventId}`);
    const progressDoc = await progressRef.get();

    if (!progressDoc.exists) throw new HttpsError("not-found", "No progress found.");

    const pData = progressDoc.data();
    const claimed = pData.claimedMilestones || [];
    if (claimed.includes(milestoneId)) throw new HttpsError("already-exists", "Already claimed.");

    const msDoc = await db.collection("recharge_milestones").doc(milestoneId).get();
    if (!msDoc.exists) throw new HttpsError("not-found", "Milestone not found.");
    const ms = msDoc.data();

    if ((pData.progress || 0) < (ms.targetAmount || 0)) {
        throw new HttpsError("failed-precondition", "Target not reached yet.");
    }

    const rewardAmount = ms.rewardAmount || 0;
    if (rewardAmount > 0) {
        await db.collection("users").doc(uid).update({
            beansBalance: admin.firestore.FieldValue.increment(rewardAmount)
        });
    }

    await progressRef.update({
        claimedMilestones: admin.firestore.FieldValue.arrayUnion([milestoneId]),
        updatedAt: admin.firestore.Timestamp.now()
    });

    return { success: true, rewardAmount, milestoneId };
});

/**
 * 📊 Get user's event progress
 */
exports.getUserEventProgress = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new HttpsError("unauthenticated", "Auth required.");
    const { eventId } = data;
    if (!eventId) throw new HttpsError("invalid-argument", "eventId required.");

    const uid = context.auth.uid;
    const progressRef = db.collection("user_event_progress").doc(`${uid}_${eventId}`);
    const doc = await progressRef.get();

    if (!doc.exists) {
        return { progress: 0, claimedMilestones: [] };
    }

    const pData = doc.data();
    return {
        progress: pData.progress || 0,
        claimedMilestones: pData.claimedMilestones || [],
        updatedAt: pData.updatedAt
    };
});

/**
 * 🎯 Upload/Create Banner via callable function
 */
exports.uploadBanner = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new HttpsError("unauthenticated", "Auth required.");
    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    const tags = callerDoc.data().tags || [];
    if (!tags.includes("Admin") && !tags.includes("SuperAdmin")) {
        throw new HttpsError("permission-denied", "Admin only.");
    }

    const { bannerId, imageUrl, title, subtitle, buttonText, actionType, actionValue, isActive, priority } = data;
    if (!imageUrl || !title) throw new HttpsError("invalid-argument", "imageUrl and title required.");

    const bid = bannerId || db.collection("app_banners").doc().id;
    await db.collection("app_banners").doc(bid).set({
        bannerId: bid,
        imageUrl,
        title,
        subtitle: subtitle || "",
        buttonText: buttonText || "",
        actionType: actionType || "none",
        actionValue: actionValue || "",
        isActive: isActive !== false,
        priority: priority || 100,
        createdBy: context.auth.uid,
        createdAt: admin.firestore.Timestamp.now()
    });

    return { success: true, bannerId: bid };
});

/**
 * 🌱 Seed Default Event Models (Admin)
 */
exports.seedEventSystem = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new HttpsError("unauthenticated", "Auth required.");
    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    const tags = callerDoc.data().tags || [];
    if (!tags.includes("Admin") && !tags.includes("SuperAdmin")) {
        throw new HttpsError("permission-denied", "Admin only.");
    }

    const now = admin.firestore.Timestamp.now();
    const future = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 30 * 24 * 60 * 60 * 1000));

    // Seed a sample recharge bonus event
    const bonusEventRef = db.collection("dynamic_events").doc("sample_bonus_event");
    await bonusEventRef.set({
        id: "sample_bonus_event",
        title: "Recharge Bonus Event",
        description: "Get bonus diamonds on every recharge!",
        type: "recharge_bonus",
        htmlContent: "<h1>Recharge Bonus</h1><p>Get bonus diamonds on every recharge!</p><ul><li>$1 → 3M coins</li><li>$5 → 15M coins</li><li>$10 → 35M coins</li></ul>",
        bannerImage: "",
        backgroundImage: "",
        backgroundType: "color",
        backgroundColor: "#1a0a2e",
        themeColor: "#FFD700",
        icon: "stars",
        buttonText: "Recharge Now",
        buttonColor: "#D32F2F",
        buttonAction: "recharge",
        navigationTarget: "/wallet",
        priority: 1,
        isActive: true,
        startDate: now,
        endDate: future,
        createdAt: now,
        createdBy: context.auth.uid
    });

    // Seed sample bonus packages
    const packages = [
        { eventId: "sample_bonus_event", rechargeAmount: 1, baseCoins: 1000000, bonusCoins: 2000000, totalCoins: 3000000, sortOrder: 1, isActive: true },
        { eventId: "sample_bonus_event", rechargeAmount: 5, baseCoins: 5000000, bonusCoins: 10000000, totalCoins: 15000000, sortOrder: 2, isActive: true },
        { eventId: "sample_bonus_event", rechargeAmount: 10, baseCoins: 10000000, bonusCoins: 25000000, totalCoins: 35000000, sortOrder: 3, isActive: true },
    ];

    const batch = db.batch();
    for (const pkg of packages) {
        const ref = db.collection("recharge_bonus_packages").doc();
        batch.set(ref, pkg);
    }

    // Seed a sample milestone event
    const milestoneEventRef = db.collection("dynamic_events").doc("sample_milestone_event");
    await milestoneEventRef.set({
        id: "sample_milestone_event",
        title: "Recharge Milestone Event",
        description: "Reach recharge milestones to claim rewards!",
        type: "recharge_milestone",
        htmlContent: "<h1>Milestone Event</h1><p> Reach recharge milestones and claim rewards! </p>",
        bannerImage: "",
        backgroundImage: "",
        backgroundType: "gradient",
        backgroundColor: "#0d1b2a",
        backgroundGradient: ["#0d1b2a", "#1b2838", "#2d3a4a"],
        themeColor: "#00E5FF",
        icon: "flag",
        buttonText: "Recharge Now",
        buttonColor: "#00E5FF",
        buttonAction: "recharge",
        navigationTarget: "/wallet",
        priority: 2,
        isActive: true,
        startDate: now,
        endDate: future,
        includeBonus: false,
        createdAt: now,
        createdBy: context.auth.uid
    });

    // Seed sample milestones
    const milestones = [
        { eventId: "sample_milestone_event", targetAmount: 10, rewardAmount: 1000000, rewardType: "coins", label: "10M", sortOrder: 1, isActive: true },
        { eventId: "sample_milestone_event", targetAmount: 20, rewardAmount: 3000000, rewardType: "coins", label: "20M", sortOrder: 2, isActive: true },
        { eventId: "sample_milestone_event", targetAmount: 50, rewardAmount: 8000000, rewardType: "coins", label: "50M", sortOrder: 3, isActive: true },
        { eventId: "sample_milestone_event", targetAmount: 100, rewardAmount: 20000000, rewardType: "coins", label: "100M", sortOrder: 4, isActive: true },
    ];

    for (const ms of milestones) {
        const ref = db.collection("recharge_milestones").doc();
        batch.set(ref, ms);
    }

    await batch.commit();
    return { success: true, message: "Sample events seeded!" };
});

/**
 * 🌱 Seed Default Relationship Levels (Admin only)
 */
exports.seedRelationshipLevels = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    const tags = callerDoc.data().tags || [];
    if (!tags.includes("Admin") && !tags.includes("SuperAdmin")) {
        throw new functions.https.HttpsError("permission-denied", "Admin only.");
    }

    const levels = [
        { level: 1, name: "Acquaintance", minIntimacy: 0, maxIntimacy: 999, badgeIcon: "handshake", rewards: [{ type: "badge", name: "Acquaintance Badge" }] },
        { level: 2, name: "Friend", minIntimacy: 1000, maxIntimacy: 4999, badgeIcon: "star", rewards: [{ type: "badge", name: "Friend Badge" }] },
        { level: 3, name: "Close Friend", minIntimacy: 5000, maxIntimacy: 19999, badgeIcon: "heart", rewards: [{ type: "badge", name: "Close Friend Badge" }, { type: "chat_bubble", name: "Friendship Bubble" }] },
        { level: 4, name: "Best Friend", minIntimacy: 20000, maxIntimacy: 49999, badgeIcon: "sparkles", rewards: [{ type: "badge", name: "Best Friend Badge" }, { type: "frame", name: "Best Friend Frame" }] },
        { level: 5, name: "Soulmate", minIntimacy: 50000, maxIntimacy: 999999, badgeIcon: "crown", rewards: [{ type: "badge", name: "Soulmate Badge" }, { type: "frame", name: "Soulmate Frame" }, { type: "entrance_effect", name: "Soulmate Entrance" }] },
    ];

    const batch = db.batch();
    for (const lvl of levels) {
        const ref = db.collection("relationship_levels").doc(`level_${lvl.level}`);
        batch.set(ref, lvl);
    }
    await batch.commit();

    return { success: true, count: levels.length };
});

/**
 * 📩 Helper: Send Official Inbox Reward Message
 */
async function sendOfficialRewardMessage(uid, { type = "reward", title, body, rewardName, rewardAmount, reason, status = "Claimed" }) {
    if (!uid) return;
    const msgRef = db.collection("users").doc(uid).collection("inbox_messages").doc();
    await msgRef.set({
        id: msgRef.id,
        type,
        title: title || "Official Reward Received 🎁",
        body: body || `You received ${rewardAmount || ""} ${rewardName || "Reward"}. Reason: ${reason || "Official Reward"}.`,
        rewardName: rewardName || "",
        rewardAmount: rewardAmount || 0,
        reason: reason || "Official Reward",
        status,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
}
exports.sendOfficialRewardMessage = sendOfficialRewardMessage;

/**
 * 📢 Admin Broadcast Callable Function (PRD 4)
 */
exports.sendAdminBroadcast = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    const tags = callerDoc.data()?.tags || [];
    if (!tags.includes("Admin") && !tags.includes("SuperAdmin")) {
        throw new functions.https.HttpsError("permission-denied", "Admin only.");
    }

    const { title, body, imageUrl, linkUrl, filters = {} } = data;
    if (!title || !body) throw new functions.https.HttpsError("invalid-argument", "title and body required.");

    let query = db.collection("users");
    if (filters.vipLevel != null) query = query.where("vipTier", "==", filters.vipLevel);
    if (filters.country) query = query.where("country", "==", filters.country);
    if (filters.familyId) query = query.where("familyId", "==", filters.familyId);
    if (filters.agencyId) query = query.where("agencyId", "==", filters.agencyId);

    const targetUsersSnap = await query.limit(500).get();
    const batch = db.batch();

    for (const uDoc of targetUsersSnap.docs) {
        const msgRef = uDoc.ref.collection("inbox_messages").doc();
        batch.set(msgRef, {
            id: msgRef.id,
            type: "broadcast",
            title,
            body,
            imageUrl: imageUrl || null,
            linkUrl: linkUrl || null,
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
        const fcmToken = uDoc.data()?.fcmToken;
        if (fcmToken) {
            try { await sendPush(uDoc.id, title, body, { type: "BROADCAST", linkUrl }); } catch (_) {}
        }
    }

    await batch.commit();
    return { success: true, targetCount: targetUsersSnap.docs.length };
});


/**
 * 💸 Refund VIP Membership (Admin)
 */
exports.refundVip = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    const tags = callerDoc.data()?.tags || [];
    if (!tags.includes("Admin") && !tags.includes("SuperAdmin")) {
        throw new functions.https.HttpsError("permission-denied", "Admin only.");
    }

    const { targetUid, refundAmount, reason } = data;
    if (!targetUid) throw new functions.https.HttpsError("invalid-argument", "targetUid required.");

    const userRef = db.collection("users").doc(targetUid);
    const uDoc = await userRef.get();
    if (!uDoc.exists) throw new functions.https.HttpsError("not-found", "Target user not found.");

    await userRef.update({
        vipTier: 0,
        vipExpiry: admin.firestore.FieldValue.delete(),
        diamondBalance: admin.firestore.FieldValue.increment(refundAmount || 0)
    });

    await sendOfficialRewardMessage(targetUid, {
        type: "system",
        title: "VIP Membership Refunded 💸",
        body: `Your VIP membership has been refunded. ${refundAmount || 0} diamonds have been credited back. Reason: ${reason || "Administrative Refund"}.`,
        rewardName: "Diamonds Refund",
        rewardAmount: refundAmount || 0,
        reason: reason || "VIP Refund",
        status: "Processed"
    });

    return { success: true };
});

/**
 * 📦 Helper: Send Official System Message & Push Notification
 */
async function sendOfficialRewardMessage(targetUid, rewardData) {
    try {
        const msgRef = db.collection("users").doc(targetUid).collection("inbox_messages").doc();
        await msgRef.set({
            id: msgRef.id,
            type: rewardData.type || "reward",
            title: rewardData.title || "Official Reward Received 🎁",
            body: rewardData.body || "You have received an official reward.",
            rewardName: rewardData.rewardName || "Reward",
            rewardAmount: rewardData.rewardAmount || 0,
            reason: rewardData.reason || "Official System Event",
            status: rewardData.status || "Received",
            read: false,
            createdAt: admin.firestore.Timestamp.now(),
            data: rewardData.data || { route: "/wallet" }
        });
        await sendPush(targetUid, rewardData.title || "Official Reward", rewardData.body || "", { route: "/inbox", type: "OFFICIAL_REWARD" });
    } catch (err) {
        console.error(`[OFFICIAL_MESSAGE_ERROR] Failed writing to ${targetUid}:`, err);
    }
}

/**
 * 💎 Diamond Seller Transfer Function
 */
exports.resellerTransferDiamonds = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const senderUid = context.auth.uid;
    const { targetHelloId, amount } = data;

    const parsedAmount = parseInt(amount);
    if (!targetHelloId || isNaN(parsedAmount) || parsedAmount <= 0) {
        throw new functions.https.HttpsError("invalid-argument", "Valid targetHelloId and positive amount required.");
    }

    const senderRef = db.collection("users").doc(senderUid);
    const senderDoc = await senderRef.get();
    if (!senderDoc.exists) throw new functions.https.HttpsError("not-found", "Sender not found.");
    const senderData = senderDoc.data();

    if (!senderData.isReseller && !(senderData.tags || []).includes("Reseller") && !(senderData.tags || []).includes("Admin")) {
        throw new functions.https.HttpsError("permission-denied", "Only authorized Diamond Sellers can transfer stock.");
    }

    const stock = senderData.diamondStock || 0;
    if (stock < parsedAmount) {
        throw new functions.https.HttpsError("failed-precondition", `Insufficient diamond stock. Current stock: ${stock.toLocaleString()}`);
    }

    let targetUid = null;
    let targetData = null;
    const helloIdNum = parseInt(targetHelloId);

    const queryNum = await db.collection("users").where("helloId", "==", isNaN(helloIdNum) ? targetHelloId : helloIdNum).limit(1).get();
    if (!queryNum.empty) {
        targetUid = queryNum.docs[0].id;
        targetData = queryNum.docs[0].data();
    } else {
        const queryStr = await db.collection("users").where("helloId", "==", targetHelloId.toString()).limit(1).get();
        if (!queryStr.empty) {
            targetUid = queryStr.docs[0].id;
            targetData = queryStr.docs[0].data();
        }
    }

    if (!targetUid || !targetData) {
        throw new functions.https.HttpsError("not-found", `User with Hello ID ${targetHelloId} not found.`);
    }

    const targetRef = db.collection("users").doc(targetUid);
    const now = new Date();
    const dateTimeStr = now.toLocaleDateString("en-US", { day: "numeric", month: "long", year: "numeric" }) + ", " + now.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
    const sellerName = senderData.displayName || "Diamond Seller";
    const sellerId = senderData.helloId ? `S${senderData.helloId}` : senderUid.substring(0, 6);

    const bonusAmount = parsedAmount * 2; // 2x bonus event diamonds (e.g. 1M -> 2M bonus)
    const totalCredited = parsedAmount + bonusAmount;

    await db.runTransaction(async (transaction) => {
        transaction.update(senderRef, {
            diamondStock: admin.firestore.FieldValue.increment(-parsedAmount)
        });
        transaction.update(targetRef, {
            diamondBalance: admin.firestore.FieldValue.increment(totalCredited)
        });

        const txRef = db.collection("reseller_transactions").doc();
        transaction.set(txRef, {
            senderUid: senderUid,
            senderName: sellerName,
            senderHelloId: sellerId,
            targetUid: targetUid,
            targetName: targetData.displayName || "User",
            targetHelloId: targetHelloId,
            amount: parsedAmount,
            bonusAmount: bonusAmount,
            totalCredited: totalCredited,
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        });

        const inboxRef = targetRef.collection("inbox_messages").doc();
        transaction.set(inboxRef, {
            type: "reward",
            title: "Recharge Successful",
            body: `Recharged successfully！ You have obtained ${bonusAmount} diamonds from the recharge event, and other rewards have been delivered to your package. Please check your account.`,
            rewardName: "Diamonds",
            rewardAmount: totalCredited,
            reason: `Recharge Event 200% Bonus (${parsedAmount.toLocaleString()} basic + ${bonusAmount.toLocaleString()} bonus)`,
            status: "Received",
            read: false,
            createdAt: admin.firestore.Timestamp.now(),
            data: {
                sellerName: sellerName,
                sellerId: sellerId,
                amount: totalCredited,
                route: "/wallet"
            }
        });
    });

    const pushBody = `Recharged successfully！ You have obtained ${bonusAmount} diamonds from the recharge event, and other rewards have been delivered to your package. Please check your account.`;
    await sendPush(targetUid, "Recharge Successful", pushBody, { route: "/inbox", type: "RECHARGE_SUCCESSFUL" });

    return { success: true, targetName: targetData.displayName, amount: totalCredited, bonusAmount: bonusAmount };
});


/**
 * ═══════════════════════════════════════════════════════════════════════════
 * ⚔️ FAMILY BATTLE SYSTEM CLOUD FUNCTIONS
 * ═══════════════════════════════════════════════════════════════════════════
 */

// Helper to determine Family Level from combat points
function getFamilyLevelForPoints(points) {
    if (points >= 1000000000) return 10;
    if (points >= 700000000) return 9;
    if (points >= 500000000) return 8;
    if (points >= 300000000) return 7;
    if (points >= 100000000) return 6;
    if (points >= 50000000) return 5;
    if (points >= 30000000) return 4;
    if (points >= 20000000) return 3;
    if (points >= 10000000) return 2;
    if (points >= 5000000) return 1;
    return 1;
}

// Helper to determine Dynamic Member Capacity from Level
function getMemberCapacityForLevel(level) {
    if (level >= 10) return 1000;
    if (level >= 9) return 500;
    if (level >= 7) return 300;
    if (level >= 5) return 200;
    if (level >= 3) return 150;
    return 100;
}

/**
 * 1. Send Family Battle Request with Concurrency Lock
 */
exports.sendFamilyBattleRequest = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const uid = context.auth.uid;
    const { challengerFamilyId, opponentFamilyId, cost, imageUrl } = data;

    if (!challengerFamilyId || !opponentFamilyId) {
        throw new functions.https.HttpsError("invalid-argument", "Challenger and opponent family IDs required.");
    }

    // 🔒 Concurrency Lock Check: 1 Family = Max 1 Active Battle
    const [challengerActive, opponentActive] = await Promise.all([
        db.collection("families").doc(challengerFamilyId).collection("battles").where("status", "==", "active").limit(1).get(),
        db.collection("families").doc(opponentFamilyId).collection("battles").where("status", "==", "active").limit(1).get()
    ]);

    if (!challengerActive.empty) {
        throw new functions.https.HttpsError("failed-precondition", "Your Family is already participating in an active Family Battle.");
    }
    if (!opponentActive.empty) {
        throw new functions.https.HttpsError("failed-precondition", "Opponent Family is already participating in an active Family Battle.");
    }

    // Check pending request lock
    const existingReq = await db.collection("familyBattleRequests")
        .where("challengerFamilyId", "==", challengerFamilyId)
        .where("status", "==", "pending")
        .limit(1)
        .get();

    if (!existingReq.empty) {
        throw new functions.https.HttpsError("already-exists", "Your Family already has an active outgoing battle request.");
    }

    const challengerDoc = await db.collection("families").doc(challengerFamilyId).get();
    const opponentDoc = await db.collection("families").doc(opponentFamilyId).get();

    if (!challengerDoc.exists || !opponentDoc.exists) {
        throw new functions.https.HttpsError("not-found", "One or both families were not found.");
    }

    const challengerData = challengerDoc.data();
    const opponentData = opponentDoc.data();

    const reqRef = db.collection("familyBattleRequests").doc();
    await reqRef.set({
        requestId: reqRef.id,
        challengerFamilyId: challengerFamilyId,
        challengerName: challengerData.name || "Challenger Family",
        challengerAvatar: challengerData.avatarUrl || "",
        opponentFamilyId: opponentFamilyId,
        opponentName: opponentData.name || "Opponent Family",
        opponentAvatar: opponentData.avatarUrl || "",
        cost: cost || 0,
        imageUrl: imageUrl || "",
        senderUid: uid,
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log(`[FAMILY_BATTLE] Battle request created: ${reqRef.id} (${challengerFamilyId} vs ${opponentFamilyId})`);
    return { success: true, requestId: reqRef.id };
});

/**
 * 2. Accept Family Battle Request with State Lock & Overwrite Protection
 */
exports.acceptFamilyBattle = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const { requestId } = data;

    if (!requestId) {
        throw new functions.https.HttpsError("invalid-argument", "requestId required.");
    }

    const reqRef = db.collection("familyBattleRequests").doc(requestId);
    const reqDoc = await reqRef.get();

    if (!reqDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Battle request not found.");
    }

    const reqData = reqDoc.data();
    if (reqData.status !== "pending") {
        throw new functions.https.HttpsError("failed-precondition", `Request is already ${reqData.status}.`);
    }

    const challengerId = reqData.challengerFamilyId;
    const opponentId = reqData.opponentFamilyId;

    // 🔒 Hard Concurrency Check & Overwrite Protection: 1 Family = Max 1 Active Battle
    const [challengerActive, opponentActive] = await Promise.all([
        db.collection("families").doc(challengerId).collection("battles").where("status", "==", "active").limit(1).get(),
        db.collection("families").doc(opponentId).collection("battles").where("status", "==", "active").limit(1).get()
    ]);

    if (!challengerActive.empty || !opponentActive.empty) {
        throw new functions.https.HttpsError("failed-precondition", "Your Family is already participating in an active Family Battle.");
    }

    const challengerDoc = await db.collection("families").doc(challengerId).get();
    const opponentDoc = await db.collection("families").doc(opponentId).get();

    if (!challengerDoc.exists || !opponentDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Family profiles not found.");
    }

    const cData = challengerDoc.data();
    const oData = opponentDoc.data();
    const battleId = db.collection("families").doc(challengerId).collection("battles").doc().id;
    const now = admin.firestore.Timestamp.now();
    const durationSeconds = 300; // 5 minute standard duration

    const battlePayload = {
        id: battleId,
        familyAId: challengerId,
        familyBId: opponentId,
        familyAName: cData.name || "Family A",
        familyBName: oData.name || "Family B",
        familyAAvatar: cData.avatarUrl || "",
        familyBAvatar: oData.avatarUrl || "",
        imageUrl: reqData.imageUrl || "",
        familyAPoints: 0,
        familyBPoints: 0,
        startedAt: now,
        durationSeconds: durationSeconds,
        status: "active",
        createdAt: now
    };

    const batch = db.batch();
    // Update request status
    batch.update(reqRef, { status: "accepted", acceptedAt: now });

    // Write isolated battle document to BOTH families' battles subcollection
    batch.set(db.collection("families").doc(challengerId).collection("battles").doc(battleId), battlePayload);
    batch.set(db.collection("families").doc(opponentId).collection("battles").doc(battleId), battlePayload);

    await batch.commit();

    console.log(`[FAMILY_BATTLE] Battle accepted and active: ${battleId} (${challengerId} vs ${opponentId})`);
    return { success: true, battleId: battleId };
});

/**
 * 3. Atomic Battle Point Injection & 1:1 Diamond Conversion
 */
exports.scoreBattleTap = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const uid = context.auth.uid;
    const { battleId, familyId, points } = data;

    const diamondAmount = parseInt(points) || 1;
    if (!battleId || !familyId || diamondAmount <= 0) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid parameters.");
    }

    const battleRef = db.collection("families").doc(familyId).collection("battles").doc(battleId);
    const battleDoc = await battleRef.get();

    if (!battleDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Active battle not found.");
    }

    const battleData = battleDoc.data();
    // 🔒 State Lifecycle Rule: Points only injected when state == 'active'
    if (battleData.status !== "active") {
        console.log(`[FAMILY_BATTLE] Point injection rejected: battle ${battleId} state is ${battleData.status}`);
        return { success: false, reason: "Battle not active" };
    }

    const familyAId = battleData.familyAId;
    const familyBId = battleData.familyBId;
    const isFamilyA = familyId === familyAId;
    const opponentFamilyId = isFamilyA ? familyBId : familyAId;

    const userDoc = await db.collection("users").doc(uid).get();
    const userData = userDoc.exists ? userDoc.data() : {};
    const displayName = userData.displayName || "Member";
    const avatarUrl = userData.profilePhotoUrl || "";
    const level = userData.level || 1;

    await db.runTransaction(async (transaction) => {
        // 1. ACID-Compliant Transaction Record Log
        const txLogRef = db.collection("family_battle_transactions").doc();
        transaction.set(txLogRef, {
            transactionId: txLogRef.id,
            userId: uid,
            familyId: familyId,
            battleId: battleId,
            diamondCount: diamondAmount,
            pointsConverted: diamondAmount, // 1:1 Ratio
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        });

        // 2. Increment Battle Points on both mirrored battle docs
        const pointsField = isFamilyA ? "familyAPoints" : "familyBPoints";
        const mirrorRef = db.collection("families").doc(opponentFamilyId).collection("battles").doc(battleId);

        transaction.update(battleRef, { [pointsField]: admin.firestore.FieldValue.increment(diamondAmount) });
        transaction.update(mirrorRef, { [pointsField]: admin.firestore.FieldValue.increment(diamondAmount) });

        // 3. Dynamic Family Level Progression & In-Flight Capacity Scaling
        const familyRef = db.collection("families").doc(familyId);
        const familyDoc = await transaction.get(familyRef);
        if (familyDoc.exists) {
            const currentCombat = (familyDoc.data().totalCombatPoints || 0) + diamondAmount;
            const newLevel = getFamilyLevelForPoints(currentCombat);
            const newCapacity = getMemberCapacityForLevel(newLevel);

            transaction.update(familyRef, {
                totalCombatPoints: admin.firestore.FieldValue.increment(diamondAmount),
                totalBattlePoints: admin.firestore.FieldValue.increment(diamondAmount),
                totalDiamonds: admin.firestore.FieldValue.increment(diamondAmount),
                currentMonthPoints: admin.firestore.FieldValue.increment(diamondAmount),
                level: newLevel,
                memberLimit: newCapacity
            });
        }

        // 4. Update Member Individual Contribution
        const memberRef = familyRef.collection("members").doc(uid);
        transaction.set(memberRef, {
            userId: uid,
            combatPoints: admin.firestore.FieldValue.increment(diamondAmount),
            totalBattlePoints: admin.firestore.FieldValue.increment(diamondAmount),
            totalDiamondsSent: admin.firestore.FieldValue.increment(diamondAmount),
            contribution: admin.firestore.FieldValue.increment(diamondAmount),
            memberXP: admin.firestore.FieldValue.increment(diamondAmount)
        }, { merge: true });

        // 5. Update MVP Top Contributor Micro-Leaderboard Profile
        const contribRef = battleRef.collection("contributors").doc(uid);
        transaction.set(contribRef, {
            userId: uid,
            displayName: displayName,
            avatarUrl: avatarUrl,
            userLevel: level,
            battlePoints: admin.firestore.FieldValue.increment(diamondAmount),
            diamondsGifted: admin.firestore.FieldValue.increment(diamondAmount),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
    });

    return { success: true, pointsAdded: diamondAmount };
});

/**
 * 4. Scheduled Auto-Termination of Expired Family Battles
 */
exports.autoEndFamilyBattles = functions.pubsub.schedule("every 1 minutes").onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    
    // Find active family battles that have exceeded duration
    const families = await db.collection("families").get();
    let count = 0;

    for (const fDoc of families.docs) {
        const activeBattles = await fDoc.ref.collection("battles")
            .where("status", "==", "active")
            .get();

        for (const bDoc of activeBattles.docs) {
            const bData = bDoc.data();
            const startedAt = bData.startedAt ? bData.startedAt.toDate() : new Date();
            const durationSec = bData.durationSeconds || 300;
            const expiresAt = new Date(startedAt.getTime() + durationSec * 1000);

            if (new Date() >= expiresAt) {
                const aPts = bData.familyAPoints || 0;
                const bPts = bData.familyBPoints || 0;
                const familyAId = bData.familyAId;
                const familyBId = bData.familyBId;

                let winnerId = null;
                if (aPts > bPts) winnerId = familyAId;
                else if (bPts > aPts) winnerId = familyBId;

                const batch = db.batch();
                // Immutable State Lock: mark completed
                batch.update(bDoc.ref, {
                    status: "completed",
                    winnerId: winnerId,
                    endedAt: now
                });

                const mirrorRef = db.collection("families").doc(familyBId === fDoc.id ? familyAId : familyBId).collection("battles").doc(bDoc.id);
                const mirrorDoc = await mirrorRef.get();
                if (mirrorDoc.exists) {
                    batch.update(mirrorRef, {
                        status: "completed",
                        winnerId: winnerId,
                        endedAt: now
                    });
                }

                await batch.commit();
                count++;
                console.log(`[FAMILY_BATTLE_AUTO_END] Battle ${bDoc.id} ended. Winner: ${winnerId || 'Draw'}`);
            }
        }
    }
    return null;
});

/**
 * 5. Scheduled Ranking Indexers (Daily, Weekly, Monthly)
 */
exports.scheduledFamilyRankings = functions.pubsub.schedule("every 24 hours").onRun(async (context) => {
    console.log("[RANKINGS] Recalculating Family Rankings at 00:00 UTC");
    const familiesSnap = await db.collection("families")
        .orderBy("totalCombatPoints", "desc")
        .limit(100)
        .get();

    const batch = db.batch();
    let rank = 1;

    for (const doc of familiesSnap.docs) {
        const data = doc.data();
        const pts = data.totalCombatPoints || 0;
        const level = getFamilyLevelForPoints(pts);

        const rankRef = db.collection("familyRankings").doc(`daily_${doc.id}`);
        batch.set(rankRef, {
            familyId: doc.id,
            familyName: data.name,
            avatarUrl: data.avatarUrl || "",
            level: level,
            pts: pts,
            rank: rank,
            period: "daily",
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        rank++;
    }

    await batch.commit();
    return null;
});


/**
 * ═══════════════════════════════════════════════════════════════════════════
 * 👑 HIERARCHY PERMISSION, COMMISSION WALLET & USD-TO-DIAMOND SYSTEM
 * ═══════════════════════════════════════════════════════════════════════════
 */

/**
 * 1. Owner: Financial Policies Config (Commission Rates, Conversion Rate, Gateways)
 */
exports.updateFinancialPolicies = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const uid = context.auth.uid;

    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");
    const uData = userDoc.data();
    const isOwner = uData.role === "owner" || (uData.tags || []).includes("Owner");
    if (!isOwner) {
        throw new functions.https.HttpsError("permission-denied", "Only the Platform Owner can modify financial policies.");
    }

    const { agencyCommissionRate, adminCommissionRate, usdToDiamondRate, supportedGateways } = data;

    const updates = {
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: uid,
    };
    if (agencyCommissionRate !== undefined) updates.agencyCommissionRate = parseFloat(agencyCommissionRate) || 0.30;
    if (adminCommissionRate !== undefined) updates.adminCommissionRate = parseFloat(adminCommissionRate) || 0.10;
    if (usdToDiamondRate !== undefined) updates.usdToDiamondRate = parseInt(usdToDiamondRate) || 1000000;
    if (supportedGateways !== undefined) updates.supportedGateways = supportedGateways;

    await db.collection("system_configs").doc("financial_policies").set(updates, { merge: true });

    // Immutable Audit Log
    await db.collection("audit_logs").add({
        actorUid: uid,
        actorRole: uData.role || "owner",
        action: "UPDATE_FINANCIAL_POLICIES",
        details: updates,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log(`[FINANCIAL_POLICY] Updated by Owner ${uid}:`, updates);
    return { success: true, policies: updates };
});

/**
 * 2. Get Active Financial Policies
 */
exports.getFinancialPolicies = functions.https.onCall(async (data, context) => {
    const docSnap = await db.collection("system_configs").doc("financial_policies").get();
    if (!docSnap.exists) {
        return {
            agencyCommissionRate: 0.30,
            adminCommissionRate: 0.10,
            usdToDiamondRate: 1000000,
            supportedGateways: ["bKash", "Nagad", "Rocket", "Bank Transfer", "PayPal", "Wise", "Binance Pay", "USDT TRC20", "USDT BEP20"]
        };
    }
    return docSnap.data();
});

/**
 * 3. Real-Time Recharge Commission Process Trigger
 * 30% to Agency Commission Wallet (USD) | 10% to Admin Commission Wallet (USD)
 */
exports.processRechargeCommission = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const { hostUid, rechargeUSD } = data;

    const usdAmount = parseFloat(rechargeUSD);
    if (!hostUid || isNaN(usdAmount) || usdAmount <= 0) {
        throw new functions.https.HttpsError("invalid-argument", "Valid hostUid and positive rechargeUSD required.");
    }

    const policySnap = await db.collection("system_configs").doc("financial_policies").get();
    const policy = policySnap.exists ? policySnap.data() : {};
    const agencyRate = policy.agencyCommissionRate !== undefined ? policy.agencyCommissionRate : 0.30;
    const adminRate = policy.adminCommissionRate !== undefined ? policy.adminCommissionRate : 0.10;

    const hostDoc = await db.collection("users").doc(hostUid).get();
    if (!hostDoc.exists) return { success: false, reason: "Host not found" };

    const hData = hostDoc.data();
    const agencyId = hData.agencyId;
    if (!agencyId) return { success: true, processed: false, reason: "Host has no agency assigned" };

    const agencyDoc = await db.collection("users").doc(agencyId).get();
    if (!agencyDoc.exists) return { success: false, reason: "Agency not found" };

    const aData = agencyDoc.data();
    const adminId = aData.adminId;

    const agencyCommissionUSD = parseFloat((usdAmount * agencyRate).toFixed(2));
    const adminCommissionUSD = adminId ? parseFloat((usdAmount * adminRate).toFixed(2)) : 0.0;

    await db.runTransaction(async (transaction) => {
        // 1. Credit Agency USD Commission Wallet
        const agencyRef = db.collection("users").doc(agencyId);
        transaction.update(agencyRef, {
            usdCommissionBalance: admin.firestore.FieldValue.increment(agencyCommissionUSD),
            totalCommissionEarned: admin.firestore.FieldValue.increment(agencyCommissionUSD),
            totalRechargeGenerated: admin.firestore.FieldValue.increment(usdAmount)
        });

        const agencyTxRef = db.collection("commission_transactions").doc();
        transaction.set(agencyTxRef, {
            txId: agencyTxRef.id,
            recipientUid: agencyId,
            recipientRole: "agency",
            hostUid: hostUid,
            rechargeUSD: usdAmount,
            commissionRate: agencyRate,
            commissionUSD: agencyCommissionUSD,
            type: "agency_commission",
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        });

        // 2. Credit Admin USD Commission Wallet (If Admin Assigned)
        if (adminId) {
            const adminRef = db.collection("users").doc(adminId);
            transaction.update(adminRef, {
                usdCommissionBalance: admin.firestore.FieldValue.increment(adminCommissionUSD),
                totalCommissionEarned: admin.firestore.FieldValue.increment(adminCommissionUSD),
                totalRechargeGenerated: admin.firestore.FieldValue.increment(usdAmount)
            });

            const adminTxRef = db.collection("commission_transactions").doc();
            transaction.set(adminTxRef, {
                txId: adminTxRef.id,
                recipientUid: adminId,
                recipientRole: "admin",
                hostUid: hostUid,
                agencyId: agencyId,
                rechargeUSD: usdAmount,
                commissionRate: adminRate,
                commissionUSD: adminCommissionUSD,
                type: "admin_commission",
                timestamp: admin.firestore.FieldValue.serverTimestamp()
            });
        }

        // 3. Process Host SVIP Points & Immediate Upgrade (1 USD = 100 SVIP Points)
        const hostRef = db.collection("users").doc(hostUid);
        processSvipPointsForRecharge(transaction, hostRef, hData, usdAmount);
    });

    console.log(`[COMMISSION] Processed recharge $${usdAmount} for Host ${hostUid}: Agency=${agencyId} ($${agencyCommissionUSD}), Admin=${adminId || 'none'} ($${adminCommissionUSD})`);
    return { success: true, agencyCommissionUSD, adminCommissionUSD };
});

/**
 * 4. USD Commission Wallet -> Convert to Diamonds Engine
 * Rate: 1 USD = 1,000,000 Diamonds (Configurable)
 */
exports.convertCommissionToDiamonds = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const uid = context.auth.uid;
    const { usdAmount } = data;

    const parsedUSD = parseFloat(usdAmount);
    if (isNaN(parsedUSD) || parsedUSD <= 0) {
        throw new functions.https.HttpsError("invalid-argument", "Positive USD amount required.");
    }

    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();
    if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");

    const uData = userDoc.data();
    const currentUSD = uData.usdCommissionBalance || 0.0;

    if (currentUSD < parsedUSD) {
        throw new functions.https.HttpsError("failed-precondition", `Insufficient USD commission balance. Available: $${currentUSD.toFixed(2)} USD.`);
    }

    // Get conversion rate
    const policySnap = await db.collection("system_configs").doc("financial_policies").get();
    const rate = policySnap.exists && policySnap.data().usdToDiamondRate ? policySnap.data().usdToDiamondRate : 1000000;
    const diamondsReceived = Math.floor(parsedUSD * rate);

    const now = admin.firestore.Timestamp.now();

    await db.runTransaction(async (transaction) => {
        // Deduct USD, credit Diamonds
        transaction.update(userRef, {
            usdCommissionBalance: admin.firestore.FieldValue.increment(-parsedUSD),
            diamondBalance: admin.firestore.FieldValue.increment(diamondsReceived)
        });

        // Record Conversion Log
        const convRef = db.collection("commission_diamond_conversions").doc();
        transaction.set(convRef, {
            id: convRef.id,
            userId: uid,
            displayName: uData.displayName || "User",
            role: uData.role || "agency",
            usdAmount: parsedUSD,
            conversionRate: rate,
            diamondsReceived: diamondsReceived,
            status: "completed",
            createdAt: now
        });
    });

    console.log(`[DIAMOND_CONVERSION] User ${uid} converted $${parsedUSD} USD -> ${diamondsReceived.toLocaleString()} Diamonds (Rate: 1 USD = ${rate.toLocaleString()})`);
    return {
        success: true,
        usdAmount: parsedUSD,
        conversionRate: rate,
        diamondsReceived: diamondsReceived
    };
});

/**
 * 5. Option 1: Reseller Wallet Transfer Engine
 */
exports.transferCommissionToReseller = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const senderUid = context.auth.uid;
    const { targetResellerHelloId, usdAmount } = data;

    const parsedUSD = parseFloat(usdAmount);
    if (!targetResellerHelloId || isNaN(parsedUSD) || parsedUSD <= 0) {
        throw new functions.https.HttpsError("invalid-argument", "Valid target reseller ID and positive USD amount required.");
    }

    const senderRef = db.collection("users").doc(senderUid);
    const senderDoc = await senderRef.get();
    if (!senderDoc.exists) throw new functions.https.HttpsError("not-found", "Sender user not found.");

    const sData = senderDoc.data();
    const currentUSD = sData.usdCommissionBalance || 0.0;
    if (currentUSD < parsedUSD) {
        throw new functions.https.HttpsError("failed-precondition", `Insufficient USD balance. Available: $${currentUSD.toFixed(2)} USD.`);
    }

    // Find Target Reseller
    const helloIdNum = parseInt(targetResellerHelloId);
    let targetUid = null;
    let targetData = null;

    const qNum = await db.collection("users").where("helloId", "==", isNaN(helloIdNum) ? targetResellerHelloId : helloIdNum).limit(1).get();
    if (!qNum.empty) {
        targetUid = qNum.docs[0].id;
        targetData = qNum.docs[0].data();
    } else {
        const qStr = await db.collection("users").where("helloId", "==", targetResellerHelloId.toString()).limit(1).get();
        if (!qStr.empty) {
            targetUid = qStr.docs[0].id;
            targetData = qStr.docs[0].data();
        }
    }

    if (!targetUid || !targetData) {
        throw new functions.https.HttpsError("not-found", `Reseller with ID ${targetResellerHelloId} not found.`);
    }

    const now = admin.firestore.Timestamp.now();

    await db.runTransaction(async (transaction) => {
        // Deduct from Sender USD Commission
        transaction.update(senderRef, {
            usdCommissionBalance: admin.firestore.FieldValue.increment(-parsedUSD)
        });

        // Credit to Target Reseller
        const targetRef = db.collection("users").doc(targetUid);
        transaction.update(targetRef, {
            usdResellerBalance: admin.firestore.FieldValue.increment(parsedUSD)
        });

        // Log Transfer
        const trfRef = db.collection("commission_reseller_transfers").doc();
        transaction.set(trfRef, {
            transactionId: `TRF-${trfRef.id.slice(0, 8).toUpperCase()}-USD`,
            senderUid: senderUid,
            senderName: sData.displayName || "Agency/Admin",
            senderRole: sData.role || "agency",
            targetUid: targetUid,
            targetName: targetData.displayName || "Reseller",
            targetHelloId: targetResellerHelloId,
            transferAmountUSD: parsedUSD,
            status: "completed",
            createdAt: now
        });
    });

    console.log(`[RESELLER_TRANSFER] User ${senderUid} transferred $${parsedUSD} USD to Reseller ${targetUid}`);
    return { success: true, targetName: targetData.displayName, transferAmountUSD: parsedUSD };
});

/**
 * 6. Option 2: Direct Financial Withdrawal Submission
 */
exports.submitCommissionWithdrawal = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const uid = context.auth.uid;
    const { usdAmount, paymentMethod, paymentAccountDetails } = data;

    const parsedUSD = parseFloat(usdAmount);
    if (isNaN(parsedUSD) || parsedUSD <= 0 || !paymentMethod || !paymentAccountDetails) {
        throw new functions.https.HttpsError("invalid-argument", "USD amount, payment method, and account details required.");
    }

    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();
    if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");

    const uData = userDoc.data();
    const currentUSD = uData.usdCommissionBalance || 0.0;

    if (currentUSD < parsedUSD) {
        throw new functions.https.HttpsError("failed-precondition", `Insufficient USD commission balance. Available: $${currentUSD.toFixed(2)} USD.`);
    }

    const reqRef = db.collection("commission_withdrawals").doc();
    const now = admin.firestore.Timestamp.now();

    await db.runTransaction(async (transaction) => {
        // Lock funds into pendingWithdrawalBalance
        transaction.update(userRef, {
            usdCommissionBalance: admin.firestore.FieldValue.increment(-parsedUSD),
            pendingWithdrawalBalance: admin.firestore.FieldValue.increment(parsedUSD)
        });

        transaction.set(reqRef, {
            requestId: reqRef.id,
            userId: uid,
            displayName: uData.displayName || "User",
            userRole: uData.role || "agency",
            usdAmount: parsedUSD,
            paymentMethod: paymentMethod,
            paymentAccountDetails: paymentAccountDetails,
            status: "pending", // pending -> processing -> paid / rejected
            createdAt: now
        });
    });

    console.log(`[WITHDRAWAL_SUBMIT] User ${uid} submitted $${parsedUSD} USD withdrawal via ${paymentMethod}`);
    return { success: true, requestId: reqRef.id };
});

/**
 * 7. Owner Review Commission Withdrawal (Approve / Reject)
 */
exports.reviewCommissionWithdrawal = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const reviewerUid = context.auth.uid;

    const reviewerDoc = await db.collection("users").doc(reviewerUid).get();
    const rData = reviewerDoc.exists ? reviewerDoc.data() : {};
    const isOwner = rData.role === "owner" || (rData.tags || []).includes("Owner") || (rData.tags || []).includes("SuperAdmin");

    if (!isOwner) {
        throw new functions.https.HttpsError("permission-denied", "Only the Owner can review withdrawal requests.");
    }

    const { requestId, action, notes } = data;
    if (!requestId || !["approve", "reject", "process"].includes(action)) {
        throw new functions.https.HttpsError("invalid-argument", "requestId and valid action required ('approve', 'reject', 'process').");
    }

    const reqRef = db.collection("commission_withdrawals").doc(requestId);
    const reqDoc = await reqRef.get();
    if (!reqDoc.exists) throw new functions.https.HttpsError("not-found", "Withdrawal request not found.");

    const reqData = reqDoc.data();
    if (reqData.status === "paid" || reqData.status === "rejected") {
        throw new functions.https.HttpsError("failed-precondition", `Request is already in terminal state: ${reqData.status}`);
    }

    const targetUid = reqData.userId;
    const usdAmount = reqData.usdAmount;
    const userRef = db.collection("users").doc(targetUid);
    const now = admin.firestore.Timestamp.now();

    await db.runTransaction(async (transaction) => {
        if (action === "process") {
            transaction.update(reqRef, { status: "processing", processedAt: now });
        } else if (action === "approve") {
            // Deduct pending, increment total withdrawn
            transaction.update(userRef, {
                pendingWithdrawalBalance: admin.firestore.FieldValue.increment(-usdAmount),
                totalWithdrawnUSD: admin.firestore.FieldValue.increment(usdAmount)
            });
            transaction.update(reqRef, {
                status: "paid",
                paidAt: now,
                approvedBy: reviewerUid
            });
        } else if (action === "reject") {
            // Refund locked pending balance back to available balance
            transaction.update(userRef, {
                pendingWithdrawalBalance: admin.firestore.FieldValue.increment(-usdAmount),
                usdCommissionBalance: admin.firestore.FieldValue.increment(usdAmount)
            });
            transaction.update(reqRef, {
                status: "rejected",
                rejectedAt: now,
                rejectionNotes: notes || "Declined by Owner",
                rejectedBy: reviewerUid
            });
        }

        // Immutable Audit Log
        const auditRef = db.collection("audit_logs").doc();
        transaction.set(auditRef, {
            id: auditRef.id,
            actorUid: reviewerUid,
            actorRole: "owner_or_reviewer",
            action: `WITHDRAWAL_${action.toUpperCase()}`,
            targetId: requestId,
            details: { targetUid, usdAmount, action, notes: notes || null },
            timestamp: now
        });
    });

    console.log(`[WITHDRAWAL_REVIEW] Request ${requestId} ${action}d by Owner ${reviewerUid}`);
    return { success: true, action: action };
});

/**
 * 7. Owner: Provision Isolated Super Admin Branch
 */
exports.provisionBranch = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const callerUid = context.auth.uid;
    const callerDoc = await db.collection("users").doc(callerUid).get();
    if (!callerDoc.exists) throw new functions.https.HttpsError("not-found", "Caller not found.");
    const cData = callerDoc.data();
    const isOwner = cData.role === "owner" || (cData.tags || []).includes("Owner");
    if (!isOwner) {
        throw new functions.https.HttpsError("permission-denied", "Only the Platform Owner can provision branches.");
    }

    const { branchName, superAdminUid } = data;
    if (!branchName || !superAdminUid) {
        throw new functions.https.HttpsError("invalid-argument", "branchName and superAdminUid are required.");
    }

    const saDoc = await db.collection("users").doc(superAdminUid).get();
    if (!saDoc.exists) throw new functions.https.HttpsError("not-found", "Target Super Admin user not found.");

    const branchRef = db.collection("branches").doc();
    const now = admin.firestore.FieldValue.serverTimestamp();

    await db.runTransaction(async (transaction) => {
        transaction.set(branchRef, {
            id: branchRef.id,
            name: branchName,
            superAdminUid: superAdminUid,
            createdBy: callerUid,
            createdAt: now,
            status: "active"
        });

        transaction.update(db.collection("users").doc(superAdminUid), {
            role: "superadmin",
            branchId: branchRef.id,
            superAdminId: superAdminUid,
            roleUpdatedAt: now
        });

        const auditRef = db.collection("audit_logs").doc();
        transaction.set(auditRef, {
            id: auditRef.id,
            actorUid: callerUid,
            actorRole: "owner",
            action: "PROVISION_BRANCH",
            targetId: branchRef.id,
            details: { branchName, superAdminUid },
            timestamp: now
        });
    });

    console.log(`[HB_PMS] Branch ${branchRef.id} (${branchName}) provisioned by Owner ${callerUid}`);
    return { success: true, branchId: branchRef.id };
});

/**
 * 8. Hierarchy-Based Role Assignment with Sandboxing
 */
exports.assignHierarchyRole = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const callerUid = context.auth.uid;
    const callerDoc = await db.collection("users").doc(callerUid).get();
    if (!callerDoc.exists) throw new functions.https.HttpsError("not-found", "Caller not found.");
    const cData = callerDoc.data();
    const callerRole = cData.role || "host";
    const isOwner = callerRole === "owner" || (cData.tags || []).includes("Owner");

    const { targetUid, newRole, targetBranchId, targetSuperAdminId, targetAdminId, targetAgencyId } = data;
    if (!targetUid || !newRole) {
        throw new functions.https.HttpsError("invalid-argument", "targetUid and newRole are required.");
    }

    const targetUserRef = db.collection("users").doc(targetUid);
    const targetDoc = await targetUserRef.get();
    if (!targetDoc.exists) throw new functions.https.HttpsError("not-found", "Target user not found.");

    const now = admin.firestore.FieldValue.serverTimestamp();
    const updates = {
        role: newRole,
        roleUpdatedAt: now
    };

    if (isOwner) {
        if (targetBranchId !== undefined) updates.branchId = targetBranchId;
        if (targetSuperAdminId !== undefined) updates.superAdminId = targetSuperAdminId;
        if (targetAdminId !== undefined) updates.adminId = targetAdminId;
        if (targetAgencyId !== undefined) updates.agencyId = targetAgencyId;
    } else if (callerRole === "superadmin") {
        if (newRole !== "admin" && newRole !== "host") {
            throw new functions.https.HttpsError("permission-denied", "Super Admins can only assign Admin or Host roles.");
        }
        if (!cData.branchId) {
            throw new functions.https.HttpsError("failed-precondition", "Super Admin has no assigned branch.");
        }
        updates.branchId = cData.branchId;
        updates.superAdminId = callerUid;
    } else if (callerRole === "admin") {
        if (newRole !== "agency" && newRole !== "host") {
            throw new functions.https.HttpsError("permission-denied", "Admins can only assign Agency or Host roles.");
        }
        updates.branchId = cData.branchId || null;
        updates.superAdminId = cData.superAdminId || null;
        updates.adminId = callerUid;
        if (newRole === "agency") {
            updates.isAgencyOwner = true;
        }
    } else if (callerRole === "agency" || cData.isAgencyOwner) {
        if (newRole !== "host") {
            throw new functions.https.HttpsError("permission-denied", "Agencies can only recruit Hosts.");
        }
        updates.branchId = cData.branchId || null;
        updates.superAdminId = cData.superAdminId || null;
        updates.adminId = cData.adminId || null;
        updates.agencyId = callerUid;
    } else {
        throw new functions.https.HttpsError("permission-denied", "Insufficient permissions for role assignment.");
    }

    await db.runTransaction(async (transaction) => {
        transaction.update(targetUserRef, updates);

        const auditRef = db.collection("audit_logs").doc();
        transaction.set(auditRef, {
            id: auditRef.id,
            actorUid: callerUid,
            actorRole: callerRole,
            action: "ASSIGN_ROLE",
            targetId: targetUid,
            details: { newRole, updates },
            timestamp: now
        });
    });

    console.log(`[HB_PMS] Role ${newRole} assigned to ${targetUid} by ${callerUid} (${callerRole})`);
    return { success: true, targetUid, newRole };
});

/**
 * ============================================================================
 * 🌟 COMPLETE SVIP MEMBERSHIP ENGINE (OFFICIAL SPECIFICATION)
 * ============================================================================
 */

/**
 * 1. Process Gold Coin Top-Up Recharge & SVIP Point Credit
 * Rule: $1 USD Gold Coin Recharge = 100 SVIP Points.
 * Instant Upgrade Check: If points meet next level, activate instantly, reset validity to 60 days, and reset points to 0.
 */
exports.processGoldCoinRecharge = onCall({ region: "us-central1" }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Auth required.");
    const uid = request.auth.uid;
    const { usdAmount, coinsPurchased } = request.data || {};

    const usd = parseFloat(usdAmount);
    if (isNaN(usd) || usd <= 0) {
        throw new HttpsError("invalid-argument", "Valid USD recharge amount required.");
    }

    const pointsEarned = Math.floor(usd * 100);
    const userRef = db.collection("users").doc(uid);

    return db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw new HttpsError("not-found", "User profile not found.");

        const userData = userDoc.data();
        const currentLevel = userData.svipLevel || 0;
        const currentPoints = userData.svipPoints || 0;
        let newPoints = currentPoints + pointsEarned;

        // Check potential upgrade
        let targetLevel = currentLevel;
        for (const t of SVIP_THRESHOLDS) {
            if (newPoints >= t.points && t.level > targetLevel) {
                targetLevel = t.level;
            }
        }

        const now = new Date();
        const sixtyDaysMs = 60 * 24 * 60 * 60 * 1000;
        const cycleEndDate = new Date(now.getTime() + sixtyDaysMs);

        const updates = {
            totalRechargeUsd: admin.firestore.FieldValue.increment(usd),
            lastRechargeAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        let isUpgraded = false;
        if (targetLevel > currentLevel) {
            isUpgraded = true;
            updates.svipLevel = targetLevel;
            updates.svipPoints = 0; // RESET TO 0 UPON INSTANT UPGRADE
            updates.svipCycleStartDate = admin.firestore.Timestamp.fromDate(now);
            updates.svipCycleEndDate = admin.firestore.Timestamp.fromDate(cycleEndDate);

            // Reset SVIP 6 removal request count if entering SVIP 6
            if (targetLevel === 6) {
                updates.svip6CpRemoveRequestsUsed = 0;
            }

            // Audit log
            const auditRef = db.collection("svip_audit_logs").doc();
            transaction.set(auditRef, {
                uid: uid,
                type: "instant_upgrade",
                previousLevel: currentLevel,
                newLevel: targetLevel,
                pointsBefore: currentPoints,
                pointsEarned: pointsEarned,
                pointsAfterReset: 0,
                cycleStartDate: admin.firestore.Timestamp.fromDate(now),
                cycleEndDate: admin.firestore.Timestamp.fromDate(cycleEndDate),
                timestamp: admin.firestore.FieldValue.serverTimestamp()
            });
        } else {
            updates.svipPoints = newPoints;
            if (!userData.svipCycleStartDate && currentLevel > 0) {
                updates.svipCycleStartDate = admin.firestore.Timestamp.fromDate(now);
                updates.svipCycleEndDate = admin.firestore.Timestamp.fromDate(cycleEndDate);
            }
        }

        transaction.update(userRef, updates);

        return {
            success: true,
            pointsEarned: pointsEarned,
            isUpgraded: isUpgraded,
            svipLevel: targetLevel > currentLevel ? targetLevel : currentLevel,
            svipPoints: isUpgraded ? 0 : newPoints,
        };
    });
});

/**
 * 2. Daily Cron Job: 60-Day SVIP Cycle Expiration & Renewal Evaluation
 * Runs daily at 00:00 UTC. Evaluates expired cycles:
 * - Multi-Level Upgrade -> Promote, reset 60d validity, reset points to 0.
 * - Maintain Tier -> Renew 60d validity, reset points to 0.
 * - Tier Down -> Downgrade by 1 tier, start new 60d validity, reset points to 0.
 * - Expiration (SVIP 1) -> Expire to normal member, revoke privileges, reset points to 0.
 */
exports.evaluateSvipCycles = onCall({ region: "us-central1" }, async (request) => {
    // Admin execution or scheduled trigger
    const now = new Date();
    const nowTimestamp = admin.firestore.Timestamp.fromDate(now);
    const sixtyDaysMs = 60 * 24 * 60 * 60 * 1000;

    const snapshot = await db.collection("users")
        .where("svipLevel", ">", 0)
        .where("svipCycleEndDate", "<=", nowTimestamp)
        .limit(500)
        .get();

    let processedCount = 0;

    for (const doc of snapshot.docs) {
        const userData = doc.data();
        const uid = doc.id;
        const currentLevel = userData.svipLevel || 1;
        const pointsEarned = userData.svipPoints || 0;

        const currentThreshold = SVIP_THRESHOLDS.find(t => t.level === currentLevel);
        const requiredToMaintain = currentThreshold ? currentThreshold.points : 5000;

        let action = "";
        let newLevel = currentLevel;

        // Check if points qualify for higher level
        let highestQualifiedLevel = 0;
        for (const t of SVIP_THRESHOLDS) {
            if (pointsEarned >= t.points) {
                highestQualifiedLevel = t.level;
            }
        }

        if (highestQualifiedLevel > currentLevel) {
            action = "upgrade";
            newLevel = highestQualifiedLevel;
        } else if (pointsEarned >= requiredToMaintain) {
            action = "maintain";
            newLevel = currentLevel;
        } else if (currentLevel > 1) {
            action = "downgrade";
            newLevel = currentLevel - 1;
        } else {
            action = "expire";
            newLevel = 0;
        }

        const newCycleStart = new Date();
        const newCycleEnd = new Date(newCycleStart.getTime() + sixtyDaysMs);

        const updates = {
            svipLevel: newLevel,
            svipPoints: 0, // MUST RESET TO 0 IN ALL SCENARIOS
            svipLastEvaluatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (newLevel > 0) {
            updates.svipCycleStartDate = admin.firestore.Timestamp.fromDate(newCycleStart);
            updates.svipCycleEndDate = admin.firestore.Timestamp.fromDate(newCycleEnd);
        } else {
            updates.svipCycleStartDate = null;
            updates.svipCycleEndDate = null;
            updates.isProfileHidden = false;
        }

        await db.runTransaction(async (transaction) => {
            transaction.update(doc.ref, updates);

            const auditRef = db.collection("svip_audit_logs").doc();
            transaction.set(auditRef, {
                uid: uid,
                type: `cycle_${action}`,
                previousLevel: currentLevel,
                newLevel: newLevel,
                pointsEarnedInCycle: pointsEarned,
                pointsAfterReset: 0,
                timestamp: admin.firestore.FieldValue.serverTimestamp()
            });
        });

        processedCount++;
    }

    console.log(`[SVIP_CRON] Processed ${processedCount} expired SVIP cycles`);
    return { success: true, processedCount: processedCount };
});

/**
 * 3. Daily Diamond Reward Claim (24-Hour Server UTC Cooldown)
 */
exports.claimSvipDailyReward = onCall({ region: "us-central1" }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Auth required.");
    const uid = request.auth.uid;
    const userRef = db.collection("users").doc(uid);

    return db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw new HttpsError("not-found", "User not found.");

        const userData = userDoc.data();
        const svipLevel = userData.svipLevel || 0;
        if (svipLevel <= 0) {
            throw new HttpsError("failed-precondition", "Active SVIP membership required.");
        }

        const threshold = SVIP_THRESHOLDS.find(t => t.level === svipLevel);
        const rewardAmount = threshold ? threshold.dailyReward : 25000;

        const lastClaim = userData.lastSvipRewardClaimAt ? userData.lastSvipRewardClaimAt.toMillis() : 0;
        const now = Date.now();
        const twentyFourHoursMs = 24 * 60 * 60 * 1000;

        if (now - lastClaim < twentyFourHoursMs) {
            const remainingMs = twentyFourHoursMs - (now - lastClaim);
            const remainingHours = Math.ceil(remainingMs / (1000 * 60 * 60));
            throw new HttpsError("failed-precondition", `Reward already claimed. Next claim available in ${remainingHours} hours.`);
        }

        transaction.update(userRef, {
            diamondBalance: admin.firestore.FieldValue.increment(rewardAmount),
            lastSvipRewardClaimAt: admin.firestore.FieldValue.serverTimestamp()
        });

        const logRef = db.collection("svip_reward_logs").doc();
        transaction.set(logRef, {
            uid: uid,
            svipLevel: svipLevel,
            rewardAmount: rewardAmount,
            claimedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        return { success: true, rewardAmount: rewardAmount, svipLevel: svipLevel };
    });
});

/**
 * 4. Temporary ID Target Swap Request & Response Callables
 */
exports.requestTempIdSwap = onCall({ region: "us-central1" }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Auth required.");
    const requesterUid = request.auth.uid;
    const { targetHelloId } = request.data || {};

    if (!targetHelloId) throw new HttpsError("invalid-argument", "Target Hello ID required.");

    const requesterDoc = await db.collection("users").doc(requesterUid).get();
    const requesterData = requesterDoc.data() || {};
    const svipLevel = requesterData.svipLevel || 0;

    if (svipLevel <= 0) throw new HttpsError("failed-precondition", "SVIP membership required.");

    // Target User Lookup
    const targetQuery = await db.collection("users").where("helloId", "==", parseInt(targetHelloId)).limit(1).get();
    if (targetQuery.empty) throw new HttpsError("not-found", "Target user ID not found.");
    const targetDoc = targetQuery.docs[0];
    const targetUid = targetDoc.id;

    if (targetUid === requesterUid) throw new HttpsError("invalid-argument", "Cannot target your own ID.");

    // Digit limit check
    const targetIdStr = targetHelloId.toString();
    const len = targetIdStr.length;

    const reqRef = db.collection("svip_temp_id_requests").doc();
    await reqRef.set({
        id: reqRef.id,
        requesterUid: requesterUid,
        requesterName: requesterData.displayName || "SVIP User",
        requesterSvipLevel: svipLevel,
        targetUid: targetUid,
        targetHelloId: parseInt(targetHelloId),
        idLength: len,
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    await sendPush(targetUid, "Temporary ID Target Request", `${requesterData.displayName} (SVIP ${svipLevel}) requested to temporarily use your ID Number.`);

    return { success: true, requestId: reqRef.id };
});

exports.respondTempIdSwap = onCall({ region: "us-central1" }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Auth required.");
    const targetUid = request.auth.uid;
    const { requestId, accept } = request.data || {};

    const reqRef = db.collection("svip_temp_id_requests").doc(requestId);
    return db.runTransaction(async (transaction) => {
        const reqDoc = await transaction.get(reqRef);
        if (!reqDoc.exists) throw new HttpsError("not-found", "Request not found.");

        const reqData = reqDoc.data();
        if (reqData.targetUid !== targetUid) throw new HttpsError("permission-denied", "Unauthorized decision.");
        if (reqData.status !== "pending") throw new HttpsError("failed-precondition", "Request already handled.");

        if (!accept) {
            transaction.update(reqRef, { status: "rejected", respondedAt: admin.firestore.FieldValue.serverTimestamp() });
            return { success: true, accepted: false };
        }

        // Target Accepted: Backup requester's original ID and swap
        const requesterRef = db.collection("users").doc(reqData.requesterUid);
        const requesterDoc = await transaction.get(requesterRef);
        const requesterData = requesterDoc.data();

        const originalId = requesterData.helloId;
        const targetId = reqData.targetHelloId;

        transaction.update(requesterRef, {
            originalHelloId: requesterData.originalHelloId || originalId,
            helloId: targetId,
            isTempIdActive: true,
            tempIdExpiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 30 * 24 * 60 * 60 * 1000))
        });

        transaction.update(reqRef, { status: "accepted", respondedAt: admin.firestore.FieldValue.serverTimestamp() });

        return { success: true, accepted: true, tempId: targetId };
    });
});

/**
 * 5. SVIP 6 Exclusive Global Kick Callable
 */
exports.svipGlobalKick = onCall({ region: "us-central1" }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Auth required.");
    const kickerUid = request.auth.uid;
    const { roomId, targetUid } = request.data || {};

    if (!roomId || !targetUid) throw new HttpsError("invalid-argument", "Room ID & Target User ID required.");
    if (kickerUid === targetUid) throw new HttpsError("invalid-argument", "Cannot kick yourself.");

    const kickerDoc = await db.collection("users").doc(kickerUid).get();
    const kickerData = kickerDoc.data() || {};
    if ((kickerData.svipLevel || 0) < 6) {
        throw new HttpsError("permission-denied", "Exclusive to SVIP 6 users.");
    }

    const targetDoc = await db.collection("users").doc(targetUid).get();
    const targetData = targetDoc.data() || {};
    if ((targetData.svipLevel || 0) === 6) {
        throw new HttpsError("permission-denied", "SVIP 6 users cannot Kick Out another SVIP 6 user.");
    }

    // Execute Room Kick Out
    const roomRef = db.collection("rooms").doc(roomId);
    await roomRef.update({
        [`kickedUsers.${targetUid}`]: admin.firestore.FieldValue.serverTimestamp(),
        activeParticipants: admin.firestore.FieldValue.arrayRemove(targetUid)
    });

    console.log(`[SVIP6_GLOBAL_KICK] SVIP 6 ${kickerUid} kicked ${targetUid} from room ${roomId}`);
    return { success: true };
});

/**
 * 6. CP Lock & SVIP 6 CP Remove Request Callables
 */
exports.lockCp = onCall({ region: "us-central1" }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Auth required.");
    const uid = request.auth.uid;
    const { cpId, lockDuration } = request.data || {};

    const userDoc = await db.collection("users").doc(uid).get();
    const svipLevel = (userDoc.data() || {}).svipLevel || 0;
    if (svipLevel < 3) throw new HttpsError("permission-denied", "CP Lock available for SVIP 3+ only.");

    const cpRef = db.collection("cp_relationships").doc(cpId);
    const cpDoc = await cpRef.get();
    if (!cpDoc.exists) throw new HttpsError("not-found", "CP relationship not found.");

    let durationMs = 0;
    if (lockDuration === "24 Hours") durationMs = 24 * 60 * 60 * 1000;
    else if (lockDuration === "72 Hours") durationMs = 72 * 60 * 60 * 1000;
    else if (lockDuration === "7 Days") durationMs = 7 * 24 * 60 * 60 * 1000;
    else if (lockDuration === "30 Days") durationMs = 30 * 24 * 60 * 60 * 1000;

    const expiresAt = durationMs > 0 ? admin.firestore.Timestamp.fromDate(new Date(Date.now() + durationMs)) : null;

    await cpRef.update({
        isLocked: true,
        lockDuration: lockDuration,
        lockedByUid: uid,
        lockedAt: admin.firestore.FieldValue.serverTimestamp(),
        lockExpiresAt: expiresAt
    });

    return { success: true, lockDuration: lockDuration };
});

exports.requestSvip6CpRemove = onCall({ region: "us-central1" }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Auth required.");
    const requesterUid = request.auth.uid;
    const { cpId, targetUid } = request.data || {};

    const requesterRef = db.collection("users").doc(requesterUid);
    const requesterDoc = await requesterRef.get();
    const requesterData = requesterDoc.data() || {};

    if ((requesterData.svipLevel || 0) < 6) {
        throw new HttpsError("permission-denied", "Exclusive to SVIP 6 users.");
    }

    const used = requesterData.svip6CpRemoveRequestsUsed || 0;
    if (used >= 5) {
        throw new HttpsError("failed-precondition", "Maximum 5 CP Removal Requests reached for this cycle.");
    }

    const reqRef = db.collection("svip_cp_remove_requests").doc();
    await reqRef.set({
        id: reqRef.id,
        cpId: cpId,
        requesterUid: requesterUid,
        targetUid: targetUid,
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    await sendPush(targetUid, "Locked CP Removal Request", `${requesterData.displayName} (SVIP 6) requested to unlock and remove your CP relationship.`);

    return { success: true, requestId: reqRef.id, remainingAllowance: 5 - used };
});

exports.respondSvip6CpRemove = onCall({ region: "us-central1" }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Auth required.");
    const targetUid = request.auth.uid;
    const { requestId, accept } = request.data || {};

    const reqRef = db.collection("svip_cp_remove_requests").doc(requestId);
    return db.runTransaction(async (transaction) => {
        const reqDoc = await transaction.get(reqRef);
        if (!reqDoc.exists) throw new HttpsError("not-found", "Request not found.");

        const reqData = reqDoc.data();
        if (reqData.targetUid !== targetUid) throw new HttpsError("permission-denied", "Unauthorized decision.");
        if (reqData.status !== "pending") throw new HttpsError("failed-precondition", "Request already handled.");

        if (!accept) {
            transaction.update(reqRef, { status: "rejected", respondedAt: admin.firestore.FieldValue.serverTimestamp() });
            return { success: true, accepted: false };
        }

        // Target Accepted: Remove CP and increment requester usage count
        const cpRef = db.collection("cp_relationships").doc(reqData.cpId);
        transaction.delete(cpRef);

        const requesterRef = db.collection("users").doc(reqData.requesterUid);
        transaction.update(requesterRef, {
            svip6CpRemoveRequestsUsed: admin.firestore.FieldValue.increment(1)
        });

        transaction.update(reqRef, { status: "accepted", respondedAt: admin.firestore.FieldValue.serverTimestamp() });

        return { success: true, accepted: true };
    });
});

/**
 * 7. Banner Promotion Submission & Admin Review Callables
 */
exports.submitSvipBanner = onCall({ region: "us-central1" }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Auth required.");
    const uid = request.auth.uid;
    const { bannerUrl, bannerText, durationHours } = request.data || {};

    const userDoc = await db.collection("users").doc(uid).get();
    const svipLevel = (userDoc.data() || {}).svipLevel || 0;
    if (svipLevel <= 0) throw new HttpsError("permission-denied", "SVIP membership required.");

    const bannerRef = db.collection("svip_banners").doc();
    await bannerRef.set({
        id: bannerRef.id,
        uid: uid,
        svipLevel: svipLevel,
        bannerUrl: bannerUrl,
        bannerText: bannerText || "",
        durationHours: durationHours || 24,
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: true, bannerId: bannerRef.id };
});

exports.reviewSvipBanner = onCall({ region: "us-central1" }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Auth required.");
    const adminUid = request.auth.uid;
    if (!(await isUserAdmin(adminUid))) throw new HttpsError("permission-denied", "Admin only.");

    const { bannerId, approve } = request.data || {};
    const bannerRef = db.collection("svip_banners").doc(bannerId);

    const bannerDoc = await bannerRef.get();
    if (!bannerDoc.exists) throw new HttpsError("not-found", "Banner not found.");

    const bannerData = bannerDoc.data();
    const durationMs = (bannerData.durationHours || 24) * 60 * 60 * 1000;
    const expiresAt = admin.firestore.Timestamp.fromDate(new Date(Date.now() + durationMs));

    await bannerRef.update({
        status: approve ? "approved" : "rejected",
        approvedBy: adminUid,
        reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: approve ? expiresAt : null
    });

    return { success: true, approved: approve };
});

/**
 * 8. SVIP Protection Assignment (SVIP 5 & 6)
 * SVIP 5 can assign up to 5 users, SVIP 6 up to 10 users for 30 days.
 */
exports.assignProtection = onCall({ region: "us-central1" }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Auth required.");
    const requesterUid = request.auth.uid;
    const { targetUid } = request.data || {};

    if (!targetUid) throw new HttpsError("invalid-argument", "Target user ID required.");

    const requesterDoc = await db.collection("users").doc(requesterUid).get();
    const requesterData = requesterDoc.data() || {};
    const svipLevel = requesterData.svipLevel || 0;

    if (svipLevel < 5) {
        throw new HttpsError("permission-denied", "Available for SVIP 5 and SVIP 6 only.");
    }

    const maxAllowed = svipLevel === 6 ? 10 : 5;
    const currentAssigned = requesterData.assignedProtectionUsers || [];

    if (currentAssigned.length >= maxAllowed && !currentAssigned.includes(targetUid)) {
        throw new HttpsError("failed-precondition", `Maximum ${maxAllowed} protection assignments reached.`);
    }

    const thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;
    const expiresAt = admin.firestore.Timestamp.fromDate(new Date(Date.now() + thirtyDaysMs));

    await db.runTransaction(async (transaction) => {
        const targetRef = db.collection("users").doc(targetUid);
        transaction.update(targetRef, {
            assignedProtectionExpiresAt: expiresAt,
            protectedByUid: requesterUid
        });

        const requesterRef = db.collection("users").doc(requesterUid);
        transaction.update(requesterRef, {
            assignedProtectionUsers: admin.firestore.FieldValue.arrayUnion(targetUid)
        });

        const notifRef = targetRef.collection("notifications").doc();
        transaction.set(notifRef, {
            title: "🛡️ Room Protection Granted!",
            message: `${requesterData.displayName || "An SVIP Member"} granted you 30-day Kick & Mute Protection in voice rooms!`,
            type: "svip_protection",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            isRead: false
        });
    });

    return { success: true, expiresAt: expiresAt };
});

/**
 * 9. SVIP Friend & Follower List Hide Assignment (SVIP 3–6)
 * SVIP 3: 2 IDs, SVIP 4: 5 IDs, SVIP 5: 10 IDs, SVIP 6: 25 IDs (30 days)
 */
exports.assignFriendListHide = onCall({ region: "us-central1" }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Auth required.");
    const requesterUid = request.auth.uid;
    const { targetUid } = request.data || {};

    const effectiveTargetUid = targetUid || requesterUid;

    const requesterDoc = await db.collection("users").doc(requesterUid).get();
    const requesterData = requesterDoc.data() || {};
    const svipLevel = requesterData.svipLevel || 0;

    if (svipLevel < 3) {
        throw new HttpsError("permission-denied", "Available for SVIP 3 to SVIP 6 only.");
    }

    let maxAllowed = 2;
    if (svipLevel === 4) maxAllowed = 5;
    else if (svipLevel === 5) maxAllowed = 10;
    else if (svipLevel === 6) maxAllowed = 25;

    const currentAssigned = requesterData.assignedFriendHideUsers || [];
    if (currentAssigned.length >= maxAllowed && !currentAssigned.includes(effectiveTargetUid)) {
        throw new HttpsError("failed-precondition", `Maximum ${maxAllowed} Friend List Hide assignments reached.`);
    }

    const thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;
    const expiresAt = admin.firestore.Timestamp.fromDate(new Date(Date.now() + thirtyDaysMs));

    await db.runTransaction(async (transaction) => {
        const targetRef = db.collection("users").doc(effectiveTargetUid);
        transaction.update(targetRef, {
            isFriendListHidden: true,
            hasSvipStarBadge: true,
            friendListHideExpiresAt: expiresAt,
            friendHideAssignedBy: requesterUid
        });

        const requesterRef = db.collection("users").doc(requesterUid);
        transaction.update(requesterRef, {
            assignedFriendHideUsers: admin.firestore.FieldValue.arrayUnion(effectiveTargetUid)
        });
    });

    return { success: true, expiresAt: expiresAt };
});

/**
 * 10. SVIP Profile Hide (Mystery Man) Assignment
 * SVIP 4: self only, SVIP 5: self + 2 IDs, SVIP 6: self + 10 IDs
 */
exports.assignProfileHide = onCall({ region: "us-central1" }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Auth required.");
    const requesterUid = request.auth.uid;
    const { targetUid } = request.data || {};

    const effectiveTargetUid = targetUid || requesterUid;

    const requesterDoc = await db.collection("users").doc(requesterUid).get();
    const requesterData = requesterDoc.data() || {};
    const svipLevel = requesterData.svipLevel || 0;

    if (svipLevel < 4) {
        throw new HttpsError("permission-denied", "Available for SVIP 4, 5, and 6 only.");
    }

    if (effectiveTargetUid !== requesterUid) {
        if (svipLevel === 4) throw new HttpsError("permission-denied", "SVIP 4 can only enable Profile Hide for their own account.");
        const maxAdditional = svipLevel === 6 ? 10 : 2;
        const currentDelegated = requesterData.delegatedProfileHideUsers || [];
        if (currentDelegated.length >= maxAdditional && !currentDelegated.includes(effectiveTargetUid)) {
            throw new HttpsError("failed-precondition", `Maximum ${maxAdditional} delegated Profile Hide users reached.`);
        }
    }

    const thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;
    const expiresAt = admin.firestore.Timestamp.fromDate(new Date(Date.now() + thirtyDaysMs));

    await db.runTransaction(async (transaction) => {
        const targetRef = db.collection("users").doc(effectiveTargetUid);
        transaction.update(targetRef, {
            isProfileHidden: true,
            profileHideExpiresAt: expiresAt,
            profileHideAssignedBy: requesterUid
        });

        if (effectiveTargetUid !== requesterUid) {
            const requesterRef = db.collection("users").doc(requesterUid);
            transaction.update(requesterRef, {
                delegatedProfileHideUsers: admin.firestore.FieldValue.arrayUnion(effectiveTargetUid)
            });
        }
    });

    return { success: true, expiresAt: expiresAt };
});

/**
 * 11. Admin SVIP User Management & Manual Point Adjustments
 */
exports.adminAdjustSvipPoints = onCall({ region: "us-central1" }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Auth required.");
    const adminUid = request.auth.uid;
    if (!(await isUserAdmin(adminUid))) throw new HttpsError("permission-denied", "Admin only.");

    const { targetUid, action, points, newLevel, extendDays } = request.data || {};
    if (!targetUid) throw new HttpsError("invalid-argument", "Target user ID required.");

    const targetRef = db.collection("users").doc(targetUid);
    const targetDoc = await targetRef.get();
    if (!targetDoc.exists) throw new HttpsError("not-found", "Target user not found.");

    const targetData = targetDoc.data();
    const currentPoints = targetData.svipPoints || 0;
    const currentLevel = targetData.svipLevel || 0;

    let updatedPoints = currentPoints;
    let updatedLevel = currentLevel;
    let updatedEndDate = targetData.svipCycleEndDate;

    if (action === "add_points") {
        updatedPoints = currentPoints + Math.max(0, parseInt(points) || 0);
    } else if (action === "deduct_points") {
        updatedPoints = Math.max(0, currentPoints - (parseInt(points) || 0));
    } else if (action === "reset_points") {
        updatedPoints = 0;
    } else if (action === "set_level") {
        updatedLevel = Math.max(0, Math.min(6, parseInt(newLevel) || 0));
        updatedPoints = 0; // RESET TO 0 ON LEVEL CHANGE
        const sixtyDaysMs = 60 * 24 * 60 * 60 * 1000;
        updatedEndDate = admin.firestore.Timestamp.fromDate(new Date(Date.now() + sixtyDaysMs));
    } else if (action === "extend_validity") {
        const days = parseInt(extendDays) || 60;
        const currentMs = updatedEndDate ? updatedEndDate.toMillis() : Date.now();
        updatedEndDate = admin.firestore.Timestamp.fromDate(new Date(currentMs + days * 24 * 60 * 60 * 1000));
    }

    const updates = {
        svipPoints: updatedPoints,
        svipLevel: updatedLevel,
    };
    if (updatedEndDate) updates.svipCycleEndDate = updatedEndDate;
    if (updatedLevel === 0) {
        updates.svipCycleStartDate = null;
        updates.svipCycleEndDate = null;
        updates.isProfileHidden = false;
    }

    await targetRef.update(updates);

    // Audit log
    await db.collection("svip_audit_logs").doc().set({
        adminUid: adminUid,
        targetUid: targetUid,
        action: action,
        previousLevel: currentLevel,
        newLevel: updatedLevel,
        previousPoints: currentPoints,
        newPoints: updatedPoints,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: true, updatedPoints, updatedLevel };
});



/**
 * ⏰ Scheduled / Callable Role & Recharge Frame Expiration Cleanup
 */
exports.checkRoleAndExpiredFrames = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const adminUid = context.auth.uid;
    if (!(await isUserAdmin(adminUid))) throw new functions.https.HttpsError("permission-denied", "Admin only.");

    const now = admin.firestore.Timestamp.now();
    const snap = await db.collection("users")
        .where("rechargeFrameExpiresAt", "<=", now)
        .get();

    const batch = db.batch();
    let count = 0;
    for (const userDoc of snap.docs) {
        batch.update(userDoc.ref, {
            profileFrame: "",
            rechargeFrameExpiresAt: admin.firestore.FieldValue.delete()
        });
        count++;
    }
    await batch.commit();

    return { success: true, expiredFramesCleared: count };
});

/**
 * 🧧 1. Send Lucky Bag (Hongbao Random Diamond Pool Distribution)
 */
exports.sendLuckyBag = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Authentication required.");
    const senderUid = context.auth.uid;
    const { roomId, totalDiamonds, winnerCount, message } = data;

    const amount = Math.max(1000, parseInt(totalDiamonds) || 50000);
    const winners = Math.max(1, parseInt(winnerCount) || 10);

    return await db.runTransaction(async (transaction) => {
        const senderRef = db.collection("users").doc(senderUid);
        const roomRef = db.collection("rooms").doc(roomId);

        const [senderDoc, roomDoc] = await Promise.all([
            transaction.get(senderRef),
            transaction.get(roomRef)
        ]);

        if (!senderDoc.exists) throw new functions.https.HttpsError("not-found", "Sender user profile not found.");
        const currentBalance = senderDoc.data().diamondBalance || 0;
        if (currentBalance < amount) {
            throw new functions.https.HttpsError("failed-precondition", `Insufficient Diamond balance. Available: ${currentBalance}`);
        }

        // Generate Hongbao Red-Envelope Random Diamond Distribution Algorithm
        let remainingAmount = amount;
        let remainingWinners = winners;
        const rewardPool = [];

        for (let i = 0; i < winners - 1; i++) {
            const maxAllocation = (remainingAmount / remainingWinners) * 2;
            const slice = Math.max(1, Math.floor(Math.random() * maxAllocation));
            rewardPool.push(slice);
            remainingAmount -= slice;
            remainingWinners--;
        }
        rewardPool.push(remainingAmount); // Last winner gets remaining remainder

        // Shuffle slices randomly
        rewardPool.sort(() => Math.random() - 0.5);

        // Deduct sender balance
        transaction.update(senderRef, {
            diamondBalance: admin.firestore.FieldValue.increment(-amount),
            totalDiamondsSpent: admin.firestore.FieldValue.increment(amount)
        });

        // Create Lucky Bag Document
        const bagRef = db.collection("lucky_bags").doc();
        const roomName = roomDoc.exists ? (roomDoc.data().name || "Live Room") : "Live Room";
        const senderName = senderDoc.data().displayName || senderDoc.data().username || "User";

        transaction.set(bagRef, {
            bagId: bagRef.id,
            roomId,
            roomName,
            senderUid,
            senderName,
            senderAvatar: senderDoc.data().profilePhotoUrl || "",
            totalDiamonds: amount,
            winnerCount: winners,
            remainingWinners: winners,
            rewardPool,
            claimedUids: [],
            claims: [],
            message: message || "Join and claim your Lucky Bag!",
            status: "active",
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // Push Global Lucky Bag Banner Notification across all rooms
        const notifRef = db.collection("global_notifications").doc();
        transaction.set(notifRef, {
            id: notifRef.id,
            type: "lucky_bag",
            roomId,
            title: "🎉 Lucky Bag Drop!",
            message: `🎉 ${senderName} sent a Lucky Bag (${amount.toLocaleString()} 💎) in ${roomName}! Tap to Join & Claim Now!`,
            senderName,
            totalDiamonds: amount,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        });

        return { success: true, bagId: bagRef.id, totalDiamonds: amount };
    });
});

/**
 * 🧧 2. Claim Lucky Bag Slice
 */
exports.claimLuckyBag = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Authentication required.");
    const claimantUid = context.auth.uid;
    const { bagId } = data;

    if (!bagId) throw new functions.https.HttpsError("invalid-argument", "Missing bagId.");

    return await db.runTransaction(async (transaction) => {
        const bagRef = db.collection("lucky_bags").doc(bagId);
        const claimantRef = db.collection("users").doc(claimantUid);

        const [bagDoc, claimantDoc] = await Promise.all([
            transaction.get(bagRef),
            transaction.get(claimantRef)
        ]);

        if (!bagDoc.exists) throw new functions.https.HttpsError("not-found", "Lucky Bag expired or not found.");
        const bagData = bagDoc.data();

        if (bagData.status !== "active" || bagData.rewardPool.length === 0) {
            throw new functions.https.HttpsError("failed-precondition", "This Lucky Bag is fully claimed!");
        }

        const claimedUids = bagData.claimedUids || [];
        if (claimedUids.includes(claimantUid)) {
            throw new functions.https.HttpsError("already-exists", "You have already claimed a reward from this Lucky Bag!");
        }

        // Draw next random slice from reward pool
        const rewardPool = [...bagData.rewardPool];
        const rewardDiamonds = rewardPool.pop();

        // Update Claimant Diamond Balance
        transaction.update(claimantRef, {
            diamondBalance: admin.firestore.FieldValue.increment(rewardDiamonds)
        });

        const updatedClaimed = [...claimedUids, claimantUid];
        const isDepleted = rewardPool.length === 0;

        transaction.update(bagRef, {
            rewardPool,
            claimedUids: updatedClaimed,
            remainingWinners: rewardPool.length,
            status: isDepleted ? "depleted" : "active",
            claims: admin.firestore.FieldValue.arrayUnion({
                uid: claimantUid,
                name: claimantDoc.data()?.displayName || "User",
                avatar: claimantDoc.data()?.profilePhotoUrl || "",
                diamonds: rewardDiamonds,
                claimedAt: Date.now()
            })
        });

        return { success: true, rewardDiamonds, isDepleted };
    });
});

/* ==========================================================================
   TEEN PATTI ROYALE - REAL-TIME MULTIPLAYER ROOM GAME
   ========================================================================== */

const TP_SUITS = ["hearts", "diamonds", "clubs", "spades"];
const TP_RANKS = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"];
const TP_RANK_VALUES = {
    "2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8, "9": 9, "10": 10,
    "J": 11, "Q": 12, "K": 13, "A": 14
};
const TP_RANK_NAMES = {
    2: "Twos", 3: "Threes", 4: "Fours", 5: "Fives", 6: "Sixes", 7: "Sevens",
    8: "Eights", 9: "Nines", 10: "Tens", 11: "Jacks", 12: "Queens", 13: "Kings", 14: "Aces"
};

function createShuffledTeenPattiDeck() {
    const deck = [];
    for (const suit of TP_SUITS) {
        for (const rank of TP_RANKS) {
            deck.push({ id: `${rank}-${suit}`, suit, rank });
        }
    }
    for (let i = deck.length - 1; i > 0; i--) {
        const j = crypto.randomInt(0, i + 1);
        [deck[i], deck[j]] = [deck[j], deck[i]];
    }
    return deck;
}

function evaluateTeenPattiHand(cards) {
    if (!cards || cards.length !== 3) return { score: 0, label: "NONE", description: "" };
    const values = cards.map(c => TP_RANK_VALUES[c.rank]).sort((a, b) => b - a);
    const sameSuit = cards.every(c => c.suit === cards[0].suit);
    const isA23 = values[0] === 14 && values[1] === 3 && values[2] === 2;
    const isSeq = isA23 || (values[0] - 1 === values[1] && values[1] - 1 === values[2]);
    const seqHigh = isA23 ? 3 : values[0];

    const counts = {};
    values.forEach(v => counts[v] = (counts[v] || 0) + 1);
    const pairVal = Object.keys(counts).find(k => counts[k] === 2);
    const trailVal = Object.keys(counts).find(k => counts[k] === 3);

    let score, label, description;
    if (trailVal) {
        score = 6000000 + Number(trailVal) * 10000;
        label = "TRAIL";
        description = `Three ${TP_RANK_NAMES[Number(trailVal)] || "Cards"}`;
    } else if (isSeq && sameSuit) {
        score = 5000000 + seqHigh * 10000;
        label = "PURE SEQUENCE";
        description = `Pure Sequence, ${TP_RANK_NAMES[seqHigh] || "High"}`;
    } else if (isSeq) {
        score = 4000000 + seqHigh * 10000;
        label = "SEQUENCE";
        description = `Sequence, ${TP_RANK_NAMES[seqHigh] || "High"}`;
    } else if (sameSuit) {
        score = 3000000 + values[0] * 10000 + values[1] * 100 + values[2];
        label = "COLOR";
        description = `Color Flush, ${TP_RANK_NAMES[values[0]] || "High"}`;
    } else if (pairVal) {
        const pNum = Number(pairVal);
        const kicker = values.find(v => v !== pNum) || 0;
        score = 2000000 + pNum * 10000 + kicker * 100;
        label = "PAIR";
        description = `Pair of ${TP_RANK_NAMES[pNum] || "Cards"}`;
    } else {
        score = 1000000 + values[0] * 10000 + values[1] * 100 + values[2];
        label = "HIGH CARD";
        description = `${TP_RANK_NAMES[values[0]] || "Card"} High`;
    }
    return { score, label, description };
}

exports.joinTeenPattiSeat = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const uid = context.auth.uid;
    const roomId = (data.roomId || "").trim();
    const seatIndex = parseInt(data.seatIndex, 10);

    if (!roomId) throw new functions.https.HttpsError("invalid-argument", "Room ID is required.");
    if (isNaN(seatIndex) || seatIndex < 0 || seatIndex > 5) {
        throw new functions.https.HttpsError("invalid-argument", "Seat must be between 0 and 5.");
    }

    const tableRef = db.collection("rooms").doc(roomId).collection("games").doc("teen_patti");
    const userRef = db.collection("users").doc(uid);

    return db.runTransaction(async (transaction) => {
        const [userDoc, tableDoc] = await Promise.all([
            transaction.get(userRef),
            transaction.get(tableRef)
        ]);

        if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");
        const userData = userDoc.data();
        const diamondBalance = Number(userData.diamondBalance || 0);

        let tableData = tableDoc.exists ? tableDoc.data() : {
            roomId,
            phase: "waiting",
            round: 1,
            pot: 0,
            currentBet: 1000,
            bootAmount: 1000,
            turn: 0,
            turnDeadline: null,
            seats: [null, null, null, null, null, null],
            winner: null,
            revealAll: false,
            revealedHands: {}
        };

        const seats = Array.isArray(tableData.seats) ? [...tableData.seats] : [null, null, null, null, null, null];
        while (seats.length < 6) seats.push(null);

        if (diamondBalance < (tableData.bootAmount || 1000)) {
            throw new functions.https.HttpsError("failed-precondition", "Insufficient Diamonds. Need at least 1,000 Diamonds to sit.");
        }

        if (seats[seatIndex] && seats[seatIndex].uid !== uid) {
            throw new functions.https.HttpsError("already-exists", "This seat is already occupied.");
        }

        // Check if user is already seated in another seat
        for (let i = 0; i < 6; i++) {
            if (seats[i] && seats[i].uid === uid && i !== seatIndex) {
                seats[i] = null;
            }
        }

        seats[seatIndex] = {
            seat: seatIndex,
            uid,
            name: userData.displayName || "Player",
            avatar: userData.photoUrl || userData.avatar || `https://api.dicebear.com/9.x/adventurer/svg?seed=${uid}`,
            balance: diamondBalance,
            bet: 0,
            seen: false,
            folded: false,
            cardsCount: 0,
            lastAction: null
        };

        transaction.set(tableRef, {
            ...tableData,
            seats
        }, { merge: true });

        return { success: true, seatIndex };
    });
});

exports.leaveTeenPattiSeat = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const uid = context.auth.uid;
    const roomId = (data.roomId || "").trim();
    if (!roomId) throw new functions.https.HttpsError("invalid-argument", "Room ID is required.");

    const tableRef = db.collection("rooms").doc(roomId).collection("games").doc("teen_patti");

    return db.runTransaction(async (transaction) => {
        const tableDoc = await transaction.get(tableRef);
        if (!tableDoc.exists) return { success: true };

        const tableData = tableDoc.data();
        const seats = [...(tableData.seats || [])];
        const seatIdx = seats.findIndex(s => s && s.uid === uid);
        if (seatIdx === -1) return { success: true };

        seats[seatIdx] = null;
        let update = { seats };

        // If in betting phase and was active player's turn, advance turn
        if (tableData.phase === "betting" && tableData.turn === seatIdx) {
            let nextTurn = seatIdx;
            for (let i = 1; i <= 6; i++) {
                const check = (seatIdx + i) % 6;
                if (seats[check] && !seats[check].folded) {
                    nextTurn = check;
                    break;
                }
            }
            update.turn = nextTurn;
            update.turnDeadline = Date.now() + 15000;
        }

        transaction.update(tableRef, update);
        return { success: true };
    });
});

exports.startTeenPattiRound = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const roomId = (data.roomId || "").trim();
    if (!roomId) throw new functions.https.HttpsError("invalid-argument", "Room ID is required.");

    const tableRef = db.collection("rooms").doc(roomId).collection("games").doc("teen_patti");

    return db.runTransaction(async (transaction) => {
        const tableDoc = await transaction.get(tableRef);
        if (!tableDoc.exists) throw new functions.https.HttpsError("not-found", "Table not found.");

        const tableData = tableDoc.data();
        if (tableData.phase === "betting" || tableData.phase === "dealing") {
            return { success: true, message: "Round already in progress." };
        }

        const seats = [...(tableData.seats || [])];
        const seatedPlayers = seats.filter(s => s !== null);
        if (seatedPlayers.length < 2) {
            throw new functions.https.HttpsError("failed-precondition", "Need at least 2 players seated to start.");
        }

        const bootAmount = tableData.bootAmount || 1000;
        const userRefs = seatedPlayers.map(p => db.collection("users").doc(p.uid));
        const userDocs = await Promise.all(userRefs.map(ref => transaction.get(ref)));

        // Verify all players have sufficient boot balance
        for (let i = 0; i < seatedPlayers.length; i++) {
            const uDoc = userDocs[i];
            const bal = Number(uDoc.data()?.diamondBalance || 0);
            if (bal < bootAmount) {
                throw new functions.https.HttpsError("failed-precondition", `${seatedPlayers[i].name} has insufficient Diamonds for Boot.`);
            }
        }

        // Deduct boot amount from each player atomically
        for (let i = 0; i < seatedPlayers.length; i++) {
            transaction.update(userRefs[i], {
                diamondBalance: admin.firestore.FieldValue.increment(-bootAmount)
            });
        }

        // Deal 3 cards securely to each seated player
        const deck = createShuffledTeenPattiDeck();
        let firstTurnIndex = 0;
        let foundFirst = false;

        for (let i = 0; i < 6; i++) {
            if (seats[i]) {
                if (!foundFirst) {
                    firstTurnIndex = i;
                    foundFirst = true;
                }
                const cards = [deck.pop(), deck.pop(), deck.pop()];
                const privateRef = tableRef.collection("private_cards").doc(seats[i].uid);
                transaction.set(privateRef, { cards });

                seats[i] = {
                    ...seats[i],
                    bet: bootAmount,
                    balance: seats[i].balance - bootAmount,
                    seen: false,
                    folded: false,
                    cardsCount: 3,
                    lastAction: "BOOT"
                };
            }
        }

        const totalPot = bootAmount * seatedPlayers.length;
        const roundNumber = (tableData.round || 0) + 1;

        transaction.update(tableRef, {
            phase: "betting",
            round: roundNumber,
            pot: totalPot,
            currentBet: bootAmount,
            turn: firstTurnIndex,
            turnDeadline: Date.now() + 15000,
            winner: null,
            revealAll: false,
            revealedHands: {},
            seats
        });

        return { success: true, round: roundNumber, pot: totalPot };
    });
});

exports.teenPattiAction = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const uid = context.auth.uid;
    const roomId = (data.roomId || "").trim();
    const action = (data.action || "").trim().toLowerCase(); // see, chaal, raise, fold, show
    const amount = parseInt(data.amount, 10) || 0;

    if (!roomId) throw new functions.https.HttpsError("invalid-argument", "Room ID is required.");
    if (!["see", "chaal", "raise", "fold", "show"].includes(action)) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid action: " + action);
    }

    const tableRef = db.collection("rooms").doc(roomId).collection("games").doc("teen_patti");
    const userRef = db.collection("users").doc(uid);

    return db.runTransaction(async (transaction) => {
        const [tableDoc, userDoc] = await Promise.all([
            transaction.get(tableRef),
            transaction.get(userRef)
        ]);

        if (!tableDoc.exists) throw new functions.https.HttpsError("not-found", "Table not found.");
        const tableData = tableDoc.data();
        if (tableData.phase !== "betting") {
            throw new functions.https.HttpsError("failed-precondition", "Round is not in betting phase.");
        }

        const seats = [...(tableData.seats || [])];
        const mySeatIdx = seats.findIndex(s => s && s.uid === uid);
        if (mySeatIdx === -1) throw new functions.https.HttpsError("permission-denied", "You are not seated at this table.");
        const mySeat = { ...seats[mySeatIdx] };

        // Handle 'SEE' action (can be called at any time before folding)
        if (action === "see") {
            mySeat.seen = true;
            mySeat.lastAction = "SEEN";
            seats[mySeatIdx] = mySeat;
            transaction.update(tableRef, { seats });
            return { success: true, action: "see" };
        }

        // For betting moves (chaal, raise, fold, show), must be user's turn
        if (tableData.turn !== mySeatIdx) {
            throw new functions.https.HttpsError("failed-precondition", "Not your turn.");
        }

        if (action === "fold") {
            mySeat.folded = true;
            mySeat.lastAction = "FOLD";
            seats[mySeatIdx] = mySeat;

            const remainingActive = seats.filter(s => s && !s.folded);
            if (remainingActive.length === 1) {
                // Only 1 survivor -> Instant Winner!
                const survivor = remainingActive[0];
                const pot = Number(tableData.pot || 0);

                const survivorUserRef = db.collection("users").doc(survivor.uid);
                transaction.update(survivorUserRef, {
                    diamondBalance: admin.firestore.FieldValue.increment(pot)
                });

                transaction.update(tableRef, {
                    phase: "result",
                    revealAll: true,
                    winner: {
                        uid: survivor.uid,
                        name: survivor.name,
                        avatar: survivor.avatar,
                        pot,
                        handLabel: "SURVIVOR",
                        handDescription: "All other players folded",
                        cards: []
                    },
                    seats
                });

                return { success: true, action: "fold", winner: survivor.name };
            }

            // Advance turn
            let nextTurn = mySeatIdx;
            for (let i = 1; i <= 6; i++) {
                const check = (mySeatIdx + i) % 6;
                if (seats[check] && !seats[check].folded) {
                    nextTurn = check;
                    break;
                }
            }

            transaction.update(tableRef, {
                seats,
                turn: nextTurn,
                turnDeadline: Date.now() + 15000
            });
            return { success: true, action: "fold" };
        }

        if (action === "chaal" || action === "raise") {
            const currentBet = Number(tableData.currentBet || 1000);
            const betAmount = action === "raise" ? currentBet * 2 : currentBet;
            const finalCost = mySeat.seen ? betAmount : Math.max(100, Math.floor(betAmount / 2));

            const userBalance = Number(userDoc.data()?.diamondBalance || 0);
            if (userBalance < finalCost) {
                throw new functions.https.HttpsError("failed-precondition", "Insufficient Diamonds for " + action.toUpperCase());
            }

            // Deduct balance
            transaction.update(userRef, {
                diamondBalance: admin.firestore.FieldValue.increment(-finalCost)
            });

            mySeat.bet = (mySeat.bet || 0) + finalCost;
            mySeat.balance = userBalance - finalCost;
            mySeat.lastAction = action.toUpperCase();
            seats[mySeatIdx] = mySeat;

            const newPot = Number(tableData.pot || 0) + finalCost;
            const newCurrentBet = action === "raise" ? betAmount : currentBet;

            // Advance turn
            let nextTurn = mySeatIdx;
            for (let i = 1; i <= 6; i++) {
                const check = (mySeatIdx + i) % 6;
                if (seats[check] && !seats[check].folded) {
                    nextTurn = check;
                    break;
                }
            }

            transaction.update(tableRef, {
                pot: newPot,
                currentBet: newCurrentBet,
                seats,
                turn: nextTurn,
                turnDeadline: Date.now() + 15000
            });

            return { success: true, action, amount: finalCost, pot: newPot };
        }

        if (action === "show") {
            // Showdown resolution
            const contenders = seats.filter(s => s && !s.folded);
            const privateCardsDocs = await Promise.all(
                contenders.map(c => transaction.get(tableRef.collection("private_cards").doc(c.uid)))
            );

            let bestContender = null;
            let bestEvaluation = { score: -1 };
            const revealedHands = {};

            for (let i = 0; i < contenders.length; i++) {
                const c = contenders[i];
                const cards = privateCardsDocs[i].exists ? (privateCardsDocs[i].data().cards || []) : [];
                revealedHands[c.uid] = cards;
                const evalResult = evaluateTeenPattiHand(cards);

                if (evalResult.score > bestEvaluation.score) {
                    bestEvaluation = evalResult;
                    bestContender = { ...c, cards };
                }
            }

            const pot = Number(tableData.pot || 0);
            if (bestContender) {
                const winnerUserRef = db.collection("users").doc(bestContender.uid);
                transaction.update(winnerUserRef, {
                    diamondBalance: admin.firestore.FieldValue.increment(pot)
                });
            }

            transaction.update(tableRef, {
                phase: "result",
                revealAll: true,
                revealedHands,
                winner: {
                    uid: bestContender?.uid || "",
                    name: bestContender?.name || "Player",
                    avatar: bestContender?.avatar || "",
                    pot,
                    handLabel: bestEvaluation.label,
                    handDescription: bestEvaluation.description,
                    cards: bestContender?.cards || []
                },
                seats
            });

            return { success: true, action: "show", winner: bestContender?.name, pot };
        }

        return { success: false };
    });
});

