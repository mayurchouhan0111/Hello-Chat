# Admin Panel — Roles, Login & Testing Guide

> For: client / QA handoff
> Last verified: 2026-09-28 (all 5 tiers, 30/30 routes, emulator + production deploy)

---

## 1. How the role system works

There are **5 tiers**. Every screen, query and action is scoped by tier — the scope
is derived **on the server**, never from what the browser asks for.

| Tier | Rank | Sees | Cannot see |
|---|---|---|---|
| `owner` | 4 | Everything, global | — |
| `superadmin` | 3 | Own branch only | Company financials, audit logs, other branches |
| `admin` | 2 | Own agencies + their hosts | Other admins' branches, financials |
| `agency` | 1 | Own hosts | Everything above agency |
| `host` | 0 | Own profile only | **Cannot log into the admin panel at all** |

### The hierarchy

```
Owner
 └── provisionBranch() ──▶ Super Admin  (must have a branchId)
       └── assign role admin ──▶ Admin
             └── assign role agency ──▶ Agency
                   └── assign role host ──▶ Host
```

Each level **binds its own children server-side**. A Super Admin can never escape its
branch; an Admin always becomes `adminId` of the people it creates; an Agency always
becomes `agencyId` of the hosts it recruits.

### What each tier can open

| Route | owner | superadmin | admin | agency |
|---|:--:|:--:|:--:|:--:|
| Dashboard `/` | ✅ | ✅ | ✅ | — |
| Hierarchy `/hierarchy` | ✅ | ✅ | — | — |
| Users `/users` | ✅ | ✅ | ✅ | — |
| Agencies `/agencies` | ✅ | ✅ | ✅ | ✅ |
| Host Metrics `/hosts` | ✅ | ✅ | ✅ | ✅ |
| Live Rooms `/rooms` | ✅ | ✅ | ✅ | — |
| Reports `/reports` | ✅ | ✅ | ✅ | — |
| Commission Wallet `/commission-wallet` | ✅ | ⛔ policy-blocked | ✅ | ✅ |
| Financials, Withdrawals, Resellers, KYC, Settings, Logs, Moderation, Moments, VIP, SVIP, Gifts, Families, Boutique, Role Frames, Rocket, Winning Config, Mini Games, Family Battle, Room Support, Recharge Event, Events, Relationships (22 routes) | ✅ | 403 | 403 | 403 |

⛔ = shows a message, not an error. 403 = full-screen "Access denied — this section
requires the **owner** tier. You are signed in as **agency**."

---

## 2. How to log in

There is **one** login method: **phone number + OTP**. No email/password exists.

1. Go to the panel URL and enter a phone number in E.164 format (e.g. `+919000000001`).
2. Press **ENTER PLATFORM** — an SMS code is sent.
3. Enter the 6-digit code in **ENTRY KEY** and press **ESTABLISH LINK**.
4. If the account's tier is below `agency`, the login is rejected with
   `ACCESS DENIED: INSUFFICIENT PERMISSIONS FOR THIS NODE.`

**Production URL:** https://hellochat-e8965.web.app

---

## 3. Test accounts

These six accounts exist **only in the local emulator**. They are for automated/manual
testing on a developer machine; they have no real SMS attached.

| Role | Phone | OTP |
|---|---|---|
| Owner | `+919000000001` | random — see emulator log |
| Super Admin | `+919000000002` | random — see emulator log |
| Admin | `+919000000003` | random — see emulator log |
| Agency | `+919000000004` | random — see emulator log |
| Host | `+919000000005` | *(expected: rejected at login)* |
| Host 2 | `+919000000006` | — |

> **You cannot pre-set the OTP.** It is generated fresh on every attempt — both in the
> emulator and in production. Verified: even Firebase's documented test number
> `+9996661111` returned `979237`, not the documented `123456`. The column above is
> therefore "how to get it", not a fixed password.

The OTP is **random each attempt**. The emulator prints it:

```
To verify the phone number +919000000001, use the code 236098.
To verify the phone number +9996661111, use the code 979237.
```

Where to find it:
- the terminal running `firebase emulators:start`, or
- Emulator UI → **Authentication** tab → http://localhost:4000

**These six numbers are registered in BOTH the emulator and production.** They are
test numbers in the Firebase Console (*Authentication → Sign-in method → Phone →
Phone numbers for testing*), so they never send a real SMS — the fixed code below
is accepted instead.

### ✅ Production accounts — VERIFIED WORKING (real project `hellochat-e8965`)

