# PLAN: App crashes when 3–4 people speak at the same time in a room

> Status: DRAFT — read fully before touching code. Reproduce + capture logcat FIRST (Step 0).
> Fix targets: Android app only (`lib/`). No backend change needed.

---

## 1. The problem (symptom)

- When **3–4 users speak simultaneously** in a live voice room, the app **crashes and exits the room / the app**.
- Happens on Android (device V2132, Android 14, 7.6 GB RAM). Reproducible, not intermittent.
- Blocks ALL other module testing (gifts, rocket, spin wheel) because the room dies mid-team-test.
- Works fine with 1 speaker, and mostly fine with 2.

## 2. Where the problem lives (evidence, file:line)

All paths below are live code read at analysis time (2026-09-16).

### 2.1 Agora volume events → speaking UID stream (the trigger)

- `lib/services/agora_voice_service.dart:224`
  `await _engine!.enableAudioVolumeIndication(interval: 200, smooth: 3, reportVad: true);`
  → Agora calls `onAudioVolumeIndication` **every 200 ms** while anyone (incl. remote) talks.
- `lib/services/agora_voice_service.dart:121-145`
  `onAudioVolumeIndication` → for each speaker with `volume > 15`, collects uid into a **new** `List<int> speakingUids`, then:
  - `_speakingUidsController.add(speakingUids)` (line 139)
  - `_speakingController.add(...)` (line 140)
  These are **broadcast** `StreamController`s (lines 22-24).
- Calls are on the main isolate (agora_rtc_engine 6.5.3 marshals callbacks to Dart on the UI thread) — not a cross-thread bug.

### 2.2 Providers fanning the events to every widget

- `lib/core/providers/room_provider.dart:36-42`
  - `isSpeakingProvider = StreamProvider<bool>`
  - `speakingUidsProvider = StreamProvider<List<int>>`
  Both watch `voiceServiceProvider` streams. A new list of uids is emitted every 200 ms while anyone talks.

### 2.3 The crash surface — concurrent SVGA "speaking wave" players

- `lib/features/rooms/presentation/widgets/seat_grid.dart:349-395` — `SpeakingBorderWidget` (ConsumerWidget):
  - line 361: `ref.watch(speakingUidsProvider)` → rebuilds on **every** 200 ms emission
  - line 367: `if (!isSpeaking) return SizedBox.shrink();`
  - lines 378-384: when speaking, mounts the **full SVGA player** asset per speaker:
    `SvgaPlayer(key: ValueKey('speaking_sound_waves_${user.vipTier}'), assetPath: wavesPath)`.
  - `getVipMicWavesPath` (line 501) returns a real `.svga` for VIP levels 1-8 (sizes: 180 px overlay per speaker; host overlay 180 px at live_room_screen.dart:3189).
  - Non-VIP users get `_SpeakingRippleBorder` (pure CustomPaint controller, cheap).

- `lib/features/rooms/presentation/screens/live_room_screen.dart:1966` — `Positioned.fill(child: HostRippleWidget(user: u))`.
- `live_room_screen.dart:3172-3196` — `_HostRippleWidgetState.build`:
  - line 3174: `ref.watch(speakingUidsProvider)`
  - lines 3188-3193: host speaking → full SVGA player (`SvgaPlayer(assetPath: wavesPath)`).

### 2.4 SVGA caching / lifecycle (the amplifying bug)

- `lib/core/utils/svga_parser_util.dart:79-98` (`decodeSafeFromAssets`):
  - Caches a **single shared `MovieEntity` per asset** in `_movieCache` (`autorelease = false`, line 87).
  - **Cache eviction:** when cache grows past `_maxMovieCacheSize = 80` (line 91-95), it calls `evicted?.dispose()` on the oldest entity.
- `lib/core/widgets/svga_player.dart:84-191` (`_SvgaPlayerState`):
  - Each mount creates `SVGAAnimationController(vsync: this)` (line 94) and `repeat()`s it (line 148).
  - `dispose()` at 186-190 stops + disposes the controller.
- **Problem:** the "Mic Waives"/"Sound Waives" entities are the same shared cache entries used by many simultaneous players (host + up to 8 seats). `preloadVipAssets()` (svga_parser_util.dart:190-297) decodes ~45 entities into cache at startup — so the wave assets usually hit cache; but when other gift/entry/rocket SVGA decodes flood the 80-slot cache during an active team test, the evicted entity can be **disposed while a live speaker is still rendering it** → native use-after-free crash. Activity spikes exactly when many users (speakers + gifts) are live — matching "3–4 people talking → crash".

