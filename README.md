# Hello Chat - Live Voice Rooms, Gaming & Creator Ecosystem

Hello Chat is a real-time live voice room, minigames, and creator monetization platform featuring a Flutter mobile client, Firebase Cloud Functions backend, and a comprehensive React administrative dashboard.

---

## 🌟 Key Architecture & Modules

### 1. 🎙️ Live Voice Rooms & Room Support
- **Multi-Seat Voice Rooms**: Low-latency audio streaming, interactive seat controls, host speaking animations, and permission controls.
- **Rocket System & Global Events**: Progressive room rocket levels, real-time contribution tracking, top 3 winner podiums, and auto-dismissing celebration overlays.
- **Room Support Program**: Weekly room competition, partner seat assignments, and automatic Wednesday distributions.
- **SVGA / Special Effect Animations**: High-performance gift and entry rendering with bounded memory queues and deduplication.

### 2. 🎮 Interactive Minigames (Spin Wheel & Yummy Bingo)
- **Lucky Spin Engine**: 30-second live rounds, multi-tier betting, real-time bet reconciliation without balance flicker, server-verified RNG, and daily reset cron jobs.
- **In-Flight Bet History**: Transparent tracking of active rounds marked as **IN PLAY** before settlement.
- **Top Winner Podium**: Immediate display of the Top 3 champions at the end of each round.

### 3. 💰 Salary & Rewards Matrix (10 Tiers)
- **Creator Milestones**: 10 cumulative bean targets (1M up to 209M beans).
- **Automated Payout Split**:
  - **Host Share (60%)**: Daily USD payout conversions.
  - **Agency Share (30%)**: Bi-weekly bean distribution.
  - **Platform Admin (10%)**: System fee allocation.
- **Interactive Matrix View**: Built-in milestone tracker with real-time status badges (**Completed**, **In Progress**, **Locked**).

### 4. 🛡️ Admin & Moderation Portal (`hellochat_admin`)
- **Real-Time Dashboards**: User management, live room controls, financial reconciliations, agency tracking, VIP/SVIP assignments, and winning config sliders.
- **Developer & Preview Mode**: One-click role testing (System Owner, Super Admin, Agency Lead).

---

## 🚀 Recent Updates (2026-09-16)
- **Salary Milestone Table**: Integrated all 10 tiers directly into the mobile Salary History view.
- **Spin Wheel Stability**: Eliminated balance flicker during active wagers and hidden server-side spoilers before deceleration ends.
- **Live Room Concurrency**: Added 8-second safety watchdog on rocket explosions, isolated participant counter subscriptions, and capped gift animation queues.
- **Admin Portal Integration**: Verified React dashboard compilation and Vite build pipeline.

For a full historical changelog, see [PROJECT_WORKLOG.md](./PROJECT_WORKLOG.md).

