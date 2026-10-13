import { Navigate, useLocation } from 'react-router-dom';
import { useAdmin } from '../context/AdminContext';
import { TIER_RANK, rankOf } from '../lib/tier';

/**
 * HB-PMS route guard.
 *
 * Minimum rank per route, mirroring lib/hb_pms.js on the backend. A route that
 * asks for `min="superadmin"` refuses admin, agency and host alike.
 *
 * SECURITY NOTE: this is UX, not authority. `role` is derived from the viewer's
 * own user doc, which they cannot write (`tags`/`role` are in PROTECTED_FIELDS in
 * firestore.rules) - so it cannot be self-granted - but every privileged action is
 * also enforced server-side in the callable that performs it. Removing this guard
 * would show a 403 sooner, it would not grant access to data.
 *
 * FAIL CLOSED: rankOf() maps an unknown tier to 0 instead of `undefined`.
 * The previous `TIER_RANK[role] < TIER_RANK[min]` evaluated `undefined < 2` ->
 * false -> access GRANTED for any role outside the five keys (e.g. 'user').
 */

export function RequireRole({ min = 'admin', children }) {
  const { user, role, loading } = useAdmin();
  const location = useLocation();

  if (loading) {
    return (
      <div className="min-h-screen bg-slate-950 flex items-center justify-center">
        <div className="text-slate-400 text-sm">Verifying access…</div>
      </div>
    );
  }

  if (!user) {
    return <Navigate to="/login" state={{ from: location.pathname }} replace />;
  }

  if (rankOf(role) < (TIER_RANK[min] ?? Infinity)) {
    return <Forbidden actual={role} required={min} />;
  }

  return children;
}

function Forbidden({ actual, required }) {
  return (
    <div className="min-h-screen bg-slate-950 flex items-center justify-center p-8">
      <div className="max-w-md text-center">
        <div className="text-5xl mb-4">403</div>
        <h1 className="text-xl font-bold text-white mb-2">Access denied</h1>
        <p className="text-slate-400 text-sm mb-6">
          This section requires the <span className="text-white font-semibold">{required}</span> tier.
          You are signed in as <span className="text-white font-semibold">{actual}</span>.
        </p>
        <a
          href="/"
          className="inline-block px-5 py-2.5 rounded-lg bg-slate-800 text-white text-sm hover:bg-slate-700 transition-colors"
        >
          Back to dashboard
        </a>
      </div>
    </div>
  );
}
