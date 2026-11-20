const {test, after} = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");

if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error("Run with the Firestore emulator.");
admin.initializeApp({projectId: "demo-wheel-banner"});
const db = admin.firestore();
const {settleSpinWheelRound, playSpinWheel, hydrateLuckySpinLeader} = require("../../index.js");
const stats = db.doc("games_meta/lucky_spin");
const rank = stats.collection("daily_players");
const user = db.doc("users/first");
const ctx = {auth: {uid: user.id}};
const outcome = {name: "Carrot", label: "5x", emoji: "🥕", multiplier: 5, type: "standard", category: "salad"};

async function seedRound(roundId, player, bets) {
    const wager = Object.values(bets).reduce((a, b) => a + b, 0);
    const winnings = Number(bets.Carrot || 0) * 5;
    await Promise.all([
        db.doc(`games_meta_private/spin_${roundId}`).set({outcome}),
        player.collection("game_history").doc(`spin_${roundId}`).set({
            totalBet: wager, bets, settled: false,
        }),
        stats.collection("round_player_bets").doc(`${roundId}_${player.id}`).set({
            uid: player.id,
            roundId: String(roundId),
            name: player.id,
            avatar: `${player.id}.jpg`,
            totalBet: wager,
            prize: winnings,
            winnings,
        }),
    ]);
}

test("a legacy leader, retries, a loss, and a new leader use authoritative win receipts", async () => {
    await user.set({diamondBalance: 1000000, displayName: "First", profilePhotoUrl: "first.jpg"});
    await rank.doc(user.id).set({uid: user.id, totalWinnings: 500, totalBets: 100});
    await user.collection("transactions").doc("old_win").set({type: "game_win", game: "spin_wheel"});
    await user.collection("transactions").doc("other_game").set({type: "game_win", game: "lucky_draw"});
    await hydrateLuckySpinLeader.run({}, ctx);
    assert.equal((await rank.doc(user.id).get()).get("totalWins"), 1);

    await seedRound("555", user, {Carrot: 100});
    await Promise.all([0, 1].map(() => settleSpinWheelRound.run({roundId: "555"}, ctx)));
    let row = (await rank.doc(user.id).get()).data();
    assert.equal(row.totalWins, 2);
    assert.equal(row.totalWinnings, 1000);
    assert.equal(row.avatar, "first.jpg");
    const event = (await stats.get()).get("topWinnerEvent");
    assert.equal(event.eventId, "spin_555");
    assert.equal(event.roundId, "555");
    assert.equal(event.winnerUid, user.id);
    assert.equal(event.amount, 500);
    await seedRound("556", user, {Corn: 100});
    await settleSpinWheelRound.run({roundId: "556"}, ctx);
    assert.equal((await rank.doc(user.id).get()).get("totalWins"), 2);

    const next = db.doc("users/next");
    await next.set({diamondBalance: 5000, username: "Second", profilePhotoUrl: "second.jpg"});
    await seedRound("557", next, {Carrot: 1000});
    await settleSpinWheelRound.run({roundId: "557"}, {auth: {uid: next.id}});
    const leader = (await rank.orderBy("totalWinnings", "desc").orderBy("totalBets", "desc").limit(1).get()).docs[0];
    assert.equal(leader.id, next.id);
    assert.equal(leader.get("totalWins"), 1);
    assert.equal(leader.get("name"), "Second");
});

test("automatic recovery records a prior win only once", async () => {
    const player = db.doc("users/recovered");
    await player.set({diamondBalance: 5000, displayName: "Recovered"});
    const round = Math.floor(Date.now() / 40000);
    const previous = String(round - 1);
    await seedRound(previous, player, {Carrot: 100});
    const originalNow = Date.now;
    Date.now = () => round * 40000 + 5000;
    try {
        const context = {auth: {uid: player.id}};
        await playSpinWheel.run({bets: {Corn: 100}}, context);
        await settleSpinWheelRound.run({roundId: previous}, context);
        const row = (await rank.doc(player.id).get()).data();
        assert.equal(row.totalWins, 1);
        assert.equal(row.totalWinnings, 500);
    } finally {
        Date.now = originalNow;
    }
});
after(() => admin.app().delete());