All created by `node functions/provision_production_admins.js` and verified
end-to-end (OTP → token → privileged callable → live data).

**Login: `https://hellochat-e8965.web.app` — phone + OTP `123456` for every account.**

| Tier | Phone | UID | Scope | Users visible |
|---|---|---|---|---|
| **Owner** | `+919000000001` | `jvz5YOstXRTX2I1ujXOeGLFf7CL2` | `global` | **125** |
| **Super Admin** | `+919000000002` | `tkDQPhwRs0UdtPg0rWtuGzm1cWa2` | `branchId` | 6 |
| **Admin** | `+919000000003` | `hjntivA2pmasR8sE8QXGvABujNy2` | `adminId` | 4 |
| **Agency** | `+919000000004` | `lnmsVutlHiO7GDTkRmhRPvs5Y8J2` | `agencyId` | 3 |
| **Host** (denied) | `+919000000005` | `HfJJhQau7XfdrFXyhtjpCkyRKTw2` | `self` | 1 — **blocked at panel login** |
| Host 2 | `+917898840444` | `7onb5B5ZdbMbskb9yMYO8avvffl2` | `self` | 1 |
| Super Admin (your original) | `+916263850508` | `VJ1GwGfAwafIhCuHDaRTqBbdhYj2` | `branchId` | 6 |

Branch: **`branch-prod-1` — "Production Branch"** (Owner has no branch by design).

Verified 2026-09-28 against production:

| Check | Result |
|---|---|
| OTP `123456` accepted | ✅ returns a real `idToken` |
| Returned uid matches provisioned doc | ✅ `jvz5YOstXRTX2I1ujXOeGLFf7CL2` |
| `getScopedUsers` as Owner | ✅ `role:owner, scope:global, count:125` |
| as Super Admin | ✅ `scope:branchId, count:6` |
| as Admin | ✅ `scope:adminId, count:4` |
| as Agency | ✅ `scope:agencyId, count:3` |
| as Host | ✅ `scope:self` — sees only itself, panel login blocked |

> **Gotcha (already handled):** `createBaseUserDoc` (`functions/index.js:1079`) is an
> `onCreate` trigger that writes the user doc when an Auth user is created. It fired
> *after* the first provisioning pass and wiped `role`/`tags`. Re-running the script
> after creation fixes it — the trigger never fires twice. If you ever recreate an
> Auth user, **re-run the script**.

Anyone else (real users) signs up in the **mobile app** with their own phone first;
the panel then assigns a role to their UID via Hierarchy.

### Starting the test environment

```bash
# 1. emulators (auth + firestore + functions + storage + UI)
firebase emulators:start --only auth,firestore,functions,storage,ui

# 2. seed the 6 accounts + data for all 30 screens
node functions/seed_emulator.js

# 3. panel wired to the emulator (port 5174)
cd hellochat_admin
set VITE_USE_EMULATOR=1&& npx vite --port 5174 --strictPort
```

Open http://localhost:5174 and log in with a number from the table above.

> `VITE_USE_EMULATOR` is compiled out of production builds entirely — production
> always talks to the real project.

---

## 4. Creating real accounts for production

The 7 test accounts in §3 **already exist**. This section is for adding *real*
people later. Add them in this order:

### Step 0 — bootstrap the first Owner (one-time) ✅ DONE

No function can mint the first Owner. Already provisioned: `+919000000001` =
`owner`. To grant one to a different person, in **Firebase Console → Firestore →
`users`** set on their document:

```json
{ "role": "owner" }
```

(or add `"Owner"` to the existing `tags` array). Refresh the panel — the sidebar
now shows the full Owner menu. Every later Owner is granted from **Hierarchy**.

### Step 1 — Owner creates a branch + Super Admin

Panel → **Hierarchy & Branches** → **PROVISION NEW BRANCH**
- branch name
- target user's uid (the person who will be Super Admin)

This writes the `branches` document **and** sets `role: superadmin` + `branchId` on
that user. A Super Admin with **no branch sees nothing** — the branch is mandatory.

### Step 2 — Super Admin creates Admins

Panel → **Hierarchy** → pick a user → assign role **admin**.
Forced server-side: `branchId` = own branch, `superAdminId` = self, `adminId` = self.

### Step 3 — Admin creates Agencies

Panel → **Agencies** → assign role **agency**. Sets `isAgencyOwner: true`,
`adminId` = self.

### Step 4 — Agency recruits Hosts

