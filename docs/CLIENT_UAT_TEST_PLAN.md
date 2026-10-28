# Hello Chat Production UAT Test Plan

Status: **PLAN ONLY - NOT EXECUTED**
Project: `hellochat-e8965`
Audience: Platform Owner, client UAT coordinator, non-developer testers
Date: `[FILL]`
Build under test: `[FILL: commit / app version / admin build]`

## 1. Purpose and rules

This plan proves the production hierarchy, role-code allocation, agency
isolation, commission wallets, and the normal app flows with real accounts.

Rules for testers:

1. Use real Firebase accounts with real Hello IDs and production-style roles.
   Do not use `test_*` seeded documents as evidence.
2. Tests marked **READ** must not change money, roles, hosts, or agency data.
3. Tests marked **WRITE** must run only in the Owner-approved UAT branch with
   dedicated UAT accounts. Never use a client or real host account for a write
   test.
4. Every test records: Pass / Fail / Blocked, tester, time, account alias,
   evidence (screenshot, request ID, or function log line).
5. A failed money test stops the rest of that section. Do not "work around" a
   balance error by editing Firestore.
6. Do not test the 8 invalid `agencyId` links by repairing them during UAT.
   They are decision items, not test data.

## 2. Accounts to use

Replace bracketed values with accounts approved by the Owner before execution.
The real production identifiers below are evidence from the read-only audit.

| Alias | Role / purpose | Hello ID | UID | Notes |
|---|---|---|---|---|
| OWNER | Platform Owner | `[FILL]` | `[FILL]` | Full global scope. |
| SA-1 | Super Admin, `branch-prod-1` | `[FILL]` | `[FILL]` | Expected 4-digit role code. |
| ADM-1 | Admin, `branch-prod-1` | `3607188625` | `HgrLl9ubSmcZ0LdWi05MS0jHGvu1` | Also linked to agency `VO4m5hbOpMwLc6PDF1bn`. |
| ADM-2 | Admin, `branch-prod-1` | `1805742773` | `aRdHp4qLLKdd8qUoVTcgTcpZpKf2` | No `agencyId`. |
| ADM-3 | Admin, `branch-prod-1` | `3485703221` | `lDLp5QDDbXRzfT14qEAr4SauR0G3` | `agencyId` points to a user UID; decision item. |
| ADM-4 | Admin, `branch-prod-1` | `100003` | `PhFe53EOGzRxricZKawdA4DARcz2` | No `agencyId`. |
| AGY-A | Admin-panel agency wallet | `3607188625` | `HgrLl9ubSmcZ0LdWi05MS0jHGvu1` | Owns agency `VO4m5hbOpMwLc6PDF1bn` (`rofikul`). Admin role; use the admin Commission Wallet, not Agency Portal. |
| AGY-B | Second agency wallet (blocked) | `6114943995` | `8xS6BOlqjhMWuN9v7lxqoVulqan2` | Owns agency `pUOzQAMTYQlvrTsxCVlC` (`hello chat`); currently Normal User. Do not score until decision D1 is approved. |
| HOST-EXPLICIT | Explicit Host, roster check | `4926026367` | `4zbctX7hzLNBfeHsU7JU5prCrQt1` | Explicit `role: host`, no `agencyId`. |
| HOST-DEMOTED | Normal User regression | `3473579420` | `0Xt6Z8CaC5VUHm5UMZGA` | Was unmarked Host; must behave as Normal User. |
| USER-NORMAL | Normal User regression | `[FILL]` | `[FILL]` | A known normal account. |
| UAT-USER | Write tests | `[FILL]` | `[FILL]` | UAT branch only. |
| UAT-AGENCY | Write tests | `[FILL]` | `[FILL]` | UAT branch only. |
| UAT-HOST | Write tests | `[FILL]` | `[FILL]` | UAT branch only. |

No production account currently has BOTH an Agency role AND a valid agency document. AGY-A is an Admin who owns an agency document; AGY-B is a Normal User who owns one. The Agency Portal tests (C1, D3) must use a real UAT agency created by A3, not an emulator seed.

