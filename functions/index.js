const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

/**
 * 1. onCreate Auth User Trigger
 * Creates a basic skeletal user document when they sign up.
 */
exports.createBaseUserDoc = functions.auth.user().onCreate(async (user) => {
    const { uid, phoneNumber, email, displayName, photoURL } = user;
    
    const userRef = db.collection("users").doc(uid);
    
    return userRef.set({
        uid: uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        phoneNumber: phoneNumber || null,
        email: email || null,
        username: "", // empty, user must set this in profile setup
        displayName: displayName || "New User",
        bio: "",
        country: "",
        profilePhotoUrl: photoURL || "",
        diamondBalance: 0,
        beansBalance: 0,
        xp: 0,
        benchXP: 0,
        princeXP: 0,
        level: 1,
        followerCount: 0,
        followingCount: 0,
        status: "offline",
        badges: [],
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

        // If username is changing, verify it's available
        if (userDoc.exists && userDoc.data().username !== cleanUsername) {
            if (usernameDoc.exists) {
                throw new functions.https.HttpsError("already-exists", "Username already taken.");
            }
            // Remove old username if needed (advanced logic)
        }

        transaction.set(usernameRef, { uid: uid, createdAt: admin.firestore.FieldValue.serverTimestamp() });
        transaction.update(userRef, {
            username: cleanUsername,
            displayName: displayName,
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
    const subFollowerRef = targetRef.collection("followers").doc(followerUid);
    const subFollowingRef = followerRef.collection("following").doc(targetUid);

    return db.runTransaction(async (transaction) => {
        const subFollowerDoc = await transaction.get(subFollowerRef);
        if (subFollowerDoc.exists) return { message: "Already following" };

        transaction.set(subFollowerRef, { followedAt: admin.firestore.FieldValue.serverTimestamp() });
        transaction.set(subFollowingRef, { followedAt: admin.firestore.FieldValue.serverTimestamp() });
        
        transaction.update(followerRef, { followingCount: admin.firestore.FieldValue.increment(1) });
        transaction.update(targetRef, { followerCount: admin.firestore.FieldValue.increment(1) });

        return { success: true };
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
    const subFollowerRef = targetRef.collection("followers").doc(followerUid);
    const subFollowingRef = followerRef.collection("following").doc(targetUid);

    return db.runTransaction(async (transaction) => {
        const subFollowerDoc = await transaction.get(subFollowerRef);
        if (!subFollowerDoc.exists) return { message: "Not following" };

        transaction.delete(subFollowerRef);
        transaction.delete(subFollowingRef);
        
        transaction.update(followerRef, { followingCount: admin.firestore.FieldValue.increment(-1) });
        transaction.update(targetRef, { followerCount: admin.firestore.FieldValue.increment(-1) });

        return { success: true };
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
        theme: theme,
        coverUrl: coverUrl || "",
        isPrivate: isPrivate || false,
        passwordHash: passwordHash || null,
        capacity: capacity || 10,
        currentUsersCount: 0,
        backgroundMusic: backgroundMusic || false,
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
        const participantsRef = roomRef.collection("participants");
        
        const roomDoc = await transaction.get(roomRef);
        if (!roomDoc.exists) throw new functions.https.HttpsError("not-found", "Room not found.");
        
        const roomData = roomDoc.data();
        if (roomData.status !== "active") throw new functions.https.HttpsError("failed-precondition", "Room has ended.");
        if (roomData.bannedUids && roomData.bannedUids.includes(uid)) throw new functions.https.HttpsError("permission-denied", "You are banned.");

        // Check if already in
        const participantDoc = await transaction.get(participantRef);
        if (participantDoc.exists) return { success: true, message: "Already in room" };

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
            seatIndex: seatIndex,
            isMuted: false,
            role: role,
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
exports.sendGiftWithCombo = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    const { roomId, giftId, targetUid, quantity } = data;
    const senderUid = context.auth.uid;
    const qty = quantity || 1;

    return db.runTransaction(async (transaction) => {
        const senderRef = db.collection("users").doc(senderUid);
        const receiverRef = db.collection("users").doc(targetUid);
        const roomRef = db.collection("rooms").doc(roomId);
        const giftRef = db.collection("gifts").doc(giftId);
        const msgRef = roomRef.collection("messages").doc();

        const [senderDoc, receiverDoc, roomDoc, giftDoc] = await Promise.all([
            transaction.get(senderRef),
            transaction.get(receiverRef),
            transaction.get(roomRef),
            transaction.get(giftRef)
        ]);

        if (!senderDoc.exists || !giftDoc.exists) throw new functions.https.HttpsError("not-found", "User or Gift not found.");
        
        const giftData = giftDoc.data();
        const totalCost = giftData.priceInDiamonds * qty;
        const senderData = senderDoc.data();

        if ((senderData.diamondBalance || 0) < totalCost) {
            throw new functions.https.HttpsError("failed-precondition", "Insufficient diamonds.");
        }

        // 1. Deduct from sender, Add XP
        transaction.update(senderRef, {
            diamondBalance: admin.firestore.FieldValue.increment(-totalCost),
            benchXP: admin.firestore.FieldValue.increment(totalCost),
            level: admin.firestore.FieldValue.increment(Math.floor(totalCost / 1000)) // Simple level up logic
        });

        // 2. Add beans to receiver (Gifts convert to beans at 1:1 or 1:0.8 etc), Add XP
        const beansEarned = Math.floor(totalCost * 0.8);
        if (receiverDoc.exists) {
            transaction.update(receiverRef, {
                beansBalance: admin.firestore.FieldValue.increment(beansEarned),
                princeXP: admin.firestore.FieldValue.increment(totalCost)
            });
            
            // Log for receiver
            const receiverTxRef = receiverRef.collection("transactions").doc();
            transaction.set(receiverTxRef, {
                type: "gift_received",
                amount: beansEarned,
                fromUid: senderUid,
                giftId: giftId,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                description: `Received ${qty}x ${giftData.name} from ${senderData.username || "User"}`
            });
        }

        // 3. Log for sender
        const senderTxRef = senderRef.collection("transactions").doc();
        transaction.set(senderTxRef, {
            type: "gift_sent",
            amount: totalCost,
            toUid: targetUid,
            giftId: giftId,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            description: `Sent ${qty}x ${giftData.name} to ${receiverDoc.exists ? receiverDoc.data().username : "User"}`
        });

        // 4. Update PK Battle Score if active
        const roomData = roomDoc.data();
        if (roomData && roomData.pkActive) {
            const side = roomData.pkTeams ? roomData.pkTeams[targetUid] : null;
            if (side) {
                const pkScores = roomData.pkScores || { left: 0, right: 0 };
                pkScores[side] += totalCost;
                transaction.update(roomRef, { pkScores: pkScores });
            }
        }

        // 5. Room Message for Animation
        transaction.set(msgRef, {
            uid: senderUid,
            type: "gift",
            giftId: giftId,
            quantity: qty,
            animationUrl: giftData.lottieAssetPath,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            targetUid: targetUid,
            senderName: senderData.username || "User"
        });

        return { success: true };
    });
});

/**
 * 13. Start PK Battle
 */
exports.startPKBattle = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    const { roomId, leftUid, rightUid, durationSeconds } = data;
    const roomRef = db.collection("rooms").doc(roomId);
    
    const endTime = Date.now() + (durationSeconds || 300) * 1000;

    await roomRef.update({
        pkActive: true,
        pkStartTime: admin.firestore.FieldValue.serverTimestamp(),
        pkEndTime: admin.firestore.Timestamp.fromMillis(endTime),
        pkScores: { left: 0, right: 0 },
        pkTeams: { [leftUid]: "left", [rightUid]: "right" },
        pkWinnerUid: null
    });

    return { success: true };
});

/**
 * 14. End PK Battle & Reward
 */
exports.endPKBattle = functions.https.onCall(async (data, context) => {
    const { roomId } = data;
    const roomRef = db.collection("rooms").doc(roomId);

    return db.runTransaction(async (transaction) => {
        const roomDoc = await transaction.get(roomRef);
        if (!roomDoc.exists || !roomDoc.data().pkActive) return { success: false };

        const roomData = roomDoc.data();
        const scores = roomData.pkScores;
        let winnerUid = null;
        
        const teams = roomData.pkTeams;
        const leftUid = Object.keys(teams).find(k => teams[k] === "left");
        const rightUid = Object.keys(teams).find(k => teams[k] === "right");

        if (scores.left > scores.right) winnerUid = leftUid;
        else if (scores.right > scores.left) winnerUid = rightUid;

        transaction.update(roomRef, {
            pkActive: false,
            pkWinnerUid: winnerUid
        });

        if (winnerUid) {
            // Reward logic (XP boost or extra beans)
            const winnerRef = db.collection("users").doc(winnerUid);
            transaction.update(winnerRef, { 
                beansBalance: admin.firestore.FieldValue.increment(500), // Bonus
                princeXP: admin.firestore.FieldValue.increment(1000)
            });
        }

        return { winnerUid: winnerUid };
    });
});

/**
 * 11. Recharge Diamonds (Sandbox)
 * Cloud-side atomic recharge with transaction logging.
 */
exports.rechargeDiamonds = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    const uid = context.auth.uid;
    const { amount } = data;
    
    if (!amount || amount <= 0) throw new functions.https.HttpsError("invalid-argument", "Positive amount required.");

    const userRef = db.collection("users").doc(uid);
    const txRef = userRef.collection("transactions").doc();

    return db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");

        transaction.update(userRef, { 
            diamondBalance: admin.firestore.FieldValue.increment(amount) 
        });

        transaction.set(txRef, {
            type: "recharge",
            amount: amount,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            description: `Recharge of ◈ ${amount} (Sandbox)`,
        });

        return { success: true };
    });
});

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
 * 13. Feed Sample Gifts
 * Admin-only function to seed initial gifts.
 */
exports.feedSampleGifts = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    // Check if user is Admin or SuperAdmin
    const userDoc = await db.collection("users").doc(context.auth.uid).get();
    const tags = userDoc.data()?.tags || [];
    if (!tags.includes("Admin") && !tags.includes("SuperAdmin")) {
        throw new functions.https.HttpsError("permission-denied", "Admin only.");
    }

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
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    });

    await batch.commit();
    return { success: true, count: gifts.length };
});
/**
 * 15. Feed Sample VIP Tiers
 * Admin-only function to seed initial VIP tiers.
 */