### 2.5 Why it specifically happens at 3–4 speakers (not 1–2)

1. Each extra speaker = one **more concurrent SVGA render loop @ 60 fps** (plus the host) on one raster thread.
2. More speakers → `speakingUids` list changes more often → more `SpeakingBorderWidget` mounts/unmounts → more `SVGAAnimationController.init/repeat/dispose` churn per 200 ms tick.
3. Meanwhile gifts/entries keep evicting shared SVGA cache entries that wave players depend on.

## 3. Fix strategy (ranked — do 3A first, it likely solves 100%)

### 3A (REQUIRED, cheapest, likely root fix) — Stop mounting full SVGA players per speaking seat

Option A1 (recommended): Replace the per-speaker full `SvgaPlayer` wave overlay with the **existing lightweight `_SpeakingRippleBorder` (CustomPaint)** for ALL tiers in `SpeakingBorderWidget`:
- `seat_grid.dart:367-394` — always use `borderChild = _buildDefaultSpeakingBorder(radius, hasFrame)`.
- Keep `getVipMicWavesPath` unused or remove it; host side (`live_room_screen.dart:3180-3196`) → use the ripple too (`_HostRippleWidget` already has a ripple path at lines 3197+).
- Effect: zero SVGA render loops tied to speaking state; crash surface removed entirely. Wave cosmetics lost (acceptable — rip wall animation is a common tradeoff).

Option A2 (if waves must stay): Throttle + cap. Add a debounce so `SpeakingBorderWidget` only *mounts* the SVGA player after the speaker is consistently active (e.g. stable for 400 ms), never mount per 200 ms tick; cap concurrent wave players at 1 (the host) — seats get ripple.

### 3B (REQUIRED) — Stop sharing + disposing live `MovieEntity`s

`svga_parser_util.dart:79-128`:
- Never `dispose()` a cached `MovieEntity` that may be referenced by a live painter. Either:
  - (a) Remove eviction dispose for wave/entry assets: guard with a ref-count in `SvgaPlayer` mount/unmount, or
  - (b) Set `_maxMovieCacheSize` high enough + skip eviction for the preloaded set (track a "protected" set), or
  - (c) `SvgaParserUtil` per-player copy-on-use (own decode per `SvgaPlayer`) — heavier, only needed if 3B(a/b) can't be proven.
- Set `autorelease=false` only on shared cache entries and ensure **nothing** disposes a shared entity still in use (`player.dart` SVGAAnimationController.dispose auto-disposes when `autorelease`; verify this is bypassed — 2.x checks `_videoItem?.autorelease`, good).

### 3C (RECOMMENDED) — Silence the 200 ms rebuild storm

Even with ripple-only, every `SpeakingBorderWidget` rebuilds on every 200 ms tick:
- In `agora_voice_service.dart:121-145`, only emit when the speaking set actually **changes** (compare against last list before `add`). Prevents 5 rebuild/s per widget.
- Or subscribe once per seat widget and compute `isSpeaking` locally without Riverpod `ref.watch` on a per-tick stream (e.g. watch a single combined provider).

### 3D (DEFENSE) — Never let animation state kill the room

- `lib/core/widgets/svga_player.dart` — wrap `repeat()`/`forward()`/`_controller.videoItem = ...` in try/catch + `if (!mounted) return`.
- In `seat_grid.dart`/`live_room_screen.dart`, guard SVGA mount blocks with `kDebugMode` on/off or a global "effects enabled" flag so a failing animation can never take down the room screen.

## 4. Verification

1. `flutter analyze` clean.
2. Reproduce manually (3-4 team phones talking in one room). App must stay alive for 10+ minutes of continuous simultaneous speech.
3. Regression: single speaker, gifts + rocket while speaking, host + VIP wave previously shown — confirm no crash + acceptable visuals.
4. (If 3A-A1) Confirm no visual regression blockers: speaking ring still shows for all tiers.

## 5. Out of scope / notes

- Do NOT change Agora backend, tokens, or `functions/index.js`.
- `onAudioVolumeIndication(interval:200, smooth:3)` firing rate is fine; the bug is the UI reaction to it, not the event cadence itself.
- `_remoteUids` join/leave (agora_voice_service.dart:101-120) is unrelated to this crash — don't touch.
- The `withOpacity` analyzer infos elsewhere are pre-existing and unrelated here.