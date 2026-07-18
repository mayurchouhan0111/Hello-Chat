/**
 * Tests for Room Kick/Ban cloud functions
 *
 * Run: npm test
 */

// Use var (not const/let) because jest.mock is hoisted above const/let TDZ
var FieldValue = {
  serverTimestamp: () => 'SERVER_TIMESTAMP',
  increment: (n) => ({ __increment: n }),
  arrayUnion: (items) => ({ __arrayUnion: items }),
  arrayRemove: (items) => ({ __arrayRemove: items }),
  delete: () => 'FIELD_DELETE',
};

var Timestamp = {
  now: () => ({ toDate: () => new Date(), seconds: 0, nanoseconds: 0 }),
  fromDate: (d) => ({ toDate: () => d, seconds: Math.floor(d.getTime() / 1000), nanoseconds: 0 }),
};

var mockFieldValue = { arrayUnion: jest.fn(), serverTimestamp: jest.fn(), delete: jest.fn(), increment: jest.fn(), arrayRemove: jest.fn() };
var mockTimestamp = { now: jest.fn(), fromDate: jest.fn(), toDate: jest.fn() };
var mockDb = {
  collection: jest.fn(),
  runTransaction: jest.fn(),
  FieldValue: mockFieldValue,
  Timestamp: mockTimestamp,
};

jest.mock('firebase-admin', () => {
  var fn = function() { return mockDb; };
  Object.defineProperties(fn, {
    FieldValue: { get: function() { return mockFieldValue; } },
    Timestamp: { get: function() { return mockTimestamp; } },
  });
  return {
    initializeApp: jest.fn(),
    credential: { applicationDefault: jest.fn() },
    firestore: fn,
  };
});

jest.mock('firebase-functions', () => {
  const mockHttpsError = function (code, message) {
    this.code = code;
    this.message = message;
  };
  const mockOnRequest = (fn) => fn;
  const mockRegion = () => ({
    https: { onCall: (fn) => fn, onRequest: mockOnRequest },
  });
  return {
    https: { onCall: (fn) => fn, onRequest: mockOnRequest, HttpsError: mockHttpsError },
    pubsub: { schedule: () => ({ timeZone: () => ({ onRun: (fn) => fn }), onRun: (fn) => fn }) },
    firestore: { document: () => ({ onWrite: (fn) => fn, onUpdate: (fn) => fn, onCreate: (fn) => fn, onDelete: (fn) => fn }) },
    auth: { user: () => ({ onCreate: (fn) => fn, onDelete: (fn) => fn }) },
    region: mockRegion,
    runWith: () => mockRegion(),
  };
});

const mod = require('./index.js');

const docSnap = (exists, dataFn) => ({ exists, data: dataFn });

// Helper: expect a promise to reject with an HttpsError-like object
function expectRejects(promise, msg) {
  return promise.then(
    () => { throw new Error('Expected promise to reject but it resolved'); },
    (err) => { expect(err.message).toContain(msg); }
  );
}

beforeAll(() => {
  mockTimestamp.now.mockReturnValue({ toDate: () => new Date() });
  mockTimestamp.fromDate.mockReturnValue({ toDate: () => new Date() });
});

