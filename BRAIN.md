# HELLO CHAT - MASTER SYSTEM BRAIN & OPERATIONAL CONSTITUTION

> **CRITICAL DIRECTIVE FOR ALL AI ASSISTANTS & DEVELOPERS**
> Every task on this codebase must adhere strictly to this document.
> Unrequested modifications, accidental regressions, or touching unrelated features is strictly forbidden.

---

## SECTION 1: THE ZERO-REGRESSION & SCOPE ISOLATION CONSTITUTION

### 1. The Core Law of Preservation
- **NEVER MODIFY UNREQUESTED FEATURES**: You are permitted to modify **ONLY** the specific files, components, and functions directly required to complete the user's explicit request.
- **SURGICAL DIFFS OVER BROAD REWRITES**: Never rewrite entire files when a targeted guard solves the problem. Keep git diffs minimal, clean, and contained.
- **PRESERVE EXISTING SETTINGS & LOGIC**:
  - Do not change existing UI layouts, color tokens, button behaviors, routing, or state management in unaffected areas.
  - Do not alter Firebase configurations, Agora RTC streaming pipelines, or game mechanics unless explicitly instructed.
- **PRE-DELIVERY VERIFICATION REQUIREMENT**:
  - Before declaring any task complete, you MUST verify that all previously working features in the affected module and connected modules remain 100% functional.
  - If a change touches a shared service (e.g. `base_firebase_service.dart`, `users` collection, or `AdminContext.jsx`), verify every dependent screen to ensure zero side-effects.

### 2. Blast Radius Protocol
Before touching any file, trace its usage across the project:
1. **Find all callers** using grep/search.
2. **Ensure backwards compatibility**: If modifying an API or model, maintain optional fields and default values so existing callers do not break.
3. **Run validation tests**: Execute `flutter analyze` and relevant unit/widget tests before handing off.

---

## SECTION 2: HIERARCHY-BASED PERMISSION MANAGEMENT SYSTEM (HB-PMS)

This specification defines the 5-Tier Hierarchy-Based Permission Management System (HB-PMS) governing administrative, operational, and financial control across the platform.

```
                    ┌─────────────────────────┐
                    │          OWNER          │ (Apex Authority - Global & Financial Control)
                    └────────────┬────────────┘
                                 │ Provision Branches / Super Admins
                    ┌────────────▼────────────┐
                    │       SUPER ADMIN       │ (Branch Authority - Branch Sandboxed)
                    └────────────┬────────────┘
                                 │ Create & Assign Admins
                    ┌────────────▼────────────┐
                    │          ADMIN          │ (Middle Management - Agency Supervision)
                    └────────────┬────────────┘
                                 │ Recruit & Onboard Agencies
                    ┌────────────▼────────────┐
                    │         AGENCY          │ (Operational Unit - Host Management)
                    └────────────┬────────────┘
                                 │ Recruit & Manage Hosts
                    ┌────────────▼────────────┐
                    │          HOST           │ (Content Creator - Self Account Only)
                    └─────────────────────────┘
```

---

### 2.1 Role Definitions & Permission Matrix

#### 1. OWNER (Apex Platform Authority)
- **Role Identifier**: `role: 'owner'`
- **Management Scope**: Global. Apex authority over all Super Admins, Admins, Agencies, and Hosts across all branches.
- **Key Responsibilities**:
  - Account Management: Create, suspend, activate, or remove Super Admin accounts.
  - Branch Provisioning: Establish independent operational branches/teams for each Super Admin.
  - Supervision Assignment: Assign or reassign Admins to specific Super Admin branches.
  - **Exclusive Financial Authority**:
    - Sole authority to configure or modify **Salary Rules, Salary Amounts, Commission Percentages, Commission Slabs, Recharge Targets, Beans Targets, and Salary Targets**.
    - Full control over global financial policies, exchange rates, and business rules.
    - Ability to cryptographically lock/unlock global financial settings.
  - **Global Oversight**: Access to platform-wide raw data, cross-branch performance reports, and global audit logs.
- **RESTRICTION**: No role other than the Owner can modify any company financial rule, salary amount, commission slab, or business policy.

#### 2. SUPER ADMIN (Branch Authority)
- **Role Identifier**: `role: 'superadmin'`
- **Scope Identifier**: `branchId: '<branch_id>'`
- **Management Scope**: Strict Branch Sandboxing. Multiple Super Admins operate simultaneously in total isolation.
- **Key Responsibilities**:
  - Branch Administration: Create, manage, and remove Admins strictly within their own branch.
  - Hierarchy Visibility: View Admins, Agencies, and Hosts assigned under their specific branch. Cross-branch data is strictly invisible and inaccessible.
  - Operational Monitoring: Real-time access to branch reports (Live Time, Live Day, Beans Target, Recharge, Salary, Commission, and Performance Reports).
  - Payout Workflow: Review, approve, or reject salaries and commissions strictly according to Owner-configured rules.
- **STRICT PROHIBITIONS**:
  - A Super Admin **CANNOT** create another Super Admin.
  - A Super Admin **CANNOT** view or access data of any other Super Admin branch.
  - A Super Admin **CANNOT** modify Salary Rules, Salary Amounts, Commission Percentages, Recharge Targets, Commission Slabs, Beans Targets, or Financial Policies.

#### 3. ADMIN (Middle Management / Agency Supervisor)
- **Role Identifier**: `role: 'admin'`
- **Scope Identifier**: `branchId: '<branch_id>'`, `adminId: '<admin_uid>'`
- **Management Scope**: Assigned to exactly one Super Admin branch.
- **Key Responsibilities**:
  - Agency Management: Recruit, onboard, and manage operational Agencies under their direct supervision.
  - Visibility Scope: View only the Agencies under their supervision and the Hosts operating under those Agencies.
  - Monitoring Access: Live Time, Live Day, Beans Target, Recharge, Performance, and Salary Status reports for their assigned Agencies/Hosts.
- **STRICT PROHIBITIONS**:
  - An Admin **CANNOT** view or manage another Admin's Agencies or Hosts.
  - An Admin **CANNOT** create Admins or Super Admins.
  - An Admin **CANNOT** modify any financial rules, salary amounts, commission slabs, or targets.

