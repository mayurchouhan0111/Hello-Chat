import { useState, useEffect } from 'react';
import { db } from '../firebase';
import { 
  collection, 
  query, 
  getDocs, 
  doc, 
  limit, 
  writeBatch, 
  deleteDoc,
  getDoc,
  updateDoc,
  where
} from 'firebase/firestore';
import { 
  Search, 
  Trash2, 
  Users, 
  Shield, 
  Info,
  X,
  Plus,
  Zap,
  RefreshCw,
  MoreVertical,
  Activity,
  Trophy,
  User
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

const FamilyDetailsModal = ({ family, onClose, onUpdate }) => {
  const [members, setMembers] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchMembers();
  }, [family]);

  const fetchMembers = async () => {
    setLoading(true);
    try {
      const memberDetails = [];
      for (const uid of family.memberUids) {
        const userDoc = await getDoc(doc(db, "users", uid));
        if (userDoc.exists()) {
          memberDetails.push({ id: userDoc.id, ...userDoc.data() });
        }
      }
      setMembers(memberDetails);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleRemoveMember = async (memberUid) => {
    if (!window.confirm(`Remove ${memberUid} from family?`)) return;
    try {
      const batch = writeBatch(db);
      
      // Update family
      const newMembers = family.memberUids.filter(id => id !== memberUid);
      batch.update(doc(db, "families", family.id), { memberUids: newMembers });
      
      // Update user
      batch.update(doc(db, "users", memberUid), { 
        familyId: null, 
        isFamilyOwner: false 
      });
      
      await batch.commit();
      alert("Member removed.");
      fetchMembers();
      onUpdate();
    } catch (err) {
      alert("Error: " + err.message);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md">
      <div className="bg-[#09090B] border border-white/10 w-full max-w-2xl rounded-3xl overflow-hidden shadow-2xl">
        <div className="p-6 border-b border-white/5 flex justify-between items-center">
          <div className="flex items-center gap-4">
            <div className="p-3 bg-amber-500/20 text-amber-500 rounded-2xl">
              <Users size={24} />
            </div>
            <div>
              <h2 className="text-xl font-black text-white uppercase tracking-tight">{family.name}</h2>
              <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest leading-none mt-1">
                ID: {family.id}
              </p>
            </div>
          </div>
          <button onClick={onClose} className="p-2 hover:bg-white/5 rounded-full transition-colors">
            <X size={20} className="text-slate-500" />
          </button>
        </div>

        <div className="p-6 max-h-[60vh] overflow-y-auto custom-scrollbar">
          <div className="grid grid-cols-3 gap-4 mb-8">
            <div className="p-4 rounded-2xl bg-white/5 border border-white/5">
              <p className="text-[10px] font-black text-slate-500 uppercase mb-1">Total Members</p>
              <p className="text-xl font-black text-white">{family.memberUids?.length || 0}</p>
            </div>
            <div className="p-4 rounded-2xl bg-white/5 border border-white/5">
              <p className="text-[10px] font-black text-slate-500 uppercase mb-1">Battle Points</p>
              <p className="text-xl font-black text-indigo-400">{family.totalBattlePoints || 0}</p>
            </div>
            <div className="p-4 rounded-2xl bg-white/5 border border-white/5">
              <p className="text-[10px] font-black text-slate-500 uppercase mb-1">Combat Points</p>
              <p className="text-xl font-black text-emerald-400">{family.totalCombatPoints || 0}</p>
            </div>
          </div>

          <h3 className="text-xs font-black text-slate-500 uppercase tracking-widest mb-4 ml-2">Family Roster</h3>
          <div className="space-y-3">
            {loading ? (
              <div className="p-8 flex justify-center"><RefreshCw className="animate-spin text-slate-600" /></div>
            ) : members.map(m => (
              <div key={m.id} className="flex items-center justify-between p-4 bg-white/5 rounded-2xl border border-white/5 group">
                <div className="flex items-center gap-3">
                  <img src={m.profilePhotoUrl} className="w-10 h-10 rounded-xl object-cover" alt="" />
                  <div>
                    <p className="text-sm font-black text-white flex items-center gap-2">
                        {m.displayName}
                        {m.id === family.ownerId && <Shield size={12} className="text-amber-500" />}
                    </p>
                    <p className="text-[10px] font-bold text-slate-500">@{m.username}</p>
                  </div>
                </div>
                {m.id !== family.ownerId && (
                  <button 
                    onClick={() => handleRemoveMember(m.id)}
                    className="p-2 text-red-500 opacity-0 group-hover:opacity-100 hover:bg-red-500/10 rounded-lg transition-all"
                  >
                    <X size={16} />
                  </button>
                )}
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};

export const FamilyManagement = () => {
  const [families, setFamilies] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedFamily, setSelectedFamily] = useState(null);

  useEffect(() => {
    fetchFamilies();
  }, []);

  const fetchFamilies = async () => {
    setLoading(true);
    try {
      const q = query(collection(db, "families"), limit(50));
      const snap = await getDocs(q);
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      setFamilies(list);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleDisband = async (family) => {
    if (!window.confirm(`PERMANENTLY DISBAND ${family.name}? This cannot be undone.`)) return;
    try {
      const batch = writeBatch(db);
      
      // 1. Clear family from members
      for (const uid of family.memberUids) {
        batch.update(doc(db, "users", uid), {
          familyId: null,
          isFamilyOwner: false
        });
      }

      // 2. Clear join requests
      const requestsSnap = await getDocs(query(collection(db, "familyJoinRequests"), where("familyId", "==", family.id)));
      for (const d of requestsSnap.docs) {
        batch.delete(d.ref);
      }

      // 3. Delete family
      batch.delete(doc(db, "families", family.id));

      await batch.commit();
      alert("Family disbanded successfully.");
      fetchFamilies();
    } catch (err) {
      alert("Error: " + err.message);
    }
  };

  const handleSimulateMembers = async (family) => {
    try {
      const batch = writeBatch(db);
      const names = ["Bot_Alpha", "Bot_Beta", "Bot_Gamma", "Bot_Delta", "Bot_Epsilon"];
      let totalPts = 0;
      const uids = [];

      for (let i = 0; i < 5; i++) {
        const uid = `bot_${family.id}_${i}_${Date.now()}`;
        const pts = 1000 + (i * 200);
        uids.push(uid);
        totalPts += pts;

        batch.set(doc(db, "users", uid), {
          uid,
          displayName: names[i],
          username: names[i].toLowerCase(),
          profilePhotoUrl: `https://api.dicebear.com/7.x/pixel-art/png?seed=${uid}`,
          combatPoints: pts,
          familyId: family.id,
          level: 5 + i
        });
      }

      batch.update(doc(db, "families", family.id), {
        memberUids: [...(family.memberUids || []), ...uids],
        totalCombatPoints: (family.totalCombatPoints || 0) + totalPts
      });

      await batch.commit();
      alert("Simulated 5 members added.");
      fetchFamilies();
    } catch (err) {
      alert(err.message);
    }
  };

  const handleSimulateBattle = async (family) => {
    try {
      await updateDoc(doc(db, "families", family.id), {
        totalBattlePoints: (family.totalBattlePoints || 0) + 1500,
        level: (family.totalBattlePoints + 1500) > (family.level * 5000) ? (family.level + 1) : family.level
      });
      alert("Battle simulation complete.");
      fetchFamilies();
    } catch (err) {
      alert(err.message);
    }
  };

  const filteredFamilies = families.filter(f => 
    f.name?.toLowerCase().includes(searchTerm.toLowerCase()) || 
    f.id?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="p-8 space-y-8 min-h-screen bg-[#020617] text-slate-200">
      {selectedFamily && (
        <FamilyDetailsModal 
          family={selectedFamily} 
          onClose={() => setSelectedFamily(null)} 
          onUpdate={fetchFamilies}
        />
      )}

      <div className="flex flex-col md:flex-row md:items-center justify-between gap-8 pb-8 border-b border-white/5">
        <div>
          <h1 className="text-4xl font-black text-white tracking-widest uppercase">Family Oversight</h1>
          <p className="text-slate-500 font-bold text-xs uppercase tracking-widest mt-2">Manage clan structures and hierarchies</p>
        </div>
        
        <div className="relative group w-80">
          <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
             <Search className="text-slate-600 group-focus-within:text-[#00E5FF] transition-colors" size={18} />
          </div>
          <input 
            type="text" 
            placeholder="Search Clans..."
            className="glass-input w-full pl-12 !py-3.5"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <AnimatePresence>
          {loading ? (
             <div className="col-span-full py-20 flex flex-col items-center gap-4">
                <RefreshCw size={40} className="text-indigo-500 animate-spin" />
                <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Indexing Clan Documents...</p>
             </div>
          ) : filteredFamilies.map((family) => (
            <motion.div 
              key={family.id}
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              className="bg-[#09090B] border border-white/5 rounded-[32px] p-6 hover:bg-white/[0.02] transition-all relative overflow-hidden group"
            >
              <div className="absolute top-0 right-0 p-8 opacity-5 group-hover:opacity-10 transition-opacity">
                 <Shield size={120} />
              </div>

              <div className="relative">
                <div className="flex items-center gap-4 mb-6">
                  <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-indigo-500/20 to-purple-500/20 border border-white/5 overflow-hidden">
                    {family.avatarUrl ? (
                      <img src={family.avatarUrl} className="w-full h-full object-cover" alt="" />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center text-indigo-400">
                        <Users size={32} />
                      </div>
                    )}
                  </div>
                  <div>
                    <h3 className="font-black text-white text-lg tracking-tight">{family.name}</h3>
                    <p className="text-[10px] font-black text-amber-500 uppercase tracking-widest">{family.tag || 'NO TAG'}</p>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-3 mb-6">
                  <div className="p-3 bg-white/5 rounded-2xl flex flex-col gap-1 border border-white/5">
                    <div className="flex items-center gap-2 text-slate-500">
                      <Users size={12} />
                      <span className="text-[8px] font-black uppercase">Members</span>
                    </div>
                    <span className="text-sm font-black text-white">{family.memberUids?.length || 0}</span>
                  </div>
                  <div className="p-3 bg-white/5 rounded-2xl flex flex-col gap-1 border border-white/5">
                    <div className="flex items-center gap-2 text-emerald-500">
                      <Trophy size={12} />
                      <span className="text-[8px] font-black uppercase">Level</span>
                    </div>
                    <span className="text-sm font-black text-white">{family.level || 0}</span>
                  </div>
                </div>

                <div className="flex flex-col gap-3 mb-6">
                  <button 
                    onClick={() => handleSimulateMembers(family)}
                    className="w-full flex items-center justify-center gap-2 py-3 bg-indigo-500/10 text-indigo-400 border border-indigo-500/10 rounded-2xl text-[10px] font-black uppercase hover:bg-indigo-500 hover:text-white transition-all"
                  >
                    <Plus size={14} /> Simulate 5 Members
                  </button>
                  <button 
                    onClick={() => handleSimulateBattle(family)}
                    className="w-full flex items-center justify-center gap-2 py-3 bg-amber-500/10 text-amber-500 border border-amber-500/10 rounded-2xl text-[10px] font-black uppercase hover:bg-amber-500 hover:text-white transition-all"
                  >
                    <Zap size={14} /> Simulate Win (+1500 XP)
                  </button>
                </div>

                <div className="flex items-center justify-between pt-4 border-t border-white/5">
                  <button 
                    onClick={() => setSelectedFamily(family)}
                    className="flex items-center gap-2 px-4 py-2 bg-indigo-500/10 text-indigo-400 text-[10px] font-black uppercase tracking-widest rounded-xl hover:bg-indigo-500 hover:text-white transition-all"
                  >
                    <Info size={14} /> Full Intel
                  </button>
                  <button 
                    onClick={() => handleDisband(family)}
                    className="p-2.5 text-slate-500 hover:text-red-500 transition-colors"
                  >
                    <Trash2 size={20} />
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
