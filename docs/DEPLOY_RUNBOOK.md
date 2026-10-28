# Hello Chat Production Deploy Runbook

Status: **NOT EXECUTED**. This document is a local plan only.
Project: `hellochat-e8965`
Repository: `D:\UnHuman\Apps\Hello Chat\hellochat`
Branch: `consolidate/all-gift-vap-fixes`
Deploy owner: `[FILL: name]`
Date / approved commit: `[FILL]`

> Stop condition: do not run any command in this document until the Platform
> Owner has replied **"approved to deploy"** and the deploy-gate report has
> been accepted.

## 1. What is being deployed

| Area | Change | Why it matters |
|---|---|---|
| Cloud Functions | Commission wallets now aggregate `users/{uid}` legacy balances with the linked `agencies/{agencyId}` document. Debits spend legacy USD first, then agency USD. Withdrawals store `userDebitUSD`, `agencyDebitUSD`, `agencyId`; pay/reject restore the same sources. | Without this, new agency commission credits are invisible to the legacy wallet and cannot be withdrawn or converted consistently. |
| Admin Hosting | `CommissionWallet.jsx` reads the user document and the linked agency document, then aggregates the five wallet fields. Diamonds stay user-only. Denied agency reads fall back to legacy user-only. | Admin must see the same balance the client sees. |
| Flutter app | Agency wallet stream + aggregate display in `commission_wallet_screen.dart`. | Agency/Admin wallets must show legacy + agency funds. |
| Firestore rules | `/agencies` create/update now protects `usdCommissionBalance`, `totalCommissionEarned`, `totalRechargeGenerated`, `pendingWithdrawalBalance`, `totalWithdrawnUSD` in addition to `beansBalance`, `totalBeansEarned`, `code`, `adminId`, `branchId`, `superAdminId`. | Closes a client-write hole on USD ledger fields. Rules must land after functions and clients are ready. |
| No data migration | Legacy user wallet documents are left untouched. The 8 invalid `agencyId` links and 101 demoted accounts are **not** modified. | Data changes require a separate client decision. |

## 2. Hard guardrails

1. Use Google Cloud Shell for the commands below. The local Windows machine has
   Firebase CLI 15.25.1 but no `gcloud`; Cloud Shell has both.
2. Take the backup first and verify it before touching production.
3. Never run `firebase firestore:delete`, a Firestore import, or any bulk data
   script during this deploy.
4. Deploy in the order below. Do not skip ahead to rules.
5. Pause and stop if any smoke check fails. Rolling back functions after new
   split withdrawals exist requires reconciliation; do not roll back blindly.
6. All writes during smoke/UAT must use Owner-approved test accounts and a
   dedicated UAT branch. Do not use client accounts to test money flows.
7. Record every command output in the release ticket.

## 3. Preconditions

- [ ] Client approved this deploy and the account decisions in
      `docs/CLIENT_DECISIONS_NEEDED.md`.
- [ ] Approved commit is on `consolidate/all-gift-vap-fixes`.
- [ ] Backup bucket exists and the deployer has `roles/storage.objectAdmin`,
      `roles/datastore.importExportAdmin`, `roles/firebasehosting.admin`, and
      `roles/firebaserules.admin`.
- [ ] A second person is available to verify smoke checks.
- [ ] UAT test branch and test accounts exist (see `CLIENT_UAT_TEST_PLAN.md`).
- [ ] Release ticket has the backup paths, commit SHA, and rollback owner.

## 4. Backup (do this first)

Run in Cloud Shell. Replace the bucket with an existing private bucket.