describe('roomKickUser', () => {
  function setupTx(mockGet) {
    const tx = {
      get: mockGet,
      update: jest.fn(),
      delete: jest.fn(),
      set: jest.fn(),
    };
    mockDb.runTransaction = jest.fn((cb) => cb(tx));
    mockDb.collection = jest.fn(() => ({
      doc: (id) => ({
        path: `rooms/${id}`,
        collection: (sub) => ({
          doc: (subId) => ({ path: `rooms/${id}/${sub}/${subId}` }),
        }),
      }),
    }));
    return tx;
  }

  test('throws if not authenticated', async () => {
    return expectRejects(
      mod.roomKickUser({ roomId: 'room1', targetUid: 'target1' }, {}),
      'Auth required'
    );
  });

  test('throws if roomId or targetUid missing', async () => {
    await expectRejects(mod.roomKickUser({}, { auth: { uid: 'owner1' } }), 'roomId and targetUid are required');
    await expectRejects(mod.roomKickUser({ roomId: 'room1' }, { auth: { uid: 'owner1' } }), 'roomId and targetUid are required');
  });

  test('throws if room not found', async () => {
    setupTx(jest.fn().mockResolvedValue(docSnap(false, () => ({}))));
    await expectRejects(mod.roomKickUser({ roomId: 'room1', targetUid: 'target1' }, { auth: { uid: 'owner1' } }), 'Room not found');
  });

  test('throws if requester is not owner, admin, or moderator', async () => {
    setupTx(jest.fn()
      .mockResolvedValueOnce(docSnap(true, () => ({ ownerUid: 'owner1', admins: [], moderators: [], bannedUids: [], banExpiries: {} })))
      .mockResolvedValueOnce(docSnap(true, () => ({ vipTier: 'none', vipExpiry: null })))
      .mockResolvedValueOnce(docSnap(true, () => ({ tags: [] }))));
    await expectRejects(mod.roomKickUser({ roomId: 'room1', targetUid: 'target1' }, { auth: { uid: 'stranger' } }), 'Only room owner');
  });

  test('owner can kick a user', async () => {
    const tx = setupTx(jest.fn()
      .mockResolvedValueOnce(docSnap(true, () => ({ ownerUid: 'owner1', admins: [], moderators: [], bannedUids: [], banExpiries: {} })))
      .mockResolvedValueOnce(docSnap(true, () => ({ vipTier: 'none', vipExpiry: null })))
      .mockResolvedValueOnce(docSnap(true, () => ({ tags: [] })))
      .mockResolvedValueOnce(docSnap(true, () => ({ displayName: 'TargetUser' }))));
    const result = await mod.roomKickUser({ roomId: 'room1', targetUid: 'target1' }, { auth: { uid: 'owner1' } });
    expect(result.success).toBe(true);
    expect(tx.update).toHaveBeenCalled();
    expect(tx.delete).toHaveBeenCalled();
    expect(tx.set).toHaveBeenCalledTimes(2);
  });

  test('admin can kick a user', async () => {
    const tx = setupTx(jest.fn()
      .mockResolvedValueOnce(docSnap(true, () => ({ ownerUid: 'owner1', admins: ['admin1'], moderators: [], bannedUids: [], banExpiries: {} })))
      .mockResolvedValueOnce(docSnap(true, () => ({ vipTier: 'none', vipExpiry: null })))
      .mockResolvedValueOnce(docSnap(true, () => ({ tags: [] })))
      .mockResolvedValueOnce(docSnap(true, () => ({ displayName: 'TargetUser' }))));
    const result = await mod.roomKickUser({ roomId: 'room1', targetUid: 'target1' }, { auth: { uid: 'admin1' } });
    expect(result.success).toBe(true);
  });

  test('moderator can kick a user', async () => {
    const tx = setupTx(jest.fn()
      .mockResolvedValueOnce(docSnap(true, () => ({ ownerUid: 'owner1', admins: [], moderators: ['mod1'], bannedUids: [], banExpiries: {} })))
      .mockResolvedValueOnce(docSnap(true, () => ({ vipTier: 'none', vipExpiry: null })))
      .mockResolvedValueOnce(docSnap(true, () => ({ tags: [] })))
      .mockResolvedValueOnce(docSnap(true, () => ({ displayName: 'TargetUser' }))));
    const result = await mod.roomKickUser({ roomId: 'room1', targetUid: 'target1' }, { auth: { uid: 'mod1' } });
    expect(result.success).toBe(true);
  });

  test('throws if VIP 7 user has active kick protection', async () => {
    const futureDate = new Date(Date.now() + 86400000);
    setupTx(jest.fn()
      .mockResolvedValueOnce(docSnap(true, () => ({ ownerUid: 'owner1', admins: [], moderators: [], bannedUids: [], banExpiries: {} })))
      .mockResolvedValueOnce(docSnap(true, () => ({ vipTier: 'VIP 7', vipExpiry: { toDate: () => futureDate } })))
      .mockResolvedValueOnce(docSnap(true, () => ({ tags: [] }))));
    await expectRejects(mod.roomKickUser({ roomId: 'room1', targetUid: 'target1' }, { auth: { uid: 'owner1' } }), 'VIP 7 users have kick protection');
  });

  test('throws if VIP 8 user has active kick protection', async () => {
    const futureDate = new Date(Date.now() + 86400000);
    setupTx(jest.fn()
      .mockResolvedValueOnce(docSnap(true, () => ({ ownerUid: 'owner1', admins: [], moderators: [], bannedUids: [], banExpiries: {} })))
      .mockResolvedValueOnce(docSnap(true, () => ({ vipTier: 'VIP 8', vipExpiry: { toDate: () => futureDate } })))
      .mockResolvedValueOnce(docSnap(true, () => ({ tags: [] }))));
    await expectRejects(mod.roomKickUser({ roomId: 'room1', targetUid: 'target1' }, { auth: { uid: 'owner1' } }), 'VIP 8 users have kick protection');
  });

  test('allows kick if VIP 7 has expired protection', async () => {
    const pastDate = new Date(Date.now() - 86400000);
    const tx = setupTx(jest.fn()
      .mockResolvedValueOnce(docSnap(true, () => ({ ownerUid: 'owner1', admins: [], moderators: [], bannedUids: [], banExpiries: {} })))
      .mockResolvedValueOnce(docSnap(true, () => ({ vipTier: 'VIP 7', vipExpiry: { toDate: () => pastDate } })))
      .mockResolvedValueOnce(docSnap(true, () => ({ tags: [] })))
      .mockResolvedValueOnce(docSnap(true, () => ({ displayName: 'TargetUser' }))));
    const result = await mod.roomKickUser({ roomId: 'room1', targetUid: 'target1' }, { auth: { uid: 'owner1' } });
    expect(result.success).toBe(true);
  });

  test('stores banExpiry when duration is provided', async () => {
    const tx = setupTx(jest.fn()
      .mockResolvedValueOnce(docSnap(true, () => ({ ownerUid: 'owner1', admins: [], moderators: [], bannedUids: [], banExpiries: {} })))
      .mockResolvedValueOnce(docSnap(true, () => ({ vipTier: 'none', vipExpiry: null })))
      .mockResolvedValueOnce(docSnap(true, () => ({ tags: [] })))
      .mockResolvedValueOnce(docSnap(true, () => ({ displayName: 'TargetUser' }))));
    const result = await mod.roomKickUser(
      { roomId: 'room1', targetUid: 'target1', duration: 60, reason: 'Spamming' },
      { auth: { uid: 'owner1' } }
    );
    expect(result.success).toBe(true);
    expect(tx.update.mock.calls.some((c) => JSON.stringify(c[1]).includes('banExpiries'))).toBe(true);
  });

  test('stores reason in kick log', async () => {
    const tx = setupTx(jest.fn()
      .mockResolvedValueOnce(docSnap(true, () => ({ ownerUid: 'owner1', admins: [], moderators: [], bannedUids: [], banExpiries: {} })))
      .mockResolvedValueOnce(docSnap(true, () => ({ vipTier: 'none', vipExpiry: null })))
      .mockResolvedValueOnce(docSnap(true, () => ({ tags: [] })))
      .mockResolvedValueOnce(docSnap(true, () => ({ displayName: 'TargetUser' }))));
    const result = await mod.roomKickUser(
      { roomId: 'room1', targetUid: 'target1', reason: 'Inappropriate behavior' },
      { auth: { uid: 'owner1' } }
    );
    expect(result.success).toBe(true);
    expect(tx.set.mock.calls.some(([r, d]) => d.reason === 'Inappropriate behavior' && d.action === 'kick')).toBe(true);
  });
});