#### 4. AGENCY (Operational Management)
- **Role Identifier**: `role: 'agency'`
- **Scope Identifier**: `agencyId: '<agency_uid>'`, `adminId: '<admin_uid>'`, `branchId: '<branch_id>'`
- **Management Scope**: Directly recruits talent and manages streaming hosts.
- **Key Responsibilities**:
  - Host Management: Recruit, onboard, and manage assigned Hosts.
  - Visibility Scope: View strictly their own recruited Hosts and associated metrics.
  - Monitoring Reports: Host Live Time, Live Days, Beans Target Progress, Recharge Reports, Performance Reports, and Salary Status.
- **STRICT PROHIBITIONS**:
  - An Agency **CANNOT** view another Agency's Hosts, revenue, or performance.
  - An Agency **CANNOT** modify financial policies, commission rates, or salary rules.

#### 5. HOST (Content Creator)
- **Role Identifier**: `role: 'host'` (or default user)
- **Scope Identifier**: `agencyId: '<agency_uid>'`, `uid: '<user_uid>'`
- **Management Scope**: Self account only.
- **Key Responsibilities**: Personal Dashboard (Live Time, Live Days, Beans Progress, Recharge History, Salary Status, Personal Performance).
- **STRICT PROHIBITIONS**: Zero administrative, management, or financial privileges.

---

### 2.2 Hierarchy-Based Access Control (HBAC) Matrix

| Dimension | Owner | Super Admin | Admin | Agency | Host |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Manage Super Admins** | ✅ Yes | ❌ No | ❌ No | ❌ No | ❌ No |
| **Create Branches** | ✅ Yes | ❌ No | ❌ No | ❌ No | ❌ No |
| **Manage Admins** | ✅ All Admins | ✅ Own Branch Only | ❌ No | ❌ No | ❌ No |
| **Manage Agencies** | ✅ All Agencies | ✅ Own Branch Only | ✅ Supervised Only | ❌ No | ❌ No |
| **Manage Hosts** | ✅ All Hosts | ✅ Own Branch Only | ✅ Supervised Only | ✅ Own Agency Only | ❌ Self Only |
| **Modify Financial Rules** | ✅ Full Control | ❌ **PROHIBITED** | ❌ **PROHIBITED** | ❌ **PROHIBITED** | ❌ **PROHIBITED** |
| **Approve Salary Payouts** | ✅ Global | ✅ Own Branch Only | ❌ No | ❌ No | ❌ No |
| **Data Visibility Scope** | Global (Platform) | Branch Sandbox | Supervised Agencies | Recruited Hosts | Self Account |

---

### 2.3 Security & Financial Protection Architecture

1. **Immutable Financial Storage**:
   - Financial parameters (salary tables, commission percentages, recharge slabs) are stored in `system_configs/financial_policies` and `system_configs/salary_rules`.
   - Write access is strictly restricted to `role == 'owner'` at both Firestore Security Rules and Cloud Function callable levels.
2. **Branch Sandboxing (Query Injection)**:
   - Every read/write query in the admin dashboard and Cloud Functions must inject hierarchical filters:
     - Owner: No filter injected (sees all).
     - Super Admin: Filter `where('branchId', '==', user.branchId)`.
     - Admin: Filter `where('adminId', '==', user.uid)`.
     - Agency: Filter `where('agencyId', '==', user.uid)`.
   - Horizontal privilege escalation across branches is blocked at both client and server layers.
3. **Immutable Audit Trail (`audit_logs`)**:
   - Every approval, rejection, account creation, role assignment, or policy modification must generate an immutable audit document:
     ```json
     {
       "actorUid": "uid_of_actor",
       "actorRole": "superadmin",
       "branchId": "branch_alpha",
       "action": "SALARY_APPROVE",
       "targetId": "payout_doc_123",
       "details": { "amount": 1500, "hostUid": "host_456" },
       "timestamp": "serverTimestamp"
     }
     ```
   - Readable exclusively by the Owner.

---

## SECTION 3: AGENCY & ADMIN RECHARGE COMMISSION WALLET & SALARY SYSTEM

### 3.1 Real-Time Recharge Commission Logic
Whenever a Host recharges funds into the platform, the recharge event triggers instant multi-tier ledger tracking and automatic commission calculations:

- **Formula & Standard Rates (Default Rules)**:
  - **Agency Commission**: `30% (0.30)` of Host recharge amount.
  - **Admin Commission**: `10% (0.10)` of Host recharge amount.
- **Calculation Example**:
  - Host A recharges $40, Host B recharges $35, Host C recharges $25.
  - Total Agency Host Recharge: `$40 + $35 + $25 = $100.00 USD`.
  - **Agency Commission Earned (30%)**: `$100.00 × 0.30 = $30.00 USD`.
  - **Admin Commission Earned (10%)**: `$100.00 × 0.10 = $10.00 USD`.
- **Real-Time Settlement**:
  - Calculated earnings are credited automatically in real time to the respective Agency and Admin USD Commission Wallets via atomic Firestore transactions (`db.runTransaction`).
  - Immutable credit records are logged to `commission_transactions`.

---

### 3.2 Dedicated USD Commission Wallets

#### Agency Commission Wallet (USD)
1. **Total Recharge**: Cumulative total USD recharge generated by all Hosts under the Agency.
2. **Total Commission Earned**: Lifetime 30% commission accrued from sub-host recharges.
3. **Available Balance**: Current withdrawable funds in USD.
4. **Total Withdrawn**: Sum of all Owner-approved and disbursed withdrawal requests.
5. **Pending Withdrawals**: Total amount locked in active withdrawal requests awaiting Owner review.
6. **Payment History**: Complete audit ledger of all credits, withdrawal requests, approvals, and rejections.

