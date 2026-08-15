---
name: flutter-architecture
description: >-
  Expert rules for the Hello Chat Flutter client (Flutter 3.x, Dart 3.x). Enforces
  clean widget architecture, Stack/index layering, Riverpod 2.x state management,
  and SVGA/VAP/Lottie animation performance. Use when building or modifying
  screens, widgets, providers, animation layers (gifts, rocket event, effects), or
  any Flutter UI in lib/. Don't use for pure backend/Cloud Functions work.
---

# Flutter Architecture & Expert Rules (Hello Chat)

Hard rules for the Flutter client in `lib/`. Follow these before writing or
reviewing any widget, provider, or animation code.

## Use this skill when

- Building or refactoring screens/widgets in `lib/features/**` or `lib/core/widgets/**`
- Creating or editing Riverpod providers (`lib/providers/**`, `lib/core/providers/**`)
- Layering animations, overlays, gift effects, rocket event UI, or VAP/SVGA players
- Measuring or optimizing frame rate, rebuilds, or jank
- Reviewing UI architecture against the existing patterns

## Use this skill when (folder map)

| Path | Responsibility | Rules apply |
|------|----------------|-------------|
| `lib/features/**` | Feature screens & widgets (chats, rooms, diamonds, wallet, events, games, vip, admin) | full |
| `lib/providers/**` | Riverpod 2 providers for app state | full |
| `lib/core/widgets/**` | Shared widgets (badges, tags, avatars) | full |
| `lib/core/theme/**` | Theme, colors, text styles | theming |
| `lib/services/**` | Service layer (chat, gifts, rooms, voice, wallets) | state mgmt |
| `lib/utils/**` | Pure helpers (level, number formatting) | none (keep pure) |

## 1. Riverpod 2.x State Management (MANDATORY)

- App state belongs in Riverpod providers under `lib/providers/**` and
  `lib/core/providers/**`. Do not create a new global `InheritedWidget`,
  `ScopedModel`, or hand-rolled singleton `ChangeNotifier` for app state.
- Use `flutter_riverpod` (package is pinned at `^2.5.1`). Prefer
  `NotifierProvider`/`AsyncNotifierProvider` (Riverpod 2 API) over the legacy
  `StateNotifierProvider`/`ChangeNotifierProvider` for new code.
- With `riverpod_annotation` + `riverpod_generator` (present in pubspec), prefer
  code-generated providers (`@riverpod`/`@NotifierProvider`) to keep providers
  consistent and type-safe. Run codegen (`dart run build_runner build -d`) after
  adding annotated providers.
- Keep providers coarse-grained and session-scoped: user (`user_provider.dart`),
  wallet (`wallet_provider.dart`), and one per feature (chats, rooms, diamonds,
  leaderboards, VIP, etc.). Do not create one god-provider per screen.
- Read state with `ref.watch(...)` in build; call `ref.read(...)` only in event
  handlers/callbacks. Never `ref.read` during build.
- Refresh/keep-alive: mark providers that must survive navigation
  (`ref.keepAlive()` or `family` + `autoDispose`) deliberately; default to
  `autoDispose` for screen-local state to avoid leaking memory.

## 2. Widget Tree & Rendering Layers

- Composition over inheritance. Prefer small stateless widgets and `const`
  constructors everywhere possible. Every `const` saved avoids a rebuild pass.
- Keep build methods pure and fast: no network calls, `await`, or heavy math in
  `build()`. Offload to providers/services; the UI only reflects state.
- Rendering layers:
  - Use `RepaintBoundary` around heavy/animating subtrees (SVGA/VAP players,
    custom painters, large lists with effects) so a repaint doesn't cascade to
    sibling layers.
  - Use `const` `ColorFiltered`/opacity animations sparingly; they create
    intermediate layers. Prefer `AnimatedOpacity`/`AnimatedContainer` over manual
    `AnimationController` when simple.
  - Avoid `Transform`/`FractionalTranslation` on full-screen elements every frame;
    wrap in `RepaintBoundary` and only animate the leaf.
- Keys: use `ValueKey`/`ObjectKey` only where widget identity matters (reorder,
  stateful lists, per-item controllers). Do not sprinkle keys "just in case".

## 3. Stack / Overlay / Z-Indexing (gift & effect layers)

Gift effects, rocket event UI, voice rooms, and badges rely on layered overlays.
Rules:

