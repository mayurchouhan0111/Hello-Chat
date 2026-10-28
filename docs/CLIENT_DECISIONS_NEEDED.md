# Client Decisions Needed Before Production Rollout

Status: **NOT EXECUTED - NO PRODUCTION DATA HAS BEEN CHANGED**
Source: read-only audit of `hellochat-e8965` on 2026-10-28
Audit baseline: old `2ebe5c4`, newer `1011b8f`; 118 users, 2 agencies,
1 branch.

The deploy changes role resolution and agency commission handling. The items
below are data inconsistencies that this branch deliberately does **not**
repair. Each needs an Owner decision before UAT or rollout is scored complete.

## D1. 101 unmarked accounts become Normal Users

### Finding

The new resolver reads `role`, then tags, then `isAgencyOwner`, then
`isHost`. Accounts with none of those signals are Normal Users. The audit found
101 users with no explicit role/host signal; all 101 are currently shown as
Hosts and become `user` in the new model.

- Before: `user 0`, `host 104`, `agency 3`, `admin 6`, `superadmin 2`, `owner 3`.
- After: `user 101`, `host 3`, `agency 3`, `admin 6`, `superadmin 2`, `owner 3`.
- All 101 changes are `host -> user`; no other tier changed.

The 3 remaining explicit Hosts are:

| Hello ID | UID | Name | Agency link |
|---|---|---|---|
| `4926026367` | `4zbctX7hzLNBfeHsU7JU5prCrQt1` | `123456` | none |
| `8039546587` | `7onb5B5ZdbMbskb9yMYO8avvffl2` | `Panel Host Two` | `lnmsVutlHiO7GDTkRmhRPvs5Y8J2` (missing) |
| `4792863199` | `HfJJhQau7XfdrFXyhtjpCkyRKTw2` | `Panel Host` | `lnms...` (missing) |

No production account currently has BOTH an Agency role AND a valid agency document. `HgrLl9ubSmcZ0LdWi05MS0jHGvu1` is an Admin who owns `VO4...`; `8xS6BOlqjhMWuN9v7lxqoVulqan2` is a Normal User who owns `pUOz...`. The Admin path can use the admin panel; the Normal User owner cannot use the Agency/commission role path until this is decided.`n`nHigh-impact example inside the 101: `8xS6BOlqjhMWuN9v7lxqoVulqan2`
(Hello `6114943995`, name `hello`) owns agency
`pUOzQAMTYQlvrTsxCVlC`, but has `role: null`, no tags, and
`isAgencyOwner: false`. It becomes a Normal User while still being the agency
document owner. Its agency wallet will not be reachable through the normal
Agency/Admin role path.

### Options

1. **Leave all 101 as Normal Users** (recommended default). Restore named
   accounts individually only after the Owner confirms they are real Hosts.
2. Restore a named list of accounts to explicit Host/Agency, including
   `8xS6...` if that account must operate the `hello chat` agency.
3. Restore all 101 to Host. Not recommended: it recreates the unmarked-host
   problem and makes the roster misleading.

### Recommendation

Leave the 101 unchanged for rollout, but decide `8xS6...` separately. If
`pUOz...` is an active agency, either restore `8xS6...` to Agency (and set
`isAgencyOwner: true`) or name the account that should operate it. Do not
silently promote all 101.

### Risk if deferred

- The Host roster will show 3, not 104. This is a client-visible change.
- `8xS6...` may be unable to use the agency wallet/portal.
- Named real Hosts who lost access will file support tickets.

## D2. Eight invalid `agencyId` links

### Finding

These user documents point at a missing document or at a different user's UID,
not at a valid agency document:

| UID | Hello ID | Name | Current `agencyId` | Problem |
|---|---|---|---|---|
| `2jp08v1H2eq7lD44KQN4` | `4830239926` | `Host_Rose` | `PeXwnBhFYuw0StePOH3K` | Agency document does not exist. Role/tag still says Agency. |
| `2wbYCt2G9KjAsjMD178h` | `3058297519` | `Host_Aria` | `PeXwn...` | Missing agency document. |
| `64AKZHrbpvcuHhoAB4bz` | `3997594033` | `Host_Leo` | `PeXwn...` | Missing agency document. |
| `KjtUiJyYLF0m0HIH7ADt` | `2661693722` | `Host_Rose` | `PeXwn...` | Missing agency document. |
| `7onb5B5ZdbMbskb9yMYO8avvffl2` | `8039546587` | `Panel Host Two` | `lnmsVutlHiO7GDTkRmhRPvs5Y8J2` | Missing agency document. |
| `HfJJhQau7XfdrFXyhtjpCkyRKTw2` | `4792863199` | `Panel Host` | `lnms...` | Missing agency document. |
| `lnmsVutlHiO7GDTkRmhRPvs5Y8J2` | `3706067376` | `Agency Lead` | `lnms...` (self) | User points at its own UID; no agency document exists. |
| `lDLp5QDDbXRzfT14qEAr4SauR0G3` | `3485703221` | `NAZMUL` | `pc6mVRnBCVOTV9nM5J7FErJ5WZc2` | Points at a user UID, not an agency document. User is an Admin. |

The commission code tolerates a missing agency document by falling back to
legacy user balances. It does not repair the links.

### Options

1. **Leave the links untouched** (recommended until the Owner supplies the
   correct agency mapping). Missing links fail closed.
2. Clear the invalid `agencyId` only after confirmation. This changes user
   records and must be a reviewed, audited write.
3. Re-link to the correct agency documents. Requires an authoritative mapping
   from the client; do not guess.

### Recommendation

Do not repair during this release. Obtain the correct mapping for the four
`PeXwn...` users and the two `lnms...` Hosts. Decide whether `NAZMUL` should
have no `agencyId` (Admin) or a real agency. Leave `Agency Lead` unlinked until
a real agency document exists. UAT should record these as known invalid links,
not as pass/fail failures.

### Risk if deferred

Those users/agencies cannot use agency-scoped features; they may see legacy
balances only. `Agency Lead` is an Agency with no usable agency document.

## D3. Missing hierarchy fields and ambiguous admin accounts

### Finding

- The two production agency documents (`VO4m5hbOpMwLc6PDF1bn`,
  `pUOzQAMTYQlvrTsxCVlC`) have no `adminId`, `branchId`, or `superAdminId`
  fields. The new creation flow writes these fields; the old records do not
  have them.
- `qfoqaYFOLIMsPw4awQmsc8G0tRW2` (Hello `8996148082`, name `v`) carries the
  `SuperAdmin` tag but has no `branchId`.
- `pc6mVRnBCVOTV9nM5J7FErJ5WZc2` (Hello `5621916410`, name `REX`) is an Admin
  with tags `Agency` and `Admin`, `isAgencyOwner: true`, but no `agencyId` and
  no owned agency document. It is also listed in the `pUOz...` host list.
- The branch document names `wTFYRh1bCUWseZWR4SqrvHyHO8f2` (Owner) as its
  `superAdminUid`.

### Options

1. **Leave the records fail-closed** (recommended until the Owner confirms the
   intended hierarchy). Admin/agency scope will be narrow or unavailable.
2. Backfill `adminId`, `branchId`, and `superAdminId` on the two agency
   documents after confirming the correct Admin/Super Admin.
3. Assign `qfoqa...` to a branch and decide whether it is a real Super Admin;
   decide whether `pc6...` owns an agency or should remain an unlinked Admin.

### Recommendation

Do not backfill by guess. Get the Owner's intended hierarchy first. The new
code already fails closed when a parent is missing, so leaving the data
unchanged is safer than inventing links.

### Risk if deferred

Legacy agencies may not appear in branch-scoped admin lists. Unlinked Admin
`pc6...` and Super Admin `qfoqa...` may see fewer management actions than the
client expects.

## D4. Two agency-tagged users without agency documents

### Finding

| UID | Hello ID | Name | Evidence | Problem |
|---|---|---|---|---|
| `pc6mVRnBCVOTV9nM5J7FErJ5WZc2` | `5621916410` | `REX` | tags `Agency`, `Admin`; `isAgencyOwner: true`; `agencyId: null` | No agency document is owned by this UID. |
| `Inoz77w9rRgfCH6F0bt0UxoL98j2` | `7832351125` | `israt` | `role: agency`; `agencyId: null`; no owned agency document | Agency role with no agency record. |

### Options

1. **Leave both as-is until the Owner names their agency** (recommended).
2. Clear the `Agency` tag/`isAgencyOwner`/`role: agency` so the account is a
   truthful Normal User or Admin.
