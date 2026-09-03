# Spin Wheel Game - Comprehensive Architecture & Context Brain Document

This document serves as the authoritative, permanent reference for the **Spin Wheel (Lucky Spin)** game system in the Hello Chat platform. Any future AI assistant or developer working on this codebase MUST read and follow the patterns documented below.

---

## 1. Game Concept & Cycle Timings

- **Cycle Duration**: Exactly **40,000 ms (40 seconds)** per round, calculated strictly via UTC server clock timestamps:
  roundId = Math.floor(synchronizedServerTimeMs / 40000)
- **Segment Multipliers & Emoji Palette**:
  - 🍅 **Tomato**: 5x (or 2x standard sector)
  - 🥖 **Bread**: 10x
  - 🍚 **Rice**: 15x
  - 🍗 **Chicken**: 25x
  - 🥩 **Steak**: 45x
  - 🥕 **Carrot**: 5x
  - 🥬 **Cabbage**: 5x
  - 🌽 **Corn**: 5x

### Phase Breakdown (Per 40s Cycle):
| Phase | Duration | Server Time Offset | Actions & Rules |
| :--- | :--- | :--- | :--- |
| **Betting Phase** | 0s – 30s | `0ms` to `30,000ms` | Betting open. Client state `SpinGameState.betting`. Outcome is generated on first call and securely hidden in `games_meta_private`. |
| **Spinning Phase** | 30s – 35s | `30,000ms` to `35,000ms` | Betting LOCKED (`_isBetLocked = true`). Wheel decel animation runs. Outcome revealed on `games_meta/lucky_spin` at `+30000ms`. |
| **Results & Celebration** | 35s – 40s | `35,000ms` to `40,000ms` | Wheel landed. `_showResultBottomSheet` opens. `_localRecentResults` updated in RAM (0ms). Transition overlay shown at 37s–40s. |

---

## 2. Backend Architecture (`functions/index.js`)

### Firebase Collections & Documents:
1. **`games_meta_private/spin_${roundId}`** *(Admin/Server Write Only)*:
   - Stores secret round outcome `{ roundId, outcome: activeRoundOutcome, createdAt }`.
   - Prevents client-side memory prediction leaks during the betting phase (0s–30s).
2. **`games_meta/lucky_spin`** *(Public Read Document)*:
   - Stores public metadata: `activeRoundId`, `lastGlobalRound`, `lastGlobalOutcome`, `recentResults` (up to 20 items), `todaySaladHits`, `todayPizzaHits`.

### Crucial Backend Reveal Timing (`playSpinWheel`):
```javascript
// Outcome reveal threshold set to 30,000ms (when betting locks at 30.0s)
const activeRoundStartMs = activeRoundId ? (Number(activeRoundId) * ROUND_DURATION_MS) : 0;
const activeRoundRevealMs = activeRoundStartMs + 30000;

if (now >= activeRoundRevealMs && lastGlobalRound !== roundId) {
    lastGlobalRound = roundId;
    lastGlobalOutcome = roundResult;
    recentResults.unshift({
        roundId: roundId,
        emoji: activeRoundOutcome.emoji,
        label: activeRoundOutcome.label,
        type: activeRoundOutcome.type,
        name: activeRoundOutcome.name,
        multiplier: activeRoundOutcome.multiplier,
        timestamp: startOfRoundEpochMs + ROUND_DURATION_MS
    });
    if (recentResults.length > 20) recentResults = recentResults.slice(0, 20);
}
```
*Why 30,000ms?* At 30.0s, betting is officially locked. Revealing `lastGlobalOutcome` at 30.0s allows real-time Firestore stream listeners on all connected devices to receive the outcome instantly without waiting for the next round.

---

## 3. Frontend UI Architecture (`spin_wheel_screen.dart`)

### Single Source of Truth: `_resolveLatestWinner(stats)`
To prevent desynchronization between different UI panels (e.g. top header pill showing Cabbage while bottom panel shows Carrot), all 4 UI sections MUST resolve the latest winner using `_resolveLatestWinner`:

```dart
SpinItem? _resolveLatestWinner(Map<String, dynamic>? stats) {
  if (_storedWinItem != null) return _storedWinItem;
  if (_localLastWinner != null) return _localLastWinner;
  if (_localRecentResults.isNotEmpty) {
    final loc = _localRecentResults.first;
    final name = loc['name']?.toString() ?? '';
    if (name.isNotEmpty) {
      return SpinItem(
        name: name,
        multiplier: (loc['multiplier'] as num?)?.toInt() ?? 1,
        emoji: (loc['emoji'] ?? _getFoodEmoji(name)).toString(),
      );
    }
  }
  final lastGlobalOutcome = stats?['lastGlobalOutcome'] as Map<String, dynamic>?;
  if (lastGlobalOutcome != null) {
    final name = (lastGlobalOutcome['name'] ?? lastGlobalOutcome['label'] ?? '').toString();
    if (name.isNotEmpty) {
      final mult = (lastGlobalOutcome['multiplier'] as num?)?.toInt() ?? 1;
      final emoji = (lastGlobalOutcome['emoji'] ?? _getFoodEmoji(name)).toString();
      return SpinItem(name: name, multiplier: mult, emoji: emoji);
    }
  }
  return null;
}
```

### The 4 Synchronized UI Sections:
1. **Top Left Header Pill (`_buildHeader`)**: Displays `Last Winner: [Emoji] [Multiplier]x`.
2. **Result Bar Position #1 (`_buildResultBar`)**: Displays latest outcome with yellow `New` badge.
3. **Bottom Right Prev Winner Box (`_buildBottomPanel`)**: Displays `[EMOJI] [FOOD_NAME]: [Multiplier]x`.
4. **Victory Popup Sheet (`_showResultBottomSheet`)**: Displays victory card & profit stats.

---

## 4. Multi-Device Responsiveness & Scale Rules

- Scale factor formula in `LayoutBuilder`:
  ```dart
  final scale = (constraints.maxWidth / 375).clamp(0.75, 1.25);
  ```
- **Small Screens (320px–360px)**: Bounded at `0.75` minimum scale to preserve legible font sizes.
- **Tablets & Foldables (600px+)**: Bounded at `1.25` maximum scale to prevent vertical RenderFlex overflows.

---

## 5. Network & Audio Resilience

- **HTTP Audio Asset Cache**: Audio download failures (e.g. HTTP 403 Forbidden) set `_soundFailed = true` to stop repeating 403 requests on 100ms timer ticks.
- **Haptic Feedback Fallback**: `HapticFeedback.selectionClick()` runs natively on every countdown tick for crisp tactile feedback regardless of network state.

---

## 6. Key Bug Resolutions Logged for Future Reference

1. **1-Step Result Delay**: Caused by `roundIdStr == _currentRoundId` filter hiding the active round result during the reveal phase. Fixed by restricting the filter strictly to `_gameState == SpinGameState.betting`.
2. **Cabbage vs Carrot Multiplier Mismatch**: Caused by `winningItem.multiplier` computing `totalBet > 0 ? (prize / totalBet).round() : 0`. Fixed by extracting the inherent segment multiplier (`matchingSegment['multiplier'] ?? outcome['multiplier'] ?? 1`).
3. **Header Pill vs Bottom Panel Desync**: Caused by `_buildHeader` reading `stats['lastGlobalOutcome']` directly while bottom panels read local memory. Fixed by unifying all 4 panels under `_resolveLatestWinner`.