describe('roomUnbanUser', () => {
  test('throws if not authenticated', async () => {
    await expectRejects(mod.roomUnbanUser({ roomId: 'room1', targetUid: 'target1' }, {}), 'Auth required');
  });

  test('throws if room not found', async () => {
    mockDb.collection = jest.fn(() => ({ doc: jest.fn(() => ({ ['get']: jest.fn(() => Promise.resolve(docSnap(false, () => {}))) })) }));
    await expectRejects(mod.roomUnbanUser({ roomId: 'room1', targetUid: 'target1' }, { auth: { uid: 'owner1' } }), 'Room not found');
  });

  test('throws if not owner or admin', async () => {
    mockDb.collection = jest.fn(() => ({ doc: jest.fn(() => ({ ['get']: jest.fn(() => Promise.resolve(docSnap(true, () => ({ ownerUid: 'owner1', admins: [] })))) })) }));
    await expectRejects(mod.roomUnbanUser({ roomId: 'room1', targetUid: 'target1' }, { auth: { uid: 'stranger' } }), 'Only room owner');
  });

  test('owner can unban a user', async () => {
    const updateMock = jest.fn(() => Promise.resolve());
    const collectionMock = jest.fn(() => {
      const docFn = jest.fn(() => {
        const getFn = jest.fn(() => Promise.resolve(docSnap(true, () => ({ ownerUid: 'owner1', admins: [] }))));
        return { ['get']: getFn, update: updateMock };
      });
      return { doc: docFn };
    });
    mockDb.collection = collectionMock;
    const result = await mod.roomUnbanUser({ roomId: 'room1', targetUid: 'target1' }, { auth: { uid: 'owner1' } });
    expect(result.success).toBe(true);
    expect(updateMock).toHaveBeenCalled();
  });
});

describe('autoUnbanExpiredBans', () => {
  test('processes rooms with expired bans', async () => {
    const expiredDate = new Date(Date.now() - 3600000);
    const activeDate = new Date(Date.now() + 3600000);
    const updateMock = jest.fn(() => Promise.resolve());
    mockDb.collection = jest.fn(() => ({
      where: jest.fn(() => ({
        limit: jest.fn(() => ({
          get: jest.fn(() => Promise.resolve({
            empty: false,
            docs: [{
              id: 'room1',
              data: () => ({ bannedUids: ['user1', 'user2'], banExpiries: { user1: { toDate: () => expiredDate }, user2: { toDate: () => activeDate } } }),
            }],
          })),
        })),
      })),
      doc: jest.fn(() => ({ update: updateMock })),
    }));
    const result = await mod.autoUnbanExpiredBans({});
    expect(result.processed).toBe(1);
    expect(updateMock).toHaveBeenCalled();
  });

  test('handles rooms with no bans gracefully', async () => {
    mockDb.collection = jest.fn(() => ({
      where: jest.fn(() => ({
        limit: jest.fn(() => ({ get: jest.fn(() => Promise.resolve({ empty: true, docs: [] })) })),
      })),
    }));
    const result = await mod.autoUnbanExpiredBans({});
    expect(result).toBeNull();
  });
});
