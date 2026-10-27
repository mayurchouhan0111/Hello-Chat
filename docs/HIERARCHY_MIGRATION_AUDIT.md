# Hello-PMS Hierarchy Migration Audit Report

**Generated**: 2026-10-27T19:31:49.773Z  
**Firebase Project**: `hellochat-e8965`  
**Scan Mode**: Read-Only Exhaustive Scan (0 writes performed)  
**Total Scanned**: 118 Users, 2 Agencies, 1 Branches  

---

## 1. Executive Summary & Counts Table

| Category | Gaps Found | Severity | Action Required |
| :--- | :---: | :---: | :--- |
| Super Admins Missing Branch | 1 | HIGH | Provision branch or re-link |
| Super Admins with Dangling Branch | 0 | HIGH | Re-link to valid branch |
| Admins Missing Super Admin / Branch | 1 | HIGH | Link to branch Super Admin |
| Admins with Dangling Parent / Branch | 0 | HIGH | Repair invalid parent reference |
| Agencies Missing Admin / Branch | 4 | MEDIUM | Assign Admin supervisor |
| Agencies with Dangling Parent / Owner | 0 | HIGH | Repair invalid owner/admin |
| Branches Missing / Dangling Super Admin | 0 | HIGH | Appoint active Super Admin |
| Hosts Missing Agency | 1 | MEDIUM | Recruit via Agency |
| Hosts with Dangling Agency | 8 | MEDIUM | Fix legacy agency doc ID |
| Staff / Agencies Missing Role Code | 0 | CRITICAL | Run Task B Backfill Script |
| Role Codes with Invalid Length | 0 | HIGH | Reallocate valid code |
| Duplicate Role Codes | 0 | CRITICAL | Resolve collisions |

## 2. Super Admins Missing Branch (Total: 1)

