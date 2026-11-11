const assert = require('node:assert/strict');

process.env.GCLOUD_PROJECT = 'demo-hellochat';
process.env.GOOGLE_CLOUD_PROJECT = 'demo-hellochat';
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8085';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';

const admin = require('firebase-admin');

const PROJECT = 'demo-hellochat';
const REGION = 'us-central1';
const FIRESTORE_CLEAR = `http://127.0.0.1:8085/emulator/v1/projects/${PROJECT}/databases/(default)/documents`;
const AUTH_CLEAR = `http://127.0.0.1:9099/emulator/v1/projects/${PROJECT}/accounts`;
const AUTH_SIGN_IN = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=demo-key';
const FUNCTIONS_BASE = `http://127.0.0.1:5001/${PROJECT}/${REGION}`;

admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();

let passed = 0;
let failures = 0;

async function reset() {
  await fetch(FIRESTORE_CLEAR, { method: 'DELETE' });
  await fetch(AUTH_CLEAR, { method: 'DELETE' });
  await new Promise((r) => setTimeout(r, 300));
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function ensureAuthUser(uid) {
  try {
    await admin.auth().createUser({ uid });
  } catch (err) {
    if (err.code !== 'auth/uid-already-exists') throw err;
  }
}

async function waitForBaseDoc(uid) {
  for (let i = 0; i < 100; i++) {
    const snap = await db.doc(`users/${uid}`).get();
    if (snap.exists && snap.get('createdAt')) return;
    await sleep(100);
  }
  throw new Error(`createBaseUserDoc never ran for ${uid}`);
}

async function seedUsers(users) {
  const entries = Object.entries(users);
  await Promise.all(entries.map(([uid]) => ensureAuthUser(uid)));
  await Promise.all(entries.map(([uid]) => waitForBaseDoc(uid)));
  await sleep(200);
  const batch = db.batch();
  for (const [index, [uid, data]] of entries.entries()) {
    batch.set(db.collection('users').doc(uid), {
      helloId: 1000 + index,
      displayName: uid,
      profilePhotoUrl: '',
      blockedUids: [],
      ...data,
    });
  }
  await batch.commit();
  await sleep(200);
}

async function tokenFor(uid) {
  await ensureAuthUser(uid);
  const customToken = await admin.auth().createCustomToken(uid);
  const res = await fetch(AUTH_SIGN_IN, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ token: customToken, returnSecureToken: true }),
  });
  const json = await res.json();
  assert.ok(json.idToken, `auth emulator did not return an idToken: ${JSON.stringify(json)}`);
  return json.idToken;
}

