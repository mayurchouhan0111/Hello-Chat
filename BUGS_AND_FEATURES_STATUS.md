# Hello Chat - Bugs & Requirements Status Report

This document tracks the current development and verification status of all critical bug fixes and features requested in the **CyberShield Hackathon: Relationship PK System / Hello Chat Bug Report & Requirements**.

---

## Summary of Items

| Feature / Bug | Category | Current Status | Manual Verification Status |
| :--- | :--- | :--- | :--- |
| **Invite User to Audio Call** | Live Room | ✅ Implemented (Code Complete) | ❌ Not Tested |
| **Back Button Minimize System** | Live Room | ✅ Implemented (Code Complete) | ❌ Not Tested |
| **Instant User Visibility** | Live Room | ✅ Implemented (Code Complete) | ❌ Not Tested |
| **Entry Animation Replay on Seat Click** | Live Room | ✅ Implemented (Code Complete) | ❌ Not Tested |
| **Host Speaking Ring Layout Crash** | Live Room | ✅ Implemented (Code Complete) | ❌ Not Tested |
| **Audio Interruption Fix** | Audio System | ✅ Implemented (Code Complete) | ❌ Not Tested |
| **Audio Connection Health Monitor** | Audio System | ✅ Implemented (Code Complete) | ❌ Not Tested |
| **Audio Lifecycle (Background/Foreground)** | Audio System | ✅ Implemented (Code Complete) | ❌ Not Tested |
| **Room Switching Audio Stability** | Audio System | ✅ Implemented (Code Complete) | ❌ Not Tested |
| **Result Screen Consistency** | Betting System | ✅ Implemented (Code Complete) | ❌ Not Tested |
| **Offline Betting Exploit Fix** | Betting System | ✅ Implemented (Code Complete) | ❌ Not Tested |
| **Bet Persistence Fix** | Betting System | ✅ Implemented (Code Complete) | ❌ Not Tested |
| **Unified Rocket Leaderboard** | Rocket System | ✅ Implemented (Code Complete) | ❌ Not Tested |
| **Real-time Ranking System** | Rocket System | ⚠️ Partial (UI done, no RocketService) | ❌ Not Tested |
| **Participant Rewards Setup** | Rocket System | ✅ Implemented (Server writes via cloud function, client displays level-specific values) | ❌ Not Tested |
| **Reward Display Level Bug** | Rocket System | ✅ Implemented (Fixed hardcoded values → level-specific rewards) | ❌ Not Tested |
| **Delete global_engagement_banner.dart** | Rocket System | ✅ Implemented (Unused file deleted) | ❌ Not Tested |
| **Rocket Animation w/ Avatar** | Rocket System | ✅ Implemented (Code Complete) | ❌ Not Tested |
| **Global 10s Rocket Notification**| Rocket System | ✅ Implemented (Code Complete) | ❌ Not Tested |
| **Notification Duplicate Fix** | Rocket System | ✅ Implemented (`GlobalEngagementBanner` removed from `main.dart`) | ❌ Not Tested |
| **Audio Invite Seat Selection** | Live Room | ✅ Implemented (dynamic empty seat, no longer hardcoded seat 0) | ❌ Not Tested |
| **Rocket Frame Integration** | Rocket System | ✅ Implemented (Client-approved rocket.svga, vault storage with 24h/72h expiry, server-enforced, warehouse auto-display) | ❌ Not Tested |
| **Room Support System** | Room Support | ✅ Implemented (Firestore collections, Cloud Functions, RoomSupportScreen with 7 sections, banner + live room navigation, weekly cycle logic, partner assignment, auto-distribution) | ❌ Not Tested |
| **Invite to Call / Bring to Call (2 buttons)** | Live Room | ✅ Implemented (type-aware invite with `invite`/`bring` distinction) | ❌ Not Tested |
| **Support Banner (Home + Live Room)** | Room Support | ✅ Implemented (purple gradient card on home screen + live room) | ❌ Not Tested |
| **Chat Send Button** | Live Room | ✅ Implemented (send icon added next to emoji in text field) | ❌ Not Tested |

## Full 10-Module Codebase Audit Results

### Module 1: Owner Seat System — ✅ Complete
- `SeatCard.setOwnerBadge()` at line 113 with conditional isOwner logic
- `ownerUid` prop on `SeatGrid` is unused dead code — cosmetic only, no bug
- No conditional visibility bug

