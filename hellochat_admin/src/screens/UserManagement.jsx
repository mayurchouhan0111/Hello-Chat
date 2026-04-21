import { useState, useEffect } from 'react';
import { db, functions } from '../firebase';
import { 
  collection, 
  query, 
  getDocs, 
  where, 
  doc, 
  limit, 
  writeBatch, 
  serverTimestamp, 
  deleteDoc,
  getDoc,
  updateDoc
} from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { 
  Search, 
  Ban, 
  CheckCircle, 
  Coins, 
  X,
  Plus,
  Minus,
  Diamond,
  Zap,
  Trash2,
  UserPlus,
  ShieldCheck,
  RefreshCw,
  Building2
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

const BalanceAdjustmentModal = ({ user, onClose, onUpdate }) => {
  const [amount, setAmount] = useState('100');
  const [currency, setCurrency] = useState('Diamonds');
  const [reason, setReason] = useState('Admin Adjustment');
  const [isProcessing, setIsProcessing] = useState(false);

  const handleAdjust = async (isAdding) => {
    setIsProcessing(true);
    try {
      const finalAmount = isAdding ? parseInt(amount) : -parseInt(amount);
      const functionName = currency === 'Diamonds' ? 'adminAdjustBalance' : 'adminAdjustBeans';
      
      const balanceAdjust = httpsCallable(functions, functionName);
      await balanceAdjust({ 
        targetUid: user.id || user.uid, 
        amount: finalAmount, 
        reason 
      });
      
      alert(`Successfully ${isAdding ? 'added' : 'subtracted'} ${amount} ${currency}`);
      onUpdate();
      onClose();
    } catch (err) {
      console.error(err);
      alert(err.message);
    } finally {
      setIsProcessing(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md">
      <div className="bg-[#09090B] border border-white/10 w-full max-w-md rounded-3xl p-8 shadow-2xl">
        <div className="flex justify-between items-center mb-6">
          <div className="flex items-center gap-3">
            <div className="p-3 bg-indigo-500/20 text-indigo-400 rounded-xl">
              <Coins size={24} />
            </div>
            <div>
              <h2 className="text-xl font-black text-white uppercase tracking-widest">Adjust Ledger</h2>
              <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest leading-none mt-1">
                Ref: {(user.id || user.uid).slice(0, 15)}...
              </p>
            </div>
          </div>
          <button onClick={onClose} className="p-2 hover:bg-white/5 rounded-full transition-colors">
            <X size={20} className="text-slate-500" />
          </button>
        </div>

        <div className="space-y-6">
          <div className="grid grid-cols-2 gap-4">
            <button 
              onClick={() => setCurrency('Diamonds')}
              className={`p-4 rounded-2xl border transition-all ${currency === 'Diamonds' ? 'bg-indigo-500/20 border-indigo-500/50 text-indigo-400' : 'bg-white/5 border-white/5 text-slate-500'}`}
            >
              <div className="flex flex-col items-center gap-2">
                <Diamond size={24} />
                <span className="text-[10px] font-black uppercase tracking-widest">Diamonds</span>
              </div>
            </button>
            <button 
              onClick={() => setCurrency('Beans')}
              className={`p-4 rounded-2xl border transition-all ${currency === 'Beans' ? 'bg-amber-500/20 border-amber-500/50 text-amber-500' : 'bg-white/5 border-white/5 text-slate-500'}`}
            >
              <div className="flex flex-col items-center gap-2">
                <div className="w-6 h-6 border-2 border-amber-500/50 rounded-full flex items-center justify-center">
                   <div className="w-2 h-2 bg-amber-500 rounded-full"></div>
                </div>
                <span className="text-[10px] font-black uppercase tracking-widest">Beans</span>
              </div>
            </button>
          </div>

          <div className="space-y-2">
            <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-2">Delta Value</label>
            <input 
              type="number" 
              className="w-full bg-black border border-white/10 rounded-2xl p-4 text-white font-black text-2xl text-center focus:border-indigo-500 outline-none"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
            />
          </div>

          <div className="grid grid-cols-2 gap-4 mt-8">
            <button 
              disabled={isProcessing}
              onClick={() => handleAdjust(false)}
              className="flex items-center justify-center gap-2 p-5 bg-red-500/10 text-red-500 font-black text-xs uppercase tracking-widest rounded-2xl hover:bg-red-500 hover:text-white transition-all disabled:opacity-50"
            >
              <Minus size={16} /> Subtract
            </button>
            <button 
              disabled={isProcessing}
              onClick={() => handleAdjust(true)}
              className="flex items-center justify-center gap-2 p-5 bg-indigo-600 text-white font-black text-xs uppercase tracking-widest rounded-2xl hover:bg-indigo-700 transition-all disabled:opacity-50"
            >
              <Plus size={16} /> Reward
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export const UserManagement = () => {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedUser, setSelectedUser] = useState(null);
  const [isSeeding, setIsSeeding] = useState(false);

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    setLoading(true);
    try {
      const q = query(collection(db, "users"), limit(20));
      const snap = await getDocs(q);
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      setUsers(list);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleCleanupEcosystem = async (user) => {
    const targetUid = user.id || user.uid;
    if (!window.confirm(`WIPE TEST DATA? This will remove all synth users associated with ${user.displayName}.`)) return;
    
    setIsSeeding(true);
    try {
      const batch = writeBatch(db);
      
      // Cleanup following
      const followingSnap = await getDocs(collection(db, "users", targetUid, "following"));
      for (const d of followingSnap.docs) {
        if (d.id.startsWith('test_')) {
          batch.delete(d.ref); // Remove link
          batch.delete(doc(db, "users", d.id)); // Remove synthetic user
          batch.delete(doc(db, "users", d.id, "followers", targetUid)); // Remove reverse link
        }
      }

      // Cleanup followers
      const followersSnap = await getDocs(collection(db, "users", targetUid, "followers"));
      for (const d of followersSnap.docs) {
        if (d.id.startsWith('test_')) {
          batch.delete(d.ref);
          batch.delete(doc(db, "users", d.id, "following", targetUid));
        }
      }

      await batch.commit();
      alert("Test data purged successfully.");
      fetchUsers();
    } catch (err) {
      alert("Cleanup Error: " + err.message);
    } finally {
      setIsSeeding(false);
    }
  };

  const handleFreshSeed = async (user) => {
    const targetUid = user.id || user.uid;
    setIsSeeding(true);
    try {
      const batch = writeBatch(db);
      const names = ["Arena Pro", "Battle King", "PK Ninja", "Stream Master", "Gamer God"];
      
      for (let i = 0; i < 5; i++) {
        const fakeUid = `test_synthetic_${i}_${Date.now()}`;
        const fakeUsername = `pro_player_${i}_${Math.floor(Math.random() * 999)}`;
        const fakeUserRef = doc(db, "users", fakeUid);
        
        batch.set(fakeUserRef, {
          uid: fakeUid,
          username: fakeUsername,
          username_lowercase: fakeUsername,
          displayName: names[i],
          bio: "100% Guaranteed PK Valid test profile.",
          profilePhotoUrl: `https://api.dicebear.com/7.x/avataaars/png?seed=${fakeUsername}`,
          gender: i % 2 === 0 ? 'male' : 'female',
          country: 'US',
          diamondBalance: 1000,
          beansBalance: 50,
          xp: 2000,
          benchXP: 1000,
          princeXP: 500,
          level: 15,
          followerCount: 1, 
          followingCount: 1, 
          friendsCount: 1,
          createdAt: serverTimestamp(),
          lastActive: serverTimestamp(),
          status: 'online',
          tags: ["TestUser", "Verified"],
          badges: ["pk_legend"],
          profileFrame: '',
          entryAnimation: '',
          vipTier: 'none',
          isBanned: false,
          blockedUids: [],
          referralCode: fakeUsername.toUpperCase(),
          totalReferralEarnings: 0,
          isAgencyOwner: false,
          lastVipClaim: '',
          cpLevel: 0,
          cpPoints: 0
        });

        // 100% Mutual Following for PK
        batch.set(doc(db, "users", targetUid, "following", fakeUid), { followedAt: serverTimestamp() });
        batch.set(doc(db, "users", fakeUid, "followers", targetUid), { followedAt: serverTimestamp() });
        batch.set(doc(db, "users", targetUid, "followers", fakeUid), { followedAt: serverTimestamp() });
        batch.set(doc(db, "users", fakeUid, "following", targetUid), { followedAt: serverTimestamp() });
      }

      await batch.commit();
      alert("Fresh Seeding Successful! 5 Pro-level opponents added.");
      fetchUsers();
    } catch (err) {
      alert("Seeding Error: " + err.message);
    } finally {
      setIsSeeding(false);
    }
  };

    const handleFullSync = async (user) => {
        if (!window.confirm("Perform Full Ecosystem Sync? This will wipe old test data and seed 5 fresh pro users.")) return;
        
        setIsSeeding(true);
        try {
            const targetUid = user.id || user.uid;
            const batch = writeBatch(db);

            // 1. Cleanup old ones (test_*)
            const followingSnap = await getDocs(collection(db, "users", targetUid, "following"));
            for (const d of followingSnap.docs) {
                if (d.id.startsWith('test_') || d.id.startsWith('fake_')) {
                    batch.delete(d.ref);
                    batch.delete(doc(db, "users", d.id));
                    batch.delete(doc(db, "users", d.id, "followers", targetUid));
                }
            }
            const followersSnap = await getDocs(collection(db, "users", targetUid, "followers"));
            for (const d of followersSnap.docs) {
                if (d.id.startsWith('test_') || d.id.startsWith('fake_')) {
                    batch.delete(d.ref);
                    batch.delete(doc(db, "users", d.id, "following", targetUid));
                }
            }

            // 2. Seed 5 New Pro Users
            const names = ["Shadow Assassin", "Blaze Warrior", "Vortex Mage", "Phantom Rogue", "Aether Knight"];
            for (let i = 0; i < 5; i++) {
                const fakeUid = `test_pro_v2_${i}_${Date.now()}`;
                const fakeUsername = `master_pk_${i}_${Math.floor(Math.random() * 999)}`;
                const fakeUserRef = doc(db, "users", fakeUid);
                
                batch.set(fakeUserRef, {
                    uid: fakeUid,
                    username: fakeUsername,
                    username_lowercase: fakeUsername,
                    displayName: names[i],
                    bio: "Ultimate PK Opponent v2.",
                    profilePhotoUrl: `https://api.dicebear.com/7.x/avataaars/png?seed=${fakeUsername}`,
                    gender: i % 2 === 0 ? 'male' : 'female',
                    country: 'PK',
                    diamondBalance: 9999,
                    beansBalance: 500,
                    xp: 5000,
                    benchXP: 2000,
                    princeXP: 1000,
                    level: 50,
                    followerCount: 200, 
                    followingCount: 150, 
                    friendsCount: 50,
                    createdAt: serverTimestamp(),
                    lastActive: serverTimestamp(),
                    status: 'online',
                    tags: ["TestUser", "Pro"],
                    badges: ["pk_elite_v2"],
                    profileFrame: '',
                    entryAnimation: '',
                    vipTier: 'none',
                    isBanned: false,
                    blockedUids: [],
                    referralCode: fakeUsername.toUpperCase(),
                    totalReferralEarnings: 0,
                    isAgencyOwner: false,
                    lastVipClaim: '',
                    cpLevel: 0,
                    cpPoints: 0
                });

                batch.set(doc(db, "users", targetUid, "following", fakeUid), { followedAt: serverTimestamp() });
                batch.set(doc(db, "users", fakeUid, "followers", targetUid), { followedAt: serverTimestamp() });
                batch.set(doc(db, "users", targetUid, "followers", fakeUid), { followedAt: serverTimestamp() });
                batch.set(doc(db, "users", fakeUid, "following", targetUid), { followedAt: serverTimestamp() });
            }

            await batch.commit();
            alert("Full Sync Complete! Your ecosystem is now fresh and ready for battle.");
            fetchUsers();
        } catch (err) {
            alert("Sync Error: " + err.message);
        } finally {
            setIsSeeding(false);
        }
    };

    const handleAppointAgency = async (user) => {
        const targetUid = user.id || user.uid;
        if (!window.confirm(`Appoint ${user.displayName} as an Agency Owner?`)) return;
        
        setIsSeeding(true);
        try {
            const userRef = doc(db, "users", targetUid);
            const userSnap = await getDoc(userRef);
            const currentTags = userSnap.data()?.tags || [];
            
            await updateDoc(userRef, {
                isAgencyOwner: true,
                tags: Array.from(new Set([...currentTags, "Agency"]))
            });
            
            alert(`${user.displayName} is now a verified Agency Owner.`);
            fetchUsers();
        } catch (err) {
            alert("Error: " + err.message);
        } finally {
            setIsSeeding(false);
        }
    };

    const filteredUsers = users.filter(u => 
        u.displayName?.toLowerCase().includes(searchTerm.toLowerCase()) || 
        u.username?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        (u.uid || u.id) === searchTerm
    );

  return (
    <div className="p-8 space-y-8 min-h-screen bg-[#020617] text-slate-200">
      {selectedUser && (
        <BalanceAdjustmentModal 
          user={selectedUser} 
          onClose={() => setSelectedUser(null)} 
          onUpdate={fetchUsers} 
        />
      )}

      {isSeeding && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/80 backdrop-blur-xl">
           <div className="flex flex-col items-center gap-6">
              <div className="relative">
                <Zap size={64} className="text-indigo-400 animate-pulse" />
                <div className="absolute inset-0 bg-indigo-500/20 blur-3xl animate-pulse"></div>
              </div>
              <p className="text-xs font-black text-indigo-300 uppercase tracking-[0.4em] animate-pulse">Processing Ecosystem Assets...</p>
           </div>
        </div>
      )}

      <div className="flex flex-col md:flex-row md:items-center justify-between gap-8 pb-8 border-b border-white/5">
        <div>
          <h1 className="text-4xl font-black text-white tracking-widest uppercase">Seed Control</h1>
          <p className="text-slate-500 font-bold text-xs uppercase tracking-widest mt-2">Manage synthetic identities & accounts</p>
        </div>
        
        <div className="relative group min-w-[320px]">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-600 group-focus-within:text-indigo-400" size={18} />
          <input 
            type="text" 
            placeholder="Identity Search..."
            className="w-full bg-slate-900 border border-white/10 rounded-2xl py-4 pl-12 pr-4 outline-none focus:border-indigo-500"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <AnimatePresence>
          {filteredUsers.map((user) => (
            <motion.div 
              key={user.uid || user.id}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              className="bg-[#09090B] border border-white/5 rounded-3xl p-6 hover:bg-white/[0.02] transition-all group"
            >
              <div className="flex items-start justify-between">
                <div className="flex items-center gap-5">
                  <div className="relative">
                    <img 
                      src={user.profilePhotoUrl || `https://api.dicebear.com/7.x/avataaars/png?seed=${user.uid}`} 
                      className="w-16 h-16 rounded-2xl object-cover ring-2 ring-white/5" 
                    />
                    <div className="absolute -bottom-1 -right-1 w-5 h-5 bg-green-500 border-4 border-[#09090B] rounded-full"></div>
                  </div>
                  <div>
                    <h3 className="font-black text-white tracking-tight flex items-center gap-2">
                       {user.displayName}
                       {user.tags?.includes('Admin') && <ShieldCheck size={14} className="text-indigo-400" />}
                    </h3>
                    <div className="flex items-center gap-2">
                       <h3 className="font-black text-white tracking-tight flex items-center gap-2">
                          {user.displayName}
                          {user.tags?.includes('Admin') && <ShieldCheck size={14} className="text-indigo-400" />}
                       </h3>
                       {user.isAgencyOwner && (
                         <span className="bg-amber-500/20 text-amber-500 text-[8px] font-black uppercase px-2 py-0.5 rounded-md border border-amber-500/20">Agency</span>
                       )}
                    </div>
                    <p className="text-[10px] font-black uppercase text-slate-500 tracking-wider">@{user.username || 'Synthetic Identity'}</p>
                    <div className="flex gap-4 mt-2">
                       <div className="flex items-center gap-1.5 pt-1">
                          <Diamond size={10} className="text-indigo-400" />
                          <span className="text-[10px] font-black text-slate-300">{user.diamondBalance || 0}</span>
                       </div>
                       <div className="flex items-center gap-1.5 pt-1">
                          <UserPlus size={10} className="text-slate-500" />
                          <span className="text-[10px] font-black text-slate-300">{user.followerCount || 0} Foll.</span>
                       </div>
                    </div>
                  </div>
                </div>

                <div className="flex flex-col gap-2">
                   <div className="flex gap-2">
                     <button 
                        onClick={() => handleCleanupEcosystem(user)}
                        className="p-2.5 bg-red-500/10 text-red-500 border border-red-500/10 rounded-xl hover:bg-red-500 hover:text-white transition-all"
                        title="Remove Test Followers (Trash)"
                     >
                       <Trash2 size={16} />
                     </button>
                     <button 
                        onClick={() => handleFullSync(user)}
                        className="p-2.5 bg-indigo-500/10 text-indigo-400 border border-indigo-500/10 rounded-xl hover:bg-indigo-500 hover:text-white transition-all"
                        title="ONE-CLICK SYNC (Clear old & Add 5 New)"
                     >
                       <RefreshCw size={16} />
                     </button>
                     <button 
                        onClick={() => handleFreshSeed(user)}
                        className="p-2.5 bg-emerald-500/10 text-emerald-400 border border-emerald-500/10 rounded-xl hover:bg-emerald-500 hover:text-white transition-all shadow-emerald-500/20 shadow-lg"
                        title="Add 5 New Pro Users (Zap)"
                     >
                       <Zap size={16} />
                     </button>
                     <button 
                        onClick={() => handleAppointAgency(user)}
                        className="p-2.5 bg-amber-500/10 text-amber-400 border border-amber-500/10 rounded-xl hover:bg-amber-500 hover:text-white transition-all shadow-amber-500/20 shadow-lg"
                        title="Appoint as Agency Owner"
                     >
                       <Building2 size={16} />
                     </button>
                   </div>
                   <button 
                      onClick={() => setSelectedUser(user)}
                      className="flex items-center justify-center gap-2 p-2 bg-white/5 text-slate-400 border border-white/5 rounded-xl hover:bg-white/10 hover:text-white transition-all text-[10px] font-black uppercase"
                   >
                     <Coins size={12} /> Adjust
                   </button>
                </div>
              </div>
            </motion.div>
          ))}
        </AnimatePresence>
      </div>
    </div>
  );
};