Expected Admin role codes: the four Admin accounts must each hold one of
`10000`, `10001`, `10003`, `10005`, with no duplicates. The exact
account-to-code mapping must be confirmed by the Owner before B1 is scored.

## 3. Environment and safety checklist

- [ ] UAT runs against the production Firebase project only after deployment
      approval.
- [ ] Owner has created an isolated UAT branch OR explicitly approved named
      test accounts for writes.
- [ ] Owner has approved the UAT window and named a stop-contact.
- [ ] Testers know that reading is unrestricted, but money writes are limited
      to UAT accounts.
- [ ] Screenshots do not expose full phone numbers, bank details, tokens, or
      passwords.
- [ ] The decision items in `docs/CLIENT_DECISIONS_NEEDED.md` are acknowledged
      before testing the affected accounts.

## 4. Test matrix

### A. Hierarchy and role creation

All A tests are **WRITE** for the test branch unless marked READ.

| ID | Preconditions | Steps | Expected result | Type |
|---|---|---|---|---|
| A1 | OWNER signed in | Open hierarchy/branch management; select `branch-prod-1`; view the four Admins. | Four Admins are visible under the correct branch and Super Admin. No cross-branch Admin appears. | READ |
| A2 | SA-1 signed in; a UAT normal user exists | Create an Admin from the UAT user; assign the correct Super Admin and branch. | New Admin is created with a 5-digit role code in `10000-99999`; user role is Admin; branch and Super Admin links are present. | WRITE |
| A3 | New UAT Admin signed in | Create an Agency from a UAT user. | Agency document is created; owner gets a 6-digit code in `100000-999999`; `adminId`, `branchId`, `superAdminId` are set; owner role is Agency. | WRITE |
| A4 | New UAT Agency signed in | Assign a UAT user as Host. | Host user stores the agency **document ID** in `agencyId`, not the caller UID; host appears in the agency roster. | WRITE |
| A5 | SA-1 signed in | Attempt to create an Admin without a Super Admin, then with a normal-user parent. | Both attempts are rejected with a clear error; no partial user/role document is left behind. | WRITE |
| A6 | SA-1 signed in | Attempt to create an Admin under another branch's Super Admin. | Request is denied; no cross-branch link is written. | WRITE |
| A7 | ADM-1 signed in | Open the branch user list. | Only users in ADM-1's branch/scope appear; no Owner-only controls are visible. | READ |
| A8 | HOST-DEMOTED signed in | Open the profile and any role-specific entry points. | Account is treated as Normal User; no Agency Portal, Host controls, or Admin panel access. | READ |

### B. Role-code allocation

| ID | Preconditions | Steps | Expected result | Type |
|---|---|---|---|---|
| B1 | OWNER signed in | Open the four Admin records and record each `roleCode`. | Exactly one each of `10000`, `10001`, `10003`, `10005`; no missing/duplicate code. Confirm mapping with Owner. | READ |
| B2 | SA-1 signed in | Create one UAT Admin. | Code is 5 digits, greater than the previous Admin code, and unique. | WRITE |
| B3 | UAT Admin signed in | Create one UAT Agency. | Code is 6 digits in `100000-999999` and unique. | WRITE |
| B4 | Two Admin sessions, UAT branch | Create 10 Admins in parallel from two sessions. | All 10 succeed or fail cleanly; no duplicate codes; codes remain monotonic. | WRITE |
| B5 | UAT branch | Attempt to allocate outside the allowed range using a client-side forged request. | Server rejects; client cannot set `roleCode` directly. | WRITE |
| B6 | Any signed-in user | Attempt to edit own `roleCode`, `role`, `branchId`, `adminId`, `agencyId`. | All protected-field writes are denied. | WRITE |

### C. Agency isolation