async function call(name, token, data) {
  const res = await fetch(`${FUNCTIONS_BASE}/${name}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify({ data }),
  });
  const json = await res.json();
  if (!res.ok || json.error) {
    const err = new Error(json.error?.message || `HTTP ${res.status}`);
    err.status = String(json.error?.status || `http-${res.status}`)
      .toLowerCase()
      .replace(/^functions\//, '')
      .replace(/_/g, '-');
    throw err;
  }
  return json.result;
}

async function expectFail(promise, status, label) {
  let err;
  try {
    await promise;
  } catch (e) {
    err = e;
  }
  assert.ok(err, `${label}: expected failure "${status}" but call succeeded`);
  assert.equal(
    err.status,
    String(status).toLowerCase(),
    `${label}: expected "${status}", got "${err.status}" (${err.message})`
  );
}

async function get(path) {
  const snap = await db.doc(path).get();
  return snap.exists ? snap.data() : null;
}

async function test(name, fn) {
  try {
    await reset();
    await fn();
    passed++;
    console.log(`PASS  ${name}`);
  } catch (err) {
    failures++;
    console.error(`FAIL  ${name}`);
    console.error(`      ${err.message.split('\n')[0]}`);
  }
}

async function main() {
  await fetch(FIRESTORE_CLEAR, { method: 'DELETE' }).catch(() => {});

  await test('checkChatBlock reports mutual blocks and validates input', async () => {
    await seedUsers({
      alice: { displayName: 'Alice', blockedUids: [] },
      bob: { displayName: 'Bob', blockedUids: ['alice'] },
    });
    const aliceToken = await tokenFor('alice');

    const blocked = await call('checkChatBlock', aliceToken, { otherUid: 'bob' });
    assert.deepEqual(blocked, { canSend: false, iBlockedThem: false, theyBlockedMe: true });

    const self = await call('checkChatBlock', aliceToken, { otherUid: 'alice' });
    assert.equal(self.canSend, true);

    const missingPeer = await call('checkChatBlock', aliceToken, { otherUid: 'ghost' });
    assert.equal(missingPeer.canSend, true);

    await expectFail(call('checkChatBlock', aliceToken, {}), 'invalid-argument', 'missing otherUid');
    await expectFail(call('checkChatBlock', null, { otherUid: 'bob' }), 'unauthenticated', 'anonymous');
  });

  await test('referral: redeem pays invitee diamonds and referrer beans atomically', async () => {
    await seedUsers({
      alice: { displayName: 'Alice', referralCode: 'ALICE1', beansBalance: 0 },
      charlie: { displayName: 'Charlie', referralCode: 'CHARLIE1', diamondBalance: 0 },
    });
    const charlieToken = await tokenFor('charlie');

    const result = await call('redeemReferralCode', charlieToken, { code: 'ALICE1' });
    assert.equal(result.success, true);

    const charlie = await get('users/charlie');
    const alice = await get('users/alice');
    assert.equal(charlie.diamondBalance, 50);
    assert.equal(charlie.referredBy, 'alice');
    assert.equal(alice.beansBalance, 100);
    assert.equal(alice.totalReferralEarnings, 100);

    const tx = await db.collection('users/charlie/transactions').get();
    assert.equal(tx.size, 1);
    assert.equal(tx.docs[0].data().type, 'referral_bonus');
  });

  await test('referral: rejects own code, unknown code, and second redemption', async () => {
    await seedUsers({
      alice: { displayName: 'Alice', referralCode: 'ALICE1' },
      bob: { displayName: 'Bob', referralCode: 'BOB1' },
      charlie: { displayName: 'Charlie', referralCode: 'CHARLIE1' },
    });
    const charlieToken = await tokenFor('charlie');

    await expectFail(call('redeemReferralCode', charlieToken, { code: 'CHARLIE1' }), 'invalid-argument', 'own code');
    await expectFail(call('redeemReferralCode', charlieToken, { code: 'NOPE' }), 'not-found', 'unknown code');

    await call('redeemReferralCode', charlieToken, { code: 'ALICE1' });
    await expectFail(call('redeemReferralCode', charlieToken, { code: 'BOB1' }), 'already-exists', 'second redeem');

    const charlie = await get('users/charlie');
    assert.equal(charlie.diamondBalance, 50);
    assert.equal(charlie.referredBy, 'alice');
  });

  await test('referral: concurrent redemptions reward exactly once', async () => {
    await seedUsers({
      alice: { displayName: 'Alice', referralCode: 'ALICE1', beansBalance: 0 },
      bob: { displayName: 'Bob', referralCode: 'BOB1', beansBalance: 0 },
      dave: { displayName: 'Dave', referralCode: 'DAVE1', diamondBalance: 0 },
    });
    const daveToken = await tokenFor('dave');

    const results = await Promise.allSettled([
      call('redeemReferralCode', daveToken, { code: 'ALICE1' }),
      call('redeemReferralCode', daveToken, { code: 'BOB1' }),
    ]);
    const wins = results.filter((r) => r.status === 'fulfilled').length;
    const losses = results.filter((r) => r.status === 'rejected');

    assert.equal(wins, 1, 'exactly one redemption may win');
    assert.equal(losses.length, 1);
    assert.equal(losses[0].reason.status, 'already-exists');

    const dave = await get('users/dave');
    const alice = await get('users/alice');
    const bob = await get('users/bob');
    assert.equal(dave.diamondBalance, 50, 'invitee must not be paid twice');
    assert.ok(
      (alice.beansBalance === 100 && bob.beansBalance === 0) ||
        (bob.beansBalance === 100 && alice.beansBalance === 0),
      'exactly one referrer is paid'
    );
  });

  await test('CP: only the target can accept, accept is atomic and deletes the invite', async () => {
    await seedUsers({
      alice: { displayName: 'Alice', profilePhotoUrl: '' },
      bob: { displayName: 'Bob', profilePhotoUrl: '' },
    });
    const aliceToken = await tokenFor('alice');
    const bobToken = await tokenFor('bob');

    await call('sendCPInvite', aliceToken, { targetUid: 'bob' });
    const invite = await get('cp_invites/alice_bob');
    assert.equal(invite.status, 'pending');

    await expectFail(call('acceptCPInvite', aliceToken, { inviteId: 'alice_bob' }), 'permission-denied', 'sender accepts');
    await call('acceptCPInvite', bobToken, { inviteId: 'alice_bob' });

    const alice = await get('users/alice');
    const bob = await get('users/bob');
    assert.equal(alice.partnerUid, 'bob');
    assert.equal(bob.partnerUid, 'alice');
    assert.equal(await get('cp_invites/alice_bob'), null, 'accepted invite must be deleted');

    const rel = await get('relationships/alice_bob');
    assert.equal(rel.status, 'active');
    assert.equal(rel.type, 'cp');

    await expectFail(call('acceptCPInvite', bobToken, { inviteId: 'alice_bob' }), 'not-found', 'double accept');
  });

  await test('CP: concurrent accepts cannot create two partners', async () => {
    await seedUsers({
      alice: { displayName: 'Alice' },
      carol: { displayName: 'Carol' },
      bob: { displayName: 'Bob' },
    });
    const aliceToken = await tokenFor('alice');
    const carolToken = await tokenFor('carol');
    const bobToken = await tokenFor('bob');

    await call('sendCPInvite', aliceToken, { targetUid: 'bob' });
    await call('sendCPInvite', carolToken, { targetUid: 'bob' });

    const results = await Promise.allSettled([
      call('acceptCPInvite', bobToken, { inviteId: 'alice_bob' }),
      call('acceptCPInvite', bobToken, { inviteId: 'carol_bob' }),
    ]);
    const wins = results.filter((r) => r.status === 'fulfilled').length;
    assert.equal(wins, 1, 'only one CP bond may be created');

    const bob = await get('users/bob');
    assert.ok(bob.partnerUid === 'alice' || bob.partnerUid === 'carol');
    const loserUid = bob.partnerUid === 'alice' ? 'carol' : 'alice';
    const loser = await get(`users/${loserUid}`);
    assert.equal(loser.partnerUid, undefined);

    const pending = await db.collection('cp_invites').get();
    assert.equal(pending.size, 0, 'losing pending invites are cleaned up');
  });

  await test('CP: an existing partner blocks new invites', async () => {
    await seedUsers({
      alice: { displayName: 'Alice', partnerUid: 'zed' },
      bob: { displayName: 'Bob' },
    });
    const aliceToken = await tokenFor('alice');
    await expectFail(call('sendCPInvite', aliceToken, { targetUid: 'bob' }), 'already-exists', 'has partner');
  });

  await test('friendship: rejects self, missing target, blocked sender, duplicate', async () => {
    await seedUsers({
      alice: { displayName: 'Alice' },
      bob: { displayName: 'Bob' },
      carol: { displayName: 'Carol', blockedUids: ['alice'] },
    });
    const aliceToken = await tokenFor('alice');

    await expectFail(call('sendFriendRequest', aliceToken, { targetUid: 'alice' }), 'invalid-argument', 'self');
    await expectFail(call('sendFriendRequest', aliceToken, { targetUid: 'ghost' }), 'not-found', 'missing');
    await expectFail(call('sendFriendRequest', aliceToken, { targetUid: 'carol' }), 'permission-denied', 'blocked');

    await call('sendFriendRequest', aliceToken, { targetUid: 'bob' });
    await expectFail(call('sendFriendRequest', aliceToken, { targetUid: 'bob' }), 'already-exists', 'duplicate');
  });

  await test('friendship: only target accepts; accept is atomic', async () => {
    await seedUsers({
      alice: { displayName: 'Alice', friendsCount: 0 },
      bob: { displayName: 'Bob', friendsCount: 0 },
    });
    const aliceToken = await tokenFor('alice');
    const bobToken = await tokenFor('bob');

    await call('sendFriendRequest', aliceToken, { targetUid: 'bob' });
    await expectFail(call('acceptFriendRequest', aliceToken, { requestId: 'alice_bob' }), 'permission-denied', 'sender accepts');
    await call('acceptFriendRequest', bobToken, { requestId: 'alice_bob' });

    const request = await get('relationship_requests/alice_bob');
    assert.equal(request.status, 'accepted');
    assert.equal((await get('users/alice')).friendsCount, 1);
    assert.equal((await get('users/bob')).friendsCount, 1);
    const rel = await get('relationships/alice_bob');
    assert.equal(rel.status, 'active');
    assert.equal(rel.type, 'friendship');

    await expectFail(call('acceptFriendRequest', bobToken, { requestId: 'alice_bob' }), 'failed-precondition', 'double accept');
  });

  await test('gift: debits sender diamonds and credits receiver beans', async () => {
    await seedUsers({
      alice: { displayName: 'Alice', diamondBalance: 1000 },
      bob: { displayName: 'Bob', beansBalance: 0 },
    });
    await db.doc('gifts/rose').set({ name: 'Rose', priceInDiamonds: 100, category: 'normal' });
    const aliceToken = await tokenFor('alice');

    const result = await call('sendGiftWithCombo', aliceToken, {
      roomId: 'moment1',
      giftId: 'rose',
      quantity: 1,
      isMoment: true,
      targetUid: 'bob',
    });
    assert.equal(result.success, true);

    assert.equal((await get('users/alice')).diamondBalance, 900);
    const bob = await get('users/bob');
    assert.equal(bob.beansBalance, 100);
    assert.equal(bob.totalDiamondsReceived, 100);

    const sentTx = await db.collection('users/alice/transactions').get();
    assert.ok(sentTx.docs.some((d) => d.data().type === 'gift_sent'));
    const recvTx = await db.collection('users/bob/transactions').get();
    assert.ok(recvTx.docs.some((d) => d.data().type === 'gift_received'));
  });

  await test('gift: concurrent sends never overspend', async () => {
    await seedUsers({
      alice: { displayName: 'Alice', diamondBalance: 250 },
      bob: { displayName: 'Bob', beansBalance: 0 },
    });
    await db.doc('gifts/rose').set({ name: 'Rose', priceInDiamonds: 100, category: 'normal' });
    const aliceToken = await tokenFor('alice');

    const results = await Promise.allSettled(
      Array.from({ length: 10 }, () =>
        call('sendGiftWithCombo', aliceToken, {
          roomId: 'moment1',
          giftId: 'rose',
          quantity: 1,
          isMoment: true,
          targetUid: 'bob',
        })
      )
    );
    const wins = results.filter((r) => r.status === 'fulfilled').length;
    assert.equal(wins, 2, '250 diamonds can buy exactly two 100-diamond gifts');

    const alice = await get('users/alice');
    assert.equal(alice.diamondBalance, 50, 'balance must never go negative');
    assert.equal((await get('users/bob')).beansBalance, 200);

    for (const loss of results.filter((r) => r.status === 'rejected')) {
      assert.equal(loss.reason.status, 'failed-precondition');
    }
  });

  await test('gift: rejects lucky, VIP-without-VIP, and self-only targets', async () => {
    await seedUsers({
      alice: { displayName: 'Alice', diamondBalance: 1000 },
      bob: { displayName: 'Bob' },
    });
    await db.doc('gifts/lucky').set({ name: 'Lucky Bell', priceInDiamonds: 10, category: 'lucky' });
    await db.doc('gifts/viprose').set({ name: 'VIP Rose', priceInDiamonds: 10, category: 'vip' });
    await db.doc('gifts/rose').set({ name: 'Rose', priceInDiamonds: 10, category: 'normal' });
    const aliceToken = await tokenFor('alice');

    await expectFail(
      call('sendGiftWithCombo', aliceToken, { roomId: 'm', giftId: 'lucky', quantity: 1, isMoment: true, targetUid: 'bob' }),
      'failed-precondition',
      'lucky gift'
    );
    await expectFail(
      call('sendGiftWithCombo', aliceToken, { roomId: 'm', giftId: 'viprose', quantity: 1, isMoment: true, targetUid: 'bob' }),
      'permission-denied',
      'VIP gift without VIP'
    );
    await expectFail(
      call('sendGiftWithCombo', aliceToken, { roomId: 'm', giftId: 'rose', quantity: 1, isMoment: true, targetUid: 'alice' }),
      'invalid-argument',
      'self gift'
    );
    assert.equal((await get('users/alice')).diamondBalance, 1000);
  });

  await test('withdrawal: verified + minimum enforced', async () => {
    await seedUsers({
      alice: { displayName: 'Alice', beansBalance: 1500, isVerified: false },
    });
    const aliceToken = await tokenFor('alice');

    await expectFail(
      call('withdrawBeans', aliceToken, { amount: 1000, method: 'Bank' }),
      'failed-precondition',
      'unverified'
    );
    await db.doc('users/alice').update({ isVerified: true });
    await expectFail(
      call('withdrawBeans', aliceToken, { amount: 999, method: 'Bank' }),
      'invalid-argument',
      'below minimum'
    );
    assert.equal((await get('users/alice')).beansBalance, 1500);
  });

  await test('withdrawal: concurrent requests cannot double-spend beans', async () => {
    await seedUsers({
      alice: { displayName: 'Alice', beansBalance: 1500, isVerified: true },
    });
    const aliceToken = await tokenFor('alice');

    const results = await Promise.allSettled([
      call('withdrawBeans', aliceToken, { amount: 1000, method: 'Bank' }),
      call('withdrawBeans', aliceToken, { amount: 1000, method: 'Bank' }),
    ]);
    const wins = results.filter((r) => r.status === 'fulfilled').length;
    assert.equal(wins, 1, 'only one 1000-bean withdrawal is affordable');

    const alice = await get('users/alice');
    assert.equal(alice.beansBalance, 500);
    const withdrawals = await db.collection('withdrawals').get();
    assert.equal(withdrawals.size, 1);
    assert.equal(withdrawals.docs[0].data().amount, 1000);
  });

  console.log(`\n${passed} passed, ${failures} failed`);
  await admin.app().delete();
  if (failures > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
