# Hello Chat UAT Setup

Status: **SETUP GUIDE - NOT A DEPLOY APPROVAL**
Targets: Local Firebase Emulator Suite or a separate staging project
Production writes: **not allowed** without the explicit Owner approval below.

Use this guide with `docs/CLIENT_UAT_TEST_PLAN.md`. The emulator path is the
only path that is ready today. Staging/production require the steps in
section 4 and separate approval.

## 1. Safety rules

1. Keep production reads read-only.
2. Never seed or test money flows against `hellochat-e8965` unless the Owner
   has approved named accounts and the UAT window in writing.
3. Do not reuse a client, real host, or agency account for write tests.
4. Do not repair the eight invalid `agencyId` links or the 101 demoted
   accounts during UAT. They are decision items, not test fixtures.
5. Stop a section after a failed money test. Do not edit Firestore to make a
   balance test pass.

## 2. Local emulator (recommended for all write/money tests)

### 2.1 Start the emulators

From the repository root:

```powershell
firebase emulators:start --only auth,firestore,functions
```

Expected ports: Auth `9099`, Firestore `8085`, Functions `5001`. The UI is at
`http://127.0.0.1:4000`. Leave this terminal running.

### 2.2 Seed the UAT accounts

In a second terminal:

```powershell
node scripts\seed_uat_accounts.cjs --emulator
```

The command refuses to run if the emulator hosts are not local. It resets the
seeded accounts and agency wallet fields to baseline but **does not** clear
withdrawal history, commission ledgers, rooms, gifts, or idempotency records.
For a totally clean run, restart the emulators, then reseed.

All seeded accounts use password `UatTest!2026`. Sign in in the app through
**Login -> Email**, not phone OTP.

| Alias | Role | Hello ID | UID | Email |
|---|---|---|---|---|
| uat_owner | Owner | `9900000001` | `uat-owner` | `uat.owner@hellochat-uat.test` |
| uat_superadmin | Super Admin | `9900000002` | `uat-superadmin` | `uat.superadmin@hellochat-uat.test` |
| uat_admin_one | Admin | `9900000011` | `uat-admin-1` | `uat.admin1@hellochat-uat.test` |
| uat_admin_two | Admin | `9900000012` | `uat-admin-2` | `uat.admin2@hellochat-uat.test` |
| uat_agency_alpha | Agency owner | `9900000021` | `uat-agency-alpha-owner` | `uat.agency.alpha@hellochat-uat.test` |
| uat_agency_beta | Agency owner | `9900000022` | `uat-agency-beta-owner` | `uat.agency.beta@hellochat-uat.test` |
| uat_host_alpha_one | Host | `9900000031` | `uat-host-alpha-1` | `uat.host.a1@hellochat-uat.test` |
| uat_host_alpha_two | Host | `9900000032` | `uat-host-alpha-2` | `uat.host.a2@hellochat-uat.test` |
| uat_host_beta_one | Host | `9900000033` | `uat-host-beta-1` | `uat.host.b1@hellochat-uat.test` |
| uat_host_beta_two | Host | `9900000034` | `uat-host-beta-2` | `uat.host.b2@hellochat-uat.test` |
| uat_normal_one | Normal user | `9900000041` | `uat-user-1` | `uat.user1@hellochat-uat.test` |
| uat_normal_two | Normal user | `9900000042` | `uat-user-2` | `uat.user2@hellochat-uat.test` |
| uat_normal_three | Normal user | `9900000043` | `uat-user-3` | `uat.user3@hellochat-uat.test` |

Fixtures: branch `uat-branch-main`; agencies `uat-agency-alpha` and
`uat-agency-beta`. The seed allocates role codes from `counters/role_codes`
and reuses a valid code on reseed.

### 2.3 Run the automated checks before human UAT

```powershell
node scripts\uat_happy_paths.cjs
node scripts\uat_edge_cases.cjs
```

`uat_happy_paths.cjs` proves the gift, recharge, withdrawal, removal,
deactivation, and inactive-withdrawal paths. It leaves the alpha agency
deactivated, so reseed before a human pass. `uat_edge_cases.cjs` proves
normal-user protection, admin-owned agency access, non-owner isolation,
inactive/zero-balance rejection, legacy/agency split, and roster cleanup.

### 2.4 Point the apps at the emulator

**Admin panel (ready today):**