| ID | Preconditions | Steps | Expected result | Type |
|---|---|---|---|---|
| C1 | UAT-AGENCY signed in (created by A3) | Open Agency Portal -> hosts and wallet. | Only the UAT agency hosts and wallet are visible. | READ |
| C2 | UAT-AGENCY signed in | Attempt to read agency `pUOz...` hosts, wallet, or ledger by ID. | Permission denied; no data is returned. | READ |
| C3 | ADM-1 signed in | Open agency management. | Only agencies under ADM-1's branch/scope appear. | READ |
| C4 | SA-1 signed in | Open branch agencies. | Only `branch-prod-1` agencies appear. | READ |
| C5 | OWNER signed in | Open all agencies. | All agencies appear, including both current production agencies and the UAT agency; no client data is mutated. | READ |
| C6 | USER-NORMAL signed in | Attempt to open Admin/Agency routes directly. | Access denied or redirected; no privileged data loads. | READ |
| C7 | Any agency account | Attempt a client write to `/agencies/{otherAgency}`. | Rules deny the write. | WRITE |

### D. One panel per role

| ID | Preconditions | Steps | Expected result | Type |
|---|---|---|---|---|
| D1 | USER-NORMAL signed in | Inspect home, profile, and menus. | Normal User surfaces only; no Admin/Agency/Host management controls. | READ |
| D2 | HOST-EXPLICIT signed in | Open host surfaces. | Only host-relevant controls; no branch-wide Admin controls. | READ |
| D3 | UAT-AGENCY signed in | Open Agency Portal and commission wallet. | Agency wallet/portal loads; branch-wide admin controls are absent. | READ |
| D4 | ADM-1 signed in | Open Admin panel. | Branch-scoped users/agencies/withdrawals load; Owner-only global controls are absent. | READ |
| D5 | SA-1 signed in | Open Super Admin panel. | Branch scope only; no global Owner controls. | READ |
| D6 | OWNER signed in | Open Owner panel. | Global scope and Owner-only controls are available. | READ |

### E. Commission wallet, recharge, withdrawal

E1-E3, E5-E9, E11 are **WRITE** and must use UAT accounts. E4 and E10 can be
read-only policy checks.

| ID | Preconditions | Steps | Expected result | Type |
|---|---|---|---|---|
| E1 | UAT Host linked to UAT Agency; recharge policy configured | Make an approved test recharge that generates commission. | Commission is credited to the **agency document**, not the owner's user document; ledger entry names the source and rates. | WRITE |
| E2 | AGY-A signed in; legacy user balance and agency balance both known | Open the admin Commission Wallet. | Available balance = legacy user USD + agency USD. Pending, total earned, total withdrawn, and total recharge are also summed. Diamonds remain user-only. | READ |
| E3 | UAT Agency has legacy $X and agency $Y | Convert a small amount `<= X`. Then convert an amount `> X`. | First debit consumes legacy $X and leaves agency balance untouched; next debit consumes the remainder from the agency document. No negative balance. | WRITE |
| E4 | UAT Agency | Attempt withdrawal below the configured minimum. | Rejected before any balance change; message states the minimum. | WRITE |
| E5 | UAT Agency balance sufficient; UAT withdrawal request pending | Owner approves, then pays. | User/agency pending balances decrease; `totalWithdrawnUSD` increases by the exact split; request records approver, payer, and timestamps. | WRITE |
| E6 | UAT withdrawal request pending | Owner rejects. | User and agency balances are refunded to the exact original split; pending balances return to zero; rejection reason is recorded. | WRITE |
| E7 | UAT Agency has legacy + agency USD | Convert commission to Diamonds. | Diamonds credited at the configured rate; both sources debited correctly; transaction log shows the split. | WRITE |
| E8 | UAT Agency has legacy + agency USD; UAT reseller exists | Transfer commission to the reseller. | Sender split debited correctly; reseller `walletBalance` credited once; no double credit. | WRITE |
| E9 | An old withdrawal request with no split fields | Approve/pay and reject a copy in UAT. | Legacy request spends/refunds the user document only; no agency balance is touched. | WRITE |
| E10 | AGY-A signed in | Attempt to edit `usdCommissionBalance` or any protected agency ledger field through a crafted client. | Rules deny; the UI cannot override balances. | WRITE |
| E11 | AGY-A signed in | Open the admin wallet, withdrawal history, and commission ledger. | Only own records appear; no other agency's withdrawal or ledger is visible. | READ |
| E12 | Two parallel UAT withdrawals | Submit two requests that together exceed the balance. | Only one succeeds; the other fails with insufficient balance; no negative balance and no duplicate ledger entry. | WRITE |

### F. Transfers, removals, and agency lifecycle

