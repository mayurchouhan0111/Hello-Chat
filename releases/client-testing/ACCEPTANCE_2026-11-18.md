# Expanded client acceptance checks - 18 November 2026

## Completed

- Full Flutter suite: **860 tests passed** (`scratch/client_acceptance_final_suite.log`). This replaces the earlier incomplete full-suite result.
- New empty-seat widget matrix: **400 cases** across all 20 catalog themes, capacities 8/9/12/13/16, YouTube on/off, widths 320/393dp and text scale 2.0. Actual rendered grid widgets are checked for seat counts and Flutter exceptions. This exposed large-text label overflow in YouTube mode. Seat rows now allow scaled text height, and empty-seat labels remain single-line with ellipsis.
- Repaired a stalled controller timing test by separating it from asynchronous asset/codec preparation and disposing its controller. Existing asset tests remain in the full suite; a controller timing test alone does not validate every rendered asset.
- Fixed room-session cleanup: the code cleared the displayed room ID before deciding whether to remove its floating overlay. It now records that decision before updating state. A separate regression test inserts a real overlay entry and verifies ending its session removes it; **1 test passed** (`scratch/client_acceptance_overlay_cleanup.log`). The full 860-test suite also passed again after this source fix.
- Firebase emulator: **28 rules checks and 15 function checks passed** (`scratch/client_acceptance_final_emulators.log`). Added owner/admin message-clear authorization, audience/anonymous rejection and preservation of historical messages. Existing concurrency, gift, withdrawal, relationship and block checks also pass. These are isolated emulator checks, not a two-phone UI session.
- Supplied test phone and OTP authenticated successfully through Firebase in a separate session (HTTP 200, existing user). The connected phone's session was preserved. Sanitized results are in `scratch/client_acceptance_test_phone_request.json` and `scratch/client_acceptance_test_phone_result.json`; tokens were not saved.
- Read-only production salary verification passed again: scheduler enabled with Wednesday 06:00 Asia/Dhaka schedule; all three salary callables reject unauthenticated requests. No payout was invoked. Evidence: `scratch/client_acceptance_live_salary_status.log`.
- Full analysis: zero errors; 1,936 warning/info findings remain. Analysis is not warning-clean.

## Acceptance limits

- Client reference images were not supplied. Exact visual matching cannot be signed off from the text specification alone.
- The supplied phone is already registered. This authentication check does not certify new registration, password setup, password-only login or OTP recovery through the native UI. Existing-account credentials were not changed.
- Empty-seat matrix coverage does not certify every occupied/admin/VIP seat, full-screen overlay combination, landscape layout or every physical device.
- Room-clear server authorization is verified; simultaneous two-phone rendering/clearing remains unverified.
- Existing real-phone checks cover basic room restore, not seated-user audio continuity or VIP entry replay suppression.
- Actual scheduled production salary execution must be observed at its scheduled time; configuration and emulator behavior are verified separately.

## Delivered build

The release APK includes both the seat-label and overlay cleanup fixes. Offline release build and APK v2 signature verification passed. The exact delivered APK was installed as an update on the Vivo V2132, preserving app data/session. Final screenshot confirms Lucky Bag and Support remain clear of seat labels; animation-body tapping opens Lucky Bag and Support opens its target page. Minimize/restore returns to the same public room ID. The room was explicitly left afterwards and the phone returned home. Captured process logs have zero fatal/uncaught exception, layout overflow, permission denial, attestation failure or rate-limit matches. Evidence uses `scratch/client_acceptance_device_*` plus `scratch/client_acceptance_release_final_build.log` and `scratch/client_acceptance_release_signature.log`.

File: `HelloChat-client-test-release.apk`, 799,713,764 bytes. SHA-256: `cf4ba12ec304e8757efd895fef72a2db758f7f94b1e2f0db2073b392860d813c`. Ready for client testing subject to the acceptance limits above.