#### Admin Commission Wallet (USD)
1. **Total Agencies & Hosts**: Real-time count of assigned operational agencies and active hosts.
2. **Total Recharge**: Aggregate recharge volume across all Agencies under the Admin's supervision.
3. **Total Commission Earned**: Lifetime 10% commission accrued from all supervised host activities.
4. **Available Balance**: Current withdrawable funds in USD.
5. **Total Withdrawn**: Sum of all Owner-approved and disbursed withdrawal requests.
6. **Pending Withdrawals**: Total amount locked in active withdrawal requests awaiting Owner review.
7. **Payment History**: Complete audit ledger matching platform wallet standards.

---

### 3.3 Integrated Salary System & Super Admin Exclusion Rule

| Role | Salary Eligibility | Salary Wallet & Module Access | Operational Authority |
| :--- | :--- | :--- | :--- |
| **Agency** | **Eligible** | **Full Access** (View salary targets, progress, and payouts) | Subject to Owner-configured rules |
| **Admin** | **Eligible** | **Full Access** (View sub-agency metrics & salary status) | Subject to Owner-configured rules |
| **Super Admin** | **INELIGIBLE** | **NO ACCESS / NO WALLET** | Operational Monitoring & Approval Workflows Only |
| **Owner** | System Operator | Global Policy & Configuration Control | Full Control (Schedules, targets, rules) |

> [!CAUTION]
> **Super Admin Exclusion Rule**:
> Super Admins do **NOT** participate in the Salary System. They possess **NO** salary balance, **NO** salary wallet, and **NO** payment ledger within the application. Their role is strictly branch supervision, operational monitoring, and approval workflows according to Owner rules.

---

## SECTION 4: COMMISSION WITHDRAWAL & RESELLER TRANSFER SYSTEM

Both Agencies and Admins maintain a dedicated, real-time Commission Wallet (USD) with three flexible methods to utilize their commission balances:

```
                              [Commission Wallet (USD)]
                                         │
       ┌─────────────────────────────────┼─────────────────────────────────┐
       ▼                                 ▼                                 ▼
[OPTION 1: Reseller Transfer]  [OPTION 2: Direct Withdrawal]   [OPTION 3: Convert to Diamonds]
- Instant transfer to Reseller - Manual Owner Approval Queue   - Instant USD ➔ Diamonds
- Credit to Reseller Wallet    - Configured Local/Intl Gateways- Default: $1 = 1,000,000 Diamonds
- Reseller sells Diamonds      - Status: Pending➔Processing➔   - Configurable in Admin Panel
- Dedicated Ledger:              Approved➔Paid / Rejected      - Dedicated Ledger:
  'commission_reseller_transfers'- Dedicated Ledger:             'commission_diamond_conversions'
                                 'commission_withdrawals'
```

### 4.1 Option 1: Reseller Wallet Transfer System
- **Execution Mechanics**:
  1. Agency or Admin selects **"Transfer to Reseller Wallet"** in their Commission Wallet.
  2. Enter or search for the target Reseller ID/Wallet.
  3. Enter transfer amount in USD (must be `≤ Available Balance`).
  4. System executes atomic transaction: deducts USD from Commission Wallet and instantly credits the Reseller Wallet.
  5. The Reseller uses the credited balance to purchase/receive platform Diamonds to sell to end-users.
- **Audit Trail & Dedicated Ledger (`commission_reseller_transfers`)**:
  - `transactionId`: Unique hash (e.g. `TRF-90823471-USD`).
  - `createdAt`: Exact UTC timestamp.
  - `usdAmount`: Exact amount transferred.
  - `senderUid`: Agency or Admin unique UID and title.
  - `receiverUid`: Target Reseller UID and wallet ID.
  - `status`: `'completed'` or `'failed'`.

---

### 4.2 Option 2: Direct Withdrawal Engine & Configurable Gateways

#### 1. Dynamic Gateway Configuration Policy (Owner Managed Exclusively)
All payout gateways are dynamically maintained in `system_configs/financial_policies.supportedGateways`:
- **Bangladesh Channels**: `bKash`, `Nagad`, `Rocket`, `Direct Local Bank Transfer`.
- **International Channels**: `Bank Wire Transfer`, `PayPal`, `Wise`, `Binance Pay`, `USDT (TRC20)`, `USDT (BEP20)`.
- **Custom Channels**: Custom payment channels or crypto networks added dynamically by Owner.

#### 2. Request Requirements
When requesting a withdrawal, the user provides:
- `usdAmount`: Withdrawal amount in USD.
- `paymentMethod`: Selected payment gateway/method from Owner's active list.
- `paymentAccountDetails`: Account number, IBAN, Swift, phone number, or crypto wallet address.

#### 3. Owner Approval Workflow & SLA Timeline (1 to 7 Business Days)
Direct withdrawals are NEVER automated. Every request enters an approval queue managed solely by the Owner or authorized Finance Manager.

| Status Badge | Stage Description & Financial Impact |
| :--- | :--- |
| **Pending** | Request submitted. Funds locked into `pendingWithdrawals`, deducted from `availableBalance`. Awaiting Owner review. |
| **Processing** | Owner/Finance Manager accepted request for verification and financial dispatch. |
| **Approved** | Verification passed; payout instructions queued with bank/gateway processor. |
| **Paid** | Payout verified as completed. Status marked `Paid`, permanently deducted, recorded in `Payment History`. |
| **Rejected** | Request declined. Locked funds refunded immediately back to `availableBalance`. Logged with rejection notes. |

---

## SECTION 5: USD COMMISSION TO DIAMOND CONVERSION SYSTEM

In addition to Direct Withdrawals and Reseller Transfers, Agencies and Admins can convert their earned USD Commission directly into Diamonds:

### 5.1 Conversion Rules & Core Requirements
1. **Eligibility**: Accessible to all Agency and Admin accounts holding an active USD Commission balance.
2. **Independent Operations**: Direct Withdrawals, Reseller Transfers, and Diamond Conversions operate 100% independently. Users may utilize any option at any time based on their available balance.
3. **Conversion Rate**:
   - **Default Rate**: `1 USD = 1,000,000 Diamonds`.
   - **Dynamic Configuration**: The rate is stored in `system_configs/financial_policies.usdToDiamondRate` and can be adjusted at any time exclusively by the Owner from the Admin Panel.
