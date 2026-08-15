---
name: react-admin-dashboard
description: >-
  Guidelines for building clean, responsive React admin UI screens in
  hellochat_admin (React 19, Vite, Tailwind, Firebase/Firestore). Covers
  Firestore real-time bindings, form validation, status indicators, data
  tables, and admin security. Use when building or modifying admin screens,
  forms, lists, dashboards, or any React UI that reads/writes Firestore.
---

# React Admin Dashboard Skills (hellochat_admin)

Rules for the `hellochat_admin` React 19 + Vite + Tailwind + Firebase admin
app. Screens live in `src/screens/`, shared layout in `src/components/`, and
Firebase is initialized in `src/firebase.js`.

## Use this skill when

- Building or modifying admin screens in `src/screens/**`
- Adding Firestore real-time lists, forms, tables, or status badges
- Writing admin authentication/authorization (LoginScreen, AdminContext)
- Calling Cloud Functions for privileged actions (balance adjustments,
  withdrawals, game config) from the admin UI

## Use this skill when (stack map)

| Concern | Location | Notes |
|---------|----------|-------|
| Firebase init | `src/firebase.js` | single shared `firebaseApp`, auth, firestore |
| Layout/shell | `src/components/AdminLayout.jsx` | nav + app frame |
| Auth state | `src/context/AdminContext.jsx` | login, logout, role checks |
| Screens | `src/screens/*.jsx` | feature admin pages |
| Styling | Tailwind (v3.4) | utility classes; keep dark-friendly |

## 1. Firestore Real-Time Bindings

- Read data reactively with `firebase/firestore` `onSnapshot` inside a
  `useEffect`; unsubscribe in the cleanup so no listeners leak:
  ```jsx
  useEffect(() => {
    const q = query(collection(db, "users"), orderBy("createdAt", "desc"));
    const unsub = onSnapshot(q, (snap) => {
      setRows(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
    }, (err) => setError(err));
    return unsub;
  }, []);
  ```
- Always provide loading (skeleton/spinner), error, and empty states. Never leave
  a table blank while Firestore streams.
- For writes that are privileged (balance changes, withdrawals, config), do NOT
  write directly to Firestore from the client with elevated rules. Call the
  Cloud Function (`getFunctions`, `httpsCallable`) and show the returned result.
  Direct client writes must only target collections the security rules permit.
- Debounce search inputs; use `onSnapshot` only for the visible page/filter
  window — don't stream the entire collection. Prefer `limit`/`where`/`orderBy`
  and paginate large tables.

## 2. Form Validation

- Validate on the client AND re-validate server-side (in the Cloud Function).
  Client validation is UX; server validation is the security boundary.
- For each form field:
  - required, type (number/string/email), min/max bounds
  - numeric fields: `Number.isFinite(parseFloat(v))`, `>= 0`, no `NaN`
  - reject empty/whitespace; trim strings
- Show inline per-field error messages (Tailwind `text-red-*`) and a summary
  error on failed submit. Disable the submit button while a call is in flight.
- Never trust the client amount for balance/reward edits — always send the raw
  intent and let the Cloud Function compute (see `firebase-transactions-security`).

## 3. Status Indicators

- Use consistent, color-coded status chips for state fields (active/banned,
  pending/approved/declined, online/offline, enabled/disabled). Define a small
  shared badge component (or map object) so colors are consistent across screens
  instead of inlining classes per screen.
- Never show raw Firestore error strings in the UI; map error codes to friendly
  messages (e.g. `permission-denied` → "You don't have permission to do this").
- For async rows, show a per-row pending state (spinner/disabled) so the admin
  sees which action is in flight.

## 4. Layout & Responsiveness

- Admin screens are desktop-first but must not break at narrower widths: use
  responsive grid (`grid-cols-1 md:grid-cols-2 lg:grid-cols-3`) for card grids
  and `overflow-x-auto` for tables.
- Keep the shell in `AdminLayout.jsx`; screens own only their content area.
- Use `lucide-react` icons consistently; do not mix icon sets.

## 5. Admin Security

- All admin routes require auth: check `AdminContext`/`LoginScreen` before
  rendering screen content; redirect to login on `unauthenticated`.
- Role/level checks (admin/super-admin/reseller) gate privileged screens and
  actions; surface a clear "no access" state rather than hiding silently.
- Do not store Firebase config secrets in the client — `firebase.js` uses
  public web config only. Service-account keys stay server-side (see
  `scripts/service-account-key.json` is a deploy secret — never commit).
- Every balance/admin mutation must be callable-function-gated and audited
  (see `firebase-transactions-security`), never a bare Firestore `setDoc` from
  the client.

## 6. Verification

- Run `npm run lint` (eslint 9) in `hellochat_admin` after changes.
- Run `npm run build` (vite build) to confirm the production bundle compiles.
- Manually verify: login, real-time list updates on another tab, form
  validation errors, and a privileged callable round-trip.

## Do not use this skill when

- Writing Flutter UI/providers → `flutter-architecture`
- Writing Cloud Functions / Firestore transactions → `firebase-transactions-security`