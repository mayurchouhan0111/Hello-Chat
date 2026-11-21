# Salary deployment verification — 17 November 2026

Firebase project: `hellochat-e8965`, region: `us-central1`.

Firebase CLI reported successful deployment of:

- `distributeRoomSupportRewards`
- `processRoomSupportSalary`
- `retryFailedSalaryPayout` (new callable)
- `cleanupCompletedRoomSupportPartners`

The salary deployment was limited to these four functions. A later follow-up deployed the tested Firestore rules including signed-in Lucky Bag reads; its 28 emulator rules checks passed. No account data or balance migrations were deployed.

Read-only production verification:

- Scheduler: `firebase-schedule-distributeRoomSupportRewards-us-central1`, ENABLED.
- Schedule: `0 6 * * 3`, timezone `Asia/Dhaka`.
- Next scheduled run observed: Wednesday 18 November 2026 at 06:00 Bangladesh / 05:30 India.
- `weeks.distributionStatus` has the required ascending collection-group index.
- All three salary callables returned HTTP 401 / `UNAUTHENTICATED` to unauthenticated test requests.
- No live payout was invoked during these checks. Successful authorized financial behavior was covered by the prior local emulator tests; the next scheduled production payout has not yet been observed.

Local evidence: `scratch/client_salary_deploy.log`, `scratch/client_live_functions_after.json`, `scratch/client_live_indexes.json`, and `scratch/client_live_deployment_verification.json`. Read-only verification can be repeated with `node scripts/verify_client_salary_deployment.cjs` using the Firebase CLI's signed-in account.

Follow-up: App Check was removed from the client at the user's request. A read-only service check confirmed all five configured Firebase services already use `UNENFORCED`; no enforcement settings were changed. The connected Vivo phone was used for release-mode testing. See `DEVICE_TEST_REPORT_2026-11-17.md` for current results and acceptance limits. Reference images are still unavailable and full acceptance is not marked passed.
