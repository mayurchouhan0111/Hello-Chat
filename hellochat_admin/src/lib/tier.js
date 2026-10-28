/**
 * Client-side mirror of `functions/lib/hb_pms.js` normalizeTier/HB_RANK.
 *
 * The panel used to derive the tier with `rawRole || fallbackChain`, which
 * disagrees with the backend whenever `role` and `tags` conflict - e.g. a doc
 * with `role:'admin'` + `tags:['Owner']` is `owner` to the server and `admin`
 * to the panel, so the Owner was 403'd out of their own screens.
 *
 * It also had a fail-open hole: `TIER_RANK['user']` is `undefined`, and
 * `undefined < 2` is `false`, so ANY role outside these tiers passed every
 * route guard. Unknown tiers now map to `user` (rank -1).
 */

export const TIER_RANK = { user: -1, host: 0, agency: 1, admin: 2, superadmin: 3, owner: 4 };

/** Collapse `role` + `tags` + `isAgencyOwner` into one tier, mirroring normalizeTier. */
export function tierOf(data) {
  if (!data) return 'user';
  const tags = data.tags || [];
  const role = (data.role || '').toLowerCase();
  if (role === 'owner' || tags.includes('Owner')) return 'owner';
  if (role === 'superadmin' || tags.includes('SuperAdmin')) return 'superadmin';
  if (role === 'admin' || tags.includes('Admin')) return 'admin';
  if (role === 'agency' || data.isAgencyOwner === true || tags.includes('Agency')) return 'agency';
  if (role === 'host' || data.isHost === true || tags.includes('Host')) return 'host';
  return 'user';
}

/** Numeric rank for any tier string. Unknown tiers read as -1 (least privilege). */
export function rankOf(tier) {
  return Object.prototype.hasOwnProperty.call(TIER_RANK, tier) ? TIER_RANK[tier] : -1;
}

/**
 * Firestore filter that mirrors the server's hierarchyScope for direct reads.
 * Returns null only for Owner (the sole tier allowed an unfiltered list).
 * Throws for tiers that may not list users at all, so a caller can never
 * accidentally fall back to an unscoped query.
 */
export function scopeFilterOf(uid, data) {
  const tier = tierOf(data || {});
  if (tier === 'owner') return null;
  if (tier === 'superadmin') {
    if (!data?.branchId) throw new Error('Super Admin has no branch assigned; refusing an unscoped user query.');
    return { field: 'branchId', value: data.branchId };
  }
  if (tier === 'admin') return { field: 'adminId', value: uid };
  if (tier === 'agency') return { field: 'agencyId', value: uid };
  throw new Error(`The ${tier} tier may not list users.`);
}