- For a Stack of layered UI:
  - The **lowest** child in the children list renders **behind**; last child is
    topmost (highest z-index). Order children bottom→top explicitly.
  - Wrap overlay layers that must not trigger layout of the whole page in
    `StackFit.expand` or position them with `Positioned` only when they are true
    overlays; otherwise use `Align`/`Padding` to avoid `Positioned`-on-everything.
  - Keep the base content as the first child and transient effect layers last so
    z-order is: content → animated background → gift/effect layer → touch overlay.
- Use `IndexedStack` (not `Stack`) when switching between mutually exclusive full
  screens/tabs to preserve each child's state and avoid rebuild flashes.
- Use `Overlay`/`OverlayEntry` for true app-level overlays (toasts, floating
  gift panels) that must float above navigation; close them on
  `OverlayEntry.remove()` and never leak entries after `dispose`.
- Tap-through: an overlay that must not intercept touches should wrap content in
  `IgnorePointer`; use `AbsorbPointer` only when it must block interaction.
- For animated badge groups (`widgets/user_tag_badge_group.dart`,
  `widgets/uniform_tag_badge.dart`), keep badge order stable and lay out with a
  single `Wrap`/`Row` rather than nested Stacks; animate opacity/scale only on the
  entering/leaving badge, not the whole group.

## 4. SVGA / VAP / Lottie Animation Performance (rocket, gifts, effects)

The app ships heavy animation assets (`assets/rocket/`, `assets/svga/`,
`assets/animations/VAP/`, `assets/animations/lottie/`). Hard rules:

- **One player per visible animation.** Do not rebuild the
  `SVGAAnimationController`/VAP widget or the `Lottie` widget on every frame or
  every provider change. Cache the widget and only re-attach when the asset
  changes.
- Keep controllers alive across the animation's lifetime. Dispose **exactly
  once**, in `dispose()`, after `removeListener`. Double-dispose of SVGA/VAP
  controllers throws — guard with a `_disposed` flag.
- Prefer playing a compressed/optimized SVGA (the `scratch/optimize_*.py` and
  `scripts/` pipeline produces these) over raw large assets. Reference the
  optimized variants in `assets/rocket/`, not duplicate copies in the repo root.
- Loop parameters: use `SVGARepeatMode`/`repeatCount` intentionally; infinite
  loops (e.g. `RepeatMode.Loop`) only on short, cheap effects. Long rocket
  animations should play once per event, not loop.
- Wrap each player in `RepaintBoundary` and give it a fixed size (don't size a
  full-screen player with `MediaQuery` in build).
- Pause animations when the screen is not visible (e.g. on `RouteAware`/tab
  switch) to save GPU/CPU. Do not keep VAP/SVGA players animating in backgrounded
  routes.
- If a custom painter drives a progress/level animation (`utils/level_utils.dart`),
  compute values in `compute()`/precompute, never do it in `paint()`.
- Keep `tancent_vap` and `svgaplayer_flutter` separate code paths — do not mix
  their lifecycle APIs; wrap each in its own widget so controllers are typed.

## 5. Theming & Styling

- Pull colors, gradients, text styles from `lib/core/theme/**`. Do not hardcode
  hex colors or font sizes inline in feature widgets.
- Use `Theme.of(context).textTheme` / extension getters; define new style
  variants in the theme, not per-screen.
- Respect dark mode: use theme-aware colors; avoid hardcoded `Colors.white/black`
  unless intentional.

## 6. Services & Async (data layer)

- `lib/services/**` encapsulate Firebase/network. Widgets must not call
  `FirebaseFirestore`/`firebase_auth` directly — go through a provider or service.
- Errors: surface user-friendly messages; never expose raw Firebase error strings
  in UI. Log the technical detail server-side or to debug console only.
- Loading/empty/error states are required on every async screen (skeleton, empty
  state, retry button). Do not leave a screen blank while awaiting.
- Use `StreamProvider`/`AsyncNotifier` for Firestore real-time data and expose
  `AsyncValue.when(...)` (loading/data/error) instead of manual booleans.

## 7. Testing & Verification

- Widget tests live in `test/` (`widget_test.dart`, `test/svga_test.dart`).
- For any widget/UI change, run:
  - `flutter analyze`
  - `flutter test`
- For animation/layout changes, verify no jank on a real device and no leaked
  SVGA/VAP controllers (run `flutter run` with devtools, check memory grows only
  with genuine state).

## Do not use this skill when

- Writing Cloud Functions, Firestore rules, or admin (React) code → use
  `firebase-transactions-security` or `react-admin-dashboard`.
- Writing pure Dart helpers (`lib/utils/**`) → keep them framework-free.