```bash
set -euo pipefail

export PROJECT_ID="hellochat-e8965"
export BACKUP_BUCKET="gs://REPLACE_WITH_PRIVATE_BACKUP_BUCKET"
export STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
export BACKUP_DIR="$HOME/hellochat-backups/$STAMP"
mkdir -p "$BACKUP_DIR"

gcloud config set project "$PROJECT_ID"

# 4.1 Firestore export (full database)
gcloud firestore export "$BACKUP_BUCKET/$PROJECT_ID/$STAMP/firestore" \
  --project="$PROJECT_ID" \
  2>&1 | tee "$BACKUP_DIR/firestore-export.log"

gcloud firestore operations list --project="$PROJECT_ID" \
  | tee "$BACKUP_DIR/firestore-operations.txt"

# 4.2 Deployed functions inventory
firebase --project "$PROJECT_ID" functions:list \
  | tee "$BACKUP_DIR/functions-before.txt"

# 4.3 Auth user export (contains PII; keep the backup private)
firebase --project "$PROJECT_ID" auth:export "$BACKUP_DIR/auth-users.json" \
  --format=json

# 4.4 Currently deployed Firestore rules
TOKEN="$(gcloud auth print-access-token)"
curl -fsS -H "Authorization: Bearer $TOKEN" \
  "https://firebaserules.googleapis.com/v1/projects/$PROJECT_ID/releases?pageSize=100" \
  -o "$BACKUP_DIR/rules-releases.json"

RELEASE="$(jq -r '.releases[] | select(.name | endswith("/releases/cloud.firestore")) | .name' \
  "$BACKUP_DIR/rules-releases.json" | head -n 1)"
test -n "$RELEASE"

curl -fsS -H "Authorization: Bearer $TOKEN" \
  "https://firebaserules.googleapis.com/v1/$RELEASE" \
  -o "$BACKUP_DIR/rules-release.json"

RULESET="$(jq -r '.rulesetName' "$BACKUP_DIR/rules-release.json")"
curl -fsS -H "Authorization: Bearer $TOKEN" \
  "https://firebaserules.googleapis.com/v1/$RULESET" \
  -o "$BACKUP_DIR/ruleset.json"

jq -r '.source.files[] | select(.name | endswith("firestore.rules")) | .content' \
  "$BACKUP_DIR/ruleset.json" > "$BACKUP_DIR/firestore.rules.before"
wc -l "$BACKUP_DIR/firestore.rules.before"

# 4.5 Hosting release metadata
curl -fsS -H "Authorization: Bearer $TOKEN" \
  "https://firebasehosting.googleapis.com/v1beta1/sites/$PROJECT_ID/releases?pageSize=20" \
  -o "$BACKUP_DIR/hosting-releases.json"
jq -r '.releases[0:5][] | [.name, .releaseTime, .version.name, .message] | @tsv' \
  "$BACKUP_DIR/hosting-releases.json" \
  | tee "$BACKUP_DIR/hosting-releases.txt"
```

If the Hosting site ID is not `hellochat-e8965`, list sites first and substitute
the real site ID:

```bash
curl -fsS -H "Authorization: Bearer $TOKEN" \
  "https://firebasehosting.googleapis.com/v1beta1/sites?pageSize=100" \
  -o "$BACKUP_DIR/hosting-sites.json"
jq -r '.sites[] | [.name, .defaultUrl] | @tsv' "$BACKUP_DIR/hosting-sites.json"
```

Backup verification:

- [ ] `firestore-export.log` shows the export operation name and success.
- [ ] `firestore-operations.txt` shows the operation as `SUCCESSFUL`.
- [ ] `functions-before.txt` is non-empty.
- [ ] `firestore.rules.before` is non-empty and contains `service cloud.firestore`.
- [ ] `hosting-releases.txt` contains the current live release.
- [ ] Backup location is private and recorded in the release ticket.
- [ ] Source code backup is the approved Git commit:

```bash
git -C "$HOME/hellochat" rev-parse HEAD
git -C "$HOME/hellochat" status --short
```

## 5. Final pre-deploy verification

Run locally or in Cloud Shell from the repository root. Paste the output into
the ticket.

```bash
node functions/test_hb_pms.js

firebase emulators:exec --only firestore --project hellochat-e8965 \
  "node functions/test_agency_id_rules.js && node functions/test_role_codes_hierarchy_e2e.js"

flutter test test/admin_seat_label_test.dart \
  test/user_role_default_test.dart \
  test/hierarchy_permission_test.dart

flutter analyze
npm --prefix hellochat_admin ci
npm --prefix hellochat_admin run build
```

Expected as of the current branch:

- `test_hb_pms.js`: 12 passed, 0 failed.
- Rules + role/hierarchy: 13/13 and 30/30 passed.
- Wallet authorization: a Host or non-owner Agency staffer with an `agencyId`
  cannot spend the agency balance; only the agency owner can.
