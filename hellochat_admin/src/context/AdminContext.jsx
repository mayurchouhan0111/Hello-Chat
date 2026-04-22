import { createContext, useContext, useEffect, useState } from 'react';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import { auth, db } from '../firebase';

const AdminContext = createContext();

export const AdminProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [userData, setUserData] = useState(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [isAgencyOwner, setIsAgencyOwner] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (authUser) => {
      try {
        if (authUser) {
          const userDoc = await getDoc(doc(db, "users", authUser.uid));
          const data = userDoc.data();
          const tags = data?.tags || [];
          const isAuthAdmin = tags.includes("Admin") || tags.includes("SuperAdmin");
          const isAuthAgency = data?.isAgencyOwner === true || tags.includes("Agency");
          
          setUser(authUser);
          setUserData({ uid: authUser.uid, ...data });
          setIsAdmin(isAuthAdmin);
          setIsAgencyOwner(isAuthAgency);
        } else {
          setUser(null);
          setUserData(null);
          setIsAdmin(false);
          setIsAgencyOwner(false);
        }
      } catch (err) {
        console.error("Auth context error:", err);
        setUser(null);
        setUserData(null);
        setIsAdmin(false);
        setIsAgencyOwner(false);
      } finally {
        setLoading(false);
      }
    });
    return unsub;
  }, []);

  const logout = () => signOut(auth);

  return (
    <AdminContext.Provider value={{ user, userData, isAdmin, isAgencyOwner, loading, logout }}>
      {children}
    </AdminContext.Provider>
  );
};

export const useAdmin = () => useContext(AdminContext);
