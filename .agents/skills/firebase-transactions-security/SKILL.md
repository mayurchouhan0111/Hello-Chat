---
name: firebase-transactions-security
description: >-
  Security and correctness rules for Firebase Cloud Functions and Firestore in
  Hello Chat. Enforces atomic multi-document updates via db.runTransaction,
  guards against high-concurrency race conditions (gift sending, rocket fuel
  thresholds, Diamond/Bean balances), requires server-side math (never client
  trust), and mandates safe money/balance handling. Use when writing or editing
  functions/index.js, balance mutations, gift flows, rocket event, withdrawals,
  or any Firestore write that must be atomic.
---

# Firebase Transactions & Security (Hello Chat)

Hard rules for the Cloud Functions backend (`functions/index.js`) and Firestore.
The app is money-adjacent (Diamonds & Beans), so every mutation is financial
logic: treat every balance change as irreversible cash.

## Use this skill when

- Writing or editing callable functions / triggers in `functions/index.js`
- Mutating `diamondBalance`, `beansBalance`, `xp`, wallet, gift, or reward balances
- Implementing rocket event fuel/threshold logic, salary milestones, SVIP levels
- Adding Firestore writes that touch more than one document
- Reviewing existing transaction code for race conditions or atomicity holes

## 1. Atomicity: one operation, many documents

- **Every multi-document mutation must be wrapped in `db.runTransaction`.** A
  single `runTransaction` callback may touch unlimited documents; a single
  `batch()` cannot be used when a decision depends on a read inside the same
  operation.
- The canonical pattern in this repo is:
  ```js
  return db.runTransaction(async (transaction) => {
    const userDoc = await transaction.get(userRef);        // read inside
    const data = userDoc.data();
    if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "...");
    // ... compute, then mutate within the SAME transaction ...
    transaction.update(userRef, { diamondBalance: admin.firestore.FieldValue.increment(-cost) });
  });
  ```
- **Never read a document *outside* the transaction and then write inside it.**
  The read must happen on the `transaction` object (`transaction.get`), or the
  write is not protected against concurrent changes.
- If you must pre-read for validation, re-`transaction.get` inside the callback
  and re-validate; do not trust the pre-read value.

## 2. Use FieldValue.increment for balance math

- Mutate balances with `admin.firestore.FieldValue.increment(...)` (additive,
  atomic) rather than read-then-write absolute values.
- Exception (the repo already does this deliberately): when the computation must
  use the *current* balance to decide a branch (e.g. `userData.diamondBalance || 0`
  for insufficient-balance checks), you must `transaction.get`, check, and only
  then `transaction.update`. This keeps the check+write atomic.
- Never use floating point for currency. Diamonds/Beans are integers — keep
  amounts as integers, compute with `Math.floor`/`Math.round` only at the
  server boundary, and store integers.

## 3. High-concurrency race conditions

Gift sending is high-volume and concurrent. Specific hazards and the repo rules:

- **Rocket fuel / threshold trigger** (`ROCKET_SYSTEM` targets in
  `functions/index.js`): the decision to launch a rocket reads
  `roomData.rocketFuel`, adds `totalCost`, then compares against the target. The
  read, increment, level check, reward distribution, and room-state reset MUST
  all occur inside one `db.runTransaction` so two concurrent gift calls cannot
  both trigger a launch, double-award `king/t2/t3` rewards, or both reset the
  contribution map.
- **Salary milestones** (`SALARY_LEVELS` / `processSalaryMilestones`): the
  `salaryStatus.completedLevels` check must be read inside the transaction (the
  repo preloads the doc, but re-read inside the tx) so two host gifts in flight
  cannot both award the same milestone twice.
- **Top-3 ranking** in the rocket launch: sorting `rocketContributions` and
  awarding `king/t2/t3` must run on the in-transaction view of contributions.
  Never compute rankings from a stale snapshot read outside the transaction.
- **Gift sending** (`sendGift`): deduct sender, credit receiver/agency, update
  XP, PK score, room rocket fuel, and leaderboards in the SAME transaction.
  A partial write (deduct but not credit) is a hard bug.

## 4. Idempotency & retries

- `runTransaction` retries on contention; your callback must be **idempotent** —
  it may run more than once. Do not push notifications, send emails, or call
  external APIs inside the transaction callback. Queue side effects after commit
  (`await` the `runTransaction`, then side-effect).
- For event/record creation that must not duplicate (e.g. reward_logs, vault
  entries), generate the doc id explicitly and guard with a deterministic ID or a
  `createdAt`-keyed check inside the transaction.
- Max 500 writes per transaction and ~10MB — chunk large loops (e.g. mass
  diamond distribution) into batches or paginated transactions, and never read
  an entire collection inside a transaction.

## 5. Server-side math & never trust the client

- **All financial math runs in the Cloud Function.** The client may send intent
  (giftId, roomId) but NEVER the computed amount, reward, or balance delta.
  Compute price, splits (host share, agency share, referral reward), XP, and
  rocket contributions server-side from server-known constants.
- Validate and sanitize every input:
  - Cast and bounds-check numeric inputs (`parseInt`, finite, `>= 0`).
  - Reject `NaN`/`Infinity`/stringified numbers; never `eval` or pass through.
  - Whitelist IDs (giftId, roomId, uid) and check existence before writing.
- Insufficient-balance guard: throw `HttpsError("failed-precondition", ...)`
  BEFORE mutating anything; the transaction then aborts cleanly.

## 6. Security rules & least privilege

- Firestore security rules are the first line of defense: client SDKs must never
  be able to mutate `diamondBalance`/`beansBalance` directly. All balance writes
  go through callable functions (which bypass rules with the Admin SDK).
- Deny client writes to sensitive collections (`users.balance`, `wallet`,
  `salaryStatus`, `room.rocketFuel`, `reward_logs`) in `firestore.rules`; clients
  get read access only to their own data.
- The React admin writes via the Admin SDK / admin endpoint, not raw client
  writes with elevated permissions. See `react-admin-dashboard` skill.

## 7. Error handling & observability

- All callable functions must return structured errors via `functions.https.HttpsError`
  with stable codes (`not-found`, `failed-precondition`, `invalid-argument`,
  `unauthenticated`, `permission-denied`). Never leak stack traces or internal
  Firestore paths to the client.
- Log with the existing `[SECTION]` convention (e.g. `[ROCKET]`, `[GIFT]`,
  `[ADMIN_FUEL]`) so logs are greppable. Include roomId/uid and the outcome, but
  never PII beyond uid.
- Wrap the transaction in try/catch; on `firebase.firestore.FirestoreError`
  retryable codes, re-throw as HttpsError so the client sees a clean message.
- Add tests in `functions/index.test.js` (jest is present) for: atomicity
  (concurrent sendGift), rocket threshold boundary (at/just under/just over
  target), insufficient balance, and double-milestone prevention.

## Do not use this skill when

- Writing Flutter UI/providers → `flutter-architecture`
- Writing React admin UI → `react-admin-dashboard`
- Non-mutating reads/queries → normal Firestore query rules still apply, but no
  transaction needed.