- Flutter targeted tests: all passed.
- Full `flutter test` is not green on this branch and is not the deploy gate:
  6 unrelated failures in chat combo folding, room-support tiers, and the
  VAP 12-vs-13 gift catalog, plus the suite did not finish within 10 minutes.
  None touch the commission-wallet files.
- `flutter analyze`: 2 pre-existing errors in
  `integration_test/app_device_test.dart` because the `integration_test`
  dependency is commented out in `pubspec.yaml`; the deployable `lib/` code has
  no analyzer errors.
- Admin build: succeeds with warnings only.

## 6. Deploy order

### Step 1 - Cloud Functions

Why first: the new functions can read both the legacy user document and the
agency document. They are backward-compatible with the current clients. The
admin UI and mobile app can still read legacy balances until their releases
land.

```bash
firebase --project "$PROJECT_ID" deploy --only functions
firebase --project "$PROJECT_ID" functions:list | tee "$BACKUP_DIR/functions-after.txt"
```

Smoke after functions:

- [ ] The deploy reports success for all functions.
- [ ] `functions:list` shows the expected deployment timestamps.
- [ ] `firebase --project "$PROJECT_ID" functions:log --only submitCommissionWithdrawal` shows no crash loop.
- [ ] Admin panel loads; `listAgencies` still returns results.
- [ ] Read-only wallet screen opens for the approved Admin/agency account.
- [ ] No withdrawal or recharge is submitted in production.

If this step fails: see rollback for functions. Do not deploy Hosting or rules.

### Step 2 - Admin Hosting

Why second: the panel can now read and aggregate agency wallet fields. The
mobile app can remain on the old display briefly without data loss.

```bash
npm --prefix hellochat_admin ci
npm --prefix hellochat_admin run build
firebase --project "$PROJECT_ID" deploy --only hosting:hellochat_admin
```

Smoke after Hosting:

- [ ] Admin site loads with no console errors.
- [ ] Sign in as each of the four Admins and confirm the panel opens.
- [ ] Open Commission Wallet for an account with `agencyId`; legacy + agency
      values are shown.
- [ ] Open the Commission Wallet for a user without `agencyId`; legacy-only
      values are shown.
- [ ] Open Financial Management as the Owner; withdrawal queue loads.
- [ ] Do not approve, pay, or reject a live request during smoke.

If this step fails: roll back Hosting via Console release history.

### Step 3 - Flutter app release

Why third: clients must understand the agency wallet read before the rules
close direct agency ledger writes. Release the approved build to the internal
track first.

```bash
flutter pub get
flutter build appbundle --release
flutter build ipa --release  # on macOS with signing configured
```

Upload the Android App Bundle to Play Console internal testing and the iOS
build to TestFlight. Complete the internal smoke test before promoting.

Smoke after the internal build:

- [ ] Sign in as Normal User, Host, Agency, Admin, Super Admin, Owner.
- [ ] Commission Wallet shows legacy + agency for an approved agency account.
- [ ] Normal User sees only legacy/normal wallet surfaces.
- [ ] Host cannot read another agency's data.
- [ ] No crash on profile, wallet, agency portal, withdrawal history.
- [ ] Do not submit a real withdrawal during store smoke.

If this step fails: halt the rollout, keep the previous production build, and
do not deploy rules.

### Step 4 - Firestore rules (last)

Why last: rules must protect the new USD ledger fields only after the new
functions and clients are live. Deploying rules first would close the fields
while older code paths are still being replaced, and would create an avoidable
compatibility window.

```bash
firebase --project "$PROJECT_ID" deploy --only firestore:rules
```

Immediately after rules:

- [ ] Rules deploy succeeds.
- [ ] `/agencies` owner can still update descriptive fields (`name`,
      `description`, `logoUrl`, `isActive`).
- [ ] `/agencies` owner cannot update `usdCommissionBalance`,
      `totalCommissionEarned`, `totalRechargeGenerated`,
      `pendingWithdrawalBalance`, `totalWithdrawnUSD`, `beansBalance`,
      `totalBeansEarned`, `code`, `adminId`, `branchId`, `superAdminId`.
