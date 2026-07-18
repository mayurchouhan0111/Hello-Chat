# Remaining Work — Hello Chat Codebase

## Context
This project is a Flutter social audio app ("Hello Chat") with Firebase backend. Two AI agents have completed work on audio call invitations (Invite to Call / Bring to Call), room kick/ban system, support system, rocket system, betting system, and various bug fixes. The following gaps remain from a full 10-module codebase audit.

---

## 1. Room Chat — Image Sharing

**Files:** `live_room_screen.dart` (bottom bar at ~line 1157), `chat_service.dart`

**What's done:** Text messages work via Enter key + send button (just added). Emoji/sticker button exists.

**What's missing:**
- No gallery/camera image picker button in the chat bottom bar
- No image upload to Firebase Storage
- No image message type in chat display

**How to implement:**
1. Add `image_picker` package to `pubspec.yaml`
2. Add a gallery icon button (e.g. `Icons.image_outlined`) as a third `suffixIcon` in the chat `TextField` decoration (next to emoji and send buttons at `live_room_screen.dart:1190`)
3. On press: launch `ImagePicker().pickImage()` from gallery or camera
4. Upload the image to Firebase Storage at path `chat_images/{roomId}/{uid}_{timestamp}.jpg`
5. Call `chatService.sendTextMessage()` but with the Storage download URL as the message content (or add a separate `sendImageMessage()` method if the chat model supports media types)
6. Display images in the chat bubble area (add an `Image.network()` widget when the message starts with `https://` or has a media type field)

---

## 2. Official Inbox — Entire System Missing (HIGH PRIORITY)

**Files to create:** `lib/features/inbox/` (new directory), `app_router.dart`, `firestore.rules`

**What's done:** Nothing. No inbox screen, no route, no Firestore collection for reward messages.

**What's missing:**
- Inbox screen UI showing a list of messages
- Route `/inbox` registered in `app_router.dart`
- Firestore collection `users/{uid}/inbox_messages` with auto-creation from cloud functions
- Firestore rules allowing users to read their own inbox

**How to implement:**
1. Create `lib/features/inbox/presentation/screens/inbox_screen.dart` — a `ConsumerStatefulWidget` that streams `users/{uid}/inbox_messages` ordered by `createdAt` descending
2. Each message shows: icon (based on `type` field like `reward`, `broadcast`, `system`), title, body, timestamp
3. Add route `GoRoute(path: '/inbox', builder: ...)` to `app_router.dart`
4. Add Firestore rules: `match /users/{uid}/inbox_messages/{msgId} { allow read: if request.auth.uid == uid; allow write: if false; }`
5. Add a cloud function trigger (or modify existing broadcast/reward functions) to write inbox messages with fields: `{ type, title, body, data: {}, read: false, createdAt: admin.firestore.Timestamp.now() }`

---

## 3. Broadcast System — Filters, Scheduling, Push, Inbox

**File:** `functions/index.js` (broadcast cloud function), `admin_web_broadcast_broadcast.dart`

**What's done:** Basic `global_announcements` collection exists. Admin web UI broadcasts exist.

