import { createContext, useContext, useEffect, useState } from 'react';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import { auth, db } from '../firebase';
import { tierOf } from '../lib/tier';

const AdminContext = createContext();

export const AdminProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [userData, setUserData] = useState(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [isAgencyOwner, setIsAgencyOwner] = useState(false);

  // HB-PMS Hierarchy Properties
  const [role, setRole] = useState('host');
  const [isOwner, setIsOwner] = useState(false);
  const [isSuperAdmin, setIsSuperAdmin] = useState(false);
  const [isAdminRole, setIsAdminRole] = useState(false);
  const [isAgencyRole, setIsAgencyRole] = useState(false);
  const [branchId, setBranchId] = useState(null);
  const [superAdminId, setSuperAdminId] = useState(null);
  const [adminId, setAdminId] = useState(null);
  const [agencyId, setAgencyId] = useState(null);

  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (authUser) => {
      try {
        if (authUser) {
          const userDoc = await getDoc(doc(db, "users", authUser.uid));
          const data = userDoc.data() || {};

          // tierOf() mirrors functions/lib/hb_pms.js normalizeTier. The old
          // `rawRole || fallbackChain` skipped the tag checks entirely whenever
          // `role` held any value, so `role:'admin'` + `tags:['Owner']` read as
          // 'admin' here and 'owner' on the server - locking the Owner out of
          // their own owner-only screens.
          const derivedRole = tierOf(data);

          setUser(authUser);
          setUserData({ uid: authUser.uid, ...data });
          setIsAdmin(derivedRole === 'owner' || derivedRole === 'superadmin' || derivedRole === 'admin');
          setIsAgencyOwner(derivedRole === 'agency');

          // HB-PMS State
          setRole(derivedRole);
          setIsOwner(derivedRole === 'owner');
          setIsSuperAdmin(derivedRole === 'superadmin');
          setIsAdminRole(derivedRole === 'admin');
          setIsAgencyRole(derivedRole === 'agency');
          setBranchId(data?.branchId || null);
          setSuperAdminId(data?.superAdminId || null);
          setAdminId(data?.adminId || null);
          setAgencyId(data?.agencyId || null);
        } else {
          setUser(null);
          setUserData(null);
          setIsAdmin(false);
          setIsAgencyOwner(false);
          setRole('host');
          setIsOwner(false);
          setIsSuperAdmin(false);
          setIsAdminRole(false);
          setIsAgencyRole(false);
          setBranchId(null);
          setSuperAdminId(null);
          setAdminId(null);
          setAgencyId(null);
        }
      } catch (err) {
        console.error("Auth context error:", err);
        setUser(null);
        setUserData(null);
        setIsAdmin(false);
        setIsAgencyOwner(false);
        setRole('host');
        setIsOwner(false);
        setIsSuperAdmin(false);
        setIsAdminRole(false);
        setIsAgencyRole(false);
        setBranchId(null);
        setSuperAdminId(null);
        setAdminId(null);
        setAgencyId(null);
      } finally {
        setLoading(false);
      }
    });
    return unsub;
  }, []);

  const logout = () => signOut(auth);

  return (
    <AdminContext.Provider value={{ 
      user, 
      userData, 
      isAdmin, 
      isAgencyOwner, 
      loading, 
      logout,
      // HB-PMS Exports
      role,
      isOwner,
      isSuperAdmin,
      isAdminRole,
      isAgencyRole,
      branchId,
      superAdminId,
      adminId,
      agencyId
    }}>
      {children}
    </AdminContext.Provider>
  );
};

export const useAdmin = () => useContext(AdminContext);
