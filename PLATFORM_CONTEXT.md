# Hello Chat: Global Platform Orchestration Context
**Current Development Phase:** Month 7 (Finalized) -> Month 8 (Pre-Launch)
**Core Objective:** 100% Admin-Orchestrated Social & Economic Ecosystem.

---

## 🏗️ Technical Stack
-   **User App (Mobile):** Flutter (Riverpod State Management).
-   **Admin Platform (Web):** React + Vite + Lucide Icons (Glassmorphic Premium Design).
-   **Backend (Serverless):** Firebase Cloud Functions (Node.js), Firestore (Real-time DB), FCM (Push).
-   **Media Engine:** Agora RTC (Live Voice Rooms).

---

## 🗓️ Month-by-Month Success Ledger

| Month | Focus Area | Key Features Completed | Status |
| :--- | :--- | :--- | :--- |
| **Month 1** | **Foundation** | Phone/Google Auth, Profile Setup, Moments Feed, Likes/Comments. | ✅ Done |
| **Month 2** | **Voice Core** | Agora Voice Integration, Seat Management (Mic Lock), Room Text Chat. | ✅ Done |
| **Month 3** | **Gifts & PK** | 20+ Animated Gifts, PK Battle Engine (Live Scores, Winner Logic). | ✅ Done |
| **Month 4** | **Economy** | Diamond Wallet, Bean Conversions, Transaction History, User XP/Levels. | ✅ Done |
| **Month 5** | **VIP & Ranks** | VIP 1-7 Tiers, SVIP Benefits, Global Leaderboards (Top Senders/Receivers). | ✅ Done |
| **Month 6** | **Games/Salary** | Spin Wheel & Lucky Draw (Secure Backend), Weekly Salary Auto-Distribution. | ✅ Done |
| **Month 7** | **Orchestration** | Admin Console, Global Broadcast Ticker, Rich Image Push, Audit Trail Log. | 🎯 Finalized |

---

## ✅ Technical Implementation Status
1.  **Monetization Engine:**
    -   `Gifts`: Real-time catalog management, animated Lottie overlays, combo multipliers.
    -   `VIP Store`: Tiers 1-7 (SVIP) with automated benefit distribution (badges, frames).
    -   `Wallet`: Atomic Diamond-to-Bean conversions with 100% balance integrity via Cloud Functions.
2.  **Voice Ecosystem:**
    -   `Room Management`: Seat logic, mic permissions, owner/admin hierarchy.
    -   `PK Battles`: Dedicated widget with dual-timer, team-based gifting, and award logic.
3.  **Economy Security (New):**
    -   `Secure Games`: Spin Wheel & Lucky Draw moved to server-side HTTPS onCall to prevent APK cheating.
    -   `Provably Fair`: Randomization and prize calculations executed in Cloud Functions.
4.  **Admin Mastery (Month 7):**
    -   `Global Broadcasts`: Real-time "Ticker" in rooms + "Rich Push" notifications with images via FCM.
    -   `Audit Trail`: Every admin action (Gift price change, BAN, Broadcast) is logged for accountability.
    -   `System Config`: Real-time control over diamond rates, level XP thresholds, and salary multipliers.

---

## 🚨 Critical Architecture & "Golden Rules"
-   **Money Logic:** ALWAYS in `functions/index.js` using `db.runTransaction`. Never update balances from client-side Firestore rules if possible.
-   **Live Updates:** Use `onSnapshot` for room status, gift tickers, and global announcements.
-   **Admin Security:** Access restricted via `tags: ["Admin", "SuperAdmin"]` in the user document.

---

## 🛠️ Ongoing / Future Tasks (Month 8+)
-   **Hosting Fix:** `firebase.json` updated with correct Hosting rewrites; awaiting deployment health-check.
-   **Payment Gateway:** Move from `Sandbox` simulation to `Stripe/Razorpay` production keys.
-   **Advanced Analytics:** Build charts in `DashboardHome` for Revenue (Beans/Diamonds) per month.

---

**End of Context Save.** This file serves as the "source of truth" for the current project state for the next session. 📡✨