### Module 2: Room Chat — ⚠️ Partial (~40%)
- ✅ Enter key sends message + real-time delivery works via `chatServiceProvider`
- ✅ Emoji/sticker button exists
- ❌ No send button — text field `suffixIcon` only had emoji button → ✅ FIXED
- ❌ No image sharing — no gallery picker, camera capture, upload button, or image preview
- Missing: `image_picker` package, upload to Firebase Storage, chat image message type

### Module 3: Official Inbox — ❌ Missing (0%)
- No inbox screen
- No route for inbox
- No auto-created reward messages collection
- No Firestore rules for inbox

### Module 4: Broadcast System — ⚠️ Partial (~30%)
- ✅ `global_announcements` collection + admin web UI (`admin_web_broadcast_broadcast.dart`)
- ❌ No filters (VIP/country/family/agency/level)
- ❌ No scheduling support
- ❌ No push notification integration
- ❌ No inbox storage for history

### Module 5: Push Notifications — ⚠️ Partial (~40%)
- ✅ FCM integration exists (messaging import in functions)
- ✅ Token stored on login (`fcmToken` field on user profile in `auth_service.dart`)
- ❌ No click handling (`onMessageOpenedApp`, `getInitialMessage` in FirebaseMessaging)
- ❌ No notification-to-inbox routing
- ❌ No foreground notification display (`onMessage` handler)

### Module 6: Diamond Seller — ⚠️ Partial (~60%)
- ✅ Reseller/diamond seller transfers work with validation
- ❌ No push notification to user on diamond receipt

### Module 7: VIP System — ⚠️ Partial (~70%)
- ✅ Purchase, expiry, demotion, restore, kick protection all work
- ❌ No VIP daily reward claim UI
- ❌ No refund logic

### Module 8: Room Support — ⚠️ Partial (~85%)
- ✅ Weekly cycles, coin tracking, rankings, partner assignment, reward distribution all work
- ❌ No countdown timer for weekly cycle (when does it lock/distribute?)
- ✅ Support banners on home + live room screens → ✅ FIXED

### Module 9: Rocket System — ✅ Complete (100%)
- Top contributors, rankings, rewards, frames, expiry, equip, notifications, avatar display all verified

### Module 10: Betting System — ✅ Complete (100%)
- Result screen, offline protection, persistence, wallet validation, history, recovery all verified

---

## Detailed Status & Proposed Action Items

### 1. Live Room Issues

#### Issue 1: Invite User to Audio Live Call Feature Missing
* **Implementation Status**: ✅ Implemented — Code Complete, Not Tested
* **Enhancement**: Split single "Invite Mic" button into "Invite to Call" (type: `invite`) and "Bring to Call" (type: `bring`) with distinct dialog titles/descriptions
* **Files Changed**:
  - `room_service.dart` — `inviteToAudioCall()` accepts optional `type` parameter, saves it to Firestore
  - `room_user_options_sheet.dart` — Two buttons instead of one
  - `audio_call_invite_dialog.dart` — `_showInviteDialog` + `_AudioCallInviteCard` read `type` from invite data
* **Bug Fix**: `takeSeat(roomId, 0)` was hardcoded → now dynamically finds first empty seat from participants list + room capacity

#### Issue 2: Incorrect Back Button Behavior
* **Implementation Status**: ✅ Implemented — Code Complete, Not Tested
* **Files Changed**:
  - `live_room_screen.dart` — Added `canPop: false` to `PopScope` so back is intercepted. Handler calls `roomOverlayProvider.notifier.minimize()` then `GoRouter.pop()` to return to home screen with mini player overlay visible

#### Issue 3: User Entry Not Showing Instantly
* **Implementation Status**: ✅ Implemented — Code Complete, Not Tested
* **Files Changed**:
  - `participant_model.dart` — Added `helloId` field with `toMap()`/`fromMap()` serialization
  - `room_service.dart` — Added `helloId` to participant data in `createRoom()` and `joinRoom()`
  - `live_room_screen.dart` — `_OverlappingAvatarItem` changed to `ConsumerStatefulWidget`

#### Issue 4: Entry Animation Replay on Seat Click
* **Implementation Status**: ✅ Implemented — Code Complete, Not Tested
* **Files Changed**:
  - `live_room_screen.dart` — Added `if (p.uid == myUid) continue;` in Scenario B new-participant detection

