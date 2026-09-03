---
name: multi-device-ui-and-sync-rules
description: Mandatory rules for multi-device responsive UI, server time synchronization, and user ID visibility on call seats and sheets.
---

# 🚨 IMPORTANT: Prevent Device Layout Cut-offs & Missing User IDs

When modifying or creating any UI screens, games, or live room features, strictly follow these 3 mandatory design and engineering rules.

---

## 1. Multi-Device Responsive UI & Bottom Navigation Bar Support

### Never calculate scale using only `maxWidth`
Always factor in vertical height constraints when scaling UI elements:

```dart
final widthScale = constraints.maxWidth / 375;
final heightScale = constraints.maxHeight / 750;
final scale = math.min(widthScale, heightScale).clamp(0.70, 1.15);
```

### Respect Android Software Navigation Bars
Wrap bottom-aligned panels and fixed bottom stacks in `SafeArea(top: false)` or account for `MediaQuery.of(context).padding.bottom` so elements are never cut off or pushed off-screen on shorter phones or devices using 3-button software navigation.

---

## 2. Server Time Synchronization for Shared Real-Time Game States

### Do NOT rely exclusively on `DateTime.now()` (local phone clock)
Phone clocks differ by seconds/minutes or timezones across different client devices.

### Use Server Time Offset
Always calculate game rounds, countdown timers, and wheel spin target highlights using server time synchronization (e.g., Firebase Realtime Database `.info/serverTimeOffset` or server timestamps) so every connected user sees the exact same round ID and winning animation at the same time.

---

## 3. Mandatory User ID (`helloId`) Visibility on Call Seats & Sheets

### Always render User IDs on mic call seats
In `seat_grid.dart` (`OccupiedSeatWidget`) and viewer lists (`viewers_list_sheet.dart`), always display the user's unique ID (`ID: ${helloId}`) clearly under or next to their display name.

### Sync `helloId` in real-time payloads
When a user takes a seat (`takeSeat` in `room_service.dart`), ensure `helloId` is attached to the participant payload merged into Firestore so all client devices display the ID immediately.

---

## Testing Protocol

**Always test on a connected device in debug mode first** before merging any changes. Verify:
1. UI elements are not cut off on different device sizes
2. Bottom navigation bars do not overlap content
3. Game timers are synchronized across multiple connected clients
4. User IDs are visible on all call seats and viewer lists
