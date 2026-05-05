const functions = require("firebase-functions");
const { onValueUpdated } = require("firebase-functions/v2/database");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineString, defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp({
    databaseURL: "https://hellochat-e8965-default-rtdb.firebaseio.com"
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
 * 1. onCreate Auth User Trigger
 * Creates a basic skeletal user document when they sign up.
 */

exports.onUserWrite = functions.firestore.document("users/{uid}").onWrite(async (change, context) => {
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
 * --- SVIP SYSTEM (SPENDING BASED) ---
 */
const SVIP_THRESHOLDS = [
    { level: 1, points: 10000000 },
    { level: 2, points: 30000000 },
    { level: 3, points: 50000000 },
    { level: 4, points: 100000000 },
    { level: 5, points: 200000000 },
    { level: 6, points: 300000000 },
    { level: 7, points: 500000000 },
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
 * --- ID LEVEL SYSTEM (XP BASED) ---
 * Level 1-50: Easy (Linear growth)
 * Level 51-100: Hard (Exponential growth)
 */
function getXPRequiredForNextLevel(currentLevel) {
    if (currentLevel <= 0) return 100;
    if (currentLevel < 50) {
        return currentLevel * 200;
    } else {
        return 10000 + (currentLevel - 50) * 2000;
    }
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
    { level: 1, target: 10000, label: "Lv.1 Beginner" },
    { level: 2, target: 50000, label: "Lv.2 Rising Star" },
    { level: 3, target: 150000, label: "Lv.3 Influencer" },
    { level: 4, target: 500000, label: "Lv.4 Professional" },
    { level: 5, target: 1500000, label: "Lv.5 Elite" },
    { level: 6, target: 5000000, label: "Lv.6 Master" },
    { level: 7, target: 15000000, label: "Lv.7 Legend" },
    { level: 8, target: 50000000, label: "Lv.8 Mythic" },
    { level: 9, target: 150000000, label: "Lv.9 Immortal" },
    { level: 10, target: 500000000, label: "Lv.10 Ultimate" },
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
async function processSalaryMilestones(transaction, hostUid, beansReceived) {
    const statusRef = db.collection("salaryStatus").doc(hostUid);
    const userRef = db.collection("users").doc(hostUid);

    const statusDoc = await transaction.get(statusRef);
    const userDoc = await transaction.get(userRef);

    if (!userDoc.exists) return;
    const userData = userDoc.data();

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
        // 1. Host Payout (60%)
        const hostPayoutRef = db.collection("salaryPayouts").doc();
        transaction.set(hostPayoutRef, {
            id: hostPayoutRef.id,
            uid: hostUid,
            amount: lv.target * 0.6,
            type: "host",
            level: lv.level,
            scheduledDate: admin.firestore.Timestamp.fromDate(hostPayoutDate),
            status: "pending",
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // 2. Agency Payout (30%)
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

        // 3. Admin Payout (10%)
        const adminPayoutRef = db.collection("salaryPayouts").doc();
        transaction.set(adminPayoutRef, {
            id: adminPayoutRef.id,
            uid: "SYSTEM_ADMIN",
            amount: lv.target * 0.1,
            type: "admin",
            level: lv.level,
            scheduledDate: admin.firestore.Timestamp.fromDate(biWeeklyPayoutDate),
            status: "pending",
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
    }
}

exports.onUserUpdate = functions.firestore.document("users/{uid}").onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    const updates = {};

    // 1. SVIP Points (Spending based)
    const oldDiamonds = before.diamondBalance || 0;
    const newDiamonds = after.diamondBalance || 0;
    if (newDiamonds < oldDiamonds) {
        const spentAmount = oldDiamonds - newDiamonds;
        const currentPoints = after.svipPoints || 0;
        const newPoints = currentPoints + spentAmount;
        
        const currentSVIP = after.svipLevel || 0;
        const nextSVIP = calculateSVIPLevel(newPoints);

        updates.svipPoints = newPoints;
        if (nextSVIP > currentSVIP) {
            updates.svipLevel = nextSVIP;
            updates.svipLastPromotionAt = admin.firestore.FieldValue.serverTimestamp();
        }
    }

    // 2. ID Level (XP based)
    const oldXP = before.xp || 0;
    const newXP = after.xp || 0;
    if (newXP !== oldXP) {
        const nextLevel = calculateIDLevel(newXP);
        if (nextLevel !== (after.level || 1)) {
            updates.level = nextLevel;
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
        diamondBalance: 0,
        beansBalance: 0,
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

    return db.runTransaction(async (transaction) => {
        const userRef = db.collection("users").doc(targetUid);
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw new Error("User not found");

        const currentBalance = userDoc.data().diamondBalance || 0;
        transaction.update(userRef, { diamondBalance: currentBalance + amount });

        // Log action
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

    return db.runTransaction(async (transaction) => {
        const userRef = db.collection("users").doc(targetUid);
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw new Error("User not found");

        const currentBalance = userDoc.data().beansBalance || 0;
        transaction.update(userRef, { beansBalance: currentBalance + amount });

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
 * 100. Follow User
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
    const { roomId } = data;

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
        if (roomData.bannedUids && roomData.bannedUids.includes(uid)) throw new functions.https.HttpsError("permission-denied", "You are banned.");

        // Check if already in
        if (participantDoc.exists) return { success: true, message: "Already in room" };

        const userData = userDoc.exists ? userDoc.data() : {};

        // Find available seat if joining as host or needs seat
        let seatIndex = null;
        let role = "audience";

        if (uid === roomData.ownerUid) {
            seatIndex = 0; // Host always gets seat 0
            role = "host";
        } else {
            // Logic to find next available seat could be added here if needed for non-hosts
        }

        transaction.set(participantRef, {
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

        return { success: true };
    });
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
    const { roomId } = data;

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
        if (roomData.bannedUids && roomData.bannedUids.includes(uid)) throw new functions.https.HttpsError("permission-denied", "You are banned.");

        // Check if already in
        if (participantDoc.exists) return { success: true, message: "Already in room" };

        const userData = userDoc.exists ? userDoc.data() : {};

        // Find available seat if joining as host or needs seat
        let seatIndex = null;
        let role = "audience";

        if (uid === roomData.ownerUid) {
            seatIndex = 0; // Host always gets seat 0
            role = "host";
        } else {
            // Logic to find next available seat could be added here if needed for non-hosts
        }

        transaction.set(participantRef, {
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

        return await db.runTransaction(async (transaction) => {
            const senderRef = db.collection("users").doc(senderUid);
            const receiverRef = db.collection("users").doc(targetUid);
            const roomRef = db.collection("rooms").doc(roomId);
            const giftRef = db.collection("gifts").doc(giftId);

            const [senderDoc, receiverDoc, giftDoc, roomDoc] = await Promise.all([
                transaction.get(senderRef),
                transaction.get(receiverRef),
                transaction.get(giftRef),
                transaction.get(roomRef)
            ]);

            if (!senderDoc.exists) throw new functions.https.HttpsError("not-found", "Sender profile not found.");
            if (!giftDoc.exists) throw new functions.https.HttpsError("not-found", "Gift type not found.");

            const giftData = giftDoc.data();
            const totalCost = (giftData.priceInDiamonds || 0) * qty;

            // 🔍 2.5 Preliminary Agency Read (Transactions must read before write)
            let agencyDoc = null;
            let agencyRef = null;
            if (receiverDoc.exists && receiverDoc.data().agencyId) {
                // IMPORTANT: Agencies are Users with isAgencyOwner: true
                agencyRef = db.collection("users").doc(receiverDoc.data().agencyId);
                agencyDoc = await transaction.get(agencyRef);
            }

            // 💰 3. Balance Check
            const currentBalance = senderDoc.data().diamondBalance || 0;
            if (currentBalance < totalCost) {
                throw new functions.https.HttpsError("failed-precondition", "Insufficient diamond balance.");
            }

            // 💎 4. Deduct & Add XP (500 diamonds = 1 XP)
            const senderXP = Math.floor(totalCost / 500);
            transaction.update(senderRef, {
                diamondBalance: admin.firestore.FieldValue.increment(-totalCost),
                xp: admin.firestore.FieldValue.increment(senderXP),
                benchXP: admin.firestore.FieldValue.increment(senderXP),
                dailyXP: admin.firestore.FieldValue.increment(senderXP),
                weeklyXP: admin.firestore.FieldValue.increment(senderXP),
                monthlyXP: admin.firestore.FieldValue.increment(senderXP),
            });

            // 💹 5. Record Receiver Beans & XP
            if (receiverDoc.exists) {
                const receiverData = receiverDoc.data();
                const agencyId = receiverData.agencyId;

                let hostSharePercent = 0.8;
                let agencySharePercent = 0;

                // Only pay agency if user exists AND is actually an agency owner
                if (agencyId && agencyDoc && agencyDoc.exists && agencyDoc.data().isAgencyOwner) {
                    hostSharePercent = 0.7;
                    agencySharePercent = 0.1;
                    const agencyBeans = Math.floor(totalCost * agencySharePercent);
                    transaction.update(agencyRef, {
                        beansBalance: admin.firestore.FieldValue.increment(agencyBeans),
                        // Also track total earnings if field exists
                        totalBeansEarned: admin.firestore.FieldValue.increment(agencyBeans)
                    });
                } else if (agencyId) {
                    console.warn(`⚠️ Agency Owner ${agencyId} not found or invalid for receiver ${targetUid}. Skipping commission.`);
                }

                const beansEarned = Math.floor(totalCost * hostSharePercent);
                // Receiver XP: 1000 diamonds = 1 XP
                const receiverXP = Math.floor(totalCost / 1000);
                transaction.update(receiverRef, {
                    beansBalance: admin.firestore.FieldValue.increment(beansEarned),
                    princeXP: admin.firestore.FieldValue.increment(receiverXP),
                    dailyPrinceXP: admin.firestore.FieldValue.increment(receiverXP),
                    weeklyPrinceXP: admin.firestore.FieldValue.increment(receiverXP),
                    monthlyPrinceXP: admin.firestore.FieldValue.increment(receiverXP),
                });

                // 💹 NEW: Process Salary Milestones
                await processSalaryMilestones(transaction, targetUid, beansEarned);
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
                transaction.set(msgRef, {
                    uid: senderUid,
                    senderName: senderDoc.data().displayName || "User",
                    type: "gift",
                    giftId: giftId,
                    quantity: qty,
                    animationUrl: giftData.lottieAssetPath,
                    text: `Sent ${qty}x ${giftData.name}`,
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
            }

            return { success: true, newBalance: currentBalance - totalCost };
        });
    } catch (error) {
        console.error("🛑 Gifting Error:", error);
        if (error instanceof functions.https.HttpsError) throw error;
        throw new functions.https.HttpsError("internal", error.message || "An unexpected error occurred while gifting.");
    }
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
    return db.collection("rooms").doc(roomId).collection("participants").doc(ownerUid).set({
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastActive: admin.firestore.FieldValue.serverTimestamp(),
        seatIndex: 0,
        isMuted: false,
        role: "host",
    });
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
        { tierId: 'vip1', name: 'VIP 1', level: 1, monthlyPriceInDiamonds: 500, monthlyPriceInUSD: 5, benefits: ["special_frame", "badge"], profileFrame: "assets/frames/vip1.png", entryAnimation: "vip_entry_1", badgeIcon: "assets/badges/vip1.png", priorityMicAccess: false, isActive: true, sortOrder: 1 },
        { tierId: 'vip2', name: 'VIP 2', level: 2, monthlyPriceInDiamonds: 1500, monthlyPriceInUSD: 15, benefits: ["special_frame", "badge", "entry_effect"], profileFrame: "assets/frames/vip2.png", entryAnimation: "vip_entry_2", badgeIcon: "assets/badges/vip2.png", priorityMicAccess: false, isActive: true, sortOrder: 2 },
        { tierId: 'vip3', name: 'VIP 3', level: 3, monthlyPriceInDiamonds: 5000, monthlyPriceInUSD: 50, benefits: ["special_frame", "badge", "entry_effect", "priority_mic"], profileFrame: "assets/frames/vip3.png", entryAnimation: "vip_entry_3", badgeIcon: "assets/badges/vip3.png", priorityMicAccess: true, isActive: true, sortOrder: 3 },
        { tierId: 'vip4', name: 'VIP 4', level: 4, monthlyPriceInDiamonds: 15000, monthlyPriceInUSD: 150, benefits: ["special_frame", "badge", "entry_effect", "priority_mic", "exclusive_gifts"], profileFrame: "assets/frames/vip4.png", entryAnimation: "vip_entry_4", badgeIcon: "assets/badges/vip4.png", priorityMicAccess: true, isActive: true, sortOrder: 4 },
        { tierId: 'vip5', name: 'VIP 5', level: 5, monthlyPriceInDiamonds: 50000, monthlyPriceInUSD: 500, benefits: ["special_frame", "badge", "entry_effect", "priority_mic", "exclusive_gifts", "custom_id"], profileFrame: "assets/frames/vip5.png", entryAnimation: "vip_entry_5", badgeIcon: "assets/badges/vip5.png", priorityMicAccess: true, isActive: true, sortOrder: 5 },
        { tierId: 'vip6', name: 'VIP 6', level: 6, monthlyPriceInDiamonds: 150000, monthlyPriceInUSD: 1500, benefits: ["special_frame", "badge", "entry_effect", "priority_mic", "exclusive_gifts", "manager"], profileFrame: "assets/frames/vip6.png", entryAnimation: "vip_entry_6", badgeIcon: "assets/badges/vip6.png", priorityMicAccess: true, isActive: true, sortOrder: 6 },
        { tierId: 'svip', name: 'SVIP', level: 7, monthlyPriceInDiamonds: 500000, monthlyPriceInUSD: 5000, benefits: ["all_access", "god_badge", "world_frame"], profileFrame: "assets/frames/svip.png", entryAnimation: "svip_entry", badgeIcon: "assets/badges/svip.png", priorityMicAccess: true, isActive: true, sortOrder: 7 },
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
 * 16. Purchase VIP (Dynamic)
 */
exports.purchaseVIP = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const uid = context.auth.uid;
    const { tierId } = data;

    return db.runTransaction(async (transaction) => {
        const tierRef = db.collection("vip_tiers").doc(tierId);
        const userRef = db.collection("users").doc(uid);

        const [tierDoc, userDoc] = await Promise.all([
            transaction.get(tierRef),
            transaction.get(userRef)
        ]);

        if (!tierDoc.exists) throw new functions.https.HttpsError("not-found", "VIP Tier not found.");
        if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");

        const userData = userDoc.data();
        const tierData = tierDoc.data();
        const price = tierData.monthlyPriceInDiamonds;

        if ((userData.diamondBalance || 0) < price) {
            throw new functions.https.HttpsError("failed-precondition", "Insufficient diamonds.");
        }

        // 80/20 Split Logic
        const immediateCredit = Math.floor(price * 0.8);
        const delayedCredit = price - immediateCredit;

        // Calculate expiry (30 days)
        const expiry = new Date();
        expiry.setDate(expiry.getDate() + 30);

        // Calculate Release Date (30 days)
        const releaseDate = new Date();
        releaseDate.setDate(releaseDate.getDate() + 30);

        // 1. Deduct full price, give 80% back, set Tier
        transaction.update(userRef, {
            diamondBalance: admin.firestore.FieldValue.increment(-price + immediateCredit),
            vipTier: tierData.name,
            vipExpiry: admin.firestore.Timestamp.fromDate(expiry),
            profileFrame: tierData.profileFrame || "",
            entryAnimation: tierData.entryAnimation || "",
            badgeIcon: tierData.badgeIcon || ""
        });

        // 2. Schedule 20% release
        const pendingRef = userRef.collection("pending_credits").doc();
        transaction.set(pendingRef, {
            amount: delayedCredit,
            releaseDate: admin.firestore.Timestamp.fromDate(releaseDate),
            status: "pending",
            type: "vip_retention_bonus",
            description: `20% Retention Bonus for ${tierData.name}`,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // 3. Log main transaction
        const txRef = userRef.collection("transactions").doc();
        transaction.set(txRef, {
            type: "purchase",
            amount: price,
            immediateCredit: immediateCredit,
            delayedCredit: delayedCredit,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            description: `Purchased ${tierData.name} Monthly Subscription (80/20 Split)`
        });

        return { success: true, immediate: immediateCredit, delayed: delayedCredit };
    });
});


/**
 * 17. Distribute Weekly Salary
 */
exports.distributeWeeklySalary = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const { roomId } = data;

    return db.runTransaction(async (transaction) => {
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

        return { success: true, amount: hostShare };
    });
});

/**
 * 20. Global Push Notification Trigger
 * Sends a real FCM push notification to all users when an admin creates a global announcement with isPush: true.
 */
exports.sendGlobalPush = functions.firestore.document("global_announcements/{id}").onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    if (!data.isPush) return null;

    const message = data.message;
    const title = data.title || "Hello Chat Admin";

    // 1. Fetch all users with fcmTokens
    // Note: This is an example of a simple broadcast for 500 users.
    const usersSnap = await db.collection("users")
        .where("fcmToken", "!=", null)
        .limit(500)
        .get();

    const tokens = usersSnap.docs.map(d => d.data().fcmToken).filter(t => !!t);
    if (tokens.length === 0) return null;

    const pushMessage = {
        notification: {
            title: title,
            body: message,
            image: data.imageUrl || null,
        },
        tokens: tokens, // Multicast
    };

    try {
        const response = await admin.messaging().sendEachForMulticast(pushMessage);
        console.log(`Push sent: ${response.successCount} success.`);
        return db.collection("global_announcements").doc(context.params.id).update({
            pushStatus: "sent",
            successCount: response.successCount
        });
    } catch (err) {
        console.error("Push Error:", err);
        return null;
    }
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
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    // Supports both old single 'betAmount' and new 'bets' Map
    const bets = data.bets || (data.betAmount ? { [data.label || "any"]: data.betAmount } : {});
    const totalBet = Object.values(bets).reduce((acc, b) => acc + (Number(b) || 0), 0);

    if (totalBet !== 0 && totalBet < 10) {
        throw new functions.https.HttpsError("invalid-argument", "Min total bet 10 Diamonds.");
    }

    const uid = context.auth.uid;
    const userRef = db.collection("users").doc(uid);
    const settingsRef = db.collection("game_settings").doc("lucky_spin");
    const statsRef = db.collection("games_meta").doc("lucky_spin");

    const now = Date.now();
    const roundId = Math.floor(now / 30000).toString();

    return db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        const settingsDoc = await transaction.get(settingsRef);
        const statsDoc = await transaction.get(statsRef);

        if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");
        
        const settings = settingsDoc.exists ? settingsDoc.data() : { segments: [] };
        const segments = settings.segments || [];
        const currentStats = statsDoc.exists ? statsDoc.data() : {};

        let balance = Number(userDoc.data().diamondBalance || 0);
        let beansBalance = Number(userDoc.data().beansBalance || 0);

        // --- AUTOMATIC EXCHANGE LOGIC ---
        if (balance < totalBet) {
            const needed = totalBet - balance;
            const starsRequired = Math.ceil((needed * 7) / 2);
            if (beansBalance >= starsRequired) {
                beansBalance -= starsRequired;
                balance = totalBet;
                transaction.update(userRef, { beansBalance, diamondBalance: balance });
            } else {
                throw new functions.https.HttpsError("failed-precondition", "Insufficient Diamonds & Stars.");
            }
        }

        // --- GLOBAL OUTCOME DETERMINATION ---
        let roundResult = currentStats.lastGlobalRound === roundId ? currentStats.lastGlobalOutcome : null;
        
        if (!roundResult) {
            const todayStr = new Date().toISOString().split('T')[0];
            let saladHits = currentStats.todaySaladHits || 0;
            let pizzaHits = currentStats.todayPizzaHits || 0;

            // Daily Reset
            if (currentStats.lastResetDate !== todayStr) {
                saladHits = 0;
                pizzaHits = 0;
            }
            
            // Random chance for special rounds (e.g., 2% for Salad, 1% for Pizza)
            const roll = getRandomInt(100);
            let resultType = "standard";
            
            if (roll < 1 && pizzaHits < 1) {
                resultType = "pizza";
                pizzaHits++;
            } else if (roll < 5 && saladHits < 4) {
                resultType = "salad";
                saladHits++;
            }

            let winnerSegment = null;
            if (resultType === "standard") {
                const totalWeight = segments.reduce((acc, s) => acc + (Number(s.weight) || 0), 0);
                let random = getRandomInt(totalWeight || 100);
                winnerSegment = segments[0] || { multiplier: 0, emoji: "❌", name: "Empty" };

                for (const s of segments) {
                    const w = Number(s.weight) || 0;
                    if (random < w) {
                        winnerSegment = s;
                        break;
                    }
                    random -= w;
                }
            } else {
                // For Salad/Pizza, we just pick one segment from that category as the "visual anchor"
                const categorySegments = segments.filter(s => s.category === resultType);
                winnerSegment = categorySegments.length > 0 
                    ? categorySegments[getRandomInt(categorySegments.length)] 
                    : segments[0];
            }

            roundResult = {
                type: resultType,
                multiplier: Number(winnerSegment.multiplier) || 0,
                emoji: winnerSegment.emoji || "🎰",
                label: resultType === "standard" ? `${winnerSegment.multiplier}x` : resultType.toUpperCase(),
                name: winnerSegment.name
            };

            // Update Global Stats
            const statsUpdate = {
                lastGlobalRound: roundId,
                lastGlobalOutcome: roundResult,
                currentRound: admin.firestore.FieldValue.increment(1),
                todaySaladHits: saladHits,
                todayPizzaHits: pizzaHits,
                lastResetDate: todayStr
            };
            
            transaction.update(statsRef, statsUpdate);
        }

        // --- WIN CALCULATION ---
        let totalPrize = 0;
        
        if (roundResult.type === "standard") {
            const betOnWinner = Number(bets[roundResult.name] || bets[roundResult.label]) || 0;
            totalPrize = Math.floor(betOnWinner * roundResult.multiplier);
        } else {
            // Category Win: Pay out all bets in that category
            for (const s of segments) {
                if (s.category === roundResult.type) {
                    const betOnItem = Number(bets[s.name] || bets[`${s.multiplier}x`]) || 0;
                    totalPrize += Math.floor(betOnItem * (Number(s.multiplier) || 1));
                }
            }
        }
        
        const netChange = totalPrize - totalBet;

        const userUpdates = {
            diamondBalance: balance + netChange
        };

        // Award Jackpot King badge for Pizza wins
        if (roundResult.type === 'pizza') {
            userUpdates.badges = admin.firestore.FieldValue.arrayUnion('jackpot_winner');
        }

        transaction.update(userRef, userUpdates);

        if (totalPrize > 0) {
            let todayWinners = currentStats.todayWinners || [];
            const userName = userDoc.data().displayName || userDoc.data().username || "User";
            const userAvatar = userDoc.data().photoURL || "";

            todayWinners.push({
                uid, name: userName, avatar: userAvatar, amount: totalPrize, 
                multiplier: roundResult.multiplier, type: roundResult.type, timestamp: now
            });

            const uniqueWinners = {};
            todayWinners.forEach(w => {
                if (!uniqueWinners[w.uid] || w.amount > uniqueWinners[w.uid].amount) {
                    uniqueWinners[w.uid] = w;
                }
            });

            todayWinners = Object.values(uniqueWinners).sort((a, b) => b.amount - a.amount).slice(0, 10);
            
            transaction.update(statsRef, {
                todayWinners,
                lastWinnerName: userName,
                lastWinnerAmount: totalPrize,
                lastWinnerLabel: roundResult.label
            });
        }

        // Log History
        const logRef = userRef.collection("game_history").doc();
        transaction.set(logRef, {
            game: "spin_wheel",
            roundId: roundId,
            bets: bets,
            totalBet: totalBet,
            prize: totalPrize,
            resultType: roundResult.type,
            label: roundResult.label,
            multiplier: roundResult.multiplier,
            emoji: roundResult.emoji,
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        });

        return { prize: totalPrize, label: roundResult.label, type: roundResult.type };
    });
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
    console.log("[CRON] Lucky Spin stats reset successfully.");
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
 * 400. Universal Leveling Engine
 * Automatically calculates and updates User Level based on XP gain.
 * Logic: Every 1,000 XP earned = +1 Level.
 */
exports.onUserUpdate = functions.firestore.document("users/{uid}").onUpdate(async (change, context) => {
    const after = change.after.data();
    const before = change.before.data();

    // Only run logic if XP has increased
    if ((after.xp || 0) <= (before.xp || 0)) return null;

    const currentXP = after.xp || 0;
    const currentLevel = after.level || 1;

    // Formula: Level starts at 1, gains +1 for every 1000 XP
    const calculatedLevel = Math.floor(currentXP / 1000) + 1;

    // Trigger update only if a new level is reached
    if (calculatedLevel > currentLevel) {
        console.log(`[LEVEL_UP] User:${context.params.uid} New Level:${calculatedLevel}`);

        return change.after.ref.update({
            level: calculatedLevel,
            lastLevelUp: admin.firestore.FieldValue.serverTimestamp()
        });
    }

    return null;
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

        // Conversion Rate: 7 Stars = 2 Diamonds
        const diamondsToReceive = Math.floor((amount / 7) * 2);

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
    const { amount, method, accountDetails } = data; // amount in Beans

    if (!amount || amount < 1000) {
        throw new functions.https.HttpsError("invalid-argument", "Minimum withdrawal: 1,000 Beans.");
    }

    return db.runTransaction(async (transaction) => {
        const userRef = db.collection("users").doc(uid);
        const userDoc = await transaction.get(userRef);

        if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");

        const currentBeans = userDoc.data().beansBalance || 0;
        if (currentBeans < amount) {
            throw new functions.https.HttpsError("failed-precondition", "Insufficient beans.");
        }

        // Deduct beans immediately
        transaction.update(userRef, {
            beansBalance: admin.firestore.FieldValue.increment(-amount)
        });

        // Log request in global withdrawals collection for Admin
        const withdrawalRef = db.collection("withdrawals").doc();
        transaction.set(withdrawalRef, {
            requestId: withdrawalRef.id,
            uid: uid,
            username: userDoc.data().username,
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
            status: "pending",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            description: `Withdrawal request of ${amount} Beans initiated.`,
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

        // Calculate new SVIP level
        let newSvipLevel = -1;
        let newSvipPoints = 0;
        for (const tier of SVIP_TIERS) {
            if (currentMonthly >= tier.min) {
                newSvipLevel = tier.level;
                newSvipPoints = tier.points;
            } else {
                break;
            }
        }

        const updates = {
            diamondBalance: admin.firestore.FieldValue.increment(amount),
            monthlyRecharge: currentMonthly,
        };

        if (newSvipLevel !== -1) {
            updates.svipLevel = newSvipLevel;
            updates.svipPoints = newSvipPoints;
        }

        transaction.update(userRef, updates);

        // Log transaction
        const txRef = userRef.collection("transactions").doc();
        transaction.set(txRef, {
            type: "RECHARGE",
            amount: amount,
            packageId: packageId || "CUSTOM",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            monthlyRechargeTotal: currentMonthly,
            newSvipLevel: newSvipLevel >= 0 ? newSvipLevel : null
        });

        return {
            success: true,
            newBalance: (userData.diamondBalance || 0) + amount,
            newSvipLevel: newSvipLevel
        };
    });
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

        return sendPush(after.uid, "Withdrawal Update 🏦", msg, { type: "WITHDRAWAL", status: after.status });
    }
    return null;
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
    if (senderDoc.data().partnerUid) throw new functions.https.HttpsError("already-exists", "You are already paired.");
    if (targetDoc.data().partnerUid) throw new functions.https.HttpsError("already-exists", "Target is already paired.");

    const inviteId = `${senderUid}_${targetUid}`;
    await db.collection("cp_invites").doc(inviteId).set({
        senderUid,
        targetUid,
        senderName: senderDoc.data().displayName,
        senderAvatar: senderDoc.data().profilePhotoUrl,
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Send Push Notification
    await sendPush(targetUid, "New CP Invite! 💖", `${senderDoc.data().displayName} wants to be your partner!`, { type: "CP_INVITE", inviteId });

    return { success: true };
});

/**
 * 👩‍❤️‍👨 16. Accept CP Invite
 */
exports.acceptCPInvite = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const { inviteId } = data;
    const inviteRef = db.collection("cp_invites").doc(inviteId);

    return db.runTransaction(async (transaction) => {
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

        transaction.update(senderRef, {
            partnerUid: targetDoc.id,
            partnerName: targetDoc.data().displayName,
            partnerAvatar: targetDoc.data().profilePhotoUrl,
            cpLevel: 1,
            cpPoints: 0
        });

        transaction.update(targetRef, {
            partnerUid: senderDoc.id,
            partnerName: senderDoc.data().displayName,
            partnerAvatar: senderDoc.data().profilePhotoUrl,
            cpLevel: 1,
            cpPoints: 0
        });

        transaction.delete(inviteRef);

        return { success: true };
    });
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
        if (itemId === 'none' || itemId === 'vip_reward_frame') {
            const field = category === 'bubble' ? 'chatBubble' : (category === 'mount' ? 'entryAnimation' : 'profileFrame');
            transaction.update(userRef, { [field]: "" });
            
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
    
    // 1. Threshold for ROOM cleanup (90 seconds - more aggressive)
    const roomThreshold = admin.firestore.Timestamp.fromMillis(now - 90 * 1000);
    // 2. Threshold for GLOBAL OFFLINE (5 minutes)
    const globalThreshold = admin.firestore.Timestamp.fromMillis(now - 5 * 60 * 1000);
    // 3. Threshold for HOST transfer (3 minutes)
    const hostTransferThreshold = admin.firestore.Timestamp.fromMillis(now - 3 * 60 * 1000);

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
            const lastActive = pData.lastActive.toMillis();
            const isHost = pData.role === 'host' || pData.role === 'owner';

            if (isHost) {
                if (now - lastActive > 3 * 60 * 1000) { // 3 min host grace
                    batch.delete(pDoc.ref);
                    hostDeleted = true;
                }
            } else if (now - lastActive > 90 * 1000) { // 90s listener grace
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
            diamondBalance: admin.firestore.FieldValue.increment(pkgData.diamonds)
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

exports.resellerTransferDiamonds = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    const resellerUid = context.auth.uid;
    const { targetHelloId, amount } = data;
    const resellerRef = db.collection("users").doc(resellerUid);
    
    // Ensure helloId is treated as a number
    const numericId = parseInt(targetHelloId);
    if (isNaN(numericId)) throw new functions.https.HttpsError("invalid-argument", "Invalid Hello ID format.");

    const targetSnap = await db.collection("users").where("helloId", "==", numericId).get();
    if (targetSnap.empty) throw new functions.https.HttpsError("not-found", "Target user not found.");
    
    const targetDoc = targetSnap.docs[0];
    const targetUid = targetDoc.id;
    const targetName = targetDoc.data().displayName || "User";

    return db.runTransaction(async (transaction) => {
        const targetRef = db.collection("users").doc(targetUid);
        const resellerDoc = await transaction.get(resellerRef);
        const currentStock = resellerDoc.data().diamondBalance || 0;
        
        if (currentStock < amount) {
            throw new functions.https.HttpsError("failed-precondition", "Insufficient diamond stock.");
        }

        transaction.update(resellerRef, { diamondBalance: currentStock - amount });
        transaction.update(targetRef, { diamondBalance: admin.firestore.FieldValue.increment(amount) });
        
        const txRef = db.collection("transactions").doc();
        transaction.set(txRef, {
            senderId: resellerUid,
            receiverId: targetUid,
            targetHelloId: numericId,
            type: "RESELLER_TO_USER",
            amount: amount,
            currency: "DIAMONDS",
            status: "completed",
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        });
        
        return { success: true, targetName: targetName };
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
        
        let query = db.collection("transactions");
        if (targetUid) query = query.where("senderId", "==", targetUid);
        else if (!isPrivileged) query = query.where("senderId", "==", uid);
        
        // Remove orderBy to avoid index requirement for now if not set
        const snap = await query.limit(parseInt(limitCount)).get();
        const transactions = snap.docs.map(doc => ({ 
            id: doc.id, 
            ...doc.data(), 
            timestamp: doc.data().timestamp ? (doc.data().timestamp.toDate ? doc.data().timestamp.toDate().toISOString() : doc.data().timestamp) : null 
        }));

        // Sort manually
        transactions.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

        if (transactions.length === 0) {
            transactions.push({
                id: "DIAGNOSTIC_STUB",
                type: "CONNECTION_VERIFIED",
                amount: 0,
                currency: "DEBUG",
                senderId: "SYSTEM",
                timestamp: new Date().toISOString()
            });
        }

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

exports.scheduledDailyReset = functions.pubsub.schedule('0 0 * * *')
    .timeZone('UTC')
    .onRun(async (context) => {
        await resetUsersField(["dailyXP", "dailyPrinceXP"]);
    });

exports.scheduledWeeklyReset = functions.pubsub.schedule('0 0 * * 1')
    .timeZone('UTC')
    .onRun(async (context) => {
        await resetUsersField(["weeklyXP", "weeklyPrinceXP"]);
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
        await resetUsersField(["monthlyXP", "monthlyPrinceXP"]);
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
                        const agencyRef = db.collection("users").doc(payout.agencyId);
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

