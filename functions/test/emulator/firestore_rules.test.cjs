const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  collection,
  getDocs,
  query,
  where,
} = require('firebase/firestore');

const PROJECT_ID = 'demo-hellochat';
let testEnv;
let failures = 0;
let passed = 0;

const db = (ctx) => ctx.firestore();
const ref = (ctx, path) => doc(db(ctx), path.split('/').slice(0, -1).join('/'), path.split('/').pop());

async function seed() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const c = db(ctx);
    const users = {
      alice: { role: 'host', displayName: 'Alice', blockedUids: [] },
      bob: { role: 'host', displayName: 'Bob', blockedUids: [] },
      carol: { role: 'host', displayName: 'Carol', blockedUids: [] },
      admin: { role: 'admin', displayName: 'Admin' },
      owner: { role: 'owner', displayName: 'Owner' },
      sa1: { role: 'superadmin', branchId: 'b1', displayName: 'SA1' },
      sa2: { role: 'superadmin', branchId: 'b2', displayName: 'SA2' },
      branchUser1: { role: 'host', branchId: 'b1', displayName: 'B1' },
      branchUser2: { role: 'host', branchId: 'b2', displayName: 'B2' },
      agency: { role: 'agency', agencyId: 'ag1', displayName: 'Agency' },
      agencyHost: { role: 'host', agencyId: 'ag1', displayName: 'Agency Host' },
    };
    for (const [uid, data] of Object.entries(users)) {
      await setDoc(doc(c, 'users', uid), data);
    }
    await setDoc(doc(c, 'publicUsers', 'alice'), { displayName: 'Alice' });
    await setDoc(doc(c, 'chats', 'c1'), { participants: ['alice', 'bob'] });
    await setDoc(doc(c, 'chats', 'c1', 'messages', 'm1'), { text: 'hi', senderUid: 'alice' });
    await setDoc(doc(c, 'gifts', 'g1'), { name: 'Rose', price: 10 });
    await setDoc(doc(c, 'relationships', 'r1'), { participants: ['alice', 'bob'] });
    await setDoc(doc(c, 'relationship_requests', 'rr1'), { senderUid: 'alice', targetUid: 'bob' });
    await setDoc(doc(c, 'cp_invites', 'ci1'), { senderUid: 'alice', targetUid: 'bob' });
    await setDoc(doc(c, 'withdrawals', 'w1'), { uid: 'alice', amount: 10 });
    await setDoc(doc(c, 'commission_transactions', 't1'), { agencyOwnerUid: 'alice', amount: 1 });
  });
}

