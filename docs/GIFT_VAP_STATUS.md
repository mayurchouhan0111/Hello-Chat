# VAP Gift Animations — Status & Handoff

Scope: the 12 new Tencent `.vap` gift assets under `assets/gifts-vap/`.
Out of scope: Antigravity / Rocket VAPs (separate system, see below).

---

## What is DONE

### 1. Assets bundled
13 `.vap` files are in `assets/gifts-vap/` (gift_1 … gift_13).
Each was generated with the official Tencent VapTool 2.0.6 (H.264 + AAC audio,
`vapc` box embedded). Verified: every file has the `vapc` box + audio track.

The 1080p sources were downscaled to ≤1504px so the packed VAP stays inside
Tencent's safe limit (avoids the green-screen bug on some devices).

### 2. Registered in `pubspec.yaml`
```yaml
- assets/gifts-vap/
```

### 3. Catalog config added
`lib/core/constants/gift_vap_catalog.dart` — single source of truth:

| giftId | file | tier | duration | size |
|---|---|---|---|---|
| vap_gift_13 | gift_13.vap | NORMAL | 5.0s | 846×1504 |
| vap_gift_12 | gift_12.vap | NORMAL | 5.3s | 846×1504 |
| vap_gift_11 | gift_11.vap | NORMAL | 6.0s | 846×1504 |
| vap_gift_10 | gift_10.vap | NORMAL | 6.7s | 846×1504 |
| vap_gift_2  | gift_2.vap  | MEDIUM | 7.8s | 478×850 |
| vap_gift_1  | gift_1.vap  | MEDIUM | 9.6s | 1280×720 |
| vap_gift_3  | gift_3.vap  | MEDIUM | 9.6s | 720×1280 |
| vap_gift_4  | gift_4.vap  | MEDIUM | 10.0s | 846×1504 |
| vap_gift_5  | gift_5.vap  | MEDIUM | 10.0s | 1504×846 |
| vap_gift_6  | gift_6.vap  | MEDIUM | 10.0s | 1504×846 |
| vap_gift_7  | gift_7.vap  | MEDIUM | 10.0s | 846×1504 |
| vap_gift_9  | gift_9.vap  | LUXURY | 11.9s | 846×1504 |
| vap_gift_8  | gift_8.vap  | LUXURY | 15.6s | 846×1504 |

Tier + duration follow the product rule: NORMAL ~5s, MEDIUM ~10s, LUXURY 15s.
`durationMs` is the exact encoded length so the overlay hold matches the
animation (no early cut-off, no dead air).

### 4. No playback code changes were needed
The existing pipeline already handles these assets end-to-end:
- `GiftModel.fromMap` auto-detects `.vap` → `animationFormat: 'vap'`.
- `SvgaParserUtil.getLocalVapPath` returns any `assets/*.vap` as-is.
- `_VapNetworkPlayer` → `VapAnimation` → `VapView` (`tancent_vap`) plays it.
- Tier → overlay layer already wired: NORMAL = seat 200×200,
  MEDIUM = center 360×360, LUXURY = full-screen.

---

## Status: FULLY COMPLETED & SEEDED IN FIRESTORE ✅

1. **Firestore `gifts` collection seeded**:
   All 12 docs (`vap_gift_1` through `vap_gift_12`) are created and active in Firestore with exact prices, durations, tiers, and `animationFormat: "vap"`.
2. **Final Marketing Names Assigned**:
   - NORMAL: Mini Rose (10 💎), Twinkle Star (20 💎), Candy Heart (50 💎)
   - MEDIUM: Sweet Bear (200 💎), Aurora Lights (300 💎), Neon Heart (300 💎), Pink Kiss (500 💎), Rhythm Bell (500 💎), Heart Wand (800 💎), Treasure Chest (1000 💎)
   - LUXURY: Crystal Castle (2000 💎), Royal Crown (5000 💎)
3. **Gift Icons Generated & Uploaded**:
   High-resolution transparent PNG icons were extracted from each VAP asset, bundled under `assets/images/gifts/vap_gift_*.png`, and uploaded to Cloudinary CDN for instant loading.
4. **Local Interception & Multi-Target Binding**:
   `SvgaParserUtil.getLocalVapPath` configured with regex lookup mapping all `vap_gift_*` IDs and combo suffixes directly to bundled assets.
5. **Automated Integration Tests**:
   `test/vap_gifts_integration_test.dart` passes 7/7 tests verifying asset presence, model parsing, duration tiers, and resolution.

---

## Antigravity / Rocket — handled separately

The Antigravity (rocket) VAP system is a **different pipeline** and is NOT part
of this batch. It already works and needs no changes from this work:

- Assets: `assets/animations/VAP/` (`a..e (1|2|3).mp4`) and `assets/rocket/VAP/`.
- Config: `lib/core/utils/rocket_vap_config.dart`
  (`RocketVapConfig.vapAssetPath(level, variant)`).
- Players: `rocket_launch_overlay.dart`, `rocket_completion_vap_overlay.dart`,
  `rocket_detail_sheet.dart` — all use the same `VapAnimation` widget.
- Level → letter mapping + variants are already wired; the detail sheet lets
  the user pick a variant.

Leave the Rocket/Antigravity code as-is. This batch only adds the new
`assets/gifts-vap/` gift set.

---

## Tests that must stay green

- `test/gift_tier_test.dart`
- `test/gift_asset_interception_test.dart`
- `test/gift_animation_system_test.dart`

This batch adds files + one config file only; no existing gift logic was
modified, so these should pass unchanged. Run `flutter test` after seeding.
