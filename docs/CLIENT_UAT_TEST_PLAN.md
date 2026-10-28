# Hello Chat Client UAT Test Plan

Status: **PLAN ONLY - NOT EXECUTED**
Project: `hellochat-e8965` (production, read-only evidence) or local emulator
Build under test: `[FILL: commit / app version / admin build]`
Date: `[FILL]`

This plan was audited against the code, UI, and seeded data on 2026-10-29.
Rows marked **BLOCKED** cannot be executed as written. Rows marked **DEV**
need the rules test or a Firebase console/emulator inspection, not a
non-developer tester. `docs/UAT_SETUP.md` has the environment and credentials.

## 1. Purpose and rules

Prove hierarchy, role codes, agency isolation, commission wallets, and normal
app flows before release.

1. Write/money tests run only on the emulator or an approved staging project.
2. Production checks are read-only. Do not seed, repair, or write production
   during this plan.
3. Use the seeded accounts from `docs/UAT_SETUP.md`. For production rows use
   the accounts named below.
4. Record Pass / Fail / Blocked, tester, time, account, and evidence.
5. Stop a section after a failed money test. Never edit Firestore to make a
   balance test pass.
6. Do not repair the eight invalid `agencyId` links or the 101 unmarked
   accounts. They are decision items.
7. A gift credits **beans** to the host/agency split. USD commission comes from
   **recharge**, not from gifts. Do not score E1 against a gift.

## 2. Accounts

### 2.1 Emulator write accounts

Use the aliases, emails, UIDs, and password in `docs/UAT_SETUP.md`:
`uat_owner`, `uat_superadmin`, `uat_admin_one`, `uat_admin_two`,
`uat_agency_alpha`, `uat_agency_beta`, the four `uat_host_*` accounts, and
`uat_normal_one/two/three`. The emulator has **2 Admins**, not the production
4.

### 2.2 Production read-only evidence accounts

| Alias | Role / purpose | Hello ID | UID | Notes |
|---|---|---|---|---|
| OWNER | Platform Owner | `[FILL]` | `[FILL]` | Global read-only scope. |
| SA-1 | Super Admin | `8996148082` | `qfoqaYFOLIMsPw4awQmsc8G0tRW2` | Missing branch; decision D3. |
| ADM-1 | Admin / agency owner | `3607188625` | `HgrLl9ubSmcZ0LdWi05MS0jHGvu1` | Owns `VO4m5hbOpMwLc6PDF1bn`. Use admin Commission Wallet. |
| ADM-2 | Admin | `1805742773` | `aRdHp4qLLKdd8qUoVTcgTcpZpKf2` | No agency. |
| ADM-3 | Admin | `3485703221` | `lDLp5QDDbXRzfT14qEAr4SauR0G3` | Dangling user-UID agency link. |
| ADM-4 | Admin | `100003` | `PhFe53EOGzRxricZKawdA4DARcz2` | No agency. |
| ADM-5 | Admin | `1887819976` | `hjntivA2pmasR8sE8QXGvABujNy2` | No agency. |
| ADM-6 | Admin / Agency tag | `5621916410` | `pc6mVRnBCVOTV9nM5J7FErJ5WZc2` | No agency doc; ADM-3 points at this UID. |
| AGY-B | Agency document owner | `6114943995` | `8xS6BOlqjhMWuN9v7lxqoVulqan2` | Normal User, no `isAgencyOwner`, owns `pUOz...`; cannot spend agency USD. |
| HOST-EXPLICIT | Host | `4926026367` | `4zbctX7hzLNBfeHsU7JU5prCrQt1` | No agency. |
| HOST-DEMOTED | Normal User regression | `3473579420` | `0Xt6Z8CaC5VUHm5UMZGA` | Former unmarked Host. |

No production account has an Agency role plus a valid agency document. Agency
USD-wallet tests use seeded emulator/staging accounts or admin-owned production
`ADM-1` (read-only).

