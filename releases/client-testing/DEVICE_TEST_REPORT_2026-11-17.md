# Release APK phone check — 17 November 2026

Device: connected Vivo V2132, 1080 × 2400 screen. Tested the delivered release APK against the deployed Firebase project using the existing signed-in session.

Latest replacement and expanded acceptance results are in `ACCEPTANCE_2026-11-18.md`. That report supersedes the prior artifact checksum and incomplete full-suite status below.

## Latest instruction: App Check removed

The user explicitly requested removal of App Check. The client initialization, Flutter package and direct native Play Integrity dependency have been removed. All configured Firebase services were checked read-only and already report `UNENFORCED`; no production enforcement settings were changed. Authentication and database authorization remain active. The earlier direct-APK App Check configuration proposal is superseded and its helper was removed.

45 selected regression tests passed and analysis reports zero errors after removal. Earlier App Check findings below refer to the previous APK and are retained only as history.

## Connected-phone follow-up, 18 November 2026

- Installed the rebuilt, signature-verified release as an update on the Vivo V2132. The existing account/session and original first-install date were preserved; package flags exclude `DEBUGGABLE`.
- Home ranking preview cards now display profile images. Captured app-process logs contain no `PERMISSION_DENIED`, app-attestation HTTP 403, fatal/uncaught exception or RenderFlex overflow.
- Firebase Auth can still log `No AppCheckProvider installed` when requesting an optional token after SDK removal. The earlier attestation failures are absent; all configured services report App Check unenforced. This native warning is not a user-visible login test result.
- Room screenshot `scratch/client_verified_room.png` confirms Lucky Bag beside Support, below seat 9. UI bounds give a 22px horizontal gap between Lucky Bag and Support and a 21px vertical gap below seat 9's full semantics bounds. Chat has a wider reserved margin while a bag is active.
- Support opens the Room Support/Weekly Target screen. Tapping the Lucky Bag LIVE badge opens its claim dialog. The first tap test exposed an ignored tap on the SVGA body; the final source adds an opaque hit area covering the existing 68x72dp widget. Claim/purchase was not submitted.
- Emoji picker displays its image grid. Tools lists Spin Wheel and Lucky Draw. Spin Wheel loads live round/history controls and its Rules sheet; no wager was placed.
- Room minimizes to a floating bubble and restores to the same public room ID. This does not certify seated-user audio continuity or VIP entry replay suppression.
- After the touch correction, the same 45 selected regression tests passed and full analysis again reports zero errors (1,935 warning/info findings).
- **Final APK verified on phone:** the touch-fix release built successfully, passed APK v2 signature verification and installed as an update at 00:31 on 18 November. The existing signed-in profile and original 14 November first-install date were retained. Tapping the SVGA body at the previously failing location now opens Lucky Bag; Support opens its target page. Final UI bounds retain the same 22px horizontal and 21px vertical gaps. No claim or purchase was submitted. The final app-process log has zero fatal/uncaught exception, RenderFlex overflow, permission denial, attestation failure or rate-limit matches.
- Final evidence: `scratch/client_final_touch_room.png`, matching room/dialog/Support/profile XML dumps, `scratch/client_final_touch_logcat.log`, `scratch/client_final_tap_build.log`, `scratch/client_final_tap_signature.log`, test and analysis logs with the same `client_final_tap_` prefix. These captures contain account information and remain local.
- Delivered file: `HelloChat-client-test-release.apk`, 799,713,764 bytes. SHA-256: `dbd894ea87c3ebb8d30ad8195bf8a9410e93b9ae05985ab241c3189aeeb5c72e`. Suitable for client testing; full acceptance is not certified.
- Finished by explicitly leaving the test room. Phone is on home; Wi-Fi and mobile data both remain enabled. Final delivery checksum was checked again after the phone test.

Evidence from this follow-up uses the `scratch/client_verified_*` prefix. Full long-message history, fresh login/OTP and every seat/theme/screen-size combination remain outside this single-account smoke test.

## Earlier follow-up fixes and rebuilt APK (superseded layout)