4. **Execution Flow & Atomic Safety**:
   - User inputs USD amount to convert (e.g. `$5.00 USD`).
   - System calculates equivalent Diamonds (`usdAmount × usdToDiamondRate`, e.g. `5 × 1,000,000 = 5,000,000 Diamonds`).
   - **Pre-flight Validation**: If `usdAmount > availableCommissionBalance`, transaction is rejected immediately with an explicit error: `"Insufficient USD commission balance."`
   - **Atomic Transaction (`db.runTransaction`)**:
     - Deduct `usdAmount` from user's `usdCommissionBalance`.
     - Instantly increment user's `diamondBalance` by the calculated diamond count.
     - Insert conversion record into `commission_diamond_conversions`.
5. **Dedicated Audit Ledger (`commission_diamond_conversions`)**:
   Every conversion is recorded permanently with:
   - `id`: Unique Firestore document ID.
   - `userId`: UID of the converting user.
   - `usdAmount`: Exact USD amount converted.
   - `conversionRate`: Conversion rate applied at the moment of the transaction (e.g. `1,000,000`).
   - `diamondsReceived`: Exact diamond amount credited.
   - `status`: `'completed'`.
   - `createdAt`: UTC Server timestamp.

---

## SECTION 6: ISOLATED LEDGERS & DATA INTEGRITY MATRIX

To guarantee clean financial auditing, all monetary activities are isolated into strictly separated database collections:

| Activity | Database Collection | Write Authority | Read Authority |
| :--- | :--- | :--- | :--- |
| **Recharge Commissions** | `commission_transactions` | Cloud Functions (Atomic on Recharge) | User (own), Owner (global) |
| **Direct Cash Withdrawals** | `commission_withdrawals` | User (create), Owner (review/approve/reject) | User (own), Owner (global) |
| **Reseller Wallet Transfers** | `commission_reseller_transfers` | Cloud Functions (Atomic Transfer) | User (own), Reseller (own), Owner |
| **Diamond Conversions** | `commission_diamond_conversions` | Cloud Functions (Atomic Conversion) | User (own), Owner (global) |
| **System Audit Logs** | `audit_logs` | Cloud Functions & Backend Services | Owner Only |

---

## SECTION 7: REPOSITORY ARCHITECTURE & SAFEGUARD INVENTORY

To prevent accidental regressions, here is the registry of core modules and their isolation boundaries:

| Module | Location | Critical Protection Rule |
| :--- | :--- | :--- |
| **Spin Wheel Game** | `lib/features/games/presentation/screens/spin_wheel_screen.dart` | 40s server cycle, 0s-30s betting, 30s-35s spin, 35s-40s celebration. Strict offline detection via `NetworkConnectivityService`. Server authority on all payouts. DO NOT alter timing or outcome reveal logic. |
| **Lucky Draw Game** | `lib/features/games/presentation/screens/lucky_draw_screen.dart` | Offline button disablement. Offline check in `_play()`. DO NOT remove connectivity guard. |
| **Voice Streaming (Agora)** | `lib/features/rooms/` | Agora RTC voice engine, audio mixing, floating overlay. DO NOT modify room tokens, permissions, or channel IDs. |
| **Gifts & Rocket System** | `functions/index.js`, `lib/features/gifts/` | Atomic transaction wallet mutations (`db.runTransaction`), rocket fuel thresholds. Server-side math only. |
| **Admin Dashboard** | `hellochat_admin/src/` | React 19 + Tailwind dashboard. HBAC must be implemented without altering the visual styling or existing features of other screens. |
| **Commission Wallets** | `functions/index.js`, `hellochat_admin/src/screens/FinancialManagement.jsx`, `lib/features/profile/presentation/screens/agency/commission_wallet_screen.dart` | 30% Agency / 10% Admin real-time split. Dedicated Agency & Admin USD wallets. Super Admin has NO salary wallet. Reseller transfer, Direct withdrawal, Diamond conversion. |
| **Cloud Functions** | `functions/index.js` | Backend authority for all balance modifications, role validations, and salary payouts. |
| **SVIP Membership System** | `functions/index.js`, `lib/core/models/svip_level_model.dart`, `lib/core/widgets/user_badge.dart`, `hellochat_admin/src/screens/SVIPManagement.jsx`, `lib/features/profile/presentation/screens/agency/svip_privileges_screen.dart` | 6 tiers ($50-$2500, 5k-250k pts). 1 USD = 100 SVIP Points. Immediate upgrade + 60-day validity + RESET POINTS TO 0. 60-day cycle renewal evaluation (Upgrade, Maintain, Downgrade, Expire). 24h server UTC Daily Diamond Claim. Room kick & mute protection (SVIP 4-6). SVIP 6 global kick. 11 privileges. Video-exact pill badges with metallic gradients & glowing borders. |

---

## SECTION 8: SVIP MEMBERSHIP SYSTEM ARCHITECTURE & PRIVILEGE ENGINE

### 8.1 Core Parameters & Tier Specification
- **Conversion Rate**: $1.00 USD recharge = 100 SVIP Points. (Only gold coin recharge transactions generate points; diamonds/coins/XP are tracked in separate ledgers).
- **Tier Structure**:
  - **SVIP 1**: 5,000 Points ($50 USD) | 25,000 Daily Diamonds | Family Battle Name, Temp ID Swap (24h, 5 IDs).
  - **SVIP 2**: 10,000 Points ($100 USD) | 50,000 Daily Diamonds | Family Logo Edit, Temp ID Swap (72h, 7 IDs).
  - **SVIP 3**: 20,000 Points ($200 USD) | 100,000 Daily Diamonds | Friend Hide (2 IDs), CP Lock (24h/72h/7d), Family Description/Announcement/Transfer.
  - **SVIP 4**: 50,000 Points ($500 USD) | 250,000 Daily Diamonds | Mystery Man Profile Hide (Self), Room Kick & Mute Immunity, CP Lock (+30d).
  - **SVIP 5**: 100,000 Points ($1,000 USD) | 500,000 Daily Diamonds | Mystery Man (+2 IDs), Room Protection Delegation (5 users for 30d), CP Lock (+Permanent).
  - **SVIP 6**: 250,000 Points ($2,500 USD) | 1,000,000 Daily Diamonds | Global Room Kick, Mystery Man (+10 IDs), Friend Hide (25 IDs + SVIP Star), CP Removal Request (max 5), Protection Delegation (10 users for 30d).