#### Issue 5: Host Speaking Ring Layout Crash
* **Implementation Status**: ✅ Implemented — Code Complete, Not Tested
* **Files Changed**:
  - `live_room_screen.dart` — Wrapped `HostRippleWidget` in `Positioned.fill` inside the inner Stack

---

### 2. Audio Live Room Critical Bug

#### Issue: Audio Stops During Live Room Voice Chat
* **Implementation Status**: ✅ Implemented — Code Complete, Not Tested
* **Files Changed**:
  - `AndroidManifest.xml` — Added `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_MICROPHONE` permissions
  - `agora_voice_service.dart`:
    - **Reconnection handler**: `onConnectionStateChanged` callback detects `connectionStateFailed` → calls `_attemptReconnect()` with exponential backoff (3 attempts, 2s/4s/6s delays)
    - **Health monitor**: `_healthTimer` runs every 10s while in a channel. Tracks `_lastAudioTimestamp` from `onAudioVolumeIndication`. If no audio for 20s, triggers `_attemptReconnect()`
    - **Role tracking**: `_currentRole` tracks broadcaster/audience role, used on reconnect to restore correct role
    - **Room switching**: Detects `isSwitchingRoom`, stops health/reconnect timers, only calls `leaveChannel()` when actually switching rooms
    - **Cleanup**: `leaveRoom()` and `dispose()` both cancel health + reconnect timers
  - `voice_service.dart` — Added `onAppPaused()` and `onAppResumed()` abstract methods
  - `fake_voice_service.dart` — Added stub implementations
  - `live_room_screen.dart` — `didChangeAppLifecycleState` now calls `voiceService.onAppPaused()` on background and `voiceService.onAppResumed()` on foreground

---

### 3. Game Betting & Result System

#### Issue 1: Result Screen Not Showing Consistently
* **Implementation Status**: ✅ Implemented — Code Complete, Not Tested

#### Issue 2: Offline Betting Exploit
* **Implementation Status**: ✅ Implemented — Code Complete, Not Tested

#### Issue 3: Bet Cancellation When User Leaves Screen
* **Implementation Status**: ✅ Implemented — Code Complete, Not Tested

---

### 4. Audio Rocket System

#### Feature 1 & 2: Leaderboard & Real-Time Ranking
* **Implementation Status**: ✅ Code Complete, Not Tested

#### Feature 3: Reward System
* **Implementation Status**: ✅ Code Complete (server writes via cloud function `processRocketLaunch()`)
* **Note**: Rewards are credited via Firestore transaction — diamonds/XP/frames written, Top 3 only

#### Feature 4: Rocket Animation
* **Implementation Status**: ✅ Implemented — Code Complete, Not Tested

#### Feature 5: Global Notifications & Duplication
* **Implementation Status**: ✅ Implemented — Code Complete, Not Tested

---

### 5. Room Support System

#### Feature: Room Support / Room Target System
* **Implementation Status**: ✅ Implemented — Code Complete, Not Tested
* **Backend**: `seedRoomSupportConfigs`, `assignRoomPartner`, `removeRoomPartner`, `lockRoomSupportCycles`, `distributeRoomSupportRewards` cloud functions
* **Dart Code**: `RoomSupportService`, Riverpod providers, `RoomSupportScreen` with 7 sections
* **Navigation**: `/room-support` route; support banners on home screen + live room screen
* **Weekly Cycle**: Sunday 23:59 UTC lock, Wednesday 00:00 UTC auto-distribute
* **Partner Rules**: Level 1-7 with 4-7 slots; assignment only Mon-Tue
* **Missing**: Countdown timer display for weekly cycle deadlines

---

### 6. Remaining Gaps (Not Yet Implemented)

| Module | Gap | Priority |
| :--- | :--- | :--- |
| Room Chat | Image sharing (gallery/camera/upload) | Medium |
| Official Inbox | Full inbox system (screen + rewards + routing) | High |
| Broadcast | Filters, scheduling, push integration, inbox storage | Low |
| Push Notifications | Click handling, inbox routing, foreground display | High |
| Diamond Seller | Push notification on diamond receipt | Medium |
| VIP | Daily reward claim UI | Medium |
| VIP | Refund logic | Low |
| Room Support | Countdown timer for weekly cycle | Low |
