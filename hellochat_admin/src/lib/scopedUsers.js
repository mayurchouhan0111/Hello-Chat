import { auth, db, functions } from '../firebase';
import { httpsCallable } from 'firebase/functions';
import { collection, doc, getDoc, getDocs, limit as fsLimit, query, where } from 'firebase/firestore';
import { scopeFilterOf } from './tier';

/**
 * Scoped user list with automatic direct Firestore fallback.
 *
 * The fallback must apply the same hierarchy filter as the callable. An
 * unfiltered users query is either denied by the rules or, for an Owner,
 * returns the whole platform; it must never be used for any other tier.
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

  const uid = auth.currentUser?.uid;
  if (!uid) throw new Error('Not signed in; refusing an unscoped user query.');

  const selfSnap = await getDoc(doc(db, 'users', uid));
  if (!selfSnap.exists()) throw new Error('Signed-in user profile not found.');
  const filter = scopeFilterOf(uid, selfSnap.data());
  const constraints = filter ? [where(filter.field, '==', filter.value)] : [];

  const snap = await getDocs(query(collection(db, 'users'), ...constraints, fsLimit(limitCount)));
  return snap.docs.map((d) => ({ ...d.data(), uid: d.id, id: d.id }));
}

/** Back-compat shape: Firestore docs expose `id`, the callable returns `uid`. */
export function asDocList(users) {
  return users.map((u) => ({ ...u, id: u.uid }));
}