**What's missing:**
- No audience filters (VIP level, country, family/agency, minimum level)
- No scheduling (ability to set a `scheduledAt` timestamp for delayed delivery)
- No push notification integration (broadcasts don't trigger FCM)
- No inbox storage (broadcasts don't get saved to `users/{uid}/inbox_messages`)

**How to implement:**
1. Modify the broadcast cloud function to accept a `filters` map: `{ vipsOnly: bool?, minLevel: int?, countries: string[]?, families: string[]? }`
2. Query `users` collection with the appropriate filters instead of sending to everyone
3. Add a `scheduledAt` field — if set, use a scheduled cloud function (via Cloud Tasks or a cron check) instead of immediate delivery
4. Add FCM multicast via `admin.messaging.sendEachForMulticast()` with the filtered user FCM tokens
5. Write each broadcast message to `users/{uid}/inbox_messages` for persistence

---

## 4. Push Notifications — Click Handling & Routing (HIGH PRIORITY)

**File:** `lib/main.dart`, `app_router.dart`

**What's done:** FCM integration exists in the backend. Token is stored on login (`fcmToken` field in `auth_service.dart`).

**What's missing:**
- No `FirebaseMessaging.onMessageOpenedApp` listener (app launched from notification tap)
- No `FirebaseMessaging.getInitialMessage` handler (cold start from notification)
- No `FirebaseMessaging.onMessage` listener (foreground notification display)
- No routing logic when notification is tapped (should navigate to relevant screen)

**How to implement:**
1. In `main.dart` (or a dedicated notification service), initialize `FirebaseMessaging`:
   ```dart
   final messaging = FirebaseMessaging.instance;
   await messaging.requestPermission();
   ```
2. Register `onMessageOpenedApp` handler (for background tap):
   ```dart
   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
     final data = message.data;
     final route = data['route']; // e.g. '/room/123', '/inbox'
     if (route != null) context.go(route);
   });
   ```
3. Handle cold start via `getInitialMessage()` in `main()` before `runApp()`:
   ```dart
   final initial = await messaging.getInitialMessage();
   if (initial?.data case {'route': final route}) {
     // store route to navigate after app builds
   }
   ```
4. Show a local notification or SnackBar for `onMessage` (foreground):
   ```dart
   FirebaseMessaging.onMessage.listen((RemoteMessage message) {
     // show FlutterLocalNotificationsPlugin notification or an in-app overlay
   });
   ```

---

## 5. Diamond Seller — Push Notification on Receipt

**File:** `functions/index.js` (diamond/seller cloud function)

**What's done:** Reseller/diamond seller transfers work with validation. Coins/diamonds are credited.

**What's missing:**
- No push notification sent to the recipient when diamonds are received

**How to implement:**
1. In the `transferDiamonds` cloud function (or equivalent), after the transaction succeeds, add:
   ```js
   const recipientDoc = await admin.firestore().collection('users').doc(recipientUid).get();
   const fcmToken = recipientDoc.data()?.fcmToken;
   if (fcmToken) {
     await admin.messaging().send({
       token: fcmToken,
       notification: {
         title: 'Diamonds Received',
         body: `You received ${amount} diamonds from ${senderName}`,
       },
       data: { route: '/wallet' },
     });
   }
   ```

---

## 6. VIP System — Daily Reward Claim UI

**File:** `lib/features/vip/presentation/screens/vip_shop_screen.dart` or a new `vip_rewards_screen.dart`

**What's done:** VIP purchase, expiry, demotion, restore, kick protection all work.

**What's missing:**
- No UI to claim daily VIP rewards
- No logic to track last claim date (Firestore field `lastDailyClaim` on user doc)

**How to implement:**
1. Add a "Daily Reward" section to the VIP screen (or create a new `/vip-rewards` route)
2. Check `userProfile?.lastDailyClaim` — if it's before today UTC, show "Claim" button; otherwise show "Claimed" with countdown
3. On claim: call a cloud function `claimVipDailyReward` that:
   - Validates user has active VIP
   - Checks `lastDailyClaim` is before today
   - Credits reward (e.g. 100 diamonds + 500 XP) via transaction
   - Updates `lastDailyClaim` to now
4. Add a route for the reward screen in `app_router.dart`

---

## 7. VIP System — Refund Logic

**File:** `functions/index.js`

**What's done:** Nothing for refunds.

**What's missing:**
- No cloud function or logic to refund VIP when user is unhappy or when VIP is revoked prematurely

**How to implement:**
1. Create a callable function `refundVip` that:
   - Takes `{userId, reason}`
   - Admin-only (check custom claims)
   - Recalculates remaining VIP days
   - Refunds proportional diamonds (or a fixed amount)
   - Removes VIP status and expires the VIP document
2. Add an admin UI button somewhere in the admin panel

---

## 8. Room Support — Countdown Timer

**File:** `room_support_screen.dart` (~line 718, full screen)

**What's done:** Weekly cycles, coin tracking, rankings, partner assignment, reward distribution all work. Support banners added on home + live room screens.

**What's missing:**
- No visual countdown timer showing when the current cycle locks (Sunday 23:59 UTC)
- No visual countdown showing when rewards distribute (Wednesday 00:00 UTC)

**How to implement:**
1. In `room_support_screen.dart`, add a `CountdownTimer` widget in the header
2. Query the current cycle's `lockAt` (Sunday 23:59 UTC) and `distributeAt` (Wednesday 00:00 UTC)
3. Use `Timer.periodic(Duration(seconds: 1))` to update a `Duration` display
4. Show different states:
   - Before lock: "Locking in Xh Xm Xs"
   - Locked but pre-distribute: "Distributing in Xh Xm Xs"
   - Distributed: "New cycle starts in Xd Xh"

---

## Summary of File Changes Needed

| File | Change |
|------|--------|
| `pubspec.yaml` | Add `image_picker` dependency |
| `live_room_screen.dart` | Add gallery button + image capture/upload in bottom bar |
| `chat_service.dart` | Add `sendImageMessage()` or image-friendly send method |
| `lib/features/inbox/` (new) | Full inbox screen + provider |
| `app_router.dart` | Add `/inbox` and `/vip-rewards` routes |
| `firestore.rules` | Add inbox messages read rule |
| `functions/index.js` | Add inbox write on broadcast/distribution, add push on diamond transfer, add VIP refund, add scheduled broadcast delivery |
| `lib/main.dart` | Add FirebaseMessaging initialization + handlers |
| `vip_shop_screen.dart` or new file | Add daily reward claim UI |
| `room_support_screen.dart` | Add countdown timer for lock/distribute |
