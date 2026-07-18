# Spec: Room Support / Room Target System

## Objective
Implement a Room Support monetization system visible from Home banner + Live Room button. Room owners earn rewards based on weekly room coin targets, and can assign salary partners.

## Architecture

### Firestore Collections
- `room_support_configs/settings` — Target table (levels, coins required, slots, rewards)
- `room_support_cycles/{roomId}` — Current cycle: `weekStart`, `weekEnd`, `status` (accumulating|closed|distributing|distributed), `totalCoins`, `level`, `coinsNeeded`
- `room_support_partners/{roomId}` — Subcollection `partners/{uid}` with `assignedAt`, `share`
- `room_support_rewards/{rewardId}` — Distribution records
- `room_support_history/{roomId}` — Subcollection `weeks/{weekId}` with historical data
- `room_support_rankings/rankings` — Aggregated room rankings

### Cloud Functions
- `weeklyCycleCron` — Scheduled (Sunday 23:59 UTC): locks cycles
- `distributeRewards` — Scheduled (Wednesday 00:00 UTC): auto-distributes
- `assignRoomPartner` — Callable: owner assigns partner (Mon-Tue only)

### Frontend Routes
- `/room-support` → `RoomSupportScreen` (new)

### Frontend Components
- `RoomSupportScreen` — Main scrollable page with all sections
- `RoomSupportService` — Firestore read/write
- `RoomSupportProvider` — Riverpod providers
- Navigation: banner action + live room floating button

## Implementation Order
1. Firestore rules + collections setup
2. Cloud Functions (cycle logic + partner assignment)
3. RoomSupportService + RoomSupportProvider (Dart)
4. RoomSupportScreen UI (all tabs)
5. Navigation wiring (banner + live room button)
6. Status docs update