### 8.2 60-Day Validity & Point Reset Rules
1. **Immediate Level Upgrade**: When a user's accumulated points reach or exceed the threshold of a higher tier during a recharge transaction:
   - User is instantly upgraded to the new level.
   - Validity cycle is reset to 60 days starting from the upgrade timestamp.
   - **`svipPoints` is explicitly RESET TO 0**.
2. **Renewal Evaluation (Every 60 Days)**:
   - **Branch A (Upgrade)**: If cycle points qualify for a higher tier $\rightarrow$ promote, 60-day validity, reset points to 0.
   - **Branch B (Maintain)**: If cycle points qualify for current tier $\rightarrow$ renew 60 days, reset points to 0.
   - **Branch C (Downgrade)**: If cycle points insufficient $\rightarrow$ downgrade by 1 tier, 60 days, reset points to 0.
   - **Branch D (Expire)**: If SVIP 1 fails to maintain $\rightarrow$ revert to regular user (level 0), privileges revoked, reset points to 0.

### 8.3 Security & Protection Enforcement
- **Room Protection**: SVIP 4, 5, 6 and assigned protected users cannot be kicked out or muted by Room Owners, Admins, or Moderators.
- **SVIP 6 Global Kick**: Can kick any user across all voice rooms. Cannot kick another SVIP 6 user or self.
- **Daily Diamond Claims**: 24-hour server UTC cooldown enforced in Cloud Functions (`claimSvipDailyReward`); client device clock is strictly ignored.
---

## SECTION 9: AUTOMATED FULL-SYSTEM TESTING & MAESTRO E2E ENGINE

### 9.1 Multi-Layer Automation Architecture
- **Layer 1 (Static Health)**: `flutter analyze` covering core models, UI widgets, and screens (0 errors policy).
- **Layer 2 (Core System Logic)**:
  - `test/svip_system_test.dart`: 10 automated unit tests (points math, immediate upgrade, 60d validity, 0-point reset, room kick immunity, privileges).
  - `test/hierarchy_permission_test.dart`: 6 tests (HB-PMS data isolation, Super Admin salary exclusion, Owner policy lockdown, diamond conversions).
  - `test/offline_betting_prevention_test.dart`: 4 tests (server betting authority & offline network guard).
- **Layer 3 (UI & Visual Badges)**: `test/svip_widget_verification_test.dart` (4 tests verifying pill badge rendering, tier text, and zero layout overflow).
- **Layer 4 (Cloud Functions Backend)**: `scratch/test_svip_backend.js` (5 backend suites validating 60-day renewal, 24h UTC daily claims, and kick protection logic).
- **Layer 5 (React Admin Dashboard)**: `hellochat_admin` production build verification via `npm run build` (0 errors).

### 9.2 Maestro Mobile UI/E2E Automation
- **Installation**: Native Maestro CLI 2.10.0 configured at `C:\Users\Lenovo\maestro\maestro\bin`.
- **Target Device**: Connected Android physical phone (`1374223603000CJ`) via ADB (`C:\Users\Lenovo\AppData\Local\Android\Sdk\platform-tools\adb.exe`).
- **Flow Suites**:
  - `.maestro/svip_flow.yaml`: Automated app launch, system dialog handling, navigation to SVIP Privileges, daily claim testing, and tier matrix scrolling.
  - `.maestro/offline_betting_flow.yaml`: Automated Spin Wheel navigation, airplane mode network simulation, and offline overlay assertions.
- **One-Click Execution**:
  - Local Mobile E2E: `run_maestro_tests.bat`
  - Local Full-System: `powershell -ExecutionPolicy Bypass -File run_full_system_verification.ps1`
  - Cloud CI/CD: `.github/workflows/system_verification.yml`

---

## SECTION 10: DYNAMIC GIFT EVENT SYSTEM & ADMIN MANAGEMENT

### 10.1 System Overview & Zero-App-Update Architecture
The Gift Event System is a fully dynamic, real-time marketing and engagement engine. All events, point rules, participating gifts, countdown durations, and rank rewards are created, modified, toggled, or restarted directly from the Admin Panel (`hellochat_admin`), instantly reflecting across all connected Flutter clients with **zero app updates required**.

### 10.2 Admin Panel Management (`GiftEventManagement.jsx`)
- **Route**: Mounted at `/events` and `/gift-events` with a dedicated `Gift Events` sidebar entry.
- **Event Lifecycle Controls**:
  - **Create / Edit Events**: Event title, description, markdown rules, theme accent color, start/end dates, banner image URL, and background styling.
  - **Enable / Disable / Stop**: Instant live switch toggling `isActive`; disables event points accrual immediately.
  - **Restart Event**: One-click reactivation resetting start time to now and extending duration by 7 days.
  - **Rewards Disbursal**: Admin callable `distributeGiftEventRewards` automatically distributes Diamonds, Profile Frames, and Badges to top winners upon event conclusion.
- **Event Gifts Configuration**:
  - Select platform gifts or custom items.
  - Configure Diamond Price and assigned **Event Points** per gift (custom multiplier or fixed point value).
- **Ranking & Reward Configuration**:
  - Ranking rules & duration (`event_duration`, `daily`, `weekly`).
  - Tier rewards: Rank 1 Champion, Rank 2–3 Silver, Rank 4–10 Elite with customizable Diamonds, Profile Frames (with validity days), Badges, and Custom Animations.

### 10.3 Atomic Event Point Accrual (`functions/index.js`)
- Integrated directly inside `sendGiftWithCombo` within atomic `db.runTransaction`.
- When an event gift is sent, the server calculates:
  $$\text{EventPoints} = \text{eventPointsPerGift} \times \text{quantity}$$