exports.feedSampleVIPTiers = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    // Admin check
    const userDoc = await db.collection("users").doc(context.auth.uid).get();
    const tags = userDoc.data()?.tags || [];
    if (!tags.includes("Admin") && !tags.includes("SuperAdmin")) {
        throw new functions.https.HttpsError("permission-denied", "Admin only.");
    }

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
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
    });

    await batch.commit();
    return { success: true, count: tiers.length };
});

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
        
        const tierData = tierDoc.data();
        const userData = userDoc.data();
        const price = tierData.monthlyPriceInDiamonds;

        if ((userData.diamondBalance || 0) < price) {
            throw new functions.https.HttpsError("failed-precondition", "Insufficient diamonds.");
        }

        // Calculate expiry (30 days)
        const expiry = new Date();
        expiry.setDate(expiry.getDate() + 30);

        transaction.update(userRef, {
            diamondBalance: admin.firestore.FieldValue.increment(-price),
            vipTier: tierData.name,
            vipExpiry: admin.firestore.Timestamp.fromDate(expiry),
            profileFrame: tierData.profileFrame,
            entryAnimation: tierData.entryAnimation,
            badgeIcon: tierData.badgeIcon
        });

        // Log transaction
        const txRef = userRef.collection("transactions").doc();
        transaction.set(txRef, {
            type: "purchase",
            amount: price,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            description: `Purchased ${tierData.name} Monthly Subscription`
        });

        return { success: true };
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
exports.playSpinWheel = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    const { betAmount } = data;
    const uid = context.auth.uid;
    const userRef = db.collection("users").doc(uid);

    return db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");
        
        const balance = userDoc.data().diamondBalance || 0;
        if (balance < betAmount) throw new functions.https.HttpsError("failed-precondition", "Insufficient Diamonds.");

        // Odds & Results Table (Server Side Only)
        const outcomes = [
            { multiplier: 0, label: "0x" },
            { multiplier: 1.2, label: "1.2x" },
            { multiplier: 1.5, label: "1.5x" },
            { multiplier: 2, label: "2x" },
            { multiplier: 0.5, label: "0.5x" },
            { multiplier: 5, label: "5x" },
            { multiplier: 0.2, label: "0.2x" },
            { multiplier: 10, label: "10x" }
        ];

        const winner = outcomes[Math.floor(Math.random() * outcomes.length)];
        const prize = Math.floor(betAmount * winner.multiplier);

        transaction.update(userRef, { 
            diamondBalance: admin.firestore.FieldValue.increment(prize - betAmount) 
        });

        const logRef = userRef.collection("game_history").doc();
        transaction.set(logRef, {
            game: "spin_wheel",
            bet: betAmount,
            prize: prize,
            label: winner.label,
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        });

        return { prize: prize, label: winner.label };
    });
});

/**
 * 22. Secure Games: Lucky Draw
 */
exports.playLuckyDraw = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    const { betAmount } = data;
    const uid = context.auth.uid;
    const userRef = db.collection("users").doc(uid);

    return db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found.");
        
        if ((userDoc.data().diamondBalance || 0) < betAmount) throw new functions.https.HttpsError("failed-precondition", "Insufficient Diamonds.");

        // 1 in 10 chance for 8x prize
        const isWin = Math.random() < 0.1;
        const prize = isWin ? betAmount * 8 : 0;

        transaction.update(userRef, { 
            diamondBalance: admin.firestore.FieldValue.increment(prize - betAmount) 
        });

        const logRef = userRef.collection("game_history").doc();
        transaction.set(logRef, {
            game: "lucky_draw",
            bet: betAmount,
            prize: prize,
            isWin: isWin,
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        });

        return { prize: prize, isWin: isWin };
    });
});