* **Document**: [`users/qfoqaYFOLIMsPw4awQmsc8G0tRW2`](file:///users/qfoqaYFOLIMsPw4awQmsc8G0tRW2)
  - **Hello ID**: 8996148082 (v)
  - **Issue**: branchId is missing or null
  - **Proposed Correction**: MANUAL REVIEW REQUIRED: Super Admin has no branch; provision branch via HB-PMS Owner panel.

## 3. Super Admins with Dangling Branch (Total: 0)

_No gaps detected in this category._

## 4. Admins Missing Super Admin Linkage or Branch (Total: 1)

* **Document**: [`users/pc6mVRnBCVOTV9nM5J7FErJ5WZc2`](file:///users/pc6mVRnBCVOTV9nM5J7FErJ5WZc2)
  - **Hello ID**: 5621916410 (REX)
  - **Missing Fields**: superAdminId
  - **Proposed Correction**: Derive superAdminId="wTFYRh1bCUWseZWR4SqrvHyHO8f2" from branch "branch-prod-1".

## 5. Admins with Dangling Parent or Branch (Total: 0)

_No gaps detected in this category._

## 6. Agencies Missing Admin Linkage or Branch (Total: 4)

* **Document**: [`agencies/VO4m5hbOpMwLc6PDF1bn`](file:///agencies/VO4m5hbOpMwLc6PDF1bn)
  - **Name/Owner**: rofikul (Owner UID: `HgrLl9ubSmcZ0LdWi05MS0jHGvu1`)
  - **Missing Fields**: adminId, branchId, superAdminId
  - **Proposed Correction**: MANUAL REVIEW REQUIRED: Assign agency to an active branch Admin via Admin Panel.

* **Document**: [`agencies/pUOzQAMTYQlvrTsxCVlC`](file:///agencies/pUOzQAMTYQlvrTsxCVlC)
  - **Name/Owner**: hello chat  (Owner UID: `8xS6BOlqjhMWuN9v7lxqoVulqan2`)
  - **Missing Fields**: adminId, branchId, superAdminId
  - **Proposed Correction**: MANUAL REVIEW REQUIRED: Assign agency to an active branch Admin via Admin Panel.

* **Document**: [`users/2jp08v1H2eq7lD44KQN4`](file:///users/2jp08v1H2eq7lD44KQN4)
  - **Name/Owner**: Host_Rose (Owner UID: `undefined`)
  - **Missing Fields**: adminId
  - **Proposed Correction**: MANUAL REVIEW REQUIRED

* **Document**: [`users/Inoz77w9rRgfCH6F0bt0UxoL98j2`](file:///users/Inoz77w9rRgfCH6F0bt0UxoL98j2)
  - **Name/Owner**: israt (Owner UID: `undefined`)
  - **Missing Fields**: adminId, agencyId
  - **Proposed Correction**: MANUAL REVIEW REQUIRED

## 7. Agencies with Dangling Parent or Owner (Total: 0)

_No gaps detected in this category._

## 8. Branches Missing or Dangling Super Admin (Total: 0)

_No gaps detected in this category._

## 9. Hosts Missing Agency Linkage (Total: 1)

* **Document**: [`users/4zbctX7hzLNBfeHsU7JU5prCrQt1`](file:///users/4zbctX7hzLNBfeHsU7JU5prCrQt1)
  - **Hello ID**: 4926026367 (123456)
  - **Issue**: User is flagged as host but agencyId is missing/null
  - **Proposed Correction**: MANUAL REVIEW REQUIRED: Agency must recruit this host via Agency Management screen.

## 10. Hosts with Dangling Agency (Total: 8)

* **Document**: [`users/2jp08v1H2eq7lD44KQN4`](file:///users/2jp08v1H2eq7lD44KQN4)
  - **Hello ID**: 4830239926 (Host_Rose)
  - **Current Agency ID**: `PeXwnBhFYuw0StePOH3K`
  - **Issue**: agencyId "PeXwnBhFYuw0StePOH3K" does not exist in agencies collection
  - **Proposed Correction**: MANUAL REVIEW REQUIRED: Agency ID "PeXwnBhFYuw0StePOH3K" does not exist in agencies collection.

* **Document**: [`users/2wbYCt2G9KjAsjMD178h`](file:///users/2wbYCt2G9KjAsjMD178h)
  - **Hello ID**: 3058297519 (Host_Aria)
  - **Current Agency ID**: `PeXwnBhFYuw0StePOH3K`
  - **Issue**: agencyId "PeXwnBhFYuw0StePOH3K" does not exist in agencies collection
  - **Proposed Correction**: MANUAL REVIEW REQUIRED: Agency ID "PeXwnBhFYuw0StePOH3K" does not exist in agencies collection.

* **Document**: [`users/64AKZHrbpvcuHhoAB4bz`](file:///users/64AKZHrbpvcuHhoAB4bz)
  - **Hello ID**: 3997594033 (Host_Leo)
  - **Current Agency ID**: `PeXwnBhFYuw0StePOH3K`
  - **Issue**: agencyId "PeXwnBhFYuw0StePOH3K" does not exist in agencies collection
  - **Proposed Correction**: MANUAL REVIEW REQUIRED: Agency ID "PeXwnBhFYuw0StePOH3K" does not exist in agencies collection.

* **Document**: [`users/7onb5B5ZdbMbskb9yMYO8avvffl2`](file:///users/7onb5B5ZdbMbskb9yMYO8avvffl2)
  - **Hello ID**: 8039546587 (Panel Host Two)
  - **Current Agency ID**: `lnmsVutlHiO7GDTkRmhRPvs5Y8J2`
  - **Issue**: agencyId "lnmsVutlHiO7GDTkRmhRPvs5Y8J2" does not exist in agencies collection
  - **Proposed Correction**: MANUAL REVIEW REQUIRED: Agency ID "lnmsVutlHiO7GDTkRmhRPvs5Y8J2" does not exist in agencies collection.

* **Document**: [`users/HfJJhQau7XfdrFXyhtjpCkyRKTw2`](file:///users/HfJJhQau7XfdrFXyhtjpCkyRKTw2)
  - **Hello ID**: 4792863199 (Panel Host)
  - **Current Agency ID**: `lnmsVutlHiO7GDTkRmhRPvs5Y8J2`
  - **Issue**: agencyId "lnmsVutlHiO7GDTkRmhRPvs5Y8J2" does not exist in agencies collection
  - **Proposed Correction**: MANUAL REVIEW REQUIRED: Agency ID "lnmsVutlHiO7GDTkRmhRPvs5Y8J2" does not exist in agencies collection.

* **Document**: [`users/KjtUiJyYLF0m0HIH7ADt`](file:///users/KjtUiJyYLF0m0HIH7ADt)
  - **Hello ID**: 2661693722 (Host_Rose)
  - **Current Agency ID**: `PeXwnBhFYuw0StePOH3K`
  - **Issue**: agencyId "PeXwnBhFYuw0StePOH3K" does not exist in agencies collection
  - **Proposed Correction**: MANUAL REVIEW REQUIRED: Agency ID "PeXwnBhFYuw0StePOH3K" does not exist in agencies collection.

* **Document**: [`users/lDLp5QDDbXRzfT14qEAr4SauR0G3`](file:///users/lDLp5QDDbXRzfT14qEAr4SauR0G3)
  - **Hello ID**: 3485703221 (NAZMUL)
  - **Current Agency ID**: `pc6mVRnBCVOTV9nM5J7FErJ5WZc2`
  - **Issue**: agencyId "pc6mVRnBCVOTV9nM5J7FErJ5WZc2" does not exist in agencies collection
  - **Proposed Correction**: MANUAL REVIEW REQUIRED: Agency ID "pc6mVRnBCVOTV9nM5J7FErJ5WZc2" does not exist in agencies collection.

* **Document**: [`users/lnmsVutlHiO7GDTkRmhRPvs5Y8J2`](file:///users/lnmsVutlHiO7GDTkRmhRPvs5Y8J2)
  - **Hello ID**: 3706067376 (Agency Lead)
  - **Current Agency ID**: `lnmsVutlHiO7GDTkRmhRPvs5Y8J2`
  - **Issue**: agencyId "lnmsVutlHiO7GDTkRmhRPvs5Y8J2" does not exist in agencies collection
  - **Proposed Correction**: MANUAL REVIEW REQUIRED: Agency ID "lnmsVutlHiO7GDTkRmhRPvs5Y8J2" does not exist in agencies collection.

## 11. Staff and Agencies Missing Role Codes (Target for Task B) (Total: 0)

_No gaps detected in this category._

## 12. Role Codes with Invalid Length or Characters (Total: 0)

_No gaps detected in this category._

## 13. Duplicate Role Codes (Collisions) (Total: 0)

_No gaps detected in this category._

