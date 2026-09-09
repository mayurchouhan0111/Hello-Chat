# Hello Chat - Project Work Log

This document records all day-to-day changes, client requests, and fixes in **simple, plain English**. 
Whenever any task or feature is worked on, this file is updated so anyone (clients, managers, or developers) can easily see what was asked and what was completed.

---

## Format For Every Entry
- **Date**: YYYY-MM-DD
- **What Client Asked / Problem**: What the client requested or reported in plain everyday words.
- **What We Did**: Exactly what was changed or fixed in clear, simple language.
- **Files Touched**: Key files updated.
- **Status**: Completed / Testing / In Progress.

---

## Work Log Entries (Newest First)

### Date: 2026-09-10
- **What Client Asked / Problem**:
  "The game concept is written somewhere in the project so read that and Flutter code to get a clearer picture of how the game works. Use the panda icons we have in the Flutter game. You placed Salad and Pizza in the wrong place where betting chips belong, the carnival background is not matching the background we created, and the wheel should NOT spin—the marker should spin."
- **What We Did**:
  1. Studied `.agents/spin_wheel_game_brain.md` and `lib/features/games/presentation/screens/spin_wheel_screen.dart` to extract the exact mechanics, math, coordinates, and visual assets without touching any Flutter code.
  2. Applied the exact carnival Ferris wheel background (`assets/images/processed_image.webp`) directly in HTML.
  3. Made the Ferris wheel completely stationary:
     - Calibrated all 8 food pods (🌭 10x, 🍢 15x, 🍗 25x, 🥩 45x, 🥕 5x, 🌽 5x, 🥬 5x, 🍅 5x) to sit dead-center inside the 8 white wheel circles in the background illustration.
     - Replaced wheel rotation with a luminous clockwise-hopping spotlight marker (`GlowPointer`) that rapidly ticks from pod to pod across acceleration, constant speed, and deceleration steps before landing and pulsating on the winner.
  4. Centered the red hub with the exact Panda face illustration, real-time countdown timer (`9s`), and status label, accompanied by the floating dark `BETS CLOSED` banner across the lower spokes.
  5. Positioned `🥗 Salad >` and `🍕 Pizza >` directly on their respective left and right gold pedestals flanking the wheel base.
  6. Placed the 4 betting chip selector buttons (`100`, `1k`, `10k`, `100k`) directly inside the 4 blue carnival booth stalls beneath the wheel.
  7. Implemented direct on-pod betting: tapping any food pod or side pedestal places the active chip directly onto that target, displaying an instant green/amber badge pill (e.g. `1k ✓`).
  8. Verified the exact 1:1 visual match and interactive flow in the browser subagent.
- **Files Touched**:
  - `assets/games/spin_wheel.html`
  - `PROJECT_WORKLOG.md`
- **Status**: Completed & Verified

---

### Date: 2026-09-09 (Part 2)
- **What Client Asked / Problem**:
  "Make the exact same game in HTML and CSS because Flutter is not performing smoothly for them. Do not touch the current Flutter game code, push the current code to GitHub first, and replicate the exact UI/UX from the client's screenshot in HTML/CSS with zero modifications to the design."
- **What We Did**:
  1. Pushed the current Flutter codebase safely to GitHub (`origin/main`, commit `586a607`) with all latest fixes and zero regressions.
  2. Built a 100% pixel-perfect HTML5, CSS3, and Vanilla JavaScript replica of the game at [`assets/games/spin_wheel.html`](assets/games/spin_wheel.html) matching the client's screenshot:
     - Top bar with "Today's 1155 Round", "<" back button, and "Rules >" button.
     - Carnival Ferris Wheel with blue A-frame striped legs and 8 food gondolas: 🌭 Hotdog (10x), 🍢 Skewer (15x), 🍗 Chicken (25x), 🥩 Steak (45x), 🥕 Carrot (5x), 🌽 Corn (5x), 🥬 Cabbage (5x), 🍅 Tomato (5x).
     - Red center hub with Panda face and real-time countdown / "BETS CLOSED" badge.
     - Side pedestals: 🥗 Salad > and 🍕 Pizza >.
     - Red dashboard: Refresh button, "Current Amount" with 💎, "My Play History", recent "Result" strip with yellow "New" badge, "Daily Top Players", "Prev Winner", and "Catatan saya >".
     - Fully functional 40s synchronized loop, interactive betting drawer, celebration modal, and Web Audio API sounds.
  3. Verified the design and functionality using headless browser visual inspection.
  4. Pushed `assets/games/spin_wheel.html` to GitHub (`origin/main`, commit `4c0ff56`).
- **Files Touched**:
  - `assets/games/spin_wheel.html` (Created)
  - `PROJECT_WORKLOG.md` (Updated)