3. Create/link the intended agency document after an approved data request.

### Recommendation

Do not create placeholder agencies. Ask the Owner what these accounts should
own. UAT should confirm the accounts fail closed rather than showing an empty
agency with write access.

### Risk if deferred

These accounts may show an Agency label but have no agency-scoped data or
wallet. Support may confuse this with a bug.

## D5. Hard delete versus soft delete for agencies

### Finding

The current implementation is **soft delete**: `deactivateAgency` marks the
agency `isActive: false`, sets status `deactivated`, records
`deactivatedAt`/`deactivatedBy`, releases linked Hosts, and keeps balances.
There is no agency hard-delete callable in this branch.

### Options

1. **Keep soft delete** (recommended). Balances, audit history, and ledger
   records remain available for reconciliation. Re-activation can restore the
   owner role.
2. Add a separate Owner-only hard-delete flow later. It must archive balances
   and ledger records first and require a second confirmation.

### Recommendation

Keep soft delete. Do not add a hard-delete path in this release. If the client
wants permanent deletion, define a separate retention and audit policy.

### Risk if deferred

Deactivated agency documents remain in Firestore. This is intentional for
audit, but the client should know that "delete" means "deactivate".

## D6. Old `users/{uid}` commission balances

### Finding

The old per-user commission fields (`usdCommissionBalance`,
`pendingWithdrawalBalance`, `totalCommissionEarned`, `totalWithdrawnUSD`,
`totalRechargeGenerated`) still exist and are still spendable. The new code
aggregates them with the agency document and spends the legacy user source
first. It does not migrate or zero them.

### Options

1. **Keep aggregation with legacy-first spending** (recommended). No data
   rewrite, no downtime, old balances remain usable.
2. Migrate legacy balances into the agency document in a one-time, reviewed
   transaction, then zero the user fields. Requires a backup, a dry run, and an
   Owner-approved reconciliation report.
3. Freeze legacy balances only. Users lose access to old funds until an
   operator moves them. Not recommended without a support plan.

### Recommendation

Keep option 1 for this release. Revisit migration only if the Owner wants a
single source of truth per agency. If migration is chosen, do it after this
deploy is stable and with a full reconciliation.

### Risk if deferred

Some users see legacy + agency balances combined; two sources remain. A future
migration will need to handle already-withdrawn legacy balances.

## D7. Confirm the four Admin role codes

### Finding

The UAT plan expects the four Admins to hold exactly one each of `10000`,
`10001`, `10003`, `10005`. The read-only audit confirms the four Admin
accounts but does not expose a verified account-to-code mapping:

| Hello ID | UID | Current role | Agency link |
|---|---|---|---|
| `3607188625` | `HgrLl9ubSmcZ0LdWi05MS0jHGvu1` | Admin | owns `VO4...` |
| `1805742773` | `aRdHp4qLLKdd8qUoVTcgTcpZpKf2` | Admin | none |
| `3485703221` | `lDLp5QDDbXRzfT14qEAr4SauR0G3` | Admin | points at a user UID |
| `100003` | `PhFe53EOGzRxricZKawdA4DARcz2` | Admin | none |

### Decision required

Confirm which Hello ID should hold each expected code. If the actual codes
differ, update the UAT expected values before testing; do not rewrite role codes
to match the document.

## Approval record

The client must respond to each item with one of: **Keep**, **Repair**, or
**Defer**. Repairing production data is a separate change with its own backup,
review, and audit log.

| Item | Decision | Approved by | Date |
|---|---|---|---|
| D1 - 101 unmarked accounts / `8xS6...` | Keep / Repair / Defer | `[FILL]` | `[FILL]` |
| D2 - 8 invalid agency links | Keep / Repair / Defer | `[FILL]` | `[FILL]` |
| D3 - missing hierarchy fields | Keep / Repair / Defer | `[FILL]` | `[FILL]` |
| D4 - two agency-tagged users without agencies | Keep / Repair / Defer | `[FILL]` | `[FILL]` |
| D5 - hard vs soft delete | Keep / Change | `[FILL]` | `[FILL]` |
| D6 - old user commission balances | Keep / Migrate / Freeze | `[FILL]` | `[FILL]` |
| D7 - Admin role-code mapping | Confirm mapping | `[FILL]` | `[FILL]` |