## 3. Environment checklist

- [ ] Emulator or approved staging is running; production writes are disabled.
- [ ] `docs/UAT_SETUP.md` steps completed and seeded accounts verified.
- [ ] Admin panel is open at the emulator/staging URL.
- [ ] Flutter app is pointed at the same backend (emulator edit reverted after).
- [ ] Testers know that Agency USD wallet is in the **admin panel**, while the
      Flutter Agency Portal shows the bean wallet.
- [ ] Evidence folder is ready; screenshots hide tokens, phones, and bank data.
- [ ] Decision items D1-D7 are acknowledged before scoring affected accounts.

## 4. Test matrix

### A. Hierarchy and role creation

| ID | Prerequisite | Account | Steps | Expected / audit note | Type |
|---|---|---|---|---|---|
| A1 | Production read-only OR emulator | OWNER | Open branch/hierarchy view; list Admins. | Production: 6 Admin-role accounts under `branch-prod-1`. Emulator: 2 Admins. No cross-branch Admin. **[READY]** | READ |
| A2 | A fresh UAT user exists | uat_superadmin | Create an Admin, assign branch and Super Admin. | Admin role + 5-digit code `10000-99999`; links present. Seed has no spare Admin slot, so register a fresh user first. **[READY after registration]** | WRITE |
| A3 | A fresh UAT user exists | uat_admin_one | Create an Agency from that user. | Agency doc created; owner 6-digit code `100000-999999`; `adminId`, `branchId`, `superAdminId` set; owner role Agency. **[READY after registration]** | WRITE |
| A4 | A3 agency exists | new UAT agency owner | Add `uat_normal_three` as Host. | User `agencyId` stores the agency document ID, not caller UID; roster updates. **[READY]** | WRITE |
| A5 | SA signed in | uat_superadmin | Create Admin with no Super Admin, then with a normal-user parent. | Both rejected; no partial user. **[READY if the admin UI exposes the negative path]** | WRITE |
| A6 | SA signed in | uat_superadmin | Create Admin under another branch's Super Admin. | Rejected; no cross-branch link. **[BLOCKED: one seeded branch, no second Super Admin to test against]** | WRITE |
| A7 | Admin signed in | uat_admin_one | Open branch user list. | Only users with `adminId == uat-admin-1` appear. No Owner-only controls. **[READY]** | READ |
| A8 | HOST-DEMOTED signed in | production `0Xt6...` | Inspect profile, menus, role routes. | Treated as Normal User: no Host/Admin/Agency management. **[PROD-READ]** | READ |

### B. Role-code allocation

| ID | Prerequisite | Account | Steps | Expected / audit note | Type |
|---|---|---|---|---|---|
| B1 | Production read-only | OWNER | Record each of the six Admin `roleCode` values. | One each of `10000`-`10005`, no duplicates; confirm mapping. Emulator has only 2 Admin codes. **[PROD-READ for 6-code check]** | READ |
| B2 | Fresh UAT user | uat_superadmin | Create one Admin. | 5-digit unique code, greater than previous. **[READY]** | WRITE |
| B3 | Fresh UAT user | uat_admin_one | Create one Agency. | 6-digit code `100000-999999`, unique. **[READY]** | WRITE |
| B4 | Ten fresh UAT users and two sessions | UAT branch | Create 10 Admins in parallel. | No duplicate codes; clean success/fail. **[BLOCKED: seed has only 13 accounts and 2 Admins; needs a bulk fixture or test harness]** | WRITE |
| B5 | Emulator rules test | DEV | Attempt forged client `roleCode`/`role` write. | Denied. Use automated rules test; not a client UI action. **[DEV]** | WRITE |
| B6 | Emulator rules test | DEV | Attempt self-edit of `roleCode`, `role`, `branchId`, `adminId`, `agencyId`. | All denied. **[DEV - covered by rules test]** | WRITE |

### C. Agency isolation