- Home ranking preview cards now query `publicUsers` instead of private account records.
- The Lucky Bag rule passed emulator checks and was deployed to production. Signed-in reads are allowed; client balance writes remain denied. The subsequent phone session no longer logged a Lucky Bag permission error.
- Registered the actual APK signing SHA-256 fingerprint in Firebase. The remaining App Check failure is the Play-only recognition requirement for this directly installed APK. A proposed change to support off-Play APKs while requiring certified-device integrity was rejected by automatic approval review pending explicit user approval. It has NOT been applied; no debug token or attestation bypass was introduced.
- Reproduced Lucky Bag SVGA overlapping Support in `scratch/client_svga_support_before.png`. Moved Lucky Bag into the existing Support/Rocket column above Support, with an 8dp gap. Removed its independent fixed bottom offset. Animation size and lifecycle are unchanged.
- Independent layout assessment identified the conflicting anchors. A separate mechanical scan found no supported-code violations but cannot evaluate Flutter layout geometry; it is not visual proof.
- Validation: 28 database rule checks, 25 ranking/room tests and 44 gift/room regression tests passed. Analysis has zero errors, with existing warnings/info findings remaining.
- Final app release build succeeded (`scratch/client_support_layout_build.log`). The updated handover APK has a verified v2 signature and no Android debuggable flag. Its checksum was regenerated.
- The phone disconnected during the final build. A final screenshot and Support-button tap check on this layout still require reconnection. Reference images remain unavailable.

The observations below describe the earlier APK and remain as review history.

## Observed working

- APK installed successfully as an update. Original first-install date and signed-in account were retained.
- Android package flags do not include DEBUGGABLE.
- Home and profile screens rendered and live rooms loaded.
- A public room opened; logs confirmed Agora token acquisition and successful channel connection.
- Room YouTube playback reached playing state with no player error before the connectivity test.
- Game/tools sheet opened and Spin Wheel displayed live round data, wallet amount and game history controls. No bets were submitted.
- With Wi-Fi and mobile data disabled, Spin Wheel displayed its dimmed reconnecting overlay. Both connection settings were restored afterwards. This verifies the overlay, not a server-side bet rejection or settlement.
- Room minimized to a floating bubble and restored to the same room.
- Emoji picker displayed its image grid and category tabs.
- No FATAL EXCEPTION, Unhandled Exception or RenderFlex overflow message was found in the captured app-process logs.

## Initial findings (history; see latest results above)

1. Home ranking preview listeners query private `users` data and receive PERMISSION_DENIED for dailyDiamondsSent, dailyBeansReceived and totalDiamondsSent. Source: `lib/features/rooms/presentation/screens/home_screen.dart`, the three category-card collection arguments. Full leaderboard screens already use `publicUsers`; the home previews need the corresponding correction and a new APK.
2. The room's `lucky_bags` active subscription receives PERMISSION_DENIED. A signed-in read rule exists in the local modified `firebase/firestore.rules`, but the earlier salary-only deployment did not deploy database rules. Verify/deploy rule parity and retest the listener. Lucky Bag send/claim was not exercised.
3. Firebase Auth logs App Check HTTP 403 / app attestation failed and uses placeholder tokens. The preserved session and room token calls worked, but fresh login and other enforced operations are not certified by this test. Investigate the sideloaded release build's attestation configuration without weakening production protection.
4. The contribution leaderboard rendered its empty state. This alone does not prove missing data or a leaderboard bug; verify the expected period data separately.

## Limits

This is a smoke test, not full acceptance. Existing account had no VIP entry animation to exercise, so minimize/restore does not certify VIP replay suppression, seat preservation for a seated user or uninterrupted audio. No OTP was sent, credentials changed, messages sent/cleared, gifts purchased, withdrawals requested or bets placed. Only one device/account was available, so two-client clear messages and owner/admin permission checks were not performed. All seat-count/theme combinations, large text/small screens, Lucky Draw and the full animation suite remain unverified. Client reference images are still absent.

Wi-Fi and mobile data were restored, and the test room was explicitly left. The phone was left on the contribution leaderboard. No application code, APK or production configuration was changed during this check.

Evidence: screenshots and UI dumps under `scratch/client_device_*`; runtime log: `scratch/client_device_final_logcat.log`. Raw evidence stays local because screenshots/logs can contain account information.

Initial decision: suitable for continued client testing; not fully signed off as issue-free. The original permission failures required correction and retesting; use the latest results above for their current status.
