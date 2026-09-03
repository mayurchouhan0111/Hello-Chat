# OPENCODE AUTOMATED TESTING SPECIFICATION
## Feature: Room Owner Voice, Microphone & Room Header UI Verification Suite

---

### INSTRUCTIONS FOR OPENCODE AGENT

You are an automated mobile QA engineer. Execute the following testing specification on the connected Android device to verify that **Room Owner Voice/Microphone Mute** issues and **Room Owner Header UI** bugs are fully resolved.

---

### PRE-FLIGHT ENVIRONMENT & DEVICE SETUP

1. **Detect Connected Device:**
   - Execute: `cmd /c "adb devices"`
   - Confirm an active Android device or emulator is connected.

2. **Deploy & Launch Latest Build:**
   - Execute: `cmd /c "flutter run -d <device_id>"` (or install latest APK).
   - Confirm application launches without runtime exceptions.

---

### TEST SUITE: ROOM OWNER VOICE & HEADER FUNCTIONAL VERIFICATION

#### Phase 1: Room Owner Navigation & Header UI Verification
1. **Launch Room as Owner:**
   - Log in as the Room Owner.
   - Navigate to Home or Create/Open your owned voice chat room.
   - Enter `LiveRoomScreen`.

2. **Verify Room Owner Name in Header (Issues 9, 10, 11):**
   - Inspect top room header (`_buildRoomAppBar`).
   - **Verification:** Confirm header displays the **Room Owner's actual Display Name** (e.g., `"Mayur Chouhan"`), and NOT the Room Title (e.g., *"Welcome to chat"*).

3. **Verify Room Owner ID in Header (Issues 10, 12, 13):**
   - Inspect text directly below or beside the Owner Name.
   - **Verification:** Confirm header displays `ID: <Owner ID>` (e.g., `ID:102435`), using the owner's actual `helloId`, `displayId`, or `ownerUid`.
   - Confirm ID is NOT displaying a guest ID, room ID, or stale cached user ID.

4. **Verify Header Visual Alignment & Layout (Issues 13 & 15):**
   - Check owner avatar, display name, ID tag, and participant counter alignment.
   - **Verification:** Confirm no text clipping, no overlapping with action icons, and clean visual balance.

#### Phase 2: Room Owner Voice & Microphone Auto-Unmute (Issues 1, 2, 3, 4, 5)
5. **Verify Auto-Broadcaster Promotion & Permission (Issues 2, 3, 5):**
   - Upon entering the room, observe console logs & permission prompts.
   - **Verification:** Confirm app requests runtime Microphone permission if not already granted.
   - Confirm Agora/Zego RTC voice engine sets `clientRoleBroadcaster` for Room Owner.

6. **Verify Initial Microphone Unmuted State (Issues 1, 2, 6):**
   - Inspect the dedicated microphone button in the bottom action bar.
   - **Verification:** Confirm mic icon is active/unmuted (green microphone indicator `Icons.mic_rounded`).
   - Confirm local audio stream is publishing (`muteLocalAudio(false)`).

7. **Test Microphone Mute Toggle (OFF):**
   - Tap the microphone button in the bottom bar.
   - **Verification:**
     - UI icon updates to muted state (`Icons.mic_off_rounded`, red background).
     - Snackbar notification appears (*"Microphone Muted 🔇"*).
     - Audio engine stops publishing local microphone track (`muteLocalAudio(true)`).

8. **Test Microphone Unmute Toggle (ON):**
   - Tap the microphone button again.
   - **Verification:**
     - UI icon updates to unmuted state (`Icons.mic_rounded`, green background).
     - Snackbar notification appears (*"Microphone Active 🎙️"*).
     - Audio engine resumes publishing local microphone track (`muteLocalAudio(false)`).

#### Phase 3: Voice Transmission, Room Re-entry & Reconnection (Issues 7, 8, 16)
9. **Verify Voice Audio Transmission (Issue 7):**
   - Speak into the device microphone while unmuted.
   - **Verification:** Observe audio input levels / host ripple animation.
   - Verify secondary audience device receives and plays the owner's voice stream clearly.

10. **Test Room Re-entry Behavior (Issue 8):**
    - Minimize or leave room, then re-enter the room.
    - **Verification:** Room Owner is automatically re-promoted to Broadcaster role, mic control is accessible, and owner is NOT permanently muted.

11. **Test Reconnection & Lifecycle Resume (Issue 8):**
    - Move app to background for 5 seconds and resume.
    - **Verification:** Microphone state and voice connection recover seamlessly.

---

### FINAL AUTOMATED TEST REPORT FORMAT

Produce a summary report in the following format upon test completion:

```markdown
# OPENCODE AUTOMATED TEST REPORT: ROOM OWNER VOICE & HEADER UI

| Test Case ID | Test Description | Result (PASS/FAIL/BLOCKED) | Expected Behavior | Actual Behavior | Logs / Failure Reason |
|--------------|------------------|----------------------------|-------------------|-----------------|-----------------------|
| ROV-01 | Owner Name Header Display | PASS/FAIL | Shows Owner Display Name | ... | None |
| ROV-02 | Owner ID Header Display | PASS/FAIL | Shows ID:<Owner helloId/displayId> | ... | None |
| ROV-03 | Owner Auto-Broadcaster Init | PASS/FAIL | Promoted to Broadcaster role | ... | None |
| ROV-04 | Mic Permission Request | PASS/FAIL | Requests runtime mic permission | ... | None |
| ROV-05 | Bottom Bar Mic Unmute | PASS/FAIL | Mic active & unmuted on entry | ... | None |
| ROV-06 | Mic Mute/Unmute Toggle | PASS/FAIL | UI & RTC engine toggle state synchronously | ... | None |
| ROV-07 | Audio Transmission | PASS/FAIL | Owner voice transmitted to room | ... | None |
| ROV-08 | Re-entry Mic Persistence | PASS/FAIL | Owner mic functional after re-entry | ... | None |
```
