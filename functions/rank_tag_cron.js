const functions = require('firebase-functions');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

/**
 * Recalculates Top 10 Room Rank Tags for Daily, Weekly, and Monthly cycles.
 */
async function calculateTopRoomRankTags(periodDays, periodLabel) {
  try {
    console.log(`Starting Top Room Rank Tag calculation for ${periodLabel}...`);
    const now = Date.now();
    const startTime = now - (periodDays * 24 * 60 * 60 * 1000);

    // Query diamond intake transactions for rooms in the timeframe
    const snapshot = await db.collection('room_diamond_transactions')
      .where('timestamp', '>=', startTime)
      .get();

    const roomTotals = {};
    const roomEarliestAchieved = {};

    snapshot.forEach(doc => {
      const data = doc.data();
      const roomId = data.roomId;
      const amount = data.amount || 0;
      const ts = data.timestamp || now;

      if (!roomId) return;
      roomTotals[roomId] = (roomTotals[roomId] || 0) + amount;
      if (!roomEarliestAchieved[roomId] || ts < roomEarliestAchieved[roomId]) {
        roomEarliestAchieved[roomId] = ts;
      }
    });

    // Sort rooms descending by amount, tie-break by earliest timestamp
    const sortedRooms = Object.keys(roomTotals).sort((a, b) => {
      if (roomTotals[b] !== roomTotals[a]) {
        return roomTotals[b] - roomTotals[a];
      }
      return (roomEarliestAchieved[a] || 0) - (roomEarliestAchieved[b] || 0);
    });

    const top10 = sortedRooms.slice(0, 10);
    const tagField = `${periodLabel.toLowerCase()}TopRoomTag`;

    // Reset old tags
    const oldTaggedRooms = await db.collection('rooms')
      .where(tagField, '!=', null)
      .get();

    const batch = db.batch();
    oldTaggedRooms.forEach(doc => {
      batch.update(doc.ref, { [tagField]: FieldValue.delete() });
    });

    // Assign new Top 1-10 tags
    top10.forEach((roomId, index) => {
      const rank = index + 1;
      const tagText = `${periodLabel} Top ${rank}`;
      const roomRef = db.collection('rooms').doc(roomId);
      batch.set(roomRef, { [tagField]: tagText }, { merge: true });
    });

    await batch.commit();
    console.log(`Successfully assigned ${periodLabel} Top Room Rank Tags to ${top10.length} rooms.`);
  } catch (err) {
    console.error(`Error in calculateTopRoomRankTags (${periodLabel}):`, err);
  }
}

/**
 * Recalculates Top 10 Receiver Rank Tags for Daily and Weekly cycles.
 */
async function calculateTopReceiverRankTags(periodDays, periodLabel) {
  try {
    console.log(`Starting Top Receiver Rank Tag calculation for ${periodLabel}...`);
    const now = Date.now();
    const startTime = now - (periodDays * 24 * 60 * 60 * 1000);

    const snapshot = await db.collection('gift_transactions')
      .where('createdAt', '>=', admin.firestore.Timestamp.fromMillis(startTime))
      .get();

    const userTotals = {};
    const userEarliest = {};

    snapshot.forEach(doc => {
      const data = doc.data();
      const receiverId = data.receiverId;
      const amount = data.diamondAmount || 0;
      const ts = data.createdAt ? data.createdAt.toMillis() : now;

      if (!receiverId) return;
      userTotals[receiverId] = (userTotals[receiverId] || 0) + amount;
      if (!userEarliest[receiverId] || ts < userEarliest[receiverId]) {
        userEarliest[receiverId] = ts;
      }
    });

    const sortedUsers = Object.keys(userTotals).sort((a, b) => {
      if (userTotals[b] !== userTotals[a]) {
        return userTotals[b] - userTotals[a];
      }
      return (userEarliest[a] || 0) - (userEarliest[b] || 0);
    });

    const top10 = sortedUsers.slice(0, 10);
    const tagField = `${periodLabel.toLowerCase()}ReceiverRankTag`;

    const oldTaggedUsers = await db.collection('users')
      .where(tagField, '!=', null)
      .get();

    const batch = db.batch();
    oldTaggedUsers.forEach(doc => {
      batch.update(doc.ref, { [tagField]: admin.firestore.FieldValue.delete() });
    });

    top10.forEach((uid, index) => {
      const rank = index + 1;
      const tagText = `${periodLabel} Top ${rank}`;
      const userRef = db.collection('users').doc(uid);
      batch.set(userRef, { [tagField]: tagText }, { merge: true });
    });

    await batch.commit();
    console.log(`Successfully assigned ${periodLabel} Top Receiver Rank Tags.`);
  } catch (err) {
    console.error(`Error in calculateTopReceiverRankTags (${periodLabel}):`, err);
  }
}