| ID | Prerequisite | Account | Steps | Expected / audit note | Type |
|---|---|---|---|---|---|
| C1 | Agency signed in | uat_agency_alpha | Open Agency Portal -> hosts and bean wallet; admin panel -> Commission Wallet. | Only alpha hosts/bean wallet and alpha USD wallet. **[READY; USD is admin-panel only]** | READ |
| C2 | Agency signed in | uat_agency_alpha | Attempt to read the other agency: emulator `uat-agency-beta`; production `pUOz...`. | Denied; no other roster/wallet/ledger. There is no ID lookup in the app, so use the rules test/emulator console. **[DEV]** | READ |
| C3 | Admin signed in | uat_admin_one | Open agency management. | Only agencies with `adminId == uat-admin-1` (emulator: alpha). **[READY]** | READ |
| C4 | Super Admin signed in | uat_superadmin | Open branch agencies. | Only `uat-branch-main` agencies. **[READY]** | READ |
| C5 | Owner signed in | uat_owner | Open all agencies. | Both seeded agencies plus any created during UAT. **[READY]** | READ |
| C6 | Normal user signed in | uat_normal_one | Direct-open admin/agency/commission routes. | Backend data is protected, but the Flutter router has no role guard: the screen can open. No privileged data should render. This is a known UI gap, not a firewall. **[READY with known gap]** | READ |
| C7 | Agency signed in | uat_agency_alpha | Attempt client write to beta agency (emulator) or another production agency. | Rules deny. Use rules test for the crafted write. **[DEV]** | WRITE |

### D. One panel per role

| ID | Prerequisite | Account | Steps | Expected / audit note | Type |
|---|---|---|---|---|---|
| D1 | Normal user signed in | uat_normal_one | Inspect home/profile/menus. | Normal User surfaces only; no Admin/Agency/Host management. **[READY]** | READ |
| D2 | Host signed in | uat_host_alpha_one | Open host surfaces. | Host controls only; no branch-wide Admin controls. **[READY]** | READ |
| D3 | Agency signed in | uat_agency_alpha | Flutter Agency Portal; admin panel `/commission-wallet`. | Bean portal loads in Flutter; USD wallet loads in admin panel; no branch-wide Admin controls. **[READY; two different UIs]** | READ |
| D4 | Admin signed in | uat_admin_one | Open Admin panel. | Branch-scoped users/agencies/withdrawals; no Owner-only controls. **[READY]** | READ |
| D5 | Super Admin signed in | uat_superadmin | Open Super Admin panel. | Branch scope only; no global Owner controls. **[READY]** | READ |
| D6 | Owner signed in | uat_owner | Open Owner panel. | Global scope and Owner-only controls. **[READY]** | READ |

### E. Commission wallet, recharge, withdrawal

E1-E9 and E11-E12 use the **admin panel**. A gift is not commission.