- Atomically updates:
  - Participant document: `gift_events/{eventId}/participants/{senderUid}` (`points`, `giftCount`, `diamondsSpent`).
  - Event aggregates: `gift_events/{eventId}` (`totalEventPoints`, `totalGiftsSent`, `totalDiamondsSpent`).
- Zero client trust, zero race conditions.

### 10.4 Flutter In-Room & Event Hub Experience
- **Gift Panel (`gift_panel.dart`)**:
  - When an active gift event is live, an `"Event"` category tab is dynamically added to the gift panel.
  - Participating event gifts display glowing `"EVENT ✨"` pill tags with point bonuses.
  - Quick-access `"EVENT 🏆"` header button directly opens the event hub.
- **Gift Event Screen (`gift_event_screen.dart` - `/gift-event/:eventId`)**:
  - Dynamic theme-colored hero header with live ticking countdown timer (`DDd : HHh : MMm : SSs`).
  - Expandable Rules sheet.
  - **Top 3 Podium**: Rank 1 Gold pedestal with crown & glowing avatar, Rank 2 Silver, Rank 3 Bronze.
  - **Top 4–50 Leaderboard**: Live real-time participant rank listing.
  - **Event Gifts & Rewards Matrix Tabs**: Full showcase of participating gifts and prizes.
  - **Pinned My Standing Footer**: Sticky bottom bar showing user's current rank, points, and 1-tap jump to send gifts.

---

## SECTION 11: MULTIPLAYER TEEN PATTI ENGINE & CASINO SUITE

### 11.1 Architecture & Zero-Lag 60 FPS Performance
- **Client Architecture (`teen_patti.html` & `teen_patti_screen.dart`)**:
  - Standalone, ultra-lightweight HTML5/CSS3 client embedded via Flutter `WebViewWidget`.
  - Zero heavy external JavaScript bundles or remote CDNs to ensure immediate boot and guaranteed 60 FPS performance on all mobile devices.
  - Local asset embedding: Game table felt, card back, and dealer textures are read from Flutter's asset bundle and injected as base64 data URIs.
  - Real-time procedural audio: Utilizes the browser `AudioContext` (Web Audio API) for chip clinks, card swishes, dealer bells, and victory fanfares with 0 network latency.

### 11.2 Server-Authoritative Anti-Cheat & Firestore Security
- **Cloud Functions (`functions/index.js`)**:
  - `joinTeenPattiSeat`: Atomic seating validation, minimum boot Diamond verification, and seat locking.
  - `leaveTeenPattiSeat`: Seat clearance and graceful clockwise turn auto-progression.
  - `startTeenPattiRound`: Validates at least 2 seated players, performs atomic boot balance deduction (`bootAmount = 1000` Diamonds) via `FieldValue.increment(-bootAmount)`, cryptographically shuffles a 52-card deck using Node `crypto.randomInt`, and deals 3 private cards per player.
  - `teenPattiAction`: Strict turn-validated betting controller supporting `see`, `chaal`, `raise`, `fold`, and `show`.
- **Card Security & Firestore Rules (`firestore.rules`)**:
  - Player private cards are stored exclusively under `rooms/{roomId}/games/teen_patti/private_cards/{userId}`.
  - Security rules enforce `allow read: if request.auth != null && request.auth.uid == userId;`, preventing cross-player card snooping.
  - During showdown or fold resolution, Cloud Functions atomically sets `revealAll: true` and writes revealed hands to the table state.

### 11.3 Hand Ranking & Showdown Hierarchy
Evaluated using standard international Teen Patti rules:
1. **Trail (Trio / Set)**: Three cards of the same rank ($A-A-A > K-K-K > ... > 2-2-2$).
2. **Pure Sequence (Straight Flush)**: Three consecutive cards of the same suit ($A-K-Q > K-Q-J > ... > A-2-3$).
3. **Sequence (Straight)**: Three consecutive cards of mixed suits.
4. **Color (Flush)**: Three cards of the same suit.
5. **Pair**: Two cards of the same rank with a kicker ($K-K-Q > K-K-J$).
6. **High Card**: Highest single card with kickers ($A-K-J > A-K-10$).

---

## SECTION 12: REAL-TIME GLOBAL TOP LIST & RANKING SYSTEM (CONTRIBUTION & CHARM)

### 12.1 System Architecture & Technical Specifications
The Top List System powers platform-wide real-time competitive rankings across both senders and receivers, fully decoupled and verified server-side.

```
                    ┌──────────────────────────────────────────────┐
                    │               GIFT TRANSACTION               │
                    │   (sendGiftWithCombo in functions/index.js)  │
                    └──────────────────────┬───────────────────────┘
                                           │
                    ┌──────────────────────┴───────────────────────┐
                    │                                              │
         [SENDER ATOMIC MUTATION]                       [RECEIVER ATOMIC MUTATION]
      dailyDiamondsSent += totalCost                 dailyBeansReceived += beansEarned
     weeklyDiamondsSent += totalCost                weeklyBeansReceived += beansEarned
    monthlyDiamondsSent += totalCost               monthlyBeansReceived += beansEarned
      totalDiamondsSent += totalCost                 totalBeansReceived += beansEarned
                    │                                              │
                    └──────────────────────┬───────────────────────┘
                                           │ Real-time Firestore Stream
                    ┌──────────────────────▼───────────────────────┐
                    │     FLUTTER CLIENT: LeaderboardScreen       │
                    │  (lib/features/leaderboards/.../screen.dart) │
                    ├──────────────────────────────────────────────┤
                    │  • Contribution Tab: orderBy(DiamondsSent)   │
                    │  • Charm Tab: orderBy(BeansReceived)         │
                    │  • Filters: Daily | Weekly | Monthly         │
                    │  • Royal Podium: #1 Gold, #2 Silver, #3 Bronze│
                    │  • Dynamic Pinned Sticky Footer for Self     │
                    └──────────────────────────────────────────────┘
```

---

### 12.2 Requirements Compliance & Verification Matrix

