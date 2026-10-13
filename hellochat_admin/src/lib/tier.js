/**
 * Client-side mirror of `functions/lib/hb_pms.js` normalizeTier/HB_RANK.
 *
 * The panel used to derive the tier with `rawRole || fallbackChain`, which
 * disagrees with the backend whenever `role` and `tags` conflict - e.g. a doc
 * with `role:'admin'` + `tags:['Owner']` is `owner` to the server and `admin`
 * to the panel, so the Owner was 403'd out of their own screens.
 *
 * It also had a fail-open hole: `TIER_RANK['user']` is `undefined`, and
 * `undefined < 2` is `false`, so ANY role outside these five keys passed every
 * route guard. Unknown tiers now map to `host` (rank 0).
 */

export const TIER_RANK = { host: 0, agency: 1, admin: 2, superadmin: 3, owner: 4 };

/** Collapse `role` + `tags` + `isAgencyOwner` into one of the five tiers. */
export function tierOf(data) {
  if (!data) return 'host';
  const tags = data.tags || [];
  const role = (data.role || '').toLowerCase();
  if (role === 'owner' || tags.includes('Owner')) return 'owner';
  if (role === 'superadmin' || tags.includes('SuperAdmin')) return 'superadmin';
  if (role === 'admin' || tags.includes('Admin')) return 'admin';
  if (role === 'agency' || data.isAgencyOwner === true || tags.includes('Agency')) return 'agency';
  return 'host';
}

/** Numeric rank for any tier string. Unknown tiers read as 0 (least privilege). */
export function rankOf(tier) {
  return Object.prototype.hasOwnProperty.call(TIER_RANK, tier) ? TIER_RANK[tier] : 0;
}