Panel → **Agencies** → host recruitment, or Hierarchy → assign role **host**.
Sets `agencyId` = self. Hosts cannot log into the panel — they use the mobile app.

> **Login prerequisite:** each of these people must already exist as a Firebase Auth
> user (they sign up once in the mobile app with their own phone), because role
> assignment targets an existing `uid`.

---

## 5. Test status — what is proven and what is not

### ✅ Verified

| Area | Result |
|---|---|
| **PRODUCTION login — all 5 tiers** | phone + OTP `123456` → real `idToken` |
| **PRODUCTION server-side scoping** | `getScopedUsers`: owner `global/125`, superadmin `branchId/6`, admin `adminId/4`, agency `agencyId/3`, host `self` |
| Route guards | 30/30 as Super Admin; 403 correctness confirmed per tier |
| Unauthenticated access | all routes redirect to `/login` |
| **Owner — all 30 routes** | render with real data |
| **Super Admin — 7 routes** | render, branch-scoped (5 users vs Owner's 6) |
| **Admin — 7 routes** | render, scoped (4 users), 2 → 403 |
| **Agency — 3 routes** | render (wallet `$88.25`), 1 → 403 |
| **Host login** | correctly rejected |
| Tier logic unit tests | 9/9 |
| Console | 0 errors on every screen tested |
| Build / lint | `vite build` ✅, `eslint` 0 errors on changed files |

Sample data confirmed on screen: dashboard `$0.6 / 6 users / 3 PK battles / 6 rooms`,
gift catalog **12 assets**, moments 6, host roster 2 (58h live, 115M/200M beans 58%,
$420 recharge, 3 salary payouts), hierarchy branch, 4 resellers, withdrawals, KYC
queue, audit trail, reports, platform settings.

### ❌ Not verified — do not claim these work yet

1. **Every write operation.** 34 callables are deployed and confirmed *to exist*, but
   **none were executed**: `approveRecharge`, `issueRechargeOrder`,
   `provisionBranch`, `assignHierarchyRole`, `releaseHostFromAgency`,
   `deactivateAgency`, `updateFinancialPolicies`, `distributeWeeklySalary`,
   `convertCommissionToDiamonds`, `transferCommissionToReseller`,
   `submitCommissionWithdrawal`, `reviewCommissionWithdrawal`,
   `adminApproveWithdrawal`, `adminBanUser`, …
2. **File uploads** (gift icons, animations, banners) — not exercised.
3. **Panel UI clicked through on production** — accounts, OTP and server-side
   scoping are proven (§3/§5), but an automated browser could not finish the login
   UI because Google reCAPTCHA challenges automated sessions. **Open a normal
   browser and log in once per tier to eyeball the screens.**

---

## 6. Known issues

| # | Issue | Status |
|---|---|---|
| 1 | `Wallet` icon not imported → Owner/Admin/Agency sidebar crashed the whole app | **Fixed & deployed** |
| 2 | 8 panel collections had no Firestore rule → default deny (blank screens) | **Fixed & deployed** |
| 3 | TopBar showed "Welcome back, Super Admin" + blank avatar for everyone | **Fixed & deployed** |
| 4 | Rules used `if` statements → rules would not compile | **Fixed & deployed** |
| 5 | `scripts/service-account-key.json` is committed to the repo **and the key is revoked** (`Invalid JWT Signature`) | **Open — delete + rotate.** Provisioning now runs on the Firebase CLI token via `HC_USE_ADC=1` |
| 6 | ~~No production Owner / branch provisioned~~ | **Done** — 7 accounts + `branch-prod-1` |
| 7 | Recharge is fail-closed: no real payment gateway configured | **Open** |
| 8 | `AGORA_APP_CERTIFICATE` committed in plaintext in `functions/index.js` | **Open — rotate** |
| 9 | `createBaseUserDoc` overwrites a new user's `role`/`tags` if anything writes them first | **Known — re-run `provision_production_admins.js`** |

---

## 7. Re-running the full test

```bash
firebase emulators:start --only auth,firestore,functions,storage,ui   # terminal 1
node functions/seed_emulator.js                                       # terminal 2 (once)
cd hellochat_admin && set VITE_USE_EMULATOR=1&& npx vite --port 5174  # terminal 3
```

Log in as each phone in §3, click every sidebar item, and check:
- no black screen, no console errors,
- rows/numbers actually appear (not `0` / "NO … FOUND"),
- a tier-only route shows the **403** message rather than data.
