import { functions } from '../firebase';
import { httpsCallable } from 'firebase/functions';

/**
 * Scoped user list.
 *
 * Every management screen used to run its own `getDocs(collection(db,'users'))`
 * - unfiltered - and then filter by hand in the browser. That pattern is now
 * denied by firestore.rules (`allow list: if isOwner()`), and it was always the
 * wrong shape anyway: the filter lived in the client, so a tampered build could
 * drop it.
 *
 * The server derives the scope from the caller's resolved hierarchy
 * (`getScopedUsers` -> hierarchyScope), so this returns exactly the users the
 * caller is allowed to see, already projected to hide USD money from tiers that
 * must not see it. Callers do the *display* filtering (search term, role chip)
 * on top of an already-safe set.
 */
export async function listScopedUsers(limit = 500) {
  try {
    const res = await httpsCallable(functions, 'getScopedUsers')({ limit });
    return res.data.users || [];
  } catch (e) {
    console.error('listScopedUsers failed:', e);
    throw e;
  }
}

/** Back-compat shape: Firestore docs expose `id`, the callable returns `uid`. */
export function asDocList(users) {
  return users.map((u) => ({ ...u, id: u.uid }));
}