async function test(name, fn) {
  try {
    await testEnv.clearFirestore();
    await seed();
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
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(resolve(__dirname, '../../../firebase/firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8085,
    },
  });

  const alice = () => testEnv.authenticatedContext('alice');
  const bob = () => testEnv.authenticatedContext('bob');
  const admin = () => testEnv.authenticatedContext('admin');
  const owner = () => testEnv.authenticatedContext('owner');
  const anon = () => testEnv.unauthenticatedContext();

  await test('publicUsers: signed-in can read', async () => {
    await assertSucceeds(getDoc(ref(alice(), 'publicUsers/alice')));
    await assertSucceeds(getDoc(ref(bob(), 'publicUsers/alice')));
  });

  await test('publicUsers: anonymous cannot read', async () => {
    await assertFails(getDoc(ref(anon(), 'publicUsers/alice')));
  });

  await test('publicUsers: clients cannot write, even admin', async () => {
    await assertFails(setDoc(ref(alice(), 'publicUsers/alice'), { displayName: 'X' }));
    await assertFails(setDoc(ref(admin(), 'publicUsers/alice'), { displayName: 'X' }));
  });

  await test('users: self read allowed', async () => {
    await assertSucceeds(getDoc(ref(alice(), 'users/alice')));
  });

  await test('users: unrelated user read denied', async () => {
    await assertFails(getDoc(ref(bob(), 'users/alice')));
  });

  await test('users: anonymous read denied', async () => {
    await assertFails(getDoc(ref(anon(), 'users/alice')));
  });

  await test('users: self may update displayName', async () => {
    await assertSucceeds(updateDoc(ref(alice(), 'users/alice'), { displayName: 'Alice 2' }));
  });

  await test('users: self cannot mint diamondBalance', async () => {
    await assertFails(updateDoc(ref(alice(), 'users/alice'), { diamondBalance: 999999 }));
  });

  await test('users: self cannot self-assign role', async () => {
    await assertFails(updateDoc(ref(alice(), 'users/alice'), { role: 'owner' }));
  });

  await test('users: self may request verification (pending)', async () => {
    await assertSucceeds(updateDoc(ref(alice(), 'users/alice'), { verificationStatus: 'pending' }));
  });

  await test('users: self cannot self-verify', async () => {
    await assertFails(updateDoc(ref(alice(), 'users/alice'), { verificationStatus: 'verified' }));
  });

  await test('users: owner can read anyone', async () => {
    await assertSucceeds(getDoc(ref(owner(), 'users/alice')));
  });

  await test('users: superadmin reads own branch only', async () => {
    await assertSucceeds(getDoc(ref(testEnv.authenticatedContext('sa1'), 'users/branchUser1')));
    await assertFails(getDoc(ref(testEnv.authenticatedContext('sa1'), 'users/branchUser2')));
  });

  await test('users: agency reads only its own hosts', async () => {
    await assertSucceeds(getDoc(ref(testEnv.authenticatedContext('agency'), 'users/agencyHost')));
    await assertFails(getDoc(ref(testEnv.authenticatedContext('agency'), 'users/bob')));
  });

  await test('chats: participant can read, outsider denied', async () => {
    await assertSucceeds(getDoc(ref(alice(), 'chats/c1')));
    await assertFails(getDoc(ref(testEnv.authenticatedContext('carol'), 'chats/c1')));
    await assertFails(getDoc(ref(anon(), 'chats/c1')));
  });

  await test('chats: create requires self in participants', async () => {
    await assertSucceeds(
      setDoc(ref(alice(), 'chats/new1'), { participants: ['alice', 'bob'] })
    );
    await assertFails(
      setDoc(ref(alice(), 'chats/new2'), { participants: ['bob', 'carol'] })
    );
  });

  await test('chat messages: participant writes, outsider denied', async () => {
    await assertSucceeds(
      setDoc(ref(alice(), 'chats/c1/messages/m2'), { text: 'hello', senderUid: 'alice' })
    );
    await assertFails(
      setDoc(ref(testEnv.authenticatedContext('carol'), 'chats/c1/messages/m3'), {
        text: 'intruder',
        senderUid: 'carol',
      })
    );
  });

  await test('chat messages: blocks are enforced server-side in both directions', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(db(ctx), 'users', 'bob'), { blockedUids: ['alice'] });
    });
    await assertFails(
      setDoc(ref(alice(), 'chats/c1/messages/m4'), { text: 'blocked?', senderUid: 'alice' })
    );
    await assertFails(
      setDoc(ref(bob(), 'chats/c1/messages/m5'), { text: 'blocked?', senderUid: 'bob' })
    );
    await assertSucceeds(getDoc(ref(alice(), 'chats/c1/messages/m1')));
  });

  await test('gifts: public read, user/admin write split', async () => {
    await assertSucceeds(getDoc(ref(anon(), 'gifts/g1')));
    await assertFails(setDoc(ref(alice(), 'gifts/g2'), { name: 'Hack', price: 0 }));
    await assertSucceeds(setDoc(ref(admin(), 'gifts/g2'), { name: 'Rose', price: 10 }));
  });

  await test('relationships: participant read only, clients cannot write', async () => {
    await assertSucceeds(getDoc(ref(alice(), 'relationships/r1')));
    await assertFails(getDoc(ref(testEnv.authenticatedContext('carol'), 'relationships/r1')));
    await assertFails(setDoc(ref(alice(), 'relationships/r2'), { participants: ['alice', 'carol'] }));
  });

  await test('friend requests: read scoped, direct writes blocked', async () => {
    await assertSucceeds(getDoc(ref(alice(), 'relationship_requests/rr1')));
    await assertSucceeds(getDoc(ref(bob(), 'relationship_requests/rr1')));
    await assertFails(getDoc(ref(testEnv.authenticatedContext('carol'), 'relationship_requests/rr1')));
    await assertFails(
      setDoc(ref(alice(), 'relationship_requests/rr2'), { senderUid: 'alice', targetUid: 'carol' })
    );
    await assertFails(updateDoc(ref(bob(), 'relationship_requests/rr1'), { status: 'accepted' }));
  });

  await test('cp invites: read scoped, direct writes blocked', async () => {
    await assertSucceeds(getDoc(ref(bob(), 'cp_invites/ci1')));
    await assertFails(getDoc(ref(testEnv.authenticatedContext('carol'), 'cp_invites/ci1')));
    await assertFails(
      setDoc(ref(alice(), 'cp_invites/ci2'), { senderUid: 'alice', targetUid: 'carol' })
    );
    await assertFails(updateDoc(ref(bob(), 'cp_invites/ci1'), { status: 'accepted' }));
  });

  await test('withdrawals: own read only, client create denied', async () => {
    await assertSucceeds(getDoc(ref(alice(), 'withdrawals/w1')));
    await assertFails(getDoc(ref(bob(), 'withdrawals/w1')));
    await assertFails(setDoc(ref(alice(), 'withdrawals/w2'), { uid: 'alice', amount: 999 }));
  });

  await test('commission ledger: client writes denied', async () => {
    await assertFails(
      setDoc(ref(alice(), 'commission_transactions/t2'), { agencyOwnerUid: 'alice', amount: 9999 })
    );
  });

  await test('users list: unfiltered dump denied', async () => {
    await assertFails(getDocs(query(collection(db(alice()), 'users'), where('role', '==', 'host'))));
    await assertSucceeds(getDocs(query(collection(db(owner()), 'users'), where('role', '==', 'host'))));
  });

  await testEnv.cleanup();
  console.log(`\n${passed} passed, ${failures} failed`);
  if (failures > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