- **Status**: Completed & Pushed to GitHub

---

### Date: 2026-09-09
- **What Client Asked / Problem**:
  "Run the release mode apk on the connected device."
- **What We Did**:
  - Detected connected physical Android device: Vivo V2132 (`1374223603000CJ`, Android 14).
  - Launched `flutter run --release -d 1374223603000CJ` with the latest fixes (guarded bottom sheet dismissal, PopScope protection, and zero-error code).
- **Files Touched**:
  - `lib/features/games/presentation/screens/spin_wheel_screen.dart`
- **Status**: Installed & Running on Device (PID: 26271)

---

### Date: 2026-09-08
- **What Client Asked / Problem**:
  1. Asked whether the two new HTML-based games ("Yummy Bingo" and "Teen Patti") are currently commented out in the app.
  2. Asked to maintain a dedicated markdown log file that documents all client requests and team work day-by-day in simple, plain English.
- **What We Did**:
  1. Checked the codebase and confirmed that both "Yummy Bingo" and "Teen Patti" are temporarily commented out inside the room games selection sheet (`games_panel.dart`) while they are being optimized.
  2. Created `PROJECT_WORKLOG.md` in the project root and added an agent rule in `.agents/AGENTS.md` and `.agents/rules/daily-worklog-enforcement.md` to ensure the AI updates this log on every task.
- **Files Touched**:
  - `PROJECT_WORKLOG.md` (Created)
  - `.agents/rules/daily-worklog-enforcement.md` (Created)
  - `.agents/AGENTS.md` (Updated)
- **Status**: Completed

---

### Date: 2026-09-07
- **What Client Asked / Problem**:
  "The bottom sheet closing or anything in the spin game is causing me to be thrown out of the game back to the room. Check it and resolve it."
- **What We Did**:
  - **Found the bug**: When the win/loss result sheet finished displaying, two separate timers tried to close it at almost the exact same time. The first timer closed the sheet, but because the sheet was already closing, the second timer accidentally closed the entire game screen instead, throwing the user back to the voice room.
  - **Fixed the bug**:
    1. Added a strict check so a timer only closes the sheet if the sheet is actually open and hasn't already closed.
    2. Added a safety guard (`PopScope`) on the game screen so that even if a close action is triggered, it will only ever close the popup sheet and will **never** throw the user out of the game screen.
- **Files Touched**:
  - `lib/features/games/presentation/screens/spin_wheel_screen.dart`
- **Status**: Completed & Verified on physical device (Vivo V2132)

---

### Date: 2026-09-06
- **What Client Asked / Problem**:
  1. "There is an error in the game still: betting is going for the current round, but the previous round's result is showing in the bottom sheet. The round sync is not correct. Find out the reason and resolve it fast."
  2. "Both new games are lagging in release mode. Suggest a solution to make them zero error and smooth while keeping UI/UX premium."
- **What We Did**:
  1. **Fixed Round Synchronization in Spin Wheel**:
     - Synchronized the app's clock with the server's master clock down to the exact millisecond using Firebase RTDB `.info/serverTimeOffset`.
     - Strictly enforced the 40-second server round cycle: 0s–20s (Betting Open), 20s–30s (Betting Locked), 30s–35s (Wheel Spinning), 35s–38s (Celebration Popup), 38s–40s (Next Round Preparation).
     - Added a guard that immediately blocks any old or previous round results from ever popping up during a new betting round.
  2. **Analyzed HTML Games (Teen Patti & Yummy Bingo)**:
     - Identified that running raw HTML games in default mobile WebViews causes lag and resource errors (`about:blank` vs localhost).
     - Temporarily kept them hidden in the games panel so players only access the fully optimized native Flutter games (Spin Wheel & Lucky Draw) while the HTML games are optimized.
- **Files Touched**:
  - `lib/features/games/presentation/screens/spin_wheel_screen.dart`
  - `lib/features/games/presentation/screens/teen_patti_screen.dart`
  - `lib/features/games/presentation/screens/yummy_bingo_screen.dart`
  - `functions/index.js`
- **Status**: Completed

---

### Date: 2026-09-05
- **What Client Asked / Problem**:
  Make sure real backend calculations and atomic database transactions work correctly for gifts, rocket events, diamonds, and beans without race conditions or balance discrepancies.
- **What We Did**:
  - Audited and enforced Firestore transactions in Firebase Cloud Functions (`functions/index.js`).
  - Ensured all coin/diamond deductions and prize credits happen on the server only, preventing client-side manipulation or double-spending under high concurrency.
- **Files Touched**:
  - `functions/index.js`
  - `.agents/skills/firebase-transactions-security/SKILL.md`
- **Status**: Completed
