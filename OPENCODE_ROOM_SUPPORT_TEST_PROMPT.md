# OPENCODE AUTOMATED TESTING SPECIFICATION
## Feature: Room Support & Room Partner System Regression Suite

---

### INSTRUCTIONS FOR OPENCODE AGENT

You are an automated mobile application QA engineer. Execute the following testing workflow on the connected Android device to verify that all **Room Support** issues have been fully resolved.

---

### PRE-FLIGHT ENVIRONMENT & DEVICE SETUP

1. **Detect Connected Device:**
   - Execute: `cmd /c "adb devices"`
   - Confirm at least one active Android device/emulator is online.

2. **Build and Deploy Latest Application:**
   - Execute: `cmd /c "flutter run -d <device_id>"` (or install latest build).
   - Ensure the app launches successfully without crashing.

---

### TEST SUITE: ROOM SUPPORT FUNCTIONAL VERIFICATION

#### Phase 1: Room Support Navigation & Target Header Verification
1. **Launch & Navigate:**
   - Launch application on the device.
   - Login as room owner / active user.
   - Navigate to Home Banner or Live Room floating support action.
   - Open `/room-support` screen (`RoomSupportScreen`).

2. **Verify Room Support Count Display (Issue 1):**
   - Confirm the **ROOM SUPPORT COUNT** header card is visible at the top.
   - Verify that current weekly coins count is displayed (e.g., `0 Coins` or accumulated value).
   - Confirm count is not blank, zero-hidden, or corrupted.

3. **Verify Room Target Display & Weekly Target Enforcement (Issues 2 & 3):**
   - Confirm a clearly identifiable **Weekly Room Target** is displayed (e.g., `Target: 10M Coins`).
   - Verify the target represents the **Current/Applicable Week Target** (e.g., Level 1 = 10,000,000 Coins).
   - Verify that the target is NOT displaying a monthly aggregate or lifetime total.
   - Confirm progress bar percentage (e.g., `0.0%` or current progress) renders smoothly.

#### Phase 2: Room Statistics & Data Consistency (Issues 4 & 5)
4. **Verify "My Room" Statistics Table:**
   - Locate the **My Room** table card.
   - Check **This Week** row:
     - Room Level (0 to 7)
     - Reward Coins (expected reward for current level)
     - Room Visitors (active visitor count)
     - Room Coins (current week total coins)
   - Check **Last Week** row:
     - Verify last week data is separated cleanly from current week data.
     - Confirm no data leakage or double-counting between weeks.

5. **Verify Countdown & Phase Window (11 & 12):**
   - Locate the **Countdown Phase Card**.
   - Confirm countdown timer displays remaining time (e.g., `this week countdown` or `fill in countdown`).
   - Confirm weekly text rules (Monday–Sunday cycle, Wednesday reward distribution) render cleanly.

#### Phase 3: Salary Partner Assignment Flow & ID Search (Issues 6, 7, 8, 9, 10)
6. **Open Partner Assignment Section:**
   - Locate the **SALARY PARTNERS ASSIGNMENT** card.
   - Verify the assigned counter format: `0 / 4 Assigned` (or `0 / X Assigned` based on level).

7. **Test ID Input & Search (Issues 6 & 7):**
   - Tap an empty `+ Add` slot or **ASSIGN SALARY PARTNER** button.
   - Verify `Add Room Partner` bottom sheet opens cleanly.
   - Enter a valid test numeric User ID (e.g., `102435` or active user helloId/UID).
   - Tap **Search**.
   - **Verification:** Confirm matching user result card appears showing:
     - User Avatar
     - Display Name
     - User ID (`ID:...`)
     - Yellow **Add** button.

8. **Test Invalid/Non-Existing ID Search:**
   - Clear search field and type a non-existent ID (e.g., `999999999`).
   - Tap **Search**.
   - **Verification:** Confirm app cleanly displays `"No users found"` message without crashing or hanging.

9. **Test Confirmation Dialog & Cancellation (Issue 8):**
   - Search for a valid test user ID.
   - Tap **Add** on the returned user card.
   - **Verification:** Confirmation dialog appears with text:
     - *"Whether to add [Name] as your Room Partner, modification is not allowed after adding"*
     - **Cancel** button
     - **Confirm** button
     - *"Don't remind again"* checkbox.
   - Tap **Cancel**.
   - **Verification:** Dialog closes, user is NOT added, partner count remains `0 / 4 Assigned`.

10. **Test Add Flow End-to-End & Counter Increment (Issues 8, 9, 10):**
    - Search for valid test user ID again.
    - Tap **Add** -> Tap **Confirm**.
    - **Verification:**
      - Success notification snackbar appears (*"[Name] added as salary partner!"*).
      - Picker sheet closes.
      - Slot grid updates immediately showing the assigned user's avatar and name.
      - Assignment counter updates from `0 / 4 Assigned` to `1 / 4 Assigned`.
      - Exiting and re-entering the Room Support screen persists the assigned salary partner.

---

### FINAL AUTOMATED TEST REPORT FORMAT

Produce a summary report in the following format upon test completion:

```markdown
# OPENCODE AUTOMATED TEST REPORT: ROOM SUPPORT SYSTEM

| Test Case ID | Test Description | Result (PASS/FAIL/BLOCKED) | Expected Behavior | Actual Behavior | Logs / Failure Reason |
|--------------|------------------|----------------------------|-------------------|-----------------|-----------------------|
| RS-01 | Room Support Count Display | PASS/FAIL | Support count visible | ... | None |
| RS-02 | Weekly Room Target Display | PASS/FAIL | Weekly target displayed (not monthly) | ... | None |
| RS-03 | Statistics Consistency | PASS/FAIL | This week vs last week separated | ... | None |
| RS-04 | User ID Search | PASS/FAIL | Accepts numeric & string IDs | ... | None |
| RS-05 | Invalid ID Handling | PASS/FAIL | Displays no users found without crash | ... | None |
| RS-06 | Add Confirmation Dialog | PASS/FAIL | Modal with Confirm/Cancel/Checkbox | ... | None |
| RS-07 | Partner Slot Increment | PASS/FAIL | Counter updates 0/4 -> 1/4 | ... | None |
| RS-08 | Partner Persistence | PASS/FAIL | Partner visible after screen reload | ... | None |
```
