# Hello Chat — client test APK

Share `HelloChat-client-test-release.apk` with the client for release-mode testing.

Latest replacement, 18 November: includes the large-text seat-label fix and room-overlay cleanup correction. Release build/signature and final connected-phone room smoke check passed. The current checksum is in `SHA256SUMS.txt`. Expanded results and remaining acceptance limits: `ACCEPTANCE_2026-11-18.md`.

- Package: `com.example.hellochat`
- Version: `1.0.0` (build `1`)
- Android: 7.0/API 24 or newer; ARM64, ARMv7 and x86-64
- File size: 799,713,764 bytes (approximately 800 MB / 763 MiB)
- Android debuggable flag: absent
- Signature: APK v2 verified; existing Android Debug signing identity retained for testing
- SHA-256 checksum: see `SHA256SUMS.txt`

Latest automated validation: the complete Flutter suite passed **860 tests**, including 400 empty-seat layout cases. A separate actual-overlay cleanup regression test also passed. Firebase emulator checks passed **28 rules and 15 function tests**. Earlier salary checks passed 11 behavioral and 6 existing regression cases. Flutter analysis reports zero errors; warnings and style findings remain. See `ACCEPTANCE_2026-11-18.md` for coverage and limits.

The four backend salary functions were deployed to Firebase project `hellochat-e8965` on 17 November 2026. The live scheduler is enabled for Wednesday 06:00 Asia/Dhaka, the required database index is present, and all three salary callables reject unauthenticated requests. No live payout was triggered as a test. See `DEPLOYMENT_VERIFICATION.md`.

Follow-up phone testing on 17 November used a connected Vivo V2132. Install/update, preserved session, home/profile, room connection, YouTube, Spin Wheel loading, reconnecting overlay, basic minimize/restore and emoji picker were checked.

This replacement fixes home ranking preview queries. The Lucky Bag SVGA sits beside Support, below the seats, with an 8dp gap; chat reserves room for the active bag. The tested Lucky Bag read rule was deployed. Follow-up checks passed: 28 database rules checks, 25 ranking/room tests and 45 selected regression tests.

Final verification on 18 November: release build and APK v2 signature passed. The exact delivered APK was installed on the Vivo V2132 without clearing the existing account. The room screenshot confirms no Lucky Bag/Support/seat 9 overlap. Both the animation-body tap and Support navigation work. Final app-process logs contain no fatal/uncaught errors, layout overflow, permission denial, attestation failure or rate-limit matches. The final source has zero analyzer errors; existing warnings remain.

App Check initialization, Flutter package and direct native Play Integrity dependency were removed at the user's request. Read-only checks show all five configured Firebase services already have App Check unenforced; no enforcement setting was changed. Authentication and database authorization remain active. See `DEVICE_TEST_REPORT_2026-11-17.md` for the connected-phone results and remaining acceptance limits. This is a client-testing release, not certification that every edge case is covered.

If Android reports a signing conflict, preserve the installed app and its data until its signing identity is checked. Do not ask the client to uninstall an existing app as the first fix.
