// Local-only behavioral regression tests. Never connect to production.
const assert = require('node:assert/strict');
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8085';
process.env.GCLOUD_PROJECT = 'demo-client-release';
const admin = require('firebase-admin');
admin.initializeApp({ projectId: 'demo-client-release' });
const db = admin.firestore();
const backend = require('./index.js');
const run = () => backend.executeRoomSupportRewardDistribution({ testing: true });
const prefix = `release_${Date.now()}`;
let passed = 0;
async function check(name, fn) { await fn(); console.log(`PASS ${++passed}: ${name}`); }
async function seed(room, weekId, missing = false) {
  const roomId = `${prefix}_${room}`;
  const owner = `${roomId}_owner`;
  await db.doc(`users/${owner}`).set({ diamondBalance: 100 });
  await db.doc(`rooms/${roomId}`).set({ ownerUid: owner, name: roomId });
  const week = db.doc(`room_support_history/${roomId}/weeks/${weekId}`);
  await week.set({ achievedLevel: 1, totalCoins: 100000, distributionStatus: 'pending' });
  for (let i = 0; i < 4; i++) {
    const uid = `${roomId}_p${i}`;
    await db.doc(`room_support_cycles/${roomId}/partners/${uid}`).set({ uid, cycleWeekId: weekId });
    if (!missing || i !== 0) await db.doc(`users/${uid}`).set({ diamondBalance: 10 });
  }
  return { roomId, owner, week, missingUid: `${roomId}_p0` };
}
async function main() {
  const a = await seed('partial', '2026-W44', true);
  const unrelated = db.doc(`other_feature/${prefix}/partners/unrelated`);
  await unrelated.set({ keep: true });
  const future = db.doc(`room_support_cycles/${a.roomId}/partners/future`);
  await future.set({ uid: 'future', cycleWeekId: '2026-W45' });
  const partialResult = await run();
  assert.equal(partialResult.success, false);
  assert.equal(partialResult.failedCount, 1);
  await check('missing recipient is not recorded as paid', async () => {
    assert.equal((await db.doc(`room_support_rewards/reward_2026-W44_${a.missingUid}`).get()).exists, false);
    assert.equal((await a.week.get()).data().distributionStatus, 'pending');
  });
  await check('partial failure retains assignments and freezes plan', async () => {
    assert.equal((await db.collection(`room_support_cycles/${a.roomId}/partners`).get()).size, 5);
    assert.equal((await a.week.get()).data().payoutPlan.length, 5);
  });
  await db.doc(`users/${a.missingUid}`).set({ diamondBalance: 10 });
  await run();
  await check('retry credits only missing payment and completes week', async () => {
    assert.equal((await db.doc(`users/${a.owner}`).get()).data().diamondBalance, 11350);
    assert.equal((await db.doc(`users/${a.missingUid}`).get()).data().diamondBalance, 1885);
    assert.equal((await a.week.get()).data().distributionStatus, 'distributed');
  });
  await check('cleanup preserves future and unrelated partner records', async () => {
    assert.equal((await future.get()).exists, true);
    assert.equal((await unrelated.get()).exists, true);
  });
  await run();
  await check('repeat invocation cannot credit twice', async () => {
    assert.equal((await db.doc(`users/${a.owner}`).get()).data().diamondBalance, 11350);
    assert.equal((await db.collection(`users/${a.owner}/transactions`).get()).size, 1);
  });
  const b = await seed('concurrent', '2026-W44');
  await Promise.all([run(), run()]);
  await check('concurrent invocations credit exactly once', async () => {
    assert.equal((await db.doc(`users/${b.owner}`).get()).data().diamondBalance, 11350);
    assert.equal((await db.collection(`users/${b.owner}/transactions`).get()).size, 1);
  });
  await check('ordinary user cannot bypass salary schedule', async () => {
    await assert.rejects(backend.processRoomSupportSalary.run({ testing: true, bypassDayCheck: true }, { auth: { uid: a.owner } }), e => e.code === 'permission-denied');
  });
  await check('retry success resolves original failure', async () => {
    assert.equal((await db.doc(`salary_failed_transactions/failed_2026-W44_${a.missingUid}`).get()).data().resolved, true);
  });
  const c = await seed('admin_retry', '2026-W44', true);
  await run();
  const staffUid = `${prefix}_staff`;
  await db.doc(`users/${staffUid}`).set({ role: 'admin' });
  const failureId = `failed_2026-W44_${c.missingUid}`;
  await check('admin retry also rejects a missing recipient', async () => {
    await assert.rejects(backend.retryFailedSalaryPayout.run({ failedId: failureId }, { auth: { uid: staffUid } }), e => e.code === 'not-found');
    assert.equal((await db.doc(`salary_failed_transactions/${failureId}`).get()).data().resolved, false);
  });
  await db.doc(`users/${c.missingUid}`).set({ diamondBalance: 10 });
  await Promise.all([0, 1].map(() => backend.retryFailedSalaryPayout.run({ failedId: failureId }, { auth: { uid: staffUid } })));
  await check('concurrent admin retries credit once and preserve wallet history', async () => {
    assert.equal((await db.doc(`users/${c.missingUid}`).get()).data().diamondBalance, 1885);
    assert.equal((await db.collection(`users/${c.missingUid}/transactions`).get()).size, 1);
  });
  const paid = await db.doc(`salary_transactions/reward_2026-W44_${c.missingUid}`).get();
  await backend.retryFailedSalaryPayout.run({ failedId: failureId }, { auth: { uid: staffUid } });
  await check('repeated admin retry leaves original payment audit unchanged', async () => {
    const after = await db.doc(`salary_transactions/reward_2026-W44_${c.missingUid}`).get();
    assert.equal(after.data().createdAt.toMillis(), paid.data().createdAt.toMillis());
  });
  console.log(`${passed} salary release checks passed`);
}
main().then(() => db.terminate()).catch(e => { console.error(e); process.exitCode = 1; db.terminate(); });
