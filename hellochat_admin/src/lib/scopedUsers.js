import { db, functions } from '../firebase';
import { httpsCallable } from 'firebase/functions';
import { collection, getDocs, limit as fsLimit, query } from 'firebase/firestore';

/**
 * Scoped user list with automatic direct Firestore fallback.
 */
export async function listScopedUsers(limitCount = 500) {
  try {
    const res = await httpsCallable(functions, 'getScopedUsers')({ limit: limitCount });
    if (res?.data?.users) {
      return res.data.users;
    }
  } catch (e) {
    console.warn('getScopedUsers callable unavailable, falling back to direct Firestore:', e?.message);
  }

  try {
    const snap = await getDocs(query(collection(db, 'users'), fsLimit(limitCount)));
    return snap.docs.map((d) => ({ ...d.data(), uid: d.id, id: d.id }));
  } catch (err) {
    console.error('Direct Firestore user fetch failed:', err);
    return [];
  }
}

/** Back-compat shape: Firestore docs expose `id`, the callable returns `uid`. */
export function asDocList(users) {
  return users.map((u) => ({ ...u, id: u.uid }));
}
