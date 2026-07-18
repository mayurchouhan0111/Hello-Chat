# Spin Wheel Game — Code Changes for Review

## Client Problems Reported

1. **Timing desync**: Result appears before timer finishes — the spin animation completion triggers the result, not the server clock. Result shows while countdown still reads several seconds.

2. **Betting time wrong**: Was set to 25s but should be exactly 30s. Winning time was 10s but should be 5s.

3. **Screen locks during gameplay**: Phone screen turns off automatically while playing the spin wheel game (no wake lock held during the game screen).

4. **Flashlight/camera turns on unwanted**: App was incorrectly turning on the camera flashlight during gameplay — client never asked for torch.

5. **"Big Winning" empty list**: In the winning time bottom sheet, there are two winner displays. One is the live podium (top 3 players — keep this). The other is a "Big Winning" list showing empty placeholder slots even when no one is playing (remove this).

6. **RenderFlex overflow**: Bottom sheet text (result label, wager label) causes yellow/black overflow stripe on some screen sizes.

7. **Game state lost on crash**: If the app crashes or is force-closed after placing a bet, the bet is lost and the user has no way to recover.

8. **Round transition feels abrupt**: When a round ends and the next begins, there is no visual transition — the game state jumps instantly.

## Files Modified

### 1. `lib/features/games/presentation/screens/spin_wheel_screen.dart` (primary file)

#### A. Betting & Winning Timing (lines ~380-420)
- `serverBettingPhaseSec = 30`, results phase = 5s, total round = 40s
- `_gameState` transition now based on server clock (`secondsIntoCycle`), **not** spin animation completion
  - `SpinGameState.betting` → `spinning` at `serverBettingPhaseSec` (30s)
  - `SpinGameState.spinning` → `results` at `serverBettingPhaseSec + serverSpinPhaseSec` (35s)
- Result bottom sheet only appears at 35s into cycle
- Countdown label changes per phase: `"Select time"` (betting), `"Spinning"` (spinning), `"Winning"` (results)
- Results countdown shows 5→0: `(serverBettingPhaseSec + serverSpinPhaseSec + 5) - secondsIntoCycle`

#### B. Round Transition Overlay (lines ~370-400)
- New variables: `_showRoundTransition`, `_roundTransitionCountdown`
- Last 3 seconds of each round (37-40s) shows 3→1 countdown overlay
- Overlay rendered in the build method (rendered above game wheel, below app bar)

#### C. Winner Podium (lines ~2612-2648, now reorganized)
- `Consumer` watches `luckySpinCurrentRoundWinnersProvider` for live winners
- Podium section (header + 3-player display) now wrapped in conditional: only renders when `winnersList.isNotEmpty`
- Empty podium with placeholder "Empty" slots no longer appears when no one is playing

#### D. Stored Result State (lines ~70-75, methods)
- Added `_storedWinItem`, `_storedPrize`, `_storedWager`, `_storedWinners`, `_storedRoundId`, `_storedBets`
- `_showStoredResult()` / `_clearStoredResult()` for delayed result display
- Results phase handler checks stored result first before falling back to stream/pending

#### E. Wakelock Integration (lines ~145, 230-240, dispose)
- Uses shared `WakelockService` (singleton) instead of direct `WakelockPlus` calls
- `_wakelockService.acquire()` called in post-frame callback (`WidgetsBinding.instance.addPostFrameCallback`)
- `_wakelockService.release()` called in `dispose()`
- Reference counting ensures room + game can both hold wakelock without conflict

#### F. Torch Removal
- All `TorchService` references removed: `initState`, `dispose`, `_handleLifecycleChange`
- No camera/flashlight calls remain in the file

#### G. Overflow Fix (lines ~2514, 2537)
- `Flexible` widget added around result/wager label texts to prevent `RenderFlex overflow`

#### H. Lifecycle Handling
- Added `WidgetsBindingObserver` mixin to `_SpinWheelScreenState`
- `didChangeAppLifecycleState` handles app pause/resume
- On pause: saves game state via `GameRecoveryService`, releases wakelock
- On resume: re-acquires wakelock

### 2. `lib/features/rooms/presentation/screens/live_room_screen.dart`

- Import changed: `wakelock_plus` → `WakelockService` from `lib/core/services/wakelock_service.dart`
- `_wakelockService.acquire()` in post-frame callback (line ~210)
- `_wakelockService.release()` in `dispose()` (line ~258)

### 3. `lib/core/services/wakelock_service.dart` **NEW**

- Singleton with reference counting
- `acquire()`: increments ref count; calls `WakelockPlus.enable()` if first acquire
- `release()`: decrements ref count; calls `WakelockPlus.disable()` if ref reaches 0
- Thread-safe for multiple callers

### 4. `lib/core/services/game_recovery_service.dart` **NEW**

- Saves bet state (`roundId`, `itemName`, `wager`) to local JSON file
- `saveBetState()`: writes to `game_recovery.json`
- `loadBetState()`: reads and deserializes
- `clearBetState()`: deletes file
- Used in spin_wheel_screen: save on `_placeBet()`, load on `_tryRecoverGameState()` in `initState`, save on app pause, clear on successful spin submit, clear on `dispose()`

### 5. `pubspec.yaml`

- Removed `camera: ^0.11.0` dependency
- `wakelock_plus: ^1.2.5` kept

### 6. `lib/core/services/torch_service.dart` **DELETED**

- Entire file removed

## State Variables Added

```dart
String? _storedWinItem;
int? _storedPrize;
int? _storedWager;
List<Map<String, dynamic>>? _storedWinners;
String? _storedRoundId;
Map<String, int>? _storedBets;

int _roundTransitionCountdown = 0;
bool _showRoundTransition = false;
String _countdownLabel = "Select time";
```

## Game Recovery Flow

```
Place bet       → saveBetState(roundId, itemName, wager)
App crashes     → app restarts → initState → _tryRecoverGameState()
                  → checks if round still betting → re-submits bet
                  → if round already over → clears recovery file
App pause       → saveBetState() (backup)
Dispose         → clearBetState()
Spin submitted  → clearBetState()
```

## Wakelock Flow

```
Enter room      → acquire() (ref=1)
Enter game      → acquire() (ref=2) → WakelockPlus.enable()
Leave game      → release() (ref=1) → still on (room holds)
Leave room      → release() (ref=0) → WakelockPlus.disable()
```

## Backend (Firebase Functions)

All pre-existing uncommitted changes in `functions/index.js` were deployed via `firebase functions deploy`. Changes include:
- Salary payout system using daily salary config
- VIP tier upgrades (Bronze→Silver→Gold→Platinum→Diamond)
- VIP weekly salary distribution
- Diamond stock system
- Reseller transfer system
- Game provider admin endpoints
- Gamelist management APIs
- Various admin dashboard operations

## Key Timing Constants

| Phase | Duration | Server Cycle |
|-------|----------|-------------|
| Betting | 30s | 0s → 30s |
| Spinning | 5s | 30s → 35s |
| Results | 5s | 35s → 40s |
| **Total** | **40s** | |

## Lint Status

`flutter analyze` on the modified file shows no new errors. All 64 issues are pre-existing (unused fields, deprecated `withOpacity`, unused elements).