```powershell
cd hellochat_admin
$env:VITE_USE_EMULATOR="1"
npm run dev -- --port 5174
```

`VITE_USE_EMULATOR` connects Auth, Firestore, Functions, and Storage to the
local emulators. Unset it for production.

Use the **admin panel** for the USD Commission Wallet and withdrawal queue.
The Flutter Agency Portal shows the agency bean wallet; it does not link to the
USD Commission Wallet for Agency accounts.

**Flutter app (one local edit required):**

`lib/main.dart` already contains `_connectToEmulators()`, but the call is
commented out and there is no `--dart-define` flag for it. In a local test
build only, uncomment the block:

```dart
if (kDebugMode) {
  _connectToEmulators();
}
```

Then run the app. The helper uses `10.0.2.2` for an Android emulator and
`192.168.1.197` for other devices; change that IP to the PC's LAN address for a
physical phone on the same Wi-Fi. `_connectToEmulators()` also connects Auth
and Functions. Revert this edit before committing a release build.

**Important:** there is no supported build-time switch for the emulator in the
current Flutter code. If a no-edit switch is required, it must be added and
tested separately.

### 2.5 Useful emulator checks

```powershell
firebase emulators:export .\emulator-backup
node functions\test_agency_id_rules.js
node functions\test_hb_pms.js
node scripts\uat_happy_paths.cjs
node scripts\uat_edge_cases.cjs
```

Run the rules test with `FIRESTORE_EMULATOR_HOST=127.0.0.1:8085` if the
emulator is already running. It clears emulator Firestore, so reseed
afterwards. Reseed before the happy-path script; the edge script cleans up its
own temporary agencies but expects the seeded roster.

## 3. What the UAT proves

- Role codes and branch/Admin/Super Admin links.
- Agency-scoped roster and wallet isolation.
- Recharge commission: 30% to the agency document, 10% to the Admin.
- Withdrawal split: legacy user USD first, then agency USD.
- Owner-only process/approve/pay/reject and refunds.
- Host removal and agency deactivation; "transfer" is remove + add, not one
  atomic action.
- Normal users cannot self-assign hierarchy fields or write agency ledgers.
- Old-app compatibility: descriptive agency edits and roster updates still
  work; client writes to ledger fields are rejected.

## 4. Staging or production UAT (not ready)

A staging project does **not** exist yet. Before staging UAT:

1. Create a separate Firebase project and enable Auth, Firestore, Functions,
   and Hosting. Do not reuse `hellochat-e8965`.
2. Register the Android/iOS/web apps and regenerate the Flutter config:
   `flutterfire configure --project=<staging-project>`.
3. Replace `lib/firebase_options.dart` and the platform Firebase files with the
   staging values for the test build only.
4. Deploy Firestore rules, indexes, and Functions to staging. Deploy the admin
   panel with a staging `firebaseConfig` (the current admin source hardcodes the
   production project, so this needs a temporary config change or an added
   environment-based config).
5. Run `node scripts\seed_uat_accounts.cjs --project <staging-project>`.
6. Run the happy-path and edge scripts only if they are pointed at staging;
   they currently require local emulator hosts and will refuse a remote target.
7. Execute the UAT plan against staging and record evidence.

Production UAT writes require **all** of the following:

- A written Owner approval naming the accounts and time window.
- `--i-understand-this-writes-to-production`.
- `--approval-token OWNER_APPROVED_UAT`.
- A non-default `--password` or `UAT_PASSWORD`.

The seed also refuses the default password in production. Do not treat a
successful read-only production audit as approval to write.

## 5. Known setup limitations

- The Flutter emulator connection is commented out and has no dart-define
  switch.
- The admin source hardcodes `hellochat-e8965`; only the emulator path has a
  supported switch.
- The seed does not clear old withdrawals, ledgers, rooms, gifts, or
  idempotency records.
- `scripts/appoint_four_admins.cjs` contains a stale Hello ID
  (`0000100003`); do not run it as-is. The correct ID is `100003`.
- No production account has an Agency role plus a valid agency document.
  Agency UAT must use seeded/staging accounts.
- `8xS6BOlqjhMWuN9v7lxqoVulqan2` owns `pUOzQAMTYQlvrTsxCVlC` but is not an
  Agency-tier user. Treat it as decision item D1, not as an agency tester.