/**
 * Recalculates Top 10 Sender Rank Tags for Daily, Weekly, and Monthly cycles.
 */
async function calculateTopSenderRankTags(periodDays, periodLabel) {
  try {
    console.log(`Starting Top Sender Rank Tag calculation for ${periodLabel}...`);
    const now = Date.now();
    const startTime = now - (periodDays * 24 * 60 * 60 * 1000);

    const snapshot = await db.collection('gift_transactions')
      .where('createdAt', '>=', admin.firestore.Timestamp.fromMillis(startTime))
      .get();

    const userTotals = {};
    const userEarliest = {};

    snapshot.forEach(doc => {
      const data = doc.data();
      const senderId = data.senderId;
      const amount = data.diamondAmount || 0;
      const ts = data.createdAt ? data.createdAt.toMillis() : now;

      if (!senderId) return;
      userTotals[senderId] = (userTotals[senderId] || 0) + amount;
      if (!userEarliest[senderId] || ts < userEarliest[senderId]) {
        userEarliest[senderId] = ts;
      }
    });

    const sortedUsers = Object.keys(userTotals).sort((a, b) => {
      if (userTotals[b] !== userTotals[a]) {
        return userTotals[b] - userTotals[a];
      }
      return (userEarliest[a] || 0) - (userEarliest[b] || 0);
    });

    const top10 = sortedUsers.slice(0, 10);
    const tagField = `${periodLabel.toLowerCase()}SenderRankTag`;

    const oldTaggedUsers = await db.collection('users')
      .where(tagField, '!=', null)
      .get();

    const batch = db.batch();
    oldTaggedUsers.forEach(doc => {
      batch.update(doc.ref, { [tagField]: admin.firestore.FieldValue.delete() });
    });

    top10.forEach((uid, index) => {
      const rank = index + 1;
      const tagText = `${periodLabel} Top ${rank}`;
      const userRef = db.collection('users').doc(uid);
      batch.set(userRef, { [tagField]: tagText }, { merge: true });
    });

    await batch.commit();
    console.log(`Successfully assigned ${periodLabel} Top Sender Rank Tags.`);
  } catch (err) {
    console.error(`Error in calculateTopSenderRankTags (${periodLabel}):`, err);
  }
}

// Scheduled Background Crons
exports.dailyTopRankCron = functions.pubsub.schedule('0 0 * * *').onRun(async (context) => {
  await calculateTopRoomRankTags(1, 'Daily');
  await calculateTopReceiverRankTags(1, 'Daily');
  await calculateTopSenderRankTags(1, 'Daily');
});

exports.weeklyTopRankCron = functions.pubsub.schedule('0 0 * * 0').onRun(async (context) => {
  await calculateTopRoomRankTags(7, 'Weekly');
  await calculateTopReceiverRankTags(7, 'Weekly');
  await calculateTopSenderRankTags(7, 'Weekly');
});

exports.monthlyTopRankCron = functions.pubsub.schedule('0 0 1 * *').onRun(async (context) => {
  await calculateTopRoomRankTags(30, 'Monthly');
  await calculateTopSenderRankTags(30, 'Monthly');
});