- [ ] Normal user can still read own profile and wallet.
- [ ] Gift catalog is still readable.
- [ ] Room read/create/join flows still work.
- [ ] Host roster shows 3 explicit hosts and 101 Normal Users.
- [ ] Four Admins open their panels; role codes are one each of
      `10000`, `10001`, `10003`, `10005`.
- [ ] Agency isolation: Agency A cannot read Agency B hosts/wallet.
- [ ] Owner withdrawal queue still loads; no live request is modified.
- [ ] Monitor Functions logs for 15 minutes: no permission-denied or
      insufficient-balance spike.

## 7. Half-deployed states

| State | User impact | Data risk | Required action |
|---|---|---|---|
| Functions only | Mobile/admin may show only legacy balances; new agency credits are still written to the agency document. | No loss; balances may look lower than actual. | Continue to Hosting, or roll back functions before new split withdrawals exist. |
| Functions + Hosting | Admin sees correct aggregate; mobile may understate. | No loss. | Continue to mobile release promptly. |
| Functions + Hosting + mobile | Balances display correctly. | Agency ledger fields are still client-writable until rules land. | Deploy rules immediately; monitor audit logs. |
| Rules only / rules first | Old code paths may fail writes to `/agencies`; commission flow may look broken. | Operations blocked, no balance loss. | Deploy functions and clients or roll rules back. |
| Any state + new withdrawals | Split fields exist in new requests. Old functions ignore them. | Incorrect pay/reject if functions are rolled back. | Reconcile every open request before rollback. |

## 8. Rollback

### 8.1 Functions

Use a separate worktree; do not reset the main working tree.

```bash
export LAST_GOOD_COMMIT="[FILL: last known good functions commit]"
git -C "$HOME/hellochat" worktree add "$HOME/hellochat-rollback" "$LAST_GOOD_COMMIT"
npm --prefix "$HOME/hellochat-rollback/functions" ci
firebase --project "$PROJECT_ID" deploy --only functions \
  --config "$HOME/hellochat-rollback/firebase.json"
```

Before rolling back, verify that no `commission_withdrawals` document with
`userDebitUSD` / `agencyDebitUSD` is still `pending` or `approved`. If one
exists, pay/reject it on the new code first or reconcile balances manually.
After rollback, remove the worktree:

```bash
git -C "$HOME/hellochat" worktree remove "$HOME/hellochat-rollback"
```

### 8.2 Admin Hosting

Firebase Hosting has no CLI release-list/rollback command in the installed CLI.
Use the Console:

1. Firebase Console -> Hosting -> release history for the site.
2. Select the last known good release.
3. Roll back to that release.
4. Hard-refresh the admin URL and repeat the admin smoke checks.

### 8.3 Flutter app

- Halt the Play Console staged rollout / TestFlight rollout.
- Keep the previous production build available.
- Ship the previous build as a hotfix if the new build is already public.
- Do not attempt to "roll back" a store build by deleting it; publish a higher
  version containing the previous behavior.

### 8.4 Firestore rules

Preferred: Firebase Console -> Firestore -> Rules -> history -> select the
previous ruleset -> restore/publish.

CLI fallback, using the backup taken in section 4:

```bash
cp firebase/firestore.rules "$BACKUP_DIR/firestore.rules.new"
cp "$BACKUP_DIR/firestore.rules.before" firebase/firestore.rules
firebase --project "$PROJECT_ID" deploy --only firestore:rules
mv "$BACKUP_DIR/firestore.rules.new" firebase/firestore.rules
```

Rolling rules back re-opens the direct `/agencies` ledger write hole. Do it only
if clients/functions are broken, and monitor audit logs until the forward fix
is deployed.

### 8.5 Data

Do **not** import the Firestore backup as a routine rollback. An import can
overwrite newer writes and is destructive. Restore only specific affected
documents after Owner approval, or run a reviewed reconciliation script. The
backup exists for disaster recovery, not for undoing a code release.

## 9. Post-deploy record

- [ ] Commit SHA deployed: `[FILL]`
- [ ] Backup path: `[FILL]`
- [ ] Functions deploy time: `[FILL]`
- [ ] Hosting release: `[FILL]`
- [ ] Mobile build/version: `[FILL]`
- [ ] Rules release: `[FILL]`
- [ ] Smoke check owner: `[FILL]`
- [ ] Open issues / decisions: `[FILL]`

