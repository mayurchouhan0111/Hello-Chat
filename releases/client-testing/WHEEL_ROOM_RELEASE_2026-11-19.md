# Wheel and room UI client test release

## Artifact

- APK: `HelloChat-wheel-room-v1.0.0-build3.apk`
- Version: `1.0.0` (`versionCode 3`)
- SHA-256: `3A852105139E2CB99E288399F8A068D82EF437A4F74D68CC1FBDB7C6E46BC260`
- Signing: existing Android debug/test signing key; this artifact is intended for direct device/client testing, not Play Store upload.

## Production deployment

- Firebase project: `hellochat-e8965`
- `playSpinWheel`: updated and active
- `settleSpinWheelRound`: updated and active
- `hydrateLuckySpinLeader`: created and active
- Required `daily_players` and `transactions` indexes: ready
- Production daily leader data includes `totalWins`, `name`, and `avatar`.

## Physical-device verification

- Device: Vivo V2132 (`1374223603000CJ`)
- Upgrade install succeeded while preserving the signed-in session and application data.
- Installed package reports version `1.0.0` / build `3`.
- Room-wide Top Winner banner displayed profile, username, game identity, and total wins.
- Spin Wheel opened from the room game panel.
- All four responsive bet selectors displayed and selected correctly: 100, 1,000, 10,000, and 100,000 Diamonds.
- Selection was returned to 100 Diamonds; no wager was placed during verification.
- A live round completed selection -> spinning -> next-round transition.
- Runtime logs showed the canonical result fetch and the synchronized 4.5-second spin animation.
- No RenderFlex overflow, missing audio asset, Flutter platform exception, or fatal crash was observed.
- Android logged one self-corrected native MediaPlayer state warning; the game continued into the next round normally.

## Automated verification

- Flutter tests: 871 passed.
- Firestore emulator spin-winner tests: 2 passed.
- Flutter analyzer: zero errors (pre-existing warnings/info remain).