| ID | Prerequisite | Account | Steps | Expected / audit note | Type |
|---|---|---|---|---|---|
| E1 | Host linked to alpha; admin signed in | uat_admin_one + uat_host_alpha_one | Issue a $100 recharge order as Admin, then redeem as host. | Agency `usdCommissionBalance` +30, admin +10; ledger rows name source and rates. Gift path is separate beans. **[READY]** | WRITE |
| E2 | Admin-owned agency exists | production ADM-1 / emulator edge fixture | Open admin Commission Wallet. | Legacy user USD + agency USD are summed; pending/earned/withdrawn/recharge summed; diamonds user-only. Emulator seed has no admin-owned agency. **[PROD-READ or edge-test evidence]** | READ |
| E3 | Agency has legacy $X and agency $Y | uat_agency_alpha | Convert `<= X`, then `> X`, in admin wallet. | Legacy spent first, then agency; no negative. **[READY]** | WRITE |
| E4 | Agency signed in | uat_agency_alpha | Request below $10 minimum. | Rejected before balance change; message states minimum. **[READY]** | WRITE |
| E5 | Alpha has balance; request pending | uat_owner | Process -> approve -> pay. | Pending decreases; `totalWithdrawnUSD` uses exact split; approver/payer/timestamps recorded. **[READY]** | WRITE |
| E6 | Request pending | uat_owner | Reject. | Exact split refunded; pending returns to zero; reason recorded. **[READY]** | WRITE |
| E7 | Alpha has legacy + agency USD | uat_agency_alpha | Convert commission to Diamonds. | Diamonds at configured rate; both sources debited; split logged. **[READY]** | WRITE |
| E8 | A reseller fixture exists | uat_agency_alpha | Transfer commission to reseller. | Sender split correct; reseller credited once. **[BLOCKED: seed has no reseller; admin UI has no create-reseller action]** | WRITE |
| E9 | A legacy withdrawal request exists | uat_owner | Approve/pay and reject a no-split request. | Legacy request touches only user USD; agency untouched. **[BLOCKED: no legacy-request fixture; seed does not create one]** | WRITE |
| E10 | Emulator rules test | DEV | Crafted write to `usdCommissionBalance`/ledger fields. | Denied. Covered by `test_agency_id_rules.js`. **[DEV]** | WRITE |
| E11 | Agency signed in | uat_agency_alpha | Open own withdrawal history and commission ledger. | Own records only; other agency records absent. **[READY in admin panel]** | READ |
| E12 | Alpha balance enough for one request | uat_agency_alpha | Submit two parallel requests exceeding balance. | One succeeds; other insufficient; no negative/duplicate. **[READY with two browser sessions]** | WRITE |

### F. Transfers, removals, agency lifecycle

| ID | Prerequisite | Account | Steps | Expected / audit note | Type |
|---|---|---|---|---|---|
| F1 | Host in alpha | uat_admin_one | Transfer host to beta. | **No transfer action exists.** Use remove from alpha, then add to beta. Expected: new `agencyId`; both rosters update; no balance moves. **[CORRECTED: two-step, not atomic]** | WRITE |
| F2 | Host in alpha | uat_admin_one | Remove host via Admin Agency Management. | Host `agencyId` clears and roster count decreases. **`removeHost` does not change `role`**, so the Host panel can remain. The plan's old "Host panel access is removed" is false. **[KNOWN MISMATCH]** | WRITE |
| F3 | Alpha has balances | uat_owner | Deactivate agency. | `isActive:false`, status deactivated, roster cleared, hosts released, balances retained, audit row. **[READY after roster fix]** | WRITE |
| F4 | Alpha deactivated | uat_agency_alpha | Attempt withdrawal. | Rejected; no funds move. Owner role is already downgraded by deactivation. **[READY]** | WRITE |
| F5 | Released host exists | uat_admin_one | Add released host to beta. | Beta document ID stored; alpha roster no longer contains host. **[READY]** | WRITE |
| F6 | Production read-only OR emulator | OWNER | Inspect host roster and invalid links. | Production: 3 explicit Hosts, 101 unmarked accounts normal, 8 invalid links unchanged. Emulator: 4 seeded Hosts. **[PROD-READ]** | READ |

### G. Full regression