| ID | Preconditions | Steps | Expected result | Type |
|---|---|---|---|---|
| F1 | UAT Host in UAT Agency A | Transfer the Host to UAT Agency B. | Host `agencyId` changes to Agency B document ID; both rosters update; no balance is moved. | WRITE |
| F2 | UAT Agency A signed in | Remove a Host. | Host loses agency link; Host panel access is removed; agency roster count decreases. | WRITE |
| F3 | UAT Agency with balances | Deactivate the agency. | Agency is marked inactive, hosts are released, balances are retained for audit; no silent deletion. | WRITE |
| F4 | Deactivated UAT Agency | Attempt a commission withdrawal. | Request is rejected; no funds move. | WRITE |
| F5 | UAT Admin | Reassign a released Host to another agency. | New agency document ID is stored; old roster no longer contains the Host. | WRITE |
| F6 | Any tester | Inspect the three explicit Host accounts. | Roster shows exactly 3 explicit Hosts; 101 former unmarked accounts behave as Normal Users. The 8 invalid links remain unchanged and are listed as decision items. | READ |

### G. Full regression

| ID | Area | Steps | Expected result | Type |
|---|---|---|---|---|
| G1 | Login / registration | Sign in with each role; register a UAT user. | No crash; role routing is correct; errors are human-readable. | READ/WRITE |
| G2 | Rooms | List, create, enter, leave, seat, unseat, send a message. | Room and seat flows work; Admin seat label is correct. | WRITE |
| G3 | Gifts | Open gift panel, send a normal gift and a combo. | Gift animation plays; balance deducts once; combo counter works. | WRITE |
| G4 | Recharge | Open recharge packages; complete a UAT test recharge. | Diamonds/beans credit once; history shows the transaction; commission path is covered by E1. | WRITE |
| G5 | Wallet | Open wallet, transaction history, withdrawal history. | Balances match Firestore; no stale values; no unauthorized entries. | READ |
| G6 | VIP / SVIP | Open VIP/SVIP screens; purchase only with UAT account. | Entitlements update; no duplicate charge. | WRITE |
| G7 | Games | Open game lobby; run one UAT round. | Balance guard prevents over-betting; result/history persists. | WRITE |
| G8 | Chat / friends | Send/receive chat; open a friend profile. | Messages deliver; public profile hides private wallet/role fields. | WRITE |
| G9 | Notifications | Trigger a UAT notification; open it. | Deep link lands on the correct screen; no crash. | WRITE |
| G10 | Admin Commission Wallet | Open as ADM-1 and AGY-A. | Agency + legacy values match; diamonds remain user-only; denied agency read falls back cleanly. | READ |
| G11 | Owner withdrawal queue | Open queue; inspect a UAT request. | Approve/pay/reject only in UAT; status transitions are correct; no production request touched. | READ/WRITE |
| G12 | Audit logs | Open Admin/Owner audit logs. | Role changes, withdrawals, and agency changes are recorded with actor and timestamp. | READ |
| G13 | Logout / re-login | Sign out and back in as each role. | No stale role/agency data; no privilege leak. | READ |
| G14 | Error states | Use wrong OTP/password, insufficient balance, denied route. | Clear error; no crash; no balance change. | READ/WRITE |
| G15 | Regression watch | After all tests, re-check roster, four Admin codes, agency balances, and open withdrawals. | Values are unchanged except for explicit UAT writes; no unexplained drift. | READ |

## 5. Evidence and sign-off

For each executed row capture:

- Test ID, date/time, tester, account alias.
- Pass / Fail / Blocked.
- Actual result.
- Evidence: screenshot file name, withdrawal request ID, or function log
  timestamp.
- Defect ID if failed.

Sign-off:

| Role | Name | Decision | Date |
|---|---|---|---|
| Client UAT lead | `[FILL]` | Accept / Reject | `[FILL]` |
| Platform Owner | `[FILL]` | Accept / Reject | `[FILL]` |
| Engineering | `[FILL]` | Ready / Not ready | `[FILL]` |

Deployment is not approved if any A, B, C, E, or F money/isolation test fails,
or if any test changes data outside the approved UAT accounts.


