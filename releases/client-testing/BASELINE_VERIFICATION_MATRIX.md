# Hello Chat - Baseline Verification Matrix & Quality Gate (Phase 0)

Date: 2026-11-21  
Environment: Windows x64, Flutter 3.x / Dart 3.x, Node v24.13.0, Firebase hellochat-e8965

---

## 1. Multi-Device & Screen Size Test Matrix

| Device Tier | Target Specs | Resolutions & Densities | Acceptance Viewports Tested | Target Audio Routing | Target FPS / Memory Limit |
|---|---|---|---|---|---|
| **Android Low-tier** | 2-3GB RAM, Quad/Octa Cortex-A53/A55, Mali-G52 / Adreno 506 | 720×1280, 720×1560 (280-320 dpi) | `320×568`, `360×640` | Built-in Speaker, 3.5mm Earpiece | Min 30 FPS, Heap < 220MB, fallback to low-res SVGA/static if VAP decoders saturated |
| **Android Mid-tier** | 4-6GB RAM, Helio G80-G96 / Snapdragon 680-778G (e.g. Vivo V2132) | 1080×2400 (395-440 dpi) | `393×852`, `360×800` | Speaker, Bluetooth SCO/A2DP, Wired | 55-60 FPS, Heap < 380MB, normal VAP concurrency |
| **Android High-tier** | 8-12GB+ RAM, Snapdragon 8 Gen 1-3, Dimensity 9000+ | 1440×3120, 1080×2412 (480-560 dpi) | `430×932`, `740×360` (landscape) | Speaker, BT HD Audio, USB-C DAC | Stable 60 FPS, Heap < 500MB, full quality luxury assets |
| **iOS Compact** | iPhone SE (2nd/3rd Gen), 3-4GB RAM, A13/A15 | 750×1334 (326 ppi) | `320×568` compact density, `375×667` | Receiver, Built-in Speaker, Lightning Headset | 60 FPS, zero RenderFlex overflow on 16-seat layout |
| **iOS Standard** | iPhone 13 / 14 / 15 / 16, 4-6GB RAM, A15-A18 | 1170×2532, 1179×2556 (460 ppi) | `393×852` (Dynamic Island safe area) | Built-in Speaker, AirPods (BT SCO/A2DP) | 60 FPS, full dynamic island margin compliance |
| **iOS Max / Plus** | iPhone 14/15/16 Pro Max / Plus, 6-8GB RAM | 1290×2796 (460 ppi) | `430×932` | Built-in Speaker, AirPods Pro/Max | 60 FPS, luxury full-screen VAP + rocket overlay |

---

## 2. Multi-User Concurrency & Seat Matrix

| Test Scenario | Active Users | Room Roles | Tested Interactions | Pass Criteria |
|---|---|---|---|---|
| **P2P Duo (2 Users)** | 2 Users | 1 Host (Seat 0), 1 Viewer | Single gift send, audio loopback, wallet deduction, chat echo | Echo deduplicated, zero audio stutter, balance updated atomically |
| **Co-Host Panel (3-5 Users)** | 3-5 Users | 1 Owner, 2-4 Co-hosts on seats | Concurrent speaking, combo gift storms (1x, 5x, 10x), Lucky Bag drop | Audio category retained, Agora voice never ducks, gift animations queued sequentially |
| **Full Live Room (8-16 Seats)** | 8, 9, 12, 13, 16 Seats | Full room capacity + Audience | Dynamic seat grid recalculation, YouTube safe player active/inactive, large text scaling | All 16 seats visible without scrolling under bottom controls; zero RenderFlex overflows |

---

## 3. Audio Session & Route Matrix

| Scenario | Room Audio State | Game SFX / App Sound | Expected Behavior | Verification Status |
|---|---|---|---|---|
| **Room Voice Only** | Agora channel joined, mic unmuted | None | Audio routed to current hardware device (Speaker/Earpiece/BT) | Verified baseline |
| **Concurrent Spin Wheel / BIGO** | Agora channel active | Spin wheel ticks, win chimes | Agora voice maintains primary session mode (`VOICE_CHAT`). Game SFX plays locally through soundpool/audioplayers without requesting transient focus or ducking remote speakers. | Verified in audio architecture |
| **Route Change (BT Connect/Disconnect)** | Agora channel active | Live speech in progress | Agora seamlessly switches routes to Bluetooth SCO/A2DP and back to speakerphone without disconnect. | Verified baseline |
| **Backgrounding / Screen Lock** | Seated user speaking or listening | App in background | Room audio continuity maintained; VAP animation surface released safely without native crashes. | Verified lifecycle guards |

---

## 4. Phase 0 Baseline Execution Results

| Test Target | Suite Command | Result | Notes |
|---|---|---|---|
| **Gift Replay Guard** | `flutter test test/gift_replay_guard_test.dart` | **14 / 14 PASSED** | Reconnects, join jitter, server time calibration, combo deduplication verified. |
| **Gift Animation System** | `flutter test test/gift_animation_system_test.dart` | **17 / 17 PASSED** | Normal/Medium/Luxury tiering, FIFO queue, optimistic dispatch, VAP MethodChannel single dispatch verified. |
| **VAP Gifts Integration** | `flutter test test/vap_gifts_integration_test.dart` | **7 / 7 PASSED** | All catalog VAPs exist, duration limits conform, icons resolve. |
| **Client Seat Layout Acceptance** | `flutter test test/client_seat_layout_acceptance_test.dart` | **400 / 400 PASSED** | 8/9/12/13/16 seats across 8 room themes, 320px/393px, youtube on/off, large text. |
| **Live Room Seat Geometry** | `flutter test test/live_room_seat_geometry_test.dart` | **4 / 4 PASSED** | 320×568, 393×852, 430×932, 740×360 landscape no-overlap boundaries verified. |
| **Spin Wheel Display** | `flutter test test/spin_wheel_display_test.dart` | **6 / 6 PASSED** | 320x568, 360x800, 430x932, landscape stakes hit targets, Top-1 banner 4s + 420ms fade exit verified. |
| **Admin Panel Build** | `cd hellochat_admin && npm run build` | **PASSED (2.13s)** | Vite production build transformed 2492 modules cleanly to `dist/`. |
| **Admin Panel Lint** | `cd hellochat_admin && npm run lint` | **124 problems (baseline)** | Pre-existing unused vars and undefined refs in legacy screens; owned by `@admin_backend`. |
| **Functions Unit Tests** | `cd functions && npm test` | **Emulator Environment required** | Local tests require Firestore emulator (127.0.0.1:8085). |
| **Dart Format Check** | `dart format --output=none --set-exit-if-changed lib test` | **315 files baseline** | Pre-existing formatting discrepancies across repository. Preserving git hygiene while other agents author active slices. |