| # | Requirement | Implementation Details | Status |
|---|---|---|---|
| **1** | **Include all users in the app** | Users are queried directly from the root `users` collection using `.orderBy(queryField, descending: true).limit(100)` across all registered users. Zero exclusion of high spenders/receivers. | **DONE** |
| **2** | **Separate rankings for Daily, Weekly, and Monthly** | Client features a royal winged 3-way toggle (`DAILY`, `WEEKLY`, `MONTHLY`). Dynamically switches the query target: `dailyDiamondsSent`/`dailyBeansReceived`, `weeklyDiamondsSent`/`weeklyBeansReceived`, and `monthlyDiamondsSent`/`monthlyBeansReceived`. | **DONE** |
| **3** | **Automatically generated from user activity** | Updated strictly server-side within the `db.runTransaction` in `sendGiftWithCombo` (`functions/index.js`). No manual intervention required. | **DONE** |
| **4** | **Top Sending List (Contribution)** | Tracks `Diamonds Sent` in gifts. Sorted strictly in descending order. User sending the most Diamonds appears on the Top 1 Gold Podium and top of the ranking list. | **DONE** |
| **5** | **Top Receiving List (Charm)** | Completely independent tab (`Charm`) tracking `Beans Received`. Sorted strictly in descending order. Top streamer receiving the most Beans appears on the Top 1 Gold Podium. | **DONE** |
| **6** | **Zero Cross-Contamination** | Sending and Receiving metrics are completely isolated fields in Firestore (`DiamondsSent` vs `BeansReceived`). No fallback to shared XP or balances. Senders have zero score in Charm unless they receive gifts; receivers have zero score in Contribution unless they send gifts. | **DONE** |
| **7** | **Automatic Period Reset** | **Dual-Layer Reset Guarantee**:<br>1. **Real-time Transaction Check**: `sendGiftWithCombo` checks `lastDailySentDate === todayStr`, `lastWeeklySentDate === thisWeekStr`, `lastMonthlySentDate === thisMonthStr`. If period rolled over, user's counter automatically self-resets to 0 before adding new activity.<br>2. **Cloud Pub/Sub Scheduled Resets**: `scheduledDailyReset` (00:00 UTC daily), `scheduledWeeklyReset` (00:00 UTC Mondays), and `scheduledMonthlyReset` (00:00 UTC 1st of month) sweep and reset all user fields in batches. | **DONE** |
| **8** | **Automatic Real-time Update** | Flutter screen subscribes via `stream: query.snapshots()`. Whenever any gift is sent or beans credited, the Firestore real-time listener immediately fires, updating podium positions, ranks, scores, and the bottom sticky bar without page reload. | **DONE** |

---

### 12.3 Verification & Testing Guide

#### Method 1: In-App Verification via Device / Simulator
1. Open the Hello Chat app on device or emulator.
2. On the **Home Screen (Popular tab)**, observe the two category cards highlighted with badges:
   - **Contribution** (`👑 Top Senders`)
   - **Charm** (`💖 Top Receivers`)
3. Tap **Contribution**:
   - Verify it opens `LeaderboardScreen` directly on the **Contribution** tab.
   - Tap **Daily**, **Weekly**, and **Monthly** time filter tabs at the top.
   - Confirm Top 1 is on the Gold Champion Pedestal, Top 2 is Silver, and Top 3 is Bronze.
   - Confirm rank tiles 04 to 100+ render below with their Diamond score and golden coin icon.
   - Confirm sticky bottom bar displays your current rank (e.g. `01` or `- -` if outside top 100) with your actual Diamond score.
4. Tap **Charm**:
   - Verify it switches to the **Charm** tab.
   - Confirm that top receivers are displayed with their Bean count.
   - Confirm that users who only sent gifts do NOT appear here unless they received gifts.

#### Method 2: Automated Unit & Widget Test Execution
Run the automated test suite verifying UserModel metric isolation and podium widget rendering:
```bash
cmd /c "flutter test test/top_list_leaderboard_test.dart"
```
Expected output:
```
00:01 +6: All tests passed!
```

#### Method 3: Cloud Functions Reset Verification
Run Cloud Functions emulator or test script:
```bash
cmd /c "cd functions && node -e \"console.log('Testing reset exports: ' + (typeof require('./index.js').scheduledDailyReset))\""
```
Confirm `scheduledDailyReset`, `scheduledWeeklyReset`, and `scheduledMonthlyReset` are exported and valid.

---

## 13. 60 FPS Hardware-Accelerated Mobile Game Architecture (Phaser + Flutter WebView Pattern)

### 13.1 Core Principles Learned from `ReactFlutterJSGameTemplate`
To achieve rock-solid 60 FPS inside mobile WebViews (Chromium on Android / WebKit on iOS), games must decouple state from rendering and eliminate browser DOM layout thrashing:

1. **Hardware-Accelerated Single Canvas for Dynamic Entities**:
   - Moving objects (cascading chips, particle confetti, win bursts, lucky wheels) are drawn to GPU-backed 2D `<canvas>` contexts.
   - Eliminates `document.createElement`, DOM appending/removing, and CSS keyframe style recalculations.
2. **Zero-Allocation Object Pooling**:
   - Particle engines pre-allocate fixed-size buffers (`particlePool`, `chipPool`, `sparklePool`) at initialization.
   - Active entities are reused via property assignment; inactive entities are flagged `active = false`.
   - Prevents Garbage Collection (GC) pauses that trigger stutter and dropped frames during animations.
3. **Consolidated Delta-Time RAF Game Loops**:
   - Physics trajectories, easing curves, and decay use delta time (`dt = (now - lastTime) / 1000`) capped at 50ms.
   - Guarantees uniform motion across varying device refresh rates (60Hz, 90Hz, 120Hz ProMotion).
4. **CSS Containment & GPU Layer Isolation for Static UI**:
   - `contain: layout style paint;` or `contain: strict;` applied to viewports, reel stages, and seat plates.
   - `transform: translateZ(0);`, `will-change: transform;`, and `backface-visibility: hidden;` ensure HUD elements reside on dedicated compositor layers without invalidating parent layers.
5. **Signature-Based DOM Diffing**:
   - Game HUDs and player seats compute an immutable state hash string (`uid_bal_bet_turn_cards`).
   - If signature is unchanged, `.innerHTML` wipes are skipped completely, preventing SVG timer resets and image re-fetching.

### 13.2 Optimization Matrix: Teen Patti & Yummy Bingo

| Feature / Subsystem | Before (Jank / Bottleneck) | Optimized (60 FPS Architecture) | Impact |
|---|---|---|---|
| **Teen Patti Flying Chips** | DOM `div` creation + CSS keyframes on every Chaal/Raise | Single `#celebrationCanvas` with pre-allocated 24-chip pool (`CanvasFxEngine.spawnChips`) | Zero DOM nodes; smooth 60 FPS flight trajectory |
| **Teen Patti Confetti Explosions** | Dynamic array allocation on each showdown win | Pre-allocated 80-particle pool with gravity and rotational physics in RAF loop | Zero GC spikes on winner declaration |
| **Teen Patti Seat & Hand Updates** | Full `seatEl.innerHTML` and `localCardHand.innerHTML` rewrite on every tick | `lastSeatSignatures` and `lastLocalHandSig` diffing; skips DOM write if state unchanged | Eliminates circular timer SVG flashing and layout reflows |
| **Teen Patti CSS Compositing** | Default stacking contexts | `contain: layout paint;` + `transform: translateZ(0);` on `.game-viewport`, `.table-felt`, `.seat-wrapper` | Isolated GPU compositor layers |
| **Yummy Bingo Sparkle Engine** | Dynamic `particles.push()` + `particles.splice()` inside render loop | Pre-allocated 75-particle `sparklePool` with delta-time gravity | Zero array re-allocations during jackpot or line wins |
| **Yummy Bingo Win Tally Counter** | Unconditional `statusNote.textContent` write every RAF tick | Throttled integer comparison (`current !== lastDisplayed`) | Eliminates redundant text node recalculations |
| **Yummy Bingo Reel Motion** | Heavy CSS filter blur on complex SVGs | Hardware layer translation (`transform: translate3d(0, 0, 0); will-change: transform; contain: strict; backface-visibility: hidden;`) | Smooth 60 FPS spin deceleration and cabinet slam |
| **Flutter Android WebView Config** | Default webview parameters | `setMediaPlaybackRequiresUserGesture(false)`, static base64 image caching, state payload deduplication | 0ms disk I/O on re-opens; instant audio playback |

---

## 14. Lucky Spin Wheel (Ferris Wheel) HTML5 Architecture & Parity Specification

### 14.1 Architecture Rationale
To eliminate mobile device rendering stutter, memory pressure from heavy Flutter widget trees (3,900+ lines in `spin_wheel_screen.dart`), and complex animation controller allocations, the Spin Wheel game is migrated to a dedicated, high-performance HTML5/CSS3/Vanilla JS engine (`assets/games/spin_wheel.html`) embedded via `webview_flutter`.

```
┌─────────────────────────────────────────────────────────────┐
│             Flutter Host (spin_wheel_screen.dart)           │
│  - WebViewController (Hardware accelerated, transparent bg) │
│  - PopScope & System UI edge-to-edge styling                │
│  - Riverpod State (walletBalanceProvider, GameService)     │
│  - JavascriptChannel('FlutterApp')                          │
└──────────────┬───────────────────────────────▲──────────────┘
               │ JSON State Messages           │ JSON Action Requests
               │ (Balance, RoundSync, User)    │ (PlaceBet, Audio, Pop)
┌──────────────▼───────────────────────────────┴──────────────┐
│           HTML5 Game Engine (assets/games/spin_wheel.html)  │
│  - Plus Jakarta Sans unified typography                     │
│  - Ferris wheel with 8 food pods + glowing spotlight        │
│  - Salad (5x) & Pizza (45x) pedestals + payout breakdown     │
│  - Solid red (#e52828) bottom dashboard + seated chips      │
│  - 40s Synchronized Cycle (30s betting, 4.5s spin, results)  │
│  - Result Sheet, Catatan saya, Daily Top Players, Rules     │
└─────────────────────────────────────────────────────────────┘
```

### 14.2 Parity & Contract Checklist

| Category | Component / Spec | Flutter Original Behavior | HTML5 Engine Requirement |
|---|---|---|---|
| **Round Cycle** | 40s Global Cycle | `roundId = floor(now / 40000)`. 0-30s betting ("Select time", 30→0s). ≤10s: "BETS CLOSED". 30-34.5s spinning. 34.5-38s results sheet. 38-40s transition. | Exactly synced to epoch modulo 40s + backend `serverTimeOffset`. |
| **Betting** | 4 Chips & Items | Chips: `100`, `1k`, `10k`, `100k`. 8 pods: Hotdog (10x), Skewer (15x), Chicken (25x), Steak (45x), Carrot (5x), Corn (5x), Cabbage (5x), Tomato (5x). | Identical denominations, badges, and active chip states. |
| **Salad & Pizza** | Category Logic | Salad (5x): Tomato, Cabbage, Corn, Carrot. Pizza (45x): Hotdog, Skewer, Chicken, Steak. Tapping adds category bets; payouts calculate item-by-item breakdown. | Payout logic matches `calculateSpinWheelPrize` and `functions/index.js` 1:1. |
| **Bottom Sheets** | Result Sheet | Dark `#0b0b13` sheet, fork+knife streamers, winning emoji badge, outcome pill, user panda avatar, wager/prize, live podium winners, auto-dismiss < 38s. | Identical markup, dark dim backdrop, drag handle, close button, and auto-dismiss. |
| **Modals** | Catatan saya & Leaderboard | "Catatan saya >" shows game history with serial numbers, order IDs, WIN/LOSE stamps. "Daily Top Players" shows top 10 daily winners. | Full modal sheets matching styling and interactive tabs. |
| **Design** | Dashboard & Typography | Solid red `#e52828` dashboard, chips seated flush on top ledge, booth backrests visible. Font: Plus Jakarta Sans throughout. | Pixel-perfect visual replica. |


