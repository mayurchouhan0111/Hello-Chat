# Agency ID Migration Proposal (Read-Only)

**Generated**: 2026-10-28  
**Project**: `hellochat-e8965`  
**Source**: read-only audit snapshot from `docs/HIERARCHY_MIGRATION_AUDIT.md` and `hc_tier_diff.json`  
**Status**: proposal only. No Firestore writes, no deploy, no push.

## Canonical rule

`users.agencyId` must be the document ID of an existing `agencies/{id}` document. A user UID is not a valid value. The application now fails closed when it cannot resolve a real agency document.

## Invalid records (8)

| # | User document | Name | Current role | Current `agencyId` | Why invalid | Client decision needed |
|---|---|---|---|---|---|---|
| 1 | `users/2jp08v1H2eq7lD44KQN4` | Host_Rose | `agency` | `PeXwnBhFYuw0StePOH3K` | No agency document exists | Create/recover `agencies/PeXwn...` and set its owner, or clear this link and re-provision the agency account |
| 2 | `users/2wbYCt2G9KjAsjMD178h` | Host_Aria | `user` | `PeXwnBhFYuw0StePOH3K` | No agency document exists | Map to an existing agency document, or clear the link |
| 3 | `users/64AKZHrbpvcuHhoAB4bz` | Host_Leo | `user` | `PeXwnBhFYuw0StePOH3K` | No agency document exists | Map to an existing agency document, or clear the link |
| 4 | `users/KjtUiJyYLF0m0HIH7ADt` | Host_Rose | `user` | `PeXwnBhFYuw0StePOH3K` | No agency document exists | Map to an existing agency document, or clear the link |
| 5 | `users/7onb5B5ZdbMbskb9yMYO8avvffl2` | Panel Host Two | `host` | `lnmsVutlHiO7GDTkRmhRPvs5Y8J2` | No agency document exists; value equals the agency user's UID | Create `agencies/lnms...` owned by `users/lnms...`, or clear the host link and demote/reassign |
| 6 | `users/HfJJhQau7XfdrFXyhtjpCkyRKTw2` | Panel Host | `host` | `lnmsVutlHiO7GDTkRmhRPvs5Y8J2` | No agency document exists; value equals the agency user's UID | Create `agencies/lnms...` owned by `users/lnms...`, or clear the host link and demote/reassign |
| 7 | `users/lnmsVutlHiO7GDTkRmhRPvs5Y8J2` | Agency Lead | `agency` | `lnmsVutlHiO7GDTkRmhRPvs5Y8J2` | Self-referencing UID; no agency document exists | Decide whether to create an agency document with `ownerUid = lnms...`, or revoke the agency role and clear the link |
| 8 | `users/lDLp5QDDbXRzfT14qEAr4SauR0G3` | NAZMUL | `admin` | `pc6mVRnBCVOTV9nM5J7FErJ5WZc2` | Value is a user UID (`REX`), not an agency document | Clear the link, or create an agency document for REX and replace the value with its document ID |

## Valid links (do not change)

| User document | Current `agencyId` | Agency owner |
|---|---|---|
| `users/HgrLl9ubSmcZ0LdWi05MS0jHGvu1` | `VO4m5hbOpMwLc6PDF1bn` | `HgrLl9ubSmcZ0LdWi05MS0jHGvu1` |
| `users/8xS6BOlqjhMWuN9v7lxqoVulqan2` | `pUOzQAMTYQlvrTsxCVlC` | `8xS6BOlqjhMWuN9v7lxqoVulqan2` |
| `users/wTFYRh1bCUWseZWR4SqrvHyHO8f2` | `pUOzQAMTYQlvrTsxCVlC` | `8xS6BOlqjhMWuN9v7lxqoVulqan2` |

## Other legacy record to review (not in the 8)

- `users/Inoz77w9rRgfCH6F0bt0UxoL98j2` has role `agency`, no `agencyId`, and no owned agency document. The new code fails closed, so this account cannot list hosts until the client assigns or provisions an agency document.

## Proposed execution (after client approval only)

1. For each record, choose one: **map to existing agency document**, **create the missing agency document**, or **clear `agencyId`**.
2. If creating an agency document, set `ownerUid` to the intended owner and keep the document ID exactly equal to the value chosen for `users.agencyId`.
3. Re-run the read-only audit after the client's decision.
4. Apply the approved writes with a one-off admin script; never from the client SDK.
5. Re-run the agency rules tests and the hierarchy e2e suite.

## Explicit non-actions

- No records were changed.
- No invalid links were cleaned.
- No legacy accounts were demoted or reassigned.
- No production rules, functions, or hosting were deployed.
