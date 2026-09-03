# OPENCODE AUTOMATED TESTING SPECIFICATION
## Feature: Profile Detail Screen SVGA & Full-Width Layout Render Verification Suite

---

### INSTRUCTIONS FOR OPENCODE AGENT

You are an automated mobile UI testing engineer. Execute the following testing specification on the connected device/emulator to verify that `ProfileDetailScreen` renders SVGA animations live and scales background graphics edge-to-edge without side margins.

---

## 1. SVGA ANIMATED DECORATION RENDER TEST

### Test Case 1.1: Live SVGA Player Mount
- **Action**: Navigate to `ProfileDetailScreen` for a user with SVIP or VIP tier (`staticDecor: false`).
- **Assertion**:
  1. Inspect widget tree for `UserProfileCard`.
  2. Verify `SvgaPlayer` is mounted (`key: ValueKey('crown_...')` or `key: ValueKey('strip_...')`).
  3. Verify `staticDecor` is `false` and `Image.asset` fallback is NOT used.
  4. Ensure SVGA animation frames decode and render at >= 24 FPS.

### Test Case 1.2: Crown & Wings Overlay Alignment
- **Action**: Inspect the top header area of `UserProfileCard`.
- **Assertion**: SVIP/VIP crown wings overlay properly above the user avatar without clipping.

---

## 2. FULL-WIDTH COVERAGE & LAYOUT STRETCH TEST

### Test Case 2.1: Edge-to-Edge Container Stretch
- **Action**: Inspect layout constraints of `UserProfileCard` inside `ProfileDetailScreen`.
- **Assertion**:
  1. Container width equals `MediaQuery.of(context).size.width` (`double.infinity`).
  2. Left and right padding/margin around `UserProfileCard` is `0.0`.
  3. Zero dark-green or black side bars appear on screen borders.

---

## 3. IDENTITY, BADGES & DEDICATED TOP LIST NAVIGATION TEST

### Test Case 3.1: Profile Identity & Badges Render
- **Action**: Verify user display name, helloId, level badge, VIP badge, and Reseller/Family badges on `ProfileDetailScreen`.
- **Assertion**: All user badges render cleanly in `_buildIdentity` row without text overflow.

### Test Case 3.2: Dedicated Top List Navigation
- **Action**: Tap the **Top List** contribution card (`_buildContributionCard`).
- **Assertion**:
  1. Navigates to `UserContributionRankingScreen` (`targetUid: userData.uid`).
  2. Displays isolated top senders for that specific target UID.

---

## 4. COVER PHOTO & RECENT VISITORS OVERLAY TEST

### Test Case 4.1: Cover Photo Stretch
- **Action**: Inspect `_buildCoverPhoto` height and width.
- **Assertion**: Cover image scales cleanly with `BoxFit.cover`, filling 260px height.

### Test Case 4.2: Recent Visitors Counter
- **Action**: Check bottom right visitor badge on cover photo.
- **Assertion**: Displays recent visitor avatar circles and visitor count cleanly.
