# OpenCode Automated Verification Specification — Room & Profile Systems

You are an automated testing agent for **Hello Chat**. Your task is to execute the following test plan to verify the complete correctness of the 5 recently implemented features and bug fixes across Cloud Functions and Flutter UI.

---

## 1. ADMIN BADGE DISPLAY VERIFICATION

### Test Case 1.1: Room Settings Admin Assignment
- **Action**: In `Room Settings -> Admins`, assign User B (`Urmi` / `UID: 5829766012`) as a Room Admin.
- **Expected Outcome**: Firestore document `rooms/{roomId}` updates `admins` array to include `5829766012`.

### Test Case 1.2: Profile Card Admin Badge
- **Action**: Tap User B's avatar inside the room to open `RoomUserOptionsSheet`.
- **Expected Outcome**: A cyan/teal `[ Admin ]` capsule badge (`#00E5FF`) appears directly beside User B's display name above `ID:5829766012`.

### Test Case 1.3: Live Room Chat Admin Badge (FIXED & RESOLVED)
- **Action**: User B sends a text chat message in the room.
- **Implementation Detail**: `ChatWidget` now receives `roomId`, watches `currentRoomStreamProvider(roomId)`, and renders a cyan `[ Admin ]` pill badge (`#00E5FF`) before User B's username in live room chat message tiles.
- **Expected Outcome**: In the live room chat stream, a cyan `[ Admin ]` badge appears before User B's display name in the chat tile.

---

## 2. ROCKET TOP LIST 5-CYCLE PERSISTENCE VERIFICATION

### Test Case 2.1: Rocket #1 Launch Top List Retention
- **Action**: Send gifts to reach Level 1 Rocket threshold (1,000,000 💎). Trigger Rocket #1 launch.
- **Expected Outcome**: `rocketLevel` increments to 1. `rocketContributions` map is NOT reset to `{}`. The top 3 contributors remain intact.

### Test Case 2.2: Rocket #2, #3, #4 Sequential Launches
- **Action**: Continue sending gifts to trigger Rocket #2 (2,000,000 💎), Rocket #3 (3,000,000 💎), and Rocket #4 (5,000,000 💎).
- **Expected Outcome**: All top contributors accumulate scores continuously. The Rocket Top List retains all cumulative diamond points across Rockets #1, #2, #3, and #4.

### Test Case 2.3: Rocket #5 Completion & Cycle Reset
- **Action**: Send gifts to reach Level 5 Rocket threshold (10,000,000 💎). Trigger Rocket #5 launch.
- **Expected Outcome**: Top 3 rewards are awarded for Rocket #5. Room enters 5-minute cooldown (`rocketStatus: "cooldown"`). `rocketContributions` resets to `{}` ONLY after Rocket #5 finishes.

---

## 3. STAR LEVEL DYNAMIC COLOR SYSTEM VERIFICATION

### Test Case 3.1: 0 Star Initial State
- **Action**: Open `RocketDetailSheet` or check `RoomStarProgressWidget` in a room with `< 1,000` total diamonds.
- **Expected Outcome**: Badge displays `0 Star` with grey/white background opacity.

### Test Case 3.2: Star Level 1–5 Automatic Color Progression
- **Action**: Send diamonds to cross each target threshold and check the badge color:
  - **1 Star** (`>= 1,000` 💎): Cyan (`#00E5FF`)
  - **2 Star** (`>= 10,000` 💎): Green (`#00C853`)
  - **3 Star** (`>= 50,000` 💎): Purple (`#9C27B0`)
  - **4 Star** (`>= 100,000` 💎): Pink (`#FF4081`)
  - **5 Star** (`>= 250,000` 💎): Gold (`#FFD700`)
- **Expected Outcome**: Badge text, star icon, background glow, and border automatically shift colors live upon hitting each threshold.

---

## 4. SEPARATE TOP LIST PER USER ID VERIFICATION

### Test Case 4.1: Target User A Gifting
- **Action**: Send 500 diamonds to User A. Open User A's profile card -> `Top List`.
- **Expected Outcome**: User A's `sender_rankings` shows sender at Rank #1 with 500 💎.

### Test Case 4.2: Target User B Isolation
- **Action**: Open User B's profile card -> `Top List`.
- **Expected Outcome**: User B's `Top List` shows ONLY gifts sent directly to User B. User A's 500 💎 score does NOT appear in User B's Top List.

---

## 5. PROFILE BACKGROUND FULL-COVER SCALING VERIFICATION

### Test Case 5.1: Profile Card Width Stretch
- **Action**: Open `ProfileDetailScreen` or `UserProfileCard` for a user with a custom background.
- **Expected Outcome**: Background graphic stretches edge-to-edge (`BoxFit.cover`, `width: double.infinity`) across the profile header with zero side margins.