| ID | Prerequisite | Account | Steps | Expected / audit note | Type |
|---|---|---|---|---|---|
| G1 | App + admin running | all seeded roles | Sign in with email; register a normal user. | No crash; correct routing; readable errors. **[READY]** | READ/WRITE |
| G2 | Room fixture or create room | uat_host_alpha_one | List/create/enter/leave/seat/unseat/send message. | Flows work; admin seat label correct. **[READY]** | WRITE |
| G3 | Seeded normal gift | uat_normal_one | Send normal gift and combo to a host. | Animation plays; balance deducts once; combo counter works. Gift credits beans, not USD. **[READY]** | WRITE |
| G4 | Admin + host | uat_admin_one + uat_host_alpha_one | Open recharge packages; complete UAT recharge. | Diamonds/beans credit once; history present; commission is E1. **[READY]** | WRITE |
| G5 | Wallet data exists | uat_normal_one | Open wallet/history. | Balances match Firestore; no unauthorized entries. **[READY]** | READ |
| G6 | UAT account has diamonds | uat_normal_one | Open VIP/SVIP; purchase with UAT funds. | Entitlement updates once; no duplicate charge. **[READY after G4]** | WRITE |
| G7 | Mini-game feature enabled | uat_normal_one | Open lobby; run one UAT round. | Balance guard prevents over-bet; history persists. **[BLOCKED if no game/config fixture; confirm before scoring]** | WRITE |
| G8 | Two UAT users | uat_normal_one + two | Send/receive chat; open friend profile. | Messages deliver; wallet/role fields hidden. **[READY]** | WRITE |
| G9 | Staging push credentials | UAT user | Trigger/open notification. | Deep link correct; no crash. **[BLOCKED on emulator: FCM/push is not configured]** | WRITE |
| G10 | Admin-owned agency | production ADM-1 | Open admin Commission Wallet. | Agency + legacy match; diamonds user-only; denied read falls back. **[PROD-READ; emulator seed lacks admin-owned agency]** | READ |
| G11 | Withdrawal request exists | uat_owner | Open queue; inspect request. | Status transitions correct; no production request touched. **[READY after E5]** | READ/WRITE |
| G12 | Audit log entry exists | uat_owner | Open Audit Logs. | Role/withdrawal/agency changes have actor + timestamp. **[READY]** | READ |
| G13 | All roles | all | Sign out/back in. | No stale role/agency; no privilege leak. **[READY]** | READ |
| G14 | App running | uat_normal_one | Wrong OTP/password, insufficient balance, denied route. | Clear error; no crash; no balance change. **[READY]** | READ/WRITE |
| G15 | After all writes | uat_owner | Re-check roster, Admin codes, balances, open withdrawals. | Only explicit UAT writes differ. **[READY]** | READ |

## 5. Audit summary

### Ready
A1 (emulator subset or production), A2-A5 (after fresh users), A7, A8,
B1-B3, C1, C3-C6, D1-D6, E1-E7, E11-E12, F1 (two-step),
F2 (with known role behavior), F3-F6, G1-G6, G8, G10 (production),
G11-G15.

### Blocked or not client-only
- A6: no second branch/Super Admin fixture.
- B4: no 10-Account parallel fixture.
- B5, B6, C2, C7, E10: crafted-write/rules checks are developer evidence.
- E8: no reseller fixture.
- E9: no legacy withdrawal fixture.
- G7: mini-game fixture/configuration not confirmed.
- G9: push/FCM not available on emulator.

### Corrected statements
- Gift commission is wrong: gifts credit beans; recharge credits USD commission.
- F1 is not a transfer button; use remove + add.
- F2 does not remove the Host role or guarantee Host-panel removal.
- D3/E2 use the admin panel for USD Commission Wallet, not the Flutter
  Agency Portal.
- C6 routes are not redirected; only backend data protection is guaranteed.
- Production has 2 valid agency docs with no `adminId`/`branchId`/
  `superAdminId`; 8 invalid links remain; 101 unmarked accounts are Normal
  Users.

## 6. Evidence and sign-off

Capture for each row: ID, date/time, tester, account, Pass/Fail/Blocked,
actual result, evidence, defect ID.

| Role | Name | Decision | Date |
|---|---|---|---|
| Client UAT lead | `[FILL]` | Accept / Reject | `[FILL]` |
| Platform Owner | `[FILL]` | Accept / Reject | `[FILL]` |
| Engineering | `[FILL]` | Ready / Not ready | `[FILL]` |

Deployment is not approved if any A, B, C, E, or F money/isolation test fails,
or if a write touches data outside the approved UAT accounts